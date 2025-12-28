#!/bin/bash
set -e

echo "=== Portfolio Core Examples ==="
echo ""

echo "1. Basic Port Usage"
mix run examples/basic_port_usage.exs
echo ""

echo "2. Manifest Loading"
mix run examples/manifest_loading.exs
echo ""

echo "3. Custom Adapter"
mix run examples/custom_adapter.exs
echo ""

echo "4. Router Port (v0.2.0)"
mix run examples/router_port.exs
echo ""

echo "5. Cache Port (v0.2.0)"
mix run examples/cache_port.exs
echo ""

echo "6. Agent Port (v0.2.0)"
mix run examples/agent_port.exs
echo ""

echo "7. Enhanced Registry (v0.2.0)"
mix run examples/enhanced_registry.exs
echo ""

echo "=== All examples completed successfully ==="
