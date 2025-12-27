defmodule PortfolioCore.Application do
  @moduledoc """
  Application supervisor for PortfolioCore.

  Starts the registry and manifest engine processes.

  ## Configuration

  Configure the manifest path in your application config:

      config :portfolio_core, :manifest,
        manifest_path: "config/manifests/dev.yaml"

  ## Supervision Tree

      PortfolioCore.Supervisor
      ├── PortfolioCore.Registry
      └── PortfolioCore.Manifest.Engine
  """

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      PortfolioCore.Registry,
      {PortfolioCore.Manifest.Engine, manifest_opts()}
    ]

    opts = [strategy: :one_for_one, name: PortfolioCore.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp manifest_opts do
    Application.get_env(:portfolio_core, :manifest, [])
  end
end
