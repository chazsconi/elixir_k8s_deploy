defmodule K8SDeploy.Config do
  @moduledoc "Stores config for base and plugins"
  alias __MODULE__
  defstruct base_config: [], plugin_configs: [], build_config: nil

  @doc """
  Load the config from the application env

  ## Options
   * `env` - environment to be used.  Defaults to `prod`
  """
  def load_from_application_env(opts) do
    config = Application.fetch_env!(:k8s_deploy, K8SDeploy.Deploy)
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
      |> Keyword.put(:env, env)

    %Config{
      base_config: base_config,
      plugin_configs: plugin_configs,
      build_config: DockerBuild.Config.load_from_application_env(opts)
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

  @doc "Selected `MIX_ENV`"
  def mix_env(context), do: config(context, :env)

  @doc "If automatic redirection from non-www to www version of site should happen"
  def from_to_www_redirect?(context) do
    case {config(context, :from_to_www_redirect), config(context, :host)} do
      {nil, "www." <> _} -> true
      {nil, _} -> false
      {value, "www." <> _} -> value
      {value, _} -> raise "from_to_www_redirect: #{value} but host does not start with www"
    end
  end

  @doc "List of all hosts"
  def hosts(context) do
    if config(context, :from_to_www_redirect, false) do
      case config(context, :host) do
        "www." <> suffix = host -> [host, suffix]
        _ -> raise "from_to_www_redirect: true but host does not start with www"
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
end
