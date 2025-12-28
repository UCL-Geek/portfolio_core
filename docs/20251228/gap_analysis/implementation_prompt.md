# Implementation Prompt: portfolio_core v0.3.0

**Date**: December 28, 2025
**Target**: Enhance portfolio_core port specifications to achieve rag_ex feature parity
**Approach**: TDD - Write tests first, then implement

---

## REQUIRED READING

Before starting implementation, you MUST read the following files:

### Gap Analysis Document
```
/home/home/p/g/n/portfolio_core/docs/20251228/gap_analysis/gap_analysis.md
```

### Current Port Specifications (ALL FILES)
```
/home/home/p/g/n/portfolio_core/lib/portfolio_core/ports/chunker.ex
/home/home/p/g/n/portfolio_core/lib/portfolio_core/ports/retriever.ex
/home/home/p/g/n/portfolio_core/lib/portfolio_core/ports/reranker.ex
/home/home/p/g/n/portfolio_core/lib/portfolio_core/ports/embedder.ex
/home/home/p/g/n/portfolio_core/lib/portfolio_core/ports/vector_store.ex
/home/home/p/g/n/portfolio_core/lib/portfolio_core/ports/graph_store.ex
/home/home/p/g/n/portfolio_core/lib/portfolio_core/ports/pipeline.ex
/home/home/p/g/n/portfolio_core/lib/portfolio_core/ports/cache.ex
/home/home/p/g/n/portfolio_core/lib/portfolio_core/ports/router.ex
/home/home/p/g/n/portfolio_core/lib/portfolio_core/ports/agent.ex
/home/home/p/g/n/portfolio_core/lib/portfolio_core/ports/tool.ex
/home/home/p/g/n/portfolio_core/lib/portfolio_core/ports/llm.ex
/home/home/p/g/n/portfolio_core/lib/portfolio_core/ports/document_store.ex
```

### Supporting Files
```
/home/home/p/g/n/portfolio_core/lib/portfolio_core.ex
/home/home/p/g/n/portfolio_core/lib/portfolio_core/registry.ex
/home/home/p/g/n/portfolio_core/lib/portfolio_core/telemetry.ex
/home/home/p/g/n/portfolio_core/mix.exs
/home/home/p/g/n/portfolio_core/README.md
/home/home/p/g/n/portfolio_core/CHANGELOG.md
```

### Reference: rag_ex Gap Analysis
```
/home/home/p/g/n/portfolio_manager/docs/20251228/architecture-overview/gap-analysis.md
```

---

## CONTEXT

portfolio_core is a foundational library providing port specifications (Elixir behaviors) for RAG systems. It does NOT contain implementations - only contracts/interfaces.

The gap analysis identified **17 gaps** between portfolio_core ports and rag_ex behaviors. This implementation task focuses on enhancing the port specifications to achieve feature parity.

### Key Principle

**This is a ports-only library.** We are adding:
- New type definitions
- New callback specifications
- New callback specifications (required or optional as appropriate)
- Documentation updates

We are NOT adding:
- Implementations
- External dependencies
- Database schemas
- API clients

---

## IMPLEMENTATION TASKS

### Task 1: Create Evaluation Port (CRITICAL)

**File**: `/home/home/p/g/n/portfolio_core/lib/portfolio_core/ports/evaluation.ex`

Create a new port specification for RAG quality evaluation.

```elixir
defmodule PortfolioCore.Ports.Evaluation do
  @moduledoc """
  Port specification for RAG quality evaluation.

  Implements the RAG Triad evaluation framework (TruLens-based):
  - Context Relevance: Is retrieved context relevant to query?
  - Groundedness: Is response supported by context?
  - Answer Relevance: Does answer address the query?

  Also supports hallucination detection for safety verification.

  ## Example Implementation

      defmodule MyApp.Adapters.LLMEvaluator do
        @behaviour PortfolioCore.Ports.Evaluation

        @impl true
        def evaluate_rag_triad(generation, opts) do
          # Use LLM to score each dimension 1-5
        end

        @impl true
        def detect_hallucination(generation, opts) do
          # Check if response is grounded in context
        end
      end

  ## RAG Triad Scores

  Each dimension is scored 1-5:
  - 1 = Very poor
  - 2 = Poor
  - 3 = Acceptable
  - 4 = Good
  - 5 = Excellent
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

  @type hallucination_result :: %{
          hallucinating: boolean(),
          evidence: String.t()
        }

  @doc """
  Evaluate a RAG generation using the RAG Triad framework.

  ## Parameters

    - `generation` - The generation to evaluate with query, context, and response
    - `opts` - Evaluation options:
      - `:model` - LLM model to use for evaluation
      - `:timeout` - Timeout in milliseconds

  ## Returns

    - `{:ok, result}` with scores for all three dimensions
    - `{:error, reason}` on failure
  """
  @callback evaluate_rag_triad(generation(), opts :: keyword()) ::
              {:ok, triad_result()} | {:error, term()}

  @doc """
  Evaluate context relevance only.

  Measures how well the retrieved context matches the query.
  """
  @callback evaluate_context_relevance(generation(), opts :: keyword()) ::
              {:ok, triad_score()} | {:error, term()}

  @doc """
  Evaluate groundedness only.

  Measures how well the response is supported by the context.
  """
  @callback evaluate_groundedness(generation(), opts :: keyword()) ::
              {:ok, triad_score()} | {:error, term()}

  @doc """
  Evaluate answer relevance only.

  Measures how well the response addresses the query.
  """
  @callback evaluate_answer_relevance(generation(), opts :: keyword()) ::
              {:ok, triad_score()} | {:error, term()}

  @doc """
  Detect if response contains hallucinations.

  Hallucinations are claims in the response that are not supported
  by the provided context.

  ## Returns

    - `{:ok, %{hallucinating: false, evidence: "..."}}` if grounded
    - `{:ok, %{hallucinating: true, evidence: "..."}}` if hallucinating
    - `{:error, reason}` on failure
  """
  @callback detect_hallucination(generation(), opts :: keyword()) ::
              {:ok, hallucination_result()} | {:error, term()}
end
```

**Test File**: `/home/home/p/g/n/portfolio_core/test/portfolio_core/ports/evaluation_test.exs`

```elixir
defmodule PortfolioCore.Ports.EvaluationTest do
  use ExUnit.Case, async: true

  alias PortfolioCore.Ports.Evaluation

  describe "behaviour definition" do
    test "defines evaluate_rag_triad/2 callback" do
      callbacks = Evaluation.behaviour_info(:callbacks)
      assert {:evaluate_rag_triad, 2} in callbacks
    end

    test "defines detect_hallucination/2 callback" do
      callbacks = Evaluation.behaviour_info(:callbacks)
      assert {:detect_hallucination, 2} in callbacks
    end

    test "defines individual dimension callbacks as required" do
      callbacks = Evaluation.behaviour_info(:callbacks)
      optional = Evaluation.behaviour_info(:optional_callbacks)

      assert {:evaluate_context_relevance, 2} in callbacks
      assert {:evaluate_groundedness, 2} in callbacks
      assert {:evaluate_answer_relevance, 2} in callbacks

      refute {:evaluate_context_relevance, 2} in optional
      refute {:evaluate_groundedness, 2} in optional
      refute {:evaluate_answer_relevance, 2} in optional
    end
  end
end
```

---

### Task 2: Enhance GraphStore Port (CRITICAL)

**File**: `/home/home/p/g/n/portfolio_core/lib/portfolio_core/ports/graph_store.ex`

Add the following to the existing GraphStore port:

```elixir
# Add these types after existing types

@type traversal_algorithm :: :bfs | :dfs

@type community :: %{
        id: String.t(),
        name: String.t(),
        summary: String.t() | nil,
        member_count: non_neg_integer(),
        level: non_neg_integer()
      }

# Add these callbacks after existing callbacks

@doc """
Traverse the graph from a starting node.

## Parameters

  - `graph_id` - The graph to traverse
  - `node_id` - Starting node
  - `opts` - Traversal options:
    - `:direction` - `:outgoing`, `:incoming`, or `:both`
    - `:max_depth` - Maximum traversal depth
    - `:algorithm` - `:bfs` or `:dfs`
    - `:edge_types` - Filter by edge types
    - `:limit` - Maximum nodes to return

## Returns

  - `{:ok, nodes}` - List of traversed nodes
  - `{:error, reason}` on failure
"""
@callback traverse(graph_id(), node_id(), opts :: keyword()) ::
            {:ok, [graph_node()]} | {:error, term()}

@doc """
Search for nodes by vector similarity.

Requires nodes to have embeddings stored in properties.

## Parameters

  - `graph_id` - The graph to search
  - `embedding` - Query embedding vector
  - `opts` - Search options:
    - `:k` - Number of results
    - `:labels` - Filter by node labels
    - `:min_score` - Minimum similarity score

## Returns

  - `{:ok, nodes}` - Matching nodes sorted by similarity
  - `{:error, reason}` on failure
"""
@callback vector_search(graph_id(), embedding :: [float()], opts :: keyword()) ::
            {:ok, [graph_node()]} | {:error, term()}
@optional_callbacks [vector_search: 3]
```

**GraphStore.Community Behavior**:

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

### Task 3: Enhance Chunker Port (CRITICAL)

**File**: `/home/home/p/g/n/portfolio_core/lib/portfolio_core/ports/chunker.ex`

Update the chunk type and add strategy support:

```elixir
# Replace existing chunk type with enhanced version
@type chunk :: %{
        content: String.t(),
        index: non_neg_integer(),
        start_byte: non_neg_integer(),
        end_byte: non_neg_integer(),
        start_offset: non_neg_integer(),
        end_offset: non_neg_integer(),
        metadata: map()
      }

# Add strategy type
@type strategy ::
        :character
        | :sentence
        | :paragraph
        | :recursive
        | :semantic
        | :format_aware

# Add after existing callbacks
@doc """
Get list of chunking strategies supported by this adapter.

## Returns

  - List of supported strategy atoms
"""
@callback supported_strategies() :: [strategy()]

@optional_callbacks [supported_strategies: 0]
```

---

### Task 4: Enhance Retriever Port (HIGH)

**File**: `/home/home/p/g/n/portfolio_core/lib/portfolio_core/ports/retriever.ex`

Update result type and add capability callbacks:

```elixir
# Update retrieved_item type to include id
@type retrieved_item :: %{
        id: term(),
        content: String.t(),
        score: float(),
        source: String.t(),
        metadata: map()
      }

# Add capability callbacks
@doc """
Indicate whether this retriever supports embedding-based queries.
"""
@callback supports_embedding?() :: boolean()

@doc """
Indicate whether this retriever supports text-based queries.
"""
@callback supports_text_query?() :: boolean()
```

---

### Task 5: Enhance VectorStore Port (HIGH)

**File**: `/home/home/p/g/n/portfolio_core/lib/portfolio_core/ports/vector_store.ex`

Add fulltext search support:

```elixir
# Add after existing callbacks

@doc """
Perform full-text search on stored content.

## Parameters

  - `index_id` - The index to search
  - `query` - Text query string
  - `k` - Number of results to return
  - `opts` - Search options:
    - `:filter` - Metadata filter
    - `:min_score` - Minimum relevance score

## Returns

  - `{:ok, results}` - List of search results
  - `{:error, reason}` on failure
"""
@callback fulltext_search(index_id(), query :: String.t(), k :: pos_integer(), opts :: keyword()) ::
            {:ok, [search_result()]} | {:error, term()}

@optional_callbacks [fulltext_search: 4]
```

Add hybrid helpers:

```elixir
# RRF helper module
PortfolioCore.VectorStore.RRF.calculate_rrf_score(semantic_results, fulltext_results, opts)

# Capability behavior for stores that support fulltext search
defmodule PortfolioCore.Ports.VectorStore.Hybrid do
  @callback fulltext_search(index_id(), query :: String.t(), k :: pos_integer(), opts :: keyword()) ::
              {:ok, [search_result()]} | {:error, term()}
end
```

---

### Task 6: Enhance Pipeline Port (HIGH)

**File**: `/home/home/p/g/n/portfolio_core/lib/portfolio_core/ports/pipeline.ex`

Add parallel execution and error handling:

```elixir
# Add error handling type
@type on_error :: :halt | :continue | {:retry, pos_integer()}

# Add new callbacks
@doc """
Indicate whether this step can run in parallel with other steps.
"""
@callback parallel?() :: boolean()

@doc """
Define error handling behavior for this step.

  - `:halt` - Stop pipeline on error
  - `:continue` - Skip step and continue
  - `{:retry, n}` - Retry up to n times
"""
@callback on_error() :: on_error()

@doc """
Get the timeout for this step in milliseconds.
"""
@callback timeout() :: pos_integer()

@doc """
Get the cache TTL for this step.

Returns `:infinity` for permanent caching or milliseconds.
"""
@callback cache_ttl() :: pos_integer() | :infinity
```

---

### Task 7: Enhance Router Port (HIGH)

**File**: `/home/home/p/g/n/portfolio_core/lib/portfolio_core/ports/router.ex`

Add execute callback:

```elixir
# Add after existing callbacks

@doc """
Route to a provider and execute the request.

Combines provider selection and request execution in one call.

## Parameters

  - `messages` - Chat messages to process
  - `opts` - Options including strategy and task type

## Returns

  - `{:ok, response}` with provider response
  - `{:error, reason}` on failure
"""
@callback execute(messages :: [map()], opts :: route_opts()) ::
            {:ok, map()} | {:error, term()}

@doc """
Execute with automatic retry on failure.

Tries next available provider if current one fails.

## Parameters

  - `messages` - Chat messages to process
  - `opts` - Options:
    - `:max_retries` - Maximum retry attempts
    - `:retry_delay` - Delay between retries in ms

## Returns

  - `{:ok, response}` with provider response
  - `{:error, reason}` if all providers fail
"""
@callback execute_with_retry(messages :: [map()], opts :: route_opts()) ::
            {:ok, map()} | {:error, term()}

@optional_callbacks [execute_with_retry: 2]
```

---

### Task 8: Enhance Reranker Port (MEDIUM)

**File**: `/home/home/p/g/n/portfolio_core/lib/portfolio_core/ports/reranker.ex`

Add id field and normalize callback:

```elixir
# Update reranked_item type
@type reranked_item :: %{
        id: term(),
        content: String.t(),
        original_score: float(),
        rerank_score: float(),
        metadata: map()
      }

# Add normalize callback
@doc """
Normalize rerank scores to 0-1 range.

Useful for combining with other scoring systems.
"""
@callback normalize_scores([reranked_item()]) :: [reranked_item()]

@optional_callbacks [normalize_scores: 1]
```

---

### Task 9: Enhance Cache Port (MEDIUM)

**File**: `/home/home/p/g/n/portfolio_core/lib/portfolio_core/ports/cache.ex`

Add compute_if_absent and invalidate_pattern:

```elixir
# Add after existing callbacks

@doc """
Get value if exists, otherwise compute and store.

Implements the cache-aside pattern atomically.

## Parameters

  - `key` - Cache key
  - `compute_fn` - Zero-arity function to compute value if missing
  - `opts` - Cache options including TTL

## Returns

  - `{:ok, value}` - Cached or computed value
  - `{:error, reason}` on failure
"""
@callback compute_if_absent(key(), compute_fn :: (-> value()), opts :: cache_opts()) ::
            {:ok, value()} | {:error, term()}

@doc """
Invalidate all keys matching a pattern.

## Parameters

  - `pattern` - Glob or regex pattern to match keys
  - `opts` - Cache options including namespace

## Returns

  - `{:ok, count}` - Number of keys invalidated
  - `{:error, reason}` on failure
"""
@callback invalidate_pattern(pattern :: String.t(), opts :: cache_opts()) ::
            {:ok, non_neg_integer()} | {:error, term()}

@optional_callbacks [compute_if_absent: 3, invalidate_pattern: 2]
```

---

### Task 10: Enhance Agent Port (MEDIUM)

**File**: `/home/home/p/g/n/portfolio_core/lib/portfolio_core/ports/agent.ex`

Add session-based API:

```elixir
# Add session type
@type session :: %{
        id: String.t(),
        messages: [message()],
        tool_results: [tool_result()],
        created_at: DateTime.t(),
        updated_at: DateTime.t()
      }

# Add session-based callbacks
@doc """
Process input within a session context.

Maintains conversation history across calls.

## Parameters

  - `session` - Current session state
  - `input` - User input to process
  - `opts` - Processing options

## Returns

  - `{:ok, response, updated_session}` on success
  - `{:error, reason}` on failure
"""
@callback process(session(), input :: String.t(), opts :: keyword()) ::
            {:ok, String.t(), session()} | {:error, term()}

@doc """
Process input with tool execution within a session.

Runs the tool execution loop until completion or max iterations.
"""
@callback process_with_tools(session(), input :: String.t(), tools :: [atom()], opts :: keyword()) ::
            {:ok, String.t(), session()} | {:error, term()}
```

---

### Task 11: Update Main Module

**File**: `/home/home/p/g/n/portfolio_core/lib/portfolio_core.ex`

Add export for new Evaluation port.

---

### Task 12: Update Telemetry Events

**File**: `/home/home/p/g/n/portfolio_core/lib/portfolio_core/telemetry.ex`

Add telemetry event definitions for new operations:

```elixir
# Add to existing events
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
```

---

### Task 13: Version Bump

**File**: `/home/home/p/g/n/portfolio_core/mix.exs`

Update version:
```elixir
@version "0.3.0"
```

**File**: `/home/home/p/g/n/portfolio_core/README.md`

Update installation section:
```elixir
{:portfolio_core, "~> 0.3.0"}
```

Update feature list to include:
- 14 core port specifications (add Evaluation)
- GraphStore.Community behavior for GraphRAG community operations
- VectorStore hybrid capability and RRF helper
- Enhanced chunker with byte positions
- Evaluation and hallucination detection

---

### Task 14: CHANGELOG Entry

**File**: `/home/home/p/g/n/portfolio_core/CHANGELOG.md`

Add at top after `[Unreleased]`:

```markdown
## [0.3.0] - 2025-12-28

### Added
- `PortfolioCore.Ports.Evaluation` - RAG quality evaluation port
  - `evaluate_rag_triad/2` - Context relevance, groundedness, answer relevance
  - `detect_hallucination/2` - Hallucination detection
- GraphStore traversal (`traverse/3`) and optional vector search (`vector_search/3`)
- `GraphStore.Community` behavior for community operations
- Chunker byte position tracking (`start_byte`, `end_byte`)
- Chunker strategy type union and `supported_strategies/0` callback
- Retriever capability detection (`supports_embedding?/0`, `supports_text_query?/0`)
- VectorStore fulltext search (`fulltext_search/4`)
- VectorStore hybrid helper (`PortfolioCore.VectorStore.RRF`)
- VectorStore hybrid capability (`PortfolioCore.Ports.VectorStore.Hybrid`)
- Pipeline parallel execution (`parallel?/0`)
- Pipeline error handling modes (`on_error/0`)
- Pipeline timeout and cache TTL (`timeout/0`, `cache_ttl/0`)
- Router execute callbacks (`execute/2`, `execute_with_retry/2`)
- Reranker score normalization (`normalize_scores/1`)
- Cache compute-if-absent pattern (`compute_if_absent/3`)
- Cache pattern invalidation (`invalidate_pattern/2`)
- Agent session-based API (`process/3`, `process_with_tools/4`)
- New telemetry events for evaluation and community operations

### Changed
- `Chunker.chunk` type now includes `start_byte` and `end_byte` fields
- `Retriever.retrieved_item` type now includes `id` field
- `Reranker.reranked_item` type now includes `id` field
- Port count increased from 13 to 14 (plus capability behaviors)
```

At bottom, update links:
```markdown
[0.3.0]: https://github.com/nshkrdotcom/portfolio_core/compare/v0.2.0...v0.3.0
```

---

## GOALS

After completing all tasks, verify:

1. **No Warnings**
   ```bash
   mix compile --warnings-as-errors
   ```

2. **No Errors**
   ```bash
   mix compile
   ```

3. **All Tests Pass**
   ```bash
   mix test
   ```

4. **No Dialyzer Issues**
   ```bash
   mix dialyzer
   ```

5. **No Credo Issues**
   ```bash
   mix credo --strict
   ```

6. **Properly Formatted**
   ```bash
   mix format --check-formatted
   ```

---

## IMPLEMENTATION ORDER

Follow this order for clean incremental development:

1. **Create Evaluation port** (new file)
2. **Enhance GraphStore port** (most changes)
3. **Enhance Chunker port** (type changes)
4. **Enhance Retriever port** (type + callbacks)
5. **Enhance VectorStore port** (new callbacks)
6. **Enhance Pipeline port** (new callbacks)
7. **Enhance Router port** (new callbacks)
8. **Enhance Reranker port** (type + callback)
9. **Enhance Cache port** (new callbacks)
10. **Enhance Agent port** (type + callbacks)
11. **Update main module** (exports)
12. **Update telemetry** (event definitions)
13. **Version bump** (mix.exs, README)
14. **CHANGELOG entry**
15. **Final verification** (all quality checks)

---

## TEST STRATEGY

For each port enhancement:

1. Write a test that verifies the callback exists in `behaviour_info(:callbacks)`
2. Write a test that verifies optional callbacks (if any) are in `behaviour_info(:optional_callbacks)` and required callbacks are not
3. Create a minimal mock implementation using Mox to verify the types compile

Example test pattern:

```elixir
defmodule PortfolioCore.Ports.GraphStoreEnhancedTest do
  use ExUnit.Case, async: true

  alias PortfolioCore.Ports.GraphStore
  alias PortfolioCore.Ports.GraphStore.Community

  describe "graph traversal" do
    test "defines traverse/3 callback as required" do
      callbacks = GraphStore.behaviour_info(:callbacks)
      optional = GraphStore.behaviour_info(:optional_callbacks)

      assert {:traverse, 3} in callbacks
      refute {:traverse, 3} in optional
    end

    test "defines vector_search/3 callback as optional" do
      optional = GraphStore.behaviour_info(:optional_callbacks)
      assert {:vector_search, 3} in optional
    end
  end

  describe "community operations" do
    test "defines community callbacks as required" do
      callbacks = Community.behaviour_info(:callbacks)

      assert {:create_community, 3} in callbacks
      assert {:get_community_members, 2} in callbacks
      assert {:update_community_summary, 3} in callbacks
      assert {:list_communities, 2} in callbacks
    end
  end
end
```

---

## NOTES

- New callbacks should be required unless they represent optional capabilities or non-universal backend features
- Type definitions should use descriptive field names matching rag_ex conventions
- Documentation should include examples and parameter descriptions
- Use `@doc` for all public callbacks
- Keep the moduledoc concise but informative
- Ensure all types are exportable (no private types)

---

## VERIFICATION CHECKLIST

Before marking complete:

```
[ ] Evaluation port created with all callbacks
[ ] GraphStore.Community behavior added
[ ] Chunker port has byte positions
[ ] Retriever port has capability callbacks
[ ] VectorStore port has fulltext search
[ ] VectorStore hybrid helper and behavior added
[ ] Pipeline port has parallel/error handling
[ ] Router port has execute callbacks
[ ] Reranker port has normalize callback
[ ] Cache port has compute_if_absent
[ ] Agent port has session API
[ ] All tests pass
[ ] No dialyzer errors
[ ] No credo issues
[ ] Code is formatted
[ ] Version is 0.3.0
[ ] CHANGELOG is updated
[ ] README reflects new features
```
