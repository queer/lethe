defmodule Lethe.MixProject do
  use Mix.Project

  def project do
    [
      app: :lethe,
      version: "0.1.0",
      elixir: "~> 1.11",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger, :mnesia]
    ]
  end

  defp deps do
    [
      {:typed_struct, "~> 0.2.1"},
    ]
  end
end
