defmodule ExRstarTest do
  use ExUnit.Case

  test "new tree has size 0" do
    tree = ExRstar.new()
    assert ExRstar.size(tree) == 0
  end

  test "insert and size" do
    tree = ExRstar.new()
    ExRstar.insert(tree, 1.0, 2.0)
    ExRstar.insert(tree, 3.0, 4.0)
    assert ExRstar.size(tree) == 2
  end

  test "insert with data and nearest_neighbor" do
    tree = ExRstar.new()
    ExRstar.insert(tree, 0.0, 0.0, :origin)
    ExRstar.insert(tree, 10.0, 10.0, :far)

    assert {:ok, {0.0, 0.0, :origin}} = ExRstar.nearest_neighbor(tree, 1.0, 1.0)
  end

  test "nearest_neighbor on empty tree" do
    tree = ExRstar.new()
    assert {:error, :not_found} = ExRstar.nearest_neighbor(tree, 0.0, 0.0)
  end

  test "nearest_neighbors returns sorted results" do
    tree = ExRstar.new()
    ExRstar.insert(tree, 0.0, 0.0, :a)
    ExRstar.insert(tree, 5.0, 5.0, :b)
    ExRstar.insert(tree, 10.0, 10.0, :c)

    results = ExRstar.nearest_neighbors(tree, 0.0, 0.0, 2)
    assert length(results) == 2
    [{_, _, data1, _}, {_, _, data2, _}] = results
    assert data1 == :a
    assert data2 == :b
  end

  test "bulk_load" do
    points = for i <- 1..100, do: {i / 1.0, i / 1.0, "point_#{i}"}
    tree = ExRstar.bulk_load(points)
    assert ExRstar.size(tree) == 100
  end

  test "locate_in_envelope" do
    tree =
      ExRstar.bulk_load([
        {1.0, 1.0, :a},
        {2.0, 2.0, :b},
        {5.0, 5.0, :c},
        {10.0, 10.0, :d}
      ])

    results = ExRstar.locate_in_envelope(tree, {0.0, 0.0}, {3.0, 3.0})
    assert length(results) == 2
    data = Enum.map(results, fn {_, _, d} -> d end) |> Enum.sort()
    assert data == [:a, :b]
  end

  test "locate_within_distance" do
    tree =
      ExRstar.bulk_load([
        {0.0, 0.0, :close},
        {1.0, 0.0, :mid},
        {100.0, 100.0, :far}
      ])

    # squared distance of 2.0 => radius ~1.41
    results = ExRstar.locate_within_distance(tree, 0.0, 0.0, 2.0)
    data = Enum.map(results, fn {_, _, d} -> d end) |> Enum.sort()
    assert data == [:close, :mid]
  end

  test "locate_at_point" do
    tree = ExRstar.new()
    ExRstar.insert(tree, 3.0, 4.0, :target)

    assert {:ok, {3.0, 4.0, :target}} = ExRstar.locate_at_point(tree, 3.0, 4.0)
    assert {:error, :not_found} = ExRstar.locate_at_point(tree, 0.0, 0.0)
  end

  test "remove" do
    tree = ExRstar.new()
    ExRstar.insert(tree, 1.0, 2.0, :a)
    assert ExRstar.size(tree) == 1

    assert {:ok, true} = ExRstar.remove(tree, 1.0, 2.0)
    assert ExRstar.size(tree) == 0

    assert {:ok, false} = ExRstar.remove(tree, 1.0, 2.0)
  end

  test "drain_within_distance removes and returns points" do
    tree =
      ExRstar.bulk_load([
        {0.0, 0.0, :a},
        {1.0, 0.0, :b},
        {100.0, 100.0, :c}
      ])

    drained = ExRstar.drain_within_distance(tree, 0.0, 0.0, 2.0)
    assert length(drained) == 2
    assert ExRstar.size(tree) == 1
  end

  test "insert without data stores nil" do
    tree = ExRstar.new()
    ExRstar.insert(tree, 5.0, 5.0)
    assert {:ok, {5.0, 5.0, nil}} = ExRstar.nearest_neighbor(tree, 5.0, 5.0)
  end
end
