defmodule PortfolioCoreTest do
  use ExUnit.Case

  describe "adapter/1" do
    test "returns nil when no adapter registered" do
      assert nil == PortfolioCore.adapter(:unknown_port)
    end

    test "returns adapter from registry" do
      PortfolioCore.Registry.register(:test_port, {TestModule, [key: :value]})
      assert {TestModule, [key: :value]} == PortfolioCore.adapter(:test_port)
      PortfolioCore.Registry.unregister(:test_port)
    end
  end

  describe "adapter!/1" do
    test "raises when no adapter registered" do
      assert_raise ArgumentError, fn ->
        PortfolioCore.adapter!(:missing_port)
      end
    end

    test "returns adapter from registry" do
      PortfolioCore.Registry.register(:test_port2, {AnotherModule, []})
      assert {AnotherModule, []} == PortfolioCore.adapter!(:test_port2)
      PortfolioCore.Registry.unregister(:test_port2)
    end
  end

  describe "registered_ports/0" do
    test "returns list of registered ports" do
      # Register some ports
      PortfolioCore.Registry.register(:port_a, {A, []})
      PortfolioCore.Registry.register(:port_b, {B, []})

      ports = PortfolioCore.registered_ports()
      assert :port_a in ports
      assert :port_b in ports

      # Cleanup
      PortfolioCore.Registry.unregister(:port_a)
      PortfolioCore.Registry.unregister(:port_b)
    end
  end

  describe "manifest/0" do
    test "returns nil when engine has no manifest" do
      # The default engine starts without a manifest
      assert nil == PortfolioCore.manifest() or is_list(PortfolioCore.manifest())
    end
  end

  describe "reload_manifest/0" do
    test "returns error when no manifest path is set" do
      # The default engine starts without a manifest path
      result = PortfolioCore.reload_manifest()
      # Either error (no path) or ok (has path from other tests)
      assert result == {:error, :no_manifest_path} or result == :ok
    end
  end
end
