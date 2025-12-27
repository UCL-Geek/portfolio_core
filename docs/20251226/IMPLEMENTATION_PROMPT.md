# Portfolio Core Implementation Prompt

## Overview

You are implementing `portfolio_core`, a Hex.pm-publishable Elixir library providing hexagonal architecture primitives for building flexible RAG (Retrieval-Augmented Generation) systems. This is the foundational layer that defines port specifications (behaviors), manifest-based configuration, adapter registry, and dependency injection framework.

---

## Required Reading

Before implementation, read these files in order:

### Architecture Documentation
```
/home/home/p/g/n/portfolio_manager/docs/20251226/expert_architecture_review/00_executive_summary.md
/home/home/p/g/n/portfolio_manager/docs/20251226/expert_architecture_review/01_beam_otp_architecture.md
/home/home/p/g/n/portfolio_manager/docs/20251226/expert_architecture_review/02_hexagonal_core_design.md
/home/home/p/g/n/portfolio_manager/docs/20251226/expert_architecture_review/08_security_observability.md
/home/home/p/g/n/portfolio_manager/docs/20251226/expert_architecture_review/09_implementation_roadmap.md
```

### Original Design Context
```
/home/home/p/g/n/portfolio_manager/docs/20251226/ecosystem design docs/00_overview.md
/home/home/p/g/n/portfolio_manager/docs/20251226/ecosystem design docs/03_recommended_architecture.md
/home/home/p/g/n/portfolio_manager/docs/20251226/ecosystem design docs/04_manifest_hex_core.md
```

---

## Package Scope

### What portfolio_core IS:
- Port specifications (Elixir behaviors) defining contracts for adapters
- Manifest engine for YAML-based configuration
- Adapter registry with dynamic lookup
- Telemetry integration points
- Base types and protocols
- NO concrete implementations (those go in portfolio_index)

### What portfolio_core IS NOT:
- No actual vector store implementations
- No actual graph store implementations
- No actual LLM/embedding API calls
- No Broadway pipelines
- No database schemas

---

## Implementation Tasks

### 1. Project Setup

```bash
cd /home/home/p/g/n/portfolio_core
mix new . --module PortfolioCore --app portfolio_core
```

Create `mix.exs`:

```elixir
defmodule PortfolioCore.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/nshkrdotcom/portfolio_core"

  def project do
    [
      app: :portfolio_core,
      version: @version,
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      docs: docs(),
      name: "PortfolioCore",
      source_url: @source_url,
      aliases: aliases(),
      dialyzer: [
        plt_file: {:no_warn, "priv/plts/dialyzer.plt"},
        flags: [:error_handling, :unknown, :unmatched_returns]
      ],
      preferred_cli_env: [
        "test.watch": :test,
        coveralls: :test,
        "coveralls.html": :test
      ],
      test_coverage: [tool: ExCoveralls]
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {PortfolioCore.Application, []}
    ]
  end

  defp deps do
    [
      # Core dependencies
      {:yaml_elixir, "~> 2.9"},
      {:jason, "~> 1.4"},
      {:telemetry, "~> 1.2"},
      {:nimble_options, "~> 1.0"},

      # Dev/test only
      {:ex_doc, "~> 0.31", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:stream_data, "~> 0.6", only: [:dev, :test]},
      {:mox, "~> 1.1", only: :test},
      {:excoveralls, "~> 0.18", only: :test}
    ]
  end

  defp description do
    "Hexagonal architecture core for building flexible RAG systems in Elixir."
  end

  defp package do
    [
      name: "portfolio_core",
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url},
      maintainers: ["NSHKR"],
      files: ~w(lib .formatter.exs mix.exs README.md LICENSE CHANGELOG.md)
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md", "CHANGELOG.md"],
      groups_for_modules: [
        "Ports": ~r/PortfolioCore\.Ports\./,
        "Manifest": ~r/PortfolioCore\.Manifest\./,
        "Registry": ~r/PortfolioCore\.Registry/,
        "Telemetry": ~r/PortfolioCore\.Telemetry/
      ]
    ]
  end

  defp aliases do
    [
      quality: ["format --check-formatted", "credo --strict", "dialyzer"],
      "test.all": ["quality", "test"]
    ]
  end
end
```

### 2. Port Specifications

Create the following port behaviors. Each MUST have:
- Complete `@moduledoc` with usage examples
- All callbacks with `@doc` and `@spec`
- Type definitions for all parameters

#### 2.1 Vector Store Port
`lib/portfolio_core/ports/vector_store.ex`

```elixir
defmodule PortfolioCore.Ports.VectorStore do
  @moduledoc """
  Port specification for vector storage backends.

  Implementations must handle:
  - Index creation and management
  - Vector storage with metadata
  - Similarity search (k-NN, ANN)
  - Batch operations

  ## Example Implementation

      defmodule MyApp.Adapters.Pgvector do
        @behaviour PortfolioCore.Ports.VectorStore

        @impl true
        def store(index_id, id, vector, metadata) do
          # Implementation
        end
      end
  """

  @type index_id :: String.t()
  @type vector_id :: String.t()
  @type vector :: [float()]
  @type metadata :: map()
  @type dimensions :: pos_integer()
  @type distance_metric :: :cosine | :euclidean | :dot_product

  @type search_result :: %{
    id: vector_id(),
    score: float(),
    metadata: metadata(),
    vector: vector() | nil
  }

  @type index_config :: %{
    dimensions: dimensions(),
    metric: distance_metric(),
    index_type: atom(),
    options: map()
  }

  @type index_stats :: %{
    count: non_neg_integer(),
    dimensions: dimensions(),
    metric: distance_metric(),
    size_bytes: non_neg_integer() | nil
  }

  @doc "Create a new vector index with the given configuration."
  @callback create_index(index_id(), index_config()) ::
    :ok | {:error, term()}

  @doc "Delete an index and all its vectors."
  @callback delete_index(index_id()) ::
    :ok | {:error, :not_found | term()}

  @doc "Store a vector with associated metadata."
  @callback store(index_id(), vector_id(), vector(), metadata()) ::
    :ok | {:error, term()}

  @doc "Store multiple vectors in a batch operation."
  @callback store_batch(index_id(), [{vector_id(), vector(), metadata()}]) ::
    {:ok, non_neg_integer()} | {:error, term()}

  @doc "Search for similar vectors."
  @callback search(index_id(), vector(), k :: pos_integer(), opts :: keyword()) ::
    {:ok, [search_result()]} | {:error, term()}

  @doc "Delete a vector by ID."
  @callback delete(index_id(), vector_id()) ::
    :ok | {:error, :not_found | term()}

  @doc "Get index statistics."
  @callback index_stats(index_id()) ::
    {:ok, index_stats()} | {:error, :not_found | term()}

  @doc "Check if an index exists."
  @callback index_exists?(index_id()) :: boolean()

  @optional_callbacks [index_exists?: 1]
end
```

#### 2.2 Graph Store Port
`lib/portfolio_core/ports/graph_store.ex`

```elixir
defmodule PortfolioCore.Ports.GraphStore do
  @moduledoc """
  Port specification for graph database backends.

  Supports knowledge graphs with:
  - Labeled nodes with properties
  - Typed edges with properties
  - Cypher-like query interface
  - Graph namespacing for multi-tenancy
  """

  @type graph_id :: String.t()
  @type node_id :: String.t()
  @type edge_id :: String.t()
  @type label :: String.t()
  @type properties :: map()

  @type node :: %{
    id: node_id(),
    labels: [label()],
    properties: properties()
  }

  @type edge :: %{
    id: edge_id(),
    type: String.t(),
    from_id: node_id(),
    to_id: node_id(),
    properties: properties()
  }

  @type query_result :: %{
    nodes: [node()],
    edges: [edge()],
    records: [map()]
  }

  @callback create_graph(graph_id(), config :: map()) ::
    :ok | {:error, term()}

  @callback delete_graph(graph_id()) ::
    :ok | {:error, term()}

  @callback create_node(graph_id(), node()) ::
    {:ok, node()} | {:error, term()}

  @callback create_edge(graph_id(), edge()) ::
    {:ok, edge()} | {:error, term()}

  @callback get_node(graph_id(), node_id()) ::
    {:ok, node()} | {:error, :not_found | term()}

  @callback get_neighbors(graph_id(), node_id(), opts :: keyword()) ::
    {:ok, [node()]} | {:error, term()}

  @callback query(graph_id(), query :: String.t(), params :: map()) ::
    {:ok, query_result()} | {:error, term()}

  @callback delete_node(graph_id(), node_id()) ::
    :ok | {:error, term()}

  @callback delete_edge(graph_id(), edge_id()) ::
    :ok | {:error, term()}

  @callback graph_stats(graph_id()) ::
    {:ok, map()} | {:error, term()}
end
```

#### 2.3 Document Store Port
`lib/portfolio_core/ports/document_store.ex`

```elixir
defmodule PortfolioCore.Ports.DocumentStore do
  @moduledoc """
  Port specification for document storage backends.
  """

  @type store_id :: String.t()
  @type doc_id :: String.t()
  @type content :: String.t() | binary()
  @type metadata :: map()

  @type document :: %{
    id: doc_id(),
    content: content(),
    metadata: metadata(),
    created_at: DateTime.t(),
    updated_at: DateTime.t()
  }

  @callback store(store_id(), doc_id(), content(), metadata()) ::
    {:ok, document()} | {:error, term()}

  @callback get(store_id(), doc_id()) ::
    {:ok, document()} | {:error, :not_found | term()}

  @callback delete(store_id(), doc_id()) ::
    :ok | {:error, term()}

  @callback list(store_id(), opts :: keyword()) ::
    {:ok, [document()]} | {:error, term()}

  @callback search_metadata(store_id(), query :: map()) ::
    {:ok, [document()]} | {:error, term()}
end
```

#### 2.4 Embedder Port
`lib/portfolio_core/ports/embedder.ex`

```elixir
defmodule PortfolioCore.Ports.Embedder do
  @moduledoc """
  Port specification for embedding generation backends.
  """

  @type text :: String.t()
  @type vector :: [float()]
  @type model :: String.t()

  @type embedding_result :: %{
    vector: vector(),
    model: model(),
    dimensions: pos_integer(),
    token_count: non_neg_integer()
  }

  @type batch_result :: %{
    embeddings: [embedding_result()],
    total_tokens: non_neg_integer()
  }

  @callback embed(text(), opts :: keyword()) ::
    {:ok, embedding_result()} | {:error, term()}

  @callback embed_batch([text()], opts :: keyword()) ::
    {:ok, batch_result()} | {:error, term()}

  @callback dimensions(model()) :: pos_integer()

  @callback supported_models() :: [model()]
end
```

#### 2.5 LLM Port
`lib/portfolio_core/ports/llm.ex`

```elixir
defmodule PortfolioCore.Ports.LLM do
  @moduledoc """
  Port specification for Large Language Model backends.
  """

  @type message :: %{role: :system | :user | :assistant, content: String.t()}
  @type model :: String.t()

  @type completion_result :: %{
    content: String.t(),
    model: model(),
    usage: %{
      input_tokens: non_neg_integer(),
      output_tokens: non_neg_integer()
    },
    finish_reason: :stop | :length | :tool_use
  }

  @type stream_chunk :: %{
    delta: String.t(),
    finish_reason: :stop | :length | nil
  }

  @callback complete([message()], opts :: keyword()) ::
    {:ok, completion_result()} | {:error, term()}

  @callback stream([message()], opts :: keyword()) ::
    {:ok, Enumerable.t()} | {:error, term()}

  @callback supported_models() :: [model()]

  @callback model_info(model()) :: %{
    context_window: pos_integer(),
    max_output: pos_integer(),
    supports_tools: boolean()
  }
end
```

#### 2.6 Chunker Port
`lib/portfolio_core/ports/chunker.ex`

```elixir
defmodule PortfolioCore.Ports.Chunker do
  @moduledoc """
  Port specification for document chunking strategies.
  """

  @type text :: String.t()
  @type format :: :plain | :markdown | :code | :html

  @type chunk :: %{
    content: String.t(),
    index: non_neg_integer(),
    start_offset: non_neg_integer(),
    end_offset: non_neg_integer(),
    metadata: map()
  }

  @type chunk_config :: %{
    chunk_size: pos_integer(),
    chunk_overlap: non_neg_integer(),
    separators: [String.t()] | nil
  }

  @callback chunk(text(), format(), chunk_config()) ::
    {:ok, [chunk()]} | {:error, term()}

  @callback estimate_chunks(text(), chunk_config()) ::
    non_neg_integer()
end
```

#### 2.7 Retriever Port
`lib/portfolio_core/ports/retriever.ex`

```elixir
defmodule PortfolioCore.Ports.Retriever do
  @moduledoc """
  Port specification for retrieval strategies.
  """

  @type query :: String.t()
  @type context :: map()

  @type retrieved_item :: %{
    content: String.t(),
    score: float(),
    source: String.t(),
    metadata: map()
  }

  @type retrieval_result :: %{
    items: [retrieved_item()],
    query: query(),
    strategy: atom(),
    timing_ms: non_neg_integer()
  }

  @callback retrieve(query(), context(), opts :: keyword()) ::
    {:ok, retrieval_result()} | {:error, term()}

  @callback strategy_name() :: atom()

  @callback required_adapters() :: [atom()]
end
```

#### 2.8 Reranker Port
`lib/portfolio_core/ports/reranker.ex`

```elixir
defmodule PortfolioCore.Ports.Reranker do
  @moduledoc """
  Port specification for result reranking.
  """

  @type query :: String.t()
  @type item :: %{content: String.t(), score: float(), metadata: map()}

  @type reranked_item :: %{
    content: String.t(),
    original_score: float(),
    rerank_score: float(),
    metadata: map()
  }

  @callback rerank(query(), [item()], opts :: keyword()) ::
    {:ok, [reranked_item()]} | {:error, term()}

  @callback model_name() :: String.t()
end
```

### 3. Manifest Engine

#### 3.1 Schema Definition
`lib/portfolio_core/manifest/schema.ex`

```elixir
defmodule PortfolioCore.Manifest.Schema do
  @moduledoc """
  NimbleOptions schema for manifest validation.
  """

  def adapter_schema do
    [
      adapter: [
        type: :atom,
        required: true,
        doc: "The adapter module implementing the port behavior"
      ],
      config: [
        type: :keyword_list,
        default: [],
        doc: "Adapter-specific configuration"
      ],
      enabled: [
        type: :boolean,
        default: true,
        doc: "Whether this adapter is enabled"
      ]
    ]
  end

  def manifest_schema do
    [
      version: [
        type: :string,
        required: true,
        doc: "Manifest schema version"
      ],
      environment: [
        type: :atom,
        required: true,
        doc: "Target environment (:dev, :test, :prod)"
      ],
      adapters: [
        type: :keyword_list,
        required: true,
        doc: "Adapter configurations keyed by port name"
      ],
      pipelines: [
        type: :keyword_list,
        default: [],
        doc: "Pipeline configurations"
      ],
      graphs: [
        type: :keyword_list,
        default: [],
        doc: "Graph configurations"
      ],
      telemetry: [
        type: :keyword_list,
        default: [],
        doc: "Telemetry configuration"
      ]
    ]
  end

  def validate(manifest) do
    NimbleOptions.validate(manifest, manifest_schema())
  end
end
```

#### 3.2 Manifest Loader
`lib/portfolio_core/manifest/loader.ex`

```elixir
defmodule PortfolioCore.Manifest.Loader do
  @moduledoc """
  Loads and parses manifest YAML files with environment variable expansion.
  """

  @doc """
  Load manifest from file path.
  """
  @spec load(Path.t()) :: {:ok, map()} | {:error, term()}
  def load(path) do
    with {:ok, content} <- File.read(path),
         {:ok, yaml} <- YamlElixir.read_from_string(content),
         {:ok, expanded} <- expand_env_vars(yaml) do
      {:ok, expanded}
    end
  end

  @doc """
  Expand ${VAR} patterns with environment variables.
  """
  @spec expand_env_vars(term()) :: {:ok, term()} | {:error, term()}
  def expand_env_vars(value) when is_binary(value) do
    case Regex.scan(~r/\$\{(\w+)\}/, value) do
      [] ->
        {:ok, value}

      matches ->
        result = Enum.reduce_while(matches, value, fn [full, var_name], acc ->
          case System.get_env(var_name) do
            nil -> {:halt, {:error, {:missing_env_var, var_name}}}
            val -> {:cont, String.replace(acc, full, val)}
          end
        end)

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
end
```

#### 3.3 Manifest Engine GenServer
`lib/portfolio_core/manifest/engine.ex`

```elixir
defmodule PortfolioCore.Manifest.Engine do
  @moduledoc """
  GenServer that manages manifest loading and adapter wiring.
  """

  use GenServer
  require Logger

  alias PortfolioCore.Manifest.{Loader, Schema}
  alias PortfolioCore.Registry

  defstruct [:manifest_path, :manifest, :adapters, :loaded_at]

  # Client API

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: opts[:name] || __MODULE__)
  end

  @doc "Get the currently loaded manifest."
  def get_manifest(server \\ __MODULE__) do
    GenServer.call(server, :get_manifest)
  end

  @doc "Get adapter for a specific port."
  def get_adapter(port_name, server \\ __MODULE__) do
    GenServer.call(server, {:get_adapter, port_name})
  end

  @doc "Reload the manifest from disk."
  def reload(server \\ __MODULE__) do
    GenServer.call(server, :reload)
  end

  @doc "Load a new manifest from path."
  def load(path, server \\ __MODULE__) do
    GenServer.call(server, {:load, path})
  end

  # Server callbacks

  @impl true
  def init(opts) do
    path = opts[:manifest_path]

    if path do
      case load_manifest(path) do
        {:ok, state} -> {:ok, state}
        {:error, reason} -> {:stop, {:manifest_error, reason}}
      end
    else
      {:ok, %__MODULE__{}}
    end
  end

  @impl true
  def handle_call(:get_manifest, _from, state) do
    {:reply, state.manifest, state}
  end

  @impl true
  def handle_call({:get_adapter, port_name}, _from, state) do
    adapter = Map.get(state.adapters || %{}, port_name)
    {:reply, adapter, state}
  end

  @impl true
  def handle_call(:reload, _from, %{manifest_path: nil} = state) do
    {:reply, {:error, :no_manifest_path}, state}
  end

  @impl true
  def handle_call(:reload, _from, state) do
    case load_manifest(state.manifest_path) do
      {:ok, new_state} -> {:reply, :ok, new_state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:load, path}, _from, _state) do
    case load_manifest(path) do
      {:ok, new_state} -> {:reply, :ok, new_state}
      {:error, reason} -> {:reply, {:error, reason}, _state}
    end
  end

  # Private functions

  defp load_manifest(path) do
    with {:ok, manifest} <- Loader.load(path),
         {:ok, validated} <- validate_manifest(manifest),
         {:ok, adapters} <- wire_adapters(validated) do
      state = %__MODULE__{
        manifest_path: path,
        manifest: validated,
        adapters: adapters,
        loaded_at: DateTime.utc_now()
      }

      emit_telemetry(:manifest_loaded, %{path: path, adapters: Map.keys(adapters)})

      {:ok, state}
    end
  end

  defp validate_manifest(manifest) do
    # Convert string keys to atoms for validation
    atomized = atomize_keys(manifest)

    case Schema.validate(atomized) do
      {:ok, _} -> {:ok, atomized}
      {:error, _} = err -> err
    end
  end

  defp wire_adapters(manifest) do
    adapters = manifest[:adapters] || []

    result = Enum.reduce_while(adapters, {:ok, %{}}, fn {port_name, config}, {:ok, acc} ->
      case resolve_adapter(port_name, config) do
        {:ok, adapter} ->
          Registry.register(port_name, adapter)
          {:cont, {:ok, Map.put(acc, port_name, adapter)}}

        {:error, reason} ->
          {:halt, {:error, {port_name, reason}}}
      end
    end)

    result
  end

  defp resolve_adapter(_port_name, config) do
    adapter_module = config[:adapter]

    if Code.ensure_loaded?(adapter_module) do
      {:ok, {adapter_module, config[:config] || []}}
    else
      {:error, {:module_not_found, adapter_module}}
    end
  end

  defp atomize_keys(map) when is_map(map) do
    Map.new(map, fn
      {k, v} when is_binary(k) -> {String.to_atom(k), atomize_keys(v)}
      {k, v} -> {k, atomize_keys(v)}
    end)
  end

  defp atomize_keys(list) when is_list(list) do
    Enum.map(list, &atomize_keys/1)
  end

  defp atomize_keys(value), do: value

  defp emit_telemetry(event, metadata) do
    :telemetry.execute(
      [:portfolio_core, :manifest, event],
      %{count: 1},
      metadata
    )
  end
end
```

### 4. Adapter Registry

`lib/portfolio_core/registry.ex`

```elixir
defmodule PortfolioCore.Registry do
  @moduledoc """
  ETS-based registry for adapter lookup.
  """

  use GenServer

  @table_name :portfolio_core_adapters

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Register an adapter for a port."
  @spec register(atom(), {module(), keyword()}) :: :ok
  def register(port_name, adapter) do
    :ets.insert(@table_name, {port_name, adapter})
    :ok
  end

  @doc "Get adapter for a port."
  @spec get(atom()) :: {module(), keyword()} | nil
  def get(port_name) do
    case :ets.lookup(@table_name, port_name) do
      [{^port_name, adapter}] -> adapter
      [] -> nil
    end
  end

  @doc "List all registered ports."
  @spec list_ports() :: [atom()]
  def list_ports do
    :ets.tab2list(@table_name)
    |> Enum.map(&elem(&1, 0))
  end

  @doc "Unregister an adapter."
  @spec unregister(atom()) :: :ok
  def unregister(port_name) do
    :ets.delete(@table_name, port_name)
    :ok
  end

  @doc "Clear all registrations."
  @spec clear() :: :ok
  def clear do
    :ets.delete_all_objects(@table_name)
    :ok
  end

  # Server callbacks

  @impl true
  def init(_opts) do
    table = :ets.new(@table_name, [:named_table, :public, :set])
    {:ok, %{table: table}}
  end
end
```

### 5. Telemetry Integration

`lib/portfolio_core/telemetry.ex`

```elixir
defmodule PortfolioCore.Telemetry do
  @moduledoc """
  Telemetry event definitions and helpers.
  """

  @doc """
  Execute a function wrapped in telemetry span.
  """
  defmacro with_span(name, metadata \\ %{}, do: block) do
    quote do
      start_time = System.monotonic_time()
      start_metadata = Map.merge(%{start_time: start_time}, unquote(metadata))

      :telemetry.execute(
        [:portfolio_core | unquote(name)] ++ [:start],
        %{system_time: System.system_time()},
        start_metadata
      )

      try do
        result = unquote(block)

        duration = System.monotonic_time() - start_time

        :telemetry.execute(
          [:portfolio_core | unquote(name)] ++ [:stop],
          %{duration: duration},
          Map.put(start_metadata, :result, :ok)
        )

        result
      rescue
        e ->
          duration = System.monotonic_time() - start_time

          :telemetry.execute(
            [:portfolio_core | unquote(name)] ++ [:exception],
            %{duration: duration},
            Map.merge(start_metadata, %{
              kind: :error,
              reason: e,
              stacktrace: __STACKTRACE__
            })
          )

          reraise e, __STACKTRACE__
      end
    end
  end

  @doc "List of all telemetry events emitted by portfolio_core."
  def events do
    [
      # Manifest events
      [:portfolio_core, :manifest, :loaded],
      [:portfolio_core, :manifest, :reload],
      [:portfolio_core, :manifest, :error],

      # Adapter events
      [:portfolio_core, :adapter, :call, :start],
      [:portfolio_core, :adapter, :call, :stop],
      [:portfolio_core, :adapter, :call, :exception],

      # Registry events
      [:portfolio_core, :registry, :register],
      [:portfolio_core, :registry, :lookup]
    ]
  end
end
```

### 6. Application Supervisor

`lib/portfolio_core/application.ex`

```elixir
defmodule PortfolioCore.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      PortfolioCore.Registry,
      {PortfolioCore.Manifest.Engine, manifest_opts()}
    ]

    opts = [strategy: :one_for_one, name: PortfolioCore.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp manifest_opts do
    Application.get_env(:portfolio_core, :manifest, [])
  end
end
```

### 7. Test Structure

Create comprehensive tests using Mox for all ports.

#### 7.1 Test Helper Setup
`test/test_helper.exs`

```elixir
ExUnit.start()

# Define mocks for all ports
Mox.defmock(PortfolioCore.Mocks.VectorStore, for: PortfolioCore.Ports.VectorStore)
Mox.defmock(PortfolioCore.Mocks.GraphStore, for: PortfolioCore.Ports.GraphStore)
Mox.defmock(PortfolioCore.Mocks.DocumentStore, for: PortfolioCore.Ports.DocumentStore)
Mox.defmock(PortfolioCore.Mocks.Embedder, for: PortfolioCore.Ports.Embedder)
Mox.defmock(PortfolioCore.Mocks.LLM, for: PortfolioCore.Ports.LLM)
Mox.defmock(PortfolioCore.Mocks.Chunker, for: PortfolioCore.Ports.Chunker)
Mox.defmock(PortfolioCore.Mocks.Retriever, for: PortfolioCore.Ports.Retriever)
Mox.defmock(PortfolioCore.Mocks.Reranker, for: PortfolioCore.Ports.Reranker)

Application.put_env(:portfolio_core, :mocks, %{
  vector_store: PortfolioCore.Mocks.VectorStore,
  graph_store: PortfolioCore.Mocks.GraphStore,
  document_store: PortfolioCore.Mocks.DocumentStore,
  embedder: PortfolioCore.Mocks.Embedder,
  llm: PortfolioCore.Mocks.LLM,
  chunker: PortfolioCore.Mocks.Chunker,
  retriever: PortfolioCore.Mocks.Retriever,
  reranker: PortfolioCore.Mocks.Reranker
})
```

#### 7.2 Example Port Test
`test/ports/vector_store_test.exs`

```elixir
defmodule PortfolioCore.Ports.VectorStoreTest do
  use ExUnit.Case, async: true

  import Mox

  alias PortfolioCore.Mocks.VectorStore, as: MockVectorStore

  setup :verify_on_exit!

  describe "store/4" do
    test "stores vector with metadata" do
      expect(MockVectorStore, :store, fn index_id, id, vector, metadata ->
        assert index_id == "test_index"
        assert id == "vec_1"
        assert length(vector) == 3
        assert metadata == %{source: "test"}
        :ok
      end)

      assert :ok == MockVectorStore.store(
        "test_index",
        "vec_1",
        [0.1, 0.2, 0.3],
        %{source: "test"}
      )
    end
  end

  describe "search/4" do
    test "returns ranked results" do
      results = [
        %{id: "vec_1", score: 0.95, metadata: %{}, vector: nil},
        %{id: "vec_2", score: 0.87, metadata: %{}, vector: nil}
      ]

      expect(MockVectorStore, :search, fn _index, _vector, k, _opts ->
        assert k == 10
        {:ok, results}
      end)

      assert {:ok, ^results} = MockVectorStore.search(
        "test_index",
        [0.1, 0.2, 0.3],
        10,
        []
      )
    end
  end
end
```

#### 7.3 Manifest Engine Test
`test/manifest/engine_test.exs`

```elixir
defmodule PortfolioCore.Manifest.EngineTest do
  use ExUnit.Case

  alias PortfolioCore.Manifest.Engine

  @test_manifest """
  version: "1.0"
  environment: test
  adapters:
    vector_store:
      adapter: PortfolioCore.Mocks.VectorStore
      config:
        dimensions: 1536
  """

  setup do
    # Write temp manifest file
    path = Path.join(System.tmp_dir!(), "test_manifest_#{:rand.uniform(10000)}.yml")
    File.write!(path, @test_manifest)

    on_exit(fn -> File.rm(path) end)

    {:ok, path: path}
  end

  test "loads manifest from file", %{path: path} do
    {:ok, pid} = Engine.start_link(manifest_path: path, name: :test_engine)

    manifest = Engine.get_manifest(:test_engine)

    assert manifest[:version] == "1.0"
    assert manifest[:environment] == :test

    GenServer.stop(pid)
  end

  test "expands environment variables" do
    System.put_env("TEST_API_KEY", "secret123")

    manifest = """
    version: "1.0"
    environment: test
    adapters:
      embedder:
        adapter: PortfolioCore.Mocks.Embedder
        config:
          api_key: ${TEST_API_KEY}
    """

    path = Path.join(System.tmp_dir!(), "env_manifest.yml")
    File.write!(path, manifest)

    {:ok, pid} = Engine.start_link(manifest_path: path, name: :env_engine)

    manifest = Engine.get_manifest(:env_engine)
    assert get_in(manifest, [:adapters, :embedder, :config, :api_key]) == "secret123"

    GenServer.stop(pid)
    File.rm(path)
    System.delete_env("TEST_API_KEY")
  end
end
```

### 8. Examples Directory

Create `examples/` with runnable examples:

#### 8.1 examples/README.md

```markdown
# Portfolio Core Examples

## Running Examples

All examples can be run with `mix run`:

```bash
# Basic port usage with mock adapter
mix run examples/basic_port_usage.exs

# Manifest loading
mix run examples/manifest_loading.exs

# Custom adapter implementation
mix run examples/custom_adapter.exs
```

## Examples

### basic_port_usage.exs
Demonstrates how to implement and use a simple adapter.

### manifest_loading.exs
Shows manifest-based configuration loading.

### custom_adapter.exs
Complete example of creating a custom adapter for the VectorStore port.
```

#### 8.2 examples/basic_port_usage.exs

```elixir
# Basic Port Usage Example
# Run: mix run examples/basic_port_usage.exs

defmodule Examples.InMemoryVectorStore do
  @behaviour PortfolioCore.Ports.VectorStore

  use Agent

  def start_link(_opts) do
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end

  @impl true
  def create_index(index_id, config) do
    Agent.update(__MODULE__, fn state ->
      Map.put(state, index_id, %{config: config, vectors: %{}})
    end)
    :ok
  end

  @impl true
  def delete_index(index_id) do
    Agent.update(__MODULE__, &Map.delete(&1, index_id))
    :ok
  end

  @impl true
  def store(index_id, id, vector, metadata) do
    Agent.update(__MODULE__, fn state ->
      update_in(state, [index_id, :vectors], fn vectors ->
        Map.put(vectors || %{}, id, %{vector: vector, metadata: metadata})
      end)
    end)
    :ok
  end

  @impl true
  def store_batch(index_id, items) do
    Enum.each(items, fn {id, vector, metadata} ->
      store(index_id, id, vector, metadata)
    end)
    {:ok, length(items)}
  end

  @impl true
  def search(index_id, query_vector, k, _opts) do
    vectors = Agent.get(__MODULE__, fn state ->
      get_in(state, [index_id, :vectors]) || %{}
    end)

    results = vectors
    |> Enum.map(fn {id, %{vector: vec, metadata: meta}} ->
      %{id: id, score: cosine_similarity(query_vector, vec), metadata: meta, vector: nil}
    end)
    |> Enum.sort_by(& &1.score, :desc)
    |> Enum.take(k)

    {:ok, results}
  end

  @impl true
  def delete(index_id, id) do
    Agent.update(__MODULE__, fn state ->
      update_in(state, [index_id, :vectors], &Map.delete(&1 || %{}, id))
    end)
    :ok
  end

  @impl true
  def index_stats(index_id) do
    case Agent.get(__MODULE__, &Map.get(&1, index_id)) do
      nil -> {:error, :not_found}
      index ->
        count = map_size(index.vectors || %{})
        {:ok, %{
          count: count,
          dimensions: index.config[:dimensions] || 0,
          metric: index.config[:metric] || :cosine,
          size_bytes: nil
        }}
    end
  end

  defp cosine_similarity(a, b) do
    dot = Enum.zip(a, b) |> Enum.map(fn {x, y} -> x * y end) |> Enum.sum()
    mag_a = :math.sqrt(Enum.map(a, &(&1 * &1)) |> Enum.sum())
    mag_b = :math.sqrt(Enum.map(b, &(&1 * &1)) |> Enum.sum())
    dot / (mag_a * mag_b)
  end
end

# Run the example
{:ok, _} = Examples.InMemoryVectorStore.start_link([])

IO.puts("Creating index...")
:ok = Examples.InMemoryVectorStore.create_index("demo", %{dimensions: 3, metric: :cosine})

IO.puts("Storing vectors...")
:ok = Examples.InMemoryVectorStore.store("demo", "v1", [1.0, 0.0, 0.0], %{label: "x-axis"})
:ok = Examples.InMemoryVectorStore.store("demo", "v2", [0.0, 1.0, 0.0], %{label: "y-axis"})
:ok = Examples.InMemoryVectorStore.store("demo", "v3", [0.7, 0.7, 0.0], %{label: "diagonal"})

IO.puts("Searching for similar vectors to [0.8, 0.6, 0.0]...")
{:ok, results} = Examples.InMemoryVectorStore.search("demo", [0.8, 0.6, 0.0], 3, [])

IO.puts("Results:")
Enum.each(results, fn %{id: id, score: score, metadata: meta} ->
  IO.puts("  #{id}: score=#{Float.round(score, 4)}, label=#{meta[:label]}")
end)

{:ok, stats} = Examples.InMemoryVectorStore.index_stats("demo")
IO.puts("\nIndex stats: #{inspect(stats)}")
```

### 9. Documentation

#### 9.1 README.md

Create comprehensive README.md at project root.

#### 9.2 CHANGELOG.md

```markdown
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2024-XX-XX

### Added
- Initial release
- Port specifications for VectorStore, GraphStore, DocumentStore, Embedder, LLM, Chunker, Retriever, Reranker
- Manifest engine with YAML loading and environment variable expansion
- Adapter registry with ETS-backed storage
- Telemetry integration
- Comprehensive test suite with Mox
- Examples for basic usage
```

---

## Quality Requirements

### All tests must pass:
```bash
mix test
```

### No compiler warnings:
```bash
mix compile --warnings-as-errors
```

### Credo strict must pass:
```bash
mix credo --strict
```

### Dialyzer must pass:
```bash
mix dialyzer
```

### Test coverage > 90%:
```bash
mix coveralls.html
```

---

## Deliverables Checklist

- [ ] All 8 port behaviors defined with complete @callback specs
- [ ] Manifest engine loads YAML with env var expansion
- [ ] Adapter registry provides ETS-backed lookup
- [ ] Telemetry events documented and emitted
- [ ] All tests pass with Mox mocks
- [ ] Examples run with `mix run examples/*.exs`
- [ ] README.md with installation and usage docs
- [ ] CHANGELOG.md following Keep a Changelog
- [ ] No compiler warnings
- [ ] Credo --strict passes
- [ ] Dialyzer passes
- [ ] Test coverage > 90%
