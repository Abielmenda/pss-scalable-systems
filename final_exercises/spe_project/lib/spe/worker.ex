defmodule SPE.Worker do
  @moduledoc """
  Runs one SPE task in an isolated process.
  """

  def run(task, dependencies) do
    try do
      {:result, task.exec.(dependencies)}
    rescue
      exception -> {:failed, {:crashed, exception}}
    catch
      :exit, reason -> {:failed, {:crashed, reason}}
      kind, reason -> {:failed, {:crashed, {kind, reason}}}
    end
  end
end
