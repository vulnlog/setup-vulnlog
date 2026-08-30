#!/usr/bin/env bash
#
# Resolve, download and install the Vulnlog CLI on a GitHub Actions runner.
#
# Runs on Linux, macOS and Windows (Git Bash) runners from a single code path, and needs no credentials.
#
# Everything above main() is pure: each function takes its inputs as arguments and writes to stdout,
# so tests/install.bats can source this file and check the platform mapping without touching the network.
# "set -euo pipefail" is applied only on the executed path, so sourcing never changes the caller's shell.
#
# Environment:
#   VULNLOG_INPUT_VERSION   "0.17.0" | "v0.17.0" | "latest"
#   RUNNER_OS RUNNER_ARCH RUNNER_TOOL_CACHE GITHUB_PATH GITHUB_OUTPUT

REPO='vulnlog/vulnlog'

# --------------------------------------------------------------------------
# Pure functions
# --------------------------------------------------------------------------

# Map the runner's own OS/arch labels onto the platform slug used in native release asset names.
# RUNNER_OS and RUNNER_ARCH are set by the runner on every platform, so this is more reliable than parsing uname.
#
# Returns non-zero for combinations Vulnlog publishes no native build for. main() treats that as "use the JVM distribution".
platform_slug() {
  local os="$1" arch="$2"
  case "${os}:${arch}" in
    Linux:X64) printf 'linux-amd64' ;;
    macOS:ARM64) printf 'macos-aarch64' ;;
    Windows:X64) printf 'windows-amd64' ;;
    *) return 1 ;;
  esac
}

# Accept "0.17.0" and "v0.17.0" alike. Everything downstream works with the bare number, because tags carry the "v" but asset names do not.
normalize_version() {
  printf '%s' "${1#v}"
}

# Native archives are versionless. The tag in the URL is what pins them.
native_asset_name() {
  printf 'vulnlog-%s.zip' "$1"
}

# The JVM distribution is the fallback for platforms without a native build.
# It is the only asset whose name carries the version.
jvm_asset_name() {
  printf 'vulnlog-%s.zip' "$1"
}

download_url() {
  local repo="$1" version="$2" asset="$3"
  printf 'https://github.com/%s/releases/download/v%s/%s' "${repo}" "${version}" "${asset}"
}

# Native archives hold a single bare executable, only Windows carries a suffix.
native_executable_name() {
  case "$1" in
    Windows) printf 'vulnlog.exe' ;;
    *) printf 'vulnlog' ;;
  esac
}

# The JVM distribution ships launcher scripts instead of an executable. The .bat is the one cmd.exe and pwsh can resolve.
jvm_executable_name() {
  case "$1" in
    Windows) printf 'vulnlog.bat' ;;
    *) printf 'vulnlog' ;;
  esac
}

# Layout matches @actions/tool-cache, a self-hosted runner with a warm tool cache gets a hit for free.
# The two distributions are separate tools because they are not interchangeable on disk.
tool_cache_dir() {
  local root="$1" tool="$2" version="$3" arch="$4"
  printf '%s/%s/%s/%s' "${root}" "${tool}" "${version}" "${arch}"
}

# Pull the tag out of the URL that /releases/latest redirects to, e.g.
# https://github.com/vulnlog/vulnlog/releases/tag/v0.17.0 -> 0.17.0
tag_from_release_url() {
  local url="$1" tag="${1##*/tag/}"
  [ "${tag}" != "${url}" ] || return 1
  [ -n "${tag}" ] || return 1
  normalize_version "${tag}"
}

# --------------------------------------------------------------------------
# Runner helpers
# --------------------------------------------------------------------------

fail() {
  printf '::error::%s\n' "$*" >&2
  exit 1
}

info() {
  printf '%s\n' "$*" >&2
}

warn() {
  printf '::warning::%s\n' "$*" >&2
}

emit_output() {
  [ -n "${GITHUB_OUTPUT:-}" ] || return 0
  printf '%s=%s\n' "$1" "$2" >>"${GITHUB_OUTPUT}"
}

# Emits the path with no trailing newline, so callers pick the separator.
# GITHUB_PATH is read by the runner, not by bash, so a Windows entry has to be a native path.
# Writing the msys form here is the classic bug: "vulnlog" then resolves in bash steps and nowhere else.
runner_path() {
  if [ "${RUNNER_OS:-}" = "Windows" ]; then
    cygpath -w "$1" | tr -d '\r\n'
  else
    printf '%s' "$1"
  fi
}

fetch() {
  local url="$1" dest="$2"
  # No --retry-all-errors: a 404 means the version or asset is wrong, and
  # retrying it three times only makes that failure slower.
  curl --fail --silent --show-error --location \
    --retry 3 --connect-timeout 10 \
    --output "${dest}" "${url}"
}

# github.com/vulnlog/vulnlog/releases/latest redirects to the newest stable release,
# so a HEAD request resolves the version with no API call, no token and no rate limit.
# Pre-releases are never the target of that redirect.
resolve_latest_version() {
  local repo="$1" location
  location="$(
    curl --fail --silent --show-error --head --connect-timeout 10 --retry 3 \
      --output /dev/null --write-out '%{redirect_url}' \
      "https://github.com/${repo}/releases/latest"
  )" || fail "Could not reach github.com to resolve the latest release of ${repo}."

  tag_from_release_url "${location}" ||
    fail "Could not read a release tag out of '${location}'. Does ${repo} have a published release?"
}

unzip_to() {
  local archive="$1" dest="$2"
  mkdir -p "${dest}"
  # Git Bash ships neither unzip nor bsdtar reliably, so fall back through what
  # the Windows runner image does provide.
  if command -v unzip >/dev/null 2>&1; then
    unzip -q -o "${archive}" -d "${dest}"
  elif command -v 7z >/dev/null 2>&1; then
    7z x -y -o"${dest}" "${archive}" >/dev/null
  elif command -v powershell >/dev/null 2>&1; then
    powershell -NoProfile -NonInteractive -Command \
      "Expand-Archive -Force -Path '$(cygpath -w "${archive}")' -DestinationPath '$(cygpath -w "${dest}")'"
  else
    fail 'No unzip, 7z or powershell available to extract the download.'
  fi
}

# Publish a staged install directory into the tool cache in one step.
# Two jobs sharing a self-hosted runner can race here; whoever loses just reuses the directory the winner published, which is byte-identical.
publish_install_dir() {
  local staged="$1" install_dir="$2"
  mkdir -p "$(dirname "${install_dir}")"
  if ! mv "${staged}" "${install_dir}" 2>/dev/null; then
    [ -d "${install_dir}" ] ||
      fail "Could not move the extracted CLI into ${install_dir}."
    info 'Another job populated the tool cache first; reusing it.'
  fi
}

# --------------------------------------------------------------------------
# main
# --------------------------------------------------------------------------

WORKDIR=''
cleanup() { [ -z "${WORKDIR}" ] || rm -rf "${WORKDIR}"; }

main() {
  local version dist slug tool asset exe install_dir bin_dir binary staged url

  [ -n "${RUNNER_OS:-}" ] || fail 'RUNNER_OS is not set; this action only runs on a GitHub Actions runner.'
  [ -n "${RUNNER_ARCH:-}" ] || fail 'RUNNER_ARCH is not set; this action only runs on a GitHub Actions runner.'
  [ -n "${RUNNER_TOOL_CACHE:-}" ] || fail 'RUNNER_TOOL_CACHE is not set; this action only runs on a GitHub Actions runner.'
  [ -n "${GITHUB_PATH:-}" ] || fail 'GITHUB_PATH is not set; this action only runs on a GitHub Actions runner.'

  version="${VULNLOG_INPUT_VERSION:-latest}"
  if [ "${version}" = "latest" ]; then
    version="$(resolve_latest_version "${REPO}")"
    info "Resolved latest to ${version}."
  else
    version="$(normalize_version "${version}")"
  fi

  # Prefer the self-contained native build; fall back to the JVM build on the platforms Vulnlog does not ship a native binary for.
  if slug="$(platform_slug "${RUNNER_OS}" "${RUNNER_ARCH}")"; then
    dist='native'
    tool='vulnlog'
    asset="$(native_asset_name "${slug}")"
    exe="$(native_executable_name "${RUNNER_OS}")"
  else
    dist='jvm'
    tool='vulnlog-jvm'
    asset="$(jvm_asset_name "${version}")"
    exe="$(jvm_executable_name "${RUNNER_OS}")"
    info "No native Vulnlog build for ${RUNNER_OS}/${RUNNER_ARCH}; using the JVM distribution."
    command -v java >/dev/null 2>&1 ||
      fail "The JVM distribution needs Java 21+ on PATH. Add actions/setup-java before this step."
  fi

  install_dir="$(tool_cache_dir "${RUNNER_TOOL_CACHE}" "${tool}" "${version}" "${RUNNER_ARCH}")"
  # The native archive is a bare executable; the JVM one is an application layout whose launcher lives under bin/.
  if [ "${dist}" = 'native' ]; then
    bin_dir="${install_dir}"
  else
    bin_dir="${install_dir}/bin"
  fi
  binary="${bin_dir}/${exe}"

  if [ -f "${binary}" ]; then
    # The whole point of the tool-cache layout: calling this action again in the same job costs one stat() rather than a download.
    info "vulnlog ${version} (${dist}) is already installed; skipping the download."
    emit_output 'cache-hit' 'true'
  else
    emit_output 'cache-hit' 'false'
    WORKDIR="$(mktemp -d)"
    trap cleanup EXIT
    staged="${WORKDIR}/staged"

    url="$(download_url "${REPO}" "${version}" "${asset}")"
    info "Downloading ${url}"
    fetch "${url}" "${WORKDIR}/${asset}" ||
      fail "Could not download ${asset}. Does release v${version} of ${REPO} exist and publish that asset?"

    unzip_to "${WORKDIR}/${asset}" "${staged}"

    if [ "${dist}" = 'jvm' ]; then
      # The JVM archive wraps everything in a vulnlog-<version>/ directory. lift it so the tool-cache layout is the same shape for both dists.
      local root
      root="$(find "${staged}" -mindepth 1 -maxdepth 1 -type d -name 'vulnlog-*' -print -quit)"
      [ -n "${root}" ] || fail "Archive ${asset} has no vulnlog-* top-level directory."
      mv "${root}" "${staged}.root" && rm -rf "${staged}" && mv "${staged}.root" "${staged}"
      # A zip loses the executable bit on some extractors, so always restore it.
      chmod +x "${staged}/bin/"* 2>/dev/null || true
    else
      # Be tolerant of a future archive that nests the executable.
      if [ ! -f "${staged}/${exe}" ]; then
        local found
        found="$(find "${staged}" -type f -name "${exe}" -print -quit)"
        [ -n "${found}" ] || fail "Archive ${asset} contained no ${exe}."
        mv "${found}" "${staged}/${exe}"
      fi
      chmod +x "${staged}/${exe}" 2>/dev/null || true
    fi

    publish_install_dir "${staged}" "${install_dir}"
    [ -f "${binary}" ] || fail "Install finished but ${binary} is missing."
  fi

  # GITHUB_PATH is line-delimited; a missing newline glues this entry onto whatever the next step appends.
  printf '%s\n' "$(runner_path "${bin_dir}")" >>"${GITHUB_PATH}"
  emit_output 'version' "${version}"
  emit_output 'distribution' "${dist}"
  emit_output 'path' "$(runner_path "${binary}")"

  # Cheap smoke test: catches a corrupt download far closer to the cause than the user's first real "vulnlog" step would.
  "${binary}" --version >/dev/null 2>&1 ||
    warn "Installed ${binary} but 'vulnlog --version' did not succeed."

  info "vulnlog ${version} (${dist}) is on PATH."
}

# Only run when executed, so "source install.sh" in the test suite gets the functions without the side effects, and without inheriting our shell options.
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  set -euo pipefail
  main "$@"
fi
