defmodule Lethe.MixProject do
  use Mix.Project

  @repo_url "https://github.com/queer/lethe"

  def project do
    [
      app: :lethe,
      version: "0.2.0",
      elixir: "~> 1.11",
      start_permanent: Mix.env() == :prod,
      deps: deps(),

      # Hex
      description: "A friendly query DSL for Mnesia",
      package: [
        maintainers: ["amy"],
        links: %{"GitHub" => @repo_url},
        licenses: ["MIT"],
      ],

      # Docs
      name: "Lethe",
      docs: [
        homepage_url: @repo_url,
        source_url: @repo_url,
        extras: [
          "README.md",
        ],
      ],
    ]
  end

  def application do
    [
      extra_applications: [:logger, :mnesia],
    ]
  end

  defp deps do
    [
      {:typed_struct, "~> 0.2.1"},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
    ]
  end
end
