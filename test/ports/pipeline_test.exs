defmodule PortfolioCore.Ports.PipelineTest do
  use ExUnit.Case, async: true

  import Mox

  alias PortfolioCore.Mocks.Pipeline, as: MockPipeline
  alias PortfolioCore.Ports.Pipeline

  setup :verify_on_exit!

  describe "mock" do
    test "mock module is available" do
      assert Code.ensure_loaded?(MockPipeline)
    end
  end

  describe "behaviour" do
    test "defines all required callbacks" do
      callbacks = Pipeline.behaviour_info(:callbacks)

      assert {:execute, 2} in callbacks
      assert {:validate_input, 1} in callbacks
      assert {:output_schema, 0} in callbacks
      assert {:required_inputs, 0} in callbacks
      assert {:cacheable?, 0} in callbacks
      assert {:estimated_duration, 0} in callbacks
    end

    test "defines optional callbacks" do
      optional = Pipeline.behaviour_info(:optional_callbacks)

      assert {:validate_input, 1} in optional
      assert {:estimated_duration, 0} in optional
    end
  end

  describe "typespecs" do
    test "exports type specifications" do
      assert {:ok, types} = Code.Typespec.fetch_types(Pipeline)
      assert is_list(types)
      assert types != []
    end
  end

  describe "documentation" do
    test "has moduledoc" do
      assert {:docs_v1, _, _, _, moduledoc, _, _} = Code.fetch_docs(Pipeline)

      doc =
        case moduledoc do
          %{"en" => text} -> text
          {"en", text} -> text
          _ -> nil
        end

      assert is_binary(doc)
      assert String.length(doc) > 0
    end
  end
end
