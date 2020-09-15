defmodule Mix.Tasks.K8s.CleanMigrations do
  @moduledoc """
  Deletes all previously run migration jobs
  ```
    mix k8s.clean_migrations [deploy-env] [options]
  ```

  `deploy-env` will default to `prod`

  ## Options
   * `--debug` - outputs extra debugging info
  """
  @shortdoc "Deletes previously run migration jobs"
  use Mix.Task
  alias K8SDeploy.Deploy
  alias K8SDeploy.MixHelpers
  require Logger

  @impl Mix.Task
  @doc false

  def run(args) do
    {:ok, env, _flags} = MixHelpers.parse_args(args)

    Deploy.clean_all_migrations(env: env)
  end
end
