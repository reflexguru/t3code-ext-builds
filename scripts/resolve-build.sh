#!/usr/bin/env bash
# Resolve the upstream nightly, pull request heads, layer digest, and whether
# this flavor should build. Writes key=value lines to stdout, to
# .work/resolve.env, and to $GITHUB_OUTPUT when that file is set.
#
# Required environment:
#   FLAVOR          prs | v2 | v2-prs
#   PR_REFS         space-separated refs/pull/<n>/head
#   SOURCE_MODE     merge (onto the nightly tag) | pin (first PR head)
# Optional:
#   FORCE           true to rebuild even if the key matches last-built-key
#   T3CODE_REPO     default pingdotgg/t3code
#   REPO_ROOT       this packaging repository
#   GITHUB_TOKEN    authenticated GitHub API
set -euo pipefail

repo_root="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
cd "$repo_root"

flavor="${FLAVOR:?FLAVOR is required}"
pr_refs="${PR_REFS:?PR_REFS is required}"
source_mode="${SOURCE_MODE:?SOURCE_MODE is required}"
force="${FORCE:-false}"
t3code_repo="${T3CODE_REPO:-pingdotgg/t3code}"

case "$flavor" in
  prs|v2|v2-prs) ;;
  *)
    echo "unsupported flavor: ${flavor}" >&2
    exit 2
    ;;
esac

case "$source_mode" in
  merge|pin) ;;
  *)
    echo "unsupported SOURCE_MODE: ${source_mode}" >&2
    exit 2
    ;;
esac

export T3CODE_REPO="$t3code_repo"

pr_spec=""
sha_key=""
first_sha=""
for ref in ${pr_refs}; do
  number="${ref#refs/pull/}"
  number="${number%/head}"
  if [[ ! "$number" =~ ^[0-9]+$ ]]; then
    echo "Unsupported pull request ref: ${ref}" >&2
    exit 1
  fi
  sha="$(gh api "repos/${t3code_repo}/pulls/${number}" --jq '.head.sha')"
  test -n "$sha" || { echo "Could not resolve PR ${number}." >&2; exit 1; }
  pr_spec+="${pr_spec:+ }${number}:${sha}"
  sha_key+="+${sha}"
  if [[ -z "$first_sha" ]]; then
    first_sha="$sha"
  fi
done
test -n "$pr_spec" || { echo "No pull requests to layer." >&2; exit 1; }

layer_paths=()
[[ -d "patches/${flavor}" ]] && layer_paths+=("patches/${flavor}")
for entry in ${pr_spec}; do
  number="${entry%%:*}"
  [[ -d "resolutions/${number}" ]] && layer_paths+=("resolutions/${number}")
done
if [[ ${#layer_paths[@]} -eq 0 ]]; then
  layer_digest="none"
else
  layer_digest="$(find "${layer_paths[@]}" -type f -print0 | sort -z \
    | xargs -0 cat | sha256sum | cut -c1-12)"
fi

tag=""
version=""
sha=""
key=""

if [[ "$source_mode" == "merge" ]]; then
  tag="$(bash scripts/resolve-latest-nightly.sh)"
  version="${tag#v}"
  sha="$(gh api "repos/${t3code_repo}/git/ref/tags/${tag}" --jq '.object.sha' 2>/dev/null || true)"
  if [[ -z "$sha" || "$sha" == "null" ]]; then
    sha="$(gh api "repos/${t3code_repo}/git/matching-refs/tags/${tag}" --jq '.[0].object.sha')"
  fi
  key="${tag}${sha_key}+p${layer_digest}"
  echo "Resolved upstream nightly: ${tag}" >&2
else
  sha="$first_sha"
  base="$(bash scripts/resolve-latest-nightly.sh)"
  base_version="${base#v}"
  base_version="${base_version%%-nightly.*}"
  test -n "$base_version" || {
    echo "Could not read the base version out of ${base}." >&2
    exit 1
  }
  committed="$(gh api "repos/${t3code_repo}/commits/${sha}" --jq '.commit.committer.date')"
  test -n "$committed" || { echo "Could not read the commit date of ${sha}." >&2; exit 1; }
  stamp="${committed:0:4}${committed:5:2}${committed:8:2}.${sha:0:12}"
  version="${base_version}-nightly.${stamp}"
  tag="v${version}"
  key="v${base_version}${sha_key}+p${layer_digest}"
  echo "Pinned source: ${sha} (${tag}, base version from ${base})" >&2
fi

echo "Pull requests: ${pr_spec}" >&2
echo "Layer digest: p${layer_digest}" >&2

last="$(tr -d '\r\n' < "packaging/${flavor}/last-built-key" 2>/dev/null || true)"
if [[ "$force" == "true" || "$key" != "$last" ]]; then
  should_build="true"
  echo "Will build (force=${force} last=${last:-none})" >&2
else
  should_build="false"
  echo "Skipping; already recorded ${key}" >&2
fi

posix_assign() {
  printf "%s='" "$1"
  printf '%s' "$2" | sed "s/'/'\\\\''/g"
  printf "'\n"
}

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  {
    printf '%s=%s\n' should_build "$should_build"
    printf '%s=%s\n' tag "$tag"
    printf '%s=%s\n' sha "$sha"
    printf '%s=%s\n' version "$version"
    printf '%s=%s\n' pr_spec "$pr_spec"
    printf '%s=%s\n' key "$key"
    printf '%s=%s\n' flavor "$flavor"
    printf '%s=%s\n' source_mode "$source_mode"
    printf '%s=%s\n' layer_digest "$layer_digest"
  } >> "$GITHUB_OUTPUT"
fi

mkdir -p .work
{
  posix_assign should_build "$should_build"
  posix_assign tag "$tag"
  posix_assign sha "$sha"
  posix_assign version "$version"
  posix_assign pr_spec "$pr_spec"
  posix_assign key "$key"
  posix_assign flavor "$flavor"
  posix_assign source_mode "$source_mode"
  posix_assign layer_digest "$layer_digest"
} > .work/resolve.env
cat .work/resolve.env
