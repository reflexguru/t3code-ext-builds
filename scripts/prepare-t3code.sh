#!/usr/bin/env bash
# Clone or update the upstream T3 Code checkout under .work/t3code and reset it
# to TAG (merge mode) or SHA (pin mode).
set -euo pipefail

repo_root="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
t3code_repo="${T3CODE_REPO:-pingdotgg/t3code}"
src="${T3CODE_SRC:-${repo_root}/.work/t3code}"
source_mode="${SOURCE_MODE:?SOURCE_MODE is required}"
remote_url="https://github.com/${t3code_repo}.git"

mkdir -p "$(dirname "$src")"
if [[ ! -d "${src}/.git" ]]; then
  # Full objects are required: merging a pull request onto a nightly tag
  # reads merge-base blobs. A partial clone makes that fetch fail.
  git clone "$remote_url" "$src"
fi

cd "$src"
git config core.autocrlf false
git config core.eol lf
git config core.longpaths true
git remote set-url origin "$remote_url"
git fetch --tags --force --prune origin

if [[ "$source_mode" == "pin" ]]; then
  sha="${SHA:?SHA is required in pin mode}"
  git fetch --force origin "$sha"
  git reset --hard "$sha"
  git clean -fdx -e node_modules -e .turbo
else
  tag="${TAG:?TAG is required in merge mode}"
  git fetch --force origin "refs/tags/${tag}:refs/tags/${tag}"
  git reset --hard "refs/tags/${tag}"
  git clean -fdx -e node_modules -e .turbo
fi

echo "T3 Code source at $(git rev-parse HEAD) in ${src}"
