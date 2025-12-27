# Custom Adapter Example
# Run: mix run examples/custom_adapter.exs

# This example shows how to create a full-featured custom adapter
# that implements a PortfolioCore port specification.

defmodule Examples.LoggingVectorStore do
  @moduledoc """
  A vector store adapter that wraps another adapter and logs all operations.
  Demonstrates the decorator pattern with port adapters.
  """

  @behaviour PortfolioCore.Ports.VectorStore

  use GenServer

  # Client API

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: opts[:name] || __MODULE__)
  end

  # Port Implementation

  @impl PortfolioCore.Ports.VectorStore
  def create_index(index_id, config) do
    log(:create_index, index_id: index_id, config: config)
    GenServer.call(__MODULE__, {:create_index, index_id, config})
  end

  @impl PortfolioCore.Ports.VectorStore
  def delete_index(index_id) do
    log(:delete_index, index_id: index_id)
    GenServer.call(__MODULE__, {:delete_index, index_id})
  end

  @impl PortfolioCore.Ports.VectorStore
  def store(index_id, id, vector, metadata) do
    log(:store, index_id: index_id, id: id, vector_dim: length(vector))
    GenServer.call(__MODULE__, {:store, index_id, id, vector, metadata})
  end

  @impl PortfolioCore.Ports.VectorStore
  def store_batch(index_id, items) do
    log(:store_batch, index_id: index_id, count: length(items))
    GenServer.call(__MODULE__, {:store_batch, index_id, items})
  end

  @impl PortfolioCore.Ports.VectorStore
  def search(index_id, vector, k, opts) do
    log(:search, index_id: index_id, k: k, opts: opts)
    result = GenServer.call(__MODULE__, {:search, index_id, vector, k, opts})
    log(:search_complete, result_count: length(elem(result, 1)))
    result
  end

  @impl PortfolioCore.Ports.VectorStore
  def delete(index_id, id) do
    log(:delete, index_id: index_id, id: id)
    GenServer.call(__MODULE__, {:delete, index_id, id})
  end

  @impl PortfolioCore.Ports.VectorStore
  def index_stats(index_id) do
    log(:index_stats, index_id: index_id)
    GenServer.call(__MODULE__, {:index_stats, index_id})
  end

  @impl PortfolioCore.Ports.VectorStore
  def index_exists?(index_id) do
    GenServer.call(__MODULE__, {:index_exists?, index_id})
  end

  # GenServer Implementation

  @impl GenServer
  def init(_opts) do
    {:ok, %{indexes: %{}, operation_count: 0}}
  end

  @impl GenServer
  def handle_call({:create_index, index_id, config}, _from, state) do
    new_indexes = Map.put(state.indexes, index_id, %{config: config, vectors: %{}})
    {:reply, :ok, %{state | indexes: new_indexes, operation_count: state.operation_count + 1}}
  end

  @impl GenServer
  def handle_call({:delete_index, index_id}, _from, state) do
    new_indexes = Map.delete(state.indexes, index_id)
    {:reply, :ok, %{state | indexes: new_indexes, operation_count: state.operation_count + 1}}
  end

  @impl GenServer
  def handle_call({:store, index_id, id, vector, metadata}, _from, state) do
    new_state =
      update_in(state, [:indexes, index_id, :vectors], fn vectors ->
        Map.put(vectors || %{}, id, %{vector: vector, metadata: metadata})
      end)

    {:reply, :ok, %{new_state | operation_count: state.operation_count + 1}}
  end

  @impl GenServer
  def handle_call({:store_batch, index_id, items}, _from, state) do
    new_state =
      Enum.reduce(items, state, fn {id, vector, metadata}, acc ->
        update_in(acc, [:indexes, index_id, :vectors], fn vectors ->
          Map.put(vectors || %{}, id, %{vector: vector, metadata: metadata})
        end)
      end)

    {:reply, {:ok, length(items)}, %{new_state | operation_count: state.operation_count + 1}}
  end

  @impl GenServer
  def handle_call({:search, index_id, query_vector, k, _opts}, _from, state) do
    vectors = get_in(state, [:indexes, index_id, :vectors]) || %{}

    results =
      vectors
      |> Enum.map(fn {id, %{vector: vec, metadata: meta}} ->
        %{id: id, score: cosine_similarity(query_vector, vec), metadata: meta, vector: nil}
      end)
      |> Enum.sort_by(& &1.score, :desc)
      |> Enum.take(k)

    {:reply, {:ok, results}, %{state | operation_count: state.operation_count + 1}}
  end

  @impl GenServer
  def handle_call({:delete, index_id, id}, _from, state) do
    new_state =
      update_in(state, [:indexes, index_id, :vectors], fn vectors ->
        Map.delete(vectors || %{}, id)
      end)

    {:reply, :ok, %{new_state | operation_count: state.operation_count + 1}}
  end

  @impl GenServer
  def handle_call({:index_stats, index_id}, _from, state) do
    case get_in(state, [:indexes, index_id]) do
      nil ->
        {:reply, {:error, :not_found}, state}

      index ->
        stats = %{
          count: map_size(index.vectors || %{}),
          dimensions: index.config[:dimensions] || 0,
          metric: index.config[:metric] || :cosine,
          size_bytes: nil
        }

        {:reply, {:ok, stats}, %{state | operation_count: state.operation_count + 1}}
    end
  end

  @impl GenServer
  def handle_call({:index_exists?, index_id}, _from, state) do
    {:reply, Map.has_key?(state.indexes, index_id), state}
  end

  # Helpers

  defp log(operation, details) do
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601()
    details_str = Enum.map_join(details, ", ", fn {k, v} -> "#{k}=#{inspect(v)}" end)
    IO.puts("[#{timestamp}] VectorStore.#{operation}: #{details_str}")
  end

  defp cosine_similarity(a, b) do
    dot = Enum.zip(a, b) |> Enum.map(fn {x, y} -> x * y end) |> Enum.sum()
    mag_a = :math.sqrt(Enum.map(a, &(&1 * &1)) |> Enum.sum())
    mag_b = :math.sqrt(Enum.map(b, &(&1 * &1)) |> Enum.sum())

    if mag_a == 0 or mag_b == 0, do: 0.0, else: dot / (mag_a * mag_b)
  end
end

# Run the example
IO.puts("=" |> String.duplicate(60))
IO.puts("Portfolio Core - Custom Adapter Example")
IO.puts("=" |> String.duplicate(60))

IO.puts("\nThis example demonstrates a logging vector store adapter")
IO.puts("that logs all operations for debugging/auditing purposes.\n")

# Start the adapter
{:ok, _pid} = Examples.LoggingVectorStore.start_link([])

# Register with the registry
PortfolioCore.Registry.register(:vector_store, {Examples.LoggingVectorStore, []})

IO.puts("\n--- Creating index ---")

Examples.LoggingVectorStore.create_index("products", %{
  dimensions: 128,
  metric: :cosine,
  index_type: :hnsw,
  options: %{m: 16, ef_construction: 200}
})

IO.puts("\n--- Storing vectors ---")

# Simulate product embeddings
products = [
  {"prod_1", List.duplicate(0.1, 128), %{name: "Laptop", category: "Electronics"}},
  {"prod_2", List.duplicate(0.2, 128), %{name: "Headphones", category: "Electronics"}},
  {"prod_3", List.duplicate(0.15, 128), %{name: "Mouse", category: "Electronics"}},
  {"prod_4", List.duplicate(0.5, 128), %{name: "Book", category: "Books"}},
  {"prod_5", List.duplicate(0.55, 128), %{name: "Magazine", category: "Books"}}
]

{:ok, count} = Examples.LoggingVectorStore.store_batch("products", products)
IO.puts("\n   Stored #{count} products")

IO.puts("\n--- Searching ---")

query_vector = List.duplicate(0.12, 128)
{:ok, results} = Examples.LoggingVectorStore.search("products", query_vector, 3, [])

IO.puts("\n   Top 3 results:")

Enum.each(results, fn %{id: id, score: score, metadata: meta} ->
  IO.puts("     #{id}: #{meta[:name]} (#{meta[:category]}) - score: #{Float.round(score, 4)}")
end)

IO.puts("\n--- Getting stats ---")

{:ok, stats} = Examples.LoggingVectorStore.index_stats("products")
IO.puts("\n   Index has #{stats.count} vectors")

IO.puts("\n" <> String.duplicate("=", 60))
IO.puts("Example completed successfully!")
IO.puts(String.duplicate("=", 60))
