defmodule PortfolioCore.RegistryTest do
  use ExUnit.Case

  alias PortfolioCore.Registry

  setup do
    # Clear registry before each test
    Registry.clear()
    :ok
  end

  describe "register/2" do
    test "registers adapter for port" do
      assert :ok == Registry.register(:vector_store, {MockAdapter, [key: :value]})
    end

    test "overwrites existing registration" do
      Registry.register(:vector_store, {OldAdapter, []})
      Registry.register(:vector_store, {NewAdapter, []})

      assert {NewAdapter, []} == Registry.get(:vector_store)
    end
  end

  describe "get/1" do
    test "returns registered adapter" do
      Registry.register(:vector_store, {TestAdapter, [config: true]})

      assert {TestAdapter, [config: true]} == Registry.get(:vector_store)
    end

    test "returns nil for unregistered port" do
      assert nil == Registry.get(:unknown_port)
    end
  end

  describe "get!/1" do
    test "returns registered adapter" do
      Registry.register(:embedder, {EmbedAdapter, []})

      assert {EmbedAdapter, []} == Registry.get!(:embedder)
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
      Registry.register(:vector_store, {V, []})
      Registry.register(:embedder, {E, []})
      Registry.register(:chunker, {C, []})

      ports = Registry.list_ports()

      assert :vector_store in ports
      assert :embedder in ports
      assert :chunker in ports
      assert length(ports) == 3
    end
  end

  describe "unregister/1" do
    test "removes registration" do
      Registry.register(:vector_store, {Adapter, []})
      assert :ok == Registry.unregister(:vector_store)
      assert nil == Registry.get(:vector_store)
    end

    test "succeeds even if not registered" do
      assert :ok == Registry.unregister(:never_registered)
    end
  end

  describe "clear/0" do
    test "removes all registrations" do
      Registry.register(:a, {A, []})
      Registry.register(:b, {B, []})
      Registry.register(:c, {C, []})

      assert :ok == Registry.clear()
      assert [] == Registry.list_ports()
    end
  end

  describe "registered?/1" do
    test "returns true for registered port" do
      Registry.register(:vector_store, {Adapter, []})
      assert Registry.registered?(:vector_store)
    end

    test "returns false for unregistered port" do
      refute Registry.registered?(:unknown)
    end
  end
end
