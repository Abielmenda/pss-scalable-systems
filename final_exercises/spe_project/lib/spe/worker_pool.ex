defmodule SPE.WorkerPool do
  @moduledoc """
  Global worker pool for SPE task execution.
  """

  use GenServer

  def start_link(options \\ []) do
    GenServer.start_link(__MODULE__, options, name: __MODULE__)
  end

  def run(job_runner, job_id, task, dependencies, pubsub_name) do
    GenServer.cast(__MODULE__, {:run, job_runner, job_id, task, dependencies, pubsub_name})
  end

  @impl true
  def init(options) do
    {:ok,
     %{
       num_workers: Keyword.get(options, :num_workers, :unbounded),
       active: 0,
       queue: :queue.new(),
       workers: %{}
     }}
  end

  @impl true
  def handle_cast({:run, job_runner, job_id, task, dependencies, pubsub_name}, state) do
    work = {job_runner, job_id, task, dependencies, pubsub_name}
    {:noreply, %{state | queue: :queue.in(work, state.queue)} |> schedule()}
  end

  @impl true
  def handle_info({:worker_result, pid, result}, state) do
    ref = ref_for_pid(state.workers, pid)

    case Map.pop(state.workers, ref) do
      {nil, _workers} ->
        {:noreply, state}

      {worker, workers} ->
        cancel_timer(worker.timer)
        Process.demonitor(ref, [:flush])
        finish_task(worker, result)
        {:noreply, %{state | active: state.active - 1, workers: workers} |> schedule()}
    end
  end

  def handle_info({:worker_timeout, ref}, state) do
    case Map.pop(state.workers, ref) do
      {nil, _workers} ->
        {:noreply, state}

      {worker, workers} ->
        Process.exit(worker.pid, :kill)
        Process.demonitor(ref, [:flush])
        finish_task(worker, {:failed, :timeout})
        {:noreply, %{state | active: state.active - 1, workers: workers} |> schedule()}
    end
  end

  def handle_info({:DOWN, ref, :process, _pid, reason}, state) do
    case Map.pop(state.workers, ref) do
      {nil, _workers} ->
        {:noreply, state}

      {worker, workers} ->
        cancel_timer(worker.timer)
        finish_task(worker, {:failed, {:crashed, reason}})
        {:noreply, %{state | active: state.active - 1, workers: workers} |> schedule()}
    end
  end

  defp schedule(state) do
    if can_start?(state) do
      case :queue.out(state.queue) do
        {{:value, work}, queue} ->
          state
          |> Map.put(:queue, queue)
          |> start_worker(work)
          |> schedule()

        {:empty, _queue} ->
          state
      end
    else
      state
    end
  end

  defp can_start?(%{num_workers: :unbounded}), do: true
  defp can_start?(%{num_workers: num_workers, active: active}), do: active < num_workers

  defp start_worker(state, {job_runner, job_id, task, dependencies, pubsub_name}) do
    broadcast(pubsub_name, job_id, {job_id, :task_started, task.name})
    pool = self()

    {pid, ref} =
      spawn_monitor(fn ->
        send(pool, {:worker_result, self(), SPE.Worker.run(task, dependencies)})
      end)

    timer = start_timer(task.timeout, ref)

    worker = %{
      pid: pid,
      timer: timer,
      job_runner: job_runner,
      job_id: job_id,
      task_name: task.name,
      pubsub_name: pubsub_name
    }

    %{state | active: state.active + 1, workers: Map.put(state.workers, ref, worker)}
  end

  defp start_timer(:infinity, _ref), do: nil

  defp start_timer(timeout, ref) do
    Process.send_after(self(), {:worker_timeout, ref}, timeout)
  end

  defp cancel_timer(nil), do: :ok
  defp cancel_timer(timer), do: Process.cancel_timer(timer)

  defp ref_for_pid(workers, pid) do
    Enum.find_value(workers, fn {ref, worker} ->
      if worker.pid == pid, do: ref
    end)
  end

  defp finish_task(worker, result) do
    broadcast(
      worker.pubsub_name,
      worker.job_id,
      {worker.job_id, :task_terminated, worker.task_name}
    )

    send(worker.job_runner, {:task_finished, worker.task_name, result})
  end

  defp broadcast(pubsub_name, job_id, message) do
    Phoenix.PubSub.local_broadcast(
      pubsub_name,
      job_id,
      {:spe, :erlang.monotonic_time(:millisecond), message}
    )
  end
end
