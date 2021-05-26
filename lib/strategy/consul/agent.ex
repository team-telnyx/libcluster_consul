defmodule Cluster.Strategy.Consul.Agent do
  @moduledoc """
  This endpoint grab nodes from Consul using the
  [Agent HTTP API](https://www.consul.io/api/agent.html).
  """

  use Cluster.Strategy.Consul.Endpoint

  @impl true
  def build_url(%URI{} = url, config) do
    %{url | path: "/agent/service/#{config[:service_name]}"}
  end

  @impl true
  def parse_response(%{"Address" => ip}, _), do: [ip]
end
