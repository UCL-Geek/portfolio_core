defmodule PortfolioCore.Manifest.Loader do
  @moduledoc """
  Loads and parses manifest YAML files with environment variable expansion.

  Supports `${VAR_NAME}` syntax for environment variable substitution,
  allowing sensitive values to be kept out of configuration files.

  ## Environment Variable Expansion

  Any value containing `${VAR_NAME}` will be replaced with the
  environment variable's value. Missing variables cause an error.

      adapters:
        embedder:
          config:
            api_key: ${OPENAI_API_KEY}

  ## Example

      iex> PortfolioCore.Manifest.Loader.load("config/manifest.yaml")
      {:ok, %{version: "1.0", environment: :dev, adapters: ...}}
  """

  @doc """
  Load manifest from file path.

  ## Parameters

    - `path` - Path to the YAML manifest file

  ## Returns

    - `{:ok, manifest}` with parsed manifest
    - `{:error, reason}` on failure

  ## Examples

      {:ok, manifest} = Loader.load("config/manifest.yaml")
  """
  @spec load(Path.t()) :: {:ok, map()} | {:error, term()}
  def load(path) do
    with {:ok, content} <- File.read(path),
         {:ok, yaml} <- parse_yaml(content) do
      expand_env_vars(yaml)
    end
  end

  @doc """
  Load manifest from file path, raising on error.

  ## Parameters

    - `path` - Path to the YAML manifest file

  ## Returns

    - Parsed manifest

  ## Raises

    - `File.Error` if file cannot be read
    - `ArgumentError` for YAML parsing errors
    - `RuntimeError` for missing environment variables
  """
  @spec load!(Path.t()) :: map()
  def load!(path) do
    case load(path) do
      {:ok, manifest} -> manifest
      {:error, {:missing_env_var, var}} -> raise "Missing environment variable: #{var}"
      {:error, reason} -> raise "Failed to load manifest: #{inspect(reason)}"
    end
  end

  @doc """
  Load manifest from a YAML string.

  ## Parameters

    - `content` - YAML content as string

  ## Returns

    - `{:ok, manifest}` with parsed manifest
    - `{:error, reason}` on failure
  """
  @spec load_string(String.t()) :: {:ok, map()} | {:error, term()}
  def load_string(content) do
    with {:ok, yaml} <- parse_yaml(content) do
      expand_env_vars(yaml)
    end
  end

  @doc """
  Expand `${VAR}` patterns with environment variables.

  ## Parameters

    - `value` - Any term containing potential environment variable references

  ## Returns

    - `{:ok, expanded}` with all variables expanded
    - `{:error, {:missing_env_var, var_name}}` if a variable is not set

  ## Examples

      iex> System.put_env("MY_KEY", "secret")
      iex> expand_env_vars("api_key: ${MY_KEY}")
      {:ok, "api_key: secret"}
  """
  @spec expand_env_vars(term()) :: {:ok, term()} | {:error, term()}
  def expand_env_vars(value) when is_binary(value) do
    case Regex.scan(~r/\$\{(\w+)\}/, value) do
      [] ->
        {:ok, value}

      matches ->
        result = Enum.reduce_while(matches, value, &substitute_env_var/2)

        case result do
          {:error, _} = err -> err
          expanded -> {:ok, expanded}
        end
    end
  end

  def expand_env_vars(value) when is_map(value) do
    value
    |> Enum.reduce_while({:ok, %{}}, fn {k, v}, {:ok, acc} ->
      case expand_env_vars(v) do
        {:ok, expanded} -> {:cont, {:ok, Map.put(acc, k, expanded)}}
        {:error, _} = err -> {:halt, err}
      end
    end)
  end

  def expand_env_vars(value) when is_list(value) do
    value
    |> Enum.reduce_while({:ok, []}, fn item, {:ok, acc} ->
      case expand_env_vars(item) do
        {:ok, expanded} -> {:cont, {:ok, [expanded | acc]}}
        {:error, _} = err -> {:halt, err}
      end
    end)
    |> case do
      {:ok, list} -> {:ok, Enum.reverse(list)}
      err -> err
    end
  end

  def expand_env_vars(value), do: {:ok, value}

  # Private functions

  defp substitute_env_var([full, var_name], acc) do
    case System.get_env(var_name) do
      nil -> {:halt, {:error, {:missing_env_var, var_name}}}
      val -> {:cont, String.replace(acc, full, val)}
    end
  end

  defp parse_yaml(content) do
    case YamlElixir.read_from_string(content) do
      {:ok, yaml} -> {:ok, yaml}
      {:error, reason} -> {:error, {:yaml_parse_error, reason}}
    end
  rescue
    e -> {:error, {:yaml_parse_error, Exception.message(e)}}
  end
end
