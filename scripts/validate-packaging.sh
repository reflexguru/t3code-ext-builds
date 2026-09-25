#!/usr/bin/env bash
# Static checks for the packaging tree. Does not build T3 Code.
set -euo pipefail

repo_root="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
cd "$repo_root"

failed=0

for script in scripts/*.sh; do
  if ! bash -n "$script"; then
    echo "bash -n failed: ${script}" >&2
    failed=1
  fi
done

expected_patches=(
  patches/prs/0001-command-code-steer-on-mid-turn-send.patch
  patches/v2-prs/0001-acp-bundled-oh-my-pi-entry.patch
  patches/v2-prs/0002-command-code-provider.patch
)
for patch in "${expected_patches[@]}"; do
  if [[ ! -f "$patch" ]]; then
    echo "missing patch: ${patch}" >&2
    failed=1
  fi
done

shopt -s nullglob
for manifest in resolutions/*/conflicts.tsv; do
  directory="$(dirname "$manifest")"
  while read -r head_hash pr_hash path; do
    path="${path%$'\r'}"
    [[ -n "$path" ]] || continue
    if [[ ! -f "${directory}/${path}" ]]; then
      echo "${manifest} names ${path}, which is missing." >&2
      failed=1
      continue
    fi
    if grep -q '^<<<<<<< \|^>>>>>>>' "${directory}/${path}"; then
      echo "${directory}/${path} still holds conflict markers." >&2
      failed=1
    fi
    if [[ ! "$head_hash" =~ ^[0-9a-f]{64}$ || ! "$pr_hash" =~ ^[0-9a-f]{64}$ ]]; then
      echo "${manifest} has a malformed hash line for ${path}." >&2
      failed=1
    fi
  done < "$manifest"
done

if [[ "$failed" -ne 0 ]]; then
  exit 1
fi

echo "Packaging tree is valid."
