#!/usr/bin/env bash
# Submit an .app or .dmg to Apple notary service and staple the ticket.
# Usage: notarize.sh <path-to-app-or-dmg>
#
# Env: APPLE_ID, APP_PASSWORD, TEAM_ID
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: $0 <path-to-app-or-dmg>" >&2
  exit 2
fi

TARGET="$1"

: "${APPLE_ID:?APPLE_ID not set}"
: "${APP_PASSWORD:?APP_PASSWORD not set}"
: "${TEAM_ID:?TEAM_ID not set}"

if [[ ! -e "${TARGET}" ]]; then
  echo "error: ${TARGET} not found" >&2
  exit 1
fi

ext="${TARGET##*.}"
submit_path="${TARGET}"
cleanup_zip=""

# notarytool accepts .zip / .dmg / .pkg — wrap a bare .app in a zip first.
if [[ "${ext}" == "app" ]]; then
  submit_path="${TARGET%.app}.zip"
  echo "==> Zipping ${TARGET} → ${submit_path}"
  /usr/bin/ditto -c -k --keepParent "${TARGET}" "${submit_path}"
  cleanup_zip="${submit_path}"
fi

cleanup() {
  if [[ -n "${cleanup_zip}" && -f "${cleanup_zip}" ]]; then
    rm -f "${cleanup_zip}"
  fi
}
trap cleanup EXIT

echo "==> Submitting ${submit_path} to notary service"
set +e
submit_output="$(xcrun notarytool submit "${submit_path}" \
  --apple-id "${APPLE_ID}" \
  --password "${APP_PASSWORD}" \
  --team-id "${TEAM_ID}" \
  --wait \
  --output-format plist 2>&1)"
submit_rc=$?
set -e

echo "${submit_output}"

if [[ ${submit_rc} -ne 0 ]]; then
  echo "error: notarytool submit failed (rc=${submit_rc})" >&2
  # Try to extract submission id for log dump
  sub_id="$(echo "${submit_output}" | sed -n 's/.*<string>\([0-9a-f-]\{36\}\)<\/string>.*/\1/p' | head -n1)"
  if [[ -n "${sub_id}" ]]; then
    echo "==> Dumping notary log for ${sub_id}"
    xcrun notarytool log "${sub_id}" \
      --apple-id "${APPLE_ID}" \
      --password "${APP_PASSWORD}" \
      --team-id "${TEAM_ID}" || true
  fi
  exit 1
fi

# Confirm status==Accepted in the plist output
if ! echo "${submit_output}" | grep -q "Accepted"; then
  echo "error: notarization did not return Accepted status" >&2
  exit 1
fi

echo "==> Stapling ${TARGET}"
xcrun stapler staple "${TARGET}"

echo "==> Verifying staple"
xcrun stapler validate "${TARGET}"

echo "==> Notarization complete: ${TARGET}"
