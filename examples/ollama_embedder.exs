# Example: Ollama Embedder adapter (PortfolioCore.Ports.Embedder)
# Run: mix run examples/ollama_embedder.exs

Code.require_file(Path.join(__DIR__, "support/ollama_client.exs"))

alias Examples.OllamaClient

defmodule Examples.OllamaEmbedder do
  @moduledoc false
  @behaviour PortfolioCore.Ports.Embedder

  @default_model "nomic-embed-text"
  @default_dimensions 768

  @impl true
  def embed(text, opts) do
    opts = normalize_opts(opts)
    model = pick_model(opts)

    with {:ok, embeddings} <- embed_inputs(model, [text], opts),
         vector when is_list(vector) <- List.first(embeddings) do
      {:ok,
       %{
         vector: vector,
         model: model,
         dimensions: length(vector),
         token_count: 0
       }}
    else
      {:error, reason} -> {:error, reason}
      _ -> {:error, :unexpected_embedding_response}
    end
  end

  @impl true
  def embed_batch(texts, opts) do
    opts = normalize_opts(opts)
    model = pick_model(opts)

    with {:ok, embeddings} <- embed_inputs(model, texts, opts) do
      {:ok,
       %{
         embeddings:
           Enum.map(embeddings, fn vector ->
             %{
               vector: vector,
               model: model,
               dimensions: length(vector),
               token_count: 0
             }
           end),
         total_tokens: 0
       }}
    end
  end

  @impl true
  def dimensions(_model) do
    case System.get_env("OLLAMA_EMBED_DIMENSIONS") do
      nil -> @default_dimensions
      value -> parse_integer(value, @default_dimensions)
    end
  end

  @impl true
  def supported_models, do: [System.get_env("OLLAMA_EMBED_MODEL") || @default_model]

  defp normalize_opts(opts) when is_map(opts), do: Map.to_list(opts)
  defp normalize_opts(opts) when is_list(opts), do: opts
  defp normalize_opts(_opts), do: []

  defp pick_model(opts) do
    Keyword.get(opts, :model) || System.get_env("OLLAMA_EMBED_MODEL") || @default_model
  end

  defp embed_inputs(model, inputs, opts) when is_list(inputs) do
    payload = %{model: model, input: inputs}

    case OllamaClient.request_json(:post, "embed", payload, opts) do
      {:ok, %{"embeddings" => embeddings}} when is_list(embeddings) ->
        {:ok, embeddings}

      {:ok, %{"embedding" => embedding}} when is_list(embedding) ->
        {:ok, [embedding]}

      {:error, {:http_error, 404, _body}} ->
        embed_inputs_legacy(model, inputs, opts)

      {:ok, other} ->
        {:error, {:unexpected_response, other}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp embed_inputs_legacy(model, inputs, opts) do
    inputs
    |> Enum.reduce_while({:ok, []}, fn input, {:ok, acc} ->
      payload = %{model: model, prompt: input}

      case OllamaClient.request_json(:post, "embeddings", payload, opts) do
        {:ok, %{"embedding" => embedding}} when is_list(embedding) ->
          {:cont, {:ok, [embedding | acc]}}

        {:ok, other} ->
          {:halt, {:error, {:unexpected_response, other}}}

        {:error, reason} ->
          {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, embeddings} -> {:ok, Enum.reverse(embeddings)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp parse_integer(value, fallback) when is_binary(value) do
    case Integer.parse(value) do
      {int, _rest} when int > 0 -> int
      _ -> fallback
    end
  end

  defp parse_integer(_, fallback), do: fallback
end

IO.puts(String.duplicate("=", 60))
IO.puts("Portfolio Core - Ollama Embedder Example")
IO.puts(String.duplicate("=", 60))

model = System.get_env("OLLAMA_EMBED_MODEL") || "nomic-embed-text"

case OllamaClient.list_models() do
  {:ok, models} ->
    if Enum.any?(models, &String.starts_with?(&1, model)) do
      text = "Why is the sky blue?"

      IO.puts("\nGenerating embedding...")

      case Examples.OllamaEmbedder.embed(text, model: model) do
        {:ok, result} ->
          IO.puts("Model: #{result.model}")
          IO.puts("Dimensions: #{result.dimensions}")
          IO.puts("Vector sample: #{inspect(Enum.take(result.vector, 5))}")

        {:error, reason} ->
          IO.puts("Embedding failed: #{inspect(reason)}")
      end
    else
      IO.puts("Model not available: #{model}")
      IO.puts("Pull it with: ollama pull #{model}")
    end

  {:error, reason} ->
    IO.puts("Ollama server not reachable: #{inspect(reason)}")

    IO.puts(
      "Ensure Ollama is running (ollama serve) and reachable at #{OllamaClient.base_url()}."
    )
end

IO.puts("\n" <> String.duplicate("=", 60))
IO.puts("Example completed successfully!")
IO.puts(String.duplicate("=", 60))
