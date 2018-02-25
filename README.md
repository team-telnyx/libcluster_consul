# LibclusterConsul

**TODO: Add description**

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `libcluster_consul` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:libcluster_consul, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/libcluster_consul](https://hexdocs.pm/libcluster_consul).

## Configuration

Least required config is only consul service name
```elixir
config :libcluster,
  topologies: [
    consul_example: [
      strategy: ClusterConsul.Strategy,
      config: [
        service_name: "teamweek-core"
      ]
    ]
  ]
```

