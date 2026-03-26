# ExRstar

Elixir NIF wrapper around the Rust [rstar](https://crates.io/crates/rstar) R*-tree spatial index. Provides efficient 2D nearest-neighbor, envelope, radius, and point queries with optional associated data per point.

[![Hex.pm](https://img.shields.io/hexpm/v/ex_rstar.svg)](https://hex.pm/packages/ex_rstar)
[![HexDocs](https://img.shields.io/badge/hex-docs-blue.svg)](https://hexdocs.pm/ex_rstar)

## Features

- Insert, remove, and bulk-load 2D points with optional arbitrary Elixir term data
- Nearest-neighbor and k-nearest-neighbor queries (sorted by distance)
- Bounding-box queries (contained and intersecting)
- Radius queries (squared Euclidean distance)
- Exact point lookup
- Drain (remove and return) points within a radius
- O(n log n) bulk loading via the R*-tree overlap-minimizing algorithm
- Thread-safe: concurrent reads and writes from multiple BEAM processes
- Automatic garbage collection when the tree reference is no longer held

## Installation

### From Hex (Recommended)

Add `ex_rstar` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ex_rstar, "~> 0.1.2"}
  ]
end
```

Then run:

```bash
mix deps.get
mix compile
```

**Note:** This package uses precompiled Rust NIFs for fast installation. **No Rust toolchain is required** for most platforms. Precompiled binaries are automatically downloaded during installation.

If precompiled binaries are not available for your platform, the package will automatically fall back to compiling from source, which requires the Rust toolchain to be installed.

#### Supported Platforms

Precompiled binaries are provided for:
- **macOS**: x86_64 (Intel), aarch64 (Apple Silicon)
- **Linux**: x86_64 (glibc), aarch64 (glibc)
- **Windows**: x86_64 (MSVC), x86_64 (GNU)

#### Force Build from Source

To force compilation from source instead of using precompiled binaries:

```bash
RUSTLER_PRECOMPILATION_EXAMPLE_BUILD=true mix deps.compile ex_rstar --force
```

### From Source (Development)

```bash
git clone https://github.com/cortfritz/ex_rstar.git
cd ex_rstar
mix deps.get
mix compile
mix test
```

## Usage

### Creating and Populating a Tree

```elixir
# Create an empty tree and insert points one at a time
tree = ExRstar.new()
ExRstar.insert(tree, 1.0, 2.0, :cafe)
ExRstar.insert(tree, 3.0, 4.0, %{name: "Park", rating: 4.5})
ExRstar.insert(tree, 5.0, 6.0)  # no data (stores nil)

ExRstar.size(tree)
#=> 3

# Or bulk-load for better performance on large datasets
points = [
  {1.0, 2.0, :cafe},
  {3.0, 4.0, %{name: "Park"}},
  {5.0, 6.0}  # {x, y} without data is also accepted
]
tree = ExRstar.bulk_load(points)
```

### Nearest-Neighbor Queries

```elixir
# Find the single closest point
iex> ExRstar.nearest_neighbor(tree, 1.1, 2.1)
{:ok, {1.0, 2.0, :cafe}}

# Find the 2 closest points (sorted by distance)
iex> ExRstar.nearest_neighbors(tree, 0.0, 0.0, 2)
[{1.0, 2.0, :cafe, 5.0}, {3.0, 4.0, %{name: "Park"}, 25.0}]
# Each result is {x, y, data, squared_distance}

# Empty tree returns :not_found
iex> ExRstar.nearest_neighbor(ExRstar.new(), 0.0, 0.0)
{:error, :not_found}
```

### Bounding-Box Queries

```elixir
# Find all points contained within a rectangle
iex> ExRstar.locate_in_envelope(tree, {0.0, 0.0}, {4.0, 4.0})
[{1.0, 2.0, :cafe}, {3.0, 4.0, %{name: "Park"}}]

# Find all points whose envelopes intersect the rectangle
# (for point data, equivalent to locate_in_envelope)
iex> ExRstar.locate_in_envelope_intersecting(tree, {0.0, 0.0}, {4.0, 4.0})
[{1.0, 2.0, :cafe}, {3.0, 4.0, %{name: "Park"}}]
```

### Radius Queries

```elixir
# Find all points within squared distance of 10.0 from (0, 0)
# (squared distance avoids a sqrt -- distance 10.0 means radius ~3.16)
iex> ExRstar.locate_within_distance(tree, 0.0, 0.0, 10.0)
[{1.0, 2.0, :cafe}]

# Remove and return all points within a radius (mutates the tree)
iex> ExRstar.drain_within_distance(tree, 0.0, 0.0, 10.0)
[{1.0, 2.0, :cafe}]
iex> ExRstar.size(tree)
2
```

### Point Lookup and Removal

```elixir
# Find a point at exact coordinates
iex> ExRstar.locate_at_point(tree, 3.0, 4.0)
{:ok, {3.0, 4.0, %{name: "Park"}}}

iex> ExRstar.locate_at_point(tree, 99.0, 99.0)
{:error, :not_found}

# Remove a point by coordinates
iex> ExRstar.remove(tree, 3.0, 4.0)
{:ok, true}

iex> ExRstar.remove(tree, 3.0, 4.0)
{:ok, false}  # already removed
```

### API Reference

| Function | Description |
|----------|-------------|
| `new/0` | Create an empty R*-tree |
| `bulk_load/1` | Build a tree from a list of points (O(n log n)) |
| `insert/3,4` | Insert a point, optionally with data |
| `remove/3` | Remove a point by coordinates |
| `size/1` | Number of points in the tree |
| `nearest_neighbor/3` | Find the closest point |
| `nearest_neighbors/4` | Find k closest points sorted by distance |
| `locate_in_envelope/3` | All points within a bounding box |
| `locate_in_envelope_intersecting/3` | All points intersecting a bounding box |
| `locate_within_distance/4` | All points within squared distance |
| `locate_at_point/3` | Find a point at exact coordinates |
| `drain_within_distance/4` | Remove and return points within squared distance |

## Architecture

- `lib/ex_rstar.ex` -- Public API with data encoding/decoding
- `lib/ex_rstar/native.ex` -- NIF interface (RustlerPrecompiled)
- `native/rstar_nif/` -- Rust NIF wrapping the [rstar](https://crates.io/crates/rstar) crate

The tree is held as an opaque NIF resource reference backed by a `Mutex<RTree<Point2D>>` in Rust. It lives in Rust memory and is garbage-collected by the BEAM when no longer referenced. Associated data is serialized via `:erlang.term_to_binary/1`, so any Elixir term (atoms, maps, tuples, binaries, etc.) can be stored per point.

## Safety

- **Application code**: The NIF wrapper (`native/rstar_nif/`) contains no `unsafe` blocks
- **rstar library**: The spatial index crate is safe Rust
- **rustler**: The NIF binding library (v0.36) contains `unsafe` code internally to interface with the BEAM's C NIF API, but exposes only safe Rust APIs. Rustler catches Rust panics before they unwind into C, preventing BEAM crashes.
- **Concurrency**: The tree is protected by a `Mutex`, making concurrent access from multiple BEAM processes safe

## Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/your-feature`
3. Make your changes and ensure tests pass: `mix test`
4. Format your code: `mix format`
5. Commit with a descriptive message
6. Push and create a pull request

### Reporting Issues

Please use [GitHub Issues](https://github.com/cortfritz/ex_rstar/issues) to report bugs or request features. Include:

- Elixir and OTP versions
- Operating system and architecture
- Steps to reproduce
- Expected vs actual behavior

## Sponsorship

If you find this library useful, please consider [sponsoring the project](https://github.com/sponsors/cortfritz).

## License

This project is licensed under the MIT License -- see the [LICENSE](LICENSE) file for details.

## Documentation

Full API documentation is available on [HexDocs](https://hexdocs.pm/ex_rstar).
