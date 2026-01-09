# Example: Graph Store port (in-memory adapter)
# Run: mix run examples/graph_store_port.exs

defmodule Examples.InMemoryGraphStore do
  @moduledoc false
  @behaviour PortfolioCore.Ports.GraphStore

  use Agent

  def start_link(_opts) do
    Agent.start_link(fn -> %{graphs: %{}} end, name: __MODULE__)
  end

  @impl true
  def create_graph(graph_id, config) do
    Agent.update(__MODULE__, fn state ->
      graphs = Map.put(state.graphs, graph_id, %{config: config, nodes: %{}, edges: %{}})
      %{state | graphs: graphs}
    end)

    :ok
  end

  @impl true
  def delete_graph(graph_id) do
    Agent.update(__MODULE__, fn state ->
      %{state | graphs: Map.delete(state.graphs, graph_id)}
    end)

    :ok
  end

  @impl true
  def create_node(graph_id, node) do
    Agent.get_and_update(__MODULE__, fn state ->
      graph = Map.get(state.graphs, graph_id, %{config: %{}, nodes: %{}, edges: %{}})
      nodes = Map.put(graph.nodes, node.id, node)
      updated = %{graph | nodes: nodes}
      {node, put_in(state.graphs[graph_id], updated)}
    end)
    |> case do
      node -> {:ok, node}
    end
  end

  @impl true
  def create_edge(graph_id, edge) do
    Agent.get_and_update(__MODULE__, fn state ->
      graph = Map.get(state.graphs, graph_id, %{config: %{}, nodes: %{}, edges: %{}})
      edges = Map.put(graph.edges, edge.id, edge)
      updated = %{graph | edges: edges}
      {edge, put_in(state.graphs[graph_id], updated)}
    end)
    |> case do
      edge -> {:ok, edge}
    end
  end

  @impl true
  def get_node(graph_id, node_id) do
    Agent.get(__MODULE__, fn state ->
      case get_in(state, [:graphs, graph_id, :nodes, node_id]) do
        nil -> {:error, :not_found}
        node -> {:ok, node}
      end
    end)
  end

  @impl true
  def get_neighbors(graph_id, node_id, opts) do
    direction = Keyword.get(opts, :direction, :outgoing)
    edge_types = Keyword.get(opts, :edge_types)
    limit = Keyword.get(opts, :limit)

    graph = get_graph(graph_id)
    {:ok, nodes, _edges} = neighbors_in_graph(graph, node_id, direction, edge_types)
    nodes = if limit, do: Enum.take(nodes, limit), else: nodes
    {:ok, nodes}
  end

  @impl true
  def query(graph_id, _query, _params) do
    graph = get_graph(graph_id)

    {:ok,
     %{
       nodes: Map.values(graph.nodes),
       edges: Map.values(graph.edges),
       records: []
     }}
  end

  @impl true
  def delete_node(graph_id, node_id) do
    Agent.update(__MODULE__, fn state ->
      graph = get_graph(graph_id, state)

      edges =
        graph.edges
        |> Enum.reject(fn {_id, edge} -> edge.from_id == node_id or edge.to_id == node_id end)
        |> Map.new()

      updated = %{graph | nodes: Map.delete(graph.nodes, node_id), edges: edges}
      put_in(state.graphs[graph_id], updated)
    end)

    :ok
  end

  @impl true
  def delete_edge(graph_id, edge_id) do
    Agent.update(__MODULE__, fn state ->
      graph = get_graph(graph_id, state)
      updated = %{graph | edges: Map.delete(graph.edges, edge_id)}
      put_in(state.graphs[graph_id], updated)
    end)

    :ok
  end

  @impl true
  def graph_stats(graph_id) do
    graph = get_graph(graph_id)

    {:ok,
     %{
       node_count: map_size(graph.nodes),
       edge_count: map_size(graph.edges)
     }}
  end

  @impl true
  def traverse(graph_id, node_id, opts) do
    direction = Keyword.get(opts, :direction, :outgoing)
    algorithm = Keyword.get(opts, :algorithm, :bfs)
    max_depth = Keyword.get(opts, :max_depth, 1)
    edge_types = Keyword.get(opts, :edge_types)
    limit = Keyword.get(opts, :limit)

    graph = get_graph(graph_id)

    {order, _} =
      traverse_nodes(
        graph,
        [node_id],
        MapSet.new(),
        %{},
        direction,
        algorithm,
        max_depth,
        edge_types,
        []
      )

    nodes =
      order
      |> Enum.map(&Map.get(graph.nodes, &1))
      |> Enum.reject(&is_nil/1)
      |> maybe_limit(limit)

    {:ok, nodes}
  end

  @impl true
  def vector_search(graph_id, embedding, opts) do
    k = Keyword.get(opts, :k, 5)
    labels = Keyword.get(opts, :labels)

    graph = get_graph(graph_id)

    nodes =
      graph.nodes
      |> Map.values()
      |> maybe_filter_labels(labels)
      |> Enum.map(fn node ->
        properties = node.properties || %{}
        score = cosine_similarity(embedding, Map.get(properties, :embedding, []))
        {score, node}
      end)
      |> Enum.filter(fn {score, _node} -> is_float(score) end)
      |> Enum.sort_by(fn {score, _node} -> score end, :desc)
      |> Enum.take(k)
      |> Enum.map(fn {_score, node} -> node end)

    {:ok, nodes}
  end

  defp get_graph(graph_id) do
    Agent.get(__MODULE__, &get_graph(graph_id, &1))
  end

  defp get_graph(graph_id, state) do
    Map.get(state.graphs, graph_id, %{config: %{}, nodes: %{}, edges: %{}})
  end

  defp neighbors_in_graph(graph, node_id, direction, edge_types) do
    edges =
      graph.edges
      |> Map.values()
      |> Enum.filter(fn edge ->
        matches_type?(edge, edge_types) and matches_direction?(edge, node_id, direction)
      end)

    node_ids =
      edges
      |> Enum.flat_map(fn edge ->
        case direction do
          :incoming -> [edge.from_id]
          :outgoing -> [edge.to_id]
          :both -> [edge.from_id, edge.to_id]
        end
      end)
      |> Enum.uniq()
      |> Enum.reject(&(&1 == node_id))

    nodes = Enum.map(node_ids, &Map.get(graph.nodes, &1)) |> Enum.reject(&is_nil/1)
    {:ok, nodes, edges}
  end

  defp matches_type?(_edge, nil), do: true

  defp matches_type?(edge, types) when is_list(types) do
    edge.type in types
  end

  defp matches_type?(edge, type), do: edge.type == type

  defp matches_direction?(edge, node_id, :incoming), do: edge.to_id == node_id
  defp matches_direction?(edge, node_id, :outgoing), do: edge.from_id == node_id

  defp matches_direction?(edge, node_id, :both),
    do: edge.from_id == node_id or edge.to_id == node_id

  defp traverse_nodes(_graph, [], _visited, depth_map, _direction, _algo, _max, _types, order) do
    {Enum.reverse(order), depth_map}
  end

  defp traverse_nodes(
         graph,
         [current | rest],
         visited,
         depth_map,
         direction,
         algo,
         max_depth,
         edge_types,
         order
       ) do
    if MapSet.member?(visited, current) do
      traverse_nodes(
        graph,
        rest,
        visited,
        depth_map,
        direction,
        algo,
        max_depth,
        edge_types,
        order
      )
    else
      current_depth = Map.get(depth_map, current, 0)

      {next_nodes, _edges} =
        if current_depth >= max_depth do
          {[], []}
        else
          {:ok, nodes, _edges} = neighbors_in_graph(graph, current, direction, edge_types)
          {Enum.map(nodes, & &1.id), []}
        end

      {queue, depth_map} =
        next_nodes
        |> Enum.reject(&MapSet.member?(visited, &1))
        |> Enum.reduce({rest, depth_map}, fn node_id, {queue_acc, depth_acc} ->
          depth_acc = Map.put(depth_acc, node_id, current_depth + 1)

          queue_acc =
            case algo do
              :dfs -> [node_id | queue_acc]
              _ -> queue_acc ++ [node_id]
            end

          {queue_acc, depth_acc}
        end)

      visited = MapSet.put(visited, current)

      traverse_nodes(
        graph,
        queue,
        visited,
        depth_map,
        direction,
        algo,
        max_depth,
        edge_types,
        [current | order]
      )
    end
  end

  defp maybe_filter_labels(nodes, nil), do: nodes

  defp maybe_filter_labels(nodes, labels) when is_list(labels) do
    Enum.filter(nodes, fn node -> Enum.any?(labels, &(&1 in (node.labels || []))) end)
  end

  defp maybe_filter_labels(nodes, label) do
    Enum.filter(nodes, fn node -> Enum.member?(node.labels || [], label) end)
  end

  defp maybe_limit(nodes, nil), do: nodes
  defp maybe_limit(nodes, limit), do: Enum.take(nodes, limit)

  defp cosine_similarity([], _), do: nil
  defp cosine_similarity(_, []), do: nil

  defp cosine_similarity(a, b) when length(a) == length(b) do
    dot = Enum.zip(a, b) |> Enum.reduce(0.0, fn {x, y}, acc -> acc + x * y end)
    mag_a = :math.sqrt(Enum.reduce(a, 0.0, fn x, acc -> acc + x * x end))
    mag_b = :math.sqrt(Enum.reduce(b, 0.0, fn x, acc -> acc + x * x end))

    if mag_a == 0.0 or mag_b == 0.0 do
      nil
    else
      dot / (mag_a * mag_b)
    end
  end

  defp cosine_similarity(_, _), do: nil
end

IO.puts(String.duplicate("=", 60))
IO.puts("Portfolio Core - Graph Store Example")
IO.puts(String.duplicate("=", 60))

{:ok, _} = Examples.InMemoryGraphStore.start_link([])

graph_id = "knowledge"
:ok = Examples.InMemoryGraphStore.create_graph(graph_id, %{})

{:ok, _} =
  Examples.InMemoryGraphStore.create_node(graph_id, %{
    id: "alice",
    labels: ["Person"],
    properties: %{}
  })

{:ok, _} =
  Examples.InMemoryGraphStore.create_node(graph_id, %{
    id: "bob",
    labels: ["Person"],
    properties: %{}
  })

{:ok, _} =
  Examples.InMemoryGraphStore.create_edge(graph_id, %{
    id: "edge-1",
    type: "KNOWS",
    from_id: "alice",
    to_id: "bob",
    properties: %{since: 2021}
  })

{:ok, neighbors} =
  Examples.InMemoryGraphStore.get_neighbors(graph_id, "alice", direction: :outgoing)

IO.puts("\nNeighbors of alice:")
IO.inspect(Enum.map(neighbors, & &1.id))

{:ok, traversed} = Examples.InMemoryGraphStore.traverse(graph_id, "alice", max_depth: 2)
IO.puts("\nTraverse from alice:")
IO.inspect(Enum.map(traversed, & &1.id))

{:ok, stats} = Examples.InMemoryGraphStore.graph_stats(graph_id)
IO.puts("\nGraph stats:")
IO.inspect(stats)

IO.puts("\n" <> String.duplicate("=", 60))
IO.puts("Example completed successfully!")
IO.puts(String.duplicate("=", 60))
