# Portfolio Core v0.2.0 Implementation Prompt

## Mission

Implement new port specifications for Router, Cache, Pipeline, Agent, and Tool behaviors, plus enhanced Registry and Manifest features. Use TDD. All tests passing, no warnings, no dialyzer errors, credo --strict clean.

---

## Required Reading

### Documentation (Read First)
```
docs/20251227/ecosystem_expansion/01_current_state.md
docs/20251227/ecosystem_expansion/02_expansion_roadmap.md
docs/20251227/ecosystem_expansion/03_implementation_details.md
docs/20251226/IMPLEMENTATION_PROMPT.md
```

### Source Files (Understand Patterns)
```
lib/portfolio_core.ex
lib/portfolio_core/application.ex
lib/portfolio_core/registry.ex
lib/portfolio_core/telemetry.ex

lib/portfolio_core/ports/vector_store.ex
lib/portfolio_core/ports/graph_store.ex
lib/portfolio_core/ports/document_store.ex
lib/portfolio_core/ports/embedder.ex
lib/portfolio_core/ports/llm.ex
lib/portfolio_core/ports/chunker.ex
lib/portfolio_core/ports/retriever.ex
lib/portfolio_core/ports/reranker.ex

lib/portfolio_core/manifest/loader.ex
lib/portfolio_core/manifest/schema.ex
lib/portfolio_core/manifest/engine.ex
```

### Test Files (Match Patterns)
```
test/test_helper.exs
test/portfolio_core_test.exs
test/registry_test.exs
test/telemetry_test.exs
test/manifest/loader_test.exs
test/manifest/schema_test.exs
test/manifest/engine_test.exs
```

### Configuration
```
mix.exs
config/config.exs
README.md
CHANGELOG.md
examples/README.md
```

---

## Implementation Tasks

### Task 1: New Port Specifications

Create the following port behavior modules following the exact patterns in existing ports:

#### 1.1 Router Port (`lib/portfolio_core/ports/router.ex`)

```elixir
defmodule PortfolioCore.Ports.Router do
  @moduledoc """
  Behavior for multi-provider LLM routing.

  Enables intelligent distribution of LLM requests across multiple providers
  based on strategies: fallback, round_robin, specialist, cost_optimized.
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
    :generation | :reasoning | :code | :embedding |
    :streaming | :function_calling | :vision

  @type route_opts :: [
    strategy: strategy(),
    task_type: capability(),
    max_tokens: pos_integer(),
    timeout: pos_integer()
  ]

  @callback route(messages :: [map()], opts :: route_opts()) ::
    {:ok, provider()} | {:error, :no_healthy_providers | term()}

  @callback register_provider(provider()) :: :ok | {:error, term()}

  @callback unregister_provider(name :: atom()) :: :ok

  @callback health_check(name :: atom()) :: :healthy | :unhealthy | :unknown

  @callback list_providers() :: [provider()]

  @callback set_strategy(strategy()) :: :ok

  @callback get_strategy() :: strategy()
end
```

#### 1.2 Cache Port (`lib/portfolio_core/ports/cache.ex`)

```elixir
defmodule PortfolioCore.Ports.Cache do
  @moduledoc """
  Behavior for caching implementations (ETS, Redis, Mnesia).
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

  @callback get(key(), opts :: cache_opts()) ::
    {:ok, value()} | {:error, :not_found | term()}

  @callback put(key(), value(), opts :: cache_opts()) ::
    :ok | {:error, term()}

  @callback delete(key(), opts :: cache_opts()) :: :ok

  @callback exists?(key(), opts :: cache_opts()) :: boolean()

  @callback get_many([key()], opts :: cache_opts()) :: %{key() => value()}

  @callback put_many([{key(), value()}], opts :: cache_opts()) ::
    :ok | {:error, term()}

  @callback clear(opts :: cache_opts()) :: :ok

  @callback stats(opts :: cache_opts()) :: stats()

  @callback touch(key(), ttl(), opts :: cache_opts()) ::
    :ok | {:error, :not_found}
end
```

#### 1.3 Pipeline Port (`lib/portfolio_core/ports/pipeline.ex`)

```elixir
defmodule PortfolioCore.Ports.Pipeline do
  @moduledoc """
  Behavior for pipeline step implementations.
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
    :any | :string | :map | :list |
    {:list, output_type()} |
    {:map, key_type :: output_type(), value_type :: output_type()}

  @callback execute(context :: step_context(), config :: keyword()) ::
    step_result()

  @callback validate_input(input :: term()) :: :ok | {:error, term()}

  @callback output_schema() :: %{atom() => output_type()}

  @callback required_inputs() :: [atom()]

  @callback cacheable?() :: boolean()

  @callback estimated_duration() :: pos_integer()

  @optional_callbacks [validate_input: 1, estimated_duration: 0]
end
```

#### 1.4 Agent Port (`lib/portfolio_core/ports/agent.ex`)

```elixir
defmodule PortfolioCore.Ports.Agent do
  @moduledoc """
  Behavior for tool-using agent implementations.
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

  @callback run(task :: String.t(), opts :: run_opts()) ::
    {:ok, result :: term()} | {:error, term()}

  @callback available_tools() :: [tool_spec()]

  @callback execute_tool(tool_call()) ::
    {:ok, tool_result()} | {:error, term()}

  @callback max_iterations() :: pos_integer()

  @callback get_state() :: agent_state()

  @optional_callbacks [get_state: 0]
end
```

#### 1.5 Tool Port (`lib/portfolio_core/ports/tool.ex`)

```elixir
defmodule PortfolioCore.Ports.Tool do
  @moduledoc """
  Behavior for individual agent tools.
  """

  @type parameter :: %{
    name: atom(),
    type: :string | :integer | :float | :boolean | :list | :map,
    required: boolean(),
    description: String.t(),
    default: term()
  }

  @callback name() :: atom()

  @callback description() :: String.t()

  @callback parameters() :: [parameter()]

  @callback execute(args :: map()) :: {:ok, term()} | {:error, term()}

  @callback idempotent?() :: boolean()

  @optional_callbacks [idempotent?: 0]
end
```

### Task 2: Enhanced Registry

Update `lib/portfolio_core/registry.ex` with:

```elixir
# Add to existing module

@doc """
Register adapter with metadata.
"""
def register(port, module, config, metadata \\ %{})

@doc """
Find adapters by capability.
"""
def find_by_capability(capability)

@doc """
Mark adapter as unhealthy.
"""
def mark_unhealthy(port)

@doc """
Mark adapter as healthy.
"""
def mark_healthy(port)

@doc """
Get health status.
"""
def health_status(port)

@doc """
Record a call (for metrics).
"""
def record_call(port, success?)

@doc """
Get adapter metrics.
"""
def metrics(port)
```

### Task 3: Enhanced Manifest Schema

Update `lib/portfolio_core/manifest/schema.ex` to add:

```elixir
# Add to schema
router: [
  type: :map,
  keys: [
    strategy: [type: {:in, [:fallback, :round_robin, :specialist, :cost_optimized]}],
    health_check_interval: [type: :pos_integer, default: 30_000],
    providers: [type: {:list, :map}]
  ]
],

cache: [
  type: :map,
  keys: [
    enabled: [type: :boolean, default: true],
    backend: [type: {:in, [:ets, :redis, :mnesia]}],
    default_ttl: [type: :pos_integer, default: 3600],
    namespaces: [type: :map]
  ]
],

agent: [
  type: :map,
  keys: [
    max_iterations: [type: :pos_integer, default: 10],
    timeout: [type: :pos_integer, default: 300_000],
    tools: [type: {:list, :atom}]
  ]
]
```

### Task 4: Telemetry Events

Update `lib/portfolio_core/telemetry.ex` to add:

```elixir
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
```

---

## TDD Process

### Step 1: Write Tests First

For each new port, create test file:

```
test/ports/router_test.exs
test/ports/cache_test.exs
test/ports/pipeline_test.exs
test/ports/agent_test.exs
test/ports/tool_test.exs
```

Each test file should:
1. Define a mock implementation using Mox
2. Test all callbacks are defined
3. Test type specifications compile
4. Test documentation exists

Example pattern from existing tests:
```elixir
defmodule PortfolioCore.Ports.RouterTest do
  use ExUnit.Case, async: true

  alias PortfolioCore.Ports.Router

  describe "behaviour" do
    test "defines all required callbacks" do
      callbacks = Router.behaviour_info(:callbacks)

      assert {:route, 2} in callbacks
      assert {:register_provider, 1} in callbacks
      assert {:unregister_provider, 1} in callbacks
      assert {:health_check, 1} in callbacks
      assert {:list_providers, 0} in callbacks
      assert {:set_strategy, 1} in callbacks
      assert {:get_strategy, 0} in callbacks
    end

    test "defines optional callbacks" do
      optional = Router.behaviour_info(:optional_callbacks)
      # None for Router
      assert optional == []
    end
  end
end
```

### Step 2: Registry Tests

```elixir
# test/registry_test.exs additions

describe "enhanced registry" do
  test "register/4 stores metadata" do
    :ok = Registry.register(:test_port, TestModule, %{}, %{capabilities: [:code]})
    {:ok, entry} = Registry.get(:test_port)

    assert entry.metadata.capabilities == [:code]
  end

  test "find_by_capability/1 returns matching adapters" do
    Registry.register(:port1, Mod1, %{}, %{capabilities: [:code, :reasoning]})
    Registry.register(:port2, Mod2, %{}, %{capabilities: [:code]})
    Registry.register(:port3, Mod3, %{}, %{capabilities: [:embedding]})

    result = Registry.find_by_capability(:code)

    assert length(result) == 2
  end

  test "health status tracking" do
    Registry.register(:health_port, TestMod, %{})

    assert Registry.health_status(:health_port) == :healthy

    Registry.mark_unhealthy(:health_port)
    assert Registry.health_status(:health_port) == :unhealthy

    Registry.mark_healthy(:health_port)
    assert Registry.health_status(:health_port) == :healthy
  end

  test "metrics tracking" do
    Registry.register(:metrics_port, TestMod, %{})

    Registry.record_call(:metrics_port, true)
    Registry.record_call(:metrics_port, true)
    Registry.record_call(:metrics_port, false)

    {:ok, metrics} = Registry.metrics(:metrics_port)

    assert metrics.call_count == 3
    assert metrics.error_count == 1
  end
end
```

### Step 3: Schema Tests

```elixir
# test/manifest/schema_test.exs additions

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
```

### Step 4: Run Tests

```bash
mix test
```

All tests must pass before proceeding.

---

## Documentation Updates

### README.md

Add to feature list:
```markdown
## Features

### Port Specifications (13 total)

**Storage Ports:**
- `VectorStore` - Vector similarity search
- `GraphStore` - Knowledge graph operations
- `DocumentStore` - Document storage and retrieval

**AI Ports:**
- `Embedder` - Text embedding generation
- `LLM` - Language model completions
- `Chunker` - Document chunking strategies
- `Retriever` - Retrieval strategies
- `Reranker` - Result reranking

**Infrastructure Ports (NEW in v0.2.0):**
- `Router` - Multi-provider LLM routing
- `Cache` - Caching layer abstraction
- `Pipeline` - Workflow step definitions
- `Agent` - Tool-using agent behavior
- `Tool` - Individual tool definitions
```

Add new section:
```markdown
## Enhanced Registry (v0.2.0)

The registry now supports:
- Adapter metadata and capabilities
- Health status tracking
- Call metrics and error rates

\`\`\`elixir
# Register with capabilities
PortfolioCore.Registry.register(:llm, MyLLM, config, %{
  capabilities: [:generation, :streaming]
})

# Find by capability
PortfolioCore.Registry.find_by_capability(:streaming)

# Health tracking
PortfolioCore.Registry.mark_unhealthy(:llm)
PortfolioCore.Registry.health_status(:llm)  # => :unhealthy
\`\`\`
```

### CHANGELOG.md

```markdown
# Changelog

## [0.2.0] - 2025-12-27

### Added
- `PortfolioCore.Ports.Router` - Multi-provider LLM routing behavior
- `PortfolioCore.Ports.Cache` - Caching layer behavior
- `PortfolioCore.Ports.Pipeline` - Pipeline step behavior
- `PortfolioCore.Ports.Agent` - Tool-using agent behavior
- `PortfolioCore.Ports.Tool` - Individual tool behavior
- Enhanced Registry with metadata, capabilities, health tracking, and metrics
- New manifest schema fields: `router`, `cache`, `agent`
- New telemetry events for router, cache, and agent operations

### Changed
- Registry.register/3 now accepts optional metadata parameter
- Manifest schema expanded with new configuration sections
```

### Examples

Create/update:

```
examples/router_port.exs
examples/cache_port.exs
examples/agent_port.exs
examples/enhanced_registry.exs
```

#### examples/router_port.exs
```elixir
# Example: Implementing the Router port

defmodule MyRouter do
  @behaviour PortfolioCore.Ports.Router

  use GenServer

  # ... implementation
end

# Usage
{:ok, provider} = MyRouter.route(messages, strategy: :specialist)
```

#### examples/enhanced_registry.exs
```elixir
# Example: Using enhanced registry features

alias PortfolioCore.Registry

# Register with metadata
Registry.register(:primary_llm, MyLLM, %{model: "gpt-4"}, %{
  capabilities: [:generation, :streaming, :function_calling]
})

# Find capable adapters
streaming_adapters = Registry.find_by_capability(:streaming)
IO.inspect(streaming_adapters, label: "Streaming capable")

# Health management
Registry.mark_unhealthy(:primary_llm)
IO.puts("Status: #{Registry.health_status(:primary_llm)}")

# Metrics
Registry.record_call(:primary_llm, true)
{:ok, metrics} = Registry.metrics(:primary_llm)
IO.inspect(metrics)
```

#### examples/README.md
```markdown
# Portfolio Core Examples

## Running Examples

\`\`\`bash
# Run all examples
./run_all.sh

# Run individual examples
mix run examples/basic_port_usage.exs
mix run examples/manifest_loading.exs
mix run examples/custom_adapter.exs
mix run examples/router_port.exs
mix run examples/cache_port.exs
mix run examples/agent_port.exs
mix run examples/enhanced_registry.exs
\`\`\`

## Examples

| File | Description |
|------|-------------|
| basic_port_usage.exs | Using port behaviors |
| manifest_loading.exs | Loading YAML manifests |
| custom_adapter.exs | Creating custom adapters |
| router_port.exs | Multi-provider routing (v0.2.0) |
| cache_port.exs | Caching behavior (v0.2.0) |
| agent_port.exs | Agent behavior (v0.2.0) |
| enhanced_registry.exs | Registry features (v0.2.0) |
```

#### examples/run_all.sh
```bash
#!/bin/bash
set -e

echo "=== Portfolio Core Examples ==="
echo ""

echo "1. Basic Port Usage"
mix run examples/basic_port_usage.exs
echo ""

echo "2. Manifest Loading"
mix run examples/manifest_loading.exs
echo ""

echo "3. Custom Adapter"
mix run examples/custom_adapter.exs
echo ""

echo "4. Router Port (v0.2.0)"
mix run examples/router_port.exs
echo ""

echo "5. Cache Port (v0.2.0)"
mix run examples/cache_port.exs
echo ""

echo "6. Agent Port (v0.2.0)"
mix run examples/agent_port.exs
echo ""

echo "7. Enhanced Registry (v0.2.0)"
mix run examples/enhanced_registry.exs
echo ""

echo "=== All examples completed successfully ==="
```

---

## Version Bump

### mix.exs
```elixir
def project do
  [
    app: :portfolio_core,
    version: "0.2.0",
    # ...
  ]
end
```

### README.md
Update version badge and installation:
```markdown
{:portfolio_core, "~> 0.2.0"}
```

---

## Quality Gates

### All Must Pass

```bash
# Format check
mix format --check-formatted

# Credo strict
mix credo --strict

# Dialyzer
mix dialyzer

# Tests with coverage
mix test --cover

# Docs generation
mix docs
```

### Acceptance Criteria

- [ ] All 5 new ports implemented with full typespecs
- [ ] Enhanced registry with 6 new functions
- [ ] Manifest schema extended with 3 new sections
- [ ] Telemetry events for new features
- [ ] Tests for all new code (>95% coverage)
- [ ] No compiler warnings
- [ ] No dialyzer errors
- [ ] Credo --strict passes
- [ ] README updated with new features
- [ ] CHANGELOG updated for v0.2.0
- [ ] All examples work and are documented
- [ ] examples/run_all.sh runs successfully
- [ ] mix.exs version bumped to 0.2.0

---

## File Checklist

### New Files
- [ ] `lib/portfolio_core/ports/router.ex`
- [ ] `lib/portfolio_core/ports/cache.ex`
- [ ] `lib/portfolio_core/ports/pipeline.ex`
- [ ] `lib/portfolio_core/ports/agent.ex`
- [ ] `lib/portfolio_core/ports/tool.ex`
- [ ] `test/ports/router_test.exs`
- [ ] `test/ports/cache_test.exs`
- [ ] `test/ports/pipeline_test.exs`
- [ ] `test/ports/agent_test.exs`
- [ ] `test/ports/tool_test.exs`
- [ ] `examples/router_port.exs`
- [ ] `examples/cache_port.exs`
- [ ] `examples/agent_port.exs`
- [ ] `examples/enhanced_registry.exs`

### Modified Files
- [ ] `lib/portfolio_core.ex` - Add new port references
- [ ] `lib/portfolio_core/registry.ex` - Enhanced features
- [ ] `lib/portfolio_core/manifest/schema.ex` - New fields
- [ ] `lib/portfolio_core/telemetry.ex` - New events
- [ ] `test/registry_test.exs` - New tests
- [ ] `test/manifest/schema_test.exs` - New tests
- [ ] `mix.exs` - Version bump
- [ ] `README.md` - Documentation
- [ ] `CHANGELOG.md` - Release notes
- [ ] `examples/README.md` - Example docs
- [ ] `examples/run_all.sh` - Include new examples
