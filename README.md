# K8S Deploy

Library for deploying Elixir web apps to Kubernetes.  Used in combination with [`docker_build`](https://hex.pm/packages/docker_build) library.

It will build a docker image of your app, push it and then deploy it to K8S by creating a K8S `Deployment`, `Service` and `Ingress` for your app. It will also request a *Letsencrypt* SSL cert for your app.

## Prerequisites

  * A K8S cluster
  * The K8S cluster installed and configured with [Cert manager](https://cert-manager.io) to issue *Letsencrypt* SSL certificates
  * `kubectl` installed and configured to access your K8S server
  * A Docker registry available for your image.  *Gitlab* currently provides a limited
  free private registry.
  * Pull secrets configured on your cluster to access the image on the Docker registry

## Installation

Add to `mix.exs`:

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

For additional options run:

```bash
mix help k8s.deploy
```

## Advanced usage

### Additional configuration

The following additional config values are available:

  * `:from_to_www_redirect?` - if your want the `Ingress` to perform an automatic redirection from the non-`www` version of your site to the `www` version. Defaults to `true` if the host starts with `www`.  Raises if set and host does not start with `www`.
  * `:env_vars` - Map of environment variables that will be set in the K8S `Deployment`. e.g. `%{"FOO" => "BAR"}`.  The following
  environment variables are automatically injected:
    * `PORT` - set to `4000`
    * `URL_HOST` - set to the `:host` value in the config (if set)
  * `:migrator` - Module name or mfa tuple for running migrations.  See *"Running Migrations"* below.

### Using a ConfigMap for environment variables

Instead of providing environment variables via the `:env_vars` key, you can provide a K8S `ConfigMap` in the
`deploy/k8s` folder with the name `configmap-prod.yaml`.  (If using a different environment change `prod` to match).

The name of the `ConfigMap` must match the `:app_name` key specified in the `docker_build` config, with the suffix `-configmap`.
This will be referenced using `envFrom` in the `Deployment`.

For example:
```yaml
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: myapp-configmap
data:
  FOO: BAR
  FOO2: BAR2
```

### Running migrations

To run migrations set the `:migrator` config key to either a module name, e.g `MyApp.Release` which contains a `migrate/0` function,
or a mfa, e.g. `{MyApp.Release, :migrate, []}`.  You can create the necessary code by following the recommendation
in [Phoenix](https://hexdocs.pm/phoenix/releases.html#ecto-migrations-and-custom-commands).

A K8S `Job` will be created using the same docker image. It will execute the migrate function and run to completion before the deploy continutes.  Any `ConfigMap` or vars in `:env_vars` will be available in to the `Pod` container that the job creates.

### Deploying without an ingress

If you omit the `host` field, no ingress will be deployed.  You might use this if another app deploys the ingress
rules for this app.

### Deploying to multiple contexts

You can also specify `:context` as a list.  All K8S resources will then be deployed to each context in turn.

## TODO

* Run `git push origin master:production` after deploy
* Have option to ask for key press before deploying
* If custom ingress `:host` is not relevant but should still deploy ingress
* Support different environments e.g. `mix k8s.deploy staging` with an environment setting and overrides in config
* Block until deploy complete
* Support probes in deployment
