defmodule ClusterConsul.Strategy do
  use Cluster.Strategy
  use GenServer

  alias Cluster.Strategy.State
  import Cluster.Logger

  @default_polling_interval 5_000

  @impl Cluster.Strategy
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @impl GenServer
  def init(opts) do
    state = %State{
      topology: Keyword.fetch!(opts, :topology),
      connect: Keyword.fetch!(opts, :connect),
      disconnect: Keyword.fetch!(opts, :disconnect),
      list_nodes: Keyword.fetch!(opts, :list_nodes),
      config: Keyword.fetch!(opts, :config),
      meta: MapSet.new()
    }
    name = Keyword.fetch!(state.config, :service_name)
    port = Keyword.get(state.config, :service_port, 0)
    _check = Keyword.fetch(state.config, :check)

    info state.topology, "Registering/updating consul service: #{name}"
    register(name, port)
    update_check(name, :passing, "Erlang node (#{node()}) is running")

    {:ok, state, 0}
  end

  @impl GenServer
  def handle_info(:timeout, state) do
    handle_info(:update_check, state)
    handle_info(:load, state)
  end

  def handle_info(:load, %State{topology: topology, connect: connect, disconnect: disconnect, list_nodes: list_nodes} = state) do
    name = Keyword.fetch!(state.config, :service_name)
    new_nodelist =
      case get_nodes(name) do
        {:ok, node_info} ->
          node_info
          |> Enum.map(&ip_to_node(&1["Node"]["Address"]))
          |> MapSet.new()
        {:error, reason} ->
          error topology, reason
      end

    added   = MapSet.difference(new_nodelist, state.meta)
    removed = MapSet.difference(state.meta, new_nodelist)

    new_nodelist =
      case Cluster.Strategy.disconnect_nodes(topology, disconnect, list_nodes, MapSet.to_list(removed)) do
        :ok ->
          new_nodelist
        {:error, bad_nodes} ->
          # Add back the nodes which should have been removed, but which couldn't be for some reason
          Enum.reduce(bad_nodes, new_nodelist, fn {n, _}, acc ->
            MapSet.put(acc, n)
          end)
      end
    new_nodelist =
      case Cluster.Strategy.connect_nodes(topology, connect, list_nodes, MapSet.to_list(added)) do
        :ok ->
          new_nodelist
        {:error, bad_nodes} ->
          # Remove the nodes which should have been added, but couldn't be for some reason
          Enum.reduce(bad_nodes, new_nodelist, fn {n, _}, acc ->
            MapSet.delete(acc, n)
          end)
      end

    polling_interval = Keyword.get(state.config, :polling_interval, @default_polling_interval)
    Process.send_after(self(), :load, polling_interval)
    {:noreply, %{state | meta: new_nodelist}}
  end

  def handle_info(:update_check, state) do
    name = Keyword.fetch!(state.config, :service_name)
    update_check(name, :passing, "Erlang node (#{node()}) is running")
    Process.send_after(self(), :update_check, 5_000)
    {:noreply, state}
  end

  def handle_info(_, state) do
    {:noreply, state}
  end

  @impl GenServer
  def terminate(reason, state) do
    name = Keyword.fetch!(state.config, :service_name)
    output = "Terminated with reason: #{inspect reason}"
    update_check(name, :critical, output)
  end

  def register(name, port) do
    url = agent_url("/agent/service/register")
    headers = []
    content_type = ''
    body = Poison.encode!(register_payload(name, port))
    request = {to_charlist(url), headers, content_type, body}
    :httpc.request(:put, request, [], [])
  end

  def register_payload(name, port) do
    check =
      %{CheckId: "#{name}:erlang-node",
        Name: "Erlang Node Status",
        TTL: "10s"}
    %{name: name, port: port, checks: [check]}
  end

  @doc """
  Status values are "passing", "warning", and "critical".
  """
  def update_check(service_name, status, output) do
    check_name = "#{service_name}:erlang-node"
    url = agent_url("/agent/check/update/#{check_name}")
    headers = []
    content_type = ''
    body = Poison.encode!(%{Status: status, Output: output})
    request = {to_charlist(url), headers, content_type, body}
    :httpc.request(:put, request, [], [])
  end

  def get_nodes(name) do
    url = agent_url("/health/service/#{name}?passing=true")
    headers = []
    response = :httpc.request(:get, {to_charlist(url), headers}, [], [])
    case response do
      {:ok, {{_version, 200, _status}, _headers, body}} ->
        {:ok, Poison.decode!(body)}
      {:ok, {{_version, code, status}, _headers, body}} ->
        {:error, "cannot query consul agent (#{code} #{status}): #{inspect body}"}
      {:error, reason} ->
        {:error, "request to consul agent failed: #{inspect reason}"}
    end
  end

  def agent_url(path) do
    "http://localhost:8500/v1#{path}"
  end

  def ip_to_node(ip) do
    [n, _] = node() |> to_string() |> String.split("@")
    :"#{n}@#{ip}"
  end
end
