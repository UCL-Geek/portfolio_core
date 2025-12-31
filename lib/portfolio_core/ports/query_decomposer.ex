defmodule PortfolioCore.Ports.QueryDecomposer do
  @moduledoc """
  Behaviour for query decomposition - breaking complex questions into sub-questions.

  Query decomposition improves retrieval for multi-faceted queries by:
  - Identifying multiple aspects of a question
  - Breaking comparison questions into separate searches
  - Handling multi-hop reasoning requirements
  - Enabling parallel retrieval for each sub-question

  ## Example Implementation

      defmodule MyApp.Adapters.LLMDecomposer do
        @behaviour PortfolioCore.Ports.QueryDecomposer

        @impl true
        def decompose(query, opts) do
          # Call LLM to analyze and decompose
          {:ok, %{original: query, sub_questions: questions, is_complex: true}}
        end
      end

  ## Usage in Pipeline

      ctx
      |> QueryProcessor.rewrite()
      |> QueryProcessor.expand()
      |> QueryProcessor.decompose(decomposer: MyApp.Adapters.LLMDecomposer)
      |> Retriever.search()  # Searches each sub-question
  """

  @type decomposition_result :: %{
          original: String.t(),
          sub_questions: [String.t()],
          is_complex: boolean()
        }

  @doc """
  Decompose a complex question into simpler sub-questions.

  ## Parameters

    - `query` - The complex question to decompose
    - `opts` - Decomposer options:
      - `:llm` - LLM module or function for decomposition
      - `:prompt` - Custom prompt template
      - `:max_sub_questions` - Maximum number of sub-questions (default: 4)

  ## Returns

    - `{:ok, result}` with:
      - `:original` - The original question
      - `:sub_questions` - List of simpler questions (may be just the original)
      - `:is_complex` - Whether decomposition was needed
    - `{:error, reason}` on failure

  ## Examples

      # Complex comparison question
      {:ok, result} = MyDecomposer.decompose("Compare Elixir and Go for web services", [])
      result.sub_questions
      # => ["What are Elixir's strengths for web services?",
      #     "What are Go's strengths for web services?",
      #     "How do they compare for performance?"]
      result.is_complex
      # => true

      # Simple question - no decomposition needed
      {:ok, result} = MyDecomposer.decompose("What is pattern matching?", [])
      result.sub_questions
      # => ["What is pattern matching?"]
      result.is_complex
      # => false
  """
  @callback decompose(query :: String.t(), opts :: keyword()) ::
              {:ok, decomposition_result()} | {:error, term()}
end
