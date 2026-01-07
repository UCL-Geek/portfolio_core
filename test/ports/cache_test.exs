defmodule PortfolioCore.Ports.CacheTest do
  use PortfolioCore.SupertesterCase, async: true

  import Mox

  alias PortfolioCore.Mocks.Cache, as: MockCache
  alias PortfolioCore.Ports.Cache

  setup :verify_on_exit!

  describe "mock" do
    test "mock module is available" do
      assert Code.ensure_loaded?(MockCache)
    end
  end

  describe "behaviour" do
    test "defines all required callbacks" do
      callbacks = Cache.behaviour_info(:callbacks)

      assert {:get, 2} in callbacks
      assert {:put, 3} in callbacks
      assert {:delete, 2} in callbacks
      assert {:exists?, 2} in callbacks
      assert {:get_many, 2} in callbacks
      assert {:put_many, 2} in callbacks
      assert {:clear, 1} in callbacks
      assert {:stats, 1} in callbacks
      assert {:touch, 3} in callbacks
    end

    test "defines optional callbacks" do
      optional = Cache.behaviour_info(:optional_callbacks)
      assert {:compute_if_absent, 3} in optional
      assert {:invalidate_pattern, 2} in optional
    end
  end

  describe "typespecs" do
    test "exports type specifications" do
      assert {:ok, types} = Code.Typespec.fetch_types(Cache)
      assert is_list(types)
      assert types != []
    end
  end

  describe "documentation" do
    test "has moduledoc" do
      assert {:docs_v1, _, _, _, moduledoc, _, _} = Code.fetch_docs(Cache)

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
