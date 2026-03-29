defmodule ExRstar do
  @moduledoc """
  An Elixir wrapper around the Rust `rstar` R*-tree spatial index.

  Provides a 2D R*-tree that stores points with optional arbitrary data.
  Points are `{x, y}` tuples, and each point can carry an associated term
  that is serialized via `:erlang.term_to_binary/1`.

  For 3D points (ECEF, point clouds, etc.), see `ExRstar.ThreeD`.

  The tree is held as an opaque NIF resource reference -- it lives in Rust
  memory and is garbage-collected when no longer referenced from the BEAM.
  """

  alias ExRstar.Native

  @type tree :: reference()
  @type point :: {float(), float()}
  @type point_with_data :: {float(), float(), term()}

  @doc """
  Creates a new empty R*-tree.
  """
  def new do
    Native.new_tree()
  end

  @doc """
  Efficiently bulk-loads a list of points into a new tree.

  Each element is either `{x, y}` or `{x, y, data}`.
  Runs in O(n log n) using the overlap-minimizing top-down algorithm.
  """
  def bulk_load(points) when is_list(points) do
    encoded =
      Enum.map(points, fn
        {x, y} -> {x / 1, y / 1, []}
        {x, y, data} -> {x / 1, y / 1, :binary.bin_to_list(:erlang.term_to_binary(data))}
      end)

    Native.bulk_load(encoded)
  end

  @doc """
  Inserts a point into the tree. Optionally attach data.
  """
  def insert(tree, x, y, data \\ nil) do
    encoded =
      if data == nil, do: [], else: :binary.bin_to_list(:erlang.term_to_binary(data))

    Native.insert(tree, x / 1, y / 1, encoded)
  end

  @doc """
  Removes a point at the given coordinates. Returns `{:ok, true}` if
  a point was removed, `{:ok, false}` if no point was found there.
  """
  def remove(tree, x, y) do
    Native.remove(tree, x / 1, y / 1)
  end

  @doc """
  Returns the number of elements in the tree.
  """
  def size(tree) do
    Native.size(tree)
  end

  @doc """
  Returns `true` if a point exists at the given coordinates.
  """
  def contains?(tree, x, y) do
    Native.contains(tree, x / 1, y / 1)
  end

  @doc """
  Finds the nearest neighbor to the query point.
  Returns `{:ok, {x, y, data}}` or `{:error, :not_found}`.
  """
  def nearest_neighbor(tree, x, y) do
    case Native.nearest_neighbor(tree, x / 1, y / 1) do
      {:ok, {px, py, raw}} -> {:ok, {px, py, decode_data(raw)}}
    end
  rescue
    ErlangError -> {:error, :not_found}
  end

  @doc """
  Returns the `count` nearest neighbors to the query point, sorted by distance.
  Each result is `{x, y, data, squared_distance}`.
  """
  def nearest_neighbors(tree, x, y, count) do
    Native.nearest_neighbors(tree, x / 1, y / 1, count)
    |> Enum.map(fn {px, py, raw, dist2} -> {px, py, decode_data(raw), dist2} end)
  end

  @doc """
  Removes and returns the nearest neighbor to the query point.
  Returns `{:ok, {x, y, data}}` or `{:error, :not_found}`.

  Useful for queue-like consumption patterns (e.g., dispatching to the
  closest available resource).
  """
  def pop_nearest_neighbor(tree, x, y) do
    case Native.pop_nearest_neighbor(tree, x / 1, y / 1) do
      {:ok, {px, py, raw}} -> {:ok, {px, py, decode_data(raw)}}
    end
  rescue
    ErlangError -> {:error, :not_found}
  end

  @doc """
  Returns ALL points at the exact given coordinates.

  Unlike `locate_at_point/3` which returns only one, this returns all
  overlapping points. Useful when multiple items share coordinates.
  """
  def locate_all_at_point(tree, x, y) do
    Native.locate_all_at_point(tree, x / 1, y / 1)
    |> decode_points()
  end

  @doc """
  Returns all points fully contained within the given bounding box.
  """
  def locate_in_envelope(tree, {min_x, min_y}, {max_x, max_y}) do
    Native.locate_in_envelope(tree, min_x / 1, min_y / 1, max_x / 1, max_y / 1)
    |> decode_points()
  end

  @doc """
  Returns all points whose envelopes intersect the given bounding box.
  For point data this is equivalent to `locate_in_envelope/3`.
  """
  def locate_in_envelope_intersecting(tree, {min_x, min_y}, {max_x, max_y}) do
    Native.locate_in_envelope_intersecting(tree, min_x / 1, min_y / 1, max_x / 1, max_y / 1)
    |> decode_points()
  end

  @doc """
  Returns all points within the given squared distance from the query point.
  """
  def locate_within_distance(tree, x, y, max_distance_squared) do
    Native.locate_within_distance(tree, x / 1, y / 1, max_distance_squared / 1)
    |> decode_points()
  end

  @doc """
  Finds a point exactly at the given coordinates.
  Returns `{:ok, {x, y, data}}` or `{:error, :not_found}`.
  """
  def locate_at_point(tree, x, y) do
    case Native.locate_at_point(tree, x / 1, y / 1) do
      {:ok, {px, py, raw}} -> {:ok, {px, py, decode_data(raw)}}
    end
  rescue
    ErlangError -> {:error, :not_found}
  end

  @doc """
  Removes and returns all points within the given squared distance
  from the query point.
  """
  def drain_within_distance(tree, x, y, max_distance_squared) do
    Native.drain_within_distance(tree, x / 1, y / 1, max_distance_squared / 1)
    |> decode_points()
  end

  @doc """
  Removes and returns all points fully contained within the given bounding box.
  """
  def drain_in_envelope(tree, {min_x, min_y}, {max_x, max_y}) do
    Native.drain_in_envelope(tree, min_x / 1, min_y / 1, max_x / 1, max_y / 1)
    |> decode_points()
  end

  @doc """
  Removes and returns all points whose envelopes intersect the given bounding box.
  """
  def drain_in_envelope_intersecting(tree, {min_x, min_y}, {max_x, max_y}) do
    Native.drain_in_envelope_intersecting(tree, min_x / 1, min_y / 1, max_x / 1, max_y / 1)
    |> decode_points()
  end

  @doc """
  Returns all points in the tree as a list of `{x, y, data}` tuples.
  """
  def to_list(tree) do
    Native.to_list(tree)
    |> decode_points()
  end

  @doc """
  Removes all points from the tree. Returns the number of points removed.
  """
  def clear(tree) do
    Native.clear(tree)
  end

  # --- Private helpers ---

  defp decode_data([]), do: nil

  defp decode_data(bytes) when is_list(bytes),
    do: :erlang.binary_to_term(:erlang.list_to_binary(bytes))

  defp decode_points(points) do
    Enum.map(points, fn {x, y, raw} -> {x, y, decode_data(raw)} end)
  end
end
