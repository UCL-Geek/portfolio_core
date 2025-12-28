# Portfolio Core - Expansion Roadmap

## Overview

This document outlines the port specification and infrastructure expansions for portfolio_core, maintaining its role as a pure interface layer.

## Priority Tiers

### Tier 1: Essential Port Additions

#### 1.1 Router Port

**Purpose:** Enable multi-provider LLM routing strategies

```elixir
# lib/portfolio_core/ports/router.ex
defmodule PortfolioCore.Ports.Router do
  @moduledoc """
  Behavior for LLM provider routing.
  """

  @type strategy :: :fallback | :round_robin | :specialist | :cost_optimized
  @type provider :: %{
    name: atom(),
    module: module(),
    config: map(),
    capabilities: [atom()],
    cost_per_token: float()
  }

  @callback route(messages :: [map()], opts :: keyword()) ::
    {:ok, provider()} | {:error, term()}

  @callback register_provider(provider()) :: :ok | {:error, term()}

  @callback health_check(provider_name :: atom()) ::
    :healthy | :unhealthy | :unknown

  @callback list_providers() :: [provider()]

  @callback set_strategy(strategy()) :: :ok
end
```

#### 1.2 Cache Port

**Purpose:** Abstract caching for embeddings, queries, and results

```elixir
# lib/portfolio_core/ports/cache.ex
defmodule PortfolioCore.Ports.Cache do
  @moduledoc """
  Behavior for caching layer implementations.
  """

  @type key :: term()
  @type value :: term()
  @type ttl :: pos_integer() | :infinity

  @callback get(key()) :: {:ok, value()} | {:error, :not_found}

  @callback put(key(), value(), ttl()) :: :ok | {:error, term()}

  @callback delete(key()) :: :ok

  @callback clear() :: :ok

  @callback exists?(key()) :: boolean()

  @callback get_many([key()]) :: %{key() => value()}

  @callback put_many([{key(), value()}], ttl()) :: :ok | {:error, term()}
end
```

#### 1.3 Pipeline Port

**Purpose:** Define composable workflow step contracts

```elixir
# lib/portfolio_core/ports/pipeline.ex
defmodule PortfolioCore.Ports.Pipeline do
  @moduledoc """
  Behavior for pipeline step implementations.
  """

  @type step_result :: {:ok, term()} | {:error, term()} | {:skip, reason :: term()}
  @type step_context :: %{
    step_name: atom(),
    pipeline_name: atom(),
    inputs: map(),
    metadata: map()
  }

  @callback execute(step_context(), config :: keyword()) :: step_result()

  @callback validate_input(input :: term()) :: :ok | {:error, term()}

  @callback output_schema() :: map()

  @callback required_inputs() :: [atom()]

  @callback cacheable?() :: boolean()
end
```

#### 1.4 Agent Port

**Purpose:** Define tool-using agent contracts

```elixir
# lib/portfolio_core/ports/agent.ex
defmodule PortfolioCore.Ports.Agent do
  @moduledoc """
  Behavior for agentic execution engines.
  """

  @type tool_call :: %{
    tool: atom(),
    arguments: map(),
    id: String.t()
  }

  @type tool_result :: %{
    tool: atom(),
    result: term(),
    id: String.t()
  }

  @callback run(task :: String.t(), opts :: keyword()) ::
    {:ok, result :: term()} | {:error, term()}

  @callback available_tools() :: [atom()]

  @callback execute_tool(tool_call()) :: {:ok, tool_result()} | {:error, term()}

  @callback max_iterations() :: pos_integer()
end
```

### Tier 2: Enhanced Infrastructure

#### 2.1 Advanced Manifest Features

```elixir
# lib/portfolio_core/manifest/schema.ex additions

# Manifest inheritance
:extends  # Path to base manifest

# Profiles within environment
:profiles
  default: %{...}
  high_performance: %{...}
  cost_optimized: %{...}

# Secrets backend
:secrets
  backend: :vault | :aws_ssm | :env
  config: %{...}

# Schema version for migrations
:schema_version  # Integer for breaking changes
```

#### 2.2 Enhanced Registry

```elixir
# lib/portfolio_core/registry.ex additions

# Adapter metadata
def register(port, module, config, metadata \\ %{})

# Capability queries
def find_by_capability(capability)

# Health status tracking
def mark_unhealthy(port)
def mark_healthy(port)
def health_status(port)

# Metrics
def call_count(port)
def error_count(port)
```

#### 2.3 Comprehensive Telemetry Events

```elixir
# lib/portfolio_core/telemetry.ex additions

# New event categories
@adapter_events [
  [:portfolio_core, :adapter, :call, :start],
  [:portfolio_core, :adapter, :call, :stop],
  [:portfolio_core, :adapter, :call, :exception],
  [:portfolio_core, :adapter, :health, :check],
  [:portfolio_core, :adapter, :health, :change]
]

@cost_events [
  [:portfolio_core, :cost, :token],
  [:portfolio_core, :cost, :api_call],
  [:portfolio_core, :cost, :embedding]
]

@circuit_breaker_events [
  [:portfolio_core, :circuit_breaker, :open],
  [:portfolio_core, :circuit_breaker, :close],
  [:portfolio_core, :circuit_breaker, :half_open]
]
```

### Tier 3: Advanced Patterns

#### 3.1 Multi-Tenant Support

```elixir
# lib/portfolio_core/ports/tenant.ex
defmodule PortfolioCore.Ports.Tenant do
  @moduledoc """
  Behavior for multi-tenant context management.
  """

  @type tenant_id :: String.t()
  @type tenant_context :: %{
    tenant_id: tenant_id(),
    quotas: map(),
    config_overrides: map()
  }

  @callback get_context(tenant_id()) :: {:ok, tenant_context()} | {:error, term()}

  @callback set_context(tenant_context()) :: :ok

  @callback with_tenant(tenant_id(), (-> term())) :: term()

  @callback check_quota(tenant_id(), resource :: atom()) ::
    :ok | {:error, :quota_exceeded}
end
```

#### 3.2 Streaming Port

```elixir
# lib/portfolio_core/ports/stream.ex
defmodule PortfolioCore.Ports.Stream do
  @moduledoc """
  Behavior for streaming data sources and sinks.
  """

  @type chunk :: binary() | map()
  @type stream_opts :: [
    buffer_size: pos_integer(),
    timeout: pos_integer(),
    on_error: :skip | :halt | :retry
  ]

  @callback stream(source :: term(), opts :: stream_opts()) :: Enumerable.t()

  @callback write_stream(sink :: term(), stream :: Enumerable.t()) ::
    :ok | {:error, term()}

  @callback transform(stream :: Enumerable.t(), transformer :: fun()) ::
    Enumerable.t()
end
```

#### 3.3 Event Sourcing Port

```elixir
# lib/portfolio_core/ports/event_store.ex
defmodule PortfolioCore.Ports.EventStore do
  @moduledoc """
  Behavior for event sourcing patterns.
  """

  @type event :: %{
    id: String.t(),
    type: atom(),
    data: map(),
    metadata: map(),
    timestamp: DateTime.t()
  }

  @callback append(stream :: String.t(), events :: [event()]) ::
    {:ok, version :: pos_integer()} | {:error, term()}

  @callback read(stream :: String.t(), opts :: keyword()) ::
    {:ok, [event()]} | {:error, term()}

  @callback subscribe(stream :: String.t(), handler :: fun()) ::
    {:ok, subscription_id :: term()} | {:error, term()}

  @callback unsubscribe(subscription_id :: term()) :: :ok
end
```

## Implementation Phases

### Phase 1: Core Ports (Q1)

```
Week 1-2: Router port specification
Week 3-4: Cache port specification
Week 5-6: Pipeline port specification
Week 7-8: Agent port specification + testing
```

### Phase 2: Infrastructure (Q2)

```
Week 1-2: Manifest inheritance
Week 3-4: Registry enhancements
Week 5-6: Telemetry expansion
Week 7-8: Documentation + examples
```

### Phase 3: Advanced (Q3)

```
Month 1: Multi-tenant port
Month 2: Streaming port
Month 3: Event store port (if needed)
```

## Backward Compatibility

### Versioning Strategy

```elixir
# Mix.exs
def project do
  [
    version: "0.2.0",  # Minor bump for new ports
    # ...
  ]
end

# Deprecation pattern
@deprecated "Use PortfolioCore.Ports.Router instead"
def legacy_function, do: ...
```

### Migration Guide Pattern

```markdown
# Upgrading from 0.1.x to 0.2.x

## New Ports
The following ports are now available:
- `PortfolioCore.Ports.Router`
- `PortfolioCore.Ports.Cache`
- `PortfolioCore.Ports.Pipeline`
- `PortfolioCore.Ports.Agent`

## Breaking Changes
None - all new features are additive.

## Recommended Updates
1. Consider implementing Router for multi-provider support
2. Add Cache adapter for improved performance
```

## Success Metrics

| Feature | Metric | Target |
|---------|--------|--------|
| New ports | Port count | 12+ (from 8) |
| Coverage | Test coverage | >95% |
| Types | Dialyzer clean | 0 warnings |
| Docs | ExDoc score | 100% |
| Manifest | Inheritance depth | 3 levels |
| Registry | Lookup speed | <1ms P99 |
