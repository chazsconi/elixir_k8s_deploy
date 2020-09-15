defmodule K8SDeploy.MixHelpers do
  require Logger

  @doc "Parses the args which consists of [env] [flags]"
  def parse_args(args) do
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
    {:ok, env, flags}
  end
end
