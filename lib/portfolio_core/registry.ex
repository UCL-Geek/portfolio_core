defmodule PortfolioCore.Registry do
  @moduledoc """
  ETS-based registry for adapter lookup.

  The registry provides fast concurrent access to registered adapters.
  Adapters are typically registered by the manifest engine during startup.

  ## Usage

      # Register an adapter
      PortfolioCore.Registry.register(:vector_store, {MyAdapter, [config: :value]})

      # Look up an adapter
      {MyAdapter, config} = PortfolioCore.Registry.get(:vector_store)

      # List all registered ports
      [:vector_store, :embedder] = PortfolioCore.Registry.list_ports()

  ## Thread Safety

  The registry uses a public ETS table with read and write concurrency
  enabled, making it safe for concurrent access from multiple processes.
  """

  use GenServer

  @table_name :portfolio_core_adapters

  @type port_name :: atom()
  @type adapter :: {module(), keyword()}

  # Client API

  @doc """
  Start the registry process.

  The registry must be started before adapters can be registered.
  This is typically done by the application supervisor.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Register an adapter for a port.

  ## Parameters

    - `port_name` - Atom identifying the port
    - `adapter` - Tuple of `{module, config}` for the adapter

  ## Returns

    - `:ok`

  ## Examples

      iex> PortfolioCore.Registry.register(:vector_store, {Pgvector, [repo: MyRepo]})
      :ok
  """
  @spec register(port_name(), adapter()) :: :ok
  def register(port_name, adapter) do
    :ets.insert(@table_name, {port_name, adapter})
    :ok
  end

  @doc """
  Get adapter for a port.

  ## Parameters

    - `port_name` - Atom identifying the port

  ## Returns

    - `{module, config}` tuple if found
    - `nil` if not registered

  ## Examples

      iex> PortfolioCore.Registry.get(:vector_store)
      {Pgvector, [repo: MyRepo]}
  """
  @spec get(port_name()) :: adapter() | nil
  def get(port_name) do
    case :ets.lookup(@table_name, port_name) do
      [{^port_name, adapter}] -> adapter
      [] -> nil
    end
  end

  @doc """
  Get adapter for a port, raising if not found.

  ## Parameters

    - `port_name` - Atom identifying the port

  ## Returns

    - `{module, config}` tuple

  ## Raises

    - `ArgumentError` if port is not registered

  ## Examples

      iex> PortfolioCore.Registry.get!(:vector_store)
      {Pgvector, [repo: MyRepo]}
  """
  @spec get!(port_name()) :: adapter()
  def get!(port_name) do
    case get(port_name) do
      nil -> raise ArgumentError, "No adapter registered for port: #{port_name}"
      adapter -> adapter
    end
  end

  @doc """
  List all registered ports.

  ## Returns

    - List of port name atoms

  ## Examples

      iex> PortfolioCore.Registry.list_ports()
      [:vector_store, :embedder, :chunker]
  """
  @spec list_ports() :: [port_name()]
  def list_ports do
    :ets.tab2list(@table_name)
    |> Enum.map(&elem(&1, 0))
  end

  @doc """
  Unregister an adapter.

  ## Parameters

    - `port_name` - Atom identifying the port to unregister

  ## Returns

    - `:ok`
  """
  @spec unregister(port_name()) :: :ok
  def unregister(port_name) do
    :ets.delete(@table_name, port_name)
    :ok
  end

  @doc """
  Clear all registrations.

  Useful for testing or when reloading a complete new configuration.

  ## Returns

    - `:ok`
  """
  @spec clear() :: :ok
  def clear do
    :ets.delete_all_objects(@table_name)
    :ok
  end

  @doc """
  Check if a port has a registered adapter.

  ## Parameters

    - `port_name` - Atom identifying the port

  ## Returns

    - `true` if an adapter is registered
    - `false` otherwise
  """
  @spec registered?(port_name()) :: boolean()
  def registered?(port_name) do
    :ets.member(@table_name, port_name)
  end

  # Server callbacks

  @impl true
  def init(_opts) do
    table =
      :ets.new(@table_name, [
        :named_table,
        :public,
        :set,
        read_concurrency: true,
        write_concurrency: true
      ])

    {:ok, %{table: table}}
  end
end
