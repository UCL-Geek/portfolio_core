defmodule PortfolioCore.Ports.QueryExpanderTest do
  use ExUnit.Case, async: true

  alias PortfolioCore.Ports.QueryExpander

  describe "behaviour definition" do
    test "defines expand/2 callback" do
      callbacks = QueryExpander.behaviour_info(:callbacks)
      assert {:expand, 2} in callbacks
    end
  end

  describe "mock implementation" do
    defmodule MockExpander do
      @behaviour PortfolioCore.Ports.QueryExpander

      @synonyms %{
        "ML" => ["machine learning", "deep learning"],
        "GenServer" => ["gen_server", "OTP server"],
        "API" => ["application programming interface", "web service"]
      }

      @impl true
      def expand(query, _opts) do
        # Simple mock: add synonyms for known terms
        terms = String.split(query, ~r/\s+/)

        added_terms =
          terms
          |> Enum.flat_map(fn term ->
            Map.get(@synonyms, term, [])
          end)

        expanded =
          if added_terms == [] do
            query
          else
            query <> " " <> Enum.join(added_terms, " ")
          end

        {:ok,
         %{
           original: query,
           expanded: expanded,
           added_terms: added_terms
         }}
      end
    end

    test "mock implementation satisfies behaviour" do
      query = "ML models"

      {:ok, result} = MockExpander.expand(query, [])

      assert is_map(result)
      assert result.original == query
      assert is_binary(result.expanded)
      assert is_list(result.added_terms)
    end

    test "expands abbreviations" do
      {:ok, result} = MockExpander.expand("ML models", [])

      assert String.contains?(result.expanded, "machine learning")
      assert "machine learning" in result.added_terms
    end

    test "expands technical terms" do
      {:ok, result} = MockExpander.expand("GenServer implementation", [])

      assert String.contains?(result.expanded, "OTP server")
    end

    test "handles queries without expansion" do
      {:ok, result} = MockExpander.expand("Elixir programming", [])

      assert result.expanded == "Elixir programming"
      assert result.added_terms == []
    end
  end

  describe "error handling" do
    defmodule FailingExpander do
      @behaviour PortfolioCore.Ports.QueryExpander

      @impl true
      def expand(_query, _opts) do
        {:error, :expansion_failed}
      end
    end

    test "returns error tuple on failure" do
      assert {:error, :expansion_failed} = FailingExpander.expand("test", [])
    end
  end
end
