# Portfolio Core - Current State Analysis

## Overview

**Version:** 0.1.1
**Role:** Domain layer providing hexagonal architecture primitives
**Published:** Hex.pm
**Dependencies:** Zero portfolio dependencies (pure interfaces)

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                      PORTFOLIO CORE                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  PORT SPECIFICATIONS (Behaviors)                        │   │
│  │                                                         │   │
│  │  VectorStore  GraphStore  DocumentStore  Embedder      │   │
│  │  LLM          Chunker     Retriever      Reranker      │   │
│  │                                                         │   │
│  └─────────────────────────────────────────────────────────┘   │
│                              │                                  │
│  ┌───────────────────────────┴─────────────────────────────┐   │
│  │  MANIFEST ENGINE                                        │   │
│  │  • Loader    - YAML parsing with env var expansion      │   │
│  │  • Schema    - NimbleOptions validation                 │   │
│  │  • Engine    - GenServer lifecycle management           │   │
│  └─────────────────────────────────────────────────────────┘   │
│                              │                                  │
│  ┌───────────────────────────┴─────────────────────────────┐   │
│  │  INFRASTRUCTURE                                         │   │
│  │  • Registry  - ETS-backed adapter lookup                │   │
│  │  • Telemetry - Observability framework                  │   │
│  │  • Application - OTP supervisor                         │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Implemented Port Specifications

### 1. VectorStore (`ports/vector_store.ex`)

```elixir
@callback create_index(index_id, dimensions, opts) :: :ok | {:error, term()}
@callback store(index_id, id, vector, metadata, opts) :: :ok | {:error, term()}
@callback store_batch(index_id, items, opts) :: :ok | {:error, term()}
@callback search(index_id, vector, opts) :: {:ok, [result()]} | {:error, term()}
@callback delete(index_id, id) :: :ok | {:error, term()}
@callback index_stats(index_id) :: {:ok, stats()} | {:error, term()}
@optional_callback index_exists?(index_id) :: boolean()
```

### 2. GraphStore (`ports/graph_store.ex`)

```elixir
@callback create_graph(graph_id, opts) :: :ok | {:error, term()}
@callback create_node(graph_id, node_id, labels, properties) :: :ok | {:error, term()}
@callback create_edge(graph_id, edge_id, source, target, type, props) :: :ok | {:error, term()}
@callback get_node(graph_id, node_id) :: {:ok, node()} | {:error, term()}
@callback get_neighbors(graph_id, node_id, opts) :: {:ok, [node()]} | {:error, term()}
@callback query(graph_id, query, params) :: {:ok, results()} | {:error, term()}
@callback delete_node(graph_id, node_id) :: :ok | {:error, term()}
@callback delete_edge(graph_id, edge_id) :: :ok | {:error, term()}
@callback graph_stats(graph_id) :: {:ok, stats()} | {:error, term()}
```

### 3. DocumentStore (`ports/document_store.ex`)

```elixir
@callback store(store_id, doc_id, content, metadata, opts) :: :ok | {:error, term()}
@callback get(store_id, doc_id) :: {:ok, document()} | {:error, term()}
@callback delete(store_id, doc_id) :: :ok | {:error, term()}
@callback list(store_id, opts) :: {:ok, [document()]} | {:error, term()}
@callback search_metadata(store_id, query, opts) :: {:ok, [document()]} | {:error, term()}
```

### 4. Embedder (`ports/embedder.ex`)

```elixir
@callback embed(text, opts) :: {:ok, vector()} | {:error, term()}
@callback embed_batch(texts, opts) :: {:ok, [vector()]} | {:error, term()}
@callback dimensions() :: pos_integer()
@callback supported_models() :: [String.t()]
```

### 5. LLM (`ports/llm.ex`)

```elixir
@callback complete(messages, opts) :: {:ok, response()} | {:error, term()}
@callback stream(messages, callback, opts) :: :ok | {:error, term()}
@callback supported_models() :: [String.t()]
@callback model_info(model) :: {:ok, info()} | {:error, term()}
```

### 6. Chunker (`ports/chunker.ex`)

```elixir
@callback chunk(text, opts) :: {:ok, [chunk()]} | {:error, term()}
@callback estimate_chunks(text, opts) :: pos_integer()
```

### 7. Retriever (`ports/retriever.ex`)

```elixir
@callback retrieve(query, context, opts) :: {:ok, [result()]} | {:error, term()}
@callback strategy_name() :: atom()
@callback required_adapters() :: [atom()]
```

### 8. Reranker (`ports/reranker.ex`)

```elixir
@callback rerank(query, results, opts) :: {:ok, [result()]} | {:error, term()}
@callback model_name() :: String.t()
```

## Manifest Engine

### Loader Features

- YAML file parsing via yaml_elixir
- Environment variable expansion: `${VAR}`
- Default value support: `${VAR:-default}` (added v0.1.1)
- Recursive expansion in nested structures
- File I/O with error handling

### Schema Validation

```elixir
# Required fields
:version     # Manifest version string
:environment # dev, test, prod
:adapters    # Map of port -> adapter config

# Optional fields
:pipelines   # Pipeline configurations
:graphs      # Graph configurations
:rag         # RAG strategy settings
:telemetry   # Telemetry configuration
```

### Engine (GenServer)

- Loads manifest on startup
- Wires adapters to registry
- Supports hot-reload via `reload()`
- Emits telemetry events
- Module resolution (string -> atom)

## Registry

- **Backend:** ETS with read/write concurrency
- **Lookup:** O(1) by port name
- **Thread-safe:** Multi-process access
- **Operations:** register, get, get!, list_ports, unregister, clear, registered?

## Current Gaps

### Missing Port Specifications

| Port | Description | rag_ex Status |
|------|-------------|---------------|
| Cache | Result/embedding caching | Not present |
| Router | Multi-provider routing | Full implementation |
| RateLimiter | API rate limiting | Via Hammer |
| Pipeline | Workflow orchestration | DAG-based |
| Agent | Tool-using agents | Full implementation |
| SessionStore | Agent memory | Implemented |
| Tokenizer | Text tokenization | Not present |
| Parser | Code parsing | Via tree-sitter |

### Missing Manifest Features

| Feature | Description |
|---------|-------------|
| Schema versioning | Breaking change migration |
| Inheritance | Base manifests with overrides |
| Profiles | Multiple configs per environment |
| Secrets backend | Vault/AWS SSM integration |
| Validation hooks | Custom validation rules |

### Missing Telemetry

| Event Category | Examples |
|----------------|----------|
| Cost tracking | Token usage, API costs |
| Latency histograms | P50, P95, P99 |
| Error classification | By type, by adapter |
| Circuit breaker | Open/close events |

## Code Metrics

| Metric | Value |
|--------|-------|
| Total LOC | ~800 |
| Port Modules | 8 |
| Manifest Modules | 3 |
| Infrastructure | 3 |
| Test Coverage | >90% |

## Dependencies

```elixir
# Runtime
{:yaml_elixir, "~> 2.9"}      # YAML parsing
{:jason, "~> 1.4"}             # JSON support
{:telemetry, "~> 1.2"}         # Observability
{:nimble_options, "~> 1.0"}    # Schema validation

# Dev/Test
{:ex_doc, "~> 0.31"}
{:credo, "~> 1.7"}
{:dialyxir, "~> 1.4"}
{:stream_data, "~> 0.6"}
{:mox, "~> 1.1"}
{:excoveralls, "~> 0.18"}
```

## Design Principles

1. **Zero implementations** - Only contracts/behaviors
2. **Minimal dependencies** - No database, API, or framework deps
3. **Type safety** - Full typespecs throughout
4. **Testability** - All ports mockable via Mox
5. **Hot-reload** - Configuration changes without restart
6. **Telemetry-first** - Built-in observability hooks
