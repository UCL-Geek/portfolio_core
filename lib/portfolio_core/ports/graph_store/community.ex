defmodule PortfolioCore.Ports.GraphStore.Community do
  @moduledoc """
  Behavior for GraphRAG community operations on graph stores.

  Community management covers cluster creation, membership queries, and
  summary updates for higher-level graph traversal and retrieval.
  """

  @type graph_id :: PortfolioCore.Ports.GraphStore.graph_id()
  @type node_id :: PortfolioCore.Ports.GraphStore.node_id()
  @type community_id :: String.t()

  @type community :: %{
          id: community_id(),
          name: String.t(),
          summary: String.t() | nil,
          member_count: non_neg_integer(),
          level: non_neg_integer()
        }

  @doc """
  Create a community (cluster of related nodes).

  ## Parameters

    - `graph_id` - The target graph
    - `community_id` - Unique community identifier
    - `opts` - Community options:
      - `:name` - Human-readable name
      - `:level` - Hierarchy level (0 = leaf)
      - `:member_ids` - Initial member node IDs

  ## Returns

    - `:ok` on success
    - `{:error, reason}` on failure
  """
  @callback create_community(graph_id(), community_id(), opts :: keyword()) ::
              :ok | {:error, term()}

  @doc """
  Get member node IDs for a community.

  ## Parameters

    - `graph_id` - The graph to query
    - `community_id` - The community identifier

  ## Returns

    - `{:ok, node_ids}` - List of member node IDs
    - `{:error, reason}` on failure
  """
  @callback get_community_members(graph_id(), community_id()) ::
              {:ok, [node_id()]} | {:error, term()}

  @doc """
  Update the LLM-generated summary for a community.

  Summaries enable global search over community themes.

  ## Parameters

    - `graph_id` - The target graph
    - `community_id` - The community to update
    - `summary` - LLM-generated summary text

  ## Returns

    - `:ok` on success
    - `{:error, reason}` on failure
  """
  @callback update_community_summary(
              graph_id(),
              community_id(),
              summary :: String.t()
            ) ::
              :ok | {:error, term()}

  @doc """
  List all communities in a graph.

  ## Parameters

    - `graph_id` - The graph to query
    - `opts` - List options:
      - `:level` - Filter by hierarchy level
      - `:limit` - Maximum communities to return

  ## Returns

    - `{:ok, communities}` - List of community metadata
    - `{:error, reason}` on failure
  """
  @callback list_communities(graph_id(), opts :: keyword()) ::
              {:ok, [community()]} | {:error, term()}
end
