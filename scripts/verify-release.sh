#!/usr/bin/env bash
set -e

APK="${1:-}"
CHECKSUM_FILE="${2:-SHA256SUMS.txt}"
SIGNATURE_FILE="${3:-SHA256SUMS.txt.sig}"
PUBLIC_KEY="${4:-scripts/snapgrove-release.pub}"

if [ -z "$APK" ] || [ ! -f "$APK" ]; then
  echo "Usage: ./scripts/verify-release.sh <path-to-apk>"
  exit 1
fi

echo "=========================================="
echo "   Snapgrove Release Verification Tool    "
echo "=========================================="

echo -e "\n[1/2] Verifying SHA-256 Checksum..."
ACTUAL_HASH=$(sha256sum "$APK" | awk '{print $1}')
echo "  Computed: $ACTUAL_HASH"

if [ -f "$CHECKSUM_FILE" ]; then
  EXPECTED_HASH=$(grep "$(basename "$APK")" "$CHECKSUM_FILE" | awk '{print $1}')
  echo "  Expected: $EXPECTED_HASH"
  if [ "$ACTUAL_HASH" = "$EXPECTED_HASH" ]; then
    echo "  ✓ Checksum MATCHES!"
  else
    echo "  ✗ Checksum MISMATCH! File may be altered."
    exit 1
  fi
fi

echo -e "\n[2/2] Verifying Cryptographic Signature..."
if [ -f "$CHECKSUM_FILE" ] && [ -f "$SIGNATURE_FILE" ] && [ -f "$PUBLIC_KEY" ]; then
  if command -v openssl >/dev/null 2>&1; then
    openssl dgst -sha256 -verify "$PUBLIC_KEY" -signature "$SIGNATURE_FILE" "$CHECKSUM_FILE"
    echo "  ✓ Official Release Signature Verified: OK"
  fi
fi
