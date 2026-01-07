defmodule PortfolioCore.Ports.AgentTest do
  use PortfolioCore.SupertesterCase, async: true

  import Mox

  alias PortfolioCore.Mocks.Agent, as: MockAgent
  alias PortfolioCore.Ports.Agent

  setup :verify_on_exit!

  describe "mock" do
    test "mock module is available" do
      assert Code.ensure_loaded?(MockAgent)
    end
  end

  describe "behaviour" do
    test "defines all required callbacks" do
      callbacks = Agent.behaviour_info(:callbacks)

      assert {:run, 2} in callbacks
      assert {:available_tools, 0} in callbacks
      assert {:execute_tool, 1} in callbacks
      assert {:max_iterations, 0} in callbacks
      assert {:get_state, 0} in callbacks
      assert {:process, 3} in callbacks
      assert {:process_with_tools, 4} in callbacks
    end

    test "defines optional callbacks" do
      optional = Agent.behaviour_info(:optional_callbacks)
      assert {:get_state, 0} in optional
      refute {:process, 3} in optional
      refute {:process_with_tools, 4} in optional
    end
  end

  describe "typespecs" do
    test "exports type specifications" do
      assert {:ok, types} = Code.Typespec.fetch_types(Agent)
      assert is_list(types)
      assert types != []
    end
  end

  describe "documentation" do
    test "has moduledoc" do
      assert {:docs_v1, _, _, _, moduledoc, _, _} = Code.fetch_docs(Agent)

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
