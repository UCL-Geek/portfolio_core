defmodule PortfolioCore.Manifest.Schema do
  @moduledoc """
  NimbleOptions schema for manifest validation.

  Defines the structure and validation rules for portfolio manifests.
  Manifests configure which adapters implement each port and their settings.

  ## Manifest Structure

      version: "1.0"
      environment: :dev
      adapters:
        vector_store:
          adapter: MyApp.Adapters.Pgvector
          config:
            dimensions: 1536
          enabled: true
      pipelines:
        ingest:
          steps: [discover, chunk, embed, store]
  """

  @doc """
  Schema for a single adapter configuration.
  """
  def adapter_schema do
    [
      adapter: [
        type: :atom,
        required: true,
        doc: "The adapter module implementing the port behavior"
      ],
      config: [
        type: {:or, [:map, :keyword_list]},
        default: %{},
        doc: "Adapter-specific configuration"
      ],
      enabled: [
        type: :boolean,
        default: true,
        doc: "Whether this adapter is enabled"
      ]
    ]
  end

  @doc """
  Schema for the complete manifest.
  """
  def manifest_schema do
    [
      version: [
        type: :string,
        required: true,
        doc: "Manifest schema version"
      ],
      environment: [
        type: :atom,
        required: true,
        doc: "Target environment (:dev, :test, :prod)"
      ],
      adapters: [
        type: {:or, [:map, :keyword_list]},
        required: true,
        doc: "Adapter configurations keyed by port name"
      ],
      pipelines: [
        type: {:or, [:map, :keyword_list]},
        default: %{},
        doc: "Pipeline configurations"
      ],
      graphs: [
        type: {:or, [:map, :keyword_list]},
        default: %{},
        doc: "Graph configurations"
      ],
      rag: [
        type: {:or, [:map, :keyword_list]},
        default: %{},
        doc: "RAG strategy configuration"
      ],
      telemetry: [
        type: {:or, [:map, :keyword_list]},
        default: %{},
        doc: "Telemetry configuration"
      ]
    ]
  end

  @doc """
  Validate a manifest against the schema.

  ## Parameters

    - `manifest` - The manifest to validate (keyword list or map)

  ## Returns

    - `{:ok, validated}` with validated manifest
    - `{:error, %NimbleOptions.ValidationError{}}` on validation failure

  ## Examples

      iex> PortfolioCore.Manifest.Schema.validate([
      ...>   version: "1.0",
      ...>   environment: :dev,
      ...>   adapters: []
      ...> ])
      {:ok, [version: "1.0", environment: :dev, adapters: [], ...]}
  """
  @spec validate(keyword() | map()) ::
          {:ok, keyword()} | {:error, NimbleOptions.ValidationError.t()}
  def validate(manifest) when is_map(manifest) do
    manifest
    |> Map.to_list()
    |> validate()
  end

  def validate(manifest) when is_list(manifest) do
    NimbleOptions.validate(manifest, manifest_schema())
  end

  @doc """
  Validate a manifest, raising on error.

  ## Parameters

    - `manifest` - The manifest to validate

  ## Returns

    - Validated manifest on success

  ## Raises

    - `NimbleOptions.ValidationError` on validation failure
  """
  @spec validate!(keyword() | map()) :: keyword()
  def validate!(manifest) do
    case validate(manifest) do
      {:ok, validated} -> validated
      {:error, error} -> raise error
    end
  end

  @doc """
  Get the schema definition for documentation or introspection.
  """
  @spec schema_definition() :: keyword()
  def schema_definition do
    manifest_schema()
  end
end
