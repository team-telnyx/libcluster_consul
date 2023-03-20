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

        # The default service for children endpoints specifications.
        service: [name: "service_name"],

        # Apply filtering
        filter: ~s("canary" version in Service.Tags),

        # NOTE:
        # Alternatively one could specify id for the service using
        # service: [id: "service_id"]
        # The keyword list should contain only one of them, either id or name.

        # This is the node basename, the Name (first) part of an Erlang
        # node name (before the @ part. If not specified, it will assume
        # the same name as the current running node.
        # The final node name will be "node_basename@<host_or_ip>"
        node_basename: "app_name",

        # Block when starting the cluster supervisor until after the initial
        # attempt to join the cluster, or join the cluster asynchronously.
        async_initial_connection?: true
      ]]]
```

## Consul API Specific Configuration

Generic response of the Consul endpoints includes respective service's hostname of the node as well as it's IP. It is possible to establish connection using hostname exclusively by using following configuration. To retrieve only passing services `:passing` can be set to true which might be ignored if the API endpoint does not support health status. Default options use IP address of the node to establish connection

```elixir
  {Cluster.Strategy.Consul.Agent, [expected: :host, passing: true]}
```

### Agent

The Agent API comes with options to use `id` or `name` for service. Using `id` option gets the information about service directly using `/agent/service/:service_id` route. Whereas `name` option fetches the service using `/agent/health/service/name/:service_name`. Using `id` based service discovery ignores the service health status parameters. 

### Catalog

The Catalog API Endpoint strictly requires the `:name` option to be specified with `:service` option. As Catalog API does not support any health status queries, It also ignores the `:passing` option. 

#### Health

The Health API Endpoint strictly requires the `:name` option to be specified with `:service` option. It supports `:passing` option in the query parameters.


## Installation

```elixir
def deps do
  [
    {:libcluster_consul, "~> 1.1.0"}
  ]
end
```

You can determine the latest version by running `mix hex.info libcluster_consul` in your shell, or by going to the `libcluster_consul` [page on Hex.pm](https://hex.pm/packages/libcluster_consul).

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc) and published on [HexDocs](https://hexdocs.pm). Once published, the docs can be found at [https://hexdocs.pm/libcluster_consul](https://hexdocs.pm/libcluster_consul).

## Migration from 1.0.7 to 1.1.0

* Previously utilised `:service_name` option has been changed to `:service` which takes in either `[id: service_id]` or `[name: "service_name"]`. Please read through the respective endpoint requirements for further information.
* Additional options can be specified to use `hostname` for establishing connection between nodes. `:passing` option can be used along with Agent Endpoint as well.
* Multi-Datacenter Endpoint configurations should also follow the above changes in their respective configurations. 
