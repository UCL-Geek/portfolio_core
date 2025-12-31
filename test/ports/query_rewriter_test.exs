defmodule PortfolioCore.Ports.QueryRewriterTest do
  use ExUnit.Case, async: true

  alias PortfolioCore.Ports.QueryRewriter

  describe "behaviour definition" do
    test "defines rewrite/2 callback" do
      callbacks = QueryRewriter.behaviour_info(:callbacks)
      assert {:rewrite, 2} in callbacks
    end
  end

  describe "mock implementation" do
    defmodule MockRewriter do
      @behaviour PortfolioCore.Ports.QueryRewriter

      @impl true
      def rewrite(query, _opts) do
        # Simple mock: remove common greetings
        cleaned =
          query
          |> String.replace(~r/^(hey|hi|hello)[,!]?\s*/i, "")
          |> String.replace(~r/^(can you|could you|please)\s+/i, "")
          |> String.trim()

        {:ok,
         %{
           original: query,
           rewritten: cleaned,
           changes_made: ["removed greeting", "removed politeness markers"]
         }}
      end
    end

    test "mock implementation satisfies behaviour" do
      query = "Hey, can you tell me about Elixir?"

      {:ok, result} = MockRewriter.rewrite(query, [])

      assert is_map(result)
      assert result.original == query
      assert is_binary(result.rewritten)
      assert is_list(result.changes_made)
    end

    test "rewrite removes conversational noise" do
      {:ok, result} = MockRewriter.rewrite("Hello, please help me understand GenServer", [])

      assert result.original == "Hello, please help me understand GenServer"
      assert result.rewritten == "help me understand GenServer"
    end

    test "handles already clean queries" do
      {:ok, result} = MockRewriter.rewrite("What is pattern matching?", [])

      assert result.rewritten == "What is pattern matching?"
    end
  end

  describe "error handling" do
    defmodule FailingRewriter do
      @behaviour PortfolioCore.Ports.QueryRewriter

      @impl true
      def rewrite(_query, _opts) do
        {:error, :llm_unavailable}
      end
    end

    test "returns error tuple on failure" do
      assert {:error, :llm_unavailable} = FailingRewriter.rewrite("test", [])
    end
  end
end
