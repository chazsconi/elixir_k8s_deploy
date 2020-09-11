defmodule Mix.Tasks.K8s.Deploy do
  @moduledoc """
  Builds the application using `docker_build` and the deploys to K8S
  ```
    mix k8s.deploy [deploy-env] [options]
  ```

  `deploy-env` will default to `prod`

  ## Options
   * `--skip-build` - docker build and push will be skipped
   * `--dry-run` - will execute `kubectl apply` as a dry-run
   * `--debug` - outputs extra debugging info
  """
  @shortdoc "Deploys the app to K8S"
  use Mix.Task
  alias K8SDeploy.Deploy
  require Logger

  @impl Mix.Task
  @doc false
  def run(args) do
    {:ok, env, flags} =
      case args do
        [] ->
          {:ok, :prod, []}

        ["--" <> _flag | _flags] ->
          {:ok, :prod, args}

        [env | flags] ->
          {:ok, env, flags}
      end

    Logger.configure(format: "$metadata[$level] $message\n")

    if "--debug" in flags do
      Logger.configure(level: :debug)
    else
      Logger.configure(level: :warn)
    end

    Logger.debug("Using env #{env}")
    Logger.debug("Args: " <> inspect(args))

    case Deploy.run(
           env: env,
           build?: "--skip-build" not in flags,
           dry_run?: "--dry-run" in flags
         ) do
      0 -> Mix.shell().info("Deploy done")
      n -> Mix.raise("Build failed. Exit code #{n}")
    end
  end
end
