defmodule ExRstar.MixProject do
  use Mix.Project

  def project do
    [
      app: :ex_rstar,
      version: "0.2.1",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:rustler, "~> 0.36", runtime: false},
      {:rustler_precompiled, "~> 0.8"},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end

  defp description do
    "Elixir NIF wrapper around the Rust rstar R*-tree spatial index. " <>
      "Provides efficient 2D and 3D nearest-neighbor, envelope, and radius queries " <>
      "with optional associated data per point. 3D support enables ECEF and point cloud use cases."
  end

  defp package do
    [
      name: "ex_rstar",
      files: [
        "lib",
        "native/rstar_nif/src",
        "native/rstar_nif/Cargo.toml",
        "priv/native",
        "checksum-*.exs",
        "mix.exs",
        "README.md",
        "LICENSE*"
      ],
      maintainers: ["Cort Fritz"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/cortfritz/ex_rstar",
        "Sponsor" => "https://github.com/sponsors/cortfritz"
      }
    ]
  end
end
