#!/usr/bin/env bash
# Signs a built Carina.app with a Developer ID (hardened runtime, secure
# timestamp) and, when an App Store Connect API key is given, notarizes it
# and staples the ticket.
#
# Usage: tools/macos/sign_and_notarize.sh <path/to/Carina.app> <identity>
#   <identity> is a codesigning identity name or SHA-1 hash.
# Optional notarization env: ASC_KEY_PATH (.p8), ASC_KEY_ID, ASC_ISSUER_ID.
set -euo pipefail

app=$1
identity=$2
entitlements="$(cd "$(dirname "$0")/../.." && pwd)/macos/Runner/Release.entitlements"

sign() {
  codesign --force --timestamp --options runtime --sign "$identity" "$@"
}

# Inside out: loose dylibs, then frameworks, then the app with entitlements.
find "$app/Contents/Frameworks" -type f -name '*.dylib' -print0 |
  while IFS= read -r -d '' lib; do sign "$lib"; done
for framework in "$app"/Contents/Frameworks/*.framework; do
  sign "$framework"
done
sign --entitlements "$entitlements" "$app"
codesign --verify --deep --strict --verbose=2 "$app"

if [ -z "${ASC_KEY_PATH:-}" ]; then
  echo "No App Store Connect key: signed but not notarized."
  exit 0
fi

work=$(mktemp -d)
ditto -c -k --sequesterRsrc --keepParent "$app" "$work/notarize.zip"
"$(dirname "$0")/notarize.sh" "$work/notarize.zip"

xcrun stapler staple "$app"
spctl --assess --type execute --verbose=4 "$app"
