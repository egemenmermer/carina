#!/usr/bin/env bash
# Submits a .zip, .dmg or .pkg to Apple's notary service and waits for the
# result; prints the notary log and fails unless it is Accepted.
#
# Usage: tools/macos/notarize.sh <file>
# Env: ASC_KEY_PATH (.p8), ASC_KEY_ID, ASC_ISSUER_ID.
set -euo pipefail

file=$1
auth=(--key "$ASC_KEY_PATH" --key-id "$ASC_KEY_ID" --issuer "$ASC_ISSUER_ID")
result=$(mktemp)
xcrun notarytool submit "$file" "${auth[@]}" \
  --wait --timeout 30m --output-format json | tee "$result"

status=$(plutil -extract status raw "$result")
if [ "$status" != "Accepted" ]; then
  xcrun notarytool log "$(plutil -extract id raw "$result")" "${auth[@]}"
  echo "Notarization of $file finished with status: $status" >&2
  exit 1
fi
