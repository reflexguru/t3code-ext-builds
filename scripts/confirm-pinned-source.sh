#!/usr/bin/env bash
# Confirm $T3CODE_SRC is the v2 orchestrator commit the flavor claims to build.
set -euo pipefail

src="${T3CODE_SRC:?T3CODE_SRC is required}"
sha="${SHA:?SHA is required}"

cd "$src"
checked_out="$(git rev-parse HEAD)"
echo "Pinned commit: ${checked_out}"
if [[ "$checked_out" != "$sha" ]]; then
  echo "::error::Checked out ${checked_out}, expected ${sha}." >&2
  exit 1
fi
if [[ ! -f apps/server/src/orchestration-v2/ProviderAdapter.ts ]]; then
  echo "::error::${sha} is not the v2 orchestrator stack: orchestration-v2/ProviderAdapter.ts is missing." >&2
  exit 1
fi
echo "Source pull requests: ${PR_SPEC:-}"
