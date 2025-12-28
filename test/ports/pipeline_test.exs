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
      assert {:parallel?, 0} in callbacks
      assert {:on_error, 0} in callbacks
      assert {:timeout, 0} in callbacks
      assert {:cache_ttl, 0} in callbacks
    end

    test "defines optional callbacks" do
      optional = Pipeline.behaviour_info(:optional_callbacks)

      assert {:validate_input, 1} in optional
      assert {:estimated_duration, 0} in optional
      refute {:parallel?, 0} in optional
      refute {:on_error, 0} in optional
      refute {:timeout, 0} in optional
      refute {:cache_ttl, 0} in optional
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

  describe "__using__ defaults" do
    defmodule DefaultStep do
      use PortfolioCore.Ports.Pipeline

      @impl true
      def execute(_context, _config), do: {:ok, :done}

      @impl true
      def output_schema, do: %{result: :any}

      @impl true
      def required_inputs, do: []

      @impl true
      def cacheable?, do: false
    end

    defmodule CustomDefaultsStep do
      use PortfolioCore.Ports.Pipeline,
        parallel?: true,
        on_error: :continue,
        timeout: 5_000,
        cache_ttl: 15_000

      @impl true
      def execute(_context, _config), do: {:ok, :done}

      @impl true
      def output_schema, do: %{result: :any}

      @impl true
      def required_inputs, do: []

      @impl true
      def cacheable?, do: false
    end

    defmodule OverrideDefaultsStep do
      use PortfolioCore.Ports.Pipeline

      @impl true
      def execute(_context, _config), do: {:ok, :done}

      @impl true
      def output_schema, do: %{result: :any}

      @impl true
      def required_inputs, do: []

      @impl true
      def cacheable?, do: false

      @impl true
      def parallel?, do: true
    end

    test "uses built-in defaults" do
      assert DefaultStep.parallel?() == false
      assert DefaultStep.on_error() == :halt
      assert DefaultStep.timeout() == 30_000
      assert DefaultStep.cache_ttl() == :infinity
    end

    test "allows overriding defaults via use options" do
      assert CustomDefaultsStep.parallel?() == true
      assert CustomDefaultsStep.on_error() == :continue
      assert CustomDefaultsStep.timeout() == 5_000
      assert CustomDefaultsStep.cache_ttl() == 15_000
    end

    test "allows overriding defaults by defining callbacks" do
      assert OverrideDefaultsStep.parallel?() == true
      assert OverrideDefaultsStep.on_error() == :halt
    end
  end
end
