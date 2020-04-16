defmodule Cluster.Strategy.Consul.Endpoint do
  alias Cluster.Strategy.{Consul, State}

  import Cluster.Logger

  @type ip :: String.t()

  @callback build_url(URI.t(), Cluster.Strategy.Consul.options()) :: URI.t()

  @callback parse_response([map]) :: [ip]

  defmacro __using__(_opts) do
    quote do
      @behaviour Cluster.Strategy.Consul
      @behaviour Cluster.Strategy.Consul.Endpoint

      @impl true
      def get_nodes(state),
        do: Cluster.Strategy.Consul.Endpoint.get_nodes(__MODULE__, state)
    end
  end

  def get_nodes(module, %State{topology: topology, config: config}) do
    case Keyword.fetch!(config, :node_basename) do
      app_name when is_binary(app_name) and app_name != "" ->
        get_nodes(module, topology, config, app_name)

      app_name ->
        warn(
          topology,
          "Consul strategy is selected, but :node_basename is invalid, got: #{inspect(app_name)}"
        )

        []
    end
  end

  defp get_nodes(module, topology, config, app_name) do
    url =
      config
      |> Consul.base_url()
      |> module.build_url(config)
      |> (&Map.put(&1, :path, "/v1" <> &1.path)).()
      |> to_string()

    headers =
      config
      |> Consul.headers()

    case :httpc.request(:get, {to_charlist(url), headers}, [], []) do
      {:ok, {{_version, 200, _status}, _headers, body}} ->
        body
        |> Jason.decode!()
        |> module.parse_response()
        |> Enum.map(&:"#{app_name}@#{&1}")

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
