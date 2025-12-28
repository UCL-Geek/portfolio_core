defmodule PortfolioCore.Ports.Router do
  @moduledoc """
  Behavior for multi-provider LLM routing.

  Enables intelligent distribution of LLM requests across multiple providers
  based on strategies: fallback, round_robin, specialist, cost_optimized.

  ## Example Implementation

      defmodule MyApp.Router do
        @behaviour PortfolioCore.Ports.Router

        @impl true
        def route(messages, opts) do
          strategy = Keyword.get(opts, :strategy, :fallback)
          providers = list_providers()

          case select_provider(providers, strategy) do
            nil -> {:error, :no_healthy_providers}
            provider -> {:ok, provider}
          end
        end

        defp select_provider(providers, :fallback) do
          providers
          |> Enum.filter(& &1.healthy)
          |> Enum.sort_by(& &1.priority)
          |> List.first()
        end
      end
  """

  @type strategy :: :fallback | :round_robin | :specialist | :cost_optimized

  @type provider :: %{
          name: atom(),
          module: module(),
          config: map(),
          capabilities: [capability()],
          priority: non_neg_integer(),
          cost_per_token: float(),
          healthy: boolean()
        }

  @type capability ::
          :generation
          | :reasoning
          | :code
          | :embedding
          | :streaming
          | :function_calling
          | :vision

  @type route_opts :: [
          strategy: strategy(),
          task_type: capability(),
          max_tokens: pos_integer(),
          timeout: pos_integer()
        ]

  @doc """
  Select a provider for the given messages and options.

  ## Parameters

    - `messages` - List of chat messages to route
    - `opts` - Routing options including strategy and task type

  ## Returns

    - `{:ok, provider}` on success
    - `{:error, :no_healthy_providers}` if none are available
    - `{:error, reason}` on other failures
  """
  @callback route(messages :: [map()], opts :: route_opts()) ::
              {:ok, provider()} | {:error, :no_healthy_providers | term()}

  @doc """
  Register a new provider with the router.
  """
  @callback register_provider(provider()) :: :ok | {:error, term()}

  @doc """
  Remove a provider from the router.
  """
  @callback unregister_provider(name :: atom()) :: :ok

  @doc """
  Check health status of a specific provider.
  """
  @callback health_check(name :: atom()) :: :healthy | :unhealthy | :unknown

  @doc """
  List all registered providers.
  """
  @callback list_providers() :: [provider()]

  @doc """
  Set the default routing strategy.
  """
  @callback set_strategy(strategy()) :: :ok

  @doc """
  Get current routing strategy.
  """
  @callback get_strategy() :: strategy()
end
