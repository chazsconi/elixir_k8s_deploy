# K8S Deploy

Library for deploying Elixir web apps to Kubernetes.  Used in combination with [`docker_build`](https://hex.pm/packages/docker_build) library.

Will build a docker image of your app, push it and then deploy it to K8S by creating a K8S deployment, service and
ingress for your app. It will also request a *Letsencrypt* SSL cert for your app.

## Prerequisites

  * A K8S cluster
  * The K8S cluster installed and configured with [Cert manager](https://cert-manager.io) to issue *Letsencrypt* SSL certificates
  * `kubectl` installed and configured to access your K8S server
  * A Docker registry available for your image.  *Gitlab* currently provides a limited
  free private registry.
  * Pull secrets configured on your cluster to access the image on the Docker registry

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `elixir_k8s_deploy` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:k8s_deploy, "~> 0.1.0", runtime: false, only: :dev}
  ]
end
```

Install and configure `docker_build` to build your docker image for you.


## Basic Use

Create the following entries in `config/dev.exs`.  As you will run the `mix` tasks in the
development environment you should only add them here.

```elixir
# config/dev.exs
config :k8s_deploy, K8SDeploy.Deploy,
  context: "my-k8s-cluster.com", # The kubectl context name in kubectl
  image_pull_secrets: ["my-pull-secret"], # Unless a public docker image is used this must be set up before
  cert_manager_issuer: "letsencrypt-prod", # This needs to be set up before
  host: "www.mysite.com" # HTTPS host
```

### Deploy

To build a docker image and deploy:

```bash
mix k8s.deploy
```

See `mix help k8s.deploy` for options

## Advanced usage

### Additional configuration

The following additional config values are available:

  * `:from_to_www_redirect?` - if your want an automatic redirection from the non-`www` version of your site to the `www` version. Defaults to `true` if the host starts with `www`.  Raises if set and host does not start with `www`.
  * `:env_vars` - Map of environment variables that will be set in the K8S deployment. e.g. `%{"FOO" => "BAR"}`

### Deploying without an ingress

If you omit the `host` field, no ingress will be deployed.  You may use this if another app deploys the ingress
rules for this app.

### Deploying to multiple contexts

You can also specify `:context` as a list.  All K8S resources will then be deployed to each context in turn.
