# Basic Port Usage Example
# Run: mix run examples/basic_port_usage.exs

defmodule Examples.InMemoryVectorStore do
  @moduledoc """
  A simple in-memory vector store adapter for demonstration.
  """

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

# Run the example
IO.puts("=" |> String.duplicate(60))
IO.puts("Portfolio Core - Basic Port Usage Example")
IO.puts("=" |> String.duplicate(60))

{:ok, _} = Examples.InMemoryVectorStore.start_link([])

IO.puts("\n1. Creating index...")

:ok =
  Examples.InMemoryVectorStore.create_index("demo", %{
    dimensions: 3,
    metric: :cosine,
    index_type: :flat,
    options: %{}
  })

IO.puts("   Index 'demo' created")

IO.puts("\n2. Storing vectors...")
:ok = Examples.InMemoryVectorStore.store("demo", "v1", [1.0, 0.0, 0.0], %{label: "x-axis"})
:ok = Examples.InMemoryVectorStore.store("demo", "v2", [0.0, 1.0, 0.0], %{label: "y-axis"})
:ok = Examples.InMemoryVectorStore.store("demo", "v3", [0.0, 0.0, 1.0], %{label: "z-axis"})
:ok = Examples.InMemoryVectorStore.store("demo", "v4", [0.7, 0.7, 0.0], %{label: "diagonal-xy"})
IO.puts("   Stored 4 vectors")

IO.puts("\n3. Searching for similar vectors to [0.8, 0.6, 0.0]...")
{:ok, results} = Examples.InMemoryVectorStore.search("demo", [0.8, 0.6, 0.0], 3, [])

IO.puts("   Results:")

Enum.each(results, fn %{id: id, score: score, metadata: meta} ->
  IO.puts("     - #{id}: score=#{Float.round(score, 4)}, label=#{meta[:label]}")
end)

IO.puts("\n4. Getting index stats...")
{:ok, stats} = Examples.InMemoryVectorStore.index_stats("demo")
IO.puts("   Count: #{stats.count}")
IO.puts("   Dimensions: #{stats.dimensions}")
IO.puts("   Metric: #{stats.metric}")

IO.puts("\n5. Deleting a vector...")
:ok = Examples.InMemoryVectorStore.delete("demo", "v4")
{:ok, new_stats} = Examples.InMemoryVectorStore.index_stats("demo")
IO.puts("   Vector count after deletion: #{new_stats.count}")

IO.puts("\n" <> String.duplicate("=", 60))
IO.puts("Example completed successfully!")
IO.puts(String.duplicate("=", 60))
