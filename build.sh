#!/bin/bash
# Build the Pico Swan Lake APK: debug-signed, PICO loader, Godot 4.7.2. Usage: ./build.sh
set -euo pipefail
PRESET="${1:-pico}"
GODOT=/opt/homebrew/bin/godot
ROOT="$(cd "$(dirname "$0")" && pwd)"
TPL="$HOME/Library/Application Support/Godot/export_templates/4.7.2.stable"

# Gradle build template lives outside git (112MB godot-lib AARs) — reinstall if missing.
if [ ! -f "$ROOT/project/android/build/build.gradle" ]; then
  echo "[build.sh] installing android build template from $TPL"
  mkdir -p "$ROOT/project/android/build"
  (cd "$ROOT/project/android/build" && unzip -q -o "$TPL/android_source.zip")
  touch "$ROOT/project/android/.gdignore"
  # content must be plain "4.7.2.stable": with ".official" appended Godot refuses to build
  printf '4.7.2.stable\n' > "$ROOT/project/android/.build_version"
  printf '4.7.2.stable\n' > "$ROOT/project/android/build/.build_version"
  # local gradle dist (JVM downloads flake on this network) + force IPv4 (JVM prefers broken IPv6)
  sed -i '' 's#^distributionUrl=.*#distributionUrl=file\\:///Users/alex/dev/tools/gradle-8.11.1-bin.zip#' \
    "$ROOT/project/android/build/gradle/wrapper/gradle-wrapper.properties"
  printf '\nsystemProp.java.net.preferIPv4Stack=true\norg.gradle.jvmargs=-Xmx4g -Djava.net.preferIPv4Stack=true\n' \
    >> "$ROOT/project/android/build/gradle.properties"
fi

mkdir -p "$ROOT/out"

# The machine-wide editor settings point at a JDK path that no longer exists, and shared config isn't
# ours to change. Export under a private HOME with a corrected copy, keeping the real Gradle cache.
REAL_HOME="$HOME"
GODOT_HOME="$ROOT/out/.godot-home"
GODOT_CFG="$GODOT_HOME/Library/Application Support/Godot"
mkdir -p "$GODOT_CFG"
JDK="${JDK:-/Applications/Android Studio.app/Contents/jbr/Contents/Home}"
[ -x "$JDK/bin/java" ] || { echo "No JDK at $JDK. Set JDK=<path to a JDK 17+ home>." >&2; exit 1; }
sed -E "s#^export/android/java_sdk_path = .*#export/android/java_sdk_path = \"$JDK\"#" \
  "$REAL_HOME/Library/Application Support/Godot/editor_settings-4.7.tres" > "$GODOT_CFG/editor_settings-4.7.tres"
ln -sfn "$REAL_HOME/Library/Application Support/Godot/export_templates" "$GODOT_CFG/export_templates"
export GRADLE_USER_HOME="${GRADLE_USER_HOME:-$REAL_HOME/.gradle}"
find "$ROOT/project/android" -name .DS_Store -delete 2>/dev/null || true

# Assets here are generated. A fresh .wav or .glb has no .import sibling, and the export happily
# ships it. Then load() fails at runtime with "No loader found for resource". Import first.
HOME="$GODOT_HOME" "$GODOT" --headless --xr-mode off --path "$ROOT/project" --import >/dev/null 2>&1 || true

HOME="$GODOT_HOME" JAVA_HOME="$JDK" GRADLE_OPTS="-Djava.net.preferIPv4Stack=true" "$GODOT" --headless --xr-mode off \
  --path "$ROOT/project" --export-debug "$PRESET" "$ROOT/out/picoswanlake.apk"
ls -la "$ROOT/out/picoswanlake.apk"
