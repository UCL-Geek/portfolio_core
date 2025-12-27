defmodule PortfolioCore.Ports.DocumentStore do
  @moduledoc """
  Port specification for document storage backends.

  Provides storage for source documents before they are chunked and embedded.
  Supports content-addressable storage patterns.

  ## Features

  - Document CRUD operations
  - Metadata search
  - Content hashing for deduplication
  - Version tracking

  ## Example Implementation

      defmodule MyApp.Adapters.PostgresDocStore do
        @behaviour PortfolioCore.Ports.DocumentStore

        @impl true
        def store(store_id, doc_id, content, metadata) do
          # Implementation
        end
      end
  """

  @type store_id :: String.t()
  @type doc_id :: String.t()
  @type content :: String.t() | binary()
  @type metadata :: map()

  @type document :: %{
          id: doc_id(),
          content: content(),
          metadata: metadata(),
          created_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  @doc """
  Store a document.

  ## Parameters

    - `store_id` - The document store namespace
    - `doc_id` - Unique document identifier
    - `content` - Document content (text or binary)
    - `metadata` - Associated metadata

  ## Returns

    - `{:ok, document}` with stored document
    - `{:error, reason}` on failure
  """
  @callback store(store_id(), doc_id(), content(), metadata()) ::
              {:ok, document()} | {:error, term()}

  @doc """
  Get a document by ID.

  ## Parameters

    - `store_id` - The document store namespace
    - `doc_id` - The document ID to retrieve

  ## Returns

    - `{:ok, document}` if found
    - `{:error, :not_found}` if not found
    - `{:error, reason}` on other failures
  """
  @callback get(store_id(), doc_id()) ::
              {:ok, document()} | {:error, :not_found | term()}

  @doc """
  Delete a document.

  ## Parameters

    - `store_id` - The document store namespace
    - `doc_id` - The document ID to delete

  ## Returns

    - `:ok` on success
    - `{:error, reason}` on failure
  """
  @callback delete(store_id(), doc_id()) ::
              :ok | {:error, term()}

  @doc """
  List documents with optional filtering.

  ## Parameters

    - `store_id` - The document store namespace
    - `opts` - List options:
      - `:limit` - Maximum documents to return
      - `:offset` - Skip first N documents
      - `:order_by` - Sort field
      - `:order_dir` - `:asc` or `:desc`

  ## Returns

    - `{:ok, documents}` - List of documents
    - `{:error, reason}` on failure
  """
  @callback list(store_id(), opts :: keyword()) ::
              {:ok, [document()]} | {:error, term()}

  @doc """
  Search documents by metadata.

  ## Parameters

    - `store_id` - The document store namespace
    - `query` - Metadata query (key-value pairs to match)

  ## Returns

    - `{:ok, documents}` - List of matching documents
    - `{:error, reason}` on failure
  """
  @callback search_metadata(store_id(), query :: map()) ::
              {:ok, [document()]} | {:error, term()}
end
