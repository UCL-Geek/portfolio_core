defmodule Examples.OllamaClient do
  @moduledoc false

  @default_base_url "http://localhost:11434"
  @default_timeout 30_000

  def base_url do
    System.get_env("OLLAMA_BASE_URL") ||
      System.get_env("OLLAMA_HOST") ||
      @default_base_url
  end

  def api_base_url do
    base = base_url() |> String.trim_trailing("/")

    if String.ends_with?(base, "/api") do
      base
    else
      base <> "/api"
    end
  end

  def api_url(path) do
    api_base_url() <> "/" <> path
  end

  def list_models(opts \\ []) do
    with {:ok, response} <- request_json(:get, "tags", nil, opts),
         %{"models" => models} <- response do
      names =
        models
        |> Enum.map(&Map.get(&1, "name"))
        |> Enum.filter(&is_binary/1)

      {:ok, names}
    else
      {:ok, other} -> {:error, {:unexpected_response, other}}
      {:error, reason} -> {:error, reason}
    end
  end

  def request_json(method, path, payload, opts \\ []) do
    url = api_url(path)
    timeout = Keyword.get(opts, :timeout, @default_timeout)

    with {:ok, body} <- request_raw(method, url, payload, timeout) do
      case Jason.decode(body) do
        {:ok, decoded} -> {:ok, decoded}
        {:error, reason} -> {:error, {:decode_error, reason, body}}
      end
    end
  end

  defp ensure_http_started(url) do
    _ = :inets.start()

    if String.starts_with?(url, "https://") do
      if Code.ensure_loaded?(:ssl) and function_exported?(:ssl, :start, 0) do
        case apply(:ssl, :start, []) do
          :ok -> :ok
          {:error, {:already_started, :ssl}} -> :ok
          {:error, reason} -> {:error, {:ssl_start_failed, reason}}
        end
      else
        {:error, :ssl_unavailable}
      end
    else
      :ok
    end
  end

  defp request_raw(method, url, payload, timeout) do
    if use_httpc?(url) do
      with :ok <- ensure_http_started(url) do
        request_raw_httpc(method, url, payload, timeout)
      end
    else
      request_raw_curl(method, url, payload, timeout)
    end
  end

  defp request_raw_httpc(:get, url, _payload, timeout) do
    headers = [{~c"accept", ~c"application/json"}]
    url_chars = String.to_charlist(url)
    http_opts = [timeout: timeout, recv_timeout: timeout]
    request_opts = [body_format: :binary]

    case :httpc.request(:get, {url_chars, headers}, http_opts, request_opts) do
      {:ok, {{_version, 200, _reason}, _headers, response_body}} ->
        {:ok, response_body}

      {:ok, {{_version, status, _reason}, _headers, response_body}} ->
        {:error, {:http_error, status, response_body}}

      {:error, reason} ->
        {:error, reason}
    end
  rescue
    UndefinedFunctionError ->
      request_raw_curl(:get, url, nil, timeout)
  end

  defp request_raw_httpc(:post, url, payload, timeout) do
    body = Jason.encode!(payload || %{})
    headers = [{~c"content-type", ~c"application/json"}]
    url_chars = String.to_charlist(url)
    http_opts = [timeout: timeout, recv_timeout: timeout]
    request_opts = [body_format: :binary]
    request = {url_chars, headers, ~c"application/json", body}

    case :httpc.request(:post, request, http_opts, request_opts) do
      {:ok, {{_version, 200, _reason}, _headers, response_body}} ->
        {:ok, response_body}

      {:ok, {{_version, status, _reason}, _headers, response_body}} ->
        {:error, {:http_error, status, response_body}}

      {:error, reason} ->
        {:error, reason}
    end
  rescue
    UndefinedFunctionError ->
      request_raw_curl(:post, url, payload, timeout)
  end

  defp request_raw_curl(method, url, payload, timeout) do
    case System.find_executable("curl") do
      nil ->
        {:error, :curl_not_available}

      curl ->
        timeout_seconds = max(1, div(timeout + 999, 1000))
        base_args = ["--silent", "--show-error", "--max-time", Integer.to_string(timeout_seconds)]
        args = build_curl_args(method, url, payload, base_args)

        case System.cmd(curl, args, stderr_to_stdout: true) do
          {output, 0} ->
            parse_curl_response(output)

          {output, status} ->
            {:error, {:curl_failed, status, output}}
        end
    end
  end

  defp build_curl_args(:get, url, _payload, base_args) do
    base_args ++ ["-X", "GET", "-H", "accept: application/json", "-w", "\n%{http_code}", url]
  end

  defp build_curl_args(:post, url, payload, base_args) do
    body = Jason.encode!(payload || %{})

    base_args ++
      [
        "-X",
        "POST",
        "-H",
        "content-type: application/json",
        "-d",
        body,
        "-w",
        "\n%{http_code}",
        url
      ]
  end

  defp parse_curl_response(output) do
    parts = String.split(output, "\n")
    {status_line, body_parts} = List.pop_at(parts, -1)
    body = Enum.join(body_parts, "\n")

    case Integer.parse(status_line || "") do
      {200, _} ->
        {:ok, body}

      {status, _} ->
        {:error, {:http_error, status, body}}

      :error ->
        {:error, {:invalid_curl_response, output}}
    end
  end

  defp use_httpc?(url) do
    httpc_available?() and (not https_url?(url) or ssl_available?())
  end

  defp https_url?(url) do
    String.starts_with?(url, "https://")
  end

  defp httpc_available? do
    Code.ensure_loaded?(:inets) and
      Code.ensure_loaded?(:httpc) and
      public_key_available?()
  end

  defp public_key_available? do
    Code.ensure_loaded?(:public_key) and
      function_exported?(:public_key, :pkix_verify_hostname_match_fun, 1)
  end

  defp ssl_available? do
    Code.ensure_loaded?(:ssl) and function_exported?(:ssl, :start, 0)
  end
end
