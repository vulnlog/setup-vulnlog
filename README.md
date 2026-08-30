# setup-vulnlog

[![Test](https://github.com/vulnlog/setup-vulnlog/actions/workflows/test.yml/badge.svg)](https://github.com/vulnlog/setup-vulnlog/actions/workflows/test.yml)
[![Marketplace](https://img.shields.io/badge/marketplace-setup--vulnlog-%23f405c5)](https://github.com/marketplace/actions/setup-vulnlog-cli)

Installs the [Vulnlog](https://github.com/vulnlog/vulnlog) CLI on a GitHub Actions runner and puts it on `PATH`. Install
once per job, every later step can call `vulnlog`.

```yaml
- uses: vulnlog/setup-vulnlog@v1
  with:
    version: 0.17.0

- run: vulnlog validate --strict vulnlog.yaml
- run: vulnlog report impact -o impact.html vulnlog.yaml
- uses: actions/upload-artifact@v7
  with:
    name: vulnlog-impact-report
    path: impact.html
```

## Inputs

| Input     | Default  | Description                                                                                                                   |
|-----------|----------|-------------------------------------------------------------------------------------------------------------------------------|
| `version` | `latest` | Version to install, e.g. `0.17.0` or `v0.17.0`. `latest` resolves the newest stable release; pre-releases are never selected. |

Pin `version` in anything you rely on. `latest` picks up a new release the moment it ships, which is what you want in a
nightly job and not what you want in a release pipeline.

## Outputs

| Output         | Description                                                 |
|----------------|-------------------------------------------------------------|
| `version`      | Installed version, without the leading `v`.                 |
| `distribution` | `native` or `jvm`, see below.                               |
| `path`         | Absolute path to the `vulnlog` executable.                  |
| `cache-hit`    | `true` if the version was already in the runner tool cache. |

## Runner support

Vulnlog ships a self-contained native binary for three platforms and a JVM build for everything else. The action picks
automatically:

| Runner                                | Installs | Needs Java |
|---------------------------------------|----------|------------|
| `ubuntu-latest`, `ubuntu-24.04` (x64) | native   | no         |
| `macos-latest`, `macos-14`+ (arm64)   | native   | no         |
| `windows-latest` (x64)                | native   | no         |
| `ubuntu-24.04-arm` (arm64)            | jvm      | yes        |
| `macos-15-intel` (Intel x64)          | jvm      | yes        |

On a JVM runner, add Java 21+ first or the step fails with that instruction:

```yaml
- uses: actions/setup-java@v6
  with:
    distribution: temurin
    java-version: '21'
- uses: vulnlog/setup-vulnlog@v1
```

## Notes

- No token or permissions are needed. The action only fetches public release assets from `github.com`.
- The CLI lands in the runner tool cache, so using this action twice in one job is a no-op and reports
  `cache-hit: true`.
- Downloads are not yet cryptographically verified: Vulnlog releases publish neither `checksums.txt` nor build
  attestations. When they do, this action will verify them by default.

## Development

```sh
bats tests/          # unit tests, no network
shellcheck install.sh
actionlint
```

Releases are cut as described in [RELEASING.md](RELEASING.md).

`install.sh` keeps its platform mapping in `platform_slug`, `native_asset_name`and `jvm_asset_name`. The `contract` job
in [`.github/workflows/test.yml`](.github/workflows/test.yml) runs daily and fails if a Vulnlog release stops publishing
an asset that table names, so a rename in the release pipeline surfaces here before it reaches you.
