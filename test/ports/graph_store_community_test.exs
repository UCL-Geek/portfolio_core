defmodule PortfolioCore.Ports.GraphStore.CommunityTest do
  use PortfolioCore.SupertesterCase, async: true

  alias PortfolioCore.Ports.GraphStore.Community

  describe "behaviour definition" do
    test "defines community callbacks" do
      callbacks = Community.behaviour_info(:callbacks)

      assert {:create_community, 3} in callbacks
      assert {:get_community_members, 2} in callbacks
      assert {:update_community_summary, 3} in callbacks
      assert {:list_communities, 2} in callbacks
    end

    test "defines no optional callbacks" do
      optional = Community.behaviour_info(:optional_callbacks)
      assert optional == []
    end
  end

  describe "typespecs" do
    test "exports type specifications" do
      assert {:ok, types} = Code.Typespec.fetch_types(Community)
      assert is_list(types)
      assert types != []
    end
  end

  describe "documentation" do
    test "has moduledoc" do
      assert {:docs_v1, _, _, _, moduledoc, _, _} = Code.fetch_docs(Community)

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
