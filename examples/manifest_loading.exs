# Manifest Loading Example
# Run: mix run examples/manifest_loading.exs

# This example demonstrates manifest-based configuration
# using the PortfolioCore manifest engine.

defmodule Examples.DummyVectorStore do
  @moduledoc "A dummy adapter for demonstration"
  @behaviour PortfolioCore.Ports.VectorStore

  @impl true
  def create_index(_id, _config), do: :ok
  @impl true
  def delete_index(_id), do: :ok
  @impl true
  def store(_idx, _id, _vec, _meta), do: :ok
  @impl true
  def store_batch(_idx, _items), do: {:ok, 0}
  @impl true
  def search(_idx, _vec, _k, _opts), do: {:ok, []}
  @impl true
  def delete(_idx, _id), do: :ok
  @impl true
  def index_stats(_idx), do: {:ok, %{count: 0, dimensions: 0, metric: :cosine, size_bytes: nil}}
end

defmodule Examples.DummyEmbedder do
  @moduledoc "A dummy embedder for demonstration"
  @behaviour PortfolioCore.Ports.Embedder

  @impl true
  def embed(_text, _opts) do
    {:ok,
     %{
       vector: List.duplicate(0.1, 1536),
       model: "demo-model",
       dimensions: 1536,
       token_count: 10
     }}
  end

  @impl true
  def embed_batch(texts, _opts) do
    embeddings =
      Enum.map(texts, fn _ ->
        %{
          vector: List.duplicate(0.1, 1536),
          model: "demo-model",
          dimensions: 1536,
          token_count: 5
        }
      end)

    {:ok, %{embeddings: embeddings, total_tokens: length(texts) * 5}}
  end

  @impl true
  def dimensions(_model), do: 1536
  @impl true
  def supported_models, do: ["demo-model"]
end

IO.puts("=" |> String.duplicate(60))
IO.puts("Portfolio Core - Manifest Loading Example")
IO.puts("=" |> String.duplicate(60))

# Create a temporary manifest file
manifest_content = """
version: "1.0"
environment: development
adapters:
  vector_store:
    adapter: Examples.DummyVectorStore
    config:
      dimensions: 1536
      metric: cosine
  embedder:
    adapter: Examples.DummyEmbedder
    config:
      model: demo-model
      batch_size: 100
telemetry:
  enabled: true
"""

manifest_path = Path.join(System.tmp_dir!(), "example_manifest.yml")
File.write!(manifest_path, manifest_content)

IO.puts("\n1. Created manifest file at: #{manifest_path}")
IO.puts("\n   Manifest content:")
IO.puts("   " <> String.replace(manifest_content, "\n", "\n   "))

# Load the manifest using the engine
IO.puts("\n2. Loading manifest with Engine...")

{:ok, engine} =
  PortfolioCore.Manifest.Engine.start_link(
    manifest_path: manifest_path,
    name: :example_engine
  )

IO.puts("   Engine started successfully")

# Get the loaded manifest
manifest = PortfolioCore.Manifest.Engine.get_manifest(:example_engine)
IO.puts("\n3. Loaded manifest:")
IO.puts("   Version: #{manifest[:version]}")
IO.puts("   Environment: #{manifest[:environment]}")

# Get adapters
IO.puts("\n4. Registered adapters:")

{vector_module, vector_config} =
  PortfolioCore.Manifest.Engine.get_adapter(:vector_store, :example_engine)

IO.puts("   vector_store:")
IO.puts("     Module: #{inspect(vector_module)}")
IO.puts("     Config: #{inspect(vector_config)}")

{embedder_module, embedder_config} =
  PortfolioCore.Manifest.Engine.get_adapter(:embedder, :example_engine)

IO.puts("   embedder:")
IO.puts("     Module: #{inspect(embedder_module)}")
IO.puts("     Config: #{inspect(embedder_config)}")

# Demonstrate environment variable expansion
IO.puts("\n5. Testing environment variable expansion...")

System.put_env("EXAMPLE_API_KEY", "secret-key-12345")

manifest_with_env = """
version: "1.0"
environment: production
adapters:
  embedder:
    adapter: Examples.DummyEmbedder
    config:
      api_key: ${EXAMPLE_API_KEY}
      model: production-model
"""

manifest_env_path = Path.join(System.tmp_dir!(), "env_manifest.yml")
File.write!(manifest_env_path, manifest_with_env)

{:ok, expanded} = PortfolioCore.Manifest.Loader.load(manifest_env_path)

IO.puts("   Original: api_key: ${EXAMPLE_API_KEY}")

IO.puts(
  "   Expanded: api_key: #{get_in(expanded, ["adapters", "embedder", "config", "api_key"])}"
)

# Cleanup
GenServer.stop(engine)
File.rm!(manifest_path)
File.rm!(manifest_env_path)
System.delete_env("EXAMPLE_API_KEY")

IO.puts("\n" <> String.duplicate("=", 60))
IO.puts("Example completed successfully!")
IO.puts(String.duplicate("=", 60))
