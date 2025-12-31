defmodule PortfolioCore.Telemetry do
  @moduledoc """
  Telemetry event definitions and utilities for the Portfolio libraries.

  ## Event Naming Convention

  All events follow the pattern: `[:portfolio, :component, :operation]`

  ## Standard Events

  ### Embedding Events
  - `[:portfolio, :embedder, :embed, :start]`
  - `[:portfolio, :embedder, :embed, :stop]`
  - `[:portfolio, :embedder, :embed, :exception]`

  ### Vector Store Events
  - `[:portfolio, :vector_store, :search, :start]`
  - `[:portfolio, :vector_store, :search, :stop]`
  - `[:portfolio, :vector_store, :insert, :start]`
  - `[:portfolio, :vector_store, :insert, :stop]`

  ### LLM Events
  - `[:portfolio, :llm, :complete, :start]`
  - `[:portfolio, :llm, :complete, :stop]`
  - `[:portfolio, :llm, :complete, :exception]`

  ### RAG Pipeline Events
  - `[:portfolio, :rag, :rewrite, :start/:stop/:exception]`
  - `[:portfolio, :rag, :expand, :start/:stop/:exception]`
  - `[:portfolio, :rag, :decompose, :start/:stop/:exception]`
  - `[:portfolio, :rag, :select, :start/:stop/:exception]`
  - `[:portfolio, :rag, :search, :start/:stop/:exception]`
  - `[:portfolio, :rag, :rerank, :start/:stop/:exception]`
  - `[:portfolio, :rag, :answer, :start/:stop/:exception]`

  ### Evaluation Events
  - `[:portfolio, :evaluation, :run, :start/:stop/:exception]`
  - `[:portfolio, :evaluation, :test_case, :start/:stop]`

  ## Legacy Events

  For backwards compatibility, `[:portfolio_core, ...]` events are still emitted:

  - `[:portfolio_core, :manifest, :loaded]` - Manifest loaded successfully
  - `[:portfolio_core, :adapter, :call, :start]` - Adapter call started
  - `[:portfolio_core, :adapter, :call, :stop]` - Adapter call completed
  - `[:portfolio_core, :adapter, :call, :exception]` - Adapter call failed
  - `[:portfolio_core, :router, :route, :start]` - Router route started
  - `[:portfolio_core, :cache, :get, :hit]` - Cache hit event
  - `[:portfolio_core, :agent, :run, :start]` - Agent run started

  ## Usage

      require PortfolioCore.Telemetry

      PortfolioCore.Telemetry.with_span [:adapter, :search], %{index: "my_index"} do
        # Your code here
      end

      # Using the span function
      PortfolioCore.Telemetry.span([:portfolio, :embedder, :embed], %{text: "hello"}, fn ->
        do_embedding()
      end)

  ## Attaching Handlers

      :telemetry.attach_many(
        "my-handler",
        PortfolioCore.Telemetry.events(),
        &MyHandler.handle_event/4,
        nil
      )
  """

  @router_events [
    [:portfolio_core, :router, :route, :start],
    [:portfolio_core, :router, :route, :stop],
    [:portfolio_core, :router, :route, :exception],
    [:portfolio_core, :router, :health_check]
  ]

  @cache_events [
    [:portfolio_core, :cache, :get, :hit],
    [:portfolio_core, :cache, :get, :miss],
    [:portfolio_core, :cache, :put],
    [:portfolio_core, :cache, :delete]
  ]

  @agent_events [
    [:portfolio_core, :agent, :run, :start],
    [:portfolio_core, :agent, :run, :stop],
    [:portfolio_core, :agent, :tool, :execute]
  ]

  @evaluation_events [
    [:portfolio_core, :evaluation, :rag_triad, :start],
    [:portfolio_core, :evaluation, :rag_triad, :stop],
    [:portfolio_core, :evaluation, :rag_triad, :exception],
    [:portfolio_core, :evaluation, :hallucination, :start],
    [:portfolio_core, :evaluation, :hallucination, :stop],
    [:portfolio_core, :evaluation, :hallucination, :exception]
  ]

  @graph_events [
    [:portfolio_core, :graph_store, :traverse, :start],
    [:portfolio_core, :graph_store, :traverse, :stop],
    [:portfolio_core, :graph_store, :vector_search, :start],
    [:portfolio_core, :graph_store, :vector_search, :stop],
    [:portfolio_core, :graph_store, :community, :create],
    [:portfolio_core, :graph_store, :community, :update_summary]
  ]

  # Standard Portfolio events (new unified namespace)
  @embedder_events [
    [:portfolio, :embedder, :embed, :start],
    [:portfolio, :embedder, :embed, :stop],
    [:portfolio, :embedder, :embed, :exception],
    [:portfolio, :embedder, :embed_batch, :start],
    [:portfolio, :embedder, :embed_batch, :stop],
    [:portfolio, :embedder, :embed_batch, :exception]
  ]

  @vector_store_events [
    [:portfolio, :vector_store, :search, :start],
    [:portfolio, :vector_store, :search, :stop],
    [:portfolio, :vector_store, :search, :exception],
    [:portfolio, :vector_store, :insert, :start],
    [:portfolio, :vector_store, :insert, :stop],
    [:portfolio, :vector_store, :insert, :exception],
    [:portfolio, :vector_store, :insert_batch, :start],
    [:portfolio, :vector_store, :insert_batch, :stop],
    [:portfolio, :vector_store, :insert_batch, :exception]
  ]

  @llm_events [
    [:portfolio, :llm, :complete, :start],
    [:portfolio, :llm, :complete, :stop],
    [:portfolio, :llm, :complete, :exception]
  ]

  @rag_events [
    [:portfolio, :rag, :rewrite, :start],
    [:portfolio, :rag, :rewrite, :stop],
    [:portfolio, :rag, :rewrite, :exception],
    [:portfolio, :rag, :expand, :start],
    [:portfolio, :rag, :expand, :stop],
    [:portfolio, :rag, :expand, :exception],
    [:portfolio, :rag, :decompose, :start],
    [:portfolio, :rag, :decompose, :stop],
    [:portfolio, :rag, :decompose, :exception],
    [:portfolio, :rag, :select, :start],
    [:portfolio, :rag, :select, :stop],
    [:portfolio, :rag, :select, :exception],
    [:portfolio, :rag, :search, :start],
    [:portfolio, :rag, :search, :stop],
    [:portfolio, :rag, :search, :exception],
    [:portfolio, :rag, :rerank, :start],
    [:portfolio, :rag, :rerank, :stop],
    [:portfolio, :rag, :rerank, :exception],
    [:portfolio, :rag, :answer, :start],
    [:portfolio, :rag, :answer, :stop],
    [:portfolio, :rag, :answer, :exception],
    [:portfolio, :rag, :self_correct, :start],
    [:portfolio, :rag, :self_correct, :stop],
    [:portfolio, :rag, :self_correct, :exception]
  ]

  @portfolio_evaluation_events [
    [:portfolio, :evaluation, :run, :start],
    [:portfolio, :evaluation, :run, :stop],
    [:portfolio, :evaluation, :run, :exception],
    [:portfolio, :evaluation, :test_case, :start],
    [:portfolio, :evaluation, :test_case, :stop]
  ]

  @type event_name :: [atom()]
  @type measurements :: map()
  @type metadata :: map()

  @doc """
  Execute a function wrapped in telemetry span.
  Emits start, stop, and exception events automatically.

  This function uses the standard `:telemetry.span/3` pattern.
  Unlike `with_span`, the event name is used as-is without prefixing.

  ## Parameters

    - `event` - Event name (list of atoms)
    - `metadata` - Additional metadata for the events
    - `fun` - Function to execute (arity 0)

  ## Example

      PortfolioCore.Telemetry.span(
        [:portfolio, :embedder, :embed],
        %{text: "hello world"},
        fn -> generate_embedding(text) end
      )
  """
  @spec span(event_name(), metadata(), (-> result)) :: result when result: any()
  def span(event, metadata, fun) when is_list(event) and is_function(fun, 0) do
    :telemetry.span(event, metadata, fn ->
      result = fun.()
      {result, %{}}
    end)
  end

  @doc """
  Execute a function wrapped in telemetry span (legacy).

  Emits `:start`, `:stop`, and `:exception` events for the operation.
  Event names are prefixed with `:portfolio_core`.

  For new code, prefer using `span/3` with the new `[:portfolio, ...]` namespace.

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
  Get all defined event names for documentation/attachment.

  Returns both legacy `[:portfolio_core, ...]` events and new
  `[:portfolio, ...]` events.

  Use this to attach handlers for all events:

      :telemetry.attach_many(
        "my-handler",
        PortfolioCore.Telemetry.events(),
        &handle_event/4,
        nil
      )
  """
  @spec events() :: [event_name()]
  def events do
    legacy_events() ++ portfolio_events()
  end

  @doc """
  Get events for a specific component.

  ## Parameters

    - `component` - Component name (`:embedder`, `:vector_store`, `:llm`, `:rag`, `:evaluation`)

  ## Example

      PortfolioCore.Telemetry.events_for(:embedder)
      # => [[:portfolio, :embedder, :embed, :start], ...]

      PortfolioCore.Telemetry.events_for(:llm)
      # => [[:portfolio, :llm, :complete, :start], ...]
  """
  @spec events_for(atom()) :: [event_name()]
  def events_for(:embedder), do: @embedder_events
  def events_for(:vector_store), do: @vector_store_events
  def events_for(:llm), do: @llm_events
  def events_for(:rag), do: @rag_events
  def events_for(:evaluation), do: @portfolio_evaluation_events
  def events_for(:router), do: @router_events
  def events_for(:cache), do: @cache_events
  def events_for(:agent), do: @agent_events
  def events_for(:graph), do: @graph_events
  def events_for(_), do: []

  @doc false
  def legacy_events do
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
    ] ++
      @router_events ++
      @cache_events ++
      @agent_events ++
      @evaluation_events ++
      @graph_events
  end

  @doc false
  def portfolio_events do
    @embedder_events ++
      @vector_store_events ++
      @llm_events ++
      @rag_events ++
      @portfolio_evaluation_events
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
