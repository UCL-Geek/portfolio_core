defmodule PortfolioCore.Ports.Retriever do
  @moduledoc """
  Port specification for retrieval strategies.

  Retrievers combine different search techniques to find relevant
  content for a given query. They orchestrate vector stores, graph
  stores, and other data sources.

  ## Retrieval Strategies

  - `:semantic` - Pure vector similarity search
  - `:keyword` - Traditional keyword/BM25 search
  - `:hybrid` - Combines semantic and keyword search
  - `:graph` - Graph-based retrieval with entity expansion
  - `:multi_hop` - Iterative retrieval for complex queries

  ## Example Implementation

      defmodule MyApp.Adapters.HybridRetriever do
        @behaviour PortfolioCore.Ports.Retriever

        @impl true
        def retrieve(query, context, opts) do
          # Combine semantic and keyword search
        end
      end

  ## Context

  The context map provides additional information for retrieval:
  - `:graph_id` - Target graph for graph-based retrieval
  - `:index_id` - Target vector index
  - `:filters` - Metadata filters
  - `:user_context` - User-specific context for personalization
  """

  @type query :: String.t()
  @type context :: map()

  @type retrieved_item :: %{
          content: String.t(),
          score: float(),
          source: String.t(),
          metadata: map()
        }

  @type retrieval_result :: %{
          items: [retrieved_item()],
          query: query(),
          strategy: atom(),
          timing_ms: non_neg_integer()
        }

  @doc """
  Retrieve relevant content for a query.

  ## Parameters

    - `query` - The search query
    - `context` - Retrieval context (graph_id, index_id, etc.)
    - `opts` - Retrieval options:
      - `:limit` - Maximum items to return
      - `:min_score` - Minimum relevance score
      - `:rerank` - Whether to apply reranking

  ## Returns

    - `{:ok, result}` with retrieved items and metadata
    - `{:error, reason}` on failure
  """
  @callback retrieve(query(), context(), opts :: keyword()) ::
              {:ok, retrieval_result()} | {:error, term()}

  @doc """
  Get the name of this retrieval strategy.

  ## Returns

    - Atom identifying the strategy
  """
  @callback strategy_name() :: atom()

  @doc """
  Get list of required adapters for this retriever.

  ## Returns

    - List of port names this retriever depends on
  """
  @callback required_adapters() :: [atom()]
end
