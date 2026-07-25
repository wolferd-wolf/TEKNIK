#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 3 ]]; then
  echo "usage: run_godot_strict.sh <godot-binary> <log-path> <godot-args...>" >&2
  exit 2
fi

godot_binary="$1"
log_path="$2"
shift 2

mkdir -p "$(dirname "$log_path")"
set +e
"$godot_binary" "$@" 2>&1 | tee "$log_path"
godot_status=${PIPESTATUS[0]}
set -e

if [[ $godot_status -ne 0 ]]; then
  echo "Godot exited with status $godot_status" >&2
  exit "$godot_status"
fi

if grep -E -n 'SCRIPT ERROR:|^ERROR:|Parse Error:|Compile Error:|[A-Z_]+_SMOKE_FAILED' "$log_path"; then
  echo "Godot reported an error while returning exit status 0" >&2
  exit 1
fi
