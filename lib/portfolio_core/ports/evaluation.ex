defmodule PortfolioCore.Ports.Evaluation do
  @moduledoc """
  Port specification for RAG quality evaluation.

  Implements the RAG Triad evaluation framework (TruLens-based):
  - Context Relevance: Is retrieved context relevant to query?
  - Groundedness: Is response supported by context?
  - Answer Relevance: Does answer address the query?

  Also supports hallucination detection for safety verification.

  ## Example Implementation

      defmodule MyApp.Adapters.LLMEvaluator do
        @behaviour PortfolioCore.Ports.Evaluation

        @impl true
        def evaluate_rag_triad(generation, opts) do
          # Use LLM to score each dimension 1-5
        end

        @impl true
        def detect_hallucination(generation, opts) do
          # Check if response is grounded in context
        end
      end

  ## RAG Triad Scores

  Each dimension is scored 1-5:
  - 1 = Very poor
  - 2 = Poor
  - 3 = Acceptable
  - 4 = Good
  - 5 = Excellent

  ## Evaluation Workflow

  Typical evaluation workflow:

  1. Generate response using RAG pipeline
  2. Call `evaluate_rag_triad/2` to assess quality
  3. Optionally call `detect_hallucination/2` for safety check
  4. Log metrics and potentially filter low-quality responses
  """

  @type generation :: %{
          query: String.t(),
          context: String.t(),
          response: String.t(),
          context_sources: [String.t()]
        }

  @type triad_score :: %{
          score: 1..5,
          reasoning: String.t()
        }

  @type triad_result :: %{
          context_relevance: triad_score(),
          groundedness: triad_score(),
          answer_relevance: triad_score(),
          overall: float()
        }

  @type hallucination_result :: %{
          hallucinating: boolean(),
          evidence: String.t()
        }

  @doc """
  Evaluate a RAG generation using the RAG Triad framework.

  ## Parameters

    - `generation` - The generation to evaluate with query, context, and response
    - `opts` - Evaluation options:
      - `:model` - LLM model to use for evaluation
      - `:timeout` - Timeout in milliseconds

  ## Returns

    - `{:ok, result}` with scores for all three dimensions
    - `{:error, reason}` on failure
  """
  @callback evaluate_rag_triad(generation(), opts :: keyword()) ::
              {:ok, triad_result()} | {:error, term()}

  @doc """
  Evaluate context relevance only.

  Measures how well the retrieved context matches the query.

  ## Parameters

    - `generation` - The generation to evaluate
    - `opts` - Evaluation options

  ## Returns

    - `{:ok, score}` with score and reasoning
    - `{:error, reason}` on failure
  """
  @callback evaluate_context_relevance(generation(), opts :: keyword()) ::
              {:ok, triad_score()} | {:error, term()}

  @doc """
  Evaluate groundedness only.

  Measures how well the response is supported by the context.

  ## Parameters

    - `generation` - The generation to evaluate
    - `opts` - Evaluation options

  ## Returns

    - `{:ok, score}` with score and reasoning
    - `{:error, reason}` on failure
  """
  @callback evaluate_groundedness(generation(), opts :: keyword()) ::
              {:ok, triad_score()} | {:error, term()}

  @doc """
  Evaluate answer relevance only.

  Measures how well the response addresses the query.

  ## Parameters

    - `generation` - The generation to evaluate
    - `opts` - Evaluation options

  ## Returns

    - `{:ok, score}` with score and reasoning
    - `{:error, reason}` on failure
  """
  @callback evaluate_answer_relevance(generation(), opts :: keyword()) ::
              {:ok, triad_score()} | {:error, term()}

  @doc """
  Detect if response contains hallucinations.

  Hallucinations are claims in the response that are not supported
  by the provided context.

  ## Parameters

    - `generation` - The generation to check
    - `opts` - Detection options:
      - `:model` - LLM model to use
      - `:strict` - Use strict detection (default: false)

  ## Returns

    - `{:ok, %{hallucinating: false, evidence: "..."}}` if grounded
    - `{:ok, %{hallucinating: true, evidence: "..."}}` if hallucinating
    - `{:error, reason}` on failure
  """
  @callback detect_hallucination(generation(), opts :: keyword()) ::
              {:ok, hallucination_result()} | {:error, term()}

  @optional_callbacks [
    evaluate_context_relevance: 2,
    evaluate_groundedness: 2,
    evaluate_answer_relevance: 2
  ]
end
