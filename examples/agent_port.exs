# Example: Implementing the Agent port
# Run: mix run examples/agent_port.exs

defmodule Examples.SimpleAgent do
  @moduledoc """
  Minimal agent implementation for demonstration.
  """

  @behaviour PortfolioCore.Ports.Agent

  use Agent

  def start_link(_opts) do
    Agent.start_link(fn -> default_state() end, name: __MODULE__)
  end

  @impl true
  def run(task, opts) do
    memory = Keyword.get(opts, :memory, [])

    Agent.update(__MODULE__, fn _ ->
      %{
        task: task,
        memory: memory,
        tool_calls: [],
        tool_results: [],
        iteration: 1
      }
    end)

    {:ok, "completed: #{task}"}
  end

  @impl true
  def available_tools do
    [
      %{
        name: :echo,
        description: "Echo the provided text",
        parameters: [
          %{name: :text, type: :string, description: "Text to echo", required: true}
        ],
        required: [:text]
      }
    ]
  end

  @impl true
  def execute_tool(%{id: id, tool: tool, arguments: arguments} = call) do
    result = %{id: id, tool: tool, result: arguments, success: true}

    Agent.update(__MODULE__, fn state ->
      %{
        state
        | tool_calls: [call | state.tool_calls],
          tool_results: [result | state.tool_results]
      }
    end)

    {:ok, result}
  end

  @impl true
  def max_iterations, do: 5

  @impl true
  def get_state do
    Agent.get(__MODULE__, & &1)
  end

  defp default_state do
    %{
      task: "",
      memory: [],
      tool_calls: [],
      tool_results: [],
      iteration: 0
    }
  end
end

IO.puts("=" |> String.duplicate(60))
IO.puts("Portfolio Core - Agent Port Example")
IO.puts("=" |> String.duplicate(60))

{:ok, _} = Examples.SimpleAgent.start_link([])

{:ok, result} =
  Examples.SimpleAgent.run("Summarize the meeting notes",
    tools: [:echo],
    memory: [%{role: :user, content: "Kickoff notes"}]
  )

IO.puts("Run result: #{result}")

{:ok, tool_result} =
  Examples.SimpleAgent.execute_tool(%{
    id: "tool-1",
    tool: :echo,
    arguments: %{text: "hello"}
  })

IO.inspect(tool_result, label: "Tool result")
IO.inspect(Examples.SimpleAgent.get_state(), label: "Agent state")

IO.puts("\n" <> String.duplicate("=", 60))
IO.puts("Example completed successfully!")
IO.puts(String.duplicate("=", 60))
