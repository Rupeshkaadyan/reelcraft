#!/bin/bash
# One-command preflight for App Store submission.
#
#   bash tools/preflight.sh
#
# Stages:
#   1. Doc links and the App Store listing (fast, no Xcode needed)
#   2. Xcode project generation (skipped when XcodeGen is not installed)
#   3. The render pipeline tests
#   4. A Release archive: signed and exported when DEVELOPMENT_TEAM is set,
#      otherwise an unsigned device archive that proves the Release build compiles
#
# Overrides:
#   SIMULATOR="iPhone 16 Pro"  bash tools/preflight.sh
#   SKIP_TESTS=1               bash tools/preflight.sh
#   SKIP_ARCHIVE=1             bash tools/preflight.sh

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SIMULATOR="${SIMULATOR:-iPhone 17 Pro}"
SKIP_TESTS="${SKIP_TESTS:-0}"
SKIP_ARCHIVE="${SKIP_ARCHIVE:-0}"
ARCHIVE_PATH="${ARCHIVE_PATH:-build/Reelcraft.xcarchive}"
EXPORT_PATH="${EXPORT_PATH:-build/ipa}"
PROJECT="Reelcraft.xcodeproj"
SCHEME="Reelcraft"

mkdir -p build

failures=0
step() { printf "\n== %s\n" "$1"; }
pass() { printf "   PASS  %s\n" "$1"; }
fail() { printf "   FAIL  %s\n" "$1"; failures=$((failures + 1)); }
skip() { printf "   SKIP  %s\n" "$1"; }

step "1/4 Doc links and listing"
if python3 tools/check_readme_links.py README.md PRIVACY.md SUBMISSION.md; then
  pass "every local image and link resolves"
else
  fail "broken local image or link"
fi

if python3 tools/check_listing.py replica/launch/listing.json; then
  pass "listing is within App Store limits"
else
  fail "listing has errors"
fi

if [ "$failures" -gt 0 ]; then
  printf "\nPreflight stopped: fix the failures above, then run again.\n"
  exit 1
fi

step "2/4 Xcode project"
if command -v xcodegen >/dev/null 2>&1; then
  if xcodegen generate >build/preflight-xcodegen.log 2>&1; then
    pass "xcodegen generated $PROJECT"
  else
    fail "xcodegen failed (build/preflight-xcodegen.log)"
  fi
else
  skip "xcodegen not installed, using the committed project"
fi

if ! command -v xcodebuild >/dev/null 2>&1; then
  fail "xcodebuild not found: install Xcode before shipping"
  printf "\nPreflight finished with %d failure(s).\n" "$failures"
  exit 1
fi

step "3/4 Render pipeline tests"
if [ "$SKIP_TESTS" = "1" ]; then
  skip "SKIP_TESTS=1"
else
  # Resolve the name to a UDID: two runtimes can share a device name, and
  # xcodebuild treats a duplicate name as an ambiguous destination.
  SIM_ID=$(xcrun simctl list devices available 2>/dev/null \
    | grep -F "$SIMULATOR (" \
    | head -1 \
    | sed -E 's/.*\(([0-9A-Fa-f-]{36})\).*/\1/')
  if [ -z "$SIM_ID" ]; then
    SIM_ID=$(xcrun simctl list devices available 2>/dev/null \
      | grep -E "iPhone.*\([0-9A-Fa-f-]{36}\)" \
      | head -1 \
      | sed -E 's/.*\(([0-9A-Fa-f-]{36})\).*/\1/')
    [ -n "$SIM_ID" ] && printf "   \"%s\" not found, using the first available iPhone\n" "$SIMULATOR"
  fi

  if [ -z "$SIM_ID" ]; then
    fail "no available iOS Simulator found; install a runtime in Xcode"
  else
    printf "   running tests on %s (about a minute)\n" "$SIM_ID"
    xcodebuild -project "$PROJECT" -scheme "$SCHEME" \
      -destination "id=$SIM_ID" test >build/preflight-tests.log 2>&1
    status=$?
    grep -E "Executed [0-9]+ tests|TEST (SUCCEEDED|FAILED)" build/preflight-tests.log | tail -3
    if [ $status -eq 0 ]; then
      pass "render pipeline tests"
    else
      fail "tests failed (build/preflight-tests.log)"
    fi
  fi
fi

step "4/4 Archive"
TEAM=$(sed -n 's/^[[:space:]]*DEVELOPMENT_TEAM:[[:space:]]*"\{0,1\}\([A-Za-z0-9]*\)"\{0,1\}[[:space:]]*$/\1/p' project.yml | head -1)

if [ "$SKIP_ARCHIVE" = "1" ]; then
  skip "SKIP_ARCHIVE=1"
elif [ -n "$TEAM" ]; then
  printf "   signing with team %s\n" "$TEAM"
  xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Release \
    -destination 'generic/platform=iOS' -archivePath "$ARCHIVE_PATH" \
    -allowProvisioningUpdates archive >build/preflight-archive.log 2>&1
  status=$?
  if [ $status -ne 0 ]; then
    fail "signed archive failed (build/preflight-archive.log)"
  elif [ ! -d "$ARCHIVE_PATH/Products/Applications/Reelcraft.app" ]; then
    fail "archive finished without Reelcraft.app"
  else
    pass "signed archive at $ARCHIVE_PATH"
    xcodebuild -exportArchive -archivePath "$ARCHIVE_PATH" \
      -exportOptionsPlist tools/ExportOptions.plist -exportPath "$EXPORT_PATH" \
      -allowProvisioningUpdates >build/preflight-export.log 2>&1
    if [ $? -eq 0 ]; then
      pass "IPA exported to $EXPORT_PATH"
      printf "   next: upload it with Transporter, or set destination=upload in tools/ExportOptions.plist\n"
    else
      fail "export failed (build/preflight-export.log)"
    fi
  fi
else
  printf "   no DEVELOPMENT_TEAM in project.yml, so this runs an unsigned device archive\n"
  xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Release \
    -destination 'generic/platform=iOS' -archivePath "$ARCHIVE_PATH" \
    CODE_SIGNING_ALLOWED=NO archive >build/preflight-archive.log 2>&1
  status=$?
  if [ $status -ne 0 ]; then
    fail "unsigned archive failed (build/preflight-archive.log)"
  elif [ ! -d "$ARCHIVE_PATH/Products/Applications/Reelcraft.app" ]; then
    fail "archive finished without Reelcraft.app"
  else
    pass "Release build compiles for iPhone (unsigned archive)"
    skip "signing, export and upload wait for a Team ID, see SUBMISSION.md step 1"
  fi
fi

printf "\n"
if [ "$failures" -eq 0 ]; then
  printf "Preflight passed. Next: SUBMISSION.md step 1 (Team ID and bundle ID).\n"
  exit 0
fi
printf "Preflight finished with %d failure(s). Logs are in build/.\n" "$failures"
exit 1
