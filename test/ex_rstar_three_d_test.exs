defmodule ExRstarThreeDTest do
  use ExUnit.Case

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

  test "insert with data and nearest_neighbor" do
    tree = ExRstar.ThreeD.new()
    ExRstar.ThreeD.insert(tree, +0.0, +0.0, +0.0, :origin)
    ExRstar.ThreeD.insert(tree, 10.0, 10.0, 10.0, :far)

    assert {:ok, {+0.0, +0.0, +0.0, :origin}} =
             ExRstar.ThreeD.nearest_neighbor(tree, 1.0, 1.0, 1.0)
  end

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
    tree =
      ExRstar.ThreeD.bulk_load([
        {3.0, 4.0, 0.0, :a}
      ])

    [{_, _, _, _, dist2}] = ExRstar.ThreeD.nearest_neighbors(tree, 0.0, 0.0, 0.0, 1)
    assert dist2 == 25.0
  end

  test "nearest_neighbors on empty tree returns empty list" do
    tree = ExRstar.ThreeD.new()
    assert [] = ExRstar.ThreeD.nearest_neighbors(tree, 0.0, 0.0, 0.0, 5)
  end

  test "nearest_neighbors count exceeds tree size returns all points" do
    tree =
      ExRstar.ThreeD.bulk_load([
        {1.0, 1.0, 1.0, :a},
        {2.0, 2.0, 2.0, :b},
        {3.0, 3.0, 3.0, :c}
      ])

    results = ExRstar.ThreeD.nearest_neighbors(tree, 0.0, 0.0, 0.0, 10)
    assert length(results) == 3
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

  test "locate_within_distance" do
    tree =
      ExRstar.ThreeD.bulk_load([
        {+0.0, +0.0, +0.0, :close},
        {1.0, +0.0, +0.0, :mid},
        {100.0, 100.0, 100.0, :far}
      ])

    # squared distance of 2.0 => radius ~1.41
    results = ExRstar.ThreeD.locate_within_distance(tree, 0.0, 0.0, 0.0, 2.0)
    data = Enum.map(results, fn {_, _, _, d} -> d end) |> Enum.sort()
    assert data == [:close, :mid]
  end

  test "locate_at_point" do
    tree = ExRstar.ThreeD.new()
    ExRstar.ThreeD.insert(tree, 3.0, 4.0, 5.0, :target)

    assert {:ok, {3.0, 4.0, 5.0, :target}} = ExRstar.ThreeD.locate_at_point(tree, 3.0, 4.0, 5.0)
    assert {:error, :not_found} = ExRstar.ThreeD.locate_at_point(tree, 0.0, 0.0, 0.0)
  end

  test "remove" do
    tree = ExRstar.ThreeD.new()
    ExRstar.ThreeD.insert(tree, 1.0, 2.0, 3.0, :a)
    assert ExRstar.ThreeD.size(tree) == 1

    assert {:ok, true} = ExRstar.ThreeD.remove(tree, 1.0, 2.0, 3.0)
    assert ExRstar.ThreeD.size(tree) == 0

    assert {:ok, false} = ExRstar.ThreeD.remove(tree, 1.0, 2.0, 3.0)
  end

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

  test "insert without data stores nil" do
    tree = ExRstar.ThreeD.new()
    ExRstar.ThreeD.insert(tree, 5.0, 5.0, 5.0)
    assert {:ok, {5.0, 5.0, 5.0, nil}} = ExRstar.ThreeD.nearest_neighbor(tree, 5.0, 5.0, 5.0)
  end

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

  test "ECEF-scale coordinates work" do
    # Approximate ECEF for New York and London (meters)
    nyc = {1_334_998.0, -4_654_050.0, 4_138_297.0, :nyc}
    london = {3_980_608.0, -11_881.0, 4_966_862.0, :london}
    tokyo = {-3_959_786.0, 3_352_557.0, 3_697_508.0, :tokyo}

    tree = ExRstar.ThreeD.bulk_load([nyc, london, tokyo])

    # Query near NYC should find NYC
    assert {:ok, {_, _, _, :nyc}} =
             ExRstar.ThreeD.nearest_neighbor(tree, 1_335_000.0, -4_654_000.0, 4_138_300.0)
  end

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

  test "2D and 3D trees are independent" do
    tree_2d = ExRstar.new()
    tree_3d = ExRstar.ThreeD.new()

    ExRstar.insert(tree_2d, 1.0, 2.0, :flat)
    ExRstar.ThreeD.insert(tree_3d, 1.0, 2.0, 3.0, :spatial)

    assert ExRstar.size(tree_2d) == 1
    assert ExRstar.ThreeD.size(tree_3d) == 1
  end
end
