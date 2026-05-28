defmodule SPE.Validator do
  @moduledoc """
  Validates and normalizes SPE job descriptions.
  """

  def validate_job(%{"name" => name, "tasks" => tasks})
      when is_binary(name) and byte_size(name) > 0 and is_list(tasks) do
    with {:ok, parsed_tasks} <- validate_tasks(tasks) do
      {:ok, %{"name" => name, "tasks" => parsed_tasks}}
    end
  end

  def validate_job(_job_description), do: {:error, :invalid_job_description}

  defp validate_tasks(tasks) do
    tasks
    |> Enum.reduce_while({:ok, [], MapSet.new()}, &validate_task/2)
    |> case do
      {:ok, parsed_tasks, _names} -> {:ok, Enum.reverse(parsed_tasks)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp validate_task(task, {:ok, parsed_tasks, names}) when is_map(task) do
    with {:ok, parsed_task} <- parse_task(task),
         :ok <- reject_duplicate_task_name(parsed_task["name"], names) do
      {:cont, {:ok, [parsed_task | parsed_tasks], MapSet.put(names, parsed_task["name"])}}
    else
      {:error, reason} -> {:halt, {:error, reason}}
    end
  end

  defp validate_task(_task, _acc), do: {:halt, {:error, :invalid_task}}

  defp parse_task(%{"name" => name, "exec" => exec} = task)
       when is_binary(name) and byte_size(name) > 0 and is_function(exec, 1) do
    enables = Map.get(task, "enables", [])
    timeout = Map.get(task, "timeout", :infinity)

    with :ok <- validate_enables(enables),
         :ok <- validate_timeout(timeout) do
      {:ok,
       %{
         "name" => name,
         "exec" => exec,
         "enables" => enables,
         "timeout" => timeout
       }}
    end
  end

  defp parse_task(_task), do: {:error, :invalid_task}

  defp validate_enables(enables) when is_list(enables), do: :ok
  defp validate_enables(_enables), do: {:error, :invalid_task_enables}

  defp validate_timeout(:infinity), do: :ok
  defp validate_timeout(timeout) when is_integer(timeout) and timeout >= 0, do: :ok
  defp validate_timeout(_timeout), do: {:error, :invalid_task_timeout}

  defp reject_duplicate_task_name(name, names) do
    if MapSet.member?(names, name) do
      {:error, :duplicate_task_name}
    else
      :ok
    end
  end
end
