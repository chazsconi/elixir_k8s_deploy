# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.7.0] - 2023-11-07
### Breaking changes
- Drop support for Elixir <= v1.11

### Bug fixes
- Change `Logger.warn` to `Logger.warning` and similar atoms

## [0.6.0] - 2023-08-25
### Added
- Support `probe_initial_delay_seconds` for probes

## [0.5.0] - 2022-04-05
### Added
- Support namespaces
- Support Cert Manager cluster issuers
### Fixes
- Includes `:eex` as `:extra_application` to prevent compilation warning.
### Breaking changes
- Changed ingress to use API version `networking.k8s.io/v1` instead of `extensions/v1beta1`.  This will break on K8S < v1.19.
- Uses `--dry-run=client` with `kubectl`.  Will break older versions of `kubectl`.

## [0.4.0] - 2021-11-03
### Breaking changes
- The configuration is now in the `k8s_deploy:` entry in the `project/0` within `mix.exs` instead of in `dev.exs`.
See [README.md](README.md) for details.

### Fixed
- Clarify use of `:probe_path`

## [0.3.1] - 2020-09-20
### Fixed
- Fix `:from_to_www_redirect?` to work also with redirection from `www` to non `www`

## [0.3.0] - 2020-09-18
### Added
- Support `livenessProbe` and `readinessProbe`
### Fixed
- Fix bug with using mfa for `:migrator`
- Fix `:image_pull_secrets` being mandatory.

## [0.2.1] - 2020-09-17
### Fixed
- Allow for custom `Ingress` when `:host` not specified

### Changed
- Updated README with instructions on custom templates

## [0.2.0] - 2020-09-15
### Added
- Support optional ConfigMap
- Support migrations

## [0.1.0] - 2020-09-13
### Added
- Initial version
