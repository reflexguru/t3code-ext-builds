#!/usr/bin/env bash
# Write a provenance file naming every pull request, patch, and conflict
# resolution that went into a Windows build.
#
#   write-provenance.sh OUTPUT_FILE
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: $0 OUTPUT_FILE" >&2
  exit 2
fi

output="$1"
repo_root="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
flavor="${FLAVOR:?FLAVOR is required}"
tag="${TAG:?TAG is required}"
pr_spec="${PR_SPEC:?PR_SPEC is required}"

mkdir -p "$(dirname "$output")"

{
  echo "Flavor:           ${flavor}"
  echo "Platform:         windows-x64"
  echo "Upstream project: https://github.com/pingdotgg/t3code"
  echo "Base nightly tag: ${tag}"
  echo "Installer built:  $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  echo
  echo "Layered upstream pull requests, in merge order:"
  for entry in ${pr_spec}; do
    number="${entry%%:*}"
    sha="${entry#*:}"
    printf '  #%s https://github.com/pingdotgg/t3code/pull/%s\n' "$number" "$number"
    printf '     head commit %s\n' "$sha"
  done
} > "$output"

shopt -s nullglob
for patch in "${repo_root}/patches/${flavor}"/*.patch; do
  printf 'Local patch:      %s (sha256 %s)\n' \
    "$(basename "$patch")" "$(sha256sum "$patch" | cut -d' ' -f1)" \
    >> "$output"
done
for entry in ${pr_spec}; do
  number="${entry%%:*}"
  manifest="${repo_root}/resolutions/${number}/conflicts.tsv"
  if [[ -f "$manifest" ]]; then
    printf 'Conflict carry:   %s\n' "resolutions/${number}/conflicts.tsv" \
      >> "$output"
  fi
done
