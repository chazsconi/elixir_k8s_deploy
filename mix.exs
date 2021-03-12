defmodule K8SDeploy.MixProject do
  use Mix.Project

  def project do
    [
      app: :k8s_deploy,
      version: "0.3.1",
      elixir: "~> 1.9",
      start_permanent: false,
      deps: deps(),
      description: description(),
      package: package(),
      name: "K8SDeploy",
      source_url: "https://github.com/chazsconi/elixir_k8s_deploy",
      docs: docs()
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
      {:docker_build, "~> 0.4.0", only: :dev},
      {:ex_doc, ">= 0.0.0", only: :dev}
    ]
  end

  defp description do
    """
    Library for deploying Elixir web apps to Kubernetes.
    Used in combination with docker_build library.
    """
  end

  defp package do
    [
      name: :k8s_deploy,
      maintainers: ["Charles Bernasconi"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/chazsconi/elixir_k8s_deploy"}
    ]
  end

  defp docs do
    [
      extras: ["README.md"],
      main: "readme"
    ]
  end
end
