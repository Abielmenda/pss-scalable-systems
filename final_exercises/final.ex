defmodule Final do
  @moduledoc """
  Mandatory final exercises for Programming Scalable Systems.
  """

  # Exercise 1: transpose/1
  def transpose([]), do: []
  def transpose([[] | _]), do: []

  def transpose(matrix) do
    [Enum.map(matrix, &hd/1) | transpose(Enum.map(matrix, &tl/1))]
  end

  # Exercise 2: matrixprod/2
  def matrixprod(a, b) do
    bt = transpose(b)

    Enum.map(a, fn row ->
      Enum.map(bt, fn col -> dotprod(row, col) end)
    end)
  end

  defp dotprod(xs, ys) do
    xs
    |> Enum.zip(ys)
    |> Enum.map(fn {x, y} -> x * y end)
    |> Enum.sum()
  end

  # Exercise 3: tree_insert/2
  def tree_insert(:tip, value), do: {:node, :tip, value, :tip}

  def tree_insert({:node, left, value, right}, new_value) when new_value <= value do
    {:node, tree_insert(left, new_value), value, right}
  end

  def tree_insert({:node, left, value, right}, new_value) do
    {:node, left, value, tree_insert(right, new_value)}
  end

  # Exercise 4: inorder/1
  def inorder(:tip), do: []

  def inorder({:node, left, value, right}) do
    inorder(left) ++ [value] ++ inorder(right)
  end

  # Exercise 5: map_tree/2
  def map_tree(:tip, _fun), do: :tip

  def map_tree({:node, left, value, right}, fun) do
    {:node, map_tree(left, fun), fun.(value), map_tree(right, fun)}
  end

  defmodule GenBank do
    use GenServer

    def create_bank(name \\ nil) do
      options = if is_nil(name), do: [], else: [name: name]
      GenServer.start_link(__MODULE__, %{}, options)
    end

    def new_account(bank, account), do: GenServer.call(bank, {:new_account, account})
    def withdraw(bank, account, quantity), do: GenServer.call(bank, {:withdraw, account, quantity})
    def deposit(bank, account, quantity), do: GenServer.call(bank, {:deposit, account, quantity})
    def transfer(bank, from_account, to_account, quantity), do: GenServer.call(bank, {:transfer, from_account, to_account, quantity})
    def balance(bank, account), do: GenServer.call(bank, {:balance, account})

    @impl GenServer
    def init(state), do: {:ok, state}

    @impl GenServer
    def handle_call({:new_account, account}, _from, state) do
      if Map.has_key?(state, account), do: {:reply, false, state}, else: {:reply, true, Map.put(state, account, 0)}
    end

    def handle_call({:balance, account}, _from, state), do: {:reply, Map.get(state, account, 0), state}

    def handle_call({:deposit, account, quantity}, _from, state) do
      new_balance = Map.get(state, account, 0) + quantity
      {:reply, new_balance, Map.put(state, account, new_balance)}
    end

    def handle_call({:withdraw, account, quantity}, _from, state) do
      current = Map.get(state, account, 0)
      if quantity <= current, do: {:reply, quantity, Map.put(state, account, current - quantity)}, else: {:reply, 0, state}
    end

    def handle_call({:transfer, from_account, to_account, quantity}, _from, state) do
      from_balance = Map.get(state, from_account, 0)
      if quantity <= from_balance do
        new_state = state |> Map.put(from_account, from_balance - quantity) |> Map.put(to_account, Map.get(state, to_account, 0) + quantity)
        {:reply, quantity, new_state}
      else
        {:reply, 0, state}
      end
    end
  end

  defmodule SuperBank do
    use Supervisor

    def create_bank(name) when is_atom(name), do: Supervisor.start_link(__MODULE__, name)

    @impl Supervisor
    def init(name) do
      children = [%{id: Final.GenBank, start: {Final.GenBank, :create_bank, [name]}, restart: :permanent, type: :worker}]
      Supervisor.init(children, strategy: :one_for_one)
    end
  end
end
