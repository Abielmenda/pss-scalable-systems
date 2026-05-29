defmodule SPE.JobRunner do
  @moduledoc """
  Coordinates task execution for a single job.
  """

  use GenServer

  def start(job_id, parsed_tasks, pubsub_name, _num_workers) do
    child = {__MODULE__, job_id: job_id, tasks: parsed_tasks, pubsub_name: pubsub_name}
    DynamicSupervisor.start_child(SPE.JobSupervisor, child)
  end

  def start_link(options) do
    GenServer.start_link(__MODULE__, options)
  end

  @impl true
  def init(options) do
    tasks = Keyword.fetch!(options, :tasks)

    state = %{
      job_id: Keyword.fetch!(options, :job_id),
      pubsub_name: Keyword.fetch!(options, :pubsub_name),
      tasks: Map.new(tasks, &{&1.name, &1}),
      dependencies: dependencies(tasks),
      dependents: dependents(tasks),
      transitive_dependencies: transitive_dependencies(tasks),
      results: %{},
      running: MapSet.new(),
      finished?: false
    }

    {:ok, state, {:continue, :schedule}}
  end

  @impl true
  def handle_continue(:schedule, state) do
    {:noreply, schedule_ready_tasks(state)}
  end

  @impl true
  def handle_info({:task_finished, task_name, result}, state) do
    state =
      state
      |> put_task_result(task_name, result)
      |> mark_blocked_tasks(task_name, result)
      |> schedule_ready_tasks()
      |> maybe_finish_job()

    {:noreply, state}
  end

  defp put_task_result(state, task_name, result) do
    %{
      state
      | results: Map.put(state.results, task_name, result),
        running: MapSet.delete(state.running, task_name)
    }
  end

  defp mark_blocked_tasks(state, _task_name, {:result, _value}), do: state

  defp mark_blocked_tasks(state, task_name, _failed_result) do
    task_name
    |> descendants(state.dependents)
    |> Enum.reject(&Map.has_key?(state.results, &1))
    |> Enum.reduce(state, fn blocked_task, acc ->
      %{acc | results: Map.put(acc.results, blocked_task, :not_run)}
    end)
  end

  defp schedule_ready_tasks(%{finished?: true} = state), do: state

  defp schedule_ready_tasks(state) do
    ready_tasks =
      state.tasks
      |> Map.values()
      |> Enum.filter(&ready?(&1, state))

    Enum.each(ready_tasks, fn task ->
      task_dependencies = dependency_results(task.name, state)
      SPE.WorkerPool.run(self(), state.job_id, task, task_dependencies, state.pubsub_name)
    end)

    Enum.reduce(ready_tasks, state, fn task, acc ->
      %{acc | running: MapSet.put(acc.running, task.name)}
    end)
  end

  defp ready?(task, state) do
    not Map.has_key?(state.results, task.name) and
      not MapSet.member?(state.running, task.name) and
      Enum.all?(Map.fetch!(state.dependencies, task.name), fn dependency ->
        match?({:result, _value}, Map.get(state.results, dependency))
      end)
  end

  defp dependency_results(task_name, state) do
    state.transitive_dependencies
    |> Map.fetch!(task_name)
    |> Enum.reduce(%{}, fn dependency, acc ->
      case Map.fetch!(state.results, dependency) do
        {:result, value} -> Map.put(acc, dependency, value)
      end
    end)
  end

  defp maybe_finish_job(%{finished?: true} = state), do: state

  defp maybe_finish_job(state) do
    if map_size(state.results) == map_size(state.tasks) do
      status =
        if Enum.all?(state.results, fn {_task_name, result} -> match?({:result, _}, result) end) do
          :succeeded
        else
          :failed
        end

      broadcast(state.pubsub_name, state.job_id, {state.job_id, :result, {status, state.results}})
      %{state | finished?: true}
    else
      state
    end
  end

  defp dependencies(tasks) do
    base = Map.new(tasks, &{&1.name, []})

    Enum.reduce(tasks, base, fn task, acc ->
      Enum.reduce(task.enables, acc, fn enabled_task, inner_acc ->
        Map.update!(inner_acc, enabled_task, &[task.name | &1])
      end)
    end)
  end

  defp dependents(tasks) do
    Map.new(tasks, &{&1.name, &1.enables})
  end

  defp transitive_dependencies(tasks) do
    direct_dependencies = dependencies(tasks)

    Map.new(tasks, fn task ->
      {task.name, all_dependencies(task.name, direct_dependencies)}
    end)
  end

  defp all_dependencies(task_name, direct_dependencies) do
    direct_dependencies
    |> Map.fetch!(task_name)
    |> Enum.flat_map(fn dependency ->
      [dependency | all_dependencies(dependency, direct_dependencies)]
    end)
    |> Enum.uniq()
  end

  defp descendants(task_name, dependents) do
    dependents
    |> Map.fetch!(task_name)
    |> Enum.flat_map(fn dependent ->
      [dependent | descendants(dependent, dependents)]
    end)
    |> Enum.uniq()
  end

  defp broadcast(pubsub_name, job_id, message) do
    Phoenix.PubSub.local_broadcast(
      pubsub_name,
      job_id,
      {:spe, :erlang.monotonic_time(:millisecond), message}
    )
  end
end
