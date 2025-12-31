defmodule PortfolioCore.Ports.CollectionSelector do
  @moduledoc """
  Behaviour for selecting relevant collections/indexes to search.
  Enables intelligent routing of queries to appropriate data sources.

  ## How Collection Selection Works

  1. Receives a query and list of available collections with metadata
  2. Analyzes the query to determine which collections are most relevant
  3. Returns selected collections with optional reasoning and confidence

  ## Example Implementation

      defmodule MyApp.Adapters.LLMCollectionSelector do
        @behaviour PortfolioCore.Ports.CollectionSelector

        @impl true
        def select(query, available_collections, opts) do
          # Use LLM to select relevant collections
          llm = Keyword.fetch!(opts, :llm)

          prompt = build_selection_prompt(query, available_collections)
          case llm.complete(prompt, opts) do
            {:ok, response} ->
              {:ok, %{
                selected: parse_selected(response),
                reasoning: parse_reasoning(response),
                confidence: nil
              }}
            {:error, reason} ->
              {:error, reason}
          end
        end
      end

  ## Using Collection Selector

      collections = [
        %{name: "api_docs", description: "API reference documentation"},
        %{name: "tutorials", description: "Getting started tutorials"},
        %{name: "faq", description: "Frequently asked questions"}
      ]

      {:ok, result} = MySelector.select("How do I authenticate?", collections, llm: my_llm)
      result.selected
      # => ["api_docs", "faq"]
  """

  @type selection_result :: %{
          selected: [String.t()],
          reasoning: String.t() | nil,
          confidence: float() | nil
        }

  @type collection_info :: %{
          name: String.t(),
          description: String.t() | nil,
          document_count: non_neg_integer() | nil
        }

  @doc """
  Select relevant collections for a query.

  Analyzes the query and available collections to determine which
  collections should be searched. Returns a result with selected
  collection names, optional reasoning, and optional confidence score.

  ## Parameters

    - `query` - The search query string
    - `available_collections` - List of available collection info maps
    - `opts` - Options for selection:
      - `:max_collections` - Maximum number of collections to select
      - `:llm` - LLM module or function for LLM-based selection
      - `:context` - Additional context for selection decisions

  ## Returns

    - `{:ok, selection_result}` - Map with selected collections, reasoning, and confidence
    - `{:error, reason}` on failure

  ## Examples

      # Basic selection
      {:ok, result} = MySelector.select("API authentication", collections, [])
      result.selected
      # => ["api_docs"]

      # With max collections limit
      {:ok, result} = MySelector.select(query, collections, max_collections: 2)
      length(result.selected)
      # => 2

      # With reasoning
      result.reasoning
      # => "Selected api_docs because query mentions API endpoints"
  """
  @callback select(
              query :: String.t(),
              available_collections :: [collection_info()],
              opts :: keyword()
            ) :: {:ok, selection_result()} | {:error, term()}
end
