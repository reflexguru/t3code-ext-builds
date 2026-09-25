#!/usr/bin/env bash
# Resolve the newest upstream T3 Code nightly tag.
#
# Upstream publishes two prerelease channels: `-nightly.` (supported nightly
# builds) and `-preview.` (maintainer test builds, explicitly unsupported).
# Only nightly tags are eligible. We sort explicitly by published_at because
# the GitHub releases API does not guarantee newest-first ordering.
#
# Uses `gh` so a local Windows Git Bash does not need a separate jq install.
set -euo pipefail

repo="${T3CODE_REPO:-pingdotgg/t3code}"

if ! command -v gh >/dev/null 2>&1; then
  echo "gh (GitHub CLI) is required to resolve the latest nightly tag." >&2
  exit 1
fi

tag="$(gh api "repos/${repo}/releases?per_page=100" --jq '
  [ .[]
    | select(.prerelease and (.draft | not))
    | select(.tag_name | test("^v[0-9]+[.][0-9]+[.][0-9]+-nightly[.][0-9]{8}[.][0-9]+$"))
  ]
  | sort_by(.published_at)
  | reverse
  | .[0].tag_name // empty
')"

if [[ -z "$tag" ]]; then
  echo "No T3 Code nightly release found in ${repo}." >&2
  echo "Newest prereleases observed:" >&2
  gh api "repos/${repo}/releases?per_page=100" --jq '
    [ .[] | select(.prerelease and (.draft | not)) ][0:10][]
    | "  \(.published_at)  \(.tag_name)"
  ' >&2
  exit 1
fi

printf '%s\n' "$tag"
