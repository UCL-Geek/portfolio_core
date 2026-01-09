# Portfolio Core Examples

## Running Examples

```bash
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
mix run examples/document_store_port.exs
mix run examples/graph_store_port.exs
mix run examples/ollama_llm_adapter.exs
mix run examples/ollama_embedder.exs
```

Ollama examples require a running server (`ollama serve`) and the models to be pulled.
Defaults: `llama3.2` for chat and `nomic-embed-text` for embeddings. Override with
`OLLAMA_BASE_URL`, `OLLAMA_MODEL`, or `OLLAMA_EMBED_MODEL`.

The enhanced registry example uses OpenAI; set `OPENAI_API_KEY` to enable the live call.

## Examples

| File | Description |
|------|-------------|
| basic_port_usage.exs | Using port behaviors |
| manifest_loading.exs | Loading YAML manifests |
| custom_adapter.exs | Creating custom adapters |
| router_port.exs | Multi-provider routing (v0.2.0) |
| cache_port.exs | Caching behavior (v0.2.0) |
| agent_port.exs | Agent behavior (v0.2.0) |
| enhanced_registry.exs | Registry features + backend capability discovery |
| document_store_port.exs | In-memory document store adapter |
| graph_store_port.exs | In-memory graph store adapter with traversal |
| ollama_llm_adapter.exs | Ollama LLM adapter (requires Ollama server + model) |
| ollama_embedder.exs | Ollama embedder adapter (requires Ollama server + nomic-embed-text) |
