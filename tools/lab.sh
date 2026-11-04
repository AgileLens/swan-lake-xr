#!/bin/bash
# Regenerate the swan (pass --fast for a quick shape look) and render tools' close-ups.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${LAB_OUT:-$ROOT/out/swanlab}"
GODOT=/opt/homebrew/bin/godot
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python "$ROOT/assets_src/make_swan_hero.py" -- "$@" > "$OUT.blend.log" 2>&1
grep -E "^\[swan\] (low|wing)|Traceback|Error" "$OUT.blend.log"
"$GODOT" --headless --path "$ROOT/project" --import > "$OUT.import.log" 2>&1
timeout 170 "$GODOT" --xr-mode off --path "$ROOT/project" --resolution 800x450 -- --swanlab --out="$OUT" > "$OUT.run.log" 2>&1
grep -E "SCRIPT ERROR|Parse Error|LAB_DONE" "$OUT.run.log" | head
