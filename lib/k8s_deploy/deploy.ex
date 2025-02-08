defmodule K8SDeploy.Deploy do
  alias K8SDeploy.Config
  alias Docker
  require Logger

  def run(opts) do
    Logger.debug("Opts: " <> inspect(opts))
    config = Config.load(opts)

    Logger.debug("Config: " <> inspect(config))
    Logger.debug("Appdir: " <> Application.app_dir(:k8s_deploy))

    if opts[:build?] do
      print_step("Starting docker_build")

      if DockerBuild.Build.run(opts) != 0 do
        Mix.raise("docker_build failed")
      end

      print_step("Pushing docker image")
      push_image(config)
    else
      print("Skipping docker build")
    end

    if Config.migrator(config) do
      if opts[:migrate?] do
        print_step("Running migrations")
        run_migrations(config, opts[:dry_run?], opts[:clean_migrations?])
        print_step("Migrations complete")
      else
        print("Skipping migrations")
      end
    end

    if opts[:deploy?] do
      print_step("Deploying to K8S")
      deploy(config, opts[:dry_run?])
      print_step("Deploy complete")
    else
      print("Skipping deploy")
    end

    print_step("FINISHED")
  end

  @doc "Cleans all migrations for the app"
  def clean_all_migrations(args) do
    config = Config.load(args)

    each_context(config, fn context ->
      print_step("Cleaning migrations in context: #{context}")

      cmd =
        "kubectl --context=#{context} --namespace=#{Config.namespace(config)} delete job -l app=#{Config.app_name(config)}-migrate"

      shell_cmd(cmd)
    end)
  end

  defp clean_migrations(config) do
    each_context(config, fn context ->
      print_step("Cleaning migrations context: #{context}")

      cmd =
        "kubectl --context=#{context} --namespace=#{Config.namespace(config)} delete job #{migration_job_name(config)}"

      shell_cmd(cmd)
    end)
  end

  defp wait_migrations(config) do
    each_context(config, fn context ->
      print_step("Waiting for migrations to complete in context: #{context}")

      cmd =
        "kubectl --context=#{context} --namespace=#{Config.namespace(config)} wait --timeout=60s " <>
          "--for=condition=complete job/#{migration_job_name(config)}"

      shell_cmd(cmd)
    end)
  end

  defp run_migrations(config, dry_run?, clean_migrations?) do
    []
    |> add_configmap(config)
    |> add_migration_job(config)
    |> kubectl_apply(config, dry_run?)

    if not dry_run? do
      wait_migrations(config)
      if clean_migrations?, do: clean_migrations(config)
    end
  end

  defp deploy(config, dry_run?) do
    []
    |> add_configmap(config)
    |> add_deployment(config)
    |> add_service(config)
    |> add_ingress(config)
    |> kubectl_apply(config, dry_run?)
  end

  defp replace_vars(contents, config, assigns) do
    contents
    |> EEx.eval_string(
      [
        assigns:
          [
            deployment_id: Config.deployment_id(config),
            app_name: Config.app_name(config)
          ] ++ assigns
      ],
      trim: true
    )
  end

  defp add_deployment(resources, config) do
    resources
    |> add_resource("deployment", config,
      docker_image: Config.build_config(config, :docker_image),
      image_pull_secrets: Config.config(config, :image_pull_secrets),
      env_vars: Config.env_vars(config),
      probe_path: Config.config(config, :probe_path),
      probe_initial_delay_seconds: Config.config(config, :probe_initial_delay_seconds, 10),
      configmap?: has_resource?(resources, "configmap"),
      resources: Config.resources(config)
    )
  end

  defp add_service(resources, config) do
    resources
    |> add_resource("service", config, [])
  end

  defp add_configmap(resources, config) do
    resources
    |> add_resource("configmap", config, [], optional?: true)
  end

  defp add_ingress(resources, config) do
    case {resource_path("ingress", config, true), Config.config(config, :host)} do
      # Skip the ingress if there is no custom template or no host is specified
      {nil, nil} ->
        resources

      # With a custom resource don't inject any vars
      {_custom_resource, nil} ->
        resources
        |> add_resource("ingress", config, [])

      {nil, host} ->
        resources
        |> add_resource("ingress", config,
          host: host,
          cert_manager_issuer: Config.config(config, :cert_manager_issuer),
          cert_manager_cluster_issuer: Config.config(config, :cert_manager_cluster_issuer),
          from_to_www_redirect?: Config.from_to_www_redirect?(config),
          hosts: Config.hosts(config)
        )
    end
  end

  defp add_migration_job(resources, config) do
    {mod, fun, args} = Config.migrator(config)

    resources
    |> add_resource("migration-job", config,
      docker_image: Config.build_config(config, :docker_image),
      image_pull_secrets: Config.config(config, :image_pull_secrets),
      env_vars: Config.env_vars(config),
      configmap?: has_resource?(resources, "configmap"),
      job_name: migration_job_name(config),
      migrate_expr: "apply(#{inspect(mod)}, #{inspect(fun)}, #{inspect(args)})"
    )
  end

  defp migration_job_name(config) do
    "#{Config.app_name(config)}-migrate-#{Config.deployment_id(config)}"
  end

  defp add_resource(resources, name, config, assigns, opts \\ []) do
    case resource_path(name, config, opts[:optional?]) do
      nil ->
        resources

      path ->
        resource =
          path
          |> File.read!()
          |> verify_yaml_format(path)
          |> replace_vars(config, assigns)

        resources ++ [{name, resource}]
    end
  end

  defp verify_yaml_format(contents, path) do
    case contents do
      "---\n" <> _ -> contents
      _ -> Mix.raise("File #{path} does not start with '---'")
    end
  end

  defp has_resource?(resources, search) do
    Enum.any?(resources, fn {name, _contents} -> name == search end)
  end

  defp resource_path(name, config, optional?) do
    project_path = "deploy/k8s/#{name}-#{Config.config(config, :env)}.yaml"

    if File.exists?(project_path) do
      project_path
    else
      if optional? do
        Logger.debug("No #{name} file at: #{project_path} - skipping")
        nil
      else
        Logger.debug("No #{name} file at: #{project_path} - using library version")
        Application.app_dir(:k8s_deploy, "priv/templates/#{name}.yaml")
      end
    end
  end

  defp kubectl_apply(resources, config, dry_run?) do
    contents =
      resources
      |> Enum.map(fn {_name, contents} -> contents end)
      |> Enum.join("\n")

    path = Path.join(System.tmp_dir(), Config.deployment_id(config) <> ".yaml")
    Logger.debug("File contents:\n#{contents}")
    Logger.debug("Writing apply file to : #{path}")
    File.write!(path, contents)

    each_context(config, fn context ->
      print_step("Deploying to context: #{context}")

      cmd =
        "kubectl --context=#{context} --namespace=#{Config.namespace(config)} apply -f #{path}" <>
          if dry_run?, do: " --dry-run=client", else: ""

      shell_cmd(cmd)
    end)
  end

  defp each_context(config, fun) do
    contexts =
      case Config.config!(config, :context) do
        contexts when is_list(contexts) -> contexts
        context when is_binary(context) -> [context]
      end

    Enum.each(contexts, fun)
  end

  defp push_image(config) do
    url = Config.build_config(config, :docker_image)
    shell_cmd("docker push #{url}", [])
  end

  defp shell_cmd(cmd, params \\ []) do
    print("Running: #{cmd} #{inspect(params)}")
    print("Output:")
    print(IO.ANSI.italic())

    if Mix.Shell.IO.cmd(cmd, params) != 0 do
      Mix.raise("#{cmd} failed")
    end

    print(IO.ANSI.reset())
  end

  defp print_step(message) do
    Mix.Shell.IO.info("\n" <> IO.ANSI.green() <> message <> IO.ANSI.reset())
  end

  defp print(message) do
    Mix.Shell.IO.info(message)
  end
end
