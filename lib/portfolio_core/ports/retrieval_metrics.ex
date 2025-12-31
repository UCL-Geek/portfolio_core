defmodule PortfolioCore.Ports.RetrievalMetrics do
  @moduledoc """
  Behaviour for computing information retrieval quality metrics.
  Measures how well a search system retrieves relevant documents.

  ## Standard Metrics

  All metrics are computed at multiple K values (typically 1, 3, 5, 10):

    * **Recall@K** - Fraction of relevant documents found in top K results
    * **Precision@K** - Fraction of top K results that are relevant
    * **MRR (Mean Reciprocal Rank)** - 1/position of first relevant result
    * **Hit Rate@K** - Binary indicator: did we find any relevant doc in top K?

  ## Example Implementation

      defmodule MyApp.Adapters.StandardMetrics do
        @behaviour PortfolioCore.Ports.RetrievalMetrics

        @impl true
        def compute(expected_ids, retrieved_ids, opts) do
          k_values = Keyword.get(opts, :k_values, [1, 3, 5, 10])
          # ... compute metrics at each K
          {:ok, %{recall_at_k: ..., precision_at_k: ..., mrr: ..., hit_rate_at_k: ...}}
        end

        @impl true
        def aggregate(results) do
          # Average metrics across all test cases
          {:ok, aggregated_metrics}
        end
      end

  ## Evaluation Workflow

  Typical evaluation workflow:

  1. Load test cases with ground truth (expected chunk IDs)
  2. Run search for each test case question
  3. Call `compute/3` for each test case
  4. Call `aggregate/1` to get summary metrics
  """

  @type metric_result :: %{
          recall_at_k: %{pos_integer() => float()},
          precision_at_k: %{pos_integer() => float()},
          mrr: float(),
          hit_rate_at_k: %{pos_integer() => float()}
        }

  @type test_case_result :: %{
          test_case_id: String.t(),
          question: String.t(),
          expected_ids: [String.t()],
          retrieved_ids: [String.t()],
          metrics: metric_result()
        }

  @doc """
  Compute retrieval metrics for a single test case.

  ## Parameters

    - `expected_ids` - List of relevant document/chunk IDs (ground truth)
    - `retrieved_ids` - List of retrieved document/chunk IDs (in rank order)
    - `opts` - Options including:
      - `:k_values` - List of K values to compute metrics at (default [1, 3, 5, 10])

  ## Returns

    - `{:ok, metric_result()}` with metrics at each K value
    - `{:error, reason}` on failure

  ## Example

      expected = ["chunk_abc", "chunk_def"]
      retrieved = ["chunk_abc", "chunk_xyz", "chunk_def", "chunk_123"]

      {:ok, metrics} = Metrics.compute(expected, retrieved, k_values: [1, 3, 5])
      # => %{
      #   recall_at_k: %{1 => 0.5, 3 => 1.0, 5 => 1.0},
      #   precision_at_k: %{1 => 1.0, 3 => 0.67, 5 => 0.4},
      #   mrr: 1.0,
      #   hit_rate_at_k: %{1 => 1.0, 3 => 1.0, 5 => 1.0}
      # }
  """
  @callback compute(
              expected_ids :: [String.t()],
              retrieved_ids :: [String.t()],
              opts :: keyword()
            ) ::
              {:ok, metric_result()} | {:error, term()}

  @doc """
  Aggregate metrics across multiple test cases.

  Takes a list of per-test-case results and computes average metrics.

  ## Parameters

    - `results` - List of test case results, each containing:
      - `:test_case_id` - Unique identifier
      - `:question` - The query text
      - `:expected_ids` - Ground truth chunk IDs
      - `:retrieved_ids` - Retrieved chunk IDs
      - `:metrics` - The computed metrics for this case

  ## Returns

    - `{:ok, metric_result()}` with averaged metrics
    - `{:error, reason}` on failure

  ## Example

      results = [
        %{test_case_id: "1", metrics: %{recall_at_k: %{5 => 1.0}, ...}},
        %{test_case_id: "2", metrics: %{recall_at_k: %{5 => 0.5}, ...}}
      ]

      {:ok, aggregated} = Metrics.aggregate(results)
      # => %{recall_at_k: %{5 => 0.75}, ...}
  """
  @callback aggregate(results :: [test_case_result()]) ::
              {:ok, metric_result()} | {:error, term()}
end
