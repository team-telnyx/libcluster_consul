defmodule Cluster.Strategy.Consul do
  @moduledoc """
  This clustering strategy is specific to the Consul service networking
  solution. It works by querying the platform's metadata API for containers
  belonging to a given service name and attempts to connect them
  (see: https://www.consul.io/api/catalog.html).

  There is also the option to require connecting to nodes from different
  datacenters, or you can stick to a single datacenter.

  It assumes that all nodes share a base name and are using longnames of the
  form `<basename>@<ip>` where the `<ip>` is unique for each node.

  The Consul service registration isn't part of this module as there are many
  different ways to accomplish that, so it is assumed you'll do that from
  another part of your application.

  An example configuration is below:
      config :libcluster,
        topologies: [
          consul_example: [
            strategy: #{__MODULE__},
            config: [
              # The base agent URL.
              base_url: "http://consul.service.dc1.consul:8500",

              # If authentication is needed, set the access token here.
              access_token: "036c943f00594d9f97c10dec7e48ff19",

              # Nodes list will be refreshed using Consul on each interval.
              polling_interval: 10_000,

              # The Consul endpoints used to fetch service nodes.
              list_using: [
                # If you want to use the Agent HTTP API as specified in
                # https://www.consul.io/api/agent.html
                Cluster.Strategy.Consul.Agent

                # If you want to use the Health HTTP Endpoint as specified in
                # https://www.consul.io/api/health.html
                {Cluster.Strategy.Consul.Health, [passing: true]},

                # If you want to use the Catalog HTTP API as specified in
                # https://www.consul.io/api/catalog.html
                Cluster.Strategy.Consul.Catalog,

                # If you want to join nodes from multiple datacenters, do:
                {Cluster.Strategy.Consul.Multisite, [
                  datacenters: ["dc1", "dc2", "dc3", ...],
                  endpoints: [
                    ... further endpoints ...
                  ]
                ]},

                # You can also list all datacenters:
                {Cluster.Strategy.Consul.Multisite, [
                  datacenters: :all,
                  endpoints: [
                    ... further endpoints ...
                  ]
                ]},
              ]

              # All configurations below are defined as default for all
              # children endpoints.

              # Datacenter parameter while querying.
              dc: "dc1",

              # The default service for children endpoints specifications.
              service: [name: "service_name"],

              # NOTE:
              # Alternatively one could specify id for the service using
              # service: [id: "service_id"]
              # The keyword list should contain only one of them, either id or name.

              # This is the node basename, the Name (first) part of an Erlang
              # node name (before the @ part. If not specified, it will assume
              # the same name as the current running node.
              # The final node name will be "node_basename@<host_or_ip>"
              node_basename: "app_name",
            ]]]


  The generic response of the Consul endpoints includes respective service's hostname of the node as well as it's IP.
  It is possible to establish connection using hostname exclusively by using following configuration.
  To retrieve only passing services `:passing` can be set to true which might be ignored
  if the API endpoint does not support health status.
  ```
  {Cluster.Strategy.Consul.Agent, [expected: :host, passing: true]}
  ```
  """

  use GenServer
  use Cluster.Strategy

  alias Cluster.Strategy.State

  @callback get_nodes(%State{}) :: [atom()]

  @default_polling_interval 5_000
  @default_base_url "http://localhost:8500"

  def start_link(args), do: GenServer.start_link(__MODULE__, args)

  @impl true
  def init([%State{meta: nil} = state]), do: init([%State{state | :meta => MapSet.new()}])

  def init([%State{config: config} = state]) do
    state =
      case Keyword.get(config, :node_basename) do
        nil ->
          [node_basename, _] =
            node()
            |> to_string()
            |> String.split("@")

          %{state | config: Keyword.put(config, :node_basename, node_basename)}

        app_name when is_binary(app_name) and app_name != "" ->
          state

        app_name ->
          raise ArgumentError,
                "Consul strategy is selected, but :node_basename" <>
                  " is invalid, got: #{inspect(app_name)}"
      end

    {:ok, state, 0}
  end

  @impl true
  def handle_info(:timeout, state), do: {:noreply, load(state), polling_interval(state)}

  defp load(
         %State{
           topology: topology,
           connect: connect,
           disconnect: disconnect,
           list_nodes: list_nodes
         } = state
       ) do
    new_nodelist = MapSet.new(get_nodes(state))
    removed = MapSet.difference(state.meta, new_nodelist)

    new_nodelist =
      case Cluster.Strategy.disconnect_nodes(
             topology,
             disconnect,
             list_nodes,
             MapSet.to_list(removed)
           ) do
        :ok ->
          new_nodelist

        {:error, bad_nodes} ->
          # Add back the nodes which should have been removed, but which couldn't be for some reason
          Enum.reduce(bad_nodes, new_nodelist, fn {n, _}, acc ->
            MapSet.put(acc, n)
          end)
      end

    new_nodelist =
      case Cluster.Strategy.connect_nodes(
             topology,
             connect,
             list_nodes,
             MapSet.to_list(new_nodelist)
           ) do
        :ok ->
          new_nodelist

        {:error, bad_nodes} ->
          # Remove the nodes which should have been added, but couldn't be for some reason
          Enum.reduce(bad_nodes, new_nodelist, fn {n, _}, acc ->
            MapSet.delete(acc, n)
          end)
      end

    %{state | meta: new_nodelist}
  end

  def get_nodes(%State{config: config} = state) do
    config
    |> Keyword.fetch!(:list_using)
    |> Enum.flat_map(fn
      {endpoint, opts} ->
        endpoint.get_nodes(%{state | config: Keyword.merge(config, opts)})

      endpoint ->
        endpoint.get_nodes(state)
    end)
  end

  defp polling_interval(%{config: config}) do
    Keyword.get(config, :polling_interval, @default_polling_interval)
  end

  def base_url(config) do
    base_url =
      config
      |> Keyword.get(:base_url, @default_base_url)
      |> URI.parse()

    case Keyword.get(config, :dc) do
      nil ->
        base_url

      dc ->
        query =
          (base_url.query || "")
          |> URI.decode_query(%{"dc" => dc})
          |> URI.encode_query()

        %{base_url | query: query}
    end
  end

  def headers(config) do
    case Keyword.get(config, :access_token) do
      nil ->
        []

      access_token ->
        [{to_charlist("X-Consul-Token"), to_charlist("#{access_token}")}]
    end
  end

  def node_name(host_or_ip, config) do
    :"#{Keyword.fetch!(config, :node_basename)}@#{host_or_ip}"
  end
end
