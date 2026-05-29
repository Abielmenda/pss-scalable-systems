defmodule SPE.TaskRunner do
  require Logger
  # funcion para ejecutar una tarea asincronamente, al acabar envia mensaje a job runner
  def run(job_id, task, res, runner_pid) do
    task_name = task["name"]
    exec   = task["exec"]
    timeout   = Map.get(task, "timeout", :infinity)
    # porceso vigilante
    spawn(fn ->
      ejecutar_task(job_id, task_name, exec, res, timeout, runner_pid)
    end)
    # devuelve :ok sin bloquear al JobRunner
    :ok
  end
  # logica vigilante
  defp ejecutar_task(job_id, task_name, exec, res, timeout, runner_pid) do
    vigilante = self()

    # contrata un trabajador, le pasa vigilante para que le avise el resultado
    trabajador = spawn(fn -> notificar_inicio(job_id, task_name) # notificar el comienzo de tarea con aux
      # ejecucion de funcion con try para que las exepciones no maten proceso
      try do
        resultado = exec.(res)
        send(vigilante, {:resultado_ok, resultado})
      catch
        tipo, motivo ->
          send(vigilante, {:resultado_mal, tipo, motivo})
      end
    end)
    # monitorizacion al trabajador para detectar si muere de forma inesperada
    ref_monitor = Process.monitor(trabajador)
    # temporizador si procede
    ref_timer = crear_timer(timeout)
    # aux para recibir resultado y ver que hay que hacer
    recibir_resultado(job_id, task_name, trabajador, ref_monitor, ref_timer, runner_pid)
  end
  defp recibir_resultado(job_id, task_name, trabajador, ref_monitor, ref_timer, runner_pid) do
    receive do
      # caso tarea acaba bien
      {:resultado_ok, valor} ->
        cancelar_timer(ref_timer)
        # fin del monitor
        Process.demonitor(ref_monitor, [:flush])
        notificar_fin(job_id, task_name)
        # se informa a job runner de exito
        send(runner_pid, {:task_done, task_name, {:result, valor}})
      # caso excepcion en try
      {:resultado_mal, _tipo, motivo} ->
        cancelar_timer(ref_timer)
        Process.demonitor(ref_monitor, [:flush])
        notificar_fin(job_id, task_name)
        Logger.warning("[SPE] Tarea #{task_name} del job #{job_id} fallo: #{inspect(motivo)}")
        send(runner_pid, {:task_done, task_name, {:failed, {:crashed, motivo}}})
      # caso timeout
      :timeout_fired ->
        # hay que matar al trabajador con :kill
        Process.demonitor(ref_monitor, [:flush])
        Process.exit(trabajador, :kill)
        # limpia de mensajes del trabajador
        limpiar_msg(trabajador)
        notificar_fin(job_id, task_name)
        Logger.warning("[SPE] Tarea #{task_name} del job #{job_id} superó el timeout")
        send(runner_pid, {:task_done, task_name, {:failed, :timeout}})
      # caso muerte sin mensaje, el monitor avisa
      {:DOWN, ^ref_monitor, :process, ^trabajador, motivo} ->
        cancelar_timer(ref_timer)
        notificar_fin(job_id, task_name)
        Logger.warning("[SPE] Tarea #{task_name} del job #{job_id} fallo: #{inspect(motivo)}")
        send(runner_pid, {:task_done, task_name, {:failed, {:crashed, motivo}}})
    end
  end
  # aux crear el temporizador si hay timeout, o devuelve nil si no hace falta
  defp crear_timer(:infinity), do: nil
  defp crear_timer(ms) do
    Process.send_after(self(), :timeout_fired, ms)
  end
  # aux cancelar el temporizador si existe, no hace nada si es nil
  defp cancelar_timer(nil), do: :ok
  defp cancelar_timer(ref) do
    Process.cancel_timer(ref)
  end
  # aux para borrar mensajes de trabajador muerto, no vaya a ser que se procesen
  defp limpiar_msg(trabajador) do
    receive do
      {:resultado_ok, _}       -> :ok
      {:resultado_mal, tipo, motivo} -> :ok
      {:DOWN, _, :process, ^trabajador, _} -> :ok
    after
      0 -> :ok
    end
  end
  # aux aviso broadcast de inicio de tarea al PubSub
  defp notificar_inicio(job_id, task_name) do
    tiempo = :erlang.monotonic_time(:millisecond)
    Phoenix.PubSub.local_broadcast(
      SPE.PubSub,
      to_string(job_id),
      {:spe, tiempo, {job_id, :task_started, task_name}}
    )
  end
   # aux aviso broadcast de fin de tarea al PubSub
  defp notificar_fin(job_id, task_name) do
    tiempo = :erlang.monotonic_time(:millisecond)
    Phoenix.PubSub.local_broadcast(
      SPE.PubSub,
      to_string(job_id),
      {:spe, tiempo, {job_id, :task_terminated, task_name}}
    )
  end

end
