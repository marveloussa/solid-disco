#!/bin/bash
# Usage: run_one.sh r01_guards [timeout_seconds]
# Runs one runner scene headless on a fixed 60 fps step with an isolated save file and
# fails on a non-zero exit, a missing RESULT line, or SCRIPT ERROR / ERROR: / Parse Error output.
name="$1"
limit="${2:-300}"
dir="$(cd "$(dirname "$0")/../.." && pwd)"
log="/tmp/rules_${name}.log"
XDG_DATA_HOME=/tmp/xdg_rules timeout "$limit" godot --headless --path "$dir" --fixed-fps 60 "res://tests/combat_rules/${name}.tscn" > "$log" 2>&1
code=$?
grep -E "^(PASS|FAIL|RESULT)" "$log" | grep -v "^PASS" 
errors=$(grep -E "SCRIPT ERROR|ERROR:|Parse Error" "$log" | head -5)
if [ -n "$errors" ]; then
  echo "FAIL log-clean $name: engine errors in output:"
  echo "$errors"
  code=3
fi
if ! grep -q "^RESULT " "$log"; then
  echo "FAIL $name: no RESULT line (exit code $code)"
  code=4
fi
exit $code
