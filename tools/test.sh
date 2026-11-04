#!/bin/bash
# Logic checks, then the scripted program three ways on a virtual clock. Headless, no audio.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT=/opt/homebrew/bin/godot
mkdir -p "$ROOT/out"
rm -f "$ROOT"/out/autotest_*.json
rc=0
"$GODOT" --headless --path "$ROOT/project" --import >/dev/null 2>&1
# A parse error in a --script file makes Godot exit 0 with no summary, so each run must print its own
# PASS verdict or it counts as a failure.
out="$("$GODOT" --headless --path "$ROOT/project" --script res://tests/logic_tests.gd 2>&1)"; code=$?
echo "$out" | grep -E "^(PASS|FAIL|LOGIC_RESULT|     )|SCRIPT ERROR|Parse Error"
[ $code -eq 0 ] || rc=1
echo "$out" | grep -qE "^LOGIC_RESULT passed=[1-9][0-9]* failed=0$" || { echo "NO PASS SUMMARY: the logic tests never reported LOGIC_RESULT with 0 failed (parse error or crash), counting as a failure"; rc=1; }
for mode in off wild conduct; do
  "$GODOT" --headless --xr-mode off --fixed-fps 30 --path "$ROOT/project" -- --autotest=$mode > "$ROOT/out/autotest_$mode.log" 2>&1
  code=$?
  grep -E "^(PASS|FAIL|AUTOTEST)|\[program\] (curtain)|SCRIPT ERROR" "$ROOT/out/autotest_$mode.log"
  [ $code -eq 0 ] || rc=1
  grep -qE "^AUTOTEST PASS$" "$ROOT/out/autotest_$mode.log" || { echo "NO PASS SUMMARY: the $mode autotest never reported AUTOTEST PASS, counting as a failure"; rc=1; }
done
echo "TEST_SH rc=$rc"
exit $rc
