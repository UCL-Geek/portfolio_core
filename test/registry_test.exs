defmodule PortfolioCore.RegistryTest do
  use ExUnit.Case

  alias PortfolioCore.Registry

  setup do
    # Clear registry before each test
    Registry.clear()
    :ok
  end

  describe "register/3" do
    test "registers adapter for port" do
      assert :ok == Registry.register(:vector_store, MockAdapter, key: :value)
    end

    test "overwrites existing registration" do
      Registry.register(:vector_store, OldAdapter, [])
      Registry.register(:vector_store, NewAdapter, [])

      assert {:ok, entry} = Registry.get(:vector_store)
      assert entry.module == NewAdapter
    end
  end

  describe "get/1" do
    test "returns registered adapter" do
      Registry.register(:vector_store, TestAdapter, config: true)

      assert {:ok, entry} = Registry.get(:vector_store)
      assert entry.module == TestAdapter
      assert entry.config == [config: true]
    end

    test "returns nil for unregistered port" do
      assert {:error, :not_found} == Registry.get(:unknown_port)
    end
  end

  describe "get!/1" do
    test "returns registered adapter" do
      Registry.register(:embedder, EmbedAdapter, [])

      entry = Registry.get!(:embedder)
      assert entry.module == EmbedAdapter
    end

    test "raises for unregistered port" do
      assert_raise ArgumentError, ~r/No adapter registered/, fn ->
        Registry.get!(:unknown_port)
      end
    end
  end

  describe "list_ports/0" do
    test "returns empty list when no registrations" do
      assert [] == Registry.list_ports()
    end

    test "returns all registered ports" do
      Registry.register(:vector_store, V, [])
      Registry.register(:embedder, E, [])
      Registry.register(:chunker, C, [])

      ports = Registry.list_ports()

      assert :vector_store in ports
      assert :embedder in ports
      assert :chunker in ports
      assert length(ports) == 3
    end
  end

  describe "unregister/1" do
    test "removes registration" do
      Registry.register(:vector_store, Adapter, [])
      assert :ok == Registry.unregister(:vector_store)
      assert {:error, :not_found} == Registry.get(:vector_store)
    end

    test "succeeds even if not registered" do
      assert :ok == Registry.unregister(:never_registered)
    end
  end

  describe "clear/0" do
    test "removes all registrations" do
      Registry.register(:a, A, [])
      Registry.register(:b, B, [])
      Registry.register(:c, C, [])

      assert :ok == Registry.clear()
      assert [] == Registry.list_ports()
    end
  end

  describe "registered?/1" do
    test "returns true for registered port" do
      Registry.register(:vector_store, Adapter, [])
      assert Registry.registered?(:vector_store)
    end

    test "returns false for unregistered port" do
      refute Registry.registered?(:unknown)
    end
  end

  describe "enhanced registry" do
    test "register/4 stores metadata" do
      :ok = Registry.register(:test_port, TestModule, %{}, %{capabilities: [:code]})
      {:ok, entry} = Registry.get(:test_port)

      assert entry.metadata.capabilities == [:code]
    end

    test "find_by_capability/1 returns matching adapters" do
      Registry.register(:port1, Mod1, %{}, %{capabilities: [:code, :reasoning]})
      Registry.register(:port2, Mod2, %{}, %{capabilities: [:code]})
      Registry.register(:port3, Mod3, %{}, %{capabilities: [:embedding]})

      result = Registry.find_by_capability(:code)

      assert length(result) == 2
    end

    test "health status tracking" do
      Registry.register(:health_port, TestMod, %{})

      assert Registry.health_status(:health_port) == :healthy

      Registry.mark_unhealthy(:health_port)
      assert Registry.health_status(:health_port) == :unhealthy

      Registry.mark_healthy(:health_port)
      assert Registry.health_status(:health_port) == :healthy
    end

    test "metrics tracking" do
      Registry.register(:metrics_port, TestMod, %{})

      Registry.record_call(:metrics_port, true)
      Registry.record_call(:metrics_port, true)
      Registry.record_call(:metrics_port, false)

      {:ok, metrics} = Registry.metrics(:metrics_port)

      assert metrics.call_count == 3
      assert metrics.error_count == 1
    end
  end
end
