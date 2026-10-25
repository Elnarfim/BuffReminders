#!/usr/bin/env bash
#
# Fetches the pinned WoW API annotations (Ketho/vscode-wow-api) into
# .ignored/wow-api/ for `make api-audit` (config: scripts/luarc-api.json).
# Only Annotations/Core: FrameXML costs a large checkout and a slow typecheck.
# To upgrade, change VERSION and run `make api-audit`.

set -euo pipefail

cd "$(dirname "$0")/.."

VERSION="0.22.3"
DEST=".ignored/wow-api"
STAMP="$DEST/.version"

if [ -f "$STAMP" ] && [ "$(cat "$STAMP")" = "$VERSION" ]; then
  exit 0
fi

rm -rf "$DEST"
mkdir -p "$DEST"
curl -sSfL "https://codeload.github.com/Ketho/vscode-wow-api/tar.gz/refs/tags/$VERSION" \
  | tar xz -C "$DEST" --strip-components=1 "vscode-wow-api-$VERSION/Annotations/Core"
echo "$VERSION" > "$STAMP"
