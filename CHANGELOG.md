# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]
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
