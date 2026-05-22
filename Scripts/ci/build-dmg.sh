#!/usr/bin/env bash
# Build a drag-to-Applications DMG from a signed .app bundle.
# Usage: build-dmg.sh <input.app> <output.dmg>
#
# Prefers create-dmg (brew). Falls back to plain hdiutil if create-dmg is
# unavailable (e.g. local dev without Homebrew). The fallback produces a
# functional but unstyled DMG.
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $0 <input.app> <output.dmg>" >&2
  exit 2
fi

APP_PATH="$1"
DMG_PATH="$2"

if [[ ! -d "${APP_PATH}" ]]; then
  echo "error: ${APP_PATH} not found" >&2
  exit 1
fi

APP_NAME="$(basename "${APP_PATH}")"
rm -f "${DMG_PATH}"
mkdir -p "$(dirname "${DMG_PATH}")"

if command -v create-dmg >/dev/null 2>&1; then
  echo "==> Building DMG via create-dmg"
  create-dmg \
    --volname "TiredVPN" \
    --window-size 540 380 \
    --icon-size 96 \
    --icon "${APP_NAME}" 140 200 \
    --app-drop-link 400 200 \
    --no-internet-enable \
    "${DMG_PATH}" \
    "${APP_PATH}"
else
  echo "==> create-dmg not found; falling back to hdiutil (unstyled DMG)"
  staging="$(mktemp -d)"
  trap 'rm -rf "${staging}"' EXIT
  cp -R "${APP_PATH}" "${staging}/"
  ln -s /Applications "${staging}/Applications"
  hdiutil create \
    -volname "TiredVPN" \
    -srcfolder "${staging}" \
    -ov \
    -format UDZO \
    "${DMG_PATH}"
fi

echo "==> DMG ready: ${DMG_PATH}"
