defmodule SPE.Supervisor do
  @moduledoc """
  Root supervisor for SPE.
  """

  use Supervisor

  def start_link(options \\ []) do
    Supervisor.start_link(__MODULE__, options, name: __MODULE__)
  end

  def stop(_options \\ []) do
    case Process.whereis(__MODULE__) do
      nil ->
        {:error, :not_started}

      pid ->
        try do
          Supervisor.stop(pid)
        catch
          :exit, _reason -> {:error, :not_started}
        end
    end
  end

  @impl true
  def init(options) do
    children = [
      {Phoenix.PubSub, name: SPE.PubSub},
      {DynamicSupervisor, strategy: :one_for_all, name: SPE.JobSupervisor},
      {SPE.WorkerPool, options},
      {SPE.Server, options}
    ]

    Supervisor.init(children, strategy: :one_for_all)
  end
end
