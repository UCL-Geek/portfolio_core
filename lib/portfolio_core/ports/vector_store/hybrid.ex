defmodule PortfolioCore.Ports.VectorStore.Hybrid do
  @moduledoc """
  Behavior for vector stores that support hybrid (semantic + fulltext) search.

  Implementers should also satisfy `PortfolioCore.Ports.VectorStore` and expose
  `fulltext_search/4` for keyword-based retrieval.
  """

  alias PortfolioCore.Ports.VectorStore
  alias PortfolioCore.VectorStore.RRF

  @type index_id :: VectorStore.index_id()
  @type vector :: VectorStore.vector()
  @type search_result :: VectorStore.search_result()

  @doc """
  Perform full-text search on stored content.
  """
  @callback fulltext_search(
              index_id(),
              query :: String.t(),
              k :: pos_integer(),
              opts :: keyword()
            ) ::
              {:ok, [search_result()]} | {:error, term()}

  @doc """
  Execute hybrid search using semantic and fulltext results.

  Uses `PortfolioCore.VectorStore.RRF.calculate_rrf_score/3` to merge ranks.
  """
  @spec hybrid_search(module(), index_id(), vector(), String.t(), pos_integer(), keyword()) ::
          {:ok, [search_result()]} | {:error, term()}
  def hybrid_search(store_module, index_id, vector, query, k, opts) do
    semantic_opts = Keyword.get(opts, :semantic_opts, opts)
    fulltext_opts = Keyword.get(opts, :fulltext_opts, opts)

    with {:ok, semantic_results} <- store_module.search(index_id, vector, k, semantic_opts),
         {:ok, fulltext_results} <-
           store_module.fulltext_search(index_id, query, k, fulltext_opts) do
      {:ok, RRF.calculate_rrf_score(semantic_results, fulltext_results, opts)}
    end
  end
end
