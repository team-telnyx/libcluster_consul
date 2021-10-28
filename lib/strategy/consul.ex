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
                Cluster.Strategy.Consul.Agent,

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

              # The default service_name for children endpoints specifications.
              service_name: "my-service",

              # This is the node basename, the Name (first) part of an Erlang
              # node name (before the @ part. If not specified, it will assume
              # the same name as the current running node.
              node_basename: "app_name",

              # This is the EEx template used to build the node names. The
              # variables `ip`, `dc` and `node_basename` are available to
              # compose the node name.
              node_name_template: "<%= node_basename =>@<%= ip =>"
            ]]]
  """

  use GenServer
  use Cluster.Strategy

  alias Cluster.Strategy.State

  @callback get_nodes(%State{}) :: [atom()]

  @default_polling_interval 5_000
  @default_base_url "http://localhost:8500"
  @default_node_name_template "<%= node_basename %>@<%= ip %>"

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
        [{to_charlist("authorization"), to_charlist("Bearer #{access_token}")}]
    end
  end

  def node_name(ip, config) do
    template = Keyword.get(config, :node_name_template, @default_node_name_template)

    opts = [
      ip: ip,
      dc: Keyword.get(config, :dc),
      node_basename: Keyword.fetch!(config, :node_basename)
    ]

    :"#{EEx.eval_string(template, opts)}"
  end
end
