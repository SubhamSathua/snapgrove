#!/usr/bin/env bash
set -e

KEYSTORE_NAME="${1:-upload-keystore.jks}"
KEY_ALIAS="${2:-snapgrove}"
KEY_PASS="${3:-ChangeMe123!}"

echo "==============================================="
echo "   Snapgrove Keypair & Credentials Generator   "
echo "==============================================="

# 1. Android Keystore
if [ ! -f "$KEYSTORE_NAME" ]; then
  echo "Generating Android release keystore ($KEYSTORE_NAME)..."
  keytool -genkey -v -keystore "$KEYSTORE_NAME" -alias "$KEY_ALIAS" \
    -keyalg RSA -keysize 2048 -validity 10000 \
    -storepass "$KEY_PASS" -keypass "$KEY_PASS" \
    -dname "CN=Snapgrove, OU=Mobile, O=Snapgrove, L=City, S=State, C=US"
fi

base64 -w 0 "$KEYSTORE_NAME" > keystore_base64.txt 2>/dev/null || base64 "$KEYSTORE_NAME" > keystore_base64.txt
echo "✓ Keystore base64 saved to keystore_base64.txt"

cat <<EOF > android/key.properties
storePassword=$KEY_PASS
keyPassword=$KEY_PASS
keyAlias=$KEY_ALIAS
storeFile=../$KEYSTORE_NAME
EOF
echo "✓ Local config written to android/key.properties"

# 2. Windows Code-Signing Certificate (PFX)
WIN_CERT_NAME="${4:-snapgrove-windows.pfx}"
if [ ! -f "$WIN_CERT_NAME" ]; then
  echo "Generating Windows code-signing PFX ($WIN_CERT_NAME)..."
  keytool -genkeypair -v -keystore "$WIN_CERT_NAME" -storetype PKCS12 \
    -alias "$KEY_ALIAS" -keyalg RSA -keysize 2048 -validity 10000 \
    -storepass "$KEY_PASS" -keypass "$KEY_PASS" \
    -dname "CN=Snapgrove Open Source, O=Snapgrove, C=US" \
    -ext "EKU=codeSigning"
fi

keytool -exportcert -keystore "$WIN_CERT_NAME" -storetype PKCS12 \
  -alias "$KEY_ALIAS" -storepass "$KEY_PASS" \
  -file "snapgrove-windows.cer" -rfc 2>/dev/null || true
echo "✓ Public certificate exported to snapgrove-windows.cer"

base64 -w 0 "$WIN_CERT_NAME" > windows_cert_base64.txt 2>/dev/null || base64 "$WIN_CERT_NAME" > windows_cert_base64.txt
echo "✓ Windows PFX base64 saved to windows_cert_base64.txt"

# 3. Verification keypair
echo "Generating verification keypair..."
mkdir -p scripts
openssl genrsa -out verify-private.pem 2048
openssl rsa -in verify-private.pem -pubout -out scripts/snapgrove-release.pub
echo "✓ Private verification key saved to verify-private.pem"
echo "✓ Public verification key saved to scripts/snapgrove-release.pub"
