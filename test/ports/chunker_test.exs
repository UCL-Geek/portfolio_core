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
        chunk_size = config.chunk_size
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
              metadata: %{}
            }
          end)

        {:ok, chunks}
      end

      @impl true
      def estimate_chunks(text, config) do
        div(String.length(text), config.chunk_size) + 1
      end

      @impl true
      def supported_strategies do
        [:character, :sentence, :paragraph]
      end
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
end
