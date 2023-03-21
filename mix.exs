defmodule ClusterConsul.MixProject do
  use Mix.Project

  def project do
    [
      app: :libcluster_consul,
      version: "1.2.0",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      source_url: "https://github.com/team-telnyx/libcluster_consul",
      description: description()
    ]
  end

  def application do
    [
      extra_applications: [:logger, :eex]
    ]
  end

  defp deps do
    [
      {:libcluster, "~> 3.3.1"},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end

  defp description do
    """
    Consul strategy for libcluster
    """
  end

  defp package do
    [
      maintainers: ["Guilherme Balena Versiani <guilherme@telnyx.com>"],
      licenses: ["Apache 2.0"],
      links: %{"GitHub" => "https://github.com/team-telnyx/libcluster_consul"},
      files: ~w"lib mix.exs README.md LICENSE"
    ]
  end
end
