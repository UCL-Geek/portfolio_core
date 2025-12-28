# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.1] - 2025-12-27

### Added

- Default value support for environment variables with `${VAR:-default}` syntax
- RAG strategy configuration field in manifest schema

### Changed

- Enhanced environment variable regex to support default value syntax

## [0.1.0] - 2025-12-26

### Added

- Initial release of PortfolioCore
- Port specifications (Elixir behaviors) for:
  - `VectorStore` - Vector similarity search backends
  - `GraphStore` - Knowledge graph database operations
  - `DocumentStore` - Document storage and retrieval
  - `Embedder` - Text embedding generation
  - `LLM` - Large language model completions
  - `Chunker` - Document chunking strategies
  - `Retriever` - Retrieval strategy implementations
  - `Reranker` - Result reranking
- Manifest engine with:
  - YAML configuration loading
  - Environment variable expansion (`${VAR}` syntax)
  - NimbleOptions-based schema validation
  - Hot reload support
- Adapter registry with:
  - ETS-backed storage for concurrent access
  - Dynamic adapter lookup
  - Port registration and unregistration
- Telemetry integration:
  - Span macros for measuring operations
  - Standard event definitions
  - Observable adapter calls
- Application supervisor for process management
- Comprehensive test suite with Mox mocks
- Runnable examples in `examples/` directory
- Documentation with ExDoc

### Notes

- This is a foundational library providing only port specifications
- Concrete adapter implementations should use `portfolio_index` package
- No database schemas, migrations, or external API calls included

[Unreleased]: https://github.com/nshkrdotcom/portfolio_core/compare/v0.1.1...HEAD
[0.1.1]: https://github.com/nshkrdotcom/portfolio_core/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/nshkrdotcom/portfolio_core/releases/tag/v0.1.0
