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

  @type session :: %{
          id: String.t(),
          messages: [message()],
          tool_results: [tool_result()],
          created_at: DateTime.t(),
          updated_at: DateTime.t()
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

  @doc """
  Process input within a session context.

  Maintains conversation history across calls.

  ## Parameters

    - `session` - Current session state
    - `input` - User input to process
    - `opts` - Processing options

  ## Returns

    - `{:ok, response, updated_session}` on success
    - `{:error, reason}` on failure
  """
  @callback process(session(), input :: String.t(), opts :: keyword()) ::
              {:ok, String.t(), session()} | {:error, term()}

  @doc """
  Process input with tool execution within a session.

  Runs the tool execution loop until completion or max iterations.

  ## Parameters

    - `session` - Current session state
    - `input` - User input to process
    - `tools` - List of tool modules to use
    - `opts` - Processing options:
      - `:max_iterations` - Maximum tool execution iterations

  ## Returns

    - `{:ok, response, updated_session}` on success
    - `{:error, reason}` on failure
  """
  @callback process_with_tools(
              session(),
              input :: String.t(),
              tools :: [atom()],
              opts :: keyword()
            ) ::
              {:ok, String.t(), session()} | {:error, term()}

  @optional_callbacks [get_state: 0, process: 3, process_with_tools: 4]
end
