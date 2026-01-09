defmodule PortfolioCore.Backend.CapabilitiesTest do
  use PortfolioCore.SupertesterCase, async: true

  alias PortfolioCore.Backend.Capabilities

  describe "struct defaults" do
    test "matches CrucibleIR defaults" do
      caps = %Capabilities{backend_id: :openai, provider: "openai"}

      assert caps.models == []
      assert caps.default_model == nil
      assert caps.supports_streaming == true
      assert caps.supports_tools == true
      assert caps.supports_vision == false
      assert caps.supports_audio == false
      assert caps.supports_json_mode == true
      assert caps.supports_extended_thinking == false
      assert caps.supports_caching == false
      assert caps.max_tokens == nil
      assert caps.max_context_length == nil
      assert caps.max_images_per_request == nil
      assert caps.requests_per_minute == nil
      assert caps.tokens_per_minute == nil
      assert caps.cost_per_million_input == nil
      assert caps.cost_per_million_output == nil
      assert caps.metadata == %{}
    end
  end

  describe "from_metadata/2" do
    test "builds from backend_capabilities map and applies defaults" do
      metadata = %{
        backend_capabilities: %{
          backend_id: :openai,
          provider: "openai",
          supports_vision: true
        }
      }

      assert {:ok, caps} = Capabilities.from_metadata(metadata)
      assert caps.supports_vision == true
      assert caps.supports_audio == false
      assert caps.supports_streaming == true
    end

    test "maps capability hints list to support flags" do
      metadata = %{
        backend_id: :openai,
        provider: "openai",
        capabilities: [:vision, :audio, :function_calling, :caching]
      }

      assert {:ok, caps} = Capabilities.from_metadata(metadata)
      assert caps.supports_vision == true
      assert caps.supports_audio == true
      assert caps.supports_tools == true
      assert caps.supports_caching == true
    end

    test "returns error when backend_id missing" do
      assert {:error, :missing_backend_id} = Capabilities.from_metadata(%{provider: "openai"})
    end

    test "returns error when provider missing" do
      assert {:error, :missing_provider} = Capabilities.from_metadata(%{backend_id: :openai})
    end
  end

  describe "from_adapter/4" do
    defmodule AdapterWithCaps do
      def capabilities(_config) do
        %{backend_id: :openai, provider: "openai", supports_vision: true}
      end
    end

    test "uses adapter capabilities and allows overrides" do
      metadata = %{backend_capabilities: %{supports_vision: false}}

      assert {:ok, caps} = Capabilities.from_adapter(AdapterWithCaps, [], metadata)
      assert caps.supports_vision == false
      assert caps.supports_streaming == true
    end
  end

  describe "to_backend_ir/1" do
    test "returns map or struct with backend fields" do
      caps = %Capabilities{backend_id: :openai, provider: "openai", models: ["gpt-4o"]}

      backend = Capabilities.to_backend_ir(caps)
      assert backend.backend_id == :openai
      assert backend.provider == "openai"
      assert backend.models == ["gpt-4o"]
    end
  end
end
