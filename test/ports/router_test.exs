defmodule PortfolioCore.Ports.RouterTest do
  use ExUnit.Case, async: true

  import Mox

  alias PortfolioCore.Mocks.Router, as: MockRouter
  alias PortfolioCore.Ports.Router

  setup :verify_on_exit!

  describe "mock" do
    test "mock module is available" do
      assert Code.ensure_loaded?(MockRouter)
    end
  end

  describe "behaviour" do
    test "defines all required callbacks" do
      callbacks = Router.behaviour_info(:callbacks)

      assert {:route, 2} in callbacks
      assert {:register_provider, 1} in callbacks
      assert {:unregister_provider, 1} in callbacks
      assert {:health_check, 1} in callbacks
      assert {:list_providers, 0} in callbacks
      assert {:set_strategy, 1} in callbacks
      assert {:get_strategy, 0} in callbacks
      assert {:execute, 2} in callbacks
    end

    test "defines optional callbacks" do
      optional = Router.behaviour_info(:optional_callbacks)
      assert {:execute_with_retry, 2} in optional
      refute {:execute, 2} in optional
    end
  end

  describe "typespecs" do
    test "exports type specifications" do
      assert {:ok, types} = Code.Typespec.fetch_types(Router)
      assert is_list(types)
      assert types != []
    end
  end

  describe "documentation" do
    test "has moduledoc" do
      assert {:docs_v1, _, _, _, moduledoc, _, _} = Code.fetch_docs(Router)

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
