# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres
to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-08-30

First release.

### Added

- Install the Vulnlog CLI on a GitHub Actions runner and put it on `PATH`, so every later step in the job can call
  `vulnlog`.
- Add the `version` input. It defaults to `latest`, which resolves the newest stable release, and accepts either
  `0.17.0` or `v0.17.0`. Pre-releases are never selected.
- Add the `version`, `distribution`, `path`, and `cache-hit` outputs.
- Install the native binary on `ubuntu-*` (x64), `macos-*` (arm64), and `windows-*` (x64), and fall back to the JVM
  distribution elsewhere. The JVM distribution needs Java 21+ on `PATH`.
- Cache the CLI in the runner tool cache, so using the action twice in one job downloads nothing the second time.
