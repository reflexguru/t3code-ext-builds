#!/usr/bin/env bash
# Create or update the rolling GitHub prerelease that holds a flavor's Windows
# installers.
#
#   publish-github-release.sh ARTIFACT_DIR
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: $0 ARTIFACT_DIR" >&2
  exit 2
fi

artifact_dir="$1"
flavor="${FLAVOR:?FLAVOR is required}"
version="${VERSION:?VERSION is required}"
tag="${flavor}-nightly"
repo="${GITHUB_REPOSITORY:?GITHUB_REPOSITORY is required}"

case "$flavor" in
  prs)
    title='T3 Code + Command Code + Oh My Pi nightly (Windows)'
    notes='Rolling prerelease of the Windows NSIS installer built from the upstream nightly with Command Code (#10861) and Oh My Pi (#11973) layered on top.'
    ;;
  v2)
    title='T3 Code v2 orchestrator nightly (Windows)'
    notes='Rolling prerelease of the Windows NSIS installer built from the unmerged v2 orchestrator branch (Pi / ACP).'
    ;;
  v2-prs)
    title='T3 Code v2 + Command Code + Oh My Pi nightly (Windows)'
    notes='Rolling prerelease of the Windows NSIS installer built from the v2 orchestrator with the ported Command Code provider and the bundled Oh My Pi ACP entry.'
    ;;
  *)
    echo "unsupported flavor: ${flavor}" >&2
    exit 2
    ;;
esac

notes+=$'\n\n'"Version: ${version}"$'\n'
if [[ -f "${artifact_dir}/upstream-prs.txt" ]]; then
  notes+=$'\n'"$(cat "${artifact_dir}/upstream-prs.txt")"
fi

if ! gh release view "$tag" --repo "$repo" >/dev/null 2>&1; then
  gh release create "$tag" --repo "$repo" --prerelease \
    --title "$title" \
    --notes "$notes"
else
  gh release edit "$tag" --repo "$repo" --title "$title" --notes "$notes"
fi

shopt -s nullglob
uploads=("${artifact_dir}"/*)
if [[ ${#uploads[@]} -eq 0 ]]; then
  echo "No files to upload in ${artifact_dir}" >&2
  exit 1
fi
gh release upload "$tag" --repo "$repo" --clobber "${uploads[@]}"
