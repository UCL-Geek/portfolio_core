# Example: Implementing the Cache port
# Run: mix run examples/cache_port.exs

defmodule Examples.InMemoryCache do
  @moduledoc """
  Simple in-memory cache implementation for demonstration.
  """

  @behaviour PortfolioCore.Ports.Cache

  use Agent

  def start_link(_opts) do
    Agent.start_link(fn -> %{entries: %{}, hits: 0, misses: 0} end, name: __MODULE__)
  end

  @impl true
  def get(key, opts) do
    namespace = namespace(opts)

    Agent.get_and_update(__MODULE__, fn state ->
      case Map.get(state.entries, {namespace, key}) do
        nil ->
          {{:error, :not_found}, %{state | misses: state.misses + 1}}

        {value, expires_at} ->
          if expired?(expires_at) do
            new_entries = Map.delete(state.entries, {namespace, key})
            {{:error, :not_found}, %{state | entries: new_entries, misses: state.misses + 1}}
          else
            {{:ok, value}, %{state | hits: state.hits + 1}}
          end
      end
    end)
  end

  @impl true
  def put(key, value, opts) do
    namespace = namespace(opts)
    expires_at = expires_at(opts)

    Agent.update(__MODULE__, fn state ->
      %{state | entries: Map.put(state.entries, {namespace, key}, {value, expires_at})}
    end)

    :ok
  end

  @impl true
  def delete(key, opts) do
    namespace = namespace(opts)

    Agent.update(__MODULE__, fn state ->
      %{state | entries: Map.delete(state.entries, {namespace, key})}
    end)

    :ok
  end

  @impl true
  def exists?(key, opts) do
    namespace = namespace(opts)

    Agent.get_and_update(__MODULE__, fn state ->
      case Map.get(state.entries, {namespace, key}) do
        nil ->
          {false, state}

        {_value, expires_at} ->
          if expired?(expires_at) do
            new_entries = Map.delete(state.entries, {namespace, key})
            {false, %{state | entries: new_entries}}
          else
            {true, state}
          end
      end
    end)
  end

  @impl true
  def get_many(keys, opts) do
    Enum.reduce(keys, %{}, fn key, acc ->
      case get(key, opts) do
        {:ok, value} -> Map.put(acc, key, value)
        {:error, :not_found} -> acc
        {:error, _} -> acc
      end
    end)
  end

  @impl true
  def put_many(pairs, opts) do
    Enum.each(pairs, fn {key, value} ->
      put(key, value, opts)
    end)

    :ok
  end

  @impl true
  def clear(opts) do
    namespace = namespace(opts)

    Agent.update(__MODULE__, fn state ->
      new_entries =
        state.entries
        |> Enum.reject(fn {{ns, _key}, _value} -> ns == namespace end)
        |> Map.new()

      %{state | entries: new_entries}
    end)

    :ok
  end

  @impl true
  def stats(_opts) do
    Agent.get(__MODULE__, fn state ->
      %{
        hits: state.hits,
        misses: state.misses,
        size: map_size(state.entries),
        memory_bytes: :erlang.external_size(state.entries)
      }
    end)
  end

  @impl true
  def touch(key, ttl, opts) do
    namespace = namespace(opts)

    Agent.get_and_update(__MODULE__, fn state ->
      case Map.get(state.entries, {namespace, key}) do
        nil ->
          {{:error, :not_found}, state}

        {value, current_expires_at} ->
          if expired?(current_expires_at) do
            new_entries = Map.delete(state.entries, {namespace, key})
            {{:error, :not_found}, %{state | entries: new_entries}}
          else
            new_entries =
              Map.put(state.entries, {namespace, key}, {value, expires_at(opts, ttl)})

            {:ok, %{state | entries: new_entries}}
          end
      end
    end)
  end

  defp namespace(opts), do: Keyword.get(opts, :namespace, :default)

  defp expires_at(opts, ttl_override \\ nil) do
    ttl = ttl_override || Keyword.get(opts, :ttl, :infinity)

    case ttl do
      :infinity -> :infinity
      seconds -> now_seconds() + seconds
    end
  end

  defp expired?(:infinity), do: false
  defp expired?(expires_at), do: expires_at <= now_seconds()

  defp now_seconds do
    System.system_time(:second)
  end
end

IO.puts("=" |> String.duplicate(60))
IO.puts("Portfolio Core - Cache Port Example")
IO.puts("=" |> String.duplicate(60))

{:ok, _} = Examples.InMemoryCache.start_link([])

IO.puts("\n1. Storing values...")
:ok = Examples.InMemoryCache.put("greeting", "hello", ttl: 60)
:ok = Examples.InMemoryCache.put("farewell", "goodbye", ttl: 60)

IO.puts("\n2. Fetching values...")
{:ok, value} = Examples.InMemoryCache.get("greeting", [])
IO.puts("   greeting: #{value}")

IO.puts("\n3. Fetching multiple values...")
values = Examples.InMemoryCache.get_many(["greeting", "farewell", "missing"], [])
IO.inspect(values, label: "   values")

IO.puts("\n4. Cache stats...")
stats = Examples.InMemoryCache.stats([])
IO.inspect(stats, label: "   stats")

IO.puts("\n" <> String.duplicate("=", 60))
IO.puts("Example completed successfully!")
IO.puts(String.duplicate("=", 60))
