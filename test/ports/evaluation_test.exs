defmodule PortfolioCore.Ports.EvaluationTest do
  use ExUnit.Case, async: true

  alias PortfolioCore.Ports.Evaluation

  describe "behaviour definition" do
    test "defines evaluate_rag_triad/2 callback" do
      callbacks = Evaluation.behaviour_info(:callbacks)
      assert {:evaluate_rag_triad, 2} in callbacks
    end

    test "defines detect_hallucination/2 callback" do
      callbacks = Evaluation.behaviour_info(:callbacks)
      assert {:detect_hallucination, 2} in callbacks
    end

    test "defines optional callbacks for individual evaluations" do
      optional = Evaluation.behaviour_info(:optional_callbacks)
      assert {:evaluate_context_relevance, 2} in optional
      assert {:evaluate_groundedness, 2} in optional
      assert {:evaluate_answer_relevance, 2} in optional
    end

    test "all required callbacks are defined" do
      callbacks = Evaluation.behaviour_info(:callbacks)
      optional = Evaluation.behaviour_info(:optional_callbacks)
      all_callbacks = callbacks ++ optional

      assert {:evaluate_rag_triad, 2} in all_callbacks
      assert {:detect_hallucination, 2} in all_callbacks
      assert {:evaluate_context_relevance, 2} in all_callbacks
      assert {:evaluate_groundedness, 2} in all_callbacks
      assert {:evaluate_answer_relevance, 2} in all_callbacks
    end
  end

  describe "mock implementation" do
    defmodule MockEvaluator do
      @behaviour PortfolioCore.Ports.Evaluation

      @impl true
      def evaluate_rag_triad(_generation, _opts) do
        {:ok,
         %{
           context_relevance: %{score: 4, reasoning: "Relevant context"},
           groundedness: %{score: 5, reasoning: "Well grounded"},
           answer_relevance: %{score: 4, reasoning: "Addresses query"},
           overall: 4.33
         }}
      end

      @impl true
      def detect_hallucination(_generation, _opts) do
        {:ok, %{hallucinating: false, evidence: "All claims supported"}}
      end
    end

    test "mock implementation satisfies behaviour" do
      generation = %{
        query: "What is Elixir?",
        context: "Elixir is a functional programming language.",
        response: "Elixir is a functional language built on the Erlang VM.",
        context_sources: ["docs/elixir.md"]
      }

      assert {:ok, result} = MockEvaluator.evaluate_rag_triad(generation, [])
      assert result.context_relevance.score in 1..5
      assert result.groundedness.score in 1..5
      assert result.answer_relevance.score in 1..5
      assert is_float(result.overall)

      assert {:ok, hallucination_result} = MockEvaluator.detect_hallucination(generation, [])
      assert is_boolean(hallucination_result.hallucinating)
      assert is_binary(hallucination_result.evidence)
    end
  end
end
