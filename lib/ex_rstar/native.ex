defmodule ExRstar.Native do
  version = Mix.Project.config()[:version]

  use RustlerPrecompiled,
    otp_app: :ex_rstar,
    crate: "rstar_nif",
    base_url: "https://github.com/cortfritz/ex_rstar/releases/download/v#{version}",
    force_build:
      System.get_env("RUSTLER_PRECOMPILATION_EXAMPLE_BUILD") in ["1", "true"] or
        Mix.env() in [:dev, :test],
    version: version

  def new_tree(), do: :erlang.nif_error(:nif_not_loaded)
  def bulk_load(_points), do: :erlang.nif_error(:nif_not_loaded)
  def insert(_tree, _x, _y, _data), do: :erlang.nif_error(:nif_not_loaded)
  def remove(_tree, _x, _y), do: :erlang.nif_error(:nif_not_loaded)
  def size(_tree), do: :erlang.nif_error(:nif_not_loaded)
  def nearest_neighbor(_tree, _x, _y), do: :erlang.nif_error(:nif_not_loaded)
  def nearest_neighbors(_tree, _x, _y, _count), do: :erlang.nif_error(:nif_not_loaded)

  def locate_in_envelope(_tree, _min_x, _min_y, _max_x, _max_y),
    do: :erlang.nif_error(:nif_not_loaded)

  def locate_in_envelope_intersecting(_tree, _min_x, _min_y, _max_x, _max_y),
    do: :erlang.nif_error(:nif_not_loaded)

  def locate_within_distance(_tree, _x, _y, _max_dist_sq), do: :erlang.nif_error(:nif_not_loaded)
  def locate_at_point(_tree, _x, _y), do: :erlang.nif_error(:nif_not_loaded)
  def drain_within_distance(_tree, _x, _y, _max_dist_sq), do: :erlang.nif_error(:nif_not_loaded)
end
