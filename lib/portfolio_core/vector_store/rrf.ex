defmodule PortfolioCore.VectorStore.RRF do
  @moduledoc """
  Helper functions for Reciprocal Rank Fusion (RRF) scoring.

  RRF combines ranked lists by summing weighted reciprocal ranks and
  produces a single list sorted by fused score.
  """

  alias PortfolioCore.Ports.VectorStore

  @default_k 60
  @default_weight 1.0

  @spec calculate_rrf_score(
          [VectorStore.search_result()],
          [VectorStore.search_result()],
          keyword()
        ) :: [VectorStore.search_result()]
  def calculate_rrf_score(semantic_results, fulltext_results, opts) do
    k = Keyword.get(opts, :k, @default_k)
    semantic_weight = Keyword.get(opts, :semantic_weight, @default_weight)
    fulltext_weight = Keyword.get(opts, :fulltext_weight, @default_weight)

    {results, scores} =
      {%{}, %{}}
      |> add_results(semantic_results, semantic_weight, k)
      |> add_results(fulltext_results, fulltext_weight, k)

    results
    |> Enum.map(fn {id, result} ->
      %{result | score: Map.get(scores, id, 0.0)}
    end)
    |> Enum.sort_by(& &1.score, :desc)
  end

  defp add_results({results, scores}, list, weight, k) do
    Enum.with_index(list, 1)
    |> Enum.reduce({results, scores}, fn {result, rank}, {results_acc, scores_acc} ->
      id = Map.fetch!(result, :id)
      rrf_score = weight / (k + rank)

      results_acc =
        Map.update(results_acc, id, result, fn existing ->
          merge_result(existing, result)
        end)

      scores_acc = Map.update(scores_acc, id, rrf_score, &(&1 + rrf_score))

      {results_acc, scores_acc}
    end)
  end

  defp merge_result(existing, incoming) do
    vector =
      case {Map.get(existing, :vector), Map.get(incoming, :vector)} do
        {nil, nil} -> nil
        {nil, new_vector} -> new_vector
        {existing_vector, _} -> existing_vector
      end

    %{existing | vector: vector}
  end
end
