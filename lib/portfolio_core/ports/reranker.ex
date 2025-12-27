defmodule PortfolioCore.Ports.Reranker do
  @moduledoc """
  Port specification for result reranking.

  Rerankers improve retrieval quality by re-scoring initial results
  using more sophisticated models. They typically use cross-encoder
  models that consider query-document pairs together.

  ## How Reranking Works

  1. Initial retrieval returns N candidates (fast, approximate)
  2. Reranker scores each candidate against the query (slower, accurate)
  3. Results are reordered by the new scores

  ## Example Implementation

      defmodule MyApp.Adapters.CohereReranker do
        @behaviour PortfolioCore.Ports.Reranker

        @impl true
        def rerank(query, items, opts) do
          # Call Cohere rerank API
        end
      end

  ## Common Reranking Models

  - Cohere Rerank
  - Jina Reranker
  - Cross-encoder models (local)
  - LLM-based reranking
  """

  @type query :: String.t()
  @type item :: %{content: String.t(), score: float(), metadata: map()}

  @type reranked_item :: %{
          content: String.t(),
          original_score: float(),
          rerank_score: float(),
          metadata: map()
        }

  @doc """
  Rerank a list of items based on query relevance.

  ## Parameters

    - `query` - The original search query
    - `items` - List of items to rerank
    - `opts` - Reranking options:
      - `:top_n` - Return only top N after reranking
      - `:model` - Specific reranking model to use

  ## Returns

    - `{:ok, items}` - Reranked items with updated scores
    - `{:error, reason}` on failure
  """
  @callback rerank(query(), [item()], opts :: keyword()) ::
              {:ok, [reranked_item()]} | {:error, term()}

  @doc """
  Get the name of the reranking model.

  ## Returns

    - String identifying the model
  """
  @callback model_name() :: String.t()
end
