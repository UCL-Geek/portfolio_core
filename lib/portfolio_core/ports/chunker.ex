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
  """

  @type text :: String.t()
  @type format :: :plain | :markdown | :code | :html

  @type chunk :: %{
          content: String.t(),
          index: non_neg_integer(),
          start_offset: non_neg_integer(),
          end_offset: non_neg_integer(),
          metadata: map()
        }

  @type chunk_config :: %{
          chunk_size: pos_integer(),
          chunk_overlap: non_neg_integer(),
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
end
