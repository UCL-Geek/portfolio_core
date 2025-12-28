defmodule PortfolioIndex.Adapters.GraphStore.Neo4j.CommunityTest do
  use ExUnit.Case, async: true

  alias PortfolioIndex.Adapters.GraphStore.Neo4j.Community

  describe "module attributes" do
    test "implements GraphStore.Community behaviour" do
      behaviours = Community.__info__(:attributes)[:behaviour] || []
      assert PortfolioCore.Ports.GraphStore.Community in behaviours
    end
  end
end
