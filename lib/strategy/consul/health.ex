defmodule Cluster.Strategy.Consul.Health do
  @moduledoc """
  This endpoint grab nodes from Consul using the
  [Health HTTP API](https://www.consul.io/api/health.html).

  The only extra parameter adopted by this endpoint is the `passing` option. If
  true, it grabs only healthy nodes.
  """

  use Cluster.Strategy.Consul.Endpoint

  @impl true
  def build_url(%URI{query: query} = url, config) do
    query =
      case Keyword.get(config, :passing) do
        true ->
          (query || "")
          |> URI.decode_query(%{"passing" => true})
          |> URI.encode_query()

        _ ->
          query
      end

    %{url | path: "/health/service/#{config[:service_name]}", query: query}
  end

  @impl true
  def parse_response(response, :node_name) when is_list(response) do
    Enum.map(response, fn
      %{"Node" => %{"Node" => node}} -> node
    end)
  end

  @impl true
  def parse_response(response, _) when is_list(response) do
    # Fallback to node address when service address is not defined. This mirrors consul's
    # dns behaviour.
    Enum.map(response, fn
      %{"Service" => %{"Address" => ""}, "Node" => %{"Address" => ip}} -> ip
      %{"Service" => %{"Address" => ip}} -> ip
    end)
  end
end
