defmodule PortfolioCore.Ports.VectorStoreTest do
  use ExUnit.Case, async: true

  import Mox

  alias PortfolioCore.Mocks.VectorStore, as: MockVectorStore

  setup :verify_on_exit!

  describe "store/4" do
    test "stores vector with metadata" do
      expect(MockVectorStore, :store, fn index_id, id, vector, metadata ->
        assert index_id == "test_index"
        assert id == "vec_1"
        assert length(vector) == 3
        assert metadata == %{source: "test"}
        :ok
      end)

      assert :ok ==
               MockVectorStore.store(
                 "test_index",
                 "vec_1",
                 [0.1, 0.2, 0.3],
                 %{source: "test"}
               )
    end
  end

  describe "search/4" do
    test "returns ranked results" do
      results = [
        %{id: "vec_1", score: 0.95, metadata: %{}, vector: nil},
        %{id: "vec_2", score: 0.87, metadata: %{}, vector: nil}
      ]

      expect(MockVectorStore, :search, fn _index, _vector, k, _opts ->
        assert k == 10
        {:ok, results}
      end)

      assert {:ok, ^results} =
               MockVectorStore.search(
                 "test_index",
                 [0.1, 0.2, 0.3],
                 10,
                 []
               )
    end
  end

  describe "create_index/2" do
    test "creates index with config" do
      config = %{
        dimensions: 1536,
        metric: :cosine,
        index_type: :hnsw,
        options: %{}
      }

      expect(MockVectorStore, :create_index, fn index_id, config ->
        assert index_id == "my_index"
        assert config.dimensions == 1536
        :ok
      end)

      assert :ok == MockVectorStore.create_index("my_index", config)
    end
  end

  describe "store_batch/2" do
    test "stores multiple vectors" do
      items = [
        {"vec_1", [0.1, 0.2, 0.3], %{source: "a"}},
        {"vec_2", [0.4, 0.5, 0.6], %{source: "b"}},
        {"vec_3", [0.7, 0.8, 0.9], %{source: "c"}}
      ]

      expect(MockVectorStore, :store_batch, fn _index_id, batch ->
        assert length(batch) == 3
        {:ok, 3}
      end)

      assert {:ok, 3} == MockVectorStore.store_batch("test_index", items)
    end
  end

  describe "delete/2" do
    test "deletes vector by id" do
      expect(MockVectorStore, :delete, fn index_id, id ->
        assert index_id == "test_index"
        assert id == "vec_1"
        :ok
      end)

      assert :ok == MockVectorStore.delete("test_index", "vec_1")
    end

    test "returns error for non-existent vector" do
      expect(MockVectorStore, :delete, fn _index_id, _id ->
        {:error, :not_found}
      end)

      assert {:error, :not_found} == MockVectorStore.delete("test_index", "missing")
    end
  end

  describe "index_stats/1" do
    test "returns index statistics" do
      stats = %{
        count: 1000,
        dimensions: 1536,
        metric: :cosine,
        size_bytes: 6_144_000
      }

      expect(MockVectorStore, :index_stats, fn index_id ->
        assert index_id == "test_index"
        {:ok, stats}
      end)

      assert {:ok, ^stats} = MockVectorStore.index_stats("test_index")
    end
  end

  describe "behaviour - enhanced callbacks" do
    alias PortfolioCore.Ports.VectorStore

    test "defines fulltext_search as optional callback" do
      optional = VectorStore.behaviour_info(:optional_callbacks)
      assert {:fulltext_search, 4} in optional
    end

    test "does not expose calculate_rrf_score callback" do
      callbacks = VectorStore.behaviour_info(:callbacks)
      optional = VectorStore.behaviour_info(:optional_callbacks)

      refute {:calculate_rrf_score, 3} in callbacks
      refute {:calculate_rrf_score, 3} in optional
    end
  end
end
