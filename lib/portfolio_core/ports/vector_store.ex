defmodule PortfolioCore.Ports.VectorStore do
  @moduledoc """
  Port specification for vector storage backends.

  Implementations must handle:
  - Index creation and management
  - Vector storage with metadata
  - Similarity search (k-NN, ANN)
  - Batch operations

  ## Example Implementation

      defmodule MyApp.Adapters.Pgvector do
        @behaviour PortfolioCore.Ports.VectorStore

        @impl true
        def store(index_id, id, vector, metadata) do
          # Implementation
        end
      end

  ## Supported Distance Metrics

  - `:cosine` - Cosine similarity (default)
  - `:euclidean` - Euclidean distance (L2)
  - `:dot_product` - Dot product similarity

  ## Index Types

  Different backends may support different index types for ANN search:
  - IVF (Inverted File Index)
  - HNSW (Hierarchical Navigable Small World)
  - Flat (exact search)
  """

  @type index_id :: String.t()
  @type vector_id :: String.t()
  @type vector :: [float()]
  @type metadata :: map()
  @type dimensions :: pos_integer()
  @type distance_metric :: :cosine | :euclidean | :dot_product

  @type search_result :: %{
          id: vector_id(),
          score: float(),
          metadata: metadata(),
          vector: vector() | nil
        }

  @type index_config :: %{
          dimensions: dimensions(),
          metric: distance_metric(),
          index_type: atom(),
          options: map()
        }

  @type index_stats :: %{
          count: non_neg_integer(),
          dimensions: dimensions(),
          metric: distance_metric(),
          size_bytes: non_neg_integer() | nil
        }

  @doc """
  Create a new vector index with the given configuration.

  ## Parameters

    - `index_id` - Unique identifier for the index
    - `config` - Index configuration including dimensions, metric, and options

  ## Returns

    - `:ok` on success
    - `{:error, reason}` on failure
  """
  @callback create_index(index_id(), index_config()) ::
              :ok | {:error, term()}

  @doc """
  Delete an index and all its vectors.

  ## Parameters

    - `index_id` - The index to delete

  ## Returns

    - `:ok` on success
    - `{:error, :not_found}` if index doesn't exist
    - `{:error, reason}` on other failures
  """
  @callback delete_index(index_id()) ::
              :ok | {:error, :not_found | term()}

  @doc """
  Store a vector with associated metadata.

  ## Parameters

    - `index_id` - The target index
    - `id` - Unique identifier for this vector
    - `vector` - The embedding vector
    - `metadata` - Associated metadata (e.g., source, chunk_id)

  ## Returns

    - `:ok` on success
    - `{:error, reason}` on failure
  """
  @callback store(index_id(), vector_id(), vector(), metadata()) ::
              :ok | {:error, term()}

  @doc """
  Store multiple vectors in a batch operation.

  More efficient than individual store calls for bulk ingestion.

  ## Parameters

    - `index_id` - The target index
    - `items` - List of `{id, vector, metadata}` tuples

  ## Returns

    - `{:ok, count}` with number of vectors stored
    - `{:error, reason}` on failure
  """
  @callback store_batch(index_id(), [{vector_id(), vector(), metadata()}]) ::
              {:ok, non_neg_integer()} | {:error, term()}

  @doc """
  Search for similar vectors.

  ## Parameters

    - `index_id` - The index to search
    - `vector` - Query vector
    - `k` - Number of results to return
    - `opts` - Search options:
      - `:filter` - Metadata filter
      - `:min_score` - Minimum similarity score
      - `:include_vectors` - Whether to include vectors in results

  ## Returns

    - `{:ok, results}` - List of search results sorted by score
    - `{:error, reason}` on failure
  """
  @callback search(index_id(), vector(), k :: pos_integer(), opts :: keyword()) ::
              {:ok, [search_result()]} | {:error, term()}

  @doc """
  Delete a vector by ID.

  ## Parameters

    - `index_id` - The index containing the vector
    - `id` - The vector ID to delete

  ## Returns

    - `:ok` on success
    - `{:error, :not_found}` if vector doesn't exist
    - `{:error, reason}` on other failures
  """
  @callback delete(index_id(), vector_id()) ::
              :ok | {:error, :not_found | term()}

  @doc """
  Get index statistics.

  ## Parameters

    - `index_id` - The index to query

  ## Returns

    - `{:ok, stats}` with index statistics
    - `{:error, :not_found}` if index doesn't exist
    - `{:error, reason}` on other failures
  """
  @callback index_stats(index_id()) ::
              {:ok, index_stats()} | {:error, :not_found | term()}

  @doc """
  Check if an index exists.

  ## Parameters

    - `index_id` - The index to check

  ## Returns

    - `true` if index exists
    - `false` otherwise
  """
  @callback index_exists?(index_id()) :: boolean()

  @optional_callbacks [index_exists?: 1]
end
