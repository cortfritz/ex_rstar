defmodule ExRstarTest do
  use ExUnit.Case

  # ===========================================================================
  # Construction & Size
  # ===========================================================================

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

  test "bulk_load empty list" do
    tree = ExRstar.bulk_load([])
    assert ExRstar.size(tree) == 0
  end

  # ===========================================================================
  # Insert / Remove
  # ===========================================================================

  test "insert with data and nearest_neighbor" do
    tree = ExRstar.new()
    ExRstar.insert(tree, +0.0, +0.0, :origin)
    ExRstar.insert(tree, 10.0, 10.0, :far)
    assert {:ok, {+0.0, +0.0, :origin}} = ExRstar.nearest_neighbor(tree, 1.0, 1.0)
  end

  test "insert without data stores nil" do
    tree = ExRstar.new()
    ExRstar.insert(tree, 5.0, 5.0)
    assert {:ok, {5.0, 5.0, nil}} = ExRstar.nearest_neighbor(tree, 5.0, 5.0)
  end

  test "remove" do
    tree = ExRstar.new()
    ExRstar.insert(tree, 1.0, 2.0, :a)
    assert ExRstar.size(tree) == 1

    assert {:ok, true} = ExRstar.remove(tree, 1.0, 2.0)
    assert ExRstar.size(tree) == 0

    assert {:ok, false} = ExRstar.remove(tree, 1.0, 2.0)
  end

  # ===========================================================================
  # contains?
  # ===========================================================================

  test "contains? returns true for existing point" do
    tree = ExRstar.new()
    ExRstar.insert(tree, 3.0, 4.0, :target)
    assert ExRstar.contains?(tree, 3.0, 4.0) == true
  end

  test "contains? returns false for missing point" do
    tree = ExRstar.new()
    ExRstar.insert(tree, 3.0, 4.0)
    assert ExRstar.contains?(tree, 99.0, 99.0) == false
  end

  test "contains? on empty tree" do
    tree = ExRstar.new()
    assert ExRstar.contains?(tree, 0.0, 0.0) == false
  end

  test "contains? after remove" do
    tree = ExRstar.new()
    ExRstar.insert(tree, 1.0, 2.0)
    assert ExRstar.contains?(tree, 1.0, 2.0) == true
    ExRstar.remove(tree, 1.0, 2.0)
    assert ExRstar.contains?(tree, 1.0, 2.0) == false
  end

  # ===========================================================================
  # Nearest Neighbor
  # ===========================================================================

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
    tree = ExRstar.bulk_load([{1.0, 1.0, :a}, {2.0, 2.0, :b}, {3.0, 3.0, :c}])
    results = ExRstar.nearest_neighbors(tree, 0.0, 0.0, 10)
    assert length(results) == 3
  end

  test "nearest_neighbors returns correct squared distances" do
    tree = ExRstar.bulk_load([{3.0, 4.0, :a}])
    [{_, _, _, dist2}] = ExRstar.nearest_neighbors(tree, 0.0, 0.0, 1)
    assert dist2 == 25.0
  end

  # ===========================================================================
  # pop_nearest_neighbor
  # ===========================================================================

  test "pop_nearest_neighbor removes and returns closest point" do
    tree = ExRstar.bulk_load([{1.0, 1.0, :a}, {5.0, 5.0, :b}, {10.0, 10.0, :c}])
    assert ExRstar.size(tree) == 3

    assert {:ok, {1.0, 1.0, :a}} = ExRstar.pop_nearest_neighbor(tree, 0.0, 0.0)
    assert ExRstar.size(tree) == 2

    assert {:ok, {5.0, 5.0, :b}} = ExRstar.pop_nearest_neighbor(tree, 0.0, 0.0)
    assert ExRstar.size(tree) == 1

    assert {:ok, {10.0, 10.0, :c}} = ExRstar.pop_nearest_neighbor(tree, 0.0, 0.0)
    assert ExRstar.size(tree) == 0
  end

  test "pop_nearest_neighbor on empty tree" do
    tree = ExRstar.new()
    assert {:error, :not_found} = ExRstar.pop_nearest_neighbor(tree, 0.0, 0.0)
  end

  test "pop_nearest_neighbor drains tree one at a time" do
    tree = ExRstar.bulk_load(for i <- 1..10, do: {i / 1.0, 0.0, i})

    for _ <- 1..10 do
      assert {:ok, _} = ExRstar.pop_nearest_neighbor(tree, 0.0, 0.0)
    end

    assert ExRstar.size(tree) == 0
    assert {:error, :not_found} = ExRstar.pop_nearest_neighbor(tree, 0.0, 0.0)
  end

  # ===========================================================================
  # locate_all_at_point
  # ===========================================================================

  test "locate_all_at_point returns all overlapping points" do
    tree = ExRstar.new()
    ExRstar.insert(tree, 1.0, 2.0, :first)
    ExRstar.insert(tree, 1.0, 2.0, :second)
    ExRstar.insert(tree, 1.0, 2.0, :third)
    ExRstar.insert(tree, 5.0, 5.0, :elsewhere)

    results = ExRstar.locate_all_at_point(tree, 1.0, 2.0)
    assert length(results) == 3
    data = Enum.map(results, fn {_, _, d} -> d end) |> Enum.sort()
    assert data == [:first, :second, :third]
  end

  test "locate_all_at_point returns empty list for missing point" do
    tree = ExRstar.new()
    ExRstar.insert(tree, 1.0, 2.0, :a)
    assert [] = ExRstar.locate_all_at_point(tree, 99.0, 99.0)
  end

  test "locate_all_at_point on empty tree" do
    tree = ExRstar.new()
    assert [] = ExRstar.locate_all_at_point(tree, 0.0, 0.0)
  end

  # ===========================================================================
  # Envelope Queries
  # ===========================================================================

  test "locate_in_envelope" do
    tree =
      ExRstar.bulk_load([{1.0, 1.0, :a}, {2.0, 2.0, :b}, {5.0, 5.0, :c}, {10.0, 10.0, :d}])

    results = ExRstar.locate_in_envelope(tree, {0.0, 0.0}, {3.0, 3.0})
    assert length(results) == 2
    data = Enum.map(results, fn {_, _, d} -> d end) |> Enum.sort()
    assert data == [:a, :b]
  end

  test "locate_in_envelope_intersecting" do
    tree = ExRstar.bulk_load([{1.0, 1.0, :inside}, {3.0, 3.0, :boundary}, {5.0, 5.0, :outside}])

    results = ExRstar.locate_in_envelope_intersecting(tree, {0.0, 0.0}, {3.0, 3.0})
    data = Enum.map(results, fn {_, _, d} -> d end) |> Enum.sort()
    assert :inside in data
    assert :boundary in data
    refute :outside in data
  end

  test "locate_in_envelope returns empty for non-overlapping region" do
    tree = ExRstar.bulk_load([{10.0, 10.0, :far}])
    assert [] = ExRstar.locate_in_envelope(tree, {0.0, 0.0}, {1.0, 1.0})
  end

  # ===========================================================================
  # Distance Queries
  # ===========================================================================

  test "locate_within_distance" do
    tree = ExRstar.bulk_load([{+0.0, +0.0, :close}, {1.0, +0.0, :mid}, {100.0, 100.0, :far}])
    results = ExRstar.locate_within_distance(tree, 0.0, 0.0, 2.0)
    data = Enum.map(results, fn {_, _, d} -> d end) |> Enum.sort()
    assert data == [:close, :mid]
  end

  # ===========================================================================
  # Point Lookup
  # ===========================================================================

  test "locate_at_point" do
    tree = ExRstar.new()
    ExRstar.insert(tree, 3.0, 4.0, :target)
    assert {:ok, {3.0, 4.0, :target}} = ExRstar.locate_at_point(tree, 3.0, 4.0)
    assert {:error, :not_found} = ExRstar.locate_at_point(tree, 0.0, 0.0)
  end

  # ===========================================================================
  # drain_within_distance
  # ===========================================================================

  test "drain_within_distance removes and returns points" do
    tree = ExRstar.bulk_load([{+0.0, +0.0, :a}, {1.0, +0.0, :b}, {100.0, 100.0, :c}])
    drained = ExRstar.drain_within_distance(tree, 0.0, 0.0, 2.0)
    assert length(drained) == 2
    assert ExRstar.size(tree) == 1
  end

  # ===========================================================================
  # drain_in_envelope
  # ===========================================================================

  test "drain_in_envelope removes and returns contained points" do
    tree =
      ExRstar.bulk_load([{1.0, 1.0, :a}, {2.0, 2.0, :b}, {5.0, 5.0, :c}, {10.0, 10.0, :d}])

    drained = ExRstar.drain_in_envelope(tree, {0.0, 0.0}, {3.0, 3.0})
    assert length(drained) == 2
    data = Enum.map(drained, fn {_, _, d} -> d end) |> Enum.sort()
    assert data == [:a, :b]
    assert ExRstar.size(tree) == 2
  end

  test "drain_in_envelope on empty region returns empty" do
    tree = ExRstar.bulk_load([{10.0, 10.0, :far}])
    assert [] = ExRstar.drain_in_envelope(tree, {0.0, 0.0}, {1.0, 1.0})
    assert ExRstar.size(tree) == 1
  end

  test "drain_in_envelope_intersecting removes boundary points" do
    tree = ExRstar.bulk_load([{1.0, 1.0, :inside}, {3.0, 3.0, :boundary}, {5.0, 5.0, :outside}])

    drained = ExRstar.drain_in_envelope_intersecting(tree, {0.0, 0.0}, {3.0, 3.0})
    data = Enum.map(drained, fn {_, _, d} -> d end) |> Enum.sort()
    assert :inside in data
    assert :boundary in data
    refute :outside in data
    assert ExRstar.size(tree) == 1
  end

  # ===========================================================================
  # to_list
  # ===========================================================================

  test "to_list returns all points" do
    tree = ExRstar.bulk_load([{1.0, 2.0, :a}, {3.0, 4.0, :b}, {5.0, 6.0, :c}])
    result = ExRstar.to_list(tree)
    assert length(result) == 3
    data = Enum.map(result, fn {_, _, d} -> d end) |> Enum.sort()
    assert data == [:a, :b, :c]
  end

  test "to_list on empty tree" do
    tree = ExRstar.new()
    assert [] = ExRstar.to_list(tree)
  end

  test "to_list preserves coordinates" do
    tree = ExRstar.bulk_load([{42.5, -73.2, :albany}])
    [{x, y, :albany}] = ExRstar.to_list(tree)
    assert x == 42.5
    assert y == -73.2
  end

  # ===========================================================================
  # clear
  # ===========================================================================

  test "clear removes all points and returns count" do
    tree = ExRstar.bulk_load(for i <- 1..50, do: {i / 1.0, i / 1.0, i})
    assert ExRstar.size(tree) == 50

    removed = ExRstar.clear(tree)
    assert removed == 50
    assert ExRstar.size(tree) == 0
  end

  test "clear on empty tree returns 0" do
    tree = ExRstar.new()
    assert ExRstar.clear(tree) == 0
  end

  test "tree is usable after clear" do
    tree = ExRstar.bulk_load([{1.0, 2.0, :old}])
    ExRstar.clear(tree)
    ExRstar.insert(tree, 5.0, 6.0, :new)
    assert ExRstar.size(tree) == 1
    assert {:ok, {5.0, 6.0, :new}} = ExRstar.nearest_neighbor(tree, 5.0, 6.0)
  end

  # ===========================================================================
  # Data encoding edge cases
  # ===========================================================================

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

  # ===========================================================================
  # Integer coercion
  # ===========================================================================

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

  # ===========================================================================
  # Negative coordinates
  # ===========================================================================

  test "negative coordinates work correctly" do
    tree = ExRstar.bulk_load([{-5.0, -5.0, :neg}, {5.0, 5.0, :pos}, {-1.0, 1.0, :mixed}])
    assert {:ok, {-5.0, -5.0, :neg}} = ExRstar.nearest_neighbor(tree, -4.0, -4.0)
    assert {:ok, {5.0, 5.0, :pos}} = ExRstar.nearest_neighbor(tree, 6.0, 6.0)
  end

  test "locate_in_envelope with negative coordinates" do
    tree = ExRstar.bulk_load([{-3.0, -3.0, :a}, {-1.0, -1.0, :b}, {1.0, 1.0, :c}])
    results = ExRstar.locate_in_envelope(tree, {-4.0, -4.0}, {-0.5, -0.5})
    data = Enum.map(results, fn {_, _, d} -> d end) |> Enum.sort()
    assert data == [:a, :b]
  end

  test "locate_within_distance with negative origin" do
    tree = ExRstar.bulk_load([{-1.0, -1.0, :near}, {10.0, 10.0, :far}])
    results = ExRstar.locate_within_distance(tree, -1.0, -1.0, 1.0)
    assert length(results) == 1
    [{_, _, data}] = results
    assert data == :near
  end

  # ===========================================================================
  # Concurrent access
  # ===========================================================================

  test "concurrent inserts do not crash" do
    tree = ExRstar.new()

    tasks =
      for i <- 1..100 do
        Task.async(fn -> ExRstar.insert(tree, i / 1.0, i / 1.0, :"point_#{i}") end)
      end

    Task.await_many(tasks)
    assert ExRstar.size(tree) == 100
  end

  test "concurrent reads and writes do not crash" do
    tree = ExRstar.bulk_load(for i <- 1..50, do: {i / 1.0, i / 1.0, :"init_#{i}"})

    writers =
      for i <- 51..100 do
        Task.async(fn -> ExRstar.insert(tree, i / 1.0, i / 1.0, :"write_#{i}") end)
      end

    readers =
      for _ <- 1..50 do
        Task.async(fn -> ExRstar.nearest_neighbor(tree, 25.0, 25.0) end)
      end

    Task.await_many(writers ++ readers)
    assert ExRstar.size(tree) == 100
  end

  test "concurrent pop_nearest_neighbor safely drains" do
    tree = ExRstar.bulk_load(for i <- 1..20, do: {i / 1.0, 0.0, i})

    tasks =
      for _ <- 1..20 do
        Task.async(fn -> ExRstar.pop_nearest_neighbor(tree, 0.0, 0.0) end)
      end

    results = Task.await_many(tasks)
    ok_count = Enum.count(results, &match?({:ok, _}, &1))
    assert ok_count == 20
    assert ExRstar.size(tree) == 0
  end

  # ===========================================================================
  # Stress / larger datasets
  # ===========================================================================

  # ===========================================================================
  # Edge cases & empty-result scenarios
  # ===========================================================================

  test "locate_within_distance returns empty when nothing in range" do
    tree = ExRstar.bulk_load([{100.0, 100.0, :far}])
    assert [] = ExRstar.locate_within_distance(tree, 0.0, 0.0, 1.0)
  end

  test "drain_within_distance returns empty when nothing in range" do
    tree = ExRstar.bulk_load([{100.0, 100.0, :far}])
    assert [] = ExRstar.drain_within_distance(tree, 0.0, 0.0, 1.0)
    assert ExRstar.size(tree) == 1
  end

  test "locate_in_envelope on empty tree" do
    tree = ExRstar.new()
    assert [] = ExRstar.locate_in_envelope(tree, {0.0, 0.0}, {10.0, 10.0})
  end

  test "locate_in_envelope_intersecting on empty tree" do
    tree = ExRstar.new()
    assert [] = ExRstar.locate_in_envelope_intersecting(tree, {0.0, 0.0}, {10.0, 10.0})
  end

  test "locate_at_point on empty tree" do
    tree = ExRstar.new()
    assert {:error, :not_found} = ExRstar.locate_at_point(tree, 0.0, 0.0)
  end

  test "bulk_load single element" do
    tree = ExRstar.bulk_load([{42.0, 73.0, :solo}])
    assert ExRstar.size(tree) == 1
    assert {:ok, {42.0, 73.0, :solo}} = ExRstar.nearest_neighbor(tree, 42.0, 73.0)
  end

  test "pop_nearest_neighbor returns closest first (order verification)" do
    tree = ExRstar.bulk_load([{10.0, 0.0, :far}, {1.0, 0.0, :close}, {5.0, 0.0, :mid}])

    {:ok, {_, _, first}} = ExRstar.pop_nearest_neighbor(tree, 0.0, 0.0)
    {:ok, {_, _, second}} = ExRstar.pop_nearest_neighbor(tree, 0.0, 0.0)
    {:ok, {_, _, third}} = ExRstar.pop_nearest_neighbor(tree, 0.0, 0.0)

    assert first == :close
    assert second == :mid
    assert third == :far
  end

  test "remove one of multiple overlapping points" do
    tree = ExRstar.new()
    ExRstar.insert(tree, 1.0, 2.0, :first)
    ExRstar.insert(tree, 1.0, 2.0, :second)
    assert ExRstar.size(tree) == 2

    ExRstar.remove(tree, 1.0, 2.0)
    assert ExRstar.size(tree) == 1
    assert ExRstar.contains?(tree, 1.0, 2.0) == true
  end

  test "drain_in_envelope verifies remaining points are correct" do
    tree = ExRstar.bulk_load([{1.0, 1.0, :in}, {2.0, 2.0, :in2}, {10.0, 10.0, :out}])
    ExRstar.drain_in_envelope(tree, {0.0, 0.0}, {5.0, 5.0})
    remaining = ExRstar.to_list(tree)
    assert length(remaining) == 1
    [{_, _, data}] = remaining
    assert data == :out
  end

  test "remove preserves data on remaining points" do
    tree = ExRstar.new()
    ExRstar.insert(tree, 1.0, 1.0, %{id: 1, name: "first"})
    ExRstar.insert(tree, 5.0, 5.0, %{id: 2, name: "second"})

    ExRstar.remove(tree, 1.0, 1.0)
    {:ok, {_, _, data}} = ExRstar.nearest_neighbor(tree, 5.0, 5.0)
    assert data == %{id: 2, name: "second"}
  end

  test "to_list -> bulk_load round-trip preserves data" do
    original = [{1.0, 2.0, :a}, {3.0, 4.0, :b}, {5.0, 6.0, :c}]
    tree1 = ExRstar.bulk_load(original)
    exported = ExRstar.to_list(tree1)
    tree2 = ExRstar.bulk_load(exported)

    assert ExRstar.size(tree2) == 3

    for {x, y, d} <- original do
      assert {:ok, {^x, ^y, ^d}} = ExRstar.locate_at_point(tree2, x, y)
    end
  end

  test "clear then to_list returns empty" do
    tree = ExRstar.bulk_load([{1.0, 2.0, :a}])
    ExRstar.clear(tree)
    assert [] = ExRstar.to_list(tree)
  end

  test "nearest_neighbors returns correct squared distances for 2D" do
    tree = ExRstar.bulk_load([{3.0, 0.0, :a}, {0.0, 4.0, :b}])
    results = ExRstar.nearest_neighbors(tree, 0.0, 0.0, 2)
    distances = Enum.map(results, fn {_, _, _, d2} -> d2 end)
    assert distances == [9.0, 16.0]
  end

  # ===========================================================================
  # Stress / larger datasets
  # ===========================================================================

  test "1000-point KNN correctness" do
    :rand.seed(:exsss, {1, 2, 3})

    points =
      for i <- 1..1000, do: {(:rand.uniform() - 0.5) * 200, (:rand.uniform() - 0.5) * 200, i}

    tree = ExRstar.bulk_load(points)
    qx = 10.0
    qy = 10.0

    # Brute-force nearest
    {_, _, bf_data} = Enum.min_by(points, fn {x, y, _} -> (x - qx) ** 2 + (y - qy) ** 2 end)

    # Tree nearest
    {:ok, {_, _, tree_data}} = ExRstar.nearest_neighbor(tree, qx, qy)
    assert tree_data == bf_data
  end
end
