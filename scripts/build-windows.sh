#!/usr/bin/env bash
# Local Windows entry point: resolve the flavor, layer pull requests and
# patches onto pingdotgg/t3code, then build the NSIS installer.
#
#   ./scripts/build-windows.sh prs
#   ./scripts/build-windows.sh v2-prs --force
#   ./scripts/build-windows.sh prs --pr-refs "refs/pull/10861/head refs/pull/11973/head"
#   ./scripts/build-windows.sh prs --skip-package
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export REPO_ROOT="$repo_root"
cd "$repo_root"

usage() {
  echo "usage: $0 <prs|v2|v2-prs> [--force] [--skip-package] [--skip-tests] [--pr-refs REFS]" >&2
  exit 2
}

[[ $# -ge 1 ]] || usage
flavor="$1"
shift
case "$flavor" in
  prs|v2|v2-prs) ;;
  *) usage ;;
esac

force="false"
skip_package="false"
skip_tests="false"
pr_refs=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --force) force="true"; shift ;;
    --skip-package) skip_package="true"; shift ;;
    --skip-tests) skip_tests="true"; shift ;;
    --pr-refs)
      [[ $# -ge 2 ]] || usage
      pr_refs="$2"
      shift 2
      ;;
    *) usage ;;
  esac
done

export FLAVOR="$flavor"
export FORCE="$force"
export T3CODE_REPO="${T3CODE_REPO:-pingdotgg/t3code}"
export T3CODE_SRC="${T3CODE_SRC:-${repo_root}/.work/t3code}"

case "$flavor" in
  prs)
    export SOURCE_MODE="merge"
    export TEST_KIND="command-code"
    default_refs="refs/pull/10861/head refs/pull/11973/head"
    ;;
  v2)
    export SOURCE_MODE="pin"
    export TEST_KIND="v2-command-code-optional"
    default_refs="refs/pull/2829/head"
    ;;
  v2-prs)
    export SOURCE_MODE="pin"
    export TEST_KIND="v2-command-code"
    default_refs="refs/pull/2829/head"
    ;;
esac
export PR_REFS="${pr_refs:-$default_refs}"

if ! command -v gh >/dev/null 2>&1; then
  echo "gh (GitHub CLI) is required to resolve pull request heads and nightly tags." >&2
  exit 1
fi
if ! command -v git >/dev/null 2>&1; then
  echo "git is required." >&2
  exit 1
fi

./scripts/resolve-build.sh >/dev/null
# shellcheck disable=SC1091
source .work/resolve.env
export TAG SHA VERSION PR_SPEC

if [[ "$should_build" != "true" ]]; then
  echo "Nothing to do. Pass --force to rebuild ${key}."
  exit 0
fi

./scripts/prepare-t3code.sh
if [[ "$SOURCE_MODE" == "merge" ]]; then
  ./scripts/layer-pull-requests.sh
else
  ./scripts/confirm-pinned-source.sh
fi
./scripts/apply-patches.sh

if [[ "$skip_package" == "true" ]]; then
  echo "Prepared ${T3CODE_SRC} (${flavor} ${version}). Skipping the installer."
  exit 0
fi

if ! command -v vp >/dev/null 2>&1 && ! command -v vp.cmd >/dev/null 2>&1; then
  echo "Vite+ (vp) is not on PATH. Install it from https://vite.plus then re-run." >&2
  echo "  irm https://vite.plus/ps1 | iex" >&2
  exit 1
fi
if ! command -v rustc >/dev/null 2>&1; then
  echo "Rust is not on PATH. Install the stable toolchain, then re-run." >&2
  exit 1
fi

run_vp() {
  if command -v vp >/dev/null 2>&1; then
    vp "$@"
    return
  fi
  MSYS_NO_PATHCONV=1 cmd.exe /c vp.cmd "$@"
}

cd "$T3CODE_SRC"
export T3CODE_CLERK_PUBLISHABLE_KEY="${T3CODE_CLERK_PUBLISHABLE_KEY:-pk_live_Y2xlcmsudDMuY29kZXMk}"
export T3CODE_CLERK_JWT_TEMPLATE="${T3CODE_CLERK_JWT_TEMPLATE:-t3-relay}"
export T3CODE_CLERK_CLI_OAUTH_CLIENT_ID="${T3CODE_CLERK_CLI_OAUTH_CLIENT_ID:-hzxSgY2cH10sDU2r}"
export T3CODE_RELAY_URL="${T3CODE_RELAY_URL:-https://relay.t3.codes}"

run_vp install \
  --filter=t3... \
  --filter=@t3tools/web... \
  --filter=@t3tools/desktop... \
  --filter=@t3tools/scripts...

if [[ "$skip_tests" != "true" ]]; then
  "$repo_root/scripts/test-command-code.sh"
fi

node scripts/update-release-package-versions.ts "$version"
run_vp run build:desktop
run_vp run dist:desktop:artifact \
  --platform win \
  --target nsis \
  --arch x64 \
  --build-version "$version" \
  --skip-build \
  --verbose

dest="${repo_root}/release/${flavor}/${version}"
"$repo_root/scripts/collect-windows-artifacts.sh" "${T3CODE_SRC}/release" "$dest"
"$repo_root/scripts/write-provenance.sh" "${dest}/upstream-prs.txt"
"$repo_root/scripts/record-last-built-key.sh" "$flavor" "$key"

echo
echo "Windows ${flavor} build is in ${dest}"
