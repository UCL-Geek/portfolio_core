# PortfolioCore Alignment Changes (portfolio_index)

**Date**: 2025-12-28
**Context**: Align portfolio_index adapters and strategies with recent PortfolioCore port updates.

## Drivers

- GraphStore community operations moved into `PortfolioCore.Ports.GraphStore.Community`.
- VectorStore hybrid retrieval split into `PortfolioCore.Ports.VectorStore.Hybrid` with
  RRF helper in `PortfolioCore.VectorStore.RRF`.
- Pipeline port gained `use PortfolioCore.Ports.Pipeline` defaults (no direct usage
  in portfolio_index, but document alignment).

## Planned Changes

### GraphStore Community Alignment

- Make `PortfolioIndex.Adapters.GraphStore.Neo4j.Community` implement
  `PortfolioCore.Ports.GraphStore.Community`.
- Add required callback arities:
  - `create_community/3` (graph_id, community_id, opts)
  - `update_community_summary/3` (graph_id, community_id, summary)
  - Preserve existing 2-arity/4-arity functions for backward compatibility.
- Ensure return values match the behavior contract (`:ok | {:error, term()}` where required).
- Add unit tests validating behavior conformance.

### VectorStore Hybrid + RRF Alignment

- Make `PortfolioIndex.Adapters.VectorStore.Pgvector` implement
  `PortfolioCore.Ports.VectorStore.Hybrid`.
- Add `fulltext_search/4` to `Pgvector`, delegating to
  `PortfolioIndex.Adapters.VectorStore.Pgvector.FullText.search/4` and
  mapping results into `PortfolioCore.Ports.VectorStore.search_result()` shape.
- Update `PortfolioIndex.RAG.Strategies.Hybrid` to:
  - Prefer `fulltext_search/4` when available (fallback to keyword mode).
  - Use `PortfolioCore.VectorStore.RRF.calculate_rrf_score/3` for merging.
- Add unit tests for `fulltext_search/4` and updated hybrid strategy behavior.

### Documentation Touches

- Update portfolio_index module docs / README to mention
  `GraphStore.Community` and `VectorStore.Hybrid`.
- Note that pipeline defaults are provided by PortfolioCore (no code change here).

## Test Plan (TDD)

- Add failing tests first:
  - GraphStore community behavior compliance.
  - Pgvector hybrid behavior + `fulltext_search/4` mapping.
  - Hybrid strategy using fulltext search + RRF helper.
- Implement code until tests pass.
- Run full verification: `mix compile --warnings-as-errors`, `mix test`,
  `mix credo --strict`, `mix dialyzer`.
