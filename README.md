# Portfolio Core

<p align="center">
  <img src="assets/portfolio_core.svg" alt="Portfolio Core Logo" width="200">
</p>

<p align="center">
  <a href="https://hex.pm/packages/portfolio_core"><img alt="Hex.pm" src="https://img.shields.io/hexpm/v/portfolio_core.svg"></a>
  <a href="https://hexdocs.pm/portfolio_core"><img alt="Documentation" src="https://img.shields.io/badge/docs-hexdocs-purple.svg"></a>
  <a href="https://github.com/nshkrdotcom/portfolio_core/actions"><img alt="Build Status" src="https://img.shields.io/github/actions/workflow/status/nshkrdotcom/portfolio_core/ci.yml"></a>
  <a href="https://opensource.org/licenses/MIT"><img alt="License" src="https://img.shields.io/hexpm/l/portfolio_core.svg"></a>
</p>

**Hexagonal architecture core for building flexible RAG systems in Elixir. Port specifications, manifest-based configuration, adapter registry, and dependency injection framework.**

---

## Overview

Portfolio Core provides the foundational primitives for building RAG (Retrieval-Augmented Generation) systems using hexagonal (ports and adapters) architecture. It defines:

- **Port Specifications** - Elixir behaviours defining contracts for vector stores, graph databases, embedders, LLMs, and more
- **Manifest Engine** - YAML-based configuration with environment variable expansion
- **Adapter Registry** - ETS-backed runtime lookup for port implementations
- **Telemetry Integration** - Built-in observability hooks

## Features

### Port Specifications (14 total)

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

**Infrastructure Ports:**
- `Router` - Multi-provider LLM routing
- `Cache` - Caching layer abstraction
- `Pipeline` - Workflow step definitions
- `Agent` - Tool-using agent behavior
- `Tool` - Individual tool definitions

**Evaluation (NEW in v0.3.0):**
- `Evaluation` - RAG quality evaluation (RAG Triad, hallucination detection)

## Installation

Add `portfolio_core` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:portfolio_core, "~> 0.3.0"}
  ]
end
```

## Quick Start

### 1. Define a Manifest

Create `config/manifests/development.yml`:

```yaml
version: "1.0"
environment: development

adapters:
  vector_store:
    adapter: MyApp.Adapters.VectorStore.Pgvector
    config:
      dimensions: 1536
      metric: cosine

  embedder:
    adapter: MyApp.Adapters.Embedder.OpenAI
    config:
      model: text-embedding-3-small
      api_key: ${OPENAI_API_KEY}
```

### 2. Implement an Adapter

```elixir
defmodule MyApp.Adapters.VectorStore.Pgvector do
  @behaviour PortfolioCore.Ports.VectorStore

  @impl true
  def create_index(index_id, config) do
    # Implementation
  end

  @impl true
  def store(index_id, id, vector, metadata) do
    # Implementation
  end

  @impl true
  def search(index_id, query_vector, k, opts) do
    # Implementation
  end

  # ... other callbacks
end
```

### 3. Use the Registry

```elixir
# Get adapter at runtime
{module, config} = PortfolioCore.adapter(:vector_store)

# Use the adapter
module.search("my_index", query_vector, 10, [])
```

## Enhanced Registry (v0.2.0)

The registry now supports:
- Adapter metadata and capabilities
- Health status tracking
- Call metrics and error rates

```elixir
# Register with capabilities
PortfolioCore.Registry.register(:llm, MyLLM, config, %{
  capabilities: [:generation, :streaming]
})

# Find by capability
PortfolioCore.Registry.find_by_capability(:streaming)

# Health tracking
PortfolioCore.Registry.mark_unhealthy(:llm)
PortfolioCore.Registry.health_status(:llm)  # => :unhealthy
```

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      Application                            │
├─────────────────────────────────────────────────────────────┤
│                    Portfolio Core                           │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │    Ports    │  │  Manifest   │  │      Registry       │  │
│  │ (Behaviours)│  │   Engine    │  │    (ETS-backed)     │  │
│  └─────────────┘  └─────────────┘  └─────────────────────┘  │
├─────────────────────────────────────────────────────────────┤
│                       Adapters                              │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐        │
│  │ Pgvector │ │  Neo4j   │ │  OpenAI  │ │ Anthropic│  ...   │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘        │
└─────────────────────────────────────────────────────────────┘
```

## Documentation

- [HexDocs](https://hexdocs.pm/portfolio_core)

## Related Packages

- [`portfolio_index`](https://github.com/nshkrdotcom/portfolio_index) - Production adapters and pipelines
- [`portfolio_manager`](https://github.com/nshkrdotcom/portfolio_manager) - CLI and application layer

## License

MIT License - see [LICENSE](LICENSE) for details.
