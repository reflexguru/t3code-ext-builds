#!/usr/bin/env bash
# Focused adapter tests for the parts of the tree this packaging repo patches.
# TEST_KIND:
#   command-code              main-line Command Code adapter (PR #10861)
#   v2-command-code           ported v2 adapter; missing tests are an error
#   v2-command-code-optional  same tests, skipped when the flavor has no ports
#   none                      no-op
set -euo pipefail

src="${T3CODE_SRC:?T3CODE_SRC is required}"
kind="${TEST_KIND:-none}"
pr_refs="${PR_REFS:-}"

if [[ "$kind" == "none" ]]; then
  echo "No adapter tests for this flavor."
  exit 0
fi

cd "${src}/apps/server"

run_vp() {
  if [[ -f ../node_modules/.bin/vp.cmd ]]; then
    MSYS_NO_PATHCONV=1 cmd.exe /c "$(cygpath -w "../node_modules/.bin/vp.cmd")" "$@"
    return
  fi
  if [[ -x ../node_modules/.bin/vp ]]; then
    ../node_modules/.bin/vp "$@"
    return
  fi
  vp "$@"
}

case "$kind" in
  command-code)
    if [[ " ${pr_refs} " != *" refs/pull/10861/head "* ]]; then
      echo "Pull request 10861 is not layered; skipping the Command Code adapter test."
      exit 0
    fi
    run_vp test run \
      src/provider/Layers/CommandCodeAdapter.test.ts \
      src/provider/commandCodeModels.test.ts \
      src/provider/commandCodeLaunchArgs.test.ts
    ;;
  v2-command-code|v2-command-code-optional)
    tests=(
      src/orchestration-v2/Adapters/CommandCodeAdapterV2.test.ts
      src/provider/commandCodeNdjson.test.ts
      src/provider/commandCodeModels.test.ts
    )
    if [[ ! -f "${tests[0]}" ]]; then
      if [[ "$kind" == "v2-command-code-optional" ]]; then
        echo "This flavor carries no ported provider patches; skipping."
        exit 0
      fi
      echo "::error::${tests[0]} is missing: the ported Command Code patch did not apply." >&2
      exit 1
    fi
    for test in "${tests[@]}"; do
      if [[ ! -f "$test" ]]; then
        echo "::error::${test} is missing while other ported tests are present." >&2
        exit 1
      fi
    done
    run_vp test run "${tests[@]}"
    ;;
  *)
    echo "unsupported TEST_KIND: ${kind}" >&2
    exit 2
    ;;
esac
