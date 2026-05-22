#!/usr/bin/env bash
# Import Developer ID Application certificate into a temporary keychain.
# Reads CERT_P12_BASE64 + CERT_PASSWORD from env. Exports BUILD_KEYCHAIN to
# $GITHUB_ENV so subsequent steps can reference it (and the cleanup trap can
# delete it).
set -euo pipefail

: "${CERT_P12_BASE64:?CERT_P12_BASE64 not set}"
: "${CERT_PASSWORD:?CERT_PASSWORD not set}"
: "${RUNNER_TEMP:?RUNNER_TEMP not set (run inside GitHub Actions)}"
: "${GITHUB_ENV:?GITHUB_ENV not set (run inside GitHub Actions)}"

KEYCHAIN_PATH="${RUNNER_TEMP}/build.keychain"
KEYCHAIN_PASSWORD="$(openssl rand -base64 24)"
CERT_PATH="${RUNNER_TEMP}/cert.p12"

cleanup_tmp() {
  rm -f "${CERT_PATH}"
}
trap cleanup_tmp EXIT

echo "==> Decoding certificate"
echo "${CERT_P12_BASE64}" | base64 --decode > "${CERT_PATH}"

echo "==> Creating temporary keychain ${KEYCHAIN_PATH}"
security create-keychain -p "${KEYCHAIN_PASSWORD}" "${KEYCHAIN_PATH}"
security set-keychain-settings -lut 21600 "${KEYCHAIN_PATH}"
security unlock-keychain -p "${KEYCHAIN_PASSWORD}" "${KEYCHAIN_PATH}"

echo "==> Importing certificate"
security import "${CERT_PATH}" \
  -k "${KEYCHAIN_PATH}" \
  -P "${CERT_PASSWORD}" \
  -T /usr/bin/codesign \
  -T /usr/bin/security \
  -T /usr/bin/productbuild

echo "==> Setting keychain search list"
# Prepend our keychain so codesign/notarytool find the cert; keep login.keychain
# accessible for other tooling.
security list-keychains -d user -s "${KEYCHAIN_PATH}" "$(security list-keychains -d user | sed -e 's/[\" ]//g')"
security default-keychain -s "${KEYCHAIN_PATH}"

echo "==> Setting partition list (non-interactive codesign)"
security set-key-partition-list \
  -S "apple-tool:,apple:,codesign:" \
  -s \
  -k "${KEYCHAIN_PASSWORD}" \
  "${KEYCHAIN_PATH}"

echo "==> Available signing identities:"
security find-identity -v -p codesigning "${KEYCHAIN_PATH}"

echo "BUILD_KEYCHAIN=${KEYCHAIN_PATH}" >> "${GITHUB_ENV}"
echo "==> Keychain ready"
