defmodule PortfolioIndex.Adapters.GraphStore.Neo4j.CommunityTest do
  use PortfolioCore.SupertesterCase, async: true

  alias PortfolioCore.TestSupport.Neo4jCommunity, as: Community

  describe "module attributes" do
    test "implements GraphStore.Community behaviour" do
      behaviours = Community.__info__(:attributes)[:behaviour] || []
      assert PortfolioCore.Ports.GraphStore.Community in behaviours
    end
  end
end
