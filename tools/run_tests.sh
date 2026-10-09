#!/usr/bin/env bash
# Runs the test suite and fails on any test failure *or* any script error
# printed by the engine (GDScript runtime errors do not stop a test by themselves).
# Usage: tools/run_tests.sh [path/to/godot]
set -u
GODOT="${1:-${GODOT:-godot}}"
cd "$(dirname "$0")/.."
log="$(mktemp)"
"$GODOT" --headless --path . -s res://tests/run_tests.gd >"$log" 2>&1
code=$?
grep -E "^\s+(ok|FAIL)|passed|^\s+- " "$log"
if grep -q "SCRIPT ERROR" "$log"; then
	echo
	echo "Script errors detected:"
	grep -A1 "SCRIPT ERROR" "$log"
	code=1
fi
rm -f "$log"
exit $code
