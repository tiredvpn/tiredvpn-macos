#!/usr/bin/env bash
# Fetch libtiredvpn.a + libtiredvpn.h from tiredvpn-oss GitHub releases.
# Verifies SHA-256 from .sha256 sidecar files. Idempotent.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
VENDOR_DIR="$REPO_ROOT/Vendor"
VERSION_FILE="$VENDOR_DIR/VERSION"

RELEASES_BASE="https://github.com/tiredvpn/tiredvpn-oss/releases/download"

# Resolve version: $LIBTIREDVPN_VERSION env wins; otherwise Vendor/VERSION.
if [[ -n "${LIBTIREDVPN_VERSION:-}" ]]; then
  VERSION="$LIBTIREDVPN_VERSION"
elif [[ -f "$VERSION_FILE" ]]; then
  VERSION="$(tr -d '[:space:]' < "$VERSION_FILE")"
else
  echo "error: no version (set LIBTIREDVPN_VERSION or create $VERSION_FILE)" >&2
  exit 1
fi

echo "==> tiredvpn-core version: $VERSION"

mkdir -p "$VENDOR_DIR"
cd "$VENDOR_DIR"

ARTIFACTS=("libtiredvpn.a" "libtiredvpn.h")

sha256_of() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  else
    sha256sum "$1" | awk '{print $1}'
  fi
}

download() {
  local name="$1"
  local url="$RELEASES_BASE/$VERSION/$name"
  echo "    fetching $url"
  curl -fsSL --retry 3 --retry-delay 2 -o "$name" "$url"
}

for artifact in "${ARTIFACTS[@]}"; do
  sha_file="${artifact}.sha256"

  # Always refresh the .sha256 sidecar to know the expected hash for this version.
  download "$sha_file"
  expected="$(awk '{print $1}' < "$sha_file")"
  if [[ -z "$expected" ]]; then
    echo "error: empty sha256 in $sha_file" >&2
    exit 1
  fi

  if [[ -f "$artifact" ]]; then
    actual="$(sha256_of "$artifact")"
    if [[ "$actual" == "$expected" ]]; then
      echo "    $artifact: up-to-date (sha matches)"
      continue
    fi
    echo "    $artifact: sha mismatch — redownloading"
  fi

  download "$artifact"
  actual="$(sha256_of "$artifact")"
  if [[ "$actual" != "$expected" ]]; then
    echo "error: sha256 mismatch for $artifact" >&2
    echo "  expected: $expected" >&2
    echo "  actual:   $actual" >&2
    exit 1
  fi
  echo "    $artifact: ok"
done

echo "==> Vendor/ ready"
