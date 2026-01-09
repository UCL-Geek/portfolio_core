# Manifest Loading Example
# Run: mix run examples/manifest_loading.exs

# This example demonstrates manifest-based configuration
# using the PortfolioCore manifest engine.

defmodule Examples.ManifestVectorStore do
  @moduledoc "In-memory vector store adapter for the manifest demo."
  @behaviour PortfolioCore.Ports.VectorStore

  use Agent

  def start_link(_opts) do
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end

  @impl true
  def create_index(index_id, config) do
    Agent.update(__MODULE__, fn state ->
      Map.put(state, index_id, %{config: config, vectors: %{}})
    end)

    :ok
  end

  @impl true
  def delete_index(index_id) do
    Agent.update(__MODULE__, &Map.delete(&1, index_id))
    :ok
  end

  @impl true
  def store(index_id, id, vector, metadata) do
    Agent.update(__MODULE__, fn state ->
      update_in(state, [index_id, :vectors], fn vectors ->
        Map.put(vectors || %{}, id, %{vector: vector, metadata: metadata})
      end)
    end)

    :ok
  end

  @impl true
  def store_batch(index_id, items) do
    Enum.each(items, fn {id, vector, metadata} ->
      store(index_id, id, vector, metadata)
    end)

    {:ok, length(items)}
  end

  @impl true
  def search(index_id, query_vector, k, _opts) do
    vectors =
      Agent.get(__MODULE__, fn state ->
        get_in(state, [index_id, :vectors]) || %{}
      end)

    results =
      vectors
      |> Enum.map(fn {id, %{vector: vec, metadata: meta}} ->
        %{id: id, score: cosine_similarity(query_vector, vec), metadata: meta, vector: nil}
      end)
      |> Enum.sort_by(& &1.score, :desc)
      |> Enum.take(k)

    {:ok, results}
  end

  @impl true
  def delete(index_id, id) do
    Agent.update(__MODULE__, fn state ->
      update_in(state, [index_id, :vectors], &Map.delete(&1 || %{}, id))
    end)

    :ok
  end

  @impl true
  def index_stats(index_id) do
    case Agent.get(__MODULE__, &Map.get(&1, index_id)) do
      nil ->
        {:error, :not_found}

      index ->
        count = map_size(index.vectors || %{})

        {:ok,
         %{
           count: count,
           dimensions: index.config[:dimensions] || 0,
           metric: index.config[:metric] || :cosine,
           size_bytes: nil
         }}
    end
  end

  @impl true
  def index_exists?(index_id) do
    Agent.get(__MODULE__, fn state ->
      Map.has_key?(state, index_id)
    end)
  end

  defp cosine_similarity(a, b) do
    dot = Enum.zip(a, b) |> Enum.map(fn {x, y} -> x * y end) |> Enum.sum()
    mag_a = :math.sqrt(Enum.map(a, &(&1 * &1)) |> Enum.sum())
    mag_b = :math.sqrt(Enum.map(b, &(&1 * &1)) |> Enum.sum())

    if mag_a == 0 or mag_b == 0 do
      0.0
    else
      dot / (mag_a * mag_b)
    end
  end
end

defmodule Examples.ManifestEmbedder do
  @moduledoc "Deterministic embedder for the manifest demo."
  @behaviour PortfolioCore.Ports.Embedder

  @default_model "manifest-embedder"
  @default_dimensions 16

  @impl true
  def embed(text, opts) do
    opts = normalize_opts(opts)
    model = Keyword.get(opts, :model, @default_model)
    dimensions = Keyword.get(opts, :dimensions, @default_dimensions)
    vector = hash_to_vector(text, dimensions)

    {:ok, %{vector: vector, model: model, dimensions: dimensions, token_count: token_count(text)}}
  end

  @impl true
  def embed_batch(texts, opts) do
    opts = normalize_opts(opts)
    model = Keyword.get(opts, :model, @default_model)
    dimensions = Keyword.get(opts, :dimensions, @default_dimensions)

    embeddings =
      Enum.map(texts, fn text ->
        %{
          vector: hash_to_vector(text, dimensions),
          model: model,
          dimensions: dimensions,
          token_count: token_count(text)
        }
      end)

    {:ok, %{embeddings: embeddings, total_tokens: Enum.sum(Enum.map(texts, &token_count/1))}}
  end

  @impl true
  def dimensions(_model), do: @default_dimensions
  @impl true
  def supported_models, do: [@default_model]

  defp normalize_opts(opts) when is_map(opts), do: Map.to_list(opts)
  defp normalize_opts(opts) when is_list(opts), do: opts
  defp normalize_opts(_opts), do: []

  defp hash_to_vector(text, dimensions) do
    bytes = :crypto.hash(:sha256, text) |> :binary.bin_to_list()

    bytes
    |> Stream.cycle()
    |> Enum.take(dimensions)
    |> Enum.map(&(&1 / 255.0))
  end

  defp token_count(text) do
    text |> String.split() |> length()
  end
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
    adapter: Examples.ManifestVectorStore
    config:
      dimensions: 1536
      metric: cosine
  embedder:
    adapter: Examples.ManifestEmbedder
    config:
      model: demo-model
      batch_size: 100
      dimensions: 16
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
    adapter: Examples.ManifestEmbedder
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
