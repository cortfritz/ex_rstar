defmodule ExRstarThreeDTest do
  use ExUnit.Case

  # ===========================================================================
  # Construction & Size
  # ===========================================================================

  test "new tree has size 0" do
    tree = ExRstar.ThreeD.new()
    assert ExRstar.ThreeD.size(tree) == 0
  end

  test "insert and size" do
    tree = ExRstar.ThreeD.new()
    ExRstar.ThreeD.insert(tree, 1.0, 2.0, 3.0)
    ExRstar.ThreeD.insert(tree, 4.0, 5.0, 6.0)
    assert ExRstar.ThreeD.size(tree) == 2
  end

  test "bulk_load" do
    points = for i <- 1..100, do: {i / 1.0, i / 1.0, i / 1.0, "point_#{i}"}
    tree = ExRstar.ThreeD.bulk_load(points)
    assert ExRstar.ThreeD.size(tree) == 100
  end

  test "bulk_load with {x, y, z} tuples (no data)" do
    points = [{1.0, 2.0, 3.0}, {4.0, 5.0, 6.0}, {7.0, 8.0, 9.0}]
    tree = ExRstar.ThreeD.bulk_load(points)
    assert ExRstar.ThreeD.size(tree) == 3
    assert {:ok, {1.0, 2.0, 3.0, nil}} = ExRstar.ThreeD.nearest_neighbor(tree, 1.0, 2.0, 3.0)
  end

  test "bulk_load empty list" do
    tree = ExRstar.ThreeD.bulk_load([])
    assert ExRstar.ThreeD.size(tree) == 0
  end

  # ===========================================================================
  # Insert / Remove
  # ===========================================================================

  test "insert with data and nearest_neighbor" do
    tree = ExRstar.ThreeD.new()
    ExRstar.ThreeD.insert(tree, +0.0, +0.0, +0.0, :origin)
    ExRstar.ThreeD.insert(tree, 10.0, 10.0, 10.0, :far)

    assert {:ok, {+0.0, +0.0, +0.0, :origin}} =
             ExRstar.ThreeD.nearest_neighbor(tree, 1.0, 1.0, 1.0)
  end

  test "insert without data stores nil" do
    tree = ExRstar.ThreeD.new()
    ExRstar.ThreeD.insert(tree, 5.0, 5.0, 5.0)
    assert {:ok, {5.0, 5.0, 5.0, nil}} = ExRstar.ThreeD.nearest_neighbor(tree, 5.0, 5.0, 5.0)
  end

  test "remove" do
    tree = ExRstar.ThreeD.new()
    ExRstar.ThreeD.insert(tree, 1.0, 2.0, 3.0, :a)
    assert ExRstar.ThreeD.size(tree) == 1

    assert {:ok, true} = ExRstar.ThreeD.remove(tree, 1.0, 2.0, 3.0)
    assert ExRstar.ThreeD.size(tree) == 0

    assert {:ok, false} = ExRstar.ThreeD.remove(tree, 1.0, 2.0, 3.0)
  end

  # ===========================================================================
  # contains?
  # ===========================================================================

  test "contains? returns true for existing point" do
    tree = ExRstar.ThreeD.new()
    ExRstar.ThreeD.insert(tree, 3.0, 4.0, 5.0, :target)
    assert ExRstar.ThreeD.contains?(tree, 3.0, 4.0, 5.0) == true
  end

  test "contains? returns false for missing point" do
    tree = ExRstar.ThreeD.new()
    ExRstar.ThreeD.insert(tree, 3.0, 4.0, 5.0)
    assert ExRstar.ThreeD.contains?(tree, 99.0, 99.0, 99.0) == false
  end

  test "contains? on empty tree" do
    tree = ExRstar.ThreeD.new()
    assert ExRstar.ThreeD.contains?(tree, 0.0, 0.0, 0.0) == false
  end

  test "contains? after remove" do
    tree = ExRstar.ThreeD.new()
    ExRstar.ThreeD.insert(tree, 1.0, 2.0, 3.0)
    assert ExRstar.ThreeD.contains?(tree, 1.0, 2.0, 3.0) == true
    ExRstar.ThreeD.remove(tree, 1.0, 2.0, 3.0)
    assert ExRstar.ThreeD.contains?(tree, 1.0, 2.0, 3.0) == false
  end

  # ===========================================================================
  # Nearest Neighbor
  # ===========================================================================

  test "nearest_neighbor on empty tree" do
    tree = ExRstar.ThreeD.new()
    assert {:error, :not_found} = ExRstar.ThreeD.nearest_neighbor(tree, 0.0, 0.0, 0.0)
  end

  test "nearest_neighbors returns sorted results" do
    tree = ExRstar.ThreeD.new()
    ExRstar.ThreeD.insert(tree, +0.0, +0.0, +0.0, :a)
    ExRstar.ThreeD.insert(tree, 5.0, 5.0, 5.0, :b)
    ExRstar.ThreeD.insert(tree, 10.0, 10.0, 10.0, :c)

    results = ExRstar.ThreeD.nearest_neighbors(tree, 0.0, 0.0, 0.0, 2)
    assert length(results) == 2
    [{_, _, _, data1, _}, {_, _, _, data2, _}] = results
    assert data1 == :a
    assert data2 == :b
  end

  test "nearest_neighbors returns squared 3D distance" do
    tree = ExRstar.ThreeD.bulk_load([{3.0, 4.0, 0.0, :a}])
    [{_, _, _, _, dist2}] = ExRstar.ThreeD.nearest_neighbors(tree, 0.0, 0.0, 0.0, 1)
    assert dist2 == 25.0
  end

  test "nearest_neighbors on empty tree returns empty list" do
    tree = ExRstar.ThreeD.new()
    assert [] = ExRstar.ThreeD.nearest_neighbors(tree, 0.0, 0.0, 0.0, 5)
  end

  test "nearest_neighbors count exceeds tree size returns all points" do
    tree =
      ExRstar.ThreeD.bulk_load([{1.0, 1.0, 1.0, :a}, {2.0, 2.0, 2.0, :b}, {3.0, 3.0, 3.0, :c}])

    results = ExRstar.ThreeD.nearest_neighbors(tree, 0.0, 0.0, 0.0, 10)
    assert length(results) == 3
  end

  # ===========================================================================
  # pop_nearest_neighbor
  # ===========================================================================

  test "pop_nearest_neighbor removes and returns closest point" do
    tree =
      ExRstar.ThreeD.bulk_load([
        {1.0, 1.0, 1.0, :a},
        {5.0, 5.0, 5.0, :b},
        {10.0, 10.0, 10.0, :c}
      ])

    assert ExRstar.ThreeD.size(tree) == 3

    assert {:ok, {1.0, 1.0, 1.0, :a}} =
             ExRstar.ThreeD.pop_nearest_neighbor(tree, 0.0, 0.0, 0.0)

    assert ExRstar.ThreeD.size(tree) == 2

    assert {:ok, {5.0, 5.0, 5.0, :b}} =
             ExRstar.ThreeD.pop_nearest_neighbor(tree, 0.0, 0.0, 0.0)

    assert ExRstar.ThreeD.size(tree) == 1
  end

  test "pop_nearest_neighbor on empty tree" do
    tree = ExRstar.ThreeD.new()
    assert {:error, :not_found} = ExRstar.ThreeD.pop_nearest_neighbor(tree, 0.0, 0.0, 0.0)
  end

  test "pop_nearest_neighbor drains tree one at a time" do
    tree = ExRstar.ThreeD.bulk_load(for i <- 1..10, do: {i / 1.0, 0.0, 0.0, i})

    for _ <- 1..10 do
      assert {:ok, _} = ExRstar.ThreeD.pop_nearest_neighbor(tree, 0.0, 0.0, 0.0)
    end

    assert ExRstar.ThreeD.size(tree) == 0
    assert {:error, :not_found} = ExRstar.ThreeD.pop_nearest_neighbor(tree, 0.0, 0.0, 0.0)
  end

  # ===========================================================================
  # locate_all_at_point
  # ===========================================================================

  test "locate_all_at_point returns all overlapping points" do
    tree = ExRstar.ThreeD.new()
    ExRstar.ThreeD.insert(tree, 1.0, 2.0, 3.0, :first)
    ExRstar.ThreeD.insert(tree, 1.0, 2.0, 3.0, :second)
    ExRstar.ThreeD.insert(tree, 1.0, 2.0, 3.0, :third)
    ExRstar.ThreeD.insert(tree, 5.0, 5.0, 5.0, :elsewhere)

    results = ExRstar.ThreeD.locate_all_at_point(tree, 1.0, 2.0, 3.0)
    assert length(results) == 3
    data = Enum.map(results, fn {_, _, _, d} -> d end) |> Enum.sort()
    assert data == [:first, :second, :third]
  end

  test "locate_all_at_point returns empty list for missing point" do
    tree = ExRstar.ThreeD.new()
    ExRstar.ThreeD.insert(tree, 1.0, 2.0, 3.0, :a)
    assert [] = ExRstar.ThreeD.locate_all_at_point(tree, 99.0, 99.0, 99.0)
  end

  test "locate_all_at_point on empty tree" do
    tree = ExRstar.ThreeD.new()
    assert [] = ExRstar.ThreeD.locate_all_at_point(tree, 0.0, 0.0, 0.0)
  end

  # ===========================================================================
  # Envelope Queries
  # ===========================================================================

  test "locate_in_envelope" do
    tree =
      ExRstar.ThreeD.bulk_load([
        {1.0, 1.0, 1.0, :a},
        {2.0, 2.0, 2.0, :b},
        {5.0, 5.0, 5.0, :c},
        {10.0, 10.0, 10.0, :d}
      ])

    results = ExRstar.ThreeD.locate_in_envelope(tree, {0.0, 0.0, 0.0}, {3.0, 3.0, 3.0})
    assert length(results) == 2
    data = Enum.map(results, fn {_, _, _, d} -> d end) |> Enum.sort()
    assert data == [:a, :b]
  end

  test "locate_in_envelope_intersecting" do
    tree =
      ExRstar.ThreeD.bulk_load([
        {1.0, 1.0, 1.0, :inside},
        {3.0, 3.0, 3.0, :boundary},
        {5.0, 5.0, 5.0, :outside}
      ])

    results =
      ExRstar.ThreeD.locate_in_envelope_intersecting(tree, {0.0, 0.0, 0.0}, {3.0, 3.0, 3.0})

    data = Enum.map(results, fn {_, _, _, d} -> d end) |> Enum.sort()
    assert :inside in data
    assert :boundary in data
    refute :outside in data
  end

  test "locate_in_envelope returns empty for non-overlapping region" do
    tree = ExRstar.ThreeD.bulk_load([{10.0, 10.0, 10.0, :far}])
    assert [] = ExRstar.ThreeD.locate_in_envelope(tree, {0.0, 0.0, 0.0}, {1.0, 1.0, 1.0})
  end

  # ===========================================================================
  # Distance Queries
  # ===========================================================================

  test "locate_within_distance" do
    tree =
      ExRstar.ThreeD.bulk_load([
        {+0.0, +0.0, +0.0, :close},
        {1.0, +0.0, +0.0, :mid},
        {100.0, 100.0, 100.0, :far}
      ])

    results = ExRstar.ThreeD.locate_within_distance(tree, 0.0, 0.0, 0.0, 2.0)
    data = Enum.map(results, fn {_, _, _, d} -> d end) |> Enum.sort()
    assert data == [:close, :mid]
  end

  # ===========================================================================
  # Point Lookup
  # ===========================================================================

  test "locate_at_point" do
    tree = ExRstar.ThreeD.new()
    ExRstar.ThreeD.insert(tree, 3.0, 4.0, 5.0, :target)

    assert {:ok, {3.0, 4.0, 5.0, :target}} = ExRstar.ThreeD.locate_at_point(tree, 3.0, 4.0, 5.0)
    assert {:error, :not_found} = ExRstar.ThreeD.locate_at_point(tree, 0.0, 0.0, 0.0)
  end

  # ===========================================================================
  # drain_within_distance
  # ===========================================================================

  test "drain_within_distance removes and returns points" do
    tree =
      ExRstar.ThreeD.bulk_load([
        {+0.0, +0.0, +0.0, :a},
        {1.0, +0.0, +0.0, :b},
        {100.0, 100.0, 100.0, :c}
      ])

    drained = ExRstar.ThreeD.drain_within_distance(tree, 0.0, 0.0, 0.0, 2.0)
    assert length(drained) == 2
    assert ExRstar.ThreeD.size(tree) == 1
  end

  # ===========================================================================
  # drain_in_envelope
  # ===========================================================================

  test "drain_in_envelope removes and returns contained points" do
    tree =
      ExRstar.ThreeD.bulk_load([
        {1.0, 1.0, 1.0, :a},
        {2.0, 2.0, 2.0, :b},
        {5.0, 5.0, 5.0, :c},
        {10.0, 10.0, 10.0, :d}
      ])

    drained = ExRstar.ThreeD.drain_in_envelope(tree, {0.0, 0.0, 0.0}, {3.0, 3.0, 3.0})
    assert length(drained) == 2
    data = Enum.map(drained, fn {_, _, _, d} -> d end) |> Enum.sort()
    assert data == [:a, :b]
    assert ExRstar.ThreeD.size(tree) == 2
  end

  test "drain_in_envelope on empty region returns empty" do
    tree = ExRstar.ThreeD.bulk_load([{10.0, 10.0, 10.0, :far}])
    assert [] = ExRstar.ThreeD.drain_in_envelope(tree, {0.0, 0.0, 0.0}, {1.0, 1.0, 1.0})
    assert ExRstar.ThreeD.size(tree) == 1
  end

  test "drain_in_envelope_intersecting removes boundary points" do
    tree =
      ExRstar.ThreeD.bulk_load([
        {1.0, 1.0, 1.0, :inside},
        {3.0, 3.0, 3.0, :boundary},
        {5.0, 5.0, 5.0, :outside}
      ])

    drained =
      ExRstar.ThreeD.drain_in_envelope_intersecting(tree, {0.0, 0.0, 0.0}, {3.0, 3.0, 3.0})

    data = Enum.map(drained, fn {_, _, _, d} -> d end) |> Enum.sort()
    assert :inside in data
    assert :boundary in data
    refute :outside in data
    assert ExRstar.ThreeD.size(tree) == 1
  end

  # ===========================================================================
  # to_list
  # ===========================================================================

  test "to_list returns all points" do
    tree =
      ExRstar.ThreeD.bulk_load([{1.0, 2.0, 3.0, :a}, {4.0, 5.0, 6.0, :b}, {7.0, 8.0, 9.0, :c}])

    result = ExRstar.ThreeD.to_list(tree)
    assert length(result) == 3
    data = Enum.map(result, fn {_, _, _, d} -> d end) |> Enum.sort()
    assert data == [:a, :b, :c]
  end

  test "to_list on empty tree" do
    tree = ExRstar.ThreeD.new()
    assert [] = ExRstar.ThreeD.to_list(tree)
  end

  test "to_list preserves coordinates" do
    tree = ExRstar.ThreeD.bulk_load([{1_334_998.0, -4_654_050.0, 4_138_297.0, :nyc}])
    [{x, y, z, :nyc}] = ExRstar.ThreeD.to_list(tree)
    assert x == 1_334_998.0
    assert y == -4_654_050.0
    assert z == 4_138_297.0
  end

  # ===========================================================================
  # clear
  # ===========================================================================

  test "clear removes all points and returns count" do
    tree = ExRstar.ThreeD.bulk_load(for i <- 1..50, do: {i / 1.0, i / 1.0, i / 1.0, i})
    assert ExRstar.ThreeD.size(tree) == 50

    removed = ExRstar.ThreeD.clear(tree)
    assert removed == 50
    assert ExRstar.ThreeD.size(tree) == 0
  end

  test "clear on empty tree returns 0" do
    tree = ExRstar.ThreeD.new()
    assert ExRstar.ThreeD.clear(tree) == 0
  end

  test "tree is usable after clear" do
    tree = ExRstar.ThreeD.bulk_load([{1.0, 2.0, 3.0, :old}])
    ExRstar.ThreeD.clear(tree)
    ExRstar.ThreeD.insert(tree, 5.0, 6.0, 7.0, :new)
    assert ExRstar.ThreeD.size(tree) == 1

    assert {:ok, {5.0, 6.0, 7.0, :new}} =
             ExRstar.ThreeD.nearest_neighbor(tree, 5.0, 6.0, 7.0)
  end

  # ===========================================================================
  # Data encoding edge cases
  # ===========================================================================

  test "stores and retrieves map data" do
    tree = ExRstar.ThreeD.new()
    data = %{name: "satellite", altitude: 408_000.0}
    ExRstar.ThreeD.insert(tree, 1.0, 2.0, 3.0, data)

    assert {:ok, {1.0, 2.0, 3.0, ^data}} = ExRstar.ThreeD.nearest_neighbor(tree, 1.0, 2.0, 3.0)
  end

  test "stores and retrieves nested struct-like data" do
    tree = ExRstar.ThreeD.new()
    data = %{address: %{street: "123 Main", city: "Portland"}, id: 42}
    ExRstar.ThreeD.insert(tree, 3.0, 4.0, 5.0, data)

    assert {:ok, {3.0, 4.0, 5.0, ^data}} = ExRstar.ThreeD.nearest_neighbor(tree, 3.0, 4.0, 5.0)
  end

  test "stores and retrieves large binary data" do
    tree = ExRstar.ThreeD.new()
    data = :crypto.strong_rand_bytes(4096)
    ExRstar.ThreeD.insert(tree, 1.0, 1.0, 1.0, data)

    assert {:ok, {1.0, 1.0, 1.0, ^data}} = ExRstar.ThreeD.nearest_neighbor(tree, 1.0, 1.0, 1.0)
  end

  test "stores and retrieves tuple data" do
    tree = ExRstar.ThreeD.new()
    data = {:point_meta, 42, "label"}
    ExRstar.ThreeD.insert(tree, 2.0, 3.0, 4.0, data)

    assert {:ok, {2.0, 3.0, 4.0, ^data}} = ExRstar.ThreeD.nearest_neighbor(tree, 2.0, 3.0, 4.0)
  end

  # ===========================================================================
  # Integer coercion
  # ===========================================================================

  test "integer coordinate coercion" do
    tree = ExRstar.ThreeD.new()
    ExRstar.ThreeD.insert(tree, 3, 4, 5, :int_point)

    assert {:ok, {3.0, 4.0, 5.0, :int_point}} =
             ExRstar.ThreeD.nearest_neighbor(tree, 3, 4, 5)
  end

  test "bulk_load with integer coordinates" do
    points = [{1, 2, 3, :a}, {4, 5, 6, :b}]
    tree = ExRstar.ThreeD.bulk_load(points)
    assert ExRstar.ThreeD.size(tree) == 2
    assert {:ok, {1.0, 2.0, 3.0, :a}} = ExRstar.ThreeD.nearest_neighbor(tree, 1, 2, 3)
  end

  # ===========================================================================
  # Negative coordinates
  # ===========================================================================

  test "negative coordinates work correctly" do
    tree =
      ExRstar.ThreeD.bulk_load([
        {-5.0, -5.0, -5.0, :neg},
        {5.0, 5.0, 5.0, :pos},
        {-1.0, 1.0, -1.0, :mixed}
      ])

    assert {:ok, {-5.0, -5.0, -5.0, :neg}} =
             ExRstar.ThreeD.nearest_neighbor(tree, -4.0, -4.0, -4.0)

    assert {:ok, {5.0, 5.0, 5.0, :pos}} =
             ExRstar.ThreeD.nearest_neighbor(tree, 6.0, 6.0, 6.0)
  end

  test "locate_in_envelope with negative coordinates" do
    tree =
      ExRstar.ThreeD.bulk_load([
        {-3.0, -3.0, -3.0, :a},
        {-1.0, -1.0, -1.0, :b},
        {1.0, 1.0, 1.0, :c}
      ])

    results =
      ExRstar.ThreeD.locate_in_envelope(tree, {-4.0, -4.0, -4.0}, {-0.5, -0.5, -0.5})

    data = Enum.map(results, fn {_, _, _, d} -> d end) |> Enum.sort()
    assert data == [:a, :b]
  end

  test "locate_within_distance with negative origin" do
    tree =
      ExRstar.ThreeD.bulk_load([
        {-1.0, -1.0, -1.0, :near},
        {10.0, 10.0, 10.0, :far}
      ])

    results = ExRstar.ThreeD.locate_within_distance(tree, -1.0, -1.0, -1.0, 1.0)
    assert length(results) == 1
    [{_, _, _, data}] = results
    assert data == :near
  end

  # ===========================================================================
  # ECEF-scale coordinates
  # ===========================================================================

  test "ECEF-scale coordinates work" do
    nyc = {1_334_998.0, -4_654_050.0, 4_138_297.0, :nyc}
    london = {3_980_608.0, -11_881.0, 4_966_862.0, :london}
    tokyo = {-3_959_786.0, 3_352_557.0, 3_697_508.0, :tokyo}

    tree = ExRstar.ThreeD.bulk_load([nyc, london, tokyo])

    assert {:ok, {_, _, _, :nyc}} =
             ExRstar.ThreeD.nearest_neighbor(tree, 1_335_000.0, -4_654_000.0, 4_138_300.0)
  end

  test "ECEF nearest neighbor ordering matches brute force" do
    # 5 cities at ECEF scale
    cities = [
      {1_334_998.0, -4_654_050.0, 4_138_297.0, :nyc},
      {3_980_608.0, -11_881.0, 4_966_862.0, :london},
      {-3_959_786.0, 3_352_557.0, 3_697_508.0, :tokyo},
      {-1_797_543.0, 5_178_429.0, -3_430_428.0, :sydney},
      {-2_694_000.0, -4_297_600.0, -3_854_900.0, :sao_paulo}
    ]

    tree = ExRstar.ThreeD.bulk_load(cities)

    # Query from a point near London
    qx = 3_980_000.0
    qy = -10_000.0
    qz = 4_966_000.0

    # Brute-force
    {_, _, _, bf_city} =
      Enum.min_by(cities, fn {x, y, z, _} ->
        (x - qx) ** 2 + (y - qy) ** 2 + (z - qz) ** 2
      end)

    {:ok, {_, _, _, tree_city}} = ExRstar.ThreeD.nearest_neighbor(tree, qx, qy, qz)
    assert tree_city == bf_city
  end

  # ===========================================================================
  # Concurrent access
  # ===========================================================================

  test "concurrent inserts do not crash" do
    tree = ExRstar.ThreeD.new()

    tasks =
      for i <- 1..100 do
        Task.async(fn ->
          ExRstar.ThreeD.insert(tree, i / 1.0, i / 1.0, i / 1.0, :"point_#{i}")
        end)
      end

    Task.await_many(tasks)
    assert ExRstar.ThreeD.size(tree) == 100
  end

  test "concurrent reads and writes do not crash" do
    tree =
      ExRstar.ThreeD.bulk_load(for i <- 1..50, do: {i / 1.0, i / 1.0, i / 1.0, :"init_#{i}"})

    writers =
      for i <- 51..100 do
        Task.async(fn ->
          ExRstar.ThreeD.insert(tree, i / 1.0, i / 1.0, i / 1.0, :"write_#{i}")
        end)
      end

    readers =
      for _ <- 1..50 do
        Task.async(fn ->
          ExRstar.ThreeD.nearest_neighbor(tree, 25.0, 25.0, 25.0)
        end)
      end

    Task.await_many(writers ++ readers)
    assert ExRstar.ThreeD.size(tree) == 100
  end

  test "concurrent pop_nearest_neighbor safely drains" do
    tree = ExRstar.ThreeD.bulk_load(for i <- 1..20, do: {i / 1.0, 0.0, 0.0, i})

    tasks =
      for _ <- 1..20 do
        Task.async(fn -> ExRstar.ThreeD.pop_nearest_neighbor(tree, 0.0, 0.0, 0.0) end)
      end

    results = Task.await_many(tasks)
    ok_count = Enum.count(results, &match?({:ok, _}, &1))
    assert ok_count == 20
    assert ExRstar.ThreeD.size(tree) == 0
  end

  # ===========================================================================
  # Independence
  # ===========================================================================

  test "2D and 3D trees are independent" do
    tree_2d = ExRstar.new()
    tree_3d = ExRstar.ThreeD.new()

    ExRstar.insert(tree_2d, 1.0, 2.0, :flat)
    ExRstar.ThreeD.insert(tree_3d, 1.0, 2.0, 3.0, :spatial)

    assert ExRstar.size(tree_2d) == 1
    assert ExRstar.ThreeD.size(tree_3d) == 1
  end

  # ===========================================================================
  # Stress / larger datasets
  # ===========================================================================

  # ===========================================================================
  # Edge cases & empty-result scenarios
  # ===========================================================================

  test "locate_within_distance returns empty when nothing in range" do
    tree = ExRstar.ThreeD.bulk_load([{100.0, 100.0, 100.0, :far}])
    assert [] = ExRstar.ThreeD.locate_within_distance(tree, 0.0, 0.0, 0.0, 1.0)
  end

  test "drain_within_distance returns empty when nothing in range" do
    tree = ExRstar.ThreeD.bulk_load([{100.0, 100.0, 100.0, :far}])
    assert [] = ExRstar.ThreeD.drain_within_distance(tree, 0.0, 0.0, 0.0, 1.0)
    assert ExRstar.ThreeD.size(tree) == 1
  end

  test "locate_in_envelope on empty tree" do
    tree = ExRstar.ThreeD.new()
    assert [] = ExRstar.ThreeD.locate_in_envelope(tree, {0.0, 0.0, 0.0}, {10.0, 10.0, 10.0})
  end

  test "locate_in_envelope_intersecting on empty tree" do
    tree = ExRstar.ThreeD.new()

    assert [] =
             ExRstar.ThreeD.locate_in_envelope_intersecting(
               tree,
               {0.0, 0.0, 0.0},
               {10.0, 10.0, 10.0}
             )
  end

  test "locate_at_point on empty tree" do
    tree = ExRstar.ThreeD.new()
    assert {:error, :not_found} = ExRstar.ThreeD.locate_at_point(tree, 0.0, 0.0, 0.0)
  end

  test "bulk_load single element" do
    tree = ExRstar.ThreeD.bulk_load([{42.0, 73.0, 10.0, :solo}])
    assert ExRstar.ThreeD.size(tree) == 1

    assert {:ok, {42.0, 73.0, 10.0, :solo}} =
             ExRstar.ThreeD.nearest_neighbor(tree, 42.0, 73.0, 10.0)
  end

  test "pop_nearest_neighbor returns closest first (order verification)" do
    tree =
      ExRstar.ThreeD.bulk_load([
        {10.0, 0.0, 0.0, :far},
        {1.0, 0.0, 0.0, :close},
        {5.0, 0.0, 0.0, :mid}
      ])

    {:ok, {_, _, _, first}} = ExRstar.ThreeD.pop_nearest_neighbor(tree, 0.0, 0.0, 0.0)
    {:ok, {_, _, _, second}} = ExRstar.ThreeD.pop_nearest_neighbor(tree, 0.0, 0.0, 0.0)
    {:ok, {_, _, _, third}} = ExRstar.ThreeD.pop_nearest_neighbor(tree, 0.0, 0.0, 0.0)

    assert first == :close
    assert second == :mid
    assert third == :far
  end

  test "remove one of multiple overlapping points" do
    tree = ExRstar.ThreeD.new()
    ExRstar.ThreeD.insert(tree, 1.0, 2.0, 3.0, :first)
    ExRstar.ThreeD.insert(tree, 1.0, 2.0, 3.0, :second)
    assert ExRstar.ThreeD.size(tree) == 2

    ExRstar.ThreeD.remove(tree, 1.0, 2.0, 3.0)
    assert ExRstar.ThreeD.size(tree) == 1
    assert ExRstar.ThreeD.contains?(tree, 1.0, 2.0, 3.0) == true
  end

  test "drain_in_envelope verifies remaining points are correct" do
    tree =
      ExRstar.ThreeD.bulk_load([
        {1.0, 1.0, 1.0, :in},
        {2.0, 2.0, 2.0, :in2},
        {10.0, 10.0, 10.0, :out}
      ])

    ExRstar.ThreeD.drain_in_envelope(tree, {0.0, 0.0, 0.0}, {5.0, 5.0, 5.0})
    remaining = ExRstar.ThreeD.to_list(tree)
    assert length(remaining) == 1
    [{_, _, _, data}] = remaining
    assert data == :out
  end

  test "remove preserves data on remaining points" do
    tree = ExRstar.ThreeD.new()
    ExRstar.ThreeD.insert(tree, 1.0, 1.0, 1.0, %{id: 1, name: "first"})
    ExRstar.ThreeD.insert(tree, 5.0, 5.0, 5.0, %{id: 2, name: "second"})

    ExRstar.ThreeD.remove(tree, 1.0, 1.0, 1.0)
    {:ok, {_, _, _, data}} = ExRstar.ThreeD.nearest_neighbor(tree, 5.0, 5.0, 5.0)
    assert data == %{id: 2, name: "second"}
  end

  test "to_list -> bulk_load round-trip preserves data" do
    original = [{1.0, 2.0, 3.0, :a}, {4.0, 5.0, 6.0, :b}, {7.0, 8.0, 9.0, :c}]
    tree1 = ExRstar.ThreeD.bulk_load(original)
    exported = ExRstar.ThreeD.to_list(tree1)
    tree2 = ExRstar.ThreeD.bulk_load(exported)

    assert ExRstar.ThreeD.size(tree2) == 3

    for {x, y, z, d} <- original do
      assert {:ok, {^x, ^y, ^z, ^d}} = ExRstar.ThreeD.locate_at_point(tree2, x, y, z)
    end
  end

  test "clear then to_list returns empty" do
    tree = ExRstar.ThreeD.bulk_load([{1.0, 2.0, 3.0, :a}])
    ExRstar.ThreeD.clear(tree)
    assert [] = ExRstar.ThreeD.to_list(tree)
  end

  test "nearest_neighbors returns correct squared distances for 3D" do
    tree = ExRstar.ThreeD.bulk_load([{3.0, 0.0, 0.0, :a}, {0.0, 4.0, 0.0, :b}])
    results = ExRstar.ThreeD.nearest_neighbors(tree, 0.0, 0.0, 0.0, 2)
    distances = Enum.map(results, fn {_, _, _, _, d2} -> d2 end)
    assert distances == [9.0, 16.0]
  end

  test "z-axis differentiates otherwise identical xy points" do
    tree = ExRstar.ThreeD.new()
    ExRstar.ThreeD.insert(tree, 0.0, 0.0, 100.0, :high)
    ExRstar.ThreeD.insert(tree, 0.0, 0.0, 1.0, :low)

    # Query from ground level - should find :low
    {:ok, {_, _, _, :low}} = ExRstar.ThreeD.nearest_neighbor(tree, 0.0, 0.0, 0.0)

    # Query from altitude - should find :high
    {:ok, {_, _, _, :high}} = ExRstar.ThreeD.nearest_neighbor(tree, 0.0, 0.0, 99.0)
  end

  # ===========================================================================
  # Stress / larger datasets
  # ===========================================================================

  test "1000-point 3D KNN correctness" do
    :rand.seed(:exsss, {4, 5, 6})

    points =
      for i <- 1..1000 do
        {(:rand.uniform() - 0.5) * 200, (:rand.uniform() - 0.5) * 200,
         (:rand.uniform() - 0.5) * 200, i}
      end

    tree = ExRstar.ThreeD.bulk_load(points)
    qx = 10.0
    qy = -20.0
    qz = 30.0

    # Brute-force nearest
    {_, _, _, bf_data} =
      Enum.min_by(points, fn {x, y, z, _} ->
        (x - qx) ** 2 + (y - qy) ** 2 + (z - qz) ** 2
      end)

    {:ok, {_, _, _, tree_data}} = ExRstar.ThreeD.nearest_neighbor(tree, qx, qy, qz)
    assert tree_data == bf_data
  end
end
