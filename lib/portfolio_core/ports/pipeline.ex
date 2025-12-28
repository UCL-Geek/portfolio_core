defmodule PortfolioCore.Ports.Pipeline do
  @moduledoc """
  Behavior for pipeline step implementations.

  Pipelines define composable workflow steps used in ingestion or query
  execution. Each step receives context and configuration and returns
  a standardized result tuple.

  ## Example Implementation

      defmodule MyApp.PipelineSteps.Embed do
        @behaviour PortfolioCore.Ports.Pipeline

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
  """

  @type step_status :: :pending | :running | :completed | :failed | :skipped

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

  @optional_callbacks [validate_input: 1, estimated_duration: 0]
end
