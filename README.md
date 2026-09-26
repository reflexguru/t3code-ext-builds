# T3 Code Windows nightlies

Unofficial Windows x64 builds of the [T3 Code](https://github.com/pingdotgg/t3code)
desktop nightly, with Command Code and Oh My Pi (omp) layered on top.

This repository follows the same packaging model as
[slopfire/t3code-copr](https://github.com/slopfire/t3code-copr) (upstream nightly
+ pull requests + local patches), but produces an **NSIS installer** and a
portable **zip** instead of an AppImage wrapped as an RPM.

These are unofficial packages. T3 Code is distributed under the MIT license.
The installers are not Authenticode-signed unless Azure Trusted Signing is
configured later.

- **`prs`** is the upstream nightly with two pull requests layered on top:
  [pingdotgg/t3code#10861](https://github.com/pingdotgg/t3code/pull/10861) (the
  Command Code provider driver) and
  [pingdotgg/t3code#11973](https://github.com/pingdotgg/t3code/pull/11973) (the
  Oh My Pi driver), plus the local patches in `patches/prs/`.
- **`v2`** builds
  [pingdotgg/t3code#2829](https://github.com/pingdotgg/t3code/pull/2829) (the new
  orchestrator) and nothing else. That stack carries the **Pi** coding agent
  driver and the generic ACP provider registry. It is experimental: it ships an
  orchestrator upstream has not merged.
- **`v2-prs`** is that same v2 build plus the ported providers: **Command Code**
  as a full provider (driver, v2 adapter, NDJSON protocol, model catalog,
  snapshot, text generation, contracts schema, settings-UI definition) and
  **Oh My Pi** as a bundled ACP Registry entry. Neither can come from #10861 or
  #11973: those implement main's `adapter` field, while the v2 orchestrator
  requires `orchestrationAdapter`, so they live in `patches/v2-prs/`, written
  against the v2 interfaces.

Upstream publishes no Windows installer containing an open pull request, so the
layered flavors are compiled from source. Local fixes from `patches/<flavor>/`
are applied after the pull requests, and pull requests that do not merge onto
the nightly tag need the resolved files in `resolutions/`; see
[Local patches](#local-patches) and
[Conflict resolutions](#conflict-resolutions).

The two v2 flavors do not merge anything onto a nightly tag: they build the
orchestrator branch head itself, which is the revision its author tests, because
that branch trails main and stops merging as soon as main moves past its base.
Their version stamp and build key come from that pinned commit.

The plain upstream nightly is not mirrored here. Official
`T3-Code-*-x64.exe` installers already ship on
[pingdotgg/t3code releases](https://github.com/pingdotgg/t3code/releases). This
repository exists for the layered flavors upstream does not publish.

The flavors install the same application. Do not run two of them side by side:
uninstall the previous flavor, then install the other `.exe`.

## Local patches

`patches/<flavor>/*.patch` are applied after the pull requests and before the
installer is built, and the build key includes a digest of them, so editing a
patch triggers a rebuild. Each patch must apply cleanly to the layered tree; if
upstream changes the file it touches, the build fails instead of quietly
shipping something else.

The v2-prs flavor carries its own patches because the v2 interfaces are not
main's: main's drivers expose `adapter`, the v2 orchestrator requires
`orchestrationAdapter`, so the Command Code and Oh My Pi integrations cannot be
taken from #10861 / #11973 and are written against the v2 branch instead. They
are local patches, not pull requests, because they target an unmerged branch and
would have to be rewritten as it moves. `v2` is the same build with no patches
at all, so the two v2 flavours are the same branch with and without ports.

| Patch | Why |
| --- | --- |
| `patches/prs/0001-command-code-steer-on-mid-turn-send.patch` | PR #10861 rejects any `sendTurn` that arrives while a turn is running (`a turn is already running for this thread`), so a message typed mid-turn is dropped; it also reports a signal-killed child (Stop) as a provider process failure. The patch steers the message into the running turn, keeps Stop a clean abort, and names any mid-turn messages a turn ends up never delivering. |
| `patches/prs/0002-command-code-tool-work-log-payloads.patch` | PR #10861 omits `title`, `detail`, and `data.toolCallId` on completed/failed/declined tool events, so the work log falls back to a generic **Tool** row with no path or command. The patch keeps the queued args, humanizes the title, and puts structured `data` on every lifecycle event. |
| `patches/prs/0003-command-code-model-effort.patch` | PR #10861 advertises Command Code models with empty capabilities, so the composer has no Reasoning control. The patch adds the CLI `--effort` levels (`low`–`max`) to every model and forwards the selected value on each turn. |
| `patches/v2-prs/0001-acp-bundled-oh-my-pi-entry.patch` | Oh My Pi is ACP-native but its official ACP Registry entry is still pending, so the Registry flow cannot offer it. The patch ships the entry with the app (`bundledAcpAgents.ts`) and merges bundled entries behind fetched ones, so the official listing takes over automatically once it is published. |
| `patches/v2-prs/0002-command-code-provider.patch` | The Command Code provider, ported to the v2 interfaces: driver, `CommandCodeAdapterV2`, NDJSON protocol, model catalog, snapshot, text generation, contracts schema, and the settings-UI definition. Mid-turn sends are steered into the running turn by the v2 orchestrator (`supportsActiveSteering`), with the queueing implemented in the adapter because the CLI takes one prompt per process. |

A patch is not upstreamed here: once the pull request (or an equivalent change)
carries the fix, or the v2 branch merges into main, delete the patch file and its
row.

## Conflict resolutions

A layered pull request usually merges onto the nightly tag by itself. When one
does not, `git merge` stops, and the build ships it only if the conflicting
files have a recorded resolution:

- `resolutions/<number>/conflicts.tsv` lists, for every conflicted
  file, `sha256(HEAD) sha256(PR) path`.
- `resolutions/<number>/<path>` holds the resolved content of that file, which
  must carry both sides' intent and no conflict markers.

The build compares both recorded hashes against the revisions it is merging.
A mismatch means the nightly tag or the pull request moved inside a file the
resolution covers, so the resolution can no longer be trusted; the build stops
with an error instead of shipping a merge nobody reviewed. A merge that fails
before it produces conflicts (a missing object, a refused ref) stops the same
way, because there is nothing to resolve.

To refresh one, in a scratch clone of upstream at the nightly tag: fetch the pull
request refs, merge them in the order the build uses, resolve the markers in
the conflicted files, then record both sides' hashes and the resolved files here.

| Resolution | Why |
| --- | --- |
| `resolutions/11973/apps/desktop/scripts/ensure-electron-runtime.mjs` | PR #11973 adds the Windows extraction branch next to the line the nightly changed. The resolution keeps the nightly's `distDir` variable and the pull request's branch. |
| `resolutions/11973/apps/server/src/provider/acp/AcpSessionRuntime.ts` | After Command Code (#10861) is layered, nightly and #11973 both touch the ACP session runtime (omp `/fresh` session switching vs the current prompt/cancel path). The recorded file is the merge from [t3code-copr](https://github.com/slopfire/t3code-copr), keeping both sides. |

A flavor reads only the resolutions of the pull requests it layers, so neither
v2 flavor needs any: they build the orchestrator branch head directly instead of
merging pull requests onto a tag, which cannot conflict.

The resolutions are not upstreamed: once a pull request merges on its own, its
resolution is never read and can be deleted with its directory.

## Local build

On Windows x64, install:

- [Git for Windows](https://git-scm.com/download/win) (Git Bash)
- [GitHub CLI](https://cli.github.com/) (`gh auth login`)
- [Vite+](https://vite.plus): `irm https://vite.plus/ps1 | iex`
- [Rust stable](https://rustup.rs/)
- Visual Studio 2022 Build Tools with the **Desktop development with C++**
  workload

Then:

```powershell
.\scripts\build-windows.ps1 prs
.\scripts\build-windows.ps1 v2-prs
.\scripts\build-windows.ps1 v2
```

The same entry point from Git Bash:

```sh
./scripts/build-windows.sh prs
./scripts/build-windows.sh v2-prs --force
./scripts/build-windows.sh prs --skip-package
```

`--skip-package` layers the pull requests and patches into `.work/t3code/` and
stops before NSIS. `--force` rebuilds even when `packaging/<flavor>/last-built-key`
already matches.

The installer is written to `release/<flavor>/<version>/`:

- `T3-Code-<version>-x64.exe` — NSIS installer
- `T3-Code-<version>-x64.zip` — portable build
- `upstream-prs.txt` — every pull request, local patch, and conflict carry
- `SHA256SUMS`

The upstream checkout lives in `.work/t3code/` (gitignored). Later builds reuse
`node_modules` there.

## GitHub Actions

Three workflows publish here, staggered so they do not build at the same minute:

- `Build T3 Code v2 orchestrator nightly (Windows)` (`:23`) compiles the
  orchestrator branch head and archives the installer on the `v2-nightly`
  prerelease. It records the combination in `packaging/v2/last-built-key`.
- `Build T3 Code v2 orchestrator nightly with Command Code and Oh My Pi (Windows)`
  (`:33`) builds that same commit with `patches/v2-prs/` applied and archives
  it on `v2-prs-nightly`, recording `packaging/v2-prs/last-built-key`.
- `Build T3 Code + pull requests nightly (Windows)` (`:47`) compiles the nightly
  with #10861 and #11973, archives the installer on the `prs-nightly`
  prerelease, and records the combination in `packaging/prs/last-built-key`.

A layered flavor rebuilds only when its inputs changed, so a nightly tag that a
layered flavor has already packaged is skipped.

Use **Run workflow** with `force` when a rebuild of the same inputs is needed.
Each layered workflow also takes a `pr_refs` input listing the pull request refs
to merge, in order; changing that set is the supported way to package a
different pull request. The CI workflow validates the packaging tree and the
recorded resolutions on pushes and pull requests but never publishes installers.

Only upstream `-nightly.` prereleases are packaged. Upstream also publishes
`-preview.` releases, but those are maintainer test builds (marked "do not
install"), so they are intentionally ignored. Tag selection lives in
`scripts/resolve-latest-nightly.sh`.

There is no COPR project here: the artifact is the `.exe` / `.zip` on a rolling
GitHub prerelease.

## WSL

Official Windows releases embed a Linux CLI archive so the desktop app can drive
a WSL backend. These unofficial builds skip that step (there is no companion
Linux job). The native Windows agent still runs; the WSL backend is not bundled.

## Notes

The `prs` flavor is the daily Command Code + Oh My Pi build. Keep `v2` and
`v2-prs` apart from that install until you have exercised the unmerged
orchestrator.
