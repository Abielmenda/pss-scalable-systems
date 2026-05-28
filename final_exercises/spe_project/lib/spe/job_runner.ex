defmodule SPE.JobRunner do
  @moduledoc """
  Integration point for the job execution engine.
  """

  def start(_job_id, _parsed_tasks, _pubsub_name, _num_workers) do
    {:ok, self()}
  end
end
