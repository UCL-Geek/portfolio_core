defmodule PortfolioCore.Ports.Cache do
  @moduledoc """
  Behavior for caching implementations (ETS, Redis, Mnesia).

  Provides a unified interface for caching results, embeddings, and
  intermediate pipeline outputs across different backends.

  ## Features

  - TTL-based expiration
  - Namespace isolation
  - Batch operations
  - Statistics tracking

  ## Example Implementation

      defmodule MyApp.Cache.ETS do
        @behaviour PortfolioCore.Ports.Cache

        @impl true
        def get(key, opts) do
          namespace = Keyword.get(opts, :namespace, :default)
          case :ets.lookup(table_name(namespace), key) do
            [{^key, value}] -> {:ok, value}
            [] -> {:error, :not_found}
          end
        end
      end
  """

  @type key :: term()
  @type value :: term()
  @type ttl :: pos_integer() | :infinity
  @type namespace :: String.t() | atom()

  @type stats :: %{
          hits: non_neg_integer(),
          misses: non_neg_integer(),
          size: non_neg_integer(),
          memory_bytes: non_neg_integer()
        }

  @type cache_opts :: [
          namespace: namespace(),
          ttl: ttl(),
          compress: boolean()
        ]

  @doc """
  Retrieve a value by key.
  """
  @callback get(key(), opts :: cache_opts()) ::
              {:ok, value()} | {:error, :not_found | term()}

  @doc """
  Store a value with optional TTL.
  """
  @callback put(key(), value(), opts :: cache_opts()) ::
              :ok | {:error, term()}

  @doc """
  Delete a key.
  """
  @callback delete(key(), opts :: cache_opts()) :: :ok

  @doc """
  Check if key exists in the cache.
  """
  @callback exists?(key(), opts :: cache_opts()) :: boolean()

  @doc """
  Get multiple keys at once.
  """
  @callback get_many([key()], opts :: cache_opts()) :: %{key() => value()}

  @doc """
  Store multiple key-value pairs.
  """
  @callback put_many([{key(), value()}], opts :: cache_opts()) ::
              :ok | {:error, term()}

  @doc """
  Clear all keys in the namespace.
  """
  @callback clear(opts :: cache_opts()) :: :ok

  @doc """
  Return cache statistics.
  """
  @callback stats(opts :: cache_opts()) :: stats()

  @doc """
  Update the TTL for a key without changing its value.
  """
  @callback touch(key(), ttl(), opts :: cache_opts()) ::
              :ok | {:error, :not_found}
end
