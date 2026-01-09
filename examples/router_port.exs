# Example: Implementing the Router port
# Run: mix run examples/router_port.exs

defmodule Examples.EchoLLM do
  @moduledoc false
  @behaviour PortfolioCore.Ports.LLM

  @impl true
  def complete(messages, _opts) do
    content =
      messages
      |> Enum.reverse()
      |> Enum.find_value("", fn message ->
        Map.get(message, :content) || Map.get(message, "content")
      end)

    {:ok,
     %{
       content: "echo: #{content}",
       model: "echo-1",
       usage: %{input_tokens: 0, output_tokens: 0},
       finish_reason: :stop
     }}
  end

  @impl true
  def stream(_messages, _opts), do: {:error, :streaming_not_supported}

  @impl true
  def supported_models, do: ["echo-1"]

  @impl true
  def model_info(_model), do: %{context_window: 1024, max_output: 128, supports_tools: false}
end

defmodule Examples.SimpleRouter do
  @moduledoc """
  Minimal in-memory router implementation for demonstration.
  """

  @behaviour PortfolioCore.Ports.Router

  use Agent

  def start_link(_opts) do
    Agent.start_link(fn -> %{providers: [], strategy: :fallback, rr_index: 0} end,
      name: __MODULE__
    )
  end

  @impl true
  def route(_messages, opts) do
    strategy = Keyword.get(opts, :strategy, get_strategy())
    task_type = Keyword.get(opts, :task_type)

    providers =
      list_providers()
      |> Enum.filter(& &1.healthy)
      |> filter_by_task(task_type, strategy)

    case strategy do
      :round_robin -> round_robin(providers)
      _ -> fallback(providers)
    end
  end

  @impl true
  def execute(messages, opts) do
    with {:ok, provider} <- route(messages, opts) do
      {:ok, %{provider: provider.name, messages: messages}}
    end
  end

  @impl true
  def register_provider(provider) do
    Agent.update(__MODULE__, fn state ->
      providers =
        state.providers
        |> Enum.reject(&(&1.name == provider.name))
        |> List.insert_at(0, provider)

      %{state | providers: providers}
    end)

    :ok
  end

  @impl true
  def unregister_provider(name) do
    Agent.update(__MODULE__, fn state ->
      %{state | providers: Enum.reject(state.providers, &(&1.name == name))}
    end)

    :ok
  end

  @impl true
  def health_check(name) do
    case Enum.find(list_providers(), &(&1.name == name)) do
      nil -> :unknown
      %{healthy: true} -> :healthy
      %{healthy: false} -> :unhealthy
    end
  end

  @impl true
  def list_providers do
    Agent.get(__MODULE__, & &1.providers)
  end

  @impl true
  def set_strategy(strategy) do
    Agent.update(__MODULE__, fn state -> %{state | strategy: strategy} end)
    :ok
  end

  @impl true
  def get_strategy do
    Agent.get(__MODULE__, & &1.strategy)
  end

  defp filter_by_task(providers, nil, _strategy), do: providers

  defp filter_by_task(providers, task_type, :specialist) do
    Enum.filter(providers, fn provider -> task_type in provider.capabilities end)
  end

  defp filter_by_task(providers, _task_type, _strategy), do: providers

  defp fallback([]), do: {:error, :no_healthy_providers}

  defp fallback(providers) do
    provider = providers |> Enum.sort_by(& &1.priority) |> List.first()

    if provider do
      {:ok, provider}
    else
      {:error, :no_healthy_providers}
    end
  end

  defp round_robin([]), do: {:error, :no_healthy_providers}

  defp round_robin(providers) do
    provider =
      Agent.get_and_update(__MODULE__, fn state ->
        index = rem(state.rr_index, length(providers))
        {Enum.at(providers, index), %{state | rr_index: state.rr_index + 1}}
      end)

    if provider do
      {:ok, provider}
    else
      {:error, :no_healthy_providers}
    end
  end
end

IO.puts("=" |> String.duplicate(60))
IO.puts("Portfolio Core - Router Port Example")
IO.puts("=" |> String.duplicate(60))

{:ok, _} = Examples.SimpleRouter.start_link([])

:ok =
  Examples.SimpleRouter.register_provider(%{
    name: :primary,
    module: Examples.EchoLLM,
    config: %{model: "gpt-4o-mini"},
    capabilities: [:generation, :code],
    priority: 1,
    cost_per_token: 0.001,
    healthy: true
  })

:ok =
  Examples.SimpleRouter.register_provider(%{
    name: :backup,
    module: Examples.EchoLLM,
    config: %{model: "gpt-4o-mini"},
    capabilities: [:generation],
    priority: 2,
    cost_per_token: 0.001,
    healthy: true
  })

messages = [%{role: :user, content: "Write a quick function."}]

{:ok, provider} =
  Examples.SimpleRouter.route(messages,
    strategy: :specialist,
    task_type: :code,
    max_tokens: 100
  )

IO.puts("Selected provider: #{provider.name}")
IO.puts("Capabilities: #{inspect(provider.capabilities)}")

IO.puts("\n" <> String.duplicate("=", 60))
IO.puts("Example completed successfully!")
IO.puts(String.duplicate("=", 60))
