defmodule SPE.Job do
  # estructura que define el estado de un trabajo, con sus tareas, lista de tareas que dependen de la finalización de las anteriores y lista de tareas desbloqueadas por la finalizacion de otras
  defstruct id: nil, name: nil, tasks: %{}, dependencias: %{}, desbloqueos: %{}
  # funcion para construir un trabajo ya validado
  def from_description(job_id, %{"name" => name, "tasks" => task_list}) do
    # paso tareas y desbloqueos a un map con el nombre para encontrarlas facilmente
    tasks = Map.new(task_list, fn t -> {t["name"], t} end)
    desbloqueos = Map.new(task_list, fn t -> {t["name"], Map.get(t, "desbloqueos", [])} end)
    # las tareas dependientes las extraigo de desbloqueos (indicados por una task) con funcion aux para luego la topological sort
    dependencias = obtener_dep(task_list)
    # comprobacion con with de que no hay nombres inventados ni ciclos en la topological short (las task deben foramr un grafo aciclico) con funciones aux
    with :ok <- combrobar_ciclos(tasks, dependencias, desbloqueos),
         :ok <- comprobar_nombres(desbloqueos, tasks) do
      job = %__MODULE__{
        id: job_id,
        name: name,
        tasks: tasks,
        dependencias: dependencias,
        desbloqueos: desbloqueos
      }
      {:ok, job} # si esta todo bien devuelve atomo ok y el job
    end
  end
  # funcion para obtener tareas sin dependencias y que por tanto, pueden empezar desde el principio
  def task_nodep(job) do
    Enum.filter(Map.keys(job.tasks), fn name -> job.dependencias[name] == []end)
  end
  # funcion para obtener tareas desbloqueadas al terminar otra
  def task_desbloq(job, fin_task, completedas_list) do
    # primero mira que tareas habilita la tarea que acaba de terminar
    sucesores = Map.get(job.desbloqueos , fin_task, [])
    # de esas, valen las que ya no tienen mas dependencias
    Enum.filter(sucesores, fn sucesor -> Enum.all?(job.dependencias[sucesor], fn dep -> dep in completedas_list end) end)
  end
  # aux para obtener dependencias
  defp obtener_dep(task_list) do
    # lista dependecias, comienza vacia
    deps_inicio = Map.new(task_list, fn t -> {t["name"], []} end)
    # se van añadiendo tareas a la lista como dependencia de sus sucesores graciass a la lista de desbloqueos
    Enum.reduce(task_list, deps_inicio, fn task, acc ->
      desbloqueos_list = Map.get(task, "desbloqueos", [])
      Enum.reduce(desbloqueos_list_list, acc, fn sucesor, acc2 ->
        Map.update(acc2, sucesor, [task["name"]], fn lista ->
          [task["name"] | lista]
        end)
      end)
    end)
  end
  # aux para realizar topoological sort, si se visitan todos lo nodos es bueno porque no habia ciclos
  defp combrobar_ciclos(tasks, dependencias, desbloqueos) do
    # el grado de cada nodo indica cuantas dependencias tiene
    grado = Map.new(tasks, fn {name, _} -> {name, length(dependencias[name])} end)
    # se empieza con los nodos que no tienen ninguna dependencia
    cola_inicio =
      grado
      |> Enum.filter(fn {_, g} -> g == 0 end)
      |> Enum.map(fn {name, _} -> name end)
      # llama funcion aux topological sort
    topologicalSort(cola_inicio, grado, desbloqueos, 0, map_size(tasks))
  end
  # aux topological sort, se reduce en uno el grado y al llegar a 0 se agrega a la cola
  defp topologicalSort([], _grado, _desbloqueos, visitados, total) do
    # si visita todos los nodos, el grafo es un DAG válido y manda ok
    if visitados == total do
      :ok
    else
    # si no, error
      {:error, :ciclo}
    end
  end
  defp topologicalSort([nodo | resto], grado, desbloqueos, visitados, total) do
    sucesores = Map.get(desbloqueos, nodo, [])
    # se reduce el grado de cada sucesor
    {nueva_cola, nuevo_grado} =
      Enum.reduce(sucesores, {resto, grado}, fn sucesor, {cola, g} ->
        nuevo_grado = Map.update!(g, sucesor, &(&1 - 1))
        # si llega a 0, lo agrega a la cola
        if nuevo_grado[sucesor] == 0 do
          {[sucesor | cola], nuevo_grado}
        else
          {cola, nuevo_grado}
        end
      end)
    # llamada recursiva despues de visitar un nodo
    kahn(nueva_cola, nuevo_grado, desbloqueos, visitados + 1, total)
  end
  # aux para comporbar que los nombres en desbloqueos son correctos
  defp comprobar_nombres(desbloqueos, tasks) do
    Enum.reduce_while(desbloqueos, :ok, fn {_src, targets}, :ok ->
      case Enum.find(targets, fn t -> not Map.has_key?(tasks, t) end) do
        nil -> {:cont, :ok}
        # en caso de haber un nombre erroneo manda error (busca en el map con haskey), si no todo ok
        bad -> {:halt, {:error, {:nombre_error, bad}}}
      end
    end)
  end
  
end

