defmodule PortfolioCore.Ports.GraphStoreTest do
  use ExUnit.Case, async: true

  import Mox

  alias PortfolioCore.Mocks.GraphStore, as: MockGraphStore

  setup :verify_on_exit!

  describe "create_node/2" do
    test "creates node with labels and properties" do
      node = %{
        id: "node_1",
        labels: ["Person", "Developer"],
        properties: %{name: "Alice", age: 30}
      }

      expect(MockGraphStore, :create_node, fn graph_id, n ->
        assert graph_id == "knowledge"
        assert n.id == "node_1"
        assert "Person" in n.labels
        {:ok, node}
      end)

      assert {:ok, ^node} = MockGraphStore.create_node("knowledge", node)
    end
  end

  describe "create_edge/2" do
    test "creates edge between nodes" do
      edge = %{
        id: "edge_1",
        type: "KNOWS",
        from_id: "node_1",
        to_id: "node_2",
        properties: %{since: 2020}
      }

      expect(MockGraphStore, :create_edge, fn graph_id, e ->
        assert graph_id == "knowledge"
        assert e.type == "KNOWS"
        {:ok, edge}
      end)

      assert {:ok, ^edge} = MockGraphStore.create_edge("knowledge", edge)
    end
  end

  describe "get_node/2" do
    test "retrieves node by id" do
      node = %{
        id: "node_1",
        labels: ["Person"],
        properties: %{name: "Alice"}
      }

      expect(MockGraphStore, :get_node, fn graph_id, node_id ->
        assert graph_id == "knowledge"
        assert node_id == "node_1"
        {:ok, node}
      end)

      assert {:ok, ^node} = MockGraphStore.get_node("knowledge", "node_1")
    end

    test "returns error for non-existent node" do
      expect(MockGraphStore, :get_node, fn _graph_id, _node_id ->
        {:error, :not_found}
      end)

      assert {:error, :not_found} = MockGraphStore.get_node("knowledge", "missing")
    end
  end

  describe "get_neighbors/3" do
    test "gets neighboring nodes" do
      neighbors = [
        %{id: "node_2", labels: ["Person"], properties: %{name: "Bob"}},
        %{id: "node_3", labels: ["Person"], properties: %{name: "Charlie"}}
      ]

      expect(MockGraphStore, :get_neighbors, fn graph_id, node_id, opts ->
        assert graph_id == "knowledge"
        assert node_id == "node_1"
        assert opts[:direction] == :outgoing
        {:ok, neighbors}
      end)

      assert {:ok, ^neighbors} =
               MockGraphStore.get_neighbors("knowledge", "node_1", direction: :outgoing)
    end
  end

  describe "query/3" do
    test "executes graph query" do
      result = %{
        nodes: [%{id: "n1", labels: ["Person"], properties: %{}}],
        edges: [],
        records: [%{"name" => "Alice"}]
      }

      expect(MockGraphStore, :query, fn graph_id, query, params ->
        assert graph_id == "knowledge"
        assert query =~ "MATCH"
        assert params[:name] == "Alice"
        {:ok, result}
      end)

      query = "MATCH (p:Person {name: $name}) RETURN p.name as name"

      assert {:ok, ^result} = MockGraphStore.query("knowledge", query, %{name: "Alice"})
    end
  end

  describe "graph_stats/1" do
    test "returns graph statistics" do
      stats = %{
        node_count: 1000,
        edge_count: 5000,
        label_counts: %{"Person" => 500, "Company" => 500}
      }

      expect(MockGraphStore, :graph_stats, fn graph_id ->
        assert graph_id == "knowledge"
        {:ok, stats}
      end)

      assert {:ok, ^stats} = MockGraphStore.graph_stats("knowledge")
    end
  end

  describe "behaviour - enhanced callbacks" do
    alias PortfolioCore.Ports.GraphStore

    test "defines traversal as required and vector search as optional" do
      callbacks = GraphStore.behaviour_info(:callbacks)
      optional = GraphStore.behaviour_info(:optional_callbacks)

      assert {:traverse, 3} in callbacks
      refute {:traverse, 3} in optional

      assert {:vector_search, 3} in optional
      refute {:create_community, 3} in optional
      refute {:get_community_members, 2} in optional
      refute {:update_community_summary, 3} in optional
      refute {:list_communities, 2} in optional
    end
  end
end
