defmodule PortfolioCore.Ports.Embedder do
  @moduledoc """
  Port specification for embedding generation backends.

  Provides text-to-vector embedding generation using various models
  (OpenAI, Gemini, local models, etc.).

  ## Features

  - Single and batch embedding generation
  - Multiple model support
  - Token counting
  - Dimension information

  ## Example Implementation

      defmodule MyApp.Adapters.OpenAIEmbedder do
        @behaviour PortfolioCore.Ports.Embedder

        @impl true
        def embed(text, opts) do
          model = Keyword.get(opts, :model, "text-embedding-3-small")
          # Call OpenAI API
        end
      end

  ## Supported Models (examples)

  - OpenAI: `text-embedding-3-small`, `text-embedding-3-large`
  - Google: `text-embedding-004`
  - Local: Ollama models, sentence-transformers
  """

  @type text :: String.t()
  @type vector :: [float()]
  @type model :: String.t()

  @type embedding_result :: %{
          vector: vector(),
          model: model(),
          dimensions: pos_integer(),
          token_count: non_neg_integer()
        }

  @type batch_result :: %{
          embeddings: [embedding_result()],
          total_tokens: non_neg_integer()
        }

  @doc """
  Generate an embedding for a single text.

  ## Parameters

    - `text` - The text to embed
    - `opts` - Embedding options:
      - `:model` - Model to use (backend-specific)
      - `:truncate` - Whether to truncate long texts

  ## Returns

    - `{:ok, result}` with embedding and metadata
    - `{:error, reason}` on failure
  """
  @callback embed(text(), opts :: keyword()) ::
              {:ok, embedding_result()} | {:error, term()}

  @doc """
  Generate embeddings for multiple texts in batch.

  More efficient than calling embed/2 multiple times.

  ## Parameters

    - `texts` - List of texts to embed
    - `opts` - Embedding options (same as embed/2)

  ## Returns

    - `{:ok, result}` with embeddings and total token count
    - `{:error, reason}` on failure
  """
  @callback embed_batch([text()], opts :: keyword()) ::
              {:ok, batch_result()} | {:error, term()}

  @doc """
  Get the output dimensions for a model.

  ## Parameters

    - `model` - The model identifier

  ## Returns

    - Number of dimensions for the model's output vectors
  """
  @callback dimensions(model()) :: pos_integer()

  @doc """
  Get list of supported models.

  ## Returns

    - List of model identifiers supported by this adapter
  """
  @callback supported_models() :: [model()]
end
