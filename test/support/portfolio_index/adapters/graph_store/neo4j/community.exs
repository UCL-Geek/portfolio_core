defmodule PortfolioIndex.Adapters.GraphStore.Neo4j.Community do
  @moduledoc false
  # Test stub: portfolio_core ships ports only; adapters live in portfolio_index.
  @behaviour PortfolioCore.Ports.GraphStore.Community

  @impl true
  def create_community(_graph_id, _community_id, _opts) do
    {:error, :not_implemented}
  end

  @impl true
  def get_community_members(_graph_id, _community_id) do
    {:error, :not_implemented}
  end

  @impl true
  def update_community_summary(_graph_id, _community_id, _summary) do
    {:error, :not_implemented}
  end

  @impl true
  def list_communities(_graph_id, _opts) do
    {:error, :not_implemented}
  end
end
