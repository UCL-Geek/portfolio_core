# Portfolio Core Examples

## Running Examples

All examples can be run with `mix run`:

```bash
# Basic port usage with mock adapter
mix run examples/basic_port_usage.exs

# Manifest loading
mix run examples/manifest_loading.exs

# Custom adapter implementation
mix run examples/custom_adapter.exs
```

## Examples

### basic_port_usage.exs
Demonstrates how to implement and use a simple in-memory vector store adapter.

### manifest_loading.exs
Shows manifest-based configuration loading with environment variable expansion.

### custom_adapter.exs
Complete example of creating a custom adapter for the VectorStore port.

## Prerequisites

Before running examples, ensure you have:

1. Dependencies installed:
   ```bash
   mix deps.get
   ```

2. Project compiled:
   ```bash
   mix compile
   ```
