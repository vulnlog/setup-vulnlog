#!/usr/bin/env bats
#
# Unit tests for the pure functions in install.sh. No network, no runner, runs
# in about a second on any machine with bats-core installed:
#
#   npm install -g bats && bats tests/

setup() {
  # shellcheck source=../install.sh
  source "${BATS_TEST_DIRNAME}/../install.sh"
}

@test "platform slug maps every runner label with a native build" {
  [ "$(platform_slug Linux X64)" = "linux-amd64" ]
  [ "$(platform_slug macOS ARM64)" = "macos-aarch64" ]
  [ "$(platform_slug Windows X64)" = "windows-amd64" ]
}

@test "platform slug reports no native build for the rest" {
  # These are not errors: main() falls back to the JVM distribution.
  run platform_slug Linux ARM64
  [ "$status" -ne 0 ]
  run platform_slug macOS X64
  [ "$status" -ne 0 ]
  run platform_slug Windows ARM64
  [ "$status" -ne 0 ]
  run platform_slug Linux X86
  [ "$status" -ne 0 ]
}

@test "executable name carries a Windows suffix in both distributions" {
  [ "$(native_executable_name Windows)" = "vulnlog.exe" ]
  [ "$(native_executable_name Linux)" = "vulnlog" ]
  [ "$(native_executable_name macOS)" = "vulnlog" ]
  # The JVM build ships launcher scripts, so Windows gets the .bat that cmd
  # and pwsh can resolve, not an .exe.
  [ "$(jvm_executable_name Windows)" = "vulnlog.bat" ]
  [ "$(jvm_executable_name Linux)" = "vulnlog" ]
}

@test "version normalisation accepts both tag and bare forms" {
  [ "$(normalize_version 0.17.0)" = "0.17.0" ]
  [ "$(normalize_version v0.17.0)" = "0.17.0" ]
  # Only a leading v is stripped, never one inside the string.
  [ "$(normalize_version 1.0.0-dev)" = "1.0.0-dev" ]
}

@test "native assets are named by platform, JVM assets by version" {
  [ "$(native_asset_name linux-amd64)" = "vulnlog-linux-amd64.zip" ]
  [ "$(jvm_asset_name 0.17.0)" = "vulnlog-0.17.0.zip" ]
}

@test "download URL pins the versionless native asset via the tag" {
  [ "$(download_url vulnlog/vulnlog 0.17.0 "$(native_asset_name linux-amd64)")" \
    = "https://github.com/vulnlog/vulnlog/releases/download/v0.17.0/vulnlog-linux-amd64.zip" ]
}

@test "the latest tag is read out of the /releases/latest redirect target" {
  [ "$(tag_from_release_url https://github.com/vulnlog/vulnlog/releases/tag/v0.17.0)" = "0.17.0" ]
  [ "$(tag_from_release_url https://github.com/vulnlog/vulnlog/releases/tag/0.17.0)" = "0.17.0" ]
}

@test "a redirect target that is not a release tag is rejected, not guessed at" {
  # curl leaves this empty when there was no redirect at all.
  run tag_from_release_url ""
  [ "$status" -ne 0 ]
  run tag_from_release_url "https://github.com/vulnlog/vulnlog/releases"
  [ "$status" -ne 0 ]
  run tag_from_release_url "https://github.com/vulnlog/vulnlog/releases/tag/"
  [ "$status" -ne 0 ]
}

@test "tool cache layout matches the actions/tool-cache convention" {
  [ "$(tool_cache_dir /opt/hostedtoolcache vulnlog 0.17.0 X64)" \
    = "/opt/hostedtoolcache/vulnlog/0.17.0/X64" ]
}

@test "the two distributions never share a tool cache directory" {
  # They are not interchangeable on disk: one is a bare executable, the other
  # an application layout.
  [ "$(tool_cache_dir /c vulnlog 0.17.0 X64)" != "$(tool_cache_dir /c vulnlog-jvm 0.17.0 X64)" ]
}

@test "sourcing the script runs no side effects and sets no shell options" {
  # bats runs test bodies under errexit, so ask a clean shell instead: if
  # main() ever escapes the source guard this hits the network, and errexit
  # leaking out of a sourced library breaks every caller.
  run bash -c 'set +eu; source "$1"; case "$-" in *e*|*u*) exit 1;; esac' _ \
    "${BATS_TEST_DIRNAME}/../install.sh"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
