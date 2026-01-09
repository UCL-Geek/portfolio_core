# Portfolio Core - Implementation Details

## New Port Specifications

### 1. Router Port

```elixir
# lib/portfolio_core/ports/router.ex
defmodule PortfolioCore.Ports.Router do
  @moduledoc """
  Behavior for multi-provider LLM routing.

  The Router port enables intelligent distribution of LLM requests
  across multiple providers based on various strategies:

  - `:fallback` - Try providers in priority order
  - `:round_robin` - Distribute evenly across healthy providers
  - `:specialist` - Route based on task type and provider capabilities
  - `:cost_optimized` - Minimize cost while meeting requirements

  ## Example Implementation

      defmodule MyApp.Router do
        @behaviour PortfolioCore.Ports.Router

        @impl true
        def route(messages, opts) do
          strategy = Keyword.get(opts, :strategy, :fallback)
          task_type = Keyword.get(opts, :task_type, :general)

          providers = list_providers()
          |> Enum.filter(&healthy?/1)
          |> apply_strategy(strategy, task_type)

          case providers do
            [provider | _] -> {:ok, provider}
            [] -> {:error, :no_healthy_providers}
          end
        end
      end
  """

  @type strategy :: :fallback | :round_robin | :specialist | :cost_optimized

  @type provider :: %{
    name: atom(),
    module: module(),
    config: map(),
    capabilities: [capability()],
    priority: non_neg_integer(),
    cost_per_token: float(),
    healthy: boolean()
  }

  @type capability ::
    :generation
    | :reasoning
    | :code
    | :embedding
    | :streaming
    | :function_calling
    | :vision

  @type route_opts :: [
    strategy: strategy(),
    task_type: capability(),
    max_tokens: pos_integer(),
    timeout: pos_integer()
  ]

  @doc """
  Select a provider for the given messages and options.
  """
  @callback route(messages :: [map()], opts :: route_opts()) ::
    {:ok, provider()} | {:error, :no_healthy_providers | term()}

  @doc """
  Register a new provider with the router.
  """
  @callback register_provider(provider()) :: :ok | {:error, term()}

  @doc """
  Remove a provider from the router.
  """
  @callback unregister_provider(name :: atom()) :: :ok

  @doc """
  Check health status of a specific provider.
  """
  @callback health_check(name :: atom()) :: :healthy | :unhealthy | :unknown

  @doc """
  List all registered providers.
  """
  @callback list_providers() :: [provider()]

  @doc """
  Set the default routing strategy.
  """
  @callback set_strategy(strategy()) :: :ok

  @doc """
  Get current routing strategy.
  """
  @callback get_strategy() :: strategy()
end
```

### 2. Cache Port

```elixir
# lib/portfolio_core/ports/cache.ex
defmodule PortfolioCore.Ports.Cache do
  @moduledoc """
  Behavior for caching implementations.

  Supports various backends:
  - ETS for local, in-process caching
  - Redis for distributed caching
  - Mnesia for distributed, persistent caching

  ## Features
  - TTL-based expiration
  - Batch operations
  - Namespace isolation
  - Statistics tracking

  ## Example Implementation

      defmodule MyApp.Cache.ETS do
        @behaviour PortfolioCore.Ports.Cache

        @impl true
        def get(key) do
          case :ets.lookup(@table, key) do
            [{^key, value, expires_at}] when expires_at > now() ->
              {:ok, value}
            _ ->
              {:error, :not_found}
          end
        end
      end
  """

  @type key :: term()
  @type value :: term()
  @type ttl :: pos_integer() | :infinity
  @type namespace :: String.t() | atom()

  @type stats :: %{
    hits: non_neg_integer(),
    misses: non_neg_integer(),
    size: non_neg_integer(),
    memory_bytes: non_neg_integer()
  }

  @type cache_opts :: [
    namespace: namespace(),
    ttl: ttl(),
    compress: boolean()
  ]

  @doc """
  Retrieve a value by key.
  """
  @callback get(key(), opts :: cache_opts()) ::
    {:ok, value()} | {:error, :not_found | term()}

  @doc """
  Store a value with optional TTL.
  """
  @callback put(key(), value(), opts :: cache_opts()) ::
    :ok | {:error, term()}

  @doc """
  Delete a key.
  """
  @callback delete(key(), opts :: cache_opts()) :: :ok

  @doc """
  Check if key exists.
  """
  @callback exists?(key(), opts :: cache_opts()) :: boolean()

  @doc """
  Get multiple keys at once.
  """
  @callback get_many([key()], opts :: cache_opts()) :: %{key() => value()}

  @doc """
  Store multiple key-value pairs.
  """
  @callback put_many([{key(), value()}], opts :: cache_opts()) ::
    :ok | {:error, term()}

  @doc """
  Clear all keys in namespace.
  """
  @callback clear(opts :: cache_opts()) :: :ok

  @doc """
  Get cache statistics.
  """
  @callback stats(opts :: cache_opts()) :: stats()

  @doc """
  Refresh TTL for a key.
  """
  @callback touch(key(), ttl(), opts :: cache_opts()) ::
    :ok | {:error, :not_found}
end
```

### 3. Pipeline Port

```elixir
# lib/portfolio_core/ports/pipeline.ex
defmodule PortfolioCore.Ports.Pipeline do
  @moduledoc """
  Behavior for pipeline step implementations.

  Pipelines are composed of steps that:
  - Have explicit input/output schemas
  - Can be cached based on inputs
  - Support timeout and retry
  - Emit telemetry events

  ## Example Step Implementation

      defmodule MyApp.Steps.ExtractEntities do
        @behaviour PortfolioCore.Ports.Pipeline

        @impl true
        def execute(context, config) do
          text = context.inputs[:text]
          llm = config[:llm_adapter]

          case llm.complete(entity_prompt(text)) do
            {:ok, response} -> {:ok, parse_entities(response)}
            error -> error
          end
        end

        @impl true
        def required_inputs, do: [:text]

        @impl true
        def cacheable?, do: true
      end
  """

  @type step_status :: :pending | :running | :completed | :failed | :skipped

  @type step_result ::
    {:ok, term()}
    | {:error, term()}
    | {:skip, reason :: term()}

  @type step_context :: %{
    step_name: atom(),
    pipeline_name: atom(),
    inputs: map(),
    metadata: map(),
    attempt: pos_integer()
  }

  @type output_type ::
    :any
    | :string
    | :map
    | :list
    | {:list, output_type()}
    | {:map, key_type :: output_type(), value_type :: output_type()}

  @doc """
  Execute the pipeline step.
  """
  @callback execute(context :: step_context(), config :: keyword()) ::
    step_result()

  @doc """
  Validate input before execution.
  """
  @callback validate_input(input :: term()) :: :ok | {:error, term()}

  @doc """
  Describe the output schema.
  """
  @callback output_schema() :: %{atom() => output_type()}

  @doc """
  List required input keys.
  """
  @callback required_inputs() :: [atom()]

  @doc """
  Whether step results can be cached.
  """
  @callback cacheable?() :: boolean()

  @doc """
  Estimated execution time in milliseconds.
  """
  @callback estimated_duration() :: pos_integer()

  @optional_callbacks [validate_input: 1, estimated_duration: 0]
end
```

### 4. Agent Port

```elixir
# lib/portfolio_core/ports/agent.ex
defmodule PortfolioCore.Ports.Agent do
  @moduledoc """
  Behavior for tool-using agent implementations.

  Agents can:
  - Execute multi-step reasoning
  - Use tools to gather information
  - Maintain session memory
  - Self-correct based on results

  ## Example Implementation

      defmodule MyApp.Agent do
        @behaviour PortfolioCore.Ports.Agent

        @impl true
        def run(task, opts) do
          tools = Keyword.get(opts, :tools, default_tools())
          max_iter = Keyword.get(opts, :max_iterations, 10)

          execute_loop(task, tools, [], 0, max_iter)
        end
      end
  """

  @type tool_spec :: %{
    name: atom(),
    description: String.t(),
    parameters: [parameter_spec()],
    required: [atom()]
  }

  @type parameter_spec :: %{
    name: atom(),
    type: :string | :integer | :boolean | :list | :map,
    description: String.t(),
    required: boolean()
  }

  @type tool_call :: %{
    id: String.t(),
    tool: atom(),
    arguments: map()
  }

  @type tool_result :: %{
    id: String.t(),
    tool: atom(),
    result: term(),
    success: boolean()
  }

  @type agent_state :: %{
    task: String.t(),
    memory: [message()],
    tool_calls: [tool_call()],
    tool_results: [tool_result()],
    iteration: non_neg_integer()
  }

  @type message :: %{
    role: :user | :assistant | :tool,
    content: String.t()
  }

  @type run_opts :: [
    tools: [atom()],
    max_iterations: pos_integer(),
    timeout: pos_integer(),
    memory: [message()]
  ]

  @doc """
  Execute an agent task.
  """
  @callback run(task :: String.t(), opts :: run_opts()) ::
    {:ok, result :: term()} | {:error, term()}

  @doc """
  List available tools.
  """
  @callback available_tools() :: [tool_spec()]

  @doc """
  Execute a single tool call.
  """
  @callback execute_tool(tool_call()) ::
    {:ok, tool_result()} | {:error, term()}

  @doc """
  Get maximum allowed iterations.
  """
  @callback max_iterations() :: pos_integer()

  @doc """
  Get current agent state (for debugging/monitoring).
  """
  @callback get_state() :: agent_state()

  @optional_callbacks [get_state: 0]
end
```

### 5. Tool Port

```elixir
# lib/portfolio_core/ports/tool.ex
defmodule PortfolioCore.Ports.Tool do
  @moduledoc """
  Behavior for individual agent tools.

  Tools are the building blocks agents use to interact
  with external systems and gather information.

  ## Example Implementation

      defmodule MyApp.Tools.SearchCode do
        @behaviour PortfolioCore.Ports.Tool

        @impl true
        def name, do: :search_code

        @impl true
        def description do
          "Search the codebase using semantic similarity"
        end

        @impl true
        def parameters do
          [
            %{name: :query, type: :string, required: true,
              description: "Search query"},
            %{name: :limit, type: :integer, required: false,
              description: "Max results"}
          ]
        end

        @impl true
        def execute(%{query: query} = args) do
          limit = Map.get(args, :limit, 5)
          VectorStore.search(query, limit: limit)
        end
      end
  """

  @type parameter :: %{
    name: atom(),
    type: :string | :integer | :float | :boolean | :list | :map,
    required: boolean(),
    description: String.t(),
    default: term()
  }

  @doc """
  Tool identifier.
  """
  @callback name() :: atom()

  @doc """
  Human-readable description for LLM.
  """
  @callback description() :: String.t()

  @doc """
  Parameter specifications.
  """
  @callback parameters() :: [parameter()]

  @doc """
  Execute the tool with given arguments.
  """
  @callback execute(args :: map()) :: {:ok, term()} | {:error, term()}

  @doc """
  Whether tool can be safely retried on failure.
  """
  @callback idempotent?() :: boolean()

  @optional_callbacks [idempotent?: 0]
end
```

## Enhanced Manifest Schema

```elixir
# lib/portfolio_core/manifest/schema.ex additions

@manifest_schema [
  version: [type: :string, required: true],
  schema_version: [type: :integer, default: 1],
  environment: [type: :atom, required: true],

  # NEW: Inheritance
  extends: [type: :string, doc: "Path to base manifest"],

  # NEW: Profiles
  profiles: [
    type: :map,
    keys: [
      default: [type: :map],
      performance: [type: :map],
      cost_optimized: [type: :map]
    ]
  ],

  adapters: [
    type: :map,
    required: true,
    keys: adapter_keys()
  ],

  # NEW: Router configuration
  router: [
    type: :map,
    keys: [
      strategy: [type: {:in, [:fallback, :round_robin, :specialist, :cost_optimized]}],
      health_check_interval: [type: :pos_integer, default: 30_000],
      providers: [type: {:list, :map}]
    ]
  ],

  # NEW: Cache configuration
  cache: [
    type: :map,
    keys: [
      enabled: [type: :boolean, default: true],
      backend: [type: {:in, [:ets, :redis, :mnesia]}],
      default_ttl: [type: :pos_integer, default: 3600],
      namespaces: [type: :map]
    ]
  ],

  # NEW: Agent configuration
  agent: [
    type: :map,
    keys: [
      max_iterations: [type: :pos_integer, default: 10],
      timeout: [type: :pos_integer, default: 300_000],
      tools: [type: {:list, :atom}]
    ]
  ],

  # Existing
  pipelines: [type: :map],
  graphs: [type: :map],
  rag: [type: :map],
  telemetry: [type: :map]
]
```

## Registry Enhancements

```elixir
# lib/portfolio_core/registry.ex additions

defmodule PortfolioCore.Registry do
  # ... existing code ...

  @doc """
  Register adapter with metadata.
  """
  def register(port, module, config, metadata \\ %{}) do
    entry = %{
      module: module,
      config: config,
      metadata: metadata,
      registered_at: DateTime.utc_now(),
      healthy: true,
      call_count: 0,
      error_count: 0
    }
    :ets.insert(@table, {port, entry})
    emit_telemetry(:register, port)
    :ok
  end

  @doc """
  Find adapters by capability.
  """
  def find_by_capability(capability) do
    :ets.tab2list(@table)
    |> Enum.filter(fn {_port, entry} ->
      capability in (entry.metadata[:capabilities] || [])
    end)
    |> Enum.map(fn {port, entry} -> {port, entry.module, entry.config} end)
  end

  @doc """
  Mark adapter as unhealthy.
  """
  def mark_unhealthy(port) do
    update_entry(port, fn entry -> %{entry | healthy: false} end)
  end

  @doc """
  Mark adapter as healthy.
  """
  def mark_healthy(port) do
    update_entry(port, fn entry -> %{entry | healthy: true} end)
  end

  @doc """
  Get health status.
  """
  def health_status(port) do
    case get(port) do
      {:ok, entry} -> if entry.healthy, do: :healthy, else: :unhealthy
      _ -> :unknown
    end
  end

  @doc """
  Increment call counter.
  """
  def record_call(port, success?) do
    update_entry(port, fn entry ->
      entry
      |> Map.update!(:call_count, & &1 + 1)
      |> then(fn e ->
        if success?, do: e, else: Map.update!(e, :error_count, & &1 + 1)
      end)
    end)
  end

  @doc """
  Get adapter metrics.
  """
  def metrics(port) do
    case get(port) do
      {:ok, entry} ->
        {:ok, %{
          call_count: entry.call_count,
          error_count: entry.error_count,
          error_rate: safe_div(entry.error_count, entry.call_count),
          healthy: entry.healthy,
          uptime: DateTime.diff(DateTime.utc_now(), entry.registered_at)
        }}
      error -> error
    end
  end
end
```

### Backend Capability Discovery

Use `backend_capabilities/2` with `PortfolioCore.Backend.Capabilities` to expose
metadata compatible with `CrucibleIR.Backend.Capabilities`:

```elixir
Registry.register(:llm, MyLLM, config, %{
  capabilities: [:generation, :streaming],
  backend_capabilities: %{
    backend_id: :openai,
    provider: "openai",
    models: ["gpt-4o-mini"],
    supports_vision: true
  }
})

{:ok, caps} = Registry.backend_capabilities(:llm)
backend_ir = PortfolioCore.Backend.Capabilities.to_backend_ir(caps)
```

## File Structure

```
lib/portfolio_core/
├── portfolio_core.ex           # Main API
├── application.ex              # OTP app
├── registry.ex                 # Enhanced registry
├── telemetry.ex                # Enhanced telemetry
│
├── ports/
│   ├── vector_store.ex         # Existing
│   ├── graph_store.ex          # Existing
│   ├── document_store.ex       # Existing
│   ├── embedder.ex             # Existing
│   ├── llm.ex                  # Existing
│   ├── chunker.ex              # Existing
│   ├── retriever.ex            # Existing
│   ├── reranker.ex             # Existing
│   ├── router.ex               # NEW
│   ├── cache.ex                # NEW
│   ├── pipeline.ex             # NEW
│   ├── agent.ex                # NEW
│   ├── tool.ex                 # NEW
│   ├── tenant.ex               # NEW (Tier 3)
│   └── stream.ex               # NEW (Tier 3)
│
└── manifest/
    ├── loader.ex               # Enhanced
    ├── schema.ex               # Enhanced
    ├── engine.ex               # Existing
    └── inheritance.ex          # NEW
```
