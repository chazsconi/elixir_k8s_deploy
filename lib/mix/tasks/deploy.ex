defmodule Mix.Tasks.K8s.Deploy do
  @moduledoc """
  Builds the application using `docker_build` and then deploys to K8S
  ```
    mix k8s.deploy [deploy-env] [options]
  ```

  `deploy-env` will default to `prod`

  ## Options
   * `--skip-build` - docker build and push will be skipped
   * `--skip-migrate` - will skip the migrations
   * `--clean-migrations` - will delete the migration jobs after running (default false)
   * `--skip-deploy` - will just run migrations without deploying
   * `--dry-run` - will execute `kubectl apply` as a dry-run
   * `--debug` - outputs extra debugging info
  """
  @shortdoc "Deploys the app to K8S"
  use Mix.Task
  alias K8SDeploy.Deploy
  alias K8SDeploy.MixHelpers
  require Logger

  @impl Mix.Task
  @doc false
  def run(args) do
    {:ok, env, flags} = MixHelpers.parse_args(args)

    Deploy.run(
      env: env,
      build?: "--skip-build" not in flags,
      migrate?: "--skip-migrate" not in flags,
      clean_migrations?: "--clean-migrations" in flags,
      deploy?: "--skip-deploy" not in flags,
      dry_run?: "--dry-run" in flags
    )
  end
end
