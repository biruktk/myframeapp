#!/usr/bin/env bash
# Print SHA-1 / SHA-256 for Google Cloud Console → Credentials → Android OAuth client.
# Package name must be: com.myframe.minyuex
set -euo pipefail
KEYSTORE="${ANDROID_DEBUG_KEYSTORE:-$HOME/.android/debug.keystore}"
echo "Package: com.myframe.minyuex"
echo "Keystore: $KEYSTORE"
keytool -list -v -keystore "$KEYSTORE" -alias androiddebugkey -storepass android -keypass android 2>/dev/null | grep -E "SHA1|SHA256" || {
  echo "Run: keytool -list -v -keystore YOUR.keystore -alias YOUR_ALIAS"
  exit 1
}
