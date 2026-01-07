defmodule PortfolioCore.Ports.RetrievalMetricsTest do
  use PortfolioCore.SupertesterCase, async: true

  alias PortfolioCore.Ports.RetrievalMetrics

  describe "behaviour definition" do
    test "defines compute/3 callback" do
      callbacks = RetrievalMetrics.behaviour_info(:callbacks)
      assert {:compute, 3} in callbacks
    end

    test "defines aggregate/1 callback" do
      callbacks = RetrievalMetrics.behaviour_info(:callbacks)
      assert {:aggregate, 1} in callbacks
    end

    test "all required callbacks are defined" do
      callbacks = RetrievalMetrics.behaviour_info(:callbacks)
      optional = RetrievalMetrics.behaviour_info(:optional_callbacks)
      all_callbacks = callbacks ++ optional

      assert {:compute, 3} in all_callbacks
      assert {:aggregate, 1} in all_callbacks
    end
  end

  describe "mock implementation" do
    defmodule MockRetrievalMetrics do
      @behaviour PortfolioCore.Ports.RetrievalMetrics

      @impl true
      def compute(expected_ids, retrieved_ids, _opts) do
        expected_set = MapSet.new(expected_ids)
        retrieved_set = MapSet.new(retrieved_ids)

        hits = MapSet.intersection(expected_set, retrieved_set) |> MapSet.size()
        expected_count = MapSet.size(expected_set)

        recall = if expected_count > 0, do: hits / expected_count, else: 0.0

        {:ok,
         %{
           recall_at_k: %{1 => recall, 3 => recall, 5 => recall, 10 => recall},
           precision_at_k: %{1 => 1.0, 3 => 0.67, 5 => 0.4, 10 => 0.2},
           mrr: 1.0,
           hit_rate_at_k: %{1 => 1.0, 3 => 1.0, 5 => 1.0, 10 => 1.0}
         }}
      end

      @impl true
      def aggregate(results) when is_list(results) do
        n = length(results)

        if n == 0 do
          {:ok, empty_metrics()}
        else
          # Average all metrics across results
          {:ok,
           %{
             recall_at_k: %{1 => 0.8, 3 => 0.85, 5 => 0.9, 10 => 0.95},
             precision_at_k: %{1 => 1.0, 3 => 0.8, 5 => 0.6, 10 => 0.4},
             mrr: 0.85,
             hit_rate_at_k: %{1 => 0.8, 3 => 0.9, 5 => 0.95, 10 => 1.0}
           }}
        end
      end

      defp empty_metrics do
        %{
          recall_at_k: %{1 => 0.0, 3 => 0.0, 5 => 0.0, 10 => 0.0},
          precision_at_k: %{1 => 0.0, 3 => 0.0, 5 => 0.0, 10 => 0.0},
          mrr: 0.0,
          hit_rate_at_k: %{1 => 0.0, 3 => 0.0, 5 => 0.0, 10 => 0.0}
        }
      end
    end

    test "mock implementation satisfies behaviour" do
      expected_ids = ["chunk1", "chunk2"]
      retrieved_ids = ["chunk1", "chunk3", "chunk4", "chunk5"]

      assert {:ok, result} = MockRetrievalMetrics.compute(expected_ids, retrieved_ids, [])

      # Verify metric_result structure
      assert is_map(result.recall_at_k)
      assert is_map(result.precision_at_k)
      assert is_float(result.mrr)
      assert is_map(result.hit_rate_at_k)

      # Verify K values present
      for k <- [1, 3, 5, 10] do
        assert Map.has_key?(result.recall_at_k, k)
        assert Map.has_key?(result.precision_at_k, k)
        assert Map.has_key?(result.hit_rate_at_k, k)
      end
    end

    test "aggregate handles list of test case results" do
      results = [
        %{
          test_case_id: "tc1",
          question: "What is X?",
          expected_ids: ["c1", "c2"],
          retrieved_ids: ["c1", "c3"],
          metrics: %{
            recall_at_k: %{1 => 0.5, 3 => 0.5, 5 => 0.5, 10 => 0.5},
            precision_at_k: %{1 => 1.0, 3 => 0.33, 5 => 0.2, 10 => 0.1},
            mrr: 1.0,
            hit_rate_at_k: %{1 => 1.0, 3 => 1.0, 5 => 1.0, 10 => 1.0}
          }
        },
        %{
          test_case_id: "tc2",
          question: "What is Y?",
          expected_ids: ["c3"],
          retrieved_ids: ["c4", "c3"],
          metrics: %{
            recall_at_k: %{1 => 0.0, 3 => 1.0, 5 => 1.0, 10 => 1.0},
            precision_at_k: %{1 => 0.0, 3 => 0.33, 5 => 0.2, 10 => 0.1},
            mrr: 0.5,
            hit_rate_at_k: %{1 => 0.0, 3 => 1.0, 5 => 1.0, 10 => 1.0}
          }
        }
      ]

      assert {:ok, aggregated} = MockRetrievalMetrics.aggregate(results)
      assert is_map(aggregated.recall_at_k)
      assert is_map(aggregated.precision_at_k)
      assert is_float(aggregated.mrr)
      assert is_map(aggregated.hit_rate_at_k)
    end

    test "aggregate handles empty list" do
      assert {:ok, result} = MockRetrievalMetrics.aggregate([])

      # All metrics should be 0.0 for empty list
      for k <- [1, 3, 5, 10] do
        assert result.recall_at_k[k] == 0.0
        assert result.precision_at_k[k] == 0.0
        assert result.hit_rate_at_k[k] == 0.0
      end

      assert result.mrr == 0.0
    end

    test "compute handles empty expected_ids" do
      assert {:ok, result} = MockRetrievalMetrics.compute([], ["c1", "c2"], [])
      assert result.recall_at_k[1] == 0.0
    end

    test "compute handles empty retrieved_ids" do
      assert {:ok, result} = MockRetrievalMetrics.compute(["c1", "c2"], [], [])
      assert is_map(result)
    end
  end
end
