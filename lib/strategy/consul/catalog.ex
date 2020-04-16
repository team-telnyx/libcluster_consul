defmodule Cluster.Strategy.Consul.Catalog do
  @moduledoc """
  This endpoint grab nodes from Consul using the
  [Catalog HTTP API](https://www.consul.io/api/catalog.html).
  """

  use Cluster.Strategy.Consul.Endpoint

  @impl true
  def build_url(%URI{} = url, config) do
    %{url | path: "/catalog/service/#{config[:service_name]}"}
  end

  @impl true
  def parse_response(response) when is_list(response) do
    response
    |> Enum.map(fn %{"ServiceAddress" => ip} -> ip end)
  end
end
