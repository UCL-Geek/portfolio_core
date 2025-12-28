defmodule PortfolioCore.Ports.GraphStore do
  @moduledoc """
  Port specification for graph database backends.

  Supports knowledge graphs with:
  - Labeled nodes with properties
  - Typed edges with properties
  - Cypher-like query interface
  - Graph namespacing for multi-tenancy

  ## Multi-Graph Architecture

  This port supports a multi-graph architecture where each `graph_id` represents
  an isolated namespace. This enables:
  - Per-repository graphs
  - Domain-specific graphs
  - Meta-graphs for cross-graph traversal

  ## GraphRAG Community Operations

  GraphRAG community management is specified in
  `PortfolioCore.Ports.GraphStore.Community`.

  ## Example Implementation

      defmodule MyApp.Adapters.Neo4j do
        @behaviour PortfolioCore.Ports.GraphStore

        @impl true
        def create_node(graph_id, node) do
          # Implementation using Neo4j driver
        end
      end
  """

  @type graph_id :: String.t()
  @type node_id :: String.t()
  @type edge_id :: String.t()
  @type label :: String.t()
  @type properties :: map()

  @type graph_node :: %{
          id: node_id(),
          labels: [label()],
          properties: properties()
        }

  @type graph_edge :: %{
          id: edge_id(),
          type: String.t(),
          from_id: node_id(),
          to_id: node_id(),
          properties: properties()
        }

  @type query_result :: %{
          nodes: [graph_node()],
          edges: [graph_edge()],
          records: [map()]
        }

  @type traversal_algorithm :: :bfs | :dfs

  @doc """
  Create a new graph namespace.

  ## Parameters

    - `graph_id` - Unique identifier for the graph
    - `config` - Graph configuration options

  ## Returns

    - `:ok` on success
    - `{:error, reason}` on failure
  """
  @callback create_graph(graph_id(), config :: map()) ::
              :ok | {:error, term()}

  @doc """
  Delete a graph and all its data.

  ## Parameters

    - `graph_id` - The graph to delete

  ## Returns

    - `:ok` on success
    - `{:error, reason}` on failure
  """
  @callback delete_graph(graph_id()) ::
              :ok | {:error, term()}

  @doc """
  Create a new node in the graph.

  ## Parameters

    - `graph_id` - The target graph
    - `node` - Node data with id, labels, and properties

  ## Returns

    - `{:ok, node}` with created node
    - `{:error, reason}` on failure
  """
  @callback create_node(graph_id(), graph_node()) ::
              {:ok, graph_node()} | {:error, term()}

  @doc """
  Create a new edge between nodes.

  ## Parameters

    - `graph_id` - The target graph
    - `edge` - Edge data with type, from_id, to_id, and properties

  ## Returns

    - `{:ok, edge}` with created edge
    - `{:error, reason}` on failure
  """
  @callback create_edge(graph_id(), graph_edge()) ::
              {:ok, graph_edge()} | {:error, term()}

  @doc """
  Get a node by ID.

  ## Parameters

    - `graph_id` - The graph to query
    - `node_id` - The node ID to retrieve

  ## Returns

    - `{:ok, node}` if found
    - `{:error, :not_found}` if not found
    - `{:error, reason}` on other failures
  """
  @callback get_node(graph_id(), node_id()) ::
              {:ok, graph_node()} | {:error, :not_found | term()}

  @doc """
  Get neighboring nodes.

  ## Parameters

    - `graph_id` - The graph to query
    - `node_id` - The source node
    - `opts` - Query options:
      - `:direction` - `:outgoing`, `:incoming`, or `:both`
      - `:edge_types` - Filter by edge types
      - `:limit` - Maximum neighbors to return

  ## Returns

    - `{:ok, nodes}` - List of neighboring nodes
    - `{:error, reason}` on failure
  """
  @callback get_neighbors(graph_id(), node_id(), opts :: keyword()) ::
              {:ok, [graph_node()]} | {:error, term()}

  @doc """
  Execute a graph query.

  The query language depends on the backend (e.g., Cypher for Neo4j).

  ## Parameters

    - `graph_id` - The graph to query
    - `query` - Query string
    - `params` - Query parameters

  ## Returns

    - `{:ok, result}` with query results
    - `{:error, reason}` on failure
  """
  @callback query(graph_id(), query :: String.t(), params :: map()) ::
              {:ok, query_result()} | {:error, term()}

  @doc """
  Delete a node and its connected edges.

  ## Parameters

    - `graph_id` - The graph containing the node
    - `node_id` - The node to delete

  ## Returns

    - `:ok` on success
    - `{:error, reason}` on failure
  """
  @callback delete_node(graph_id(), node_id()) ::
              :ok | {:error, term()}

  @doc """
  Delete an edge.

  ## Parameters

    - `graph_id` - The graph containing the edge
    - `edge_id` - The edge to delete

  ## Returns

    - `:ok` on success
    - `{:error, reason}` on failure
  """
  @callback delete_edge(graph_id(), edge_id()) ::
              :ok | {:error, term()}

  @doc """
  Get graph statistics.

  ## Parameters

    - `graph_id` - The graph to query

  ## Returns

    - `{:ok, stats}` with graph statistics including node/edge counts
    - `{:error, reason}` on failure
  """
  @callback graph_stats(graph_id()) ::
              {:ok, map()} | {:error, term()}

  @doc """
  Traverse the graph from a starting node.

  ## Parameters

    - `graph_id` - The graph to traverse
    - `node_id` - Starting node
    - `opts` - Traversal options:
      - `:direction` - `:outgoing`, `:incoming`, or `:both`
      - `:max_depth` - Maximum traversal depth
      - `:algorithm` - `:bfs` or `:dfs`
      - `:edge_types` - Filter by edge types
      - `:limit` - Maximum nodes to return

  ## Returns

    - `{:ok, nodes}` - List of traversed nodes
    - `{:error, reason}` on failure
  """
  @callback traverse(graph_id(), node_id(), opts :: keyword()) ::
              {:ok, [graph_node()]} | {:error, term()}

  @doc """
  Search for nodes by vector similarity.

  Requires nodes to have embeddings stored in properties.

  ## Parameters

    - `graph_id` - The graph to search
    - `embedding` - Query embedding vector
    - `opts` - Search options:
      - `:k` - Number of results
      - `:labels` - Filter by node labels
      - `:min_score` - Minimum similarity score

  ## Returns

    - `{:ok, nodes}` - Matching nodes sorted by similarity
    - `{:error, reason}` on failure
  """
  @callback vector_search(graph_id(), embedding :: [float()], opts :: keyword()) ::
              {:ok, [graph_node()]} | {:error, term()}

  @optional_callbacks [vector_search: 3]
end
