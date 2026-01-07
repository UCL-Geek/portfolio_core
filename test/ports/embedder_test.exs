defmodule PortfolioCore.Ports.EmbedderTest do
  use PortfolioCore.SupertesterCase, async: true

  import Mox

  alias PortfolioCore.Mocks.Embedder, as: MockEmbedder

  setup :verify_on_exit!

  describe "embed/2" do
    test "generates embedding for text" do
      result = %{
        vector: List.duplicate(0.1, 1536),
        model: "text-embedding-3-small",
        dimensions: 1536,
        token_count: 10
      }

      expect(MockEmbedder, :embed, fn text, opts ->
        assert text == "Hello, world!"
        assert opts[:model] == "text-embedding-3-small"
        {:ok, result}
      end)

      assert {:ok, %{vector: vector}} =
               MockEmbedder.embed("Hello, world!", model: "text-embedding-3-small")

      assert length(vector) == 1536
    end
  end

  describe "embed_batch/2" do
    test "generates embeddings for multiple texts" do
      texts = ["Hello", "World", "Test"]

      result = %{
        embeddings: [
          %{vector: List.duplicate(0.1, 1536), model: "test", dimensions: 1536, token_count: 1},
          %{vector: List.duplicate(0.2, 1536), model: "test", dimensions: 1536, token_count: 1},
          %{vector: List.duplicate(0.3, 1536), model: "test", dimensions: 1536, token_count: 1}
        ],
        total_tokens: 3
      }

      expect(MockEmbedder, :embed_batch, fn t, _opts ->
        assert length(t) == 3
        {:ok, result}
      end)

      assert {:ok, %{embeddings: embeddings, total_tokens: 3}} =
               MockEmbedder.embed_batch(texts, [])

      assert length(embeddings) == 3
    end
  end

  describe "dimensions/1" do
    test "returns model dimensions" do
      expect(MockEmbedder, :dimensions, fn model ->
        case model do
          "text-embedding-3-small" -> 1536
          "text-embedding-3-large" -> 3072
          _ -> 768
        end
      end)

      assert 1536 == MockEmbedder.dimensions("text-embedding-3-small")
    end
  end

  describe "supported_models/0" do
    test "lists supported models" do
      models = ["text-embedding-3-small", "text-embedding-3-large"]

      expect(MockEmbedder, :supported_models, fn ->
        models
      end)

      assert ^models = MockEmbedder.supported_models()
    end
  end
end
