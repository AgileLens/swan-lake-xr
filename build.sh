#!/bin/bash
# Build a Swan Lake APK. Usage: ./build.sh [pico|quest]   (default: pico)
set -euo pipefail
PRESET="${1:-pico}"
GODOT=/Users/alex/dev/tools/godot471/Godot.app/Contents/MacOS/Godot
ROOT="$(cd "$(dirname "$0")" && pwd)"
TPL="$HOME/Library/Application Support/Godot/export_templates/4.7.1.stable"

# Gradle build template lives outside git (112MB godot-lib AARs) — reinstall if missing.
if [ ! -f "$ROOT/project/android/build/build.gradle" ]; then
  echo "[build.sh] installing android build template from $TPL"
  mkdir -p "$ROOT/project/android/build"
  (cd "$ROOT/project/android/build" && unzip -q -o "$TPL/android_source.zip")
  touch "$ROOT/project/android/.gdignore"
  # content must be plain "4.7.1.stable" — with ".official" appended Godot refuses to build
  printf '4.7.1.stable\n' > "$ROOT/project/android/.build_version"
  printf '4.7.1.stable\n' > "$ROOT/project/android/build/.build_version"
  # local gradle dist (JVM downloads flake on this network) + force IPv4 (JVM prefers broken IPv6)
  sed -i '' 's#^distributionUrl=.*#distributionUrl=file\\:///Users/alex/dev/tools/gradle-8.11.1-bin.zip#' \
    "$ROOT/project/android/build/gradle/wrapper/gradle-wrapper.properties"
  printf '\nsystemProp.java.net.preferIPv4Stack=true\norg.gradle.jvmargs=-Xmx4g -Djava.net.preferIPv4Stack=true\n' \
    >> "$ROOT/project/android/build/gradle.properties"
fi

mkdir -p "$ROOT/out"

# Assets here are code-generated (assets_src/*.py, Blender scripts). A fresh .wav/.glb
# has no .import sibling, and the export happily ships it — then load() fails at
# runtime with "No loader found for resource (expected type: unknown)". Import first.
"$GODOT" --headless --path "$ROOT/project" --import >/dev/null 2>&1 || true

GRADLE_OPTS="-Djava.net.preferIPv4Stack=true" "$GODOT" --headless --path "$ROOT/project" \
  --export-debug "$PRESET" "../out/SwanLake_${PRESET}.apk"
ls -la "$ROOT/out/SwanLake_${PRESET}.apk"
