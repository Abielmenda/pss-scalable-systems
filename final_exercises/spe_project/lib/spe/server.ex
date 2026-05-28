defmodule SPE.Server do
  @moduledoc """
  GenServer holding SPE job state.
  """

  use GenServer

  defstruct num_workers: :unbounded,
            jobs: %{},
            next_job_id: 1,
            running_tasks: 0,
            queue: []

  def start_link(options \\ []) do
    GenServer.start_link(__MODULE__, options, name: __MODULE__)
  end

  def submit_job(job_description) do
    GenServer.call(__MODULE__, {:submit_job, job_description})
  end

  def start_job(job_id) do
    GenServer.call(__MODULE__, {:start_job, job_id})
  end

  @impl true
  def init(options) do
    state = %__MODULE__{
      num_workers: Keyword.get(options, :num_workers, :unbounded)
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:submit_job, job_description}, _from, state) do
    case SPE.Validator.validate_job(job_description) do
      {:ok, parsed_job} ->
        job_id = state.next_job_id
        job = %{id: job_id, description: parsed_job, status: :pending, runner: nil}

        next_state = %{
          state
          | jobs: Map.put(state.jobs, job_id, job),
            next_job_id: job_id + 1
        }

        {:reply, {:ok, job_id}, next_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:start_job, job_id}, _from, state) do
    case Map.fetch(state.jobs, job_id) do
      :error ->
        {:reply, {:error, :unknown_job}, state}

      {:ok, %{status: status}} when status != :pending ->
        {:reply, {:error, :already_started}, state}

      {:ok, job} ->
        case SPE.JobRunner.start_link(
               job: job.description,
               num_workers: state.num_workers,
               job_id: job_id
             ) do
          {:ok, pid} ->
            updated_job = %{job | status: :running, runner: pid}
            next_state = %{state | jobs: Map.put(state.jobs, job_id, updated_job)}

            {:reply, {:ok, job_id}, next_state}

          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end
    end
  end
end
