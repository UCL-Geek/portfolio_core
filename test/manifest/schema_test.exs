defmodule PortfolioCore.Manifest.SchemaTest do
  use PortfolioCore.SupertesterCase, async: false

  alias PortfolioCore.Manifest.Schema

  @valid_manifest [
    version: "1.0",
    environment: :dev,
    adapters: []
  ]

  describe "validate/1" do
    test "validates a valid manifest" do
      assert {:ok, validated} = Schema.validate(@valid_manifest)
      assert validated[:version] == "1.0"
      assert validated[:environment] == :dev
    end

    test "validates manifest with map input" do
      manifest = %{
        version: "1.0",
        environment: :test,
        adapters: %{}
      }

      assert {:ok, validated} = Schema.validate(manifest)
      assert validated[:version] == "1.0"
    end

    test "returns error for invalid manifest" do
      invalid = [environment: :dev, adapters: []]
      assert {:error, %NimbleOptions.ValidationError{}} = Schema.validate(invalid)
    end

    test "validates with default values" do
      minimal = [version: "1.0", environment: :prod, adapters: []]
      assert {:ok, validated} = Schema.validate(minimal)
      assert validated[:pipelines] == %{}
      assert validated[:graphs] == %{}
      assert validated[:telemetry] == %{}
    end
  end

  describe "validate!/1" do
    test "returns validated manifest on success" do
      result = Schema.validate!(@valid_manifest)
      assert result[:version] == "1.0"
    end

    test "raises on invalid manifest" do
      assert_raise NimbleOptions.ValidationError, fn ->
        Schema.validate!(adapters: [])
      end
    end
  end

  describe "schema_definition/0" do
    test "returns the schema definition" do
      schema = Schema.schema_definition()
      assert is_list(schema)
      assert Keyword.has_key?(schema, :version)
      assert Keyword.has_key?(schema, :environment)
      assert Keyword.has_key?(schema, :adapters)
    end
  end

  describe "adapter_schema/0" do
    test "returns adapter schema" do
      schema = Schema.adapter_schema()
      assert is_list(schema)
      assert Keyword.has_key?(schema, :adapter)
      assert Keyword.has_key?(schema, :config)
      assert Keyword.has_key?(schema, :enabled)
    end
  end

  describe "new schema fields" do
    test "validates router configuration" do
      config = %{
        version: "1.0",
        environment: :dev,
        adapters: %{},
        router: %{
          strategy: :specialist,
          health_check_interval: 30_000,
          providers: []
        }
      }

      assert {:ok, _} = Schema.validate(config)
    end

    test "validates cache configuration" do
      config = %{
        version: "1.0",
        environment: :dev,
        adapters: %{},
        cache: %{
          enabled: true,
          backend: :ets,
          default_ttl: 3600
        }
      }

      assert {:ok, _} = Schema.validate(config)
    end

    test "validates agent configuration" do
      config = %{
        version: "1.0",
        environment: :dev,
        adapters: %{},
        agent: %{
          max_iterations: 10,
          timeout: 300_000,
          tools: [:search, :read_file]
        }
      }

      assert {:ok, _} = Schema.validate(config)
    end

    test "rejects invalid router strategy" do
      config = %{
        version: "1.0",
        environment: :dev,
        adapters: %{},
        router: %{strategy: :invalid}
      }

      assert {:error, _} = Schema.validate(config)
    end
  end
end
