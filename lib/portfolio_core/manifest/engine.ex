defmodule PortfolioCore.Manifest.Engine do
  @moduledoc """
  GenServer that manages manifest loading and adapter wiring.

  The manifest engine is responsible for:
  - Loading and validating manifest files
  - Resolving adapter modules from manifest configuration
  - Registering adapters with the registry
  - Supporting hot-reload in development

  ## Usage

      # Start with a manifest file
      {:ok, _pid} = PortfolioCore.Manifest.Engine.start_link(
        manifest_path: "config/manifest.yaml"
      )

      # Get an adapter for a port
      adapter = PortfolioCore.Manifest.Engine.get_adapter(:vector_store)

      # Reload manifest
      :ok = PortfolioCore.Manifest.Engine.reload()

  ## Configuration

  The engine can be configured via application config:

      config :portfolio_core, :manifest,
        manifest_path: "config/manifest.yaml"
  """

  use GenServer
  require Logger

  alias PortfolioCore.Manifest.{Loader, Schema}
  alias PortfolioCore.Registry

  defstruct [:manifest_path, :manifest, :adapters, :loaded_at]

  @type t :: %__MODULE__{
          manifest_path: String.t() | nil,
          manifest: keyword() | nil,
          adapters: map() | nil,
          loaded_at: DateTime.t() | nil
        }

  # Client API

  @doc """
  Start the manifest engine.

  ## Options

    - `:manifest_path` - Path to the manifest file
    - `:name` - Process name (defaults to `__MODULE__`)

  ## Returns

    - `{:ok, pid}` on success
    - `{:error, reason}` on failure
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: opts[:name] || __MODULE__)
  end

  @doc """
  Get the currently loaded manifest.

  ## Parameters

    - `server` - The engine process (defaults to `__MODULE__`)

  ## Returns

    - The manifest as a keyword list, or nil if not loaded
  """
  @spec get_manifest(GenServer.server()) :: keyword() | nil
  def get_manifest(server \\ __MODULE__) do
    GenServer.call(server, :get_manifest)
  end

  @doc """
  Get adapter for a specific port.

  ## Parameters

    - `port_name` - Atom identifying the port (e.g., `:vector_store`)
    - `server` - The engine process (defaults to `__MODULE__`)

  ## Returns

    - `{module, config}` tuple for the adapter
    - `nil` if no adapter is configured for the port
  """
  @spec get_adapter(atom(), GenServer.server()) :: {module(), keyword()} | nil
  def get_adapter(port_name, server \\ __MODULE__) do
    GenServer.call(server, {:get_adapter, port_name})
  end

  @doc """
  Reload the manifest from disk.

  ## Parameters

    - `server` - The engine process (defaults to `__MODULE__`)

  ## Returns

    - `:ok` on success
    - `{:error, reason}` on failure
  """
  @spec reload(GenServer.server()) :: :ok | {:error, term()}
  def reload(server \\ __MODULE__) do
    GenServer.call(server, :reload)
  end

  @doc """
  Load a new manifest from path.

  ## Parameters

    - `path` - Path to the new manifest file
    - `server` - The engine process (defaults to `__MODULE__`)

  ## Returns

    - `:ok` on success
    - `{:error, reason}` on failure
  """
  @spec load(Path.t(), GenServer.server()) :: :ok | {:error, term()}
  def load(path, server \\ __MODULE__) do
    GenServer.call(server, {:load, path})
  end

  # Server callbacks

  @impl true
  def init(opts) do
    path = opts[:manifest_path]

    if path do
      case load_manifest(path) do
        {:ok, state} -> {:ok, state}
        {:error, reason} -> {:stop, {:manifest_error, reason}}
      end
    else
      {:ok, %__MODULE__{}}
    end
  end

  @impl true
  def handle_call(:get_manifest, _from, state) do
    {:reply, state.manifest, state}
  end

  @impl true
  def handle_call({:get_adapter, port_name}, _from, state) do
    adapter = Map.get(state.adapters || %{}, port_name)
    {:reply, adapter, state}
  end

  @impl true
  def handle_call(:reload, _from, %{manifest_path: nil} = state) do
    {:reply, {:error, :no_manifest_path}, state}
  end

  @impl true
  def handle_call(:reload, _from, state) do
    case load_manifest(state.manifest_path) do
      {:ok, new_state} -> {:reply, :ok, new_state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:load, path}, _from, state) do
    case load_manifest(path) do
      {:ok, new_state} -> {:reply, :ok, new_state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  # Private functions

  defp load_manifest(path) do
    with {:ok, manifest} <- Loader.load(path),
         {:ok, validated} <- validate_manifest(manifest),
         {:ok, adapters} <- wire_adapters(validated) do
      state = %__MODULE__{
        manifest_path: path,
        manifest: validated,
        adapters: adapters,
        loaded_at: DateTime.utc_now()
      }

      emit_telemetry(:manifest_loaded, %{path: path, adapters: Map.keys(adapters)})

      {:ok, state}
    end
  end

  defp validate_manifest(manifest) do
    # Convert string keys to atoms for validation
    atomized = atomize_keys(manifest)

    case Schema.validate(atomized) do
      {:ok, _} -> {:ok, atomized}
      {:error, _} = err -> err
    end
  end

  defp wire_adapters(manifest) do
    adapters = manifest[:adapters] || %{}

    # Handle both maps and keyword lists
    adapter_list =
      case adapters do
        list when is_list(list) -> list
        map when is_map(map) -> Map.to_list(map)
      end

    result =
      Enum.reduce_while(adapter_list, {:ok, %{}}, fn {port_name, config}, {:ok, acc} ->
        case resolve_adapter(port_name, config) do
          {:ok, {module, adapter_config} = adapter} ->
            Registry.register(port_name, module, adapter_config)
            {:cont, {:ok, Map.put(acc, port_name, adapter)}}

          {:error, reason} ->
            {:halt, {:error, {port_name, reason}}}
        end
      end)

    result
  end

  defp resolve_adapter(_port_name, config) do
    # Handle both maps and keyword lists for config
    adapter_module = get_config_value(config, :adapter)
    adapter_config = get_config_value(config, :config) || %{}

    # Convert adapter config to keyword list for consistency
    adapter_config_list =
      case adapter_config do
        list when is_list(list) -> list
        map when is_map(map) -> Map.to_list(map)
      end

    cond do
      is_nil(adapter_module) ->
        {:error, :adapter_not_specified}

      not is_atom(adapter_module) ->
        {:error, {:invalid_adapter, adapter_module}}

      Code.ensure_loaded?(adapter_module) ->
        {:ok, {adapter_module, adapter_config_list}}

      true ->
        {:error, {:module_not_found, adapter_module}}
    end
  end

  # Helper to get value from either map or keyword list
  defp get_config_value(config, key) when is_map(config), do: Map.get(config, key)
  defp get_config_value(config, key) when is_list(config), do: Keyword.get(config, key)

  # Keys whose string values should be converted to atoms
  @atom_value_keys [:environment, :adapter, :strategy, :backend]

  defp atomize_keys(map) when is_map(map) do
    Map.new(map, fn
      {k, v} when is_binary(k) ->
        atom_key = String.to_atom(k)
        {atom_key, atomize_value(atom_key, v)}

      {k, v} ->
        {k, atomize_value(k, v)}
    end)
  end

  defp atomize_keys(list) when is_list(list) do
    Enum.map(list, &atomize_keys/1)
  end

  defp atomize_keys(value), do: value

  # Convert string values to atoms for specific keys
  defp atomize_value(:adapter, value) when is_binary(value) do
    # Convert module name string to proper module atom
    # "Elixir.Foo.Bar" or "Foo.Bar" should become Foo.Bar
    value
    |> String.trim_leading("Elixir.")
    |> String.split(".")
    |> Enum.map(&String.to_atom/1)
    |> Module.concat()
  end

  defp atomize_value(key, value) when key in @atom_value_keys and is_binary(value) do
    String.to_atom(value)
  end

  defp atomize_value(_key, value) when is_map(value), do: atomize_keys(value)
  defp atomize_value(_key, value) when is_list(value), do: Enum.map(value, &atomize_keys/1)
  defp atomize_value(_key, value), do: value

  defp emit_telemetry(event, metadata) do
    :telemetry.execute(
      [:portfolio_core, :manifest, event],
      %{count: 1},
      metadata
    )
  end
end
