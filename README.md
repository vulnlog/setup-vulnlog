# Setup Vulnlog CLI

[![Test](https://github.com/vulnlog/setup-vulnlog/actions/workflows/test.yml/badge.svg)](https://github.com/vulnlog/setup-vulnlog/actions/workflows/test.yml)
[![Marketplace](https://img.shields.io/badge/marketplace-setup--vulnlog-%23f405c5)](https://github.com/marketplace/actions/setup-vulnlog-cli)

Installs the [Vulnlog](https://github.com/vulnlog/vulnlog) CLI on a GitHub Actions runner and puts it on `PATH`. Install
once per job; every later step can call `vulnlog`.

## Usage

```yaml
steps:
  - uses: actions/checkout@v7

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

No token and no `permissions` block are required: the action only downloads public release assets from `github.com`.

## Inputs

| Input     | Default  | Description                                                                                                                   |
|-----------|----------|-------------------------------------------------------------------------------------------------------------------------------|
| `version` | `latest` | Version to install, e.g. `0.17.0` or `v0.17.0`. `latest` resolves the newest stable release; pre-releases are never selected. |

Pin `version` in anything you rely on. `latest` picks up a new release the moment it ships, which suits a nightly job
and not a release pipeline.

## Outputs

| Output         | Description                                                                            |
|----------------|----------------------------------------------------------------------------------------|
| `version`      | Installed version, without the leading `v`.                                            |
| `distribution` | `native` or `jvm`.                                                                     |
| `path`         | Absolute path to the `vulnlog` executable.                                             |
| `cache-hit`    | `true` if the version was already in the runner tool cache and nothing was downloaded. |

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

On a runner without a native build, install Java 21+ first, or the step fails telling you to:

```yaml
- uses: actions/setup-java@v6
  with:
    distribution: temurin
    java-version: '21'
- uses: vulnlog/setup-vulnlog@v1
```

## Verification

Downloads are not yet cryptographically verified. Vulnlog releases currently publish neither `checksums.txt` nor build
attestations; once they do, this action will verify them by default.

## License

[Apache-2.0](LICENSE)
