#!/usr/bin/env bash
# Merge upstream pull requests onto the nightly tag in $T3CODE_SRC, installing
# recorded conflict resolutions from $REPO_ROOT/resolutions/<number>/ when a
# merge does not apply cleanly.
#
# Required environment:
#   T3CODE_SRC   checkout of pingdotgg/t3code at the nightly tag
#   PR_REFS      space-separated refs/pull/<n>/head, in merge order
#   TAG          nightly tag being merged onto (for error text)
# Optional:
#   REPO_ROOT    this packaging repository (default: parent of scripts/)
set -euo pipefail

repo_root="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
src="${T3CODE_SRC:?T3CODE_SRC is required}"
pr_refs="${PR_REFS:?PR_REFS is required}"
tag="${TAG:?TAG is required}"

cd "$src"
git config core.autocrlf false
git config core.eol lf
git config user.name "${GIT_AUTHOR_NAME:-t3code-windows-nightly}"
git config user.email "${GIT_AUTHOR_EMAIL:-t3code-windows-nightly@users.noreply.github.com}"

for ref in ${pr_refs}; do
  number="${ref#refs/pull/}"
  number="${number%/head}"
  if [[ ! "$number" =~ ^[0-9]+$ ]]; then
    echo "::error::Unsupported pull request ref: ${ref}" >&2
    exit 1
  fi
  git fetch --no-tags origin "+${ref}:refs/remotes/origin/pr-${number}"
  target="refs/remotes/origin/pr-${number}"
  echo "Merging ${ref} ($(git rev-parse --short "${target}"))"
  if git merge --no-edit "$target"; then
    continue
  fi

  resolutions="${repo_root}/resolutions/${number}"
  if [[ ! -f "$(git rev-parse --git-path MERGE_HEAD)" ]]; then
    echo "::error::Merging ${ref} failed before it produced a conflict. Read the git output above; nothing was committed." >&2
    exit 1
  fi
  if [[ ! -f "${resolutions}/conflicts.tsv" ]]; then
    echo "::error::${ref} does not merge onto ${tag} and resolutions/${number}/conflicts.tsv is missing." >&2
    exit 1
  fi

  while read -r head_hash pr_hash path; do
    path="${path%$'\r'}"
    [[ -n "$path" ]] || continue
    actual_head="$(git show "HEAD:${path}" | sha256sum | cut -d' ' -f1)"
    actual_pr="$(git show "${target}:${path}" | sha256sum | cut -d' ' -f1)"
    if [[ "$actual_head" != "$head_hash" || "$actual_pr" != "$pr_hash" ]]; then
      echo "::error::The recorded resolution for ${path} is stale: the nightly tag or PR ${number} changed it. Resolve the conflict again and refresh resolutions/${number}/." >&2
      exit 1
    fi
    mkdir -p "$(dirname "${path}")"
    cp "${resolutions}/${path}" "${path}"
    git add "${path}"
    echo "Installed the recorded resolution for ${path}"
  done < "${resolutions}/conflicts.tsv"

  unresolved="$(git diff --name-only --diff-filter=U || true)"
  if [[ -n "$unresolved" ]]; then
    echo "::error::PR ${number} conflicts in files with no recorded resolution:" >&2
    echo "$unresolved" >&2
    exit 1
  fi
  git commit --no-edit
done

echo "Built commit: $(git rev-parse HEAD)"
