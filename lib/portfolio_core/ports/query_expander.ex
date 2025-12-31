defmodule PortfolioCore.Ports.QueryExpander do
  @moduledoc """
  Behaviour for query expansion - adding synonyms and related terms.

  Query expansion improves retrieval recall by:
  - Adding synonyms for key terms
  - Expanding abbreviations and acronyms (ML -> machine learning)
  - Including related technical terms
  - Adding alternative phrasings

  ## Example Implementation

      defmodule MyApp.Adapters.LLMExpander do
        @behaviour PortfolioCore.Ports.QueryExpander

        @impl true
        def expand(query, opts) do
          # Call LLM to expand the query
          {:ok, %{original: query, expanded: expanded, added_terms: terms}}
        end
      end

  ## Usage in Pipeline

      ctx
      |> QueryProcessor.rewrite()
      |> QueryProcessor.expand(expander: MyApp.Adapters.LLMExpander)
      |> Retriever.search()
  """

  @type expansion_result :: %{
          original: String.t(),
          expanded: String.t(),
          added_terms: [String.t()]
        }

  @doc """
  Expand a query with synonyms and related terms.

  ## Parameters

    - `query` - The query to expand
    - `opts` - Expander options:
      - `:llm` - LLM module or function for expansion
      - `:prompt` - Custom prompt template
      - `:max_terms` - Maximum number of terms to add

  ## Returns

    - `{:ok, result}` with:
      - `:original` - The original query
      - `:expanded` - The expanded query with additional terms
      - `:added_terms` - List of terms that were added
    - `{:error, reason}` on failure

  ## Examples

      {:ok, result} = MyExpander.expand("ML models", [])
      result.expanded
      # => "ML machine learning models neural networks"

      {:ok, result} = MyExpander.expand("GenServer", [])
      result.added_terms
      # => ["gen_server", "OTP", "process"]
  """
  @callback expand(query :: String.t(), opts :: keyword()) ::
              {:ok, expansion_result()} | {:error, term()}
end
