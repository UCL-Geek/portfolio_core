defmodule PortfolioCore.Registry do
  @moduledoc """
  ETS-based registry for adapter lookup.

  The registry provides fast concurrent access to registered adapters.
  Adapters are typically registered by the manifest engine during startup.

  ## Usage

      # Register an adapter
      PortfolioCore.Registry.register(
        :vector_store,
        MyAdapter,
        [config: :value],
        %{capabilities: [:search]}
      )

      # Look up an adapter entry
      {:ok, entry} = PortfolioCore.Registry.get(:vector_store)
      {module, config} = {entry.module, entry.config}

      # List all registered ports
      [:vector_store, :embedder] = PortfolioCore.Registry.list_ports()

  ## Thread Safety

  The registry uses a public ETS table with read and write concurrency
  enabled, making it safe for concurrent access from multiple processes.
  """

  use GenServer

  @table_name :portfolio_core_adapters

  @type port_name :: atom()
  @type metadata :: map()
  @type entry :: %{
          module: module(),
          config: keyword() | map(),
          metadata: metadata(),
          registered_at: DateTime.t(),
          healthy: boolean(),
          call_count: non_neg_integer(),
          error_count: non_neg_integer()
        }

  @type metrics :: %{
          call_count: non_neg_integer(),
          error_count: non_neg_integer(),
          error_rate: float(),
          healthy: boolean(),
          uptime: non_neg_integer()
        }

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
  Register an adapter for a port with optional metadata.

  ## Parameters

    - `port_name` - Atom identifying the port
    - `module` - Adapter module implementing the port
    - `config` - Adapter configuration
    - `metadata` - Adapter metadata (capabilities, tags, etc.)

  ## Returns

    - `:ok`
  """
  @spec register(port_name(), module(), keyword() | map(), metadata()) :: :ok
  def register(port_name, module, config, metadata \\ %{}) do
    entry = %{
      module: module,
      config: config,
      metadata: metadata,
      registered_at: DateTime.utc_now(),
      healthy: true,
      call_count: 0,
      error_count: 0
    }

    :ets.insert(@table_name, {port_name, entry})
    :ok
  end

  @doc """
  Register an adapter using the legacy tuple format.
  """
  @deprecated "Use register/3 or register/4 instead."
  @spec register(port_name(), {module(), keyword() | map()}) :: :ok
  def register(port_name, {module, config}) do
    register(port_name, module, config)
  end

  @doc """
  Get adapter entry for a port.

  ## Parameters

    - `port_name` - Atom identifying the port

  ## Returns

    - `{:ok, entry}` when registered
    - `{:error, :not_found}` otherwise
  """
  @spec get(port_name()) :: {:ok, entry()} | {:error, :not_found}
  def get(port_name) do
    case :ets.lookup(@table_name, port_name) do
      [{^port_name, entry}] -> {:ok, entry}
      [] -> {:error, :not_found}
    end
  end

  @doc """
  Get adapter entry for a port, raising if not found.

  ## Parameters

    - `port_name` - Atom identifying the port

  ## Returns

    - `entry`

  ## Raises

    - `ArgumentError` if port is not registered
  """
  @spec get!(port_name()) :: entry()
  def get!(port_name) do
    case get(port_name) do
      {:ok, entry} -> entry
      {:error, :not_found} -> raise ArgumentError, "No adapter registered for port: #{port_name}"
    end
  end

  @doc """
  List all registered ports.

  ## Returns

    - List of port name atoms
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

  @doc """
  Find adapters by capability.
  """
  @spec find_by_capability(term()) :: [{port_name(), module(), keyword() | map()}]
  def find_by_capability(capability) do
    :ets.tab2list(@table_name)
    |> Enum.filter(fn {_port, entry} ->
      capability in (entry.metadata[:capabilities] || [])
    end)
    |> Enum.map(fn {port, entry} -> {port, entry.module, entry.config} end)
  end

  @doc """
  Mark adapter as unhealthy.
  """
  @spec mark_unhealthy(port_name()) :: :ok | {:error, :not_found}
  def mark_unhealthy(port_name) do
    update_entry(port_name, fn entry -> %{entry | healthy: false} end)
  end

  @doc """
  Mark adapter as healthy.
  """
  @spec mark_healthy(port_name()) :: :ok | {:error, :not_found}
  def mark_healthy(port_name) do
    update_entry(port_name, fn entry -> %{entry | healthy: true} end)
  end

  @doc """
  Get health status.
  """
  @spec health_status(port_name()) :: :healthy | :unhealthy | :unknown
  def health_status(port_name) do
    case get(port_name) do
      {:ok, entry} -> if(entry.healthy, do: :healthy, else: :unhealthy)
      {:error, :not_found} -> :unknown
    end
  end

  @doc """
  Record a call for metrics tracking.
  """
  @spec record_call(port_name(), boolean()) :: :ok | {:error, :not_found}
  def record_call(port_name, success?) do
    update_entry(port_name, fn entry ->
      entry
      |> Map.update!(:call_count, &(&1 + 1))
      |> maybe_increment_errors(success?)
    end)
  end

  @doc """
  Get adapter metrics.
  """
  @spec metrics(port_name()) :: {:ok, metrics()} | {:error, :not_found}
  def metrics(port_name) do
    case get(port_name) do
      {:ok, entry} ->
        {:ok,
         %{
           call_count: entry.call_count,
           error_count: entry.error_count,
           error_rate: safe_div(entry.error_count, entry.call_count),
           healthy: entry.healthy,
           uptime: DateTime.diff(DateTime.utc_now(), entry.registered_at)
         }}

      {:error, :not_found} ->
        {:error, :not_found}
    end
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

  # Private helpers

  defp update_entry(port_name, fun) when is_function(fun, 1) do
    case :ets.lookup(@table_name, port_name) do
      [{^port_name, entry}] ->
        updated = fun.(entry)
        :ets.insert(@table_name, {port_name, updated})
        :ok

      [] ->
        {:error, :not_found}
    end
  end

  defp maybe_increment_errors(entry, true), do: entry

  defp maybe_increment_errors(entry, false) do
    Map.update!(entry, :error_count, &(&1 + 1))
  end

  defp safe_div(_num, 0), do: 0.0
  defp safe_div(num, denom), do: num / denom
end
