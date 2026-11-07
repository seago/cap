#!/bin/bash
set -euo pipefail

IDENTITY_NAME="Cap Local Signing"
KEYCHAIN="${KEYCHAIN:-$HOME/Library/Keychains/login.keychain-db}"

if security find-identity -v -p codesigning | grep -q "\"$IDENTITY_NAME\""; then
  echo "Signing identity already exists: $IDENTITY_NAME"
  exit 0
fi

WORK_DIR=$(mktemp -d /tmp/cap-signing.XXXXXX)
trap 'rm -rf "$WORK_DIR"' EXIT

KEY="$WORK_DIR/key.pem"
CERT="$WORK_DIR/cert.pem"
P12="$WORK_DIR/cert.p12"
PASS="cap-local-$(openssl rand -hex 8)"

openssl req -x509 -newkey rsa:2048 -sha256 -days 3650 -nodes \
  -keyout "$KEY" -out "$CERT" \
  -subj "/CN=$IDENTITY_NAME/O=Cap Local/C=US" \
  -addext "basicConstraints=critical,CA:false" \
  -addext "keyUsage=critical,digitalSignature" \
  -addext "extendedKeyUsage=critical,codeSigning"

# macOS security import does not understand modern PKCS#12 PBES2; force legacy algorithms.
openssl pkcs12 -export -out "$P12" -inkey "$KEY" -in "$CERT" \
  -passout "pass:$PASS" -name "$IDENTITY_NAME" \
  -keypbe PBE-SHA1-3DES -certpbe PBE-SHA1-3DES -macalg sha1

security import "$P12" -k "$KEYCHAIN" -P "$PASS" \
  -T /usr/bin/codesign -T /usr/bin/security -A

security add-trusted-cert -r trustRoot -k "$KEYCHAIN" "$CERT"

security find-identity -v -p codesigning | grep "\"$IDENTITY_NAME\""
echo "Created signing identity: $IDENTITY_NAME"
