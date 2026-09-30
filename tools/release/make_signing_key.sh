#!/usr/bin/env bash
# Creates the Android release signing key ONCE and prints the four values
# to store as GitHub Actions secrets. Needs `keytool` (any JDK).
#
#   tools/release/make_signing_key.sh ~/lincoin-release.jks
#
# Keep the .jks file and the password in a password manager. If they are
# lost, phones cannot update to new versions (docs/10-updates.md).
set -euo pipefail
out=${1:?usage: make_signing_key.sh <path/to/new.jks>}
[ -e "$out" ] && { echo "$out already exists; refusing to overwrite" >&2; exit 1; }
alias=lincoin
pass=$(head -c 24 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c 28)
keytool -genkeypair -v -keystore "$out" -storetype PKCS12 -alias "$alias" \
  -keyalg RSA -keysize 4096 -validity 36500 \
  -storepass "$pass" -keypass "$pass" \
  -dname "CN=Lincoin, O=Lincoin, C=TH" >/dev/null
b64=$(base64 -w0 "$out" 2>/dev/null || base64 "$out" | tr -d '\n')
cat <<MSG

Created $out
Add these in GitHub → repository → Settings → Secrets and variables → Actions:

ANDROID_KEYSTORE_BASE64 = (contents of ${out}.base64.txt)
ANDROID_KEYSTORE_PASSWORD = $pass
ANDROID_KEY_ALIAS = $alias
ANDROID_KEY_PASSWORD = $pass

Back up $out and the password now.
MSG
printf '%s' "$b64" > "${out}.base64.txt"
