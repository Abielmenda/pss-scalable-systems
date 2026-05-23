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
      GenServer.start_link(__MODULE__, name, options)
    end

    def new_account(bank, account), do: GenServer.call(bank, {:new_account, account})
    def withdraw(bank, account, quantity), do: GenServer.call(bank, {:withdraw, account, quantity})
    def deposit(bank, account, quantity), do: GenServer.call(bank, {:deposit, account, quantity})

    def transfer(bank, from_account, to_account, quantity) do
      GenServer.call(bank, {:transfer, from_account, to_account, quantity})
    end

    def balance(bank, account), do: GenServer.call(bank, {:balance, account})

    @impl GenServer
    def init(nil) do
      {:ok, %{accounts: %{}, name: nil}}
    end

    def init(name) when is_atom(name) do
      {:ok, %{accounts: read_accounts(name), name: name}}
    end

    @impl GenServer
    def handle_call({:new_account, account}, _from, state) do
      if Map.has_key?(state.accounts, account) do
        {:reply, false, state}
      else
        new_state = %{state | accounts: Map.put(state.accounts, account, 0)} |> persist()
        {:reply, true, new_state}
      end
    end

    def handle_call({:balance, account}, _from, state) do
      {:reply, Map.get(state.accounts, account, 0), state}
    end

    def handle_call({:deposit, account, quantity}, _from, state) do
      new_balance = Map.get(state.accounts, account, 0) + quantity
      new_state = %{state | accounts: Map.put(state.accounts, account, new_balance)} |> persist()
      {:reply, new_balance, new_state}
    end

    def handle_call({:withdraw, account, quantity}, _from, state) do
      current = Map.get(state.accounts, account, 0)

      if quantity <= current do
        new_state = %{state | accounts: Map.put(state.accounts, account, current - quantity)} |> persist()
        {:reply, quantity, new_state}
      else
        {:reply, 0, state}
      end
    end

    def handle_call({:transfer, from_account, to_account, quantity}, _from, state) do
      from_balance = Map.get(state.accounts, from_account, 0)

      if quantity <= from_balance do
        new_accounts =
          state.accounts
          |> Map.put(from_account, from_balance - quantity)
          |> Map.put(to_account, Map.get(state.accounts, to_account, 0) + quantity)

        new_state = %{state | accounts: new_accounts} |> persist()
        {:reply, quantity, new_state}
      else
        {:reply, 0, state}
      end
    end

    defp persist(%{name: nil} = state), do: state

    defp persist(%{name: name, accounts: accounts} = state) do
      write_accounts(name, accounts)
      state
    end

    defp read_accounts(name) do
      with_dets(name, fn table ->
        case :dets.lookup(table, :accounts) do
          [{:accounts, saved_accounts}] -> saved_accounts
          [] -> %{}
        end
      end)
    end

    defp write_accounts(name, accounts) do
      with_dets(name, fn table ->
        :ok = :dets.insert(table, {:accounts, accounts})
        :ok = :dets.sync(table)
      end)
    end

    defp with_dets(name, fun) do
      table = dets_table(name)
      file = dets_file(name)
      {:ok, ^table} = :dets.open_file(table, file: String.to_charlist(file), type: :set)

      try do
        fun.(table)
      after
        :dets.close(table)
      end
    end

    defp dets_table(name) do
      String.to_atom("#{name}_accounts_#{System.unique_integer([:positive])}")
    end

    defp dets_file(name), do: "#{name}.dets"
  end

  defmodule SuperBank do
    use Supervisor

    def create_bank(name) when is_atom(name), do: Supervisor.start_link(__MODULE__, name)

    @impl Supervisor
    def init(name) do
      children = [
        %{
          id: Final.GenBank,
          start: {Final.GenBank, :create_bank, [name]},
          restart: :permanent,
          type: :worker
        }
      ]

      Supervisor.init(children, strategy: :one_for_one)
    end
  end
end
