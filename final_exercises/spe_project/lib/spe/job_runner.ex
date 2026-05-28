defmodule SPE.JobRunner do
  @moduledoc """
  GenServer representing a running SPE job.
  """

  use GenServer

  defstruct job: nil,
            num_workers: :unbounded,
            results: %{},
            running: %{},
            ready: [],
            waiting: []

  def start_link(options \\ []) do
    GenServer.start_link(__MODULE__, options)
  end

  @impl true
  def init(options) do
    state = %__MODULE__{
      job: Keyword.fetch!(options, :job),
      num_workers: Keyword.get(options, :num_workers, :unbounded),
      ready: Keyword.get(options, :ready, []),
      waiting: Keyword.get(options, :waiting, [])
    }

    {:ok, state}
  end
end
