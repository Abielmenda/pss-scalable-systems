defmodule SPETest do
  use ExUnit.Case

  setup do
    on_exit(fn ->
      case SPE.stop() do
        :ok -> :ok
        {:error, :not_started} -> :ok
      end
    end)

    :ok
  end

  test "starts and stops SPE" do
    assert {:ok, _pid} = SPE.start_link()
    assert :ok = SPE.stop()
  end

  test "submit of a valid job returns job id" do
    start_spe!()

    assert {:ok, job_id} = SPE.submit_job(valid_job())
    assert is_integer(job_id)
  end

  test "submit of an invalid job returns error" do
    start_spe!()

    assert {:error, :invalid_job_description} = SPE.submit_job(%{})
  end

  test "start_job with unknown job returns error" do
    start_spe!()

    assert {:error, :unknown_job} = SPE.start_job(999)
  end

  test "start_job with a valid job returns job id" do
    start_spe!()
    {:ok, job_id} = SPE.submit_job(valid_job())

    assert {:ok, ^job_id} = SPE.start_job(job_id)
  end

  test "start_job twice returns already started" do
    start_spe!()
    {:ok, job_id} = SPE.submit_job(valid_job())

    assert {:ok, ^job_id} = SPE.start_job(job_id)
    assert {:error, :already_started} = SPE.start_job(job_id)
  end

  defp start_spe! do
    assert {:ok, _pid} = SPE.start_link()
  end

  defp valid_job do
    %{
      "name" => "example",
      "tasks" => [
        %{
          "name" => "task-1",
          "exec" => fn input -> input end
        }
      ]
    }
  end
end
