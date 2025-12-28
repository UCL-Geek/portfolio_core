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
        type: {:custom, __MODULE__, :to_atom, []},
        required: true,
        doc: "Target environment (:dev, :test, :prod)"
      ],
      adapters: [
        type: {:or, [:map, :keyword_list]},
        required: true,
        doc: "Adapter configurations keyed by port name"
      ],
      router: [
        type: :map,
        doc: "Router configuration",
        keys: [
          strategy: [
            type:
              {:custom, __MODULE__, :validate_strategy,
               [[:fallback, :round_robin, :specialist, :cost_optimized]]}
          ],
          health_check_interval: [type: :non_neg_integer, default: 30_000],
          providers: [type: {:list, :map}]
        ]
      ],
      cache: [
        type: :map,
        doc: "Cache configuration",
        keys: [
          enabled: [type: :boolean, default: true],
          backend: [
            type: {:custom, __MODULE__, :validate_strategy, [[:ets, :redis, :mnesia]]}
          ],
          default_ttl: [type: :pos_integer, default: 3600],
          namespaces: [type: :map]
        ]
      ],
      agent: [
        type: :map,
        doc: "Agent configuration",
        keys: [
          max_iterations: [type: :pos_integer, default: 10],
          timeout: [type: :pos_integer, default: 300_000],
          tools: [type: {:list, {:custom, __MODULE__, :to_atom, []}}]
        ]
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

  @doc """
  Convert a string or atom to an atom.
  Used as custom type validator for NimbleOptions.
  """
  @spec to_atom(term()) :: {:ok, atom()} | {:error, String.t()}
  def to_atom(value) when is_atom(value), do: {:ok, value}
  def to_atom(value) when is_binary(value), do: {:ok, String.to_atom(value)}
  def to_atom(value), do: {:error, "expected atom or string, got: #{inspect(value)}"}

  @doc """
  Validate a strategy value against allowed options.
  Accepts strings and converts them to atoms before validation.
  """
  @spec validate_strategy(term(), [atom()]) :: {:ok, atom()} | {:error, String.t()}
  def validate_strategy(value, allowed) when is_atom(value) do
    if value in allowed do
      {:ok, value}
    else
      {:error, "expected one of #{inspect(allowed)}, got: #{inspect(value)}"}
    end
  end

  def validate_strategy(value, allowed) when is_binary(value) do
    atom_value = String.to_atom(value)
    validate_strategy(atom_value, allowed)
  end

  def validate_strategy(value, allowed) do
    {:error, "expected one of #{inspect(allowed)}, got: #{inspect(value)}"}
  end
end
