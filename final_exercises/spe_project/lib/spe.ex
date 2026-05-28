defmodule SPE do
  @moduledoc """
  Public API for the SPE job processing engine.
  """

  def start_link(options \\ []) do
    SPE.Supervisor.start_link(options)
  end

  def stop(options \\ []) do
    SPE.Supervisor.stop(options)
  end

  def submit_job(job_description) do
    SPE.Server.submit_job(job_description)
  end

  def start_job(job_id) do
    SPE.Server.start_job(job_id)
  end
end
