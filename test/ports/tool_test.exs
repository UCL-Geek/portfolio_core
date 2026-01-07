defmodule PortfolioCore.Ports.ToolTest do
  use PortfolioCore.SupertesterCase, async: true

  import Mox

  alias PortfolioCore.Mocks.Tool, as: MockTool
  alias PortfolioCore.Ports.Tool

  setup :verify_on_exit!

  describe "mock" do
    test "mock module is available" do
      assert Code.ensure_loaded?(MockTool)
    end
  end

  describe "behaviour" do
    test "defines all required callbacks" do
      callbacks = Tool.behaviour_info(:callbacks)

      assert {:name, 0} in callbacks
      assert {:description, 0} in callbacks
      assert {:parameters, 0} in callbacks
      assert {:execute, 1} in callbacks
      assert {:idempotent?, 0} in callbacks
    end

    test "defines optional callbacks" do
      optional = Tool.behaviour_info(:optional_callbacks)
      assert {:idempotent?, 0} in optional
    end
  end

  describe "typespecs" do
    test "exports type specifications" do
      assert {:ok, types} = Code.Typespec.fetch_types(Tool)
      assert is_list(types)
      assert types != []
    end
  end

  describe "documentation" do
    test "has moduledoc" do
      assert {:docs_v1, _, _, _, moduledoc, _, _} = Code.fetch_docs(Tool)

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
