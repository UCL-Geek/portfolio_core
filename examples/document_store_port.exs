# Example: Document Store port (in-memory adapter)
# Run: mix run examples/document_store_port.exs

defmodule Examples.InMemoryDocumentStore do
  @moduledoc false
  @behaviour PortfolioCore.Ports.DocumentStore

  use Agent

  def start_link(_opts) do
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end

  @impl true
  def store(store_id, doc_id, content, metadata) do
    now = DateTime.utc_now()

    doc = %{
      id: doc_id,
      content: content,
      metadata: metadata,
      created_at: now,
      updated_at: now
    }

    Agent.update(__MODULE__, fn state ->
      update_in(state, [store_id], fn store ->
        Map.put(store || %{}, doc_id, doc)
      end)
    end)

    {:ok, doc}
  end

  @impl true
  def get(store_id, doc_id) do
    Agent.get(__MODULE__, fn state ->
      case get_in(state, [store_id, doc_id]) do
        nil -> {:error, :not_found}
        doc -> {:ok, doc}
      end
    end)
  end

  @impl true
  def delete(store_id, doc_id) do
    Agent.update(__MODULE__, fn state ->
      update_in(state, [store_id], fn store ->
        Map.delete(store || %{}, doc_id)
      end)
    end)

    :ok
  end

  @impl true
  def list(store_id, opts) do
    limit = Keyword.get(opts, :limit)
    offset = Keyword.get(opts, :offset, 0)
    order_by = Keyword.get(opts, :order_by, :created_at)
    order_dir = Keyword.get(opts, :order_dir, :asc)

    docs =
      Agent.get(__MODULE__, fn state ->
        state
        |> Map.get(store_id, %{})
        |> Map.values()
      end)
      |> Enum.sort_by(&Map.get(&1, order_by), order_dir)
      |> Enum.drop(offset)

    docs = if limit, do: Enum.take(docs, limit), else: docs
    {:ok, docs}
  end

  @impl true
  def search_metadata(store_id, query) do
    docs =
      Agent.get(__MODULE__, fn state ->
        state
        |> Map.get(store_id, %{})
        |> Map.values()
      end)

    matches = Enum.filter(docs, &matches_metadata?(&1.metadata, query))
    {:ok, matches}
  end

  defp matches_metadata?(metadata, query) do
    Enum.all?(query, fn {key, value} ->
      Map.get(metadata, key) == value
    end)
  end
end

IO.puts(String.duplicate("=", 60))
IO.puts("Portfolio Core - Document Store Example")
IO.puts(String.duplicate("=", 60))

{:ok, _} = Examples.InMemoryDocumentStore.start_link([])

store_id = "docs"

{:ok, doc1} =
  Examples.InMemoryDocumentStore.store(store_id, "doc-1", "Elixir is fun.", %{type: :note})

{:ok, doc2} =
  Examples.InMemoryDocumentStore.store(store_id, "doc-2", "Ollama runs locally.", %{type: :note})

IO.puts("\nStored documents:")
IO.inspect([doc1.id, doc2.id])

{:ok, listed} = Examples.InMemoryDocumentStore.list(store_id, order_dir: :desc)
IO.puts("\nList documents (desc):")
IO.inspect(Enum.map(listed, & &1.id))

{:ok, matches} = Examples.InMemoryDocumentStore.search_metadata(store_id, %{type: :note})
IO.puts("\nMetadata search (type: :note):")
IO.inspect(Enum.map(matches, & &1.id))

{:ok, fetched} = Examples.InMemoryDocumentStore.get(store_id, "doc-1")
IO.puts("\nFetched doc-1:")
IO.inspect(%{id: fetched.id, content: fetched.content})

:ok = Examples.InMemoryDocumentStore.delete(store_id, "doc-2")
{:ok, remaining} = Examples.InMemoryDocumentStore.list(store_id, [])
IO.puts("\nAfter deletion:")
IO.inspect(Enum.map(remaining, & &1.id))

IO.puts("\n" <> String.duplicate("=", 60))
IO.puts("Example completed successfully!")
IO.puts(String.duplicate("=", 60))
