defmodule Cluster.Strategy.Consul.Endpoint do
  alias Cluster.Strategy.{Consul, State}

  import Cluster.Logger

  @type ip :: String.t()

  @callback build_url(URI.t(), Keyword.t()) :: URI.t()

  @callback parse_response([map], Keyword.t()) :: [ip]

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
    url =
      config
      |> Consul.base_url()
      |> module.build_url(config)
      |> (&Map.put(&1, :path, "/v1" <> &1.path)).()
      |> to_string()

    headers =
      config
      |> Consul.headers()

    disable_verify_ssl? = Keyword.get(config, :disable_verify_ssl?, false)

    opts =
      if disable_verify_ssl? do
        [{:ssl, [{:verify, :verify_none}]}]
      else
        []
      end

    case :httpc.request(
           :get,
           {to_charlist(url), headers},
           opts,
           []
         ) do
      {:ok, {{_version, 200, _status}, _headers, body}} ->
        body
        |> Jason.decode!()
        |> module.parse_response(config)
        |> Enum.map(&Consul.node_name(&1, config))

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
