defmodule ElevatorProject.MixProject do
  use Mix.Project

  def project do
    [
      app: :elevator_project,
      version: "0.1.0",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps(),

      # Documentation
      name: "ElevatorProject",
      description: "Implementation of concurrent message passing system for parallell elevators.",
      docs: docs(),
      package: package()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      #mod: {ElevatorProject.Application, []},
      extra_applications: [:logger],
      applications: [:gen_state_machine]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:gen_state_machine, "~> 3.0"},
      {:ex_doc, "~> 0.24", only: :dev, runtime: false}
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end

  defp docs do
    [
      main: "readme",
      homepage_url: "https://hexdocs.pm/elevator_project",
      extras: ["README.md"]
    ]
  end

  defp package do
    [
      licenses: [],
      links: %{"GitHub" => "https://github.com/TTK4145-Students-2021/project-gruppe-26"}
    ]
  end
end
