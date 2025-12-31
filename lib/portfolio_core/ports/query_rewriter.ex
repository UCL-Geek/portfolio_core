defmodule PortfolioCore.Ports.QueryRewriter do
  @moduledoc """
  Behaviour for query rewriting - transforming conversational input into clean search queries.

  Query rewriting improves search quality by:
  - Removing greetings and filler phrases ("Hey, can you...")
  - Extracting the core question from conversational context
  - Preserving technical terms and entity names
  - Standardizing query format for better embedding similarity

  ## Example Implementation

      defmodule MyApp.Adapters.LLMRewriter do
        @behaviour PortfolioCore.Ports.QueryRewriter

        @impl true
        def rewrite(query, opts) do
          # Call LLM to clean the query
          {:ok, %{original: query, rewritten: cleaned, changes_made: []}}
        end
      end

  ## Usage in Pipeline

      ctx
      |> QueryProcessor.rewrite(rewriter: MyApp.Adapters.LLMRewriter)
      |> QueryProcessor.expand()
      |> Retriever.search()
  """

  @type rewrite_result :: %{
          original: String.t(),
          rewritten: String.t(),
          changes_made: [String.t()]
        }

  @doc """
  Rewrite a conversational query into a clean search query.

  ## Parameters

    - `query` - The original user query, potentially with conversational elements
    - `opts` - Rewriter options:
      - `:llm` - LLM module or function for rewriting
      - `:prompt` - Custom prompt template
      - `:context` - Additional context for rewriting

  ## Returns

    - `{:ok, result}` with:
      - `:original` - The original query
      - `:rewritten` - The cleaned query
      - `:changes_made` - List of changes applied (for debugging)
    - `{:error, reason}` on failure

  ## Examples

      {:ok, result} = MyRewriter.rewrite("Hey, what is Elixir?", [])
      result.rewritten
      # => "what is Elixir"

      {:ok, result} = MyRewriter.rewrite("Can you help me understand GenServer?", [])
      result.rewritten
      # => "understand GenServer"
  """
  @callback rewrite(query :: String.t(), opts :: keyword()) ::
              {:ok, rewrite_result()} | {:error, term()}
end
