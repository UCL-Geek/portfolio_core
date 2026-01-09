defmodule PortfolioCore.Backend.Capabilities do
  @moduledoc """
  Backend capability metadata compatible with CrucibleIR.Backend.Capabilities.

  This struct and helper functions provide a shared shape for capability discovery,
  routing, and cost visibility without requiring a hard dependency on CrucibleIR.
  """

  @derive Jason.Encoder
  @enforce_keys [:backend_id, :provider]
  defstruct [
    :backend_id,
    :provider,
    models: [],
    default_model: nil,
    supports_streaming: true,
    supports_tools: true,
    supports_vision: false,
    supports_audio: false,
    supports_json_mode: true,
    supports_extended_thinking: false,
    supports_caching: false,
    max_tokens: nil,
    max_context_length: nil,
    max_images_per_request: nil,
    requests_per_minute: nil,
    tokens_per_minute: nil,
    cost_per_million_input: nil,
    cost_per_million_output: nil,
    metadata: %{}
  ]

  @type t :: %__MODULE__{
          backend_id: atom(),
          provider: String.t(),
          models: [String.t()],
          default_model: String.t() | nil,
          supports_streaming: boolean(),
          supports_tools: boolean(),
          supports_vision: boolean(),
          supports_audio: boolean(),
          supports_json_mode: boolean(),
          supports_extended_thinking: boolean(),
          supports_caching: boolean(),
          max_tokens: non_neg_integer() | nil,
          max_context_length: non_neg_integer() | nil,
          max_images_per_request: non_neg_integer() | nil,
          requests_per_minute: non_neg_integer() | nil,
          tokens_per_minute: non_neg_integer() | nil,
          cost_per_million_input: float() | nil,
          cost_per_million_output: float() | nil,
          metadata: map()
        }

  @capability_fields [
    :backend_id,
    :provider,
    :models,
    :default_model,
    :supports_streaming,
    :supports_tools,
    :supports_vision,
    :supports_audio,
    :supports_json_mode,
    :supports_extended_thinking,
    :supports_caching,
    :max_tokens,
    :max_context_length,
    :max_images_per_request,
    :requests_per_minute,
    :tokens_per_minute,
    :cost_per_million_input,
    :cost_per_million_output,
    :metadata
  ]

  @capability_field_strings Enum.map(@capability_fields, &Atom.to_string/1)

  @capability_flag_map %{
    streaming: :supports_streaming,
    function_calling: :supports_tools,
    tools: :supports_tools,
    tool_use: :supports_tools,
    vision: :supports_vision,
    audio: :supports_audio,
    json_mode: :supports_json_mode,
    extended_thinking: :supports_extended_thinking,
    caching: :supports_caching
  }

  @doc """
  Build a capabilities struct from metadata.

  Accepts capability fields directly or under `:backend_capabilities`.
  Optional `:capabilities` lists are treated as hints and mapped to
  `supports_*` flags.
  """
  @spec from_metadata(map() | keyword() | nil, keyword()) :: {:ok, t()} | {:error, term()}
  def from_metadata(metadata, opts \\ [])

  def from_metadata(nil, opts), do: from_metadata(%{}, opts)

  def from_metadata(metadata, opts) when is_list(metadata) do
    metadata
    |> Map.new()
    |> from_metadata(opts)
  end

  def from_metadata(metadata, opts) when is_map(metadata) do
    base_source = Map.get(metadata, :backend_capabilities, metadata)

    raw_map =
      base_source
      |> normalize_source()
      |> normalize_keys()

    base_map = Map.drop(raw_map, [:backend_id, :provider])
    hint_list = Map.get(metadata, :capabilities)

    backend_id =
      opts
      |> Keyword.get(:backend_id)
      |> fallback_value(Map.get(raw_map, :backend_id))
      |> fallback_value(Map.get(metadata, :backend_id))
      |> normalize_backend_id()

    provider =
      opts
      |> Keyword.get(:provider)
      |> fallback_value(Map.get(raw_map, :provider))
      |> fallback_value(Map.get(metadata, :provider))
      |> normalize_provider()

    cond do
      is_nil(backend_id) ->
        {:error, :missing_backend_id}

      is_nil(provider) ->
        {:error, :missing_provider}

      true ->
        caps = %__MODULE__{backend_id: backend_id, provider: provider}

        caps =
          base_map
          |> compact_fields()
          |> then(&struct(caps, &1))
          |> struct(flag_overrides(hint_list))

        {:ok, caps}
    end
  end

  @doc """
  Build capabilities from an adapter module and its config.

  If the adapter exports `capabilities/1` or `capabilities/0`, its result is
  used as a baseline unless overridden by metadata.
  """
  @spec from_adapter(module(), keyword() | map(), map() | keyword() | nil, keyword()) ::
          {:ok, t()} | {:error, term()}
  def from_adapter(adapter, config, metadata \\ %{}, opts \\ [])

  def from_adapter(adapter, config, metadata, opts) when is_list(metadata) do
    from_adapter(adapter, config, Map.new(metadata), opts)
  end

  def from_adapter(adapter, config, metadata, opts) when is_map(metadata) do
    adapter_caps = adapter_capabilities(adapter, config)

    metadata =
      case adapter_caps do
        list when is_list(list) ->
          Map.put_new(metadata, :capabilities, list)

        %{} ->
          case Map.get(metadata, :backend_capabilities) do
            nil ->
              Map.put(metadata, :backend_capabilities, adapter_caps)

            existing ->
              Map.put(
                metadata,
                :backend_capabilities,
                merge_capability_sources(adapter_caps, existing)
              )
          end

        _ ->
          metadata
      end

    from_metadata(metadata, opts)
  end

  @doc """
  Convert capabilities to CrucibleIR.Backend.Capabilities when available.
  Falls back to a plain map when CrucibleIR is not loaded.
  """
  @spec to_backend_ir(t() | map()) :: map()
  def to_backend_ir(%{__struct__: CrucibleIR.Backend.Capabilities} = capabilities) do
    capabilities
  end

  def to_backend_ir(%__MODULE__{} = capabilities) do
    data = Map.from_struct(capabilities)

    if Code.ensure_loaded?(CrucibleIR.Backend.Capabilities) do
      struct(CrucibleIR.Backend.Capabilities, data)
    else
      data
    end
  end

  @doc """
  Build backend IR capabilities directly from an adapter.
  """
  @spec adapter_to_backend_ir(module(), keyword() | map(), map() | keyword() | nil, keyword()) ::
          {:ok, map()} | {:error, term()}
  def adapter_to_backend_ir(adapter, config, metadata \\ %{}, opts \\ []) do
    with {:ok, caps} <- from_adapter(adapter, config, metadata, opts) do
      {:ok, to_backend_ir(caps)}
    end
  end

  defp normalize_source(%_{} = source), do: Map.from_struct(source)
  defp normalize_source(source) when is_list(source), do: Map.new(source)
  defp normalize_source(source) when is_map(source), do: source
  defp normalize_source(_source), do: %{}

  defp merge_capability_sources(base, overrides) do
    base
    |> normalize_source()
    |> Map.merge(normalize_source(overrides))
  end

  defp normalize_keys(map) do
    Enum.reduce(map, %{}, fn {key, value}, acc ->
      cond do
        is_atom(key) and key in @capability_fields ->
          Map.put(acc, key, value)

        is_binary(key) and key in @capability_field_strings ->
          Map.put(acc, String.to_existing_atom(key), value)

        true ->
          acc
      end
    end)
  end

  defp compact_fields(map) do
    map
    |> Map.take(@capability_fields)
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end

  defp flag_overrides(list) when is_list(list) do
    Enum.reduce(list, %{}, fn capability, acc ->
      case Map.get(@capability_flag_map, capability) do
        nil -> acc
        key -> Map.put(acc, key, true)
      end
    end)
  end

  defp flag_overrides(_list), do: %{}

  defp adapter_capabilities(adapter, config) do
    cond do
      function_exported?(adapter, :capabilities, 1) -> adapter.capabilities(config)
      function_exported?(adapter, :capabilities, 0) -> adapter.capabilities()
      true -> %{}
    end
  end

  defp fallback_value(nil, next), do: next
  defp fallback_value(value, _next), do: value

  defp normalize_backend_id(nil), do: nil
  defp normalize_backend_id(id) when is_atom(id), do: id
  defp normalize_backend_id(id) when is_binary(id), do: String.to_atom(id)
  defp normalize_backend_id(id), do: id

  defp normalize_provider(nil), do: nil
  defp normalize_provider(provider) when is_binary(provider), do: provider
  defp normalize_provider(provider) when is_atom(provider), do: Atom.to_string(provider)
  defp normalize_provider(provider), do: provider
end
