# Example: Ollama LLM adapter (PortfolioCore.Ports.LLM)
# Run: mix run examples/ollama_llm_adapter.exs

Code.require_file(Path.join(__DIR__, "support/ollama_client.exs"))

alias Examples.OllamaClient

defmodule Examples.OllamaAdapter do
  @moduledoc false
  @behaviour PortfolioCore.Ports.LLM

  @default_model "llama3.2"
  @fallback_models ["llama3", "mistral", "phi3"]

  @impl true
  def complete(messages, opts) do
    opts = normalize_opts(opts)
    model = pick_model(opts)

    payload = %{
      model: model,
      messages: normalize_messages(messages),
      stream: false
    }

    with {:ok, response} <- OllamaClient.request_json(:post, "chat", payload, opts) do
      {:ok, normalize_response(response, model)}
    end
  end

  @impl true
  def stream(_messages, _opts), do: {:error, :streaming_not_supported}

  @impl true
  def supported_models do
    case OllamaClient.list_models() do
      {:ok, models} when models != [] -> models
      _ -> [@default_model]
    end
  end

  @impl true
  def model_info(_model) do
    %{context_window: 8192, max_output: 2048, supports_tools: true}
  end

  defp normalize_opts(opts) when is_map(opts), do: Map.to_list(opts)
  defp normalize_opts(opts) when is_list(opts), do: opts
  defp normalize_opts(_opts), do: []

  defp pick_model(opts) do
    configured = Keyword.get(opts, :model) || System.get_env("OLLAMA_MODEL")

    case OllamaClient.list_models() do
      {:ok, models} ->
        choose_model(models, configured)

      {:error, _reason} ->
        configured || @default_model
    end
  end

  defp choose_model(models, nil), do: choose_model(models, "")

  defp choose_model(models, "") do
    candidates = [@default_model | @fallback_models]

    fallback = List.first(models) || @default_model

    Enum.find_value(candidates, fallback, fn candidate ->
      Enum.find(models, &String.starts_with?(&1, candidate))
    end)
  end

  defp choose_model(models, configured) do
    Enum.find(models, &String.starts_with?(&1, configured)) || configured
  end

  defp normalize_messages(messages) do
    Enum.map(messages, fn message ->
      role = Map.get(message, :role) || Map.get(message, "role") || "user"
      content = Map.get(message, :content) || Map.get(message, "content") || ""
      %{role: to_string(role), content: content}
    end)
  end

  defp normalize_response(response, default_model) do
    message = get_in(response, ["message"]) || %{}

    %{
      content: Map.get(message, "content", ""),
      model: Map.get(response, "model", default_model),
      usage: %{
        input_tokens: Map.get(response, "prompt_eval_count", 0),
        output_tokens: Map.get(response, "eval_count", 0)
      },
      finish_reason: normalize_finish_reason(Map.get(response, "done_reason"))
    }
  end

  defp normalize_finish_reason("stop"), do: :stop
  defp normalize_finish_reason("length"), do: :length
  defp normalize_finish_reason("tool_calls"), do: :tool_use
  defp normalize_finish_reason(nil), do: nil
  defp normalize_finish_reason(_reason), do: :stop
end

IO.puts(String.duplicate("=", 60))
IO.puts("Portfolio Core - Ollama LLM Adapter Example")
IO.puts(String.duplicate("=", 60))

case OllamaClient.list_models() do
  {:ok, []} ->
    IO.puts("No Ollama models found. Pull one with: ollama pull llama3.2")

  {:ok, _models} ->
    messages = [
      %{role: :system, content: "You are concise and helpful."},
      %{role: :user, content: "In one sentence, explain what Ollama is."}
    ]

    IO.puts("\nMaking live Ollama chat call...")

    case Examples.OllamaAdapter.complete(messages, []) do
      {:ok, completion} ->
        IO.puts("LLM response: #{String.trim(completion.content)}")
        IO.puts("Model: #{completion.model} | Finish: #{completion.finish_reason}")
        IO.inspect(completion.usage, label: "Usage")

      {:error, reason} ->
        IO.puts("Ollama call failed: #{inspect(reason)}")
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
