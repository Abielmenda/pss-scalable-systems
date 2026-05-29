defmodule SPE.Job do
  @moduledoc """
  Job data helpers.
  """

  defstruct id: nil, name: nil, tasks: %{}

  def from_description(job_id, %{name: name, tasks: tasks}) do
    {:ok, %__MODULE__{id: job_id, name: name, tasks: Map.new(tasks, &{&1.name, &1})}}
  end
end
