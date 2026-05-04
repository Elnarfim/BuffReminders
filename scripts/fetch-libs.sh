#!/usr/bin/env bash
#
# Fetches the latest upstream of each vendored library into /tmp/<lib-name>/.
# Used by .github/workflows/check-libs.yml; runs locally too (needs `svn`
# and `git` on PATH).
#
# Adding a new lib:
#   1. Append a `fetch_svn` or `fetch_git_files` call below.
#   2. Create the matching Libs/<lib-name>/ folder.
# The verification at the end fails if either side is missing.

set -euo pipefail

cd "$(dirname "$0")/.."

err() { printf '::error::%s\n' "$*" >&2; }

fetch_svn() {
  # fetch_svn <lib-name> <svn-url>
  local name="$1" url="$2"
  svn export --force "$url" "/tmp/$name" >/dev/null
}

fetch_git_files() {
  # fetch_git_files <lib-name> <git-url> <src:dst> [<src:dst> ...]
  local name="$1" repo="$2"; shift 2
  local repo_dir="/tmp/$name-repo"
  rm -rf "$repo_dir"
  git clone --depth 1 --quiet "$repo" "$repo_dir"
  mkdir -p "/tmp/$name"
  for mapping in "$@"; do
    cp "$repo_dir/${mapping%%:*}" "/tmp/$name/${mapping#*:}"
  done
}

echo "==> Fetching CurseForge (SVN) libs"
fetch_svn LibStub             https://repos.curseforge.com/wow/libstub/trunk
fetch_svn CallbackHandler-1.0 https://repos.curseforge.com/wow/callbackhandler/trunk/CallbackHandler-1.0
fetch_svn LibSharedMedia-3.0  https://repos.curseforge.com/wow/libsharedmedia-3-0/trunk/LibSharedMedia-3.0
fetch_svn AceDB-3.0           https://repos.curseforge.com/wow/ace3/trunk/AceDB-3.0
fetch_svn LibDBIcon-1.0       https://repos.curseforge.com/wow/libdbicon-1-0/trunk/LibDBIcon-1.0

# The Ace3 BSD-style LICENSE covers AceDB-3.0, CallbackHandler-1.0, and
# LibDBIcon-1.0 (same Ace3 Development Team).
echo "==> Distributing shared Ace3 LICENSE"
svn export --force https://repos.curseforge.com/wow/ace3/trunk/LICENSE.txt /tmp/ace3-LICENSE.txt >/dev/null
for lib in AceDB-3.0 CallbackHandler-1.0 LibDBIcon-1.0; do
  cp /tmp/ace3-LICENSE.txt "/tmp/$lib/LICENSE.txt"
done

echo "==> Fetching GitHub libs"
fetch_git_files LibCustomGlow-1.0 https://github.com/Stanzilla/LibCustomGlow.git \
  LibCustomGlow-1.0.lua:LibCustomGlow-1.0.lua \
  LICENSE:LICENSE.txt

fetch_git_files LibDataBroker-1.1 https://github.com/tekkub/libdatabroker-1-1.git \
  LibDataBroker-1.1.lua:LibDataBroker-1.1.lua

fetch_git_files LibDualSpec-1.0 https://github.com/Adirelle/LibDualSpec-1.0.git \
  LibDualSpec-1.0.lua:LibDualSpec-1.0.lua
# Strip @do-not-package@ blocks (test code not meant for distribution).
sed -i '/@do-not-package@/,/@end-do-not-package@/d' /tmp/LibDualSpec-1.0/LibDualSpec-1.0.lua

fetch_git_files LibSpecialization https://github.com/BigWigsMods/LibSpecialization.git \
  LibSpecialization/LibSpecialization.lua:LibSpecialization.lua

fetch_git_files LibDeflate https://github.com/SafeteeWoW/LibDeflate.git \
  LibDeflate.lua:LibDeflate.lua \
  LICENSE.txt:LICENSE.txt

echo "==> Verifying every vendored lib has a fetch entry"
failed=0
for d in Libs/*/; do
  lib=$(basename "$d")
  if [ ! -d "/tmp/$lib" ]; then
    err "Libs/$lib has no fetch entry in $(basename "$0")"
    failed=1
  fi
done
[ "$failed" -eq 0 ]
