defmodule K8SDeploy.Config do
  @moduledoc "Stores config for base and plugins"
  alias __MODULE__
  defstruct base_config: [], plugin_configs: [], build_config: nil

  @doc """
  Load the config from the mix project

  ## Options
   * `env` - environment to be used.  Defaults to `prod`
  """
  def load(opts) do
    config =
      case Mix.Project.config()[:k8s_deploy] do
        nil ->
          Mix.raise("Missing `:k8s_deploy` entry in `project/0` in `mix.exs`")

        config ->
          config
      end

    env = Keyword.fetch!(opts, :env)

    plugin_configs =
      (config[:plugins] || [])
      |> Enum.map(fn
        {plugin, config} -> {plugin, config}
        plugin -> {plugin, Application.get_env(:k8s_deploy, plugin, [])}
      end)

    base_config =
      config
      |> Keyword.delete(:plugins)
      |> validate_cert_manager_issuer()
      |> validate_and_parse_resources()
      |> Keyword.put(:env, env)
      |> Keyword.put(
        :deployment_id,
        DateTime.utc_now() |> DateTime.to_unix() |> Integer.to_string()
      )

    %Config{
      base_config: base_config,
      plugin_configs: plugin_configs,
      build_config: DockerBuild.Config.load(opts)
    }
  end

  @doc "Get the config for a given plugin and key"
  def plugin_config(context, plugin, key)

  def plugin_config(%Config{plugin_configs: plugin_configs}, plugin, key) do
    plugin_configs[plugin][key]
  end

  # def plugin_config(%Dockerfile{config: config}, plugin, key),
  #   do: plugin_config(config, plugin, key)

  @doc "Get a list of plugins"
  def plugins(context)

  # def plugins(%Dockerfile{config: config}), do: plugins(config)

  def plugins(%Config{plugin_configs: plugin_configs}) do
    Keyword.keys(plugin_configs)
  end

  @doc "Get the main config for a given key"
  def config(%Config{base_config: base_config}, key, default \\ nil) do
    case Keyword.fetch(base_config, key) do
      {:ok, v} -> v
      :error -> default
    end
  end

  @doc "Get the config key and raise if not found"
  def config!(%Config{base_config: base_config}, key) do
    case Keyword.fetch(base_config, key) do
      {:ok, v} -> v
      :error -> raise "Config key #{__MODULE__} #{inspect(key)} not found"
    end
  end

  @doc "Get the build config key"
  def build_config(%Config{build_config: build_config}, key) do
    DockerBuild.Config.config(build_config, key)
  end

  # def config(%Dockerfile{config: config}, key), do: config(config, key)

  @doc "Name of the app"
  def app_name(context), do: config(context, :app_name, build_config(context, :app_name))

  @doc "Namespace (defaults to `default`)"
  def namespace(context), do: config(context, :namespace, "default")

  @doc "deployment_id - generated from datestamp"
  def deployment_id(context), do: config(context, :deployment_id)

  @doc "Selected `MIX_ENV`"
  def mix_env(context), do: config(context, :env)

  @doc "If automatic redirection from non-www to www version of site should happen"
  def from_to_www_redirect?(context) do
    case {config(context, :from_to_www_redirect?), config(context, :host)} do
      {nil, "www." <> _} -> true
      {nil, _} -> false
      {value, _} -> value
    end
  end

  @doc "List of all hosts"
  def hosts(context) do
    if from_to_www_redirect?(context) do
      case config(context, :host) do
        "www." <> suffix = host -> [host, suffix]
        host -> [host, "www." <> host]
      end
    else
      [config(context, :host)]
    end
  end

  @doc "Env vars for deployment"
  def env_vars(context) do
    case config(context, :host) do
      host when is_binary(host) -> %{"URL_HOST" => host}
      _ -> %{}
    end
    |> Map.merge(%{"PORT" => "4000"})
    |> Map.merge(config(context, :env_vars, %{}))
  end

  @doc "K8S container resources"
  def resources(context) do
    case config(context, :resources) do
      nil -> nil
      # Encoded as JSON so we don't need to depend on a YAML encoder
      resources -> JSON.encode!(resources)
    end
  end

  @doc "Gets the mfa for the migrator"
  def migrator(context) do
    case config(context, :migrator) do
      nil ->
        nil

      mod when is_atom(mod) ->
        {mod, :migrate, []}

      {mod, fun, args} when is_atom(mod) and is_atom(fun) and is_list(args) ->
        {mod, fun, args}

      _ ->
        raise ":migrator must be either a module with a :migrate/0 function or a mfa"
    end
  end

  defp validate_and_parse_resources(config) do
    case config[:resources] do
      nil ->
        config

      resources when is_list(resources) ->
        case Keyword.validate(resources, [:requests, :limits]) do
          {:error, _} ->
            Mix.raise("Invalid :resources config.  Specify only :requests and :limits keys")

          {:ok, _} ->
            Keyword.put(
              config,
              :resources,
              %{}
              |> add_resource(:requests, resources[:requests])
              |> add_resource(:limits, resources[:limits])
            )
        end

      _ ->
        Mix.raise("Invalid :resources config")
    end
  end

  defp add_resource(%{} = acc, _, nil), do: acc

  defp add_resource(%{} = acc, key, values) do
    case Keyword.validate(values, [:cpu, :memory]) do
      {:error, _} ->
        Mix.raise("Invalid :resources config for #{key}.  Specify only `cpu` and `memory` keys")

      {:ok, _} ->
        Map.put(acc, key, Map.new(values))
    end
  end

  defp validate_cert_manager_issuer(config) do
    case {config[:host], config[:cert_manager_issuer], config[:cert_manager_cluster_issuer]} do
      {nil, nil, nil} ->
        config

      {_, nil, nil} ->
        Mix.raise("No :cert_maanger_issuer or :cert_manager_cluster_issue specified")

      {_, nil, _} ->
        config

      {_, _, nil} ->
        config

      {_, _, _} ->
        Mix.raise("Both :cert_maanger_issuer and :cert_manager_cluster_issue specified")
    end
  end
end
