defmodule PortfolioCore.VectorStore.RRFTest do
  use PortfolioCore.SupertesterCase, async: true

  alias PortfolioCore.VectorStore.RRF

  describe "calculate_rrf_score/3" do
    test "merges and ranks results with defaults" do
      semantic_results = [
        %{id: "a", score: 0.9, metadata: %{source: :semantic}, vector: nil},
        %{id: "b", score: 0.8, metadata: %{source: :semantic}, vector: nil}
      ]

      fulltext_results = [
        %{id: "b", score: 12.0, metadata: %{source: :fulltext}, vector: [1.0]},
        %{id: "c", score: 10.0, metadata: %{source: :fulltext}, vector: nil}
      ]

      results = RRF.calculate_rrf_score(semantic_results, fulltext_results, [])

      assert Enum.map(results, & &1.id) == ["b", "a", "c"]

      top = hd(results)
      assert top.id == "b"
      assert is_float(top.score)
      assert top.metadata == %{source: :semantic}
      assert top.vector == [1.0]
    end

    test "applies weights and k parameter" do
      semantic_results = [
        %{id: "a", score: 0.9, metadata: %{}, vector: nil}
      ]

      results =
        RRF.calculate_rrf_score(semantic_results, [],
          k: 50,
          semantic_weight: 2.0
        )

      assert [%{id: "a", score: score}] = results
      assert_in_delta score, 2.0 / 51.0, 0.0001
    end
  end
end
