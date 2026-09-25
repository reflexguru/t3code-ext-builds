#!/usr/bin/env bash
# Copy the Windows NSIS installer and portable zip out of the upstream
# electron-builder output directory.
#
#   collect-windows-artifacts.sh SOURCE_RELEASE_DIR DEST_DIR
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $0 SOURCE_RELEASE_DIR DEST_DIR" >&2
  exit 2
fi

src="$1"
dest="$2"
version="${VERSION:-}"

if [[ ! -d "$src" ]]; then
  echo "No electron-builder release directory at ${src}" >&2
  exit 1
fi

mkdir -p "$dest"
shopt -s nullglob

copied=0
copy_matching() {
  local file
  for file in "$@"; do
    [[ -f "$file" ]] || continue
    cp -f "$file" "$dest/"
    echo "Collected $(basename "$file")"
    copied=$((copied + 1))
  done
}

copy_matching \
  "${src}"/T3-Code-*-x64.exe \
  "${src}"/T3-Code-*-x64.exe.blockmap \
  "${src}"/T3-Code-*-x64.zip \
  "${src}"/T3-Code-*-x64.zip.blockmap \
  "${src}"/latest.yml

if [[ "$copied" -eq 0 ]]; then
  copy_matching "${src}"/*.exe "${src}"/*.zip "${src}"/*.blockmap "${src}"/*.yml
fi

exe_count=0
for file in "${dest}"/*.exe; do
  [[ -f "$file" ]] || continue
  exe_count=$((exe_count + 1))
done
if [[ "$exe_count" -eq 0 ]]; then
  echo "No Windows installer (.exe) was produced in ${src}." >&2
  ls -la "$src" >&2 || true
  exit 1
fi

(
  cd "$dest"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum -- * > SHA256SUMS
  else
    # Git Bash fallback
    for file in *; do
      [[ -f "$file" && "$file" != SHA256SUMS ]] || continue
      sha256sum "$file"
    done > SHA256SUMS
  fi
)

echo "Windows artifacts for ${version:-unknown version}:"
ls -la "$dest"
