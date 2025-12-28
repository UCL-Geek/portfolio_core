defmodule PortfolioCore.Ports.Pipeline do
  @moduledoc """
  Behavior for pipeline step implementations.

  Pipelines define composable workflow steps used in ingestion or query
  execution. Each step receives context and configuration and returns
  a standardized result tuple.

  ## Example Implementation

      defmodule MyApp.PipelineSteps.Embed do
        use PortfolioCore.Ports.Pipeline

        @impl true
        def execute(context, _config) do
          {:ok, Map.put(context.inputs, :embedding, [0.1, 0.2, 0.3])}
        end

        @impl true
        def output_schema, do: %{embedding: :list}

        @impl true
        def required_inputs, do: [:text]

        @impl true
        def cacheable?, do: true
      end

  ## Default Step Hints

  Using `PortfolioCore.Ports.Pipeline` provides defaults for:
  - `parallel?/0` (false)
  - `on_error/0` (:halt)
  - `timeout/0` (30_000 ms)
  - `cache_ttl/0` (:infinity)

  Override defaults by passing options to `use` or by implementing the callbacks:

      use PortfolioCore.Ports.Pipeline, parallel?: true, timeout: 5_000
  """

  @default_pipeline_opts [
    parallel?: false,
    on_error: :halt,
    timeout: 30_000,
    cache_ttl: :infinity
  ]

  defmacro __using__(opts \\ []) do
    defaults = Keyword.merge(@default_pipeline_opts, opts)

    quote do
      @behaviour PortfolioCore.Ports.Pipeline

      @impl true
      def parallel?, do: unquote(defaults[:parallel?])

      @impl true
      def on_error, do: unquote(defaults[:on_error])

      @impl true
      def timeout, do: unquote(defaults[:timeout])

      @impl true
      def cache_ttl, do: unquote(defaults[:cache_ttl])

      defoverridable parallel?: 0, on_error: 0, timeout: 0, cache_ttl: 0
    end
  end

  @type step_status :: :pending | :running | :completed | :failed | :skipped

  @type on_error :: :halt | :continue | {:retry, pos_integer()}

  @type step_result ::
          {:ok, term()}
          | {:error, term()}
          | {:skip, reason :: term()}

  @type step_context :: %{
          step_name: atom(),
          pipeline_name: atom(),
          inputs: map(),
          metadata: map(),
          attempt: pos_integer()
        }

  @type output_type ::
          :any
          | :string
          | :map
          | :list
          | {:list, output_type()}
          | {:map, key_type :: output_type(), value_type :: output_type()}

  @doc """
  Execute the pipeline step with context and configuration.
  """
  @callback execute(context :: step_context(), config :: keyword()) ::
              step_result()

  @doc """
  Validate an input before executing the step.
  """
  @callback validate_input(input :: term()) :: :ok | {:error, term()}

  @doc """
  Define the output schema for this step.
  """
  @callback output_schema() :: %{atom() => output_type()}

  @doc """
  List required input keys for this step.
  """
  @callback required_inputs() :: [atom()]

  @doc """
  Indicate whether this step can be cached.
  """
  @callback cacheable?() :: boolean()

  @doc """
  Estimate duration for this step in milliseconds.
  """
  @callback estimated_duration() :: pos_integer()

  @doc """
  Indicate whether this step can run in parallel with other steps.

  ## Returns

    - `true` if this step can run concurrently
    - `false` if it must run sequentially
  """
  @callback parallel?() :: boolean()

  @doc """
  Define error handling behavior for this step.

  ## Returns

    - `:halt` - Stop pipeline on error
    - `:continue` - Skip step and continue
    - `{:retry, n}` - Retry up to n times
  """
  @callback on_error() :: on_error()

  @doc """
  Get the timeout for this step in milliseconds.

  ## Returns

    - Timeout in milliseconds
  """
  @callback timeout() :: pos_integer()

  @doc """
  Get the cache TTL for this step.

  ## Returns

    - `:infinity` for permanent caching
    - Milliseconds for time-limited caching
  """
  @callback cache_ttl() :: pos_integer() | :infinity

  @optional_callbacks [
    validate_input: 1,
    estimated_duration: 0
  ]
end
