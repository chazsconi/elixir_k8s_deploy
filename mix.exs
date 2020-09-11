defmodule K8SDeploy.MixProject do
  use Mix.Project

  def project do
    [
      app: :k8s_deploy,
      version: "0.1.0",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
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
      {:docker_build, "~> 0.3.3"}
    ]
  end
end
