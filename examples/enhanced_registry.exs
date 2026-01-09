# Example: Using enhanced registry features
# Run: mix run examples/enhanced_registry.exs

alias PortfolioCore.Registry

defmodule Examples.OpenAIAdapter do
  @moduledoc false

  @behaviour PortfolioCore.Ports.LLM

  @default_base_url "https://api.openai.com/v1"

  @impl true
  def complete(messages, opts) do
    opts = normalize_opts(opts)
    api_key = Keyword.get(opts, :api_key) || System.get_env("OPENAI_API_KEY")
    model = Keyword.get(opts, :model) || System.get_env("OPENAI_MODEL") || "gpt-4o-mini"

    base_url =
      Keyword.get(opts, :base_url) || System.get_env("OPENAI_BASE_URL") || @default_base_url

    timeout = Keyword.get(opts, :timeout, 30_000)

    with :ok <- ensure_api_key(api_key) do
      case ensure_http_started() do
        :ok ->
          with {:ok, body} <- post_completion(base_url, api_key, model, messages, opts, timeout),
               {:ok, result} <- parse_response(body, model) do
            {:ok, result}
          end

        {:error, :ssl_unavailable} ->
          with {:ok, body} <-
                 post_completion_via_curl(base_url, api_key, model, messages, opts, timeout),
               {:ok, result} <- parse_response(body, model) do
            {:ok, result}
          end

        {:error, {:ssl_start_failed, _reason}} ->
          with {:ok, body} <-
                 post_completion_via_curl(base_url, api_key, model, messages, opts, timeout),
               {:ok, result} <- parse_response(body, model) do
            {:ok, result}
          end

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  @impl true
  def stream(_messages, _opts), do: {:error, :streaming_not_supported}

  @impl true
  def supported_models, do: [System.get_env("OPENAI_MODEL") || "gpt-4o-mini"]

  @impl true
  def model_info(_model) do
    %{context_window: 128_000, max_output: 4096, supports_tools: true}
  end

  defp normalize_opts(opts) when is_map(opts), do: Map.to_list(opts)
  defp normalize_opts(opts) when is_list(opts), do: opts
  defp normalize_opts(_opts), do: []

  defp ensure_api_key(nil), do: {:error, :missing_api_key}
  defp ensure_api_key(""), do: {:error, :missing_api_key}
  defp ensure_api_key(_api_key), do: :ok

  defp ensure_http_started do
    _ = :inets.start()

    if Code.ensure_loaded?(:ssl) and function_exported?(:ssl, :start, 0) do
      case apply(:ssl, :start, []) do
        :ok -> :ok
        {:error, {:already_started, :ssl}} -> :ok
        {:error, reason} -> {:error, {:ssl_start_failed, reason}}
      end
    else
      {:error, :ssl_unavailable}
    end
  end

  defp post_completion(base_url, api_key, model, messages, opts, timeout) do
    payload = build_payload(model, messages, opts)

    body = Jason.encode!(payload)
    url = String.to_charlist("#{base_url}/chat/completions")

    headers = [
      {~c"content-type", ~c"application/json"},
      {~c"authorization", to_charlist("Bearer " <> api_key)}
    ]

    request = {url, headers, ~c"application/json", body}
    http_opts = [timeout: timeout, recv_timeout: timeout]
    request_opts = [body_format: :binary]

    case :httpc.request(:post, request, http_opts, request_opts) do
      {:ok, {{_version, 200, _reason}, _headers, response_body}} ->
        {:ok, response_body}

      {:ok, {{_version, status, _reason}, _headers, response_body}} ->
        {:error, {:http_error, status, sanitize_error_body(response_body)}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp post_completion_via_curl(base_url, api_key, model, messages, opts, timeout) do
    case System.find_executable("curl") do
      nil ->
        {:error, :curl_not_available}

      curl ->
        payload = build_payload(model, messages, opts)
        body = Jason.encode!(payload)
        url = "#{base_url}/chat/completions"
        max_time = max(1, div(timeout, 1000))

        args = [
          "--silent",
          "--show-error",
          "--location",
          "--write-out",
          "\n%{http_code}",
          "--max-time",
          Integer.to_string(max_time),
          "-X",
          "POST",
          "-H",
          "Content-Type: application/json",
          "-H",
          "Authorization: Bearer #{api_key}",
          "--data-binary",
          body,
          url
        ]

        {output, exit_status} = System.cmd(curl, args, stderr_to_stdout: true)

        case exit_status do
          0 ->
            {response_body, status} = split_curl_output(output)

            if status == 200 do
              {:ok, response_body}
            else
              {:error, {:http_error, status, sanitize_error_body(response_body)}}
            end

          _ ->
            {:error, {:curl_error, exit_status, sanitize_error_body(output)}}
        end
    end
  end

  defp normalize_messages(messages) do
    Enum.map(messages, fn message ->
      role = Map.get(message, :role) || Map.get(message, "role")
      content = Map.get(message, :content) || Map.get(message, "content")

      %{
        role: normalize_role(role),
        content: content
      }
    end)
  end

  defp normalize_role(role) when is_atom(role), do: Atom.to_string(role)
  defp normalize_role(role) when is_binary(role), do: role
  defp normalize_role(_role), do: "user"

  defp build_payload(model, messages, opts) do
    %{
      model: model,
      messages: normalize_messages(messages),
      temperature: Keyword.get(opts, :temperature, 0.2),
      max_tokens: Keyword.get(opts, :max_tokens)
    }
    |> drop_nil_values()
  end

  defp drop_nil_values(map) do
    map
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end

  defp split_curl_output(output) do
    trimmed = String.trim_trailing(output, "\n")
    lines = String.split(trimmed, "\n", trim: false)
    {body_lines, status_lines} = Enum.split(lines, -1)
    status = parse_status(List.first(status_lines, "0"))
    {Enum.join(body_lines, "\n"), status}
  end

  defp parse_status(status_line) do
    case Integer.parse(status_line) do
      {status, _rest} -> status
      :error -> 0
    end
  end

  defp sanitize_error_body(body) when is_binary(body) do
    body
    |> String.replace(~r/sk-[A-Za-z0-9_-]{10,}/, "sk-***")
  end

  defp sanitize_error_body(body), do: inspect(body)

  defp parse_response(body, model) do
    case Jason.decode(body) do
      {:ok, %{"error" => error}} ->
        {:error, {:api_error, sanitize_error(error)}}

      {:ok, %{"choices" => [choice | _]} = data} ->
        usage = Map.get(data, "usage", %{})

        {:ok,
         %{
           content: get_in(choice, ["message", "content"]) || "",
           model: Map.get(data, "model", model),
           usage: %{
             input_tokens: Map.get(usage, "prompt_tokens", 0),
             output_tokens: Map.get(usage, "completion_tokens", 0)
           },
           finish_reason: normalize_finish_reason(Map.get(choice, "finish_reason"))
         }}

      {:ok, other} ->
        {:error, {:unexpected_response, other}}

      {:error, reason} ->
        {:error, {:decode_error, reason}}
    end
  end

  defp normalize_finish_reason("stop"), do: :stop
  defp normalize_finish_reason("length"), do: :length
  defp normalize_finish_reason("tool_calls"), do: :tool_use
  defp normalize_finish_reason(_reason), do: :stop

  defp sanitize_error(%{"message" => message} = error) when is_binary(message) do
    Map.put(error, "message", sanitize_error_body(message))
  end

  defp sanitize_error(error) when is_map(error) do
    Map.new(error, fn {key, value} ->
      if is_binary(value) do
        {key, sanitize_error_body(value)}
      else
        {key, value}
      end
    end)
  end

  defp sanitize_error(error), do: sanitize_error_body(error)
end

IO.puts("=" |> String.duplicate(60))
IO.puts("Portfolio Core - Enhanced Registry Example")
IO.puts("=" |> String.duplicate(60))

Registry.clear()

model = System.get_env("OPENAI_MODEL") || "gpt-4o-mini"
base_url = System.get_env("OPENAI_BASE_URL") || "https://api.openai.com/v1"

# Register with metadata
Registry.register(:primary_llm, Examples.OpenAIAdapter, %{model: model, base_url: base_url}, %{
  capabilities: [:generation, :function_calling],
  backend_capabilities: %{
    backend_id: :openai,
    provider: "openai",
    models: [model],
    default_model: model,
    supports_streaming: false,
    supports_tools: true,
    supports_vision: false,
    cost_per_million_input: 5.0,
    cost_per_million_output: 15.0
  }
})

# Find capable adapters
generation_adapters = Registry.find_by_capability(:generation)
IO.inspect(generation_adapters, label: "Generation capable")

{:ok, backend_caps} = Registry.backend_capabilities(:primary_llm)
IO.inspect(backend_caps, label: "Backend capabilities")

# Live API call
messages = [
  %{role: :system, content: "You are a concise assistant."},
  %{role: :user, content: "In one sentence, explain what this registry example demonstrates."}
]

IO.puts("\nMaking live API call...")

{:ok, entry} = Registry.get(:primary_llm)

call_opts =
  case entry.config do
    config when is_map(config) -> Map.to_list(config)
    config when is_list(config) -> config
  end

call_result = entry.module.complete(messages, call_opts)

case call_result do
  {:ok, completion} ->
    Registry.record_call(:primary_llm, true)
    Registry.mark_healthy(:primary_llm)
    IO.puts("LLM response: #{String.trim(completion.content)}")
    IO.puts("Model: #{completion.model} | Finish: #{completion.finish_reason}")
    IO.inspect(completion.usage, label: "Usage")

  {:error, :missing_api_key} ->
    Registry.record_call(:primary_llm, false)
    Registry.mark_unhealthy(:primary_llm)
    IO.puts("Missing OPENAI_API_KEY; set it to run this example.")

  {:error, :curl_not_available} ->
    Registry.record_call(:primary_llm, false)
    Registry.mark_unhealthy(:primary_llm)
    IO.puts("SSL not available and curl not found; install curl or enable SSL for HTTPS.")

  {:error, reason} ->
    Registry.record_call(:primary_llm, false)
    Registry.mark_unhealthy(:primary_llm)
    IO.puts("LLM call failed: #{inspect(reason)}")
end

IO.puts("Status: #{Registry.health_status(:primary_llm)}")

{:ok, metrics} = Registry.metrics(:primary_llm)
IO.inspect(metrics, label: "Metrics")

IO.puts("\n" <> String.duplicate("=", 60))
IO.puts("Example completed successfully!")
IO.puts(String.duplicate("=", 60))
