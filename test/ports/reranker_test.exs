defmodule PortfolioCore.Ports.RerankerTest do
  use PortfolioCore.SupertesterCase, async: true

  alias PortfolioCore.Ports.Reranker

  describe "behaviour definition" do
    test "defines rerank/3 callback" do
      callbacks = Reranker.behaviour_info(:callbacks)
      assert {:rerank, 3} in callbacks
    end

    test "defines model_name/0 callback" do
      callbacks = Reranker.behaviour_info(:callbacks)
      assert {:model_name, 0} in callbacks
    end

    test "defines normalize_scores/1 as optional callback" do
      optional = Reranker.behaviour_info(:optional_callbacks)
      assert {:normalize_scores, 1} in optional
    end
  end

  describe "mock implementation" do
    defmodule MockReranker do
      @behaviour PortfolioCore.Ports.Reranker

      @impl true
      def rerank(_query, items, _opts) do
        reranked =
          items
          |> Enum.with_index()
          |> Enum.map(fn {item, idx} ->
            %{
              id: "item-#{idx}",
              content: item.content,
              original_score: item.score,
              rerank_score: item.score * 0.9,
              metadata: item.metadata
            }
          end)

        {:ok, reranked}
      end

      @impl true
      def model_name, do: "mock-reranker-v1"

      @impl true
      def normalize_scores(items) do
        max_score = Enum.max_by(items, & &1.rerank_score).rerank_score

        Enum.map(items, fn item ->
          %{item | rerank_score: item.rerank_score / max_score}
        end)
      end
    end

    test "mock implementation satisfies behaviour" do
      items = [
        %{content: "Test 1", score: 0.9, metadata: %{}},
        %{content: "Test 2", score: 0.8, metadata: %{}}
      ]

      {:ok, reranked} = MockReranker.rerank("test query", items, [])

      assert is_list(reranked)
      item = hd(reranked)
      assert Map.has_key?(item, :id)
      assert Map.has_key?(item, :content)
      assert Map.has_key?(item, :original_score)
      assert Map.has_key?(item, :rerank_score)
      assert Map.has_key?(item, :metadata)

      assert MockReranker.model_name() == "mock-reranker-v1"

      normalized = MockReranker.normalize_scores(reranked)
      assert hd(normalized).rerank_score == 1.0
    end
  end
end
