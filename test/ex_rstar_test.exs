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
    ExRstar.insert(tree, +0.0, +0.0, :origin)
    ExRstar.insert(tree, 10.0, 10.0, :far)

    assert {:ok, {+0.0, +0.0, :origin}} = ExRstar.nearest_neighbor(tree, 1.0, 1.0)
  end

  test "nearest_neighbor on empty tree" do
    tree = ExRstar.new()
    assert {:error, :not_found} = ExRstar.nearest_neighbor(tree, 0.0, 0.0)
  end

  test "nearest_neighbors returns sorted results" do
    tree = ExRstar.new()
    ExRstar.insert(tree, +0.0, +0.0, :a)
    ExRstar.insert(tree, 5.0, 5.0, :b)
    ExRstar.insert(tree, 10.0, 10.0, :c)

    results = ExRstar.nearest_neighbors(tree, 0.0, 0.0, 2)
    assert length(results) == 2
    [{_, _, data1, _}, {_, _, data2, _}] = results
    assert data1 == :a
    assert data2 == :b
  end

  test "nearest_neighbors on empty tree returns empty list" do
    tree = ExRstar.new()
    assert [] = ExRstar.nearest_neighbors(tree, 0.0, 0.0, 5)
  end

  test "nearest_neighbors count exceeds tree size returns all points" do
    tree =
      ExRstar.bulk_load([
        {1.0, 1.0, :a},
        {2.0, 2.0, :b},
        {3.0, 3.0, :c}
      ])

    results = ExRstar.nearest_neighbors(tree, 0.0, 0.0, 10)
    assert length(results) == 3
  end

  test "bulk_load" do
    points = for i <- 1..100, do: {i / 1.0, i / 1.0, "point_#{i}"}
    tree = ExRstar.bulk_load(points)
    assert ExRstar.size(tree) == 100
  end

  test "bulk_load with {x, y} tuples (no data)" do
    points = [{1.0, 2.0}, {3.0, 4.0}, {5.0, 6.0}]
    tree = ExRstar.bulk_load(points)
    assert ExRstar.size(tree) == 3

    assert {:ok, {1.0, 2.0, nil}} = ExRstar.nearest_neighbor(tree, 1.0, 2.0)
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

  test "locate_in_envelope_intersecting" do
    tree =
      ExRstar.bulk_load([
        {1.0, 1.0, :inside},
        {3.0, 3.0, :boundary},
        {5.0, 5.0, :outside}
      ])

    results = ExRstar.locate_in_envelope_intersecting(tree, {0.0, 0.0}, {3.0, 3.0})
    data = Enum.map(results, fn {_, _, d} -> d end) |> Enum.sort()
    assert :inside in data
    assert :boundary in data
    refute :outside in data
  end

  test "locate_within_distance" do
    tree =
      ExRstar.bulk_load([
        {+0.0, +0.0, :close},
        {1.0, +0.0, :mid},
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
        {+0.0, +0.0, :a},
        {1.0, +0.0, :b},
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

  # --- Data encoding edge cases ---

  test "stores and retrieves map data" do
    tree = ExRstar.new()
    data = %{name: "cafe", rating: 4.5, tags: ["coffee", "wifi"]}
    ExRstar.insert(tree, 1.0, 2.0, data)

    assert {:ok, {1.0, 2.0, ^data}} = ExRstar.nearest_neighbor(tree, 1.0, 2.0)
  end

  test "stores and retrieves nested struct-like data" do
    tree = ExRstar.new()
    data = %{address: %{street: "123 Main", city: "Portland"}, id: 42}
    ExRstar.insert(tree, 3.0, 4.0, data)

    assert {:ok, {3.0, 4.0, ^data}} = ExRstar.nearest_neighbor(tree, 3.0, 4.0)
  end

  test "stores and retrieves large binary data" do
    tree = ExRstar.new()
    data = :crypto.strong_rand_bytes(4096)
    ExRstar.insert(tree, 1.0, 1.0, data)

    assert {:ok, {1.0, 1.0, ^data}} = ExRstar.nearest_neighbor(tree, 1.0, 1.0)
  end

  test "stores and retrieves tuple data" do
    tree = ExRstar.new()
    data = {:point_meta, 42, "label"}
    ExRstar.insert(tree, 2.0, 3.0, data)

    assert {:ok, {2.0, 3.0, ^data}} = ExRstar.nearest_neighbor(tree, 2.0, 3.0)
  end

  # --- Integer coercion ---

  test "insert and query with integer coordinates" do
    tree = ExRstar.new()
    ExRstar.insert(tree, 3, 4, :int_point)

    assert {:ok, {3.0, 4.0, :int_point}} = ExRstar.nearest_neighbor(tree, 3, 4)
  end

  test "bulk_load with integer coordinates" do
    points = [{1, 2, :a}, {3, 4, :b}]
    tree = ExRstar.bulk_load(points)
    assert ExRstar.size(tree) == 2

    assert {:ok, {1.0, 2.0, :a}} = ExRstar.nearest_neighbor(tree, 1, 2)
  end

  # --- Negative coordinates ---

  test "negative coordinates work correctly" do
    tree =
      ExRstar.bulk_load([
        {-5.0, -5.0, :neg},
        {5.0, 5.0, :pos},
        {-1.0, 1.0, :mixed}
      ])

    assert {:ok, {-5.0, -5.0, :neg}} = ExRstar.nearest_neighbor(tree, -4.0, -4.0)
    assert {:ok, {5.0, 5.0, :pos}} = ExRstar.nearest_neighbor(tree, 6.0, 6.0)
  end

  test "locate_in_envelope with negative coordinates" do
    tree =
      ExRstar.bulk_load([
        {-3.0, -3.0, :a},
        {-1.0, -1.0, :b},
        {1.0, 1.0, :c}
      ])

    results = ExRstar.locate_in_envelope(tree, {-4.0, -4.0}, {-0.5, -0.5})
    data = Enum.map(results, fn {_, _, d} -> d end) |> Enum.sort()
    assert data == [:a, :b]
  end

  test "locate_within_distance with negative origin" do
    tree =
      ExRstar.bulk_load([
        {-1.0, -1.0, :near},
        {10.0, 10.0, :far}
      ])

    results = ExRstar.locate_within_distance(tree, -1.0, -1.0, 1.0)
    assert length(results) == 1
    [{_, _, data}] = results
    assert data == :near
  end

  # --- Concurrent access ---

  test "concurrent inserts do not crash" do
    tree = ExRstar.new()

    tasks =
      for i <- 1..100 do
        Task.async(fn ->
          ExRstar.insert(tree, i / 1.0, i / 1.0, :"point_#{i}")
        end)
      end

    Task.await_many(tasks)
    assert ExRstar.size(tree) == 100
  end

  test "concurrent reads and writes do not crash" do
    tree = ExRstar.bulk_load(for i <- 1..50, do: {i / 1.0, i / 1.0, :"init_#{i}"})

    writers =
      for i <- 51..100 do
        Task.async(fn ->
          ExRstar.insert(tree, i / 1.0, i / 1.0, :"write_#{i}")
        end)
      end

    readers =
      for _ <- 1..50 do
        Task.async(fn ->
          ExRstar.nearest_neighbor(tree, 25.0, 25.0)
        end)
      end

    Task.await_many(writers ++ readers)
    assert ExRstar.size(tree) == 100
  end
end
