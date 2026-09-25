#!/usr/bin/env bash
# Record the build key for a flavor so the next run can skip unchanged inputs.
# Inside GitHub Actions this also commits and pushes to main; locally it only
# writes the file.
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $0 <flavor> <key>" >&2
  exit 2
fi

flavor=$1
key=$2
repo_root="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
cd "$repo_root"

case "$flavor" in
  prs)
    record_path=packaging/prs/last-built-key
    commit_label='T3 Code prs Windows nightly'
    already_message="prs nightly ${key} is already recorded"
    ;;
  v2)
    record_path=packaging/v2/last-built-key
    commit_label='T3 Code v2 Windows nightly'
    already_message="v2 nightly ${key} is already recorded"
    ;;
  v2-prs)
    record_path=packaging/v2-prs/last-built-key
    commit_label='T3 Code v2-prs Windows nightly'
    already_message="v2-prs nightly ${key} is already recorded"
    ;;
  *)
    echo "unsupported flavor: $flavor" >&2
    exit 2
    ;;
esac

mkdir -p "${record_path%/*}"
printf '%s\n' "$key" > "$record_path"
echo "Recorded ${record_path}: ${key}"

if [[ "${GITHUB_ACTIONS:-}" != "true" ]]; then
  exit 0
fi

if [[ -n "${GITHUB_WORKSPACE:-}" ]]; then
  git config --global --add safe.directory "$GITHUB_WORKSPACE"
fi

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  : "${GITHUB_TOKEN:?GITHUB_TOKEN is required without a checkout}"
  : "${GITHUB_REPOSITORY:?GITHUB_REPOSITORY is required without a checkout}"
  git init
  git remote add origin "https://x-access-token:${GITHUB_TOKEN}@github.com/${GITHUB_REPOSITORY}.git"
  git fetch --depth=1 origin main
  git reset --hard FETCH_HEAD
  git branch -M main
fi

git config user.name 'github-actions[bot]'
git config user.email '41898282+github-actions[bot]@users.noreply.github.com'

git add "$record_path"
if git diff --cached --quiet; then
  echo "$already_message"
  exit 0
fi
git commit -m "chore: record ${commit_label} ${key}"

max_attempts=5
for ((attempt = 1; attempt <= max_attempts; attempt++)); do
  if push_output=$(git push origin HEAD:main 2>&1); then
    printf '%s\n' "$push_output"
    exit 0
  fi

  if [[ "$push_output" != *'(fetch first)'* && "$push_output" != *'(non-fast-forward)'* ]]; then
    printf '%s\n' "$push_output" >&2
    exit 1
  fi

  if (( attempt == max_attempts )); then
    printf '%s\n' "$push_output" >&2
    echo "record push failed after ${max_attempts} attempts" >&2
    exit 1
  fi

  echo "Record push raced with another workflow; retrying (${attempt}/${max_attempts})"
  git fetch origin main
  git reset --hard origin/main
  printf '%s\n' "$key" > "$record_path"
  git add "$record_path"
  if git diff --cached --quiet; then
    echo "$already_message"
    exit 0
  fi
  git commit -m "chore: record ${commit_label} ${key}"
done
