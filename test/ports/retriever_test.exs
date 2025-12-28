defmodule PortfolioCore.Ports.RetrieverTest do
  use ExUnit.Case, async: true

  alias PortfolioCore.Ports.Retriever

  describe "behaviour definition" do
    test "defines retrieve/3 callback" do
      callbacks = Retriever.behaviour_info(:callbacks)
      assert {:retrieve, 3} in callbacks
    end

    test "defines strategy_name/0 callback" do
      callbacks = Retriever.behaviour_info(:callbacks)
      assert {:strategy_name, 0} in callbacks
    end

    test "defines required_adapters/0 callback" do
      callbacks = Retriever.behaviour_info(:callbacks)
      assert {:required_adapters, 0} in callbacks
    end

    test "defines capability callbacks as optional" do
      optional = Retriever.behaviour_info(:optional_callbacks)
      assert {:supports_embedding?, 0} in optional
      assert {:supports_text_query?, 0} in optional
    end
  end

  describe "mock implementation" do
    defmodule MockRetriever do
      @behaviour PortfolioCore.Ports.Retriever

      @impl true
      def retrieve(_query, _context, _opts) do
        {:ok,
         %{
           items: [
             %{
               id: "doc-1",
               content: "Test content",
               score: 0.95,
               source: "test.md",
               metadata: %{}
             }
           ],
           query: "test",
           strategy: :semantic,
           timing_ms: 50
         }}
      end

      @impl true
      def strategy_name, do: :semantic

      @impl true
      def required_adapters, do: [:vector_store, :embedder]

      @impl true
      def supports_embedding?, do: true

      @impl true
      def supports_text_query?, do: false
    end

    test "mock implementation satisfies behaviour" do
      {:ok, result} = MockRetriever.retrieve("test query", %{}, [])

      assert is_list(result.items)
      item = hd(result.items)
      assert Map.has_key?(item, :id)
      assert Map.has_key?(item, :content)
      assert Map.has_key?(item, :score)
      assert Map.has_key?(item, :source)
      assert Map.has_key?(item, :metadata)

      assert MockRetriever.strategy_name() == :semantic
      assert MockRetriever.required_adapters() == [:vector_store, :embedder]
      assert MockRetriever.supports_embedding?() == true
      assert MockRetriever.supports_text_query?() == false
    end
  end
end
