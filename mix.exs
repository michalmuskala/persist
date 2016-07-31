defmodule Persist.Mixfile do
  use Mix.Project

  def project do
    [app: :persist,
     version: "0.1.0",
     elixir: "~> 1.3",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps(),
     elixirc_paths: elixirc_paths(Mix.env)]
  end

  def application do
    [applications: [:gen_stage]]
  end

  defp deps do
    [{:gen_stage, "~> 0.4"}]
  end

  defp elixirc_paths(:prod), do: ["lib"]
  defp elixirc_paths(:dev),  do: elixirc_paths(:prod)
  defp elixirc_paths(:test), do: ["test/support"] ++ elixirc_paths(:dev)
end
