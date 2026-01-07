defmodule PortfolioCore.Ports.QueryDecomposerTest do
  use PortfolioCore.SupertesterCase, async: true

  alias PortfolioCore.Ports.QueryDecomposer

  describe "behaviour definition" do
    test "defines decompose/2 callback" do
      callbacks = QueryDecomposer.behaviour_info(:callbacks)
      assert {:decompose, 2} in callbacks
    end
  end

  describe "mock implementation" do
    defmodule MockDecomposer do
      @behaviour PortfolioCore.Ports.QueryDecomposer

      @impl true
      def decompose(query, _opts) do
        # Simple mock: split on "and" or detect complexity
        cond do
          String.contains?(query, " and ") ->
            parts = String.split(query, " and ")

            {:ok,
             %{
               original: query,
               sub_questions: Enum.map(parts, &String.trim/1),
               is_complex: true
             }}

          String.contains?(query, "compare") ->
            # Extract entities being compared
            {:ok,
             %{
               original: query,
               sub_questions: [
                 "What are the features of the first item?",
                 "What are the features of the second item?",
                 "How do they compare?"
               ],
               is_complex: true
             }}

          true ->
            {:ok,
             %{
               original: query,
               sub_questions: [query],
               is_complex: false
             }}
        end
      end
    end

    test "mock implementation satisfies behaviour" do
      query = "What is Elixir?"

      {:ok, result} = MockDecomposer.decompose(query, [])

      assert is_map(result)
      assert result.original == query
      assert is_list(result.sub_questions)
      assert is_boolean(result.is_complex)
    end

    test "decomposes multi-part questions" do
      {:ok, result} = MockDecomposer.decompose("What is Elixir and what is Erlang?", [])

      assert result.is_complex == true
      assert length(result.sub_questions) == 2
      assert "What is Elixir" in result.sub_questions
      assert "what is Erlang?" in result.sub_questions
    end

    test "decomposes comparison questions" do
      {:ok, result} = MockDecomposer.decompose("compare Elixir and Go", [])

      assert result.is_complex == true
      assert length(result.sub_questions) >= 2
    end

    test "simple questions return unchanged" do
      {:ok, result} = MockDecomposer.decompose("What is pattern matching?", [])

      assert result.is_complex == false
      assert result.sub_questions == ["What is pattern matching?"]
    end
  end

  describe "error handling" do
    defmodule FailingDecomposer do
      @behaviour PortfolioCore.Ports.QueryDecomposer

      @impl true
      def decompose(_query, _opts) do
        {:error, :decomposition_failed}
      end
    end

    test "returns error tuple on failure" do
      assert {:error, :decomposition_failed} = FailingDecomposer.decompose("test", [])
    end
  end
end
