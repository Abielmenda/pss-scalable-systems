defmodule SPE.TaskRunner do
  @moduledoc """
  Runs a task and returns its normalized result.
  """

  def run(_job_id, task, dependencies) do
    SPE.Worker.run(task, dependencies)
  end
end
