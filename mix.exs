defmodule PortfolioCore.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/nshkrdotcom/portfolio_core"

  def project do
    [
      app: :portfolio_core,
      version: @version,
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      docs: docs(),
      name: "PortfolioCore",
      source_url: @source_url,
      aliases: aliases(),
      dialyzer: [
        plt_file: {:no_warn, "priv/plts/dialyzer.plt"},
        flags: [:error_handling, :unknown, :unmatched_returns]
      ],
      preferred_cli_env: [
        "test.watch": :test,
        coveralls: :test,
        "coveralls.html": :test
      ],
      test_coverage: [tool: ExCoveralls]
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {PortfolioCore.Application, []}
    ]
  end

  defp deps do
    [
      # Core dependencies
      {:yaml_elixir, "~> 2.9"},
      {:jason, "~> 1.4"},
      {:telemetry, "~> 1.2"},
      {:nimble_options, "~> 1.0"},

      # Dev/test only
      {:ex_doc, "~> 0.31", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:stream_data, "~> 0.6", only: [:dev, :test]},
      {:mox, "~> 1.1", only: :test},
      {:excoveralls, "~> 0.18", only: :test}
    ]
  end

  defp description do
    "Hexagonal architecture core for building flexible RAG systems in Elixir."
  end

  defp package do
    [
      name: "portfolio_core",
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url},
      maintainers: ["NSHKR"],
      files: ~w(lib assets .formatter.exs mix.exs README.md LICENSE CHANGELOG.md)
    ]
  end

  defp docs do
    [
      main: "readme",
      source_url: @source_url,
      source_ref: "v#{@version}",
      assets: %{"assets" => "assets"},
      logo: "assets/portfolio_core.svg",
      extras: ["README.md", "CHANGELOG.md", "LICENSE"],
      groups_for_modules: [
        Ports: ~r/PortfolioCore\.Ports\./,
        Manifest: ~r/PortfolioCore\.Manifest\./,
        Registry: ~r/PortfolioCore\.Registry/,
        Telemetry: ~r/PortfolioCore\.Telemetry/
      ]
    ]
  end

  defp aliases do
    [
      quality: ["format --check-formatted", "credo --strict", "dialyzer"],
      "test.all": ["quality", "test"]
    ]
  end
end
