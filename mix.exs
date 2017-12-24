defmodule Parameters.Mixfile do
  use Mix.Project

  def project do
    [
      app: :parameters,
      version: "0.1.1",
      elixir: "~> 1.5",
      start_permanent: Mix.env == :prod,
      description: description(),
      package: package(),
      deps: deps()
    ]
  end

  defp description do
    """
    An easy way to create Ecto Schemas for API endpoint validations
    """
  end

  defp package do
    [name: :parameters,
     files: ["lib", "mix.exs", "README*", "LICENSE*"],
     maintainers: ["Imran Ismail"],
     licenses: ["MIT"],
     links: %{"GitHub" => "https://github.com/imranismail/parameters.ex"}]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ecto, "~> 2.2"},
      {:ex_doc, ">= 0.0.0", only: :dev}
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"},
    ]
  end
end
