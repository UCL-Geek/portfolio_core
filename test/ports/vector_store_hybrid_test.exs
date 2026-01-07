defmodule PortfolioCore.Ports.VectorStore.HybridTest do
  use PortfolioCore.SupertesterCase, async: true

  alias PortfolioCore.Ports.VectorStore.Hybrid

  describe "behaviour definition" do
    test "defines fulltext_search/4 callback" do
      callbacks = Hybrid.behaviour_info(:callbacks)
      assert {:fulltext_search, 4} in callbacks
    end
  end

  describe "hybrid_search/6" do
    defmodule DummyHybrid do
      def search(_index_id, _vector, _k, _opts) do
        {:ok,
         [
           %{id: "shared", score: 0.9, metadata: %{}, vector: nil},
           %{id: "semantic", score: 0.8, metadata: %{}, vector: nil}
         ]}
      end

      def fulltext_search(_index_id, _query, _k, _opts) do
        {:ok,
         [
           %{id: "shared", score: 12.0, metadata: %{}, vector: nil},
           %{id: "fulltext", score: 10.0, metadata: %{}, vector: nil}
         ]}
      end
    end

    defmodule ErrorHybrid do
      def search(_index_id, _vector, _k, _opts), do: {:error, :search_failed}
      def fulltext_search(_index_id, _query, _k, _opts), do: {:ok, []}
    end

    test "combines semantic and fulltext results" do
      {:ok, results} = Hybrid.hybrid_search(DummyHybrid, "idx", [0.1], "query", 5, [])

      assert Enum.map(results, & &1.id) |> Enum.sort() == ["fulltext", "semantic", "shared"]
      assert hd(results).id == "shared"
      assert Enum.all?(results, &is_float(&1.score))
    end

    test "propagates errors from semantic search" do
      assert {:error, :search_failed} ==
               Hybrid.hybrid_search(ErrorHybrid, "idx", [0.1], "query", 5, [])
    end
  end
end
