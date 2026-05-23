ExUnit.start()
Code.require_file("../final.ex", __DIR__)

defmodule FinalTest do
  use ExUnit.Case

  test "transpose" do
    assert Final.transpose([[1, 2], [3, 4]]) == [[1, 3], [2, 4]]
  end

  test "matrix product" do
    assert Final.matrixprod([[1.0, 2.0]], [[3.0], [4.0]]) == [[11.0]]
  end

  test "tree insert and inorder" do
    tree = Final.tree_insert(Final.tree_insert(Final.tree_insert(:tip, 2), 1), 3)
    assert Final.inorder(tree) == [1, 2, 3]
  end

  test "map tree" do
    tree = Final.tree_insert(Final.tree_insert(Final.tree_insert(:tip, 2), 1), 3)

    assert Final.map_tree(tree, fn value -> value * 2 end) ==
             {:node, {:node, :tip, 2, :tip}, 4, {:node, :tip, 6, :tip}}
  end

  test "genbank api" do
    {:ok, bank} = Final.GenBank.create_bank()

    assert Final.GenBank.new_account(bank, 1) == true
    assert Final.GenBank.new_account(bank, 1) == false
    assert Final.GenBank.balance(bank, 1) == 0
    assert Final.GenBank.deposit(bank, 1, 10) == 10
    assert Final.GenBank.withdraw(bank, 1, 3) == 3
    assert Final.GenBank.balance(bank, 1) == 7

    assert Final.GenBank.new_account(bank, 2) == true
    assert Final.GenBank.transfer(bank, 1, 2, 5) == 5
    assert Final.GenBank.balance(bank, 1) == 2
    assert Final.GenBank.balance(bank, 2) == 5
  end

  test "superbank restarts bank and restores account balances" do
    bank_name = String.to_atom("test_bank_#{System.unique_integer([:positive])}")
    File.rm("#{bank_name}.dets")

    {:ok, supervisor} = Final.SuperBank.create_bank(bank_name)

    assert Final.GenBank.new_account(bank_name, 1) == true
    assert Final.GenBank.deposit(bank_name, 1, 10) == 10

    Process.exit(Process.whereis(bank_name), :kill)
    wait_until(fn -> Process.whereis(bank_name) != nil end)

    assert Process.alive?(supervisor)
    assert Final.GenBank.balance(bank_name, 1) == 10

    Supervisor.stop(supervisor)
    File.rm("#{bank_name}.dets")
  end

  defp wait_until(fun, attempts \\ 20)
  defp wait_until(_fun, 0), do: flunk("condition was not met in time")

  defp wait_until(fun, attempts) do
    if fun.() do
      :ok
    else
      Process.sleep(50)
      wait_until(fun, attempts - 1)
    end
  end
end
