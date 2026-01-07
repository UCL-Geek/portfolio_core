defmodule PortfolioCore.Ports.RateLimiter do
  @moduledoc """
  Port specification for rate limiting API calls.

  Provides rate limiting, backoff, and concurrency control for external API calls
  to providers like OpenAI, Anthropic, Gemini, etc.

  ## Features

  - Per-provider rate limiting
  - Backoff window tracking (after 429 responses)
  - Concurrency limiting (semaphore)
  - Success/failure tracking for adaptive limits

  ## Example Implementation

      defmodule MyApp.Adapters.RateLimiter do
        @behaviour PortfolioCore.Ports.RateLimiter

        @impl true
        def check(:openai, :chat) do
          # Check if request is allowed
          :ok
        end

        @impl true
        def wait(:openai, :chat) do
          # Block until request is allowed
          :ok
        end
      end

  ## Provider Keys

  Standard provider atoms:
  - `:openai` - OpenAI API
  - `:anthropic` - Anthropic API
  - `:gemini` - Google Gemini API
  - `:openai_embeddings` - OpenAI embeddings (separate limits)

  ## Operation Keys

  Standard operation atoms:
  - `:chat` - Chat completions
  - `:embedding` - Embedding generation
  - `:default` - Default operation
  """

  @type provider :: atom()
  @type operation :: atom()
  @type backoff_ms :: non_neg_integer()
  @type failure_reason :: :rate_limited | :timeout | :server_error | atom()

  @type check_result :: :ok | {:backoff, backoff_ms()}

  @type status :: %{
          provider: provider(),
          in_backoff: boolean(),
          backoff_until: DateTime.t() | nil,
          success_count: non_neg_integer(),
          failure_count: non_neg_integer(),
          last_failure: failure_reason() | nil
        }

  @type limit_config :: %{
          optional(:requests_per_minute) => pos_integer(),
          optional(:requests_per_second) => pos_integer(),
          optional(:tokens_per_minute) => pos_integer(),
          optional(:max_concurrency) => pos_integer(),
          optional(:burst_limit) => pos_integer()
        }

  @doc """
  Check if a request to the provider is currently allowed.

  Returns `:ok` if the request can proceed, or `{:backoff, ms}` if the caller
  should wait before retrying.
  """
  @callback check(provider()) :: check_result()

  @doc """
  Check if a request to the provider for a specific operation is allowed.
  """
  @callback check(provider(), operation()) :: check_result()

  @doc """
  Block until a request to the provider is allowed.

  This will sleep if necessary and return `:ok` when the request can proceed.
  """
  @callback wait(provider()) :: :ok

  @doc """
  Block until a request to the provider for a specific operation is allowed.
  """
  @callback wait(provider(), operation()) :: :ok

  @doc """
  Record a successful API call.

  This can be used to adjust adaptive rate limits.
  """
  @callback record_success(provider(), operation()) :: :ok

  @doc """
  Record a failed API call.

  For rate limit failures (429), this triggers backoff behavior.
  """
  @callback record_failure(provider(), operation(), failure_reason()) :: :ok

  @doc """
  Configure rate limits for a provider.
  """
  @callback configure(provider(), limit_config()) :: :ok

  @doc """
  Get the current status of rate limiting for a provider.
  """
  @callback status(provider()) :: status()
end
