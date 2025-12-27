defmodule PortfolioCore.Telemetry do
  @moduledoc """
  Telemetry event definitions and helpers.

  Provides macros and functions for emitting telemetry events throughout
  the portfolio_core system. Follows the `:telemetry` library conventions.

  ## Event Naming

  All events are prefixed with `[:portfolio_core, ...]`:

  - `[:portfolio_core, :manifest, :loaded]` - Manifest loaded successfully
  - `[:portfolio_core, :adapter, :call, :start]` - Adapter call started
  - `[:portfolio_core, :adapter, :call, :stop]` - Adapter call completed
  - `[:portfolio_core, :adapter, :call, :exception]` - Adapter call failed

  ## Usage

      require PortfolioCore.Telemetry

      PortfolioCore.Telemetry.with_span [:adapter, :search], %{index: "my_index"} do
        # Your code here
      end

  ## Attaching Handlers

      :telemetry.attach_many(
        "my-handler",
        PortfolioCore.Telemetry.events(),
        &MyHandler.handle_event/4,
        nil
      )
  """

  @doc """
  Execute a function wrapped in telemetry span.

  Emits `:start`, `:stop`, and `:exception` events for the operation.

  ## Parameters

    - `name` - Event name (list of atoms, will be prefixed with `:portfolio_core`)
    - `metadata` - Additional metadata for the events
    - `block` - The code block to execute

  ## Events

  Three events are emitted:

    - `[:portfolio_core | name] ++ [:start]` - Before execution
    - `[:portfolio_core | name] ++ [:stop]` - After successful execution
    - `[:portfolio_core | name] ++ [:exception]` - On exception

  ## Example

      require PortfolioCore.Telemetry

      PortfolioCore.Telemetry.with_span [:search], %{query: query} do
        do_search(query)
      end
  """
  defmacro with_span(name, metadata \\ Macro.escape(%{}), do: block) do
    quote do
      unquote(__MODULE__).__execute_span__(
        unquote(name),
        unquote(metadata),
        fn -> unquote(block) end
      )
    end
  end

  @doc false
  def __execute_span__(name, metadata, fun) when is_function(fun, 0) do
    start_time = System.monotonic_time()
    start_metadata = Map.merge(%{start_time: start_time}, metadata)

    :telemetry.execute(
      [:portfolio_core | name] ++ [:start],
      %{system_time: System.system_time()},
      start_metadata
    )

    try do
      result = fun.()

      duration = System.monotonic_time() - start_time

      :telemetry.execute(
        [:portfolio_core | name] ++ [:stop],
        %{duration: duration},
        Map.put(start_metadata, :result, :ok)
      )

      result
    rescue
      e ->
        duration = System.monotonic_time() - start_time

        :telemetry.execute(
          [:portfolio_core | name] ++ [:exception],
          %{duration: duration},
          Map.merge(start_metadata, %{
            kind: :error,
            reason: e,
            stacktrace: __STACKTRACE__
          })
        )

        reraise e, __STACKTRACE__
    end
  end

  @doc """
  List of all telemetry events emitted by portfolio_core.

  Use this to attach handlers for all events:

      :telemetry.attach_many(
        "my-handler",
        PortfolioCore.Telemetry.events(),
        &handle_event/4,
        nil
      )
  """
  @spec events() :: [[atom()]]
  def events do
    [
      # Manifest events
      [:portfolio_core, :manifest, :loaded],
      [:portfolio_core, :manifest, :reload],
      [:portfolio_core, :manifest, :error],

      # Adapter events
      [:portfolio_core, :adapter, :call, :start],
      [:portfolio_core, :adapter, :call, :stop],
      [:portfolio_core, :adapter, :call, :exception],

      # Registry events
      [:portfolio_core, :registry, :register],
      [:portfolio_core, :registry, :lookup]
    ]
  end

  @doc """
  Emit a simple event.

  ## Parameters

    - `event` - Event name (list of atoms)
    - `measurements` - Event measurements (map)
    - `metadata` - Event metadata (map)

  ## Example

      PortfolioCore.Telemetry.emit(
        [:vector_store, :search],
        %{duration: 150, result_count: 10},
        %{index: "my_index"}
      )
  """
  @spec emit([atom()], map(), map()) :: :ok
  def emit(event, measurements, metadata) do
    :telemetry.execute([:portfolio_core | event], measurements, metadata)
  end

  @doc """
  Measure the duration of a function and emit telemetry.

  ## Parameters

    - `event` - Event name (list of atoms)
    - `metadata` - Event metadata
    - `fun` - Function to measure

  ## Returns

    - Result of the function

  ## Example

      PortfolioCore.Telemetry.measure([:search], %{query: q}, fn ->
        do_search(q)
      end)
  """
  @spec measure([atom()], map(), (-> result)) :: result when result: term()
  def measure(event, metadata, fun) when is_function(fun, 0) do
    start = System.monotonic_time()

    try do
      result = fun.()
      duration = System.monotonic_time() - start

      :telemetry.execute(
        [:portfolio_core | event],
        %{duration: duration},
        Map.put(metadata, :status, :ok)
      )

      result
    rescue
      e ->
        duration = System.monotonic_time() - start

        :telemetry.execute(
          [:portfolio_core | event],
          %{duration: duration},
          Map.merge(metadata, %{status: :error, error: Exception.message(e)})
        )

        reraise e, __STACKTRACE__
    end
  end
end
