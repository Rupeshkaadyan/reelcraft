#!/bin/bash
# Captures review screenshots from a booted simulator.
# usage: tools/capture_screens.sh [device-udid|booted] [output-dir]
set -euo pipefail
cd "$(dirname "$0")/.."

DEVICE="${1:-booted}"
OUT="${2:-Marketing/screens}"
mkdir -p "$OUT"
BUNDLE=com.reelcraft.app

capture() {
  local name="$1"; shift
  xcrun simctl terminate "$DEVICE" "$BUNDLE" >/dev/null 2>&1 || true
  sleep 1
  xcrun simctl launch "$DEVICE" "$BUNDLE" "$@" >/dev/null
  sleep 5
  xcrun simctl io "$DEVICE" screenshot "$OUT/$name.png" >/dev/null 2>&1
  echo "captured $name"
}

capture projects -startTab projects
capture editor -openFirstProject
capture ideas -startTab ideas
capture discover -startTab discover
capture insights -startTab insights
capture record -startTab record
