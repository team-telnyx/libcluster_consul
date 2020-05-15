defmodule Cluster.Strategy.Consul.Multisite do
  @moduledoc """
  This endpoint grab nodes from multiple datacenters using a list of Consul
  endpoints.
  """

  @behaviour Cluster.Strategy.Consul

  import Cluster.Logger

  alias Cluster.Strategy.{Consul, State}

  @impl true
  def get_nodes(%State{topology: topology, config: config} = state) do
    datacenters =
      case Keyword.get(config, :datacenters, :all) do
        :all ->
          list_all_datacenters(topology, config)

        datacenters when is_list(datacenters) ->
          datacenters
      end


    endpoints = Keyword.fetch!(config, :endpoints)

    datacenters
    |> Enum.flat_map(fn datacenter ->
      config =
        config
        |> Keyword.put(:dc, datacenter)

      Enum.flat_map(endpoints, fn
        {endpoint, opts} ->
          endpoint.get_nodes(%{state | config: Keyword.merge(config, opts)})

        endpoint ->
          endpoint.get_nodes(%{state | config: config})
      end)
    end)
  end

  defp list_all_datacenters(topology, config) do
    url =
      config
      |> Consul.base_url()
      |> Map.put(:path, "/v1/catalog/datacenters")
      |> to_string()

    headers =
      config
      |> Consul.headers()

    case :httpc.request(:get, {to_charlist(url), headers}, [], []) do
      {:ok, {{_version, 200, _status}, _headers, body}} ->
        body
        |> Jason.decode!()

      {:ok, {{_version, code, status}, _headers, body}} ->
        warn(
          topology,
          "cannot query Consul (#{code} #{status}): #{inspect(body)}"
        )

        []

      {:error, reason} ->
        error(topology, "request to Consul failed!: #{inspect(reason)}")

        []
    end
  end
end
