defmodule PortfolioCore.Ports.ChunkerTest do
  use ExUnit.Case, async: true

  alias PortfolioCore.Ports.Chunker

  describe "behaviour definition" do
    test "defines chunk/3 callback" do
      callbacks = Chunker.behaviour_info(:callbacks)
      assert {:chunk, 3} in callbacks
    end

    test "defines estimate_chunks/2 callback" do
      callbacks = Chunker.behaviour_info(:callbacks)
      assert {:estimate_chunks, 2} in callbacks
    end

    test "defines supported_strategies/0 as optional callback" do
      optional = Chunker.behaviour_info(:optional_callbacks)
      assert {:supported_strategies, 0} in optional
    end
  end

  describe "mock implementation" do
    defmodule MockChunker do
      @behaviour PortfolioCore.Ports.Chunker

      @impl true
      def chunk(text, _format, config) do
        # Get effective chunk size based on size_unit
        chunk_size = effective_chunk_size(config)

        # Simple character-based chunking for test
        chunks =
          text
          |> String.codepoints()
          |> Enum.chunk_every(chunk_size)
          |> Enum.with_index()
          |> Enum.map(fn {chars, index} ->
            content = Enum.join(chars)

            %{
              content: content,
              index: index,
              start_byte: index * chunk_size,
              end_byte: index * chunk_size + byte_size(content),
              start_offset: index * chunk_size,
              end_offset: index * chunk_size + String.length(content),
              metadata: %{
                size_unit: Map.get(config, :size_unit, :characters)
              }
            }
          end)

        {:ok, chunks}
      end

      @impl true
      def estimate_chunks(text, config) do
        chunk_size = effective_chunk_size(config)
        div(String.length(text), chunk_size) + 1
      end

      @impl true
      def supported_strategies do
        [:character, :sentence, :paragraph]
      end

      # Convert token-based size to character-based (4 chars per token heuristic)
      defp effective_chunk_size(%{size_unit: :tokens, chunk_size: size}), do: size * 4
      defp effective_chunk_size(%{chunk_size: size}), do: size
    end

    test "mock implementation satisfies behaviour" do
      config = %{chunk_size: 10, chunk_overlap: 2, separators: nil}
      {:ok, chunks} = MockChunker.chunk("Hello world, this is a test", :plain, config)

      assert is_list(chunks)
      assert chunks != []

      first_chunk = hd(chunks)
      assert Map.has_key?(first_chunk, :content)
      assert Map.has_key?(first_chunk, :index)
      assert Map.has_key?(first_chunk, :start_byte)
      assert Map.has_key?(first_chunk, :end_byte)
      assert Map.has_key?(first_chunk, :start_offset)
      assert Map.has_key?(first_chunk, :end_offset)
      assert Map.has_key?(first_chunk, :metadata)
    end

    test "supported_strategies returns list of atoms" do
      strategies = MockChunker.supported_strategies()
      assert is_list(strategies)
      assert Enum.all?(strategies, &is_atom/1)
    end
  end

  describe "size_unit configuration" do
    defmodule SizeUnitChunker do
      @behaviour PortfolioCore.Ports.Chunker

      @impl true
      def chunk(text, _format, config) do
        size_unit = Map.get(config, :size_unit, :characters)
        chunk_size = config.chunk_size

        # Calculate effective size based on unit
        effective_size =
          case size_unit do
            :tokens -> chunk_size * 4
            :characters -> chunk_size
            nil -> chunk_size
          end

        chunks =
          text
          |> String.codepoints()
          |> Enum.chunk_every(effective_size)
          |> Enum.with_index()
          |> Enum.map(fn {chars, index} ->
            content = Enum.join(chars)

            %{
              content: content,
              index: index,
              start_byte: 0,
              end_byte: byte_size(content),
              start_offset: 0,
              end_offset: String.length(content),
              metadata: %{size_unit: size_unit, effective_size: effective_size}
            }
          end)

        {:ok, chunks}
      end

      @impl true
      def estimate_chunks(text, config) do
        size_unit = Map.get(config, :size_unit, :characters)
        chunk_size = config.chunk_size

        effective_size =
          case size_unit do
            :tokens -> chunk_size * 4
            :characters -> chunk_size
            nil -> chunk_size
          end

        div(String.length(text), effective_size) + 1
      end
    end

    test "config with size_unit: :characters uses character-based sizing" do
      config = %{chunk_size: 10, chunk_overlap: 0, size_unit: :characters, separators: nil}
      {:ok, chunks} = SizeUnitChunker.chunk("12345678901234567890", :plain, config)

      # 20 chars / 10 = 2 chunks
      assert length(chunks) == 2
      assert hd(chunks).metadata.size_unit == :characters
      assert hd(chunks).metadata.effective_size == 10
    end

    test "config with size_unit: :tokens converts to character-based sizing" do
      config = %{chunk_size: 5, chunk_overlap: 0, size_unit: :tokens, separators: nil}
      {:ok, chunks} = SizeUnitChunker.chunk("12345678901234567890", :plain, config)

      # 5 tokens * 4 chars/token = 20 chars effective size
      # 20 chars / 20 = 1 chunk
      assert length(chunks) == 1
      assert hd(chunks).metadata.size_unit == :tokens
      assert hd(chunks).metadata.effective_size == 20
    end

    test "config with size_unit: nil defaults to character-based sizing" do
      config = %{chunk_size: 10, chunk_overlap: 0, size_unit: nil, separators: nil}
      {:ok, chunks} = SizeUnitChunker.chunk("12345678901234567890", :plain, config)

      # 20 chars / 10 = 2 chunks
      assert length(chunks) == 2
      assert hd(chunks).metadata.size_unit == nil
      assert hd(chunks).metadata.effective_size == 10
    end

    test "config without size_unit defaults to character-based sizing" do
      config = %{chunk_size: 10, chunk_overlap: 0, separators: nil}
      {:ok, chunks} = SizeUnitChunker.chunk("12345678901234567890", :plain, config)

      # 20 chars / 10 = 2 chunks
      assert length(chunks) == 2
      assert hd(chunks).metadata.size_unit == :characters
    end

    test "estimate_chunks respects size_unit: :tokens" do
      config = %{chunk_size: 5, chunk_overlap: 0, size_unit: :tokens, separators: nil}
      # 40 chars / (5 tokens * 4) = 40 / 20 = 2 chunks + 1 = 3
      estimate = SizeUnitChunker.estimate_chunks(String.duplicate("a", 40), config)

      assert estimate == 3
    end

    test "estimate_chunks respects size_unit: :characters" do
      config = %{chunk_size: 10, chunk_overlap: 0, size_unit: :characters, separators: nil}
      # 40 chars / 10 = 4 chunks + 1 = 5
      estimate = SizeUnitChunker.estimate_chunks(String.duplicate("a", 40), config)

      assert estimate == 5
    end
  end

  describe "chunk_config type compliance" do
    alias PortfolioCore.Ports.ChunkerTest.SizeUnitChunker

    test "full config with all fields is valid" do
      config = %{
        chunk_size: 1000,
        chunk_overlap: 200,
        size_unit: :tokens,
        separators: ["\n\n", "\n", " "]
      }

      # This should work without error - demonstrates type compliance
      {:ok, _chunks} = SizeUnitChunker.chunk("test", :plain, config)
    end

    test "config with optional fields as nil is valid" do
      config = %{
        chunk_size: 500,
        chunk_overlap: 50,
        size_unit: nil,
        separators: nil
      }

      {:ok, _chunks} = SizeUnitChunker.chunk("test", :plain, config)
    end
  end
end
