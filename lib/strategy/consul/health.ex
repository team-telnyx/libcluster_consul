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
    case {config[:service], config[:passing]} do
      {[name: name], true} ->
        %{
          url
          | path: "/health/service/#{name}",
            query:
              (query || "")
              |> URI.decode_query(%{"passing" => true})
              |> URI.encode_query()
        }

      {[name: name], _} ->
        %{url | path: "/health/service/#{name}"}

      val ->
        raise(
          ArgumentError,
          "Cluster.Strategy.Consul.Agent is configured. Expected service: [name: name] but received service: #{val}"
        )
    end
  end

  @impl true
  def parse_response(response, config) when is_list(response) do
    # Fallback to node address when service address is not defined. This mirrors consul's
    # dns behaviour.
    Enum.map(response, fn
      %{"Service" => %{"Address" => ""}, "Node" => %{"Node" => host, "Address" => ip}} ->
        case config[:expected] do
          :host ->
            host

          _ ->
            ip
        end

      %{"Service" => %{"Address" => ip}} ->
        ip
    end)
  end
end
