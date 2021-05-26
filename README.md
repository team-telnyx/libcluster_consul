# Libcluster Consul Strategy

This module implements generic a [libcluster](https://github.com/bitwalker/libcluster) Consul Strategy.

## Features

- Supports [Agent HTTP API](https://www.consul.io/api/agent.html), [Catalog HTTP API](https://www.consul.io/api/catalog.html) and [Health HTTP API](https://www.consul.io/api/health.html)
- Supports multisites (i.e. multiple datacenters), including taking them dynamically by [listing all datacenters available](https://www.consul.io/api/catalog.html#list-datacenters).

## Example Configuration

There are multiple ways to configure the Consul strategy on `libcluster`:

```elixir
config :libcluster,
  topologies: [
    consul_example: [
      strategy: Cluster.Strategy.Consul,
      config: [
        # The base agent URL.
        base_url: "http://consul.service.dc1.consul:8500",

        # If authentication is needed, set the access token here.
        access_token: "036c943f00594d9f97c10dec7e48ff19",

        # Nodes list will be refreshed using Consul on each interval (in µs).
        # Defaults to 5 seconds.
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
        node_basename: "app_name"

        # Which consul response key should be considered as node
        # hostname (after the @ part). Accepted values: :ip
        # or :node_name. Default :ip.
        host_key: :ip
      ]]]
```

## Installation

```elixir
def deps do
  [
    {:libcluster_consul, "~> 1.0.0"}
  ]
end
```

You can determine the latest version by running `mix hex.info libcluster_consul` in your shell, or by going to the `libcluster_consul` [page on Hex.pm](https://hex.pm/packages/libcluster_consul).

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc) and published on [HexDocs](https://hexdocs.pm). Once published, the docs can be found at [https://hexdocs.pm/libcluster_consul](https://hexdocs.pm/libcluster_consul).
