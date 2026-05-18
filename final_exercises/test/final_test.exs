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

  test "tree inorder" do
    tree = Final.tree_insert(Final.tree_insert(Final.tree_insert(:tip, 2), 1), 3)
    assert Final.inorder(tree) == [1, 2, 3]
  end
end
