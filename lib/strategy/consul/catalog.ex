defmodule Cluster.Strategy.Consul.Catalog do
  @moduledoc """
  This endpoint grab nodes from Consul using the
  [Catalog HTTP API](https://www.consul.io/api/catalog.html).
  """

  use Cluster.Strategy.Consul.Endpoint

  @impl true
  def build_url(%URI{} = url, config) do
    case config[:service] do
      [name: name] ->
        %{url | path: "/catalog/service/#{name}"}

      val ->
        raise(
          ArgumentError,
          "Cluster.Strategy.Consul.Catalog is configured. Expected service: [name: service_name] but received #{val}"
        )
    end
  end

  @impl true
  def parse_response(response, config) when is_list(response) do
    case config[:expected] do
      :host ->
        response
        |> Enum.map(fn %{"Node" => host} -> host end)

      _ ->
        response
        |> Enum.map(fn %{"Address" => ip} -> ip end)
    end
  end
end
