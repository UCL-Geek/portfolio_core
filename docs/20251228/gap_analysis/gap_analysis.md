# Gap Analysis: portfolio_core Ports vs rag_ex Behaviors

**Date**: December 28, 2025
**portfolio_core Version**: 0.2.0
**Target Version**: 0.3.0
**Scope**: Port specifications (behaviors) only - no implementations

---

## Executive Summary

This document provides a comprehensive comparison between portfolio_core port specifications and rag_ex behavior definitions. The analysis identifies **17 gaps** in portfolio_core ports that need enhancement to achieve feature parity with rag_ex's interface contracts.

### Gap Severity Legend

- **Critical**: Missing callbacks that prevent implementations from matching rag_ex capabilities
- **High**: Missing type definitions or callbacks that affect interoperability
- **Medium**: Missing optional callbacks or type refinements
- **Low**: Documentation or naming inconsistencies

---

## Port-by-Port Comparison

### 1. Chunker Port

**File**: `/home/home/p/g/n/portfolio_core/lib/portfolio_core/ports/chunker.ex`

#### rag_ex Has (Rag.Chunker behavior):

```elixir
# Chunk struct with byte positions
defstruct [:content, :start_byte, :end_byte, :metadata]

@type chunk :: %__MODULE__{
  content: String.t(),
  start_byte: non_neg_integer(),
  end_byte: non_neg_integer(),
  metadata: map()
}

# 6 strategy structs:
# - Rag.Chunker.Character (chunk_size, chunk_overlap, word_boundary)
# - Rag.Chunker.Sentence (max_sentences, overlap_sentences)
# - Rag.Chunker.Paragraph (max_paragraphs, overlap_paragraphs)
# - Rag.Chunker.Recursive (separators, chunk_size, chunk_overlap)
# - Rag.Chunker.Semantic (threshold, max_chars, embedding_fn)
# - Rag.Chunker.FormatAware (format, chunk_size, chunk_overlap)

@callback chunk(text :: String.t(), strategy :: struct()) :: {:ok, [chunk()]} | {:error, term()}
@callback supported_strategies() :: [atom()]
```

#### portfolio_core Has:

```elixir
@type chunk :: %{
  content: String.t(),
  index: non_neg_integer(),
  start_offset: non_neg_integer(),  # character offset, not byte
  end_offset: non_neg_integer(),
  metadata: map()
}

@callback chunk(text(), format(), chunk_config()) :: {:ok, [chunk()]} | {:error, term()}
@callback estimate_chunks(text(), chunk_config()) :: non_neg_integer()
```

#### GAPS:

| Gap ID | Description | Severity | Resolution |
|--------|-------------|----------|------------|
| CHK-01 | Missing byte position tracking (`start_byte`, `end_byte`) | **Critical** | Add `start_byte` and `end_byte` to chunk type |
| CHK-02 | Missing strategy struct pattern | **High** | Add strategy type union and struct definitions |
| CHK-03 | Missing `supported_strategies/0` callback | Medium | Add optional callback |
| CHK-04 | Format-based API vs strategy-based API | Medium | Support both patterns |

**Recommended Changes**:

```elixir
# Enhanced chunk type
@type chunk :: %{
  content: String.t(),
  index: non_neg_integer(),
  start_byte: non_neg_integer(),    # NEW: byte position for source mapping
  end_byte: non_neg_integer(),      # NEW: byte position for source mapping
  start_offset: non_neg_integer(),  # character offset (kept for compatibility)
  end_offset: non_neg_integer(),
  metadata: map()
}

# Strategy union type
@type strategy ::
  :character
  | :sentence
  | :paragraph
  | :recursive
  | :semantic
  | :format_aware

# NEW callback
@callback supported_strategies() :: [strategy()]

@optional_callbacks [supported_strategies: 0]
```

---

### 2. Retriever Port

**File**: `/home/home/p/g/n/portfolio_core/lib/portfolio_core/ports/retriever.ex`

#### rag_ex Has (Rag.Retriever behavior):

```elixir
@type result :: %{
  id: term(),
  content: String.t(),
  score: float(),
  metadata: map()
}

@callback retrieve(query :: String.t(), opts :: keyword()) :: {:ok, [result()]} | {:error, term()}
@callback supports_embedding?() :: boolean()
@callback supports_text_query?() :: boolean()

# 4 retriever types: semantic, fulltext, hybrid (RRF), graph
```

#### portfolio_core Has:

```elixir
@type retrieved_item :: %{
  content: String.t(),
  score: float(),
  source: String.t(),
  metadata: map()
}

@callback retrieve(query(), context(), opts :: keyword()) :: {:ok, retrieval_result()} | {:error, term()}
@callback strategy_name() :: atom()
@callback required_adapters() :: [atom()]
```

#### GAPS:

| Gap ID | Description | Severity | Resolution |
|--------|-------------|----------|------------|
| RET-01 | Missing `id` field in result type | **High** | Add id field to retrieved_item |
| RET-02 | Missing `supports_embedding?/0` callback | **High** | Add callback for capability detection |
| RET-03 | Missing `supports_text_query?/0` callback | **High** | Add callback for capability detection |

**Recommended Changes**:

```elixir
@type retrieved_item :: %{
  id: term(),                      # NEW: unique identifier
  content: String.t(),
  score: float(),
  source: String.t(),
  metadata: map()
}

# NEW callbacks for capability detection
@callback supports_embedding?() :: boolean()
@callback supports_text_query?() :: boolean()
```

---

### 3. Reranker Port

**File**: `/home/home/p/g/n/portfolio_core/lib/portfolio_core/ports/reranker.ex`

#### rag_ex Has (Rag.Reranker behavior):

```elixir
@type reranked_result :: %{
  id: term(),
  content: String.t(),
  original_score: float(),
  rerank_score: float(),
  metadata: map()
}

@callback rerank(query :: String.t(), results :: [map()], opts :: keyword()) ::
  {:ok, [reranked_result()]} | {:error, term()}
@callback normalize_scores(results :: [reranked_result()]) :: [reranked_result()]

# Implementations: LLM-based scoring, Passthrough
```

#### portfolio_core Has:

```elixir
@type reranked_item :: %{
  content: String.t(),
  original_score: float(),
  rerank_score: float(),
  metadata: map()
}

@callback rerank(query(), [item()], opts :: keyword()) :: {:ok, [reranked_item()]} | {:error, term()}
@callback model_name() :: String.t()
```

#### GAPS:

| Gap ID | Description | Severity | Resolution |
|--------|-------------|----------|------------|
| RRK-01 | Missing `id` field in reranked_item | Medium | Add id field |
| RRK-02 | Missing `normalize_scores/1` callback | Medium | Add optional callback |
| RRK-03 | Missing passthrough option type | Low | Document passthrough pattern |

**Recommended Changes**:

```elixir
@type reranked_item :: %{
  id: term(),                      # NEW: preserve original id
  content: String.t(),
  original_score: float(),
  rerank_score: float(),
  metadata: map()
}

# NEW callback for score normalization
@callback normalize_scores([reranked_item()]) :: [reranked_item()]

@optional_callbacks [normalize_scores: 1]
```

---

### 4. Embedder Port

**File**: `/home/home/p/g/n/portfolio_core/lib/portfolio_core/ports/embedder.ex`

#### rag_ex Has (Rag.Embedding):

```elixir
@callback generate_embedding(text :: String.t(), model :: String.t(), opts :: keyword()) ::
  {:ok, [float()]} | {:error, term()}
@callback generate_embeddings_batch(texts :: [String.t()], model :: String.t(), opts :: keyword()) ::
  {:ok, [[float()]]} | {:error, term()}

# Telemetry integration: [:rag, :embedding, :start/:stop/:exception]
```

#### portfolio_core Has:

```elixir
@callback embed(text(), opts :: keyword()) :: {:ok, embedding_result()} | {:error, term()}
@callback embed_batch([text()], opts :: keyword()) :: {:ok, batch_result()} | {:error, term()}
@callback dimensions(model()) :: pos_integer()
@callback supported_models() :: [model()]
```

#### GAPS:

| Gap ID | Description | Severity | Resolution |
|--------|-------------|----------|------------|
| EMB-01 | Different function signatures (model in opts vs separate param) | Low | Document both patterns |
| EMB-02 | Missing telemetry event documentation | Low | Add to moduledoc |

**Status**: portfolio_core's Embedder port is **mostly equivalent** - different signature style but functionally complete. The `dimensions/1` and `supported_models/0` callbacks are portfolio_core additions.

---

### 5. VectorStore Port

**File**: `/home/home/p/g/n/portfolio_core/lib/portfolio_core/ports/vector_store.ex`

#### rag_ex Has (Rag.VectorStore behavior):

```elixir
# Chunk schema with pgvector type
defmodule Rag.VectorStore.Chunk do
  use Ecto.Schema
  field :content, :string
  field :embedding, Pgvector.Ecto.Vector
  field :metadata, :map
  field :document_id, :string
end

@callback semantic_search_query(query_embedding :: [float()], opts :: keyword()) :: Ecto.Query.t()
@callback fulltext_search_query(query :: String.t(), opts :: keyword()) :: Ecto.Query.t()
@callback calculate_rrf_score(semantic_results, fulltext_results, opts) :: [result()]
```

#### portfolio_core Has:

```elixir
@callback create_index(index_id(), index_config()) :: :ok | {:error, term()}
@callback delete_index(index_id()) :: :ok | {:error, :not_found | term()}
@callback store(index_id(), vector_id(), vector(), metadata()) :: :ok | {:error, term()}
@callback store_batch(index_id(), [{vector_id(), vector(), metadata()}]) :: {:ok, non_neg_integer()} | {:error, term()}
@callback search(index_id(), vector(), k :: pos_integer(), opts :: keyword()) :: {:ok, [search_result()]} | {:error, term()}
@callback delete(index_id(), vector_id()) :: :ok | {:error, :not_found | term()}
@callback index_stats(index_id()) :: {:ok, index_stats()} | {:error, :not_found | term()}
@callback index_exists?(index_id()) :: boolean()
```

#### GAPS:

| Gap ID | Description | Severity | Resolution |
|--------|-------------|----------|------------|
| VEC-01 | Missing `fulltext_search/3` callback | **High** | Add for hybrid retrieval support |
| VEC-02 | Missing `calculate_rrf_score/3` helper | Medium | Add helper module and hybrid capability |
| VEC-03 | No Ecto query builder pattern | Low | Different design - OK for hex arch |

**Recommended Changes**:

```elixir
# NEW callback for fulltext search
@callback fulltext_search(index_id(), query :: String.t(), k :: pos_integer(), opts :: keyword()) ::
  {:ok, [search_result()]} | {:error, term()}

@optional_callbacks [fulltext_search: 4]
```

**Hybrid Retrieval Helper**:

```elixir
PortfolioCore.VectorStore.RRF.calculate_rrf_score(semantic_results, fulltext_results, opts)
```

**Hybrid Capability Behavior**:

```elixir
defmodule PortfolioCore.Ports.VectorStore.Hybrid do
  @callback fulltext_search(index_id(), query :: String.t(), k :: pos_integer(), opts :: keyword()) ::
    {:ok, [search_result()]} | {:error, term()}
end
```

---

### 6. GraphStore Port

**File**: `/home/home/p/g/n/portfolio_core/lib/portfolio_core/ports/graph_store.ex`

#### rag_ex Has (Rag.GraphStore behavior):

```elixir
# Core operations
@callback create_node(graph_id, node_id, labels, properties) :: :ok | {:error, term()}
@callback create_edge(graph_id, edge_id, source, target, type, properties) :: :ok | {:error, term()}
@callback get_node(graph_id, node_id) :: {:ok, node()} | {:error, term()}
@callback find_neighbors(graph_id, node_id, opts) :: {:ok, [node()]} | {:error, term()}

# Traversal
@callback traverse(graph_id, start_node_id, opts) :: {:ok, [node()]} | {:error, term()}
# opts includes: direction, max_depth, algorithm (:bfs | :dfs)

# Vector search on entities
@callback vector_search(graph_id, embedding, opts) :: {:ok, [entity()]} | {:error, term()}

# Community operations (CRITICAL for GraphRAG)
@callback create_community(graph_id, community_id, opts) :: :ok | {:error, term()}
@callback get_community_members(graph_id, community_id) :: {:ok, [node_id()]} | {:error, term()}
@callback update_community_summary(graph_id, community_id, summary) :: :ok | {:error, term()}
@callback list_communities(graph_id, opts) :: {:ok, [community()]} | {:error, term()}
```

#### portfolio_core Has:

```elixir
@callback create_graph(graph_id(), config :: map()) :: :ok | {:error, term()}
@callback delete_graph(graph_id()) :: :ok | {:error, term()}
@callback create_node(graph_id(), graph_node()) :: {:ok, graph_node()} | {:error, term()}
@callback create_edge(graph_id(), graph_edge()) :: {:ok, graph_edge()} | {:error, term()}
@callback get_node(graph_id(), node_id()) :: {:ok, graph_node()} | {:error, :not_found | term()}
@callback get_neighbors(graph_id(), node_id(), opts :: keyword()) :: {:ok, [graph_node()]} | {:error, term()}
@callback query(graph_id(), query :: String.t(), params :: map()) :: {:ok, query_result()} | {:error, term()}
@callback delete_node(graph_id(), node_id()) :: :ok | {:error, term()}
@callback delete_edge(graph_id(), edge_id()) :: :ok | {:error, term()}
@callback graph_stats(graph_id()) :: {:ok, map()} | {:error, term()}
```

#### GAPS:

| Gap ID | Description | Severity | Resolution |
|--------|-------------|----------|------------|
| GRF-01 | Missing `traverse/3` callback (BFS/DFS) | **Critical** | Add callback with algorithm option |
| GRF-02 | Missing `vector_search/3` callback | **Critical** | Add for entity embedding search |
| GRF-03 | Missing community operations | **Critical** | Add `GraphStore.Community` behavior |
| GRF-04 | Missing `get_community_members/2` callback | **Critical** | Add in `GraphStore.Community` |
| GRF-05 | Missing `update_community_summary/3` callback | **Critical** | Add in `GraphStore.Community` |
| GRF-06 | Missing `list_communities/2` callback | **High** | Add in `GraphStore.Community` |

**Recommended Changes**:

```elixir
# Traversal algorithm type
@type traversal_algorithm :: :bfs | :dfs

# NEW: Graph traversal callback
@doc """
Traverse the graph from a starting node.

## Options
- `:direction` - `:outgoing`, `:incoming`, or `:both`
- `:max_depth` - Maximum traversal depth
- `:algorithm` - `:bfs` or `:dfs`
- `:edge_types` - Filter by edge types
"""
@callback traverse(graph_id(), node_id(), opts :: keyword()) ::
  {:ok, [graph_node()]} | {:error, term()}

# NEW: Vector search on graph entities
@callback vector_search(graph_id(), embedding :: [float()], opts :: keyword()) ::
  {:ok, [graph_node()]} | {:error, term()}

@optional_callbacks [vector_search: 3]
```

**GraphRAG Community Behavior**:

```elixir
defmodule PortfolioCore.Ports.GraphStore.Community do
  @type community :: %{
    id: String.t(),
    name: String.t(),
    summary: String.t() | nil,
    member_count: non_neg_integer(),
    level: non_neg_integer()
  }

  @callback create_community(graph_id(), community_id :: String.t(), opts :: keyword()) ::
    :ok | {:error, term()}

  @callback get_community_members(graph_id(), community_id :: String.t()) ::
    {:ok, [node_id()]} | {:error, term()}

  @callback update_community_summary(graph_id(), community_id :: String.t(), summary :: String.t()) ::
    :ok | {:error, term()}

  @callback list_communities(graph_id(), opts :: keyword()) ::
    {:ok, [community()]} | {:error, term()}
end
```

---

### 7. Pipeline Port

**File**: `/home/home/p/g/n/portfolio_core/lib/portfolio_core/ports/pipeline.ex`

#### rag_ex Has (Rag.Pipeline):

```elixir
# Step struct
defmodule Rag.Pipeline.Step do
  defstruct [
    :name,
    :module,
    :function,
    :args,
    :inputs,          # Map of input_key => source_step.output_key
    :parallel,        # Boolean: can run in parallel with other steps
    :on_error,        # :halt | :continue | {:retry, count}
    :cache,           # Boolean or TTL
    :timeout          # Milliseconds
  ]
end

# Context struct
defmodule Rag.Pipeline.Context do
  defstruct [
    :step_results,    # Map of step_name => result
    :errors,          # List of errors
    :metadata,        # User metadata
    :cache            # ETS reference
  ]
end

# Executor with ETS caching and parallel support
defmodule Rag.Pipeline.Executor do
  def execute(pipeline, input, opts)
  def execute_parallel(steps, context)
end
```

#### portfolio_core Has:

```elixir
@type step_context :: %{
  step_name: atom(),
  pipeline_name: atom(),
  inputs: map(),
  metadata: map(),
  attempt: pos_integer()
}

@callback execute(context :: step_context(), config :: keyword()) :: step_result()
@callback validate_input(input :: term()) :: :ok | {:error, term()}
@callback output_schema() :: %{atom() => output_type()}
@callback required_inputs() :: [atom()]
@callback cacheable?() :: boolean()
@callback estimated_duration() :: pos_integer()
```

#### GAPS:

| Gap ID | Description | Severity | Resolution |
|--------|-------------|----------|------------|
| PIP-01 | Missing `parallel` flag in step spec | **High** | Add parallel execution indicator |
| PIP-02 | Missing `on_error` handling mode | **High** | Add error handling strategy type |
| PIP-03 | Missing `timeout` specification | Medium | Add timeout callback |
| PIP-04 | Missing cache TTL specification | Medium | Enhance cacheable to include TTL |

**Recommended Changes**:

```elixir
# Error handling strategy type
@type on_error :: :halt | :continue | {:retry, pos_integer()}

# Enhanced step context
@type step_context :: %{
  step_name: atom(),
  pipeline_name: atom(),
  inputs: map(),
  metadata: map(),
  attempt: pos_integer(),
  parallel: boolean(),        # NEW: parallel execution flag
  timeout: pos_integer()      # NEW: step timeout in ms
}

# NEW callbacks
@callback parallel?() :: boolean()
@callback on_error() :: on_error()
@callback timeout() :: pos_integer()
@callback cache_ttl() :: pos_integer() | :infinity
```

---

### 8. Cache Port

**File**: `/home/home/p/g/n/portfolio_core/lib/portfolio_core/ports/cache.ex`

#### rag_ex Has:

```elixir
# ETS-based caching in Pipeline.Executor
# Key format: {pipeline_id, step_name, input_hash}
# Automatic cache invalidation via TTL
```

#### portfolio_core Has:

```elixir
@type ttl :: pos_integer() | :infinity
@type namespace :: String.t() | atom()

@callback get(key(), opts :: cache_opts()) :: {:ok, value()} | {:error, :not_found | term()}
@callback put(key(), value(), opts :: cache_opts()) :: :ok | {:error, term()}
@callback delete(key(), opts :: cache_opts()) :: :ok
@callback exists?(key(), opts :: cache_opts()) :: boolean()
@callback get_many([key()], opts :: cache_opts()) :: %{key() => value()}
@callback put_many([{key(), value()}], opts :: cache_opts()) :: :ok | {:error, term()}
@callback clear(opts :: cache_opts()) :: :ok
@callback stats(opts :: cache_opts()) :: stats()
@callback touch(key(), ttl(), opts :: cache_opts()) :: :ok | {:error, :not_found}
```

#### GAPS:

| Gap ID | Description | Severity | Resolution |
|--------|-------------|----------|------------|
| CAC-01 | Missing `compute_if_absent/3` callback | Medium | Add for cache-aside pattern |
| CAC-02 | Missing `invalidate_pattern/2` callback | Medium | Add for pattern-based invalidation |

**Recommended Changes**:

```elixir
# NEW: Cache-aside pattern
@callback compute_if_absent(key(), compute_fn :: (-> value()), opts :: cache_opts()) ::
  {:ok, value()} | {:error, term()}

# NEW: Pattern-based invalidation
@callback invalidate_pattern(pattern :: String.t(), opts :: cache_opts()) ::
  {:ok, non_neg_integer()} | {:error, term()}

@optional_callbacks [compute_if_absent: 3, invalidate_pattern: 2]
```

---

### 9. Router Port

**File**: `/home/home/p/g/n/portfolio_core/lib/portfolio_core/ports/router.ex`

#### rag_ex Has (Rag.Router):

```elixir
@type strategy :: :fallback | :round_robin | :specialist

@callback execute(messages, opts) :: {:ok, response()} | {:error, term()}
# Automatic retry with next provider on failure
# Provider capabilities detection
# Rate limiting integration
```

#### portfolio_core Has:

```elixir
@type strategy :: :fallback | :round_robin | :specialist | :cost_optimized

@callback route(messages :: [map()], opts :: route_opts()) :: {:ok, provider()} | {:error, term()}
@callback register_provider(provider()) :: :ok | {:error, term()}
@callback unregister_provider(name :: atom()) :: :ok
@callback health_check(name :: atom()) :: :healthy | :unhealthy | :unknown
@callback list_providers() :: [provider()]
@callback set_strategy(strategy()) :: :ok
@callback get_strategy() :: strategy()
```

#### GAPS:

| Gap ID | Description | Severity | Resolution |
|--------|-------------|----------|------------|
| RTR-01 | Missing `execute/2` callback (route + call) | **High** | Add combined route-and-execute |
| RTR-02 | Missing automatic retry mechanism | Medium | Document retry pattern |

**Recommended Changes**:

```elixir
# NEW: Combined route and execute
@callback execute(messages :: [map()], opts :: route_opts()) ::
  {:ok, response :: map()} | {:error, term()}

# NEW: Execute with retry
@callback execute_with_retry(messages :: [map()], opts :: route_opts()) ::
  {:ok, response :: map()} | {:error, term()}

@optional_callbacks [execute_with_retry: 2]
```

---

### 10. Agent Port

**File**: `/home/home/p/g/n/portfolio_core/lib/portfolio_core/ports/agent.ex`

#### rag_ex Has (Rag.Agent.Agent):

```elixir
defmodule Rag.Agent.Session do
  defstruct [:id, :messages, :tool_results, :created_at, :updated_at]
end

@callback process(session, input, opts) :: {:ok, response, updated_session} | {:error, term()}
@callback process_with_tools(session, input, tools, opts) :: {:ok, response, session} | {:error, term()}
# Max iterations control
# Tool execution loop
```

#### portfolio_core Has:

```elixir
@type agent_state :: %{
  task: String.t(),
  memory: [message()],
  tool_calls: [tool_call()],
  tool_results: [tool_result()],
  iteration: non_neg_integer()
}

@callback run(task :: String.t(), opts :: run_opts()) :: {:ok, result :: term()} | {:error, term()}
@callback available_tools() :: [tool_spec()]
@callback execute_tool(tool_call()) :: {:ok, tool_result()} | {:error, term()}
@callback max_iterations() :: pos_integer()
@callback get_state() :: agent_state()
```

#### GAPS:

| Gap ID | Description | Severity | Resolution |
|--------|-------------|----------|------------|
| AGT-01 | Missing session-based API | Medium | Add session struct and callbacks |
| AGT-02 | Missing `process/3` callback | Medium | Add for session-based processing |

**Recommended Changes**:

```elixir
# Session type
@type session :: %{
  id: String.t(),
  messages: [message()],
  tool_results: [tool_result()],
  created_at: DateTime.t(),
  updated_at: DateTime.t()
}

# NEW: Session-based processing
@callback process(session(), input :: String.t(), opts :: keyword()) ::
  {:ok, response :: String.t(), session()} | {:error, term()}

@callback process_with_tools(session(), input :: String.t(), tools :: [atom()], opts :: keyword()) ::
  {:ok, response :: String.t(), session()} | {:error, term()}

```

---

### 11. MISSING PORT: Evaluation

#### rag_ex Has (Rag.Evaluation):

```elixir
@callback evaluate_rag_triad(generation, opts) :: {:ok, triad_result()} | {:error, term()}
# Returns: context_relevance, groundedness, answer_relevance (scores 1-5)

@callback detect_hallucination(generation, opts) :: {:ok, boolean()} | {:error, term()}
# Binary YES/NO hallucination detection
```

#### portfolio_core Has:

- **Nothing** - No Evaluation port exists

#### GAPS:

| Gap ID | Description | Severity | Resolution |
|--------|-------------|----------|------------|
| EVL-01 | Missing Evaluation port entirely | **Critical** | Create new port specification |

**Recommended New Port**:

```elixir
defmodule PortfolioCore.Ports.Evaluation do
  @moduledoc """
  Port specification for RAG quality evaluation.

  Implements the RAG Triad evaluation framework:
  - Context Relevance: Is retrieved context relevant to query?
  - Groundedness: Is response supported by context?
  - Answer Relevance: Does answer address the query?
  """

  @type generation :: %{
    query: String.t(),
    context: String.t(),
    response: String.t(),
    context_sources: [String.t()]
  }

  @type triad_score :: %{
    score: 1..5,
    reasoning: String.t()
  }

  @type triad_result :: %{
    context_relevance: triad_score(),
    groundedness: triad_score(),
    answer_relevance: triad_score(),
    overall: float()
  }

  @doc """
  Evaluate a RAG generation using the RAG Triad framework.
  """
  @callback evaluate_rag_triad(generation(), opts :: keyword()) ::
    {:ok, triad_result()} | {:error, term()}

  @doc """
  Evaluate context relevance only.
  """
  @callback evaluate_context_relevance(generation(), opts :: keyword()) ::
    {:ok, triad_score()} | {:error, term()}

  @doc """
  Evaluate groundedness only.
  """
  @callback evaluate_groundedness(generation(), opts :: keyword()) ::
    {:ok, triad_score()} | {:error, term()}

  @doc """
  Evaluate answer relevance only.
  """
  @callback evaluate_answer_relevance(generation(), opts :: keyword()) ::
    {:ok, triad_score()} | {:error, term()}

  @doc """
  Detect if response contains hallucinations.
  """
  @callback detect_hallucination(generation(), opts :: keyword()) ::
    {:ok, %{hallucinating: boolean(), evidence: String.t()}} | {:error, term()}
end
```

---

### 12. MISSING PORT: AI Provider

#### rag_ex Has (Rag.Ai.Provider):

```elixir
@callback generate_embeddings(texts :: [String.t()], opts :: keyword()) ::
  {:ok, [[float()]]} | {:error, term()}

@callback generate_text(messages :: [map()], opts :: keyword()) ::
  {:ok, String.t()} | {:error, term()}

# Capabilities struct per provider
defmodule Rag.Ai.Capabilities do
  defstruct [
    :supports_embedding,
    :supports_generation,
    :supports_streaming,
    :supports_function_calling,
    :supports_vision,
    :max_tokens,
    :embedding_dimensions
  ]
end
```

#### portfolio_core Has:

- Separate Embedder and LLM ports (which is fine)
- Missing unified provider capabilities type

#### GAPS:

| Gap ID | Description | Severity | Resolution |
|--------|-------------|----------|------------|
| PRV-01 | Missing unified capabilities type | Low | Add to Router or create Provider port |

**Recommendation**: The separation of Embedder and LLM ports is architecturally sound. Consider adding a capabilities type to the Router port instead of creating a new Provider port.

---

## Summary: All Gaps by Priority

### Critical (Must Fix for v0.3.0)

| ID | Port | Description |
|----|------|-------------|
| GRF-01 | GraphStore | Missing `traverse/3` callback |
| GRF-02 | GraphStore | Missing `vector_search/3` callback |
| GRF-03 | GraphStore.Community | Missing community operations behavior |
| GRF-04 | GraphStore.Community | Missing `get_community_members/2` callback |
| GRF-05 | GraphStore.Community | Missing `update_community_summary/3` callback |
| CHK-01 | Chunker | Missing byte position tracking |
| EVL-01 | Evaluation | Missing entire port |

### High Priority

| ID | Port | Description |
|----|------|-------------|
| CHK-02 | Chunker | Missing strategy struct pattern |
| RET-01 | Retriever | Missing `id` field in result |
| RET-02 | Retriever | Missing `supports_embedding?/0` |
| RET-03 | Retriever | Missing `supports_text_query?/0` |
| VEC-01 | VectorStore | Missing `fulltext_search/3` |
| GRF-06 | GraphStore.Community | Missing `list_communities/2` |
| PIP-01 | Pipeline | Missing `parallel` flag |
| PIP-02 | Pipeline | Missing `on_error` handling |
| RTR-01 | Router | Missing `execute/2` callback |

### Medium Priority

| ID | Port | Description |
|----|------|-------------|
| CHK-03 | Chunker | Missing `supported_strategies/0` |
| CHK-04 | Chunker | Format vs strategy API |
| RRK-01 | Reranker | Missing `id` field |
| RRK-02 | Reranker | Missing `normalize_scores/1` |
| VEC-02 | VectorStore | Missing RRF helper for hybrid scoring |
| PIP-03 | Pipeline | Missing `timeout` spec |
| PIP-04 | Pipeline | Missing cache TTL spec |
| CAC-01 | Cache | Missing `compute_if_absent/3` |
| CAC-02 | Cache | Missing `invalidate_pattern/2` |
| AGT-01 | Agent | Missing session-based API |
| AGT-02 | Agent | Missing `process/3` callback |
| RTR-02 | Router | Missing retry mechanism |

### Low Priority

| ID | Port | Description |
|----|------|-------------|
| EMB-01 | Embedder | Different function signatures |
| EMB-02 | Embedder | Missing telemetry docs |
| RRK-03 | Reranker | Missing passthrough docs |
| VEC-03 | VectorStore | No Ecto query pattern |
| PRV-01 | Provider | Missing capabilities type |

---

## Implementation Checklist

```
[ ] 1. Create Evaluation port (EVL-01)
[ ] 2. Update GraphStore port and add GraphStore.Community behavior (GRF-01 to GRF-06)
[ ] 3. Update Chunker port with byte positions and strategies (CHK-01 to CHK-04)
[ ] 4. Update Retriever port with id and capability callbacks (RET-01 to RET-03)
[ ] 5. Update VectorStore port with fulltext search and hybrid helper (VEC-01, VEC-02)
[ ] 6. Update Pipeline port with parallel and error handling (PIP-01 to PIP-04)
[ ] 7. Update Router port with execute callback (RTR-01, RTR-02)
[ ] 8. Update Reranker port with id and normalize (RRK-01 to RRK-03)
[ ] 9. Update Cache port with compute_if_absent (CAC-01, CAC-02)
[ ] 10. Update Agent port with session API (AGT-01, AGT-02)
[ ] 11. Update mix.exs version to 0.3.0
[ ] 12. Update README.md version to 0.3.0
[ ] 13. Add CHANGELOG entry for v0.3.0
[ ] 14. Run mix format
[ ] 15. Run mix credo --strict
[ ] 16. Run mix dialyzer
[ ] 17. Run mix test
```
