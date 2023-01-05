defmodule Cluster.Strategy.Consul.Agent do
  @moduledoc """
  This endpoint grab nodes from Consul using the
  [Agent HTTP API](https://www.consul.io/api/agent.html).
  """

  use Cluster.Strategy.Consul.Endpoint

  @impl true
  def build_url(%URI{query: query} = url, config) do
    case {config[:service], config[:passing]} do
      {[id: id], _} ->
        %{url | path: "/agent/service/#{id}"}

      {[name: name], true} ->
        %{
          url
          | path: "/agent/health/service/name/#{name}",
            query:
              (query || "")
              |> URI.decode_query(%{"passing" => true})
              |> URI.encode_query()
        }

      {[name: name], _} ->
        %{
          url
          | path: "/agent/health/service/name/#{name}"
        }

      {val, _} ->
        raise(
          ArgumentError,
          "Cluster.Strategy.Consul.Agent is configured. Expected service: [id: service_id] || [name: name] but received service: #{val}"
        )
    end
  end

  @impl true
  def parse_response(response, _config) when is_list(response) do
    response
    |> Enum.map(fn
      %{"Service" => %{"Address" => ip}} -> ip
    end)
  end

  def parse_response(%{"Address" => ip}, _), do: [ip]
end
