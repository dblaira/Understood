#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="$ROOT_DIR/Understood.xcodeproj"
SCHEME="${UNDERSTOOD_SCHEME:-Understood}"
DESTINATION="${IOS_DESTINATION:-platform=iOS Simulator,name=iPhone 17}"

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

echo "Agent iOS check: Understood"
echo "Project: $PROJECT"
echo "Scheme: $SCHEME"
echo "Destination: $DESTINATION"

xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination "$DESTINATION" \
  build

echo "Agent iOS check passed: Understood simulator build succeeded."
echo "Note: this Xcode project currently exposes no test target."
