defmodule SPE.JobRunner do
  use GenServer
  require Logger
  alias SPE.{Job, TaskRunner}
  # estructura para el estado del jobrunner con resultados de las tareas, tareas ejecutando, listas, esperando o completadas
  defstruct job: nil,
            server_pid: nil,
            results: %{},
            running: %{},
            ready: [],
            waiting: %{},
            completadas: []
  def start_link(options \\ []) do
    GenServer.start_link(__MODULE__, options)
  end

  @impl true
  def init(options) do
    job = Keyword.fetch!(options, :job)
    server_pid = Keyword.fetch!(options, :server_pid)
    # empiezan las tareas sin dependencias
    listas_inicio = Job.task_nodep(job)
    # las que tienen esperan
    esperando_inicio = dep_waiting(job)
    state = %__MODULE__{
      job: job,
      server_pid: server_pid,
      ready: listas_inicio,
      waiting: esperando_inicio
    }
    # peticion de los slots para las tareas iniciales
    send(self(), :pedir_slots_iniciales)

    {:ok, state}
  end
  # se pide al Server un slot por cada tarea lista para ejecutar
  @impl true
  def handle_info(:pedir_slots_iniciales, state) do
    pedir_slots(length(state.ready), state.server_pid)
    {:noreply, state}
  end
  # si Server nos ha concedido un slot, se ejecuta la primera tarea de la cola
  def handle_info({:slot_granted, ref}, state) do
    case state.ready do
      [] ->
        # en caso de no tener tareas esperando slot, se devuelve
        send(state.server_pid, {:release_slot, ref})
        {:noreply, state}
      [nombre | resto] ->
        tarea = state.job.tasks[nombre]
        # resultados de sus dependencias para pasarlos a exec
        resultados_deps = recoger_resultados_deps(nombre, state)
        Logger.debug("[SPE] Job #{state.job.id} — lanzando tarea: #{nombre}")
        TaskRunner.run(state.job.id, tarea, resultados_deps, self())
        nuevo_state = %{state |
          ready:   resto,
          running: Map.put(state.running, nombre, ref)
        }
        {:noreply, nuevo_state}
    end
  end
  # tarea terminada, avisa el task runner
  def handle_info({:task_done, nombre, resultado}, state) do
    Logger.debug("[SPE] Job #{state.job.id} — tarea #{nombre} terminó: #{inspect(resultado)}")
    # se libeera el slot que usaba esta tarea
    {ref, nuevo_running} = Map.pop(state.running, nombre)
    if ref != nil, do: send(state.server_pid, {:release_slot, ref})
    # resultado tarea
    nuevo_results = Map.put(state.results, nombre, resultado)
    state_actualizado = %{state | results: nuevo_results, running: nuevo_running}
    nuevo_state =
      case resultado do
        {:result, _} ->
          # las tarea termino con exito, hay que desbloquear las tareas que dependian de esta
          procesar_tarea_exito(nombre, state_actualizado)

        _ ->
          # hay fallo, marcar como :not_run todo lo que dependia de esta tarea
          procesar_tarea_fail(nombre, state_actualizado)
      end

    # si no quedan tareas ni ejecutándose, ni listas, ni esperando, el trabajo termina
    if job_terminado?(nuevo_state) do
      publicar_resultado_final(nuevo_state)
    end

    {:noreply, nuevo_state}
  end
  defp procesar_tarea_exito(nombre, state) do
    # se añade a la lista de completadas
    nuevas_completadas = [nombre | state.completadas]
    # hay que calcular tareas que se desbloquean ahora que esta ha terminado
    recien_desbloqueadas = Job.task_desbloq(state.job, nombre, nuevas_completadas)
    # pasan de waiting a ready
    nuevo_waiting = Map.drop(state.waiting, recien_desbloqueadas)
    nuevo_ready   = state.ready ++ recien_desbloqueadas
    # hay que pedir un slot por cada tarea recién desbloqueada
    pedir_slots(length(recien_desbloqueadas), state.server_pid)
    %{state |
      completadas: nuevas_completadas,
      waiting:     nuevo_waiting,
      ready:       nuevo_ready
    }
  end
  defp procesar_tarea_fail(nombre, state) do
    # hay que buscar todas los que dependen de esta tarea
    bloqueadas = buscar_dependientes_trans(state.job, nombre)
    # se eliminan del mapa de espera porque nunca podrán ejecutarse
    nuevo_waiting = Map.drop(state.waiting, bloqueadas)
    # marcadas como :not_run en los resultados
    not_run_map = Map.new(bloqueadas, fn nombre_bloqueada ->
      {nombre_bloqueada, :not_run}
    end)
    nuevo_results = Map.merge(state.results, not_run_map)
    %{state | waiting: nuevo_waiting, results: nuevo_results}
  end
  # aux para tareas que esperan al principio
  defp dep_waiting(job) do
    job.dependencias
    |> Enum.reject(fn {_nombre, deps} -> deps == [] end)
    |> Map.new()
  end
  # aux para enviar peticiones de slot al Server (una por tarea que queremos ejecutar)
  defp pedir_slots(0, _server_pid), do: :ok
  defp pedir_slots(n, server_pid) do
    send(server_pid, {:request_slot, self()})
    pedir_slots(n - 1, server_pid)
  end
  # aux para coger resultados de dependecias de tarea para ejecutar
  defp recoger_resultados_deps(nombre_tarea, state) do
    deps_transitivas = all_deps(state.job, nombre_tarea)
    Enum.reduce(deps_transitivas, %{}, fn dep, acc ->
      case Map.get(state.results, dep) do
        # solo se incluyen las deps que terminaron con éxito
        {:result, valor} -> Map.put(acc, dep, valor)
        _  -> acc
      end
    end)
  end
  # aux para buscar en el grafo todas las dependencias
  defp all_deps(job, nombre_tarea) do
    buscar_deps(job.dependencias, [nombre_tarea], [])
    |> Enum.reject(fn d -> d == nombre_tarea end)
  end
  # busco las dependencias por medio de busqueda en anchura en el grafo
  defp buscar_deps(_deps, [], visitados), do: visitados
  defp buscar_deps(deps, [actual | resto], visitados) do
    if actual in visitados do
      # nodo visitado se salta
      buscar_deps(deps, resto, visitados)
    else
      vecinos = Map.get(deps, actual, [])
      buscar_deps(deps, resto ++ vecinos, [actual | visitados])
    end
  end
  # aux para buscar depencias transitivas para tarea fallida
  defp dependientes_transitivos(job, nombre_fallida) do
    sucesores_directos = Map.get(job.desbloqueos, nombre_fallida, [])
    busqueda_desbloqueos(job.desbloqueos, sucesores_directos, [])
  end
  defp busqueda_desbloqueos(_desbloqueos, [], visitados), do: visitados
  defp busqueda_desbloqueos(desbloqueos, [actual | resto], visitados) do
    if actual in visitados do
      busqueda_desbloqueos(desbloqueos, resto, visitados)
    else
      hijos = Map.get(enables, actual, [])
      busqueda_desbloqueos(desbloqueos, resto ++ hijos, [actual | visitados])
    end
  end
  # aux para comprobar que el job ha terminado, cuando no hay nada ejecutando, listo, ni esperando
  defp job_terminado?(state) do
    map_size(state.running) == 0 and state.ready == [] and map_size(state.waiting) == 0
  end
  # publicacion del resultado final en el pubsub
  defp publicar_resultado_final(state) do
    job_id = state.job.id
    tiempo = :erlang.monotonic_time(:millisecond)
    # job falla si alguna tarea devolvió {:failed, _}
    hay_fallo = Enum.any?(state.results, fn {_nombre, resultado} ->
      case resultado do
        {:failed, _} -> true
        _            -> false
      end
    end)
    status = if hay_fallo, do: :failed, else: :succeeded
    Phoenix.PubSub.local_broadcast(
      SPE.PubSub,
      to_string(job_id),
      {:spe, tiempo, {job_id, :result, {status, state.results}}}
    )
    Logger.info("[SPE] Job #{job_id} finalizado — estado: #{status}")
  end
end

