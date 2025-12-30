defmodule PortfolioCore.Ports.Chunker do
  @moduledoc """
  Port specification for document chunking strategies.

  Chunking splits documents into smaller pieces suitable for embedding
  and retrieval. Different strategies work better for different content types.

  ## Chunking Strategies

  - `:plain` - Simple character/word splitting
  - `:markdown` - Markdown-aware splitting (respects headers, code blocks)
  - `:code` - Code-aware splitting (respects functions, classes)
  - `:html` - HTML-aware splitting (respects tags, structure)

  ## Example Implementation

      defmodule MyApp.Adapters.RecursiveChunker do
        @behaviour PortfolioCore.Ports.Chunker

        @impl true
        def chunk(text, format, config) do
          # Split text into chunks using recursive strategy
        end
      end

  ## Chunk Overlap

  Overlap between chunks helps maintain context at boundaries.
  A typical configuration might use:
  - `chunk_size: 1000` (characters or tokens)
  - `chunk_overlap: 200` (20% overlap)

  ## Size Units

  The `size_unit` option specifies how `chunk_size` and `chunk_overlap` are measured:
  - `:characters` - Size in characters (default, uses `String.length/1`)
  - `:tokens` - Size in tokens (adapter provides token estimation)

  Token-based sizing is useful for LLM context window budgeting.
  """

  @type text :: String.t()
  @type format :: :plain | :markdown | :code | :html

  @type strategy ::
          :character
          | :sentence
          | :paragraph
          | :recursive
          | :semantic
          | :format_aware

  @type chunk :: %{
          content: String.t(),
          index: non_neg_integer(),
          start_byte: non_neg_integer(),
          end_byte: non_neg_integer(),
          start_offset: non_neg_integer(),
          end_offset: non_neg_integer(),
          metadata: map()
        }

  @type size_unit :: :characters | :tokens

  @type chunk_config :: %{
          chunk_size: pos_integer(),
          chunk_overlap: non_neg_integer(),
          size_unit: size_unit() | nil,
          separators: [String.t()] | nil
        }

  @doc """
  Split text into chunks.

  ## Parameters

    - `text` - The text to chunk
    - `format` - Content format hint for smarter splitting
    - `config` - Chunking configuration:
      - `:chunk_size` - Target size for each chunk
      - `:chunk_overlap` - Overlap between adjacent chunks
      - `:size_unit` - Unit for sizes: `:characters` or `:tokens` (optional)
      - `:separators` - Custom separators (optional)

  ## Returns

    - `{:ok, chunks}` - List of chunks with metadata
    - `{:error, reason}` on failure
  """
  @callback chunk(text(), format(), chunk_config()) ::
              {:ok, [chunk()]} | {:error, term()}

  @doc """
  Estimate the number of chunks without actually chunking.

  Useful for progress reporting and resource estimation.

  ## Parameters

    - `text` - The text to estimate
    - `config` - Chunking configuration

  ## Returns

    - Estimated number of chunks
  """
  @callback estimate_chunks(text(), chunk_config()) ::
              non_neg_integer()

  @doc """
  Get list of chunking strategies supported by this adapter.

  ## Returns

    - List of supported strategy atoms
  """
  @callback supported_strategies() :: [strategy()]

  @optional_callbacks [supported_strategies: 0]
end
