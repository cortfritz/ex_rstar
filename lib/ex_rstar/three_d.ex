defmodule ExRstar.ThreeD do
  @moduledoc """
  3D R*-tree spatial index.

  Mirrors the `ExRstar` 2D API but operates on `{x, y, z}` points with
  3D Euclidean distance. Useful for ECEF (Earth-Centered, Earth-Fixed)
  coordinates, 3D scene graphs, point clouds, or any Cartesian 3D data.

  The tree uses squared Euclidean distance (`dx^2 + dy^2 + dz^2`) for all
  distance computations. For ECEF coordinates this gives chord distance,
  which preserves nearest-neighbor ordering and is suitable for spatial
  queries. If you need great-circle (geodesic) distance, compute it on
  the query results using Haversine or Vincenty formulas.
  """

  alias ExRstar.Native

  @type tree :: reference()
  @type point :: {float(), float(), float()}
  @type point_with_data :: {float(), float(), float(), term()}

  @doc """
  Creates a new empty 3D R*-tree.
  """
  def new do
    Native.new_tree_3d()
  end

  @doc """
  Efficiently bulk-loads a list of 3D points into a new tree.

  Each element is either `{x, y, z}` or `{x, y, z, data}`.
  Runs in O(n log n) using the overlap-minimizing top-down algorithm.
  """
  def bulk_load(points) when is_list(points) do
    encoded =
      Enum.map(points, fn
        {x, y, z} ->
          {x / 1, y / 1, z / 1, []}

        {x, y, z, data} ->
          {x / 1, y / 1, z / 1, :binary.bin_to_list(:erlang.term_to_binary(data))}
      end)

    Native.bulk_load_3d(encoded)
  end

  @doc """
  Inserts a 3D point into the tree. Optionally attach data.
  """
  def insert(tree, x, y, z, data \\ nil) do
    encoded =
      if data == nil, do: [], else: :binary.bin_to_list(:erlang.term_to_binary(data))

    Native.insert_3d(tree, x / 1, y / 1, z / 1, encoded)
  end

  @doc """
  Removes a point at the given coordinates. Returns `{:ok, true}` if
  a point was removed, `{:ok, false}` if no point was found there.
  """
  def remove(tree, x, y, z) do
    Native.remove_3d(tree, x / 1, y / 1, z / 1)
  end

  @doc """
  Returns the number of elements in the tree.
  """
  def size(tree) do
    Native.size_3d(tree)
  end

  @doc """
  Finds the nearest neighbor to the query point.
  Returns `{:ok, {x, y, z, data}}` or `{:error, :not_found}`.
  """
  def nearest_neighbor(tree, x, y, z) do
    case Native.nearest_neighbor_3d(tree, x / 1, y / 1, z / 1) do
      {:ok, {px, py, pz, raw}} -> {:ok, {px, py, pz, decode_data(raw)}}
    end
  rescue
    ErlangError -> {:error, :not_found}
  end

  @doc """
  Returns the `count` nearest neighbors to the query point, sorted by distance.
  Each result is `{x, y, z, data, squared_distance}`.
  """
  def nearest_neighbors(tree, x, y, z, count) do
    Native.nearest_neighbors_3d(tree, x / 1, y / 1, z / 1, count)
    |> Enum.map(fn {px, py, pz, raw, dist2} -> {px, py, pz, decode_data(raw), dist2} end)
  end

  @doc """
  Returns all points fully contained within the given 3D bounding box.
  """
  def locate_in_envelope(tree, {min_x, min_y, min_z}, {max_x, max_y, max_z}) do
    Native.locate_in_envelope_3d(
      tree,
      min_x / 1,
      min_y / 1,
      min_z / 1,
      max_x / 1,
      max_y / 1,
      max_z / 1
    )
    |> decode_points()
  end

  @doc """
  Returns all points whose envelopes intersect the given 3D bounding box.
  For point data this is equivalent to `locate_in_envelope/3`.
  """
  def locate_in_envelope_intersecting(tree, {min_x, min_y, min_z}, {max_x, max_y, max_z}) do
    Native.locate_in_envelope_intersecting_3d(
      tree,
      min_x / 1,
      min_y / 1,
      min_z / 1,
      max_x / 1,
      max_y / 1,
      max_z / 1
    )
    |> decode_points()
  end

  @doc """
  Returns all points within the given squared distance from the query point.
  """
  def locate_within_distance(tree, x, y, z, max_distance_squared) do
    Native.locate_within_distance_3d(tree, x / 1, y / 1, z / 1, max_distance_squared / 1)
    |> decode_points()
  end

  @doc """
  Finds a point exactly at the given coordinates.
  Returns `{:ok, {x, y, z, data}}` or `{:error, :not_found}`.
  """
  def locate_at_point(tree, x, y, z) do
    case Native.locate_at_point_3d(tree, x / 1, y / 1, z / 1) do
      {:ok, {px, py, pz, raw}} -> {:ok, {px, py, pz, decode_data(raw)}}
    end
  rescue
    ErlangError -> {:error, :not_found}
  end

  @doc """
  Removes and returns all points within the given squared distance
  from the query point.
  """
  def drain_within_distance(tree, x, y, z, max_distance_squared) do
    Native.drain_within_distance_3d(tree, x / 1, y / 1, z / 1, max_distance_squared / 1)
    |> decode_points()
  end

  # --- Private helpers ---

  defp decode_data([]), do: nil

  defp decode_data(bytes) when is_list(bytes),
    do: :erlang.binary_to_term(:erlang.list_to_binary(bytes))

  defp decode_points(points) do
    Enum.map(points, fn {x, y, z, raw} -> {x, y, z, decode_data(raw)} end)
  end
end
