defmodule PortfolioCore.Ports.Agent do
  @moduledoc """
  Behavior for tool-using agent implementations.

  Agents orchestrate LLM reasoning with tool execution, maintaining
  internal state across iterations.

  ## Example Implementation

      defmodule MyApp.Agent do
        @behaviour PortfolioCore.Ports.Agent

        @impl true
        def run(task, _opts) do
          {:ok, "Completed: \#{task}"}
        end

        @impl true
        def available_tools, do: []

        @impl true
        def execute_tool(_call), do: {:error, :no_tools}

        @impl true
        def max_iterations, do: 5
      end
  """

  @type tool_spec :: %{
          name: atom(),
          description: String.t(),
          parameters: [parameter_spec()],
          required: [atom()]
        }

  @type parameter_spec :: %{
          name: atom(),
          type: :string | :integer | :boolean | :list | :map,
          description: String.t(),
          required: boolean()
        }

  @type tool_call :: %{
          id: String.t(),
          tool: atom(),
          arguments: map()
        }

  @type tool_result :: %{
          id: String.t(),
          tool: atom(),
          result: term(),
          success: boolean()
        }

  @type agent_state :: %{
          task: String.t(),
          memory: [message()],
          tool_calls: [tool_call()],
          tool_results: [tool_result()],
          iteration: non_neg_integer()
        }

  @type message :: %{
          role: :user | :assistant | :tool,
          content: String.t()
        }

  @type run_opts :: [
          tools: [atom()],
          max_iterations: pos_integer(),
          timeout: pos_integer(),
          memory: [message()]
        ]

  @doc """
  Run the agent for a given task.
  """
  @callback run(task :: String.t(), opts :: run_opts()) ::
              {:ok, result :: term()} | {:error, term()}

  @doc """
  List tool specifications available to the agent.
  """
  @callback available_tools() :: [tool_spec()]

  @doc """
  Execute a tool call.
  """
  @callback execute_tool(tool_call()) ::
              {:ok, tool_result()} | {:error, term()}

  @doc """
  Return the maximum iterations allowed for the agent.
  """
  @callback max_iterations() :: pos_integer()

  @doc """
  Get current agent state.
  """
  @callback get_state() :: agent_state()

  @optional_callbacks [get_state: 0]
end
