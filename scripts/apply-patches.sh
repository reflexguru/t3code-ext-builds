#!/usr/bin/env bash
# Apply patches/<FLAVOR>/*.patch onto $T3CODE_SRC. Fails if a patch does not
# apply cleanly: a silent mismatch would ship a tree nobody reviewed.
set -euo pipefail

repo_root="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
src="${T3CODE_SRC:?T3CODE_SRC is required}"
flavor="${FLAVOR:?FLAVOR is required}"

cd "$src"
git config core.autocrlf false
git config core.eol lf

shopt -s nullglob
patches=("${repo_root}/patches/${flavor}"/*.patch)
if [[ ${#patches[@]} -eq 0 ]]; then
  echo "No local patches to apply."
  exit 0
fi

for patch in "${patches[@]}"; do
  echo "Applying $(basename "${patch}")"
  if ! git apply --verbose "${patch}"; then
    echo "::error::Could not apply $(basename "${patch}"); the pull requests changed the files it touches." >&2
    exit 1
  fi
done
git --no-pager diff --stat
