# Example: Using enhanced registry features
# Run: mix run examples/enhanced_registry.exs

alias PortfolioCore.Registry

defmodule Examples.DummyLLM do
  @moduledoc false
end

IO.puts("=" |> String.duplicate(60))
IO.puts("Portfolio Core - Enhanced Registry Example")
IO.puts("=" |> String.duplicate(60))

Registry.clear()

# Register with metadata
Registry.register(:primary_llm, Examples.DummyLLM, %{model: "gpt-4"}, %{
  capabilities: [:generation, :streaming, :function_calling]
})

# Find capable adapters
streaming_adapters = Registry.find_by_capability(:streaming)
IO.inspect(streaming_adapters, label: "Streaming capable")

# Health management
Registry.mark_unhealthy(:primary_llm)
IO.puts("Status: #{Registry.health_status(:primary_llm)}")

# Metrics
Registry.record_call(:primary_llm, true)
Registry.record_call(:primary_llm, false)
{:ok, metrics} = Registry.metrics(:primary_llm)
IO.inspect(metrics, label: "Metrics")

IO.puts("\n" <> String.duplicate("=", 60))
IO.puts("Example completed successfully!")
IO.puts(String.duplicate("=", 60))
