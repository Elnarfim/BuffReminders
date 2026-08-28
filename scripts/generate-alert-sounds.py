#!/usr/bin/env python3
"""Regenerate Data/AlertSounds.lua from the client's own alert sound library.

The client exposes its alert sounds as sound KITS. C_UnitAuras.AddAuraSound takes
a FILE, and no API converts one into the other, so the file column must be baked.

Two public sources are read:
  * Blizzard's CooldownViewerSoundAlertData.lua - the category, the enum key, the
    sound kit id, and the global string that names each sound.
  * wago.tools SoundKitEntry - the file behind each kit.

Run it after a patch adds sounds:

    scripts/generate-alert-sounds.py

The script verifies that every global string name follows the pattern the addon
derives at run time. If one does not, it fails instead of writing a file that
would show a raw key to the player.
"""

import re
import sys
import time
import urllib.request
from pathlib import Path

BLIZZARD_DATA = (
    "https://raw.githubusercontent.com/Gethe/wow-ui-source/live/Interface/AddOns/"
    "Blizzard_CooldownViewer/CooldownViewerSoundAlertData.lua"
)
WAGO_ENTRY = "https://wago.tools/db2/SoundKitEntry/csv?filter%5BSoundKitID%5D={kit}"
OUTPUT = Path(__file__).resolve().parent.parent / "Data" / "AlertSounds.lua"

HEADER = """local _, BR = ...

-- ============================================================================
-- ALERT SOUNDS (GENERATED)
-- ============================================================================
-- The sound library of the client's own alert menu. Regenerate with
-- scripts/generate-alert-sounds.py; do not edit by hand.
--
-- The client offers these as sound kits, and C_UnitAuras.AddAuraSound takes a
-- file, with nothing in between: a kit id registers and then plays silence. So
-- the file id is baked and a kit id is never stored.
--
-- Names are not baked. Core/Sounds.lua derives each global string from the key,
-- so the picker reads in the game language and a sound the client dropped
-- disappears from the list on its own.

BR.ALERT_SOUNDS = {
"""

FOOTER = """}
"""


# wago.tools rejects the default urllib agent, and a named one is easier for them
# to trace than a spoofed browser string.
USER_AGENT = "BuffReminders-alert-sound-generator/1.0"


def fetch(url: str, attempts: int = 3) -> str:
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    for attempt in range(attempts):
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                return response.read().decode("utf-8")
        except Exception as error:  # noqa: BLE001 - a retry loop wants every failure
            if attempt == attempts - 1:
                raise SystemExit(f"failed to fetch {url}: {error}")
            time.sleep(2)
    return ""


def derive_global(key: str) -> str:
    """Mirror the run-time derivation in Core/Sounds.lua."""
    spaced = re.sub(r"(\d)", r"\1_", key)
    spaced = re.sub(r"([a-z])([A-Z])", r"\1_\2", spaced)
    return "CDMSND_" + spaced.upper()


def parse_library(source: str):
    """Yield (category, [(key, kit)]) in the order Blizzard lists them."""
    groups = []
    current = None
    for line in source.splitlines():
        category = re.search(r"Enum\.CooldownViewerSoundCategory\.(\w+)", line)
        if category:
            current = (category.group(1), [])
            groups.append(current)
            continue
        row = re.search(
            r"soundEnum = Enum\.CooldownViewerSound\.(\w+), soundKitID = (\d+), text = (\w+)",
            line,
        )
        if row and current:
            key, kit, global_string = row.group(1), int(row.group(2)), row.group(3)
            if derive_global(key) != global_string:
                raise SystemExit(
                    f"{key}: the client names it {global_string}, the addon would derive "
                    f"{derive_global(key)}. Bake the names instead of deriving them."
                )
            current[1].append((key, kit))
    return [group for group in groups if group[1]]


def resolve_files(kit: int):
    # One request per kit, paced so a full run stays a polite neighbour.
    time.sleep(0.2)
    csv = fetch(WAGO_ENTRY.format(kit=kit))
    files = []
    for line in csv.strip().splitlines()[1:]:
        columns = line.split(",")
        if len(columns) > 2 and columns[1] == str(kit):
            files.append(int(columns[2]))
    return files


def main() -> int:
    groups = parse_library(fetch(BLIZZARD_DATA))
    total = sum(len(sounds) for _, sounds in groups)
    print(f"{total} sounds in {len(groups)} categories")

    lines = []
    resolved = 0
    for category, sounds in groups:
        lines.append(f'    {{ category = "{category}", sounds = {{')
        for key, kit in sounds:
            files = resolve_files(kit)
            if len(files) != 1:
                print(f"  SKIP {key}: kit {kit} maps to {files}", file=sys.stderr)
                continue
            resolved += 1
            lines.append(f'        {{ key = "{key}", file = {files[0]} }},')
        lines.append("    } },")

    OUTPUT.write_text(HEADER + "\n".join(lines) + "\n" + FOOTER, encoding="utf-8")
    print(f"wrote {OUTPUT} with {resolved}/{total} sounds")
    return 0 if resolved == total else 1


if __name__ == "__main__":
    raise SystemExit(main())
