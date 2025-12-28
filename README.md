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

## Installation

Add `portfolio_core` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:portfolio_core, "~> 0.1.1"}
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
{module, config} = PortfolioCore.Registry.get(:vector_store)

# Use the adapter
module.search("my_index", query_vector, 10, [])
```

## Port Specifications

| Port | Description |
|------|-------------|
| `VectorStore` | Vector similarity search backends (pgvector, Qdrant, Pinecone) |
| `GraphStore` | Knowledge graph databases (Neo4j, RocksDB) |
| `DocumentStore` | Document storage and retrieval |
| `Embedder` | Text embedding generation (OpenAI, Anthropic, local) |
| `LLM` | Large language model access |
| `Chunker` | Document chunking strategies |
| `Retriever` | Retrieval strategy implementations |
| `Reranker` | Result reranking |

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
