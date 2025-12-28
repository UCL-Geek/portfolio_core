defmodule PortfolioCore.Ports.Tool do
  @moduledoc """
  Behavior for individual agent tools.

  Tools expose a simple interface for agents to execute external actions
  such as search, file access, or API calls.

  ## Example Implementation

      defmodule MyApp.Tools.Search do
        @behaviour PortfolioCore.Ports.Tool

        @impl true
        def name, do: :search

        @impl true
        def description, do: "Searches a local index"

        @impl true
        def parameters, do: [%{name: :query, type: :string, required: true}]

        @impl true
        def execute(%{query: query}) do
          {:ok, "Results for \#{query}"}
        end
      end
  """

  @type parameter :: %{
          name: atom(),
          type: :string | :integer | :float | :boolean | :list | :map,
          required: boolean(),
          description: String.t(),
          default: term()
        }

  @doc """
  Return the tool name.
  """
  @callback name() :: atom()

  @doc """
  Return the tool description.
  """
  @callback description() :: String.t()

  @doc """
  Return parameter definitions for the tool.
  """
  @callback parameters() :: [parameter()]

  @doc """
  Execute the tool with the provided arguments.
  """
  @callback execute(args :: map()) :: {:ok, term()} | {:error, term()}

  @doc """
  Indicate whether the tool is idempotent.
  """
  @callback idempotent?() :: boolean()

  @optional_callbacks [idempotent?: 0]
end
