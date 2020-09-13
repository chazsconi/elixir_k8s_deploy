defmodule K8SDeploy.Deploy do
  alias K8SDeploy.Config
  alias Docker
  require Logger

  def run(opts) do
    Logger.debug("Opts: " <> inspect(opts))
    config = Config.load_from_application_env(opts)

    Logger.debug("Config: " <> inspect(config))
    Logger.debug("Appdir: " <> Application.app_dir(:k8s_deploy))

    print_step("Starting K8S Deploy..")

    if opts[:build?] do
      DockerBuild.Build.run(opts)
      print_step("Pushing docker image")
      push_image(config)
    else
      print("Skipping docker build")
    end

    print_step("Deploying to K8S")
    deploy(config, opts[:dry_run?])
    0
  end

  defp deploy(config, dry_run?) do
    []
    |> add_deployment(config)
    |> add_service(config)
    |> add_ingress(config)
    |> Enum.join("\n")
    |> kubectl_apply(config, dry_run?)
  end

  defp replace_vars(contents, config, assigns) do
    contents
    |> EEx.eval_string(
      [
        assigns:
          [
            deployment_id: deployment_id(),
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
      image_pull_secrets: Config.config!(config, :image_pull_secrets),
      env_vars: Config.env_vars(config)
    )
  end

  defp add_service(resources, config) do
    resources
    |> add_resource("service", config, [])
  end

  defp add_ingress(resources, config) do
    # Only add ingress if the host is specified
    case Config.config(config, :host) do
      nil ->
        resources

      host ->
        resources
        |> add_resource("ingress", config,
          host: host,
          cert_manager_issuer: Config.config!(config, :cert_manager_issuer),
          from_to_www_redirect?: Config.from_to_www_redirect?(config),
          hosts: Config.hosts(config)
        )
    end
  end

  defp add_resource(resources, name, config, assigns) do
    resource =
      resource_path(name, config)
      |> File.read!()
      |> replace_vars(config, assigns)

    resources ++ [resource]
  end

  defp resource_path(name, config) do
    project_path = "deploy/k8s/#{name}-#{Config.config(config, :env)}.yaml"

    if File.exists?(project_path) do
      project_path
    else
      Logger.debug("No #{name} file at: #{project_path} - using library version")
      Application.app_dir(:k8s_deploy, "priv/templates/#{name}.yaml")
    end
  end

  defp kubectl_apply(contents, config, dry_run?) do
    path = Path.join(System.tmp_dir(), deployment_id() <> ".yaml")
    Logger.debug("File contents:\n#{contents}")
    Logger.debug("Writing apply file to : #{path}")
    File.write!(path, contents)

    contexts =
      case Config.config!(config, :context) do
        contexts when is_list(contexts) -> contexts
        context when is_binary(context) -> [context]
      end

    Enum.each(contexts, fn context ->
      print_step("Deploying to context: #{context}")

      cmd =
        "kubectl --context=#{context} apply -f #{path}" <>
          if dry_run?, do: " --dry-run=true", else: ""

      print("Running: #{cmd}")
      print("Output:")
      print(IO.ANSI.italic())
      Mix.Shell.IO.cmd(cmd)
      print(IO.ANSI.reset())
    end)
  end

  defp push_image(config) do
    url = Config.build_config(config, :docker_image)
    Mix.Shell.IO.cmd("docker push #{url}", [])
  end

  defp deployment_id, do: DateTime.utc_now() |> DateTime.to_unix() |> Integer.to_string()

  defp print_step(message) do
    Mix.Shell.IO.info("\n" <> IO.ANSI.green() <> message <> IO.ANSI.reset())
  end

  defp print(message) do
    Mix.Shell.IO.info(message)
  end
end
