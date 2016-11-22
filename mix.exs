defmodule Airbax.Mixfile do
  use Mix.Project

  @version "0.0.4"

  def project() do
    [app: :airbax,
     version: @version,
     elixir: "~> 1.0",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     description: description(),
     package: package(),
     deps: deps(),
     aliases: [test: "test --no-start"],
     name: "Airbax",
     docs: [main: "Airbax",
            source_ref: "v#{@version}",
            source_url: "https://github.com/adjust/airbax",
            extras: ["pages/Using Airbax in Plug-based applications.md"]]]
  end

  def application() do
    [applications: [:logger, :hackney, :poison, :sidejob],
     mod: {Airbax, []}]
  end

  defp deps() do
    [{:hackney, "~> 1.1"},
     {:poison,  "~> 1.4 or ~> 2.0"},
     {:sidejob, "~> 2.0"},

     {:ex_doc, ">= 0.0.0", only: :docs},
     {:earmark, ">= 0.0.0", only: :docs},

     {:plug,   "~> 0.13.0", only: :test},
     {:cowboy, "~> 1.0.0", only: :test}]
  end

  defp description() do
    "Exception tracking from Elixir to Airbrake"
  end

  defp package() do
    [maintainers: ["Damir Gainetdinov"],
     licenses: ["ISC"],
     links: %{"GitHub" => "https://github.com/adjust/airbax"}]
  end
end
