defmodule PortfolioCore.Ports.CollectionSelectorTest do
  use ExUnit.Case, async: true

  alias PortfolioCore.Ports.CollectionSelector

  describe "behaviour definition" do
    test "defines select/3 callback" do
      callbacks = CollectionSelector.behaviour_info(:callbacks)
      assert {:select, 3} in callbacks
    end
  end

  describe "mock implementation" do
    defmodule MockCollectionSelector do
      @behaviour PortfolioCore.Ports.CollectionSelector

      @impl true
      def select(_query, available_collections, opts) do
        max_collections = Keyword.get(opts, :max_collections, 3)

        selected =
          available_collections
          |> Enum.take(max_collections)
          |> Enum.map(& &1.name)

        {:ok,
         %{
           selected: selected,
           reasoning: "Mock selection reasoning",
           confidence: 0.85
         }}
      end
    end

    test "mock implementation satisfies behaviour" do
      collections = [
        %{name: "docs", description: "Documentation", document_count: 100},
        %{name: "api", description: "API reference", document_count: 50},
        %{name: "faq", description: "FAQ", document_count: 25}
      ]

      {:ok, result} = MockCollectionSelector.select("test query", collections, [])

      assert is_list(result.selected)
      assert is_binary(result.reasoning)
      assert is_float(result.confidence)
      assert result.selected == ["docs", "api", "faq"]
    end

    test "respects max_collections option" do
      collections = [
        %{name: "docs", description: "Documentation", document_count: 100},
        %{name: "api", description: "API reference", document_count: 50},
        %{name: "faq", description: "FAQ", document_count: 25}
      ]

      {:ok, result} = MockCollectionSelector.select("test query", collections, max_collections: 2)

      assert length(result.selected) == 2
      assert result.selected == ["docs", "api"]
    end

    test "handles empty collections list" do
      {:ok, result} = MockCollectionSelector.select("test query", [], [])

      assert result.selected == []
    end

    test "handles collection_info with nil fields" do
      collections = [
        %{name: "docs", description: nil, document_count: nil}
      ]

      {:ok, result} = MockCollectionSelector.select("test query", collections, [])

      assert result.selected == ["docs"]
    end
  end

  describe "error handling mock" do
    defmodule ErrorMockSelector do
      @behaviour PortfolioCore.Ports.CollectionSelector

      @impl true
      def select(_query, _collections, _opts) do
        {:error, :llm_error}
      end
    end

    test "can return error tuple" do
      collections = [%{name: "docs", description: "Test", document_count: 10}]

      assert {:error, :llm_error} = ErrorMockSelector.select("query", collections, [])
    end
  end
end
