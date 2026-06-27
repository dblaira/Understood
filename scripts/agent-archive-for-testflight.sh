#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/scripts/load-app-store-connect-env.sh"
load_app_store_connect_env

PROJECT="$ROOT_DIR/Understood.xcodeproj"
SCHEME="${UNDERSTOOD_SCHEME:-Understood}"
ARCHIVE_PATH="${ARCHIVE_PATH:-$ROOT_DIR/build/Understood.xcarchive}"
EXPORT_PATH="${EXPORT_PATH:-$ROOT_DIR/build/TestFlightExport}"
EXPORT_OPTIONS="${EXPORT_OPTIONS:-$ROOT_DIR/ExportOptions-TestFlight.plist}"
PROJECT_FILE="$ROOT_DIR/Understood.xcodeproj/project.pbxproj"

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

"$ROOT_DIR/scripts/agent-testflight-readiness.sh"

mkdir -p "$(dirname "$ARCHIVE_PATH")" "$EXPORT_PATH"

TEAM_ID="$(awk -F'= ' '/DEVELOPMENT_TEAM =/ { gsub(/[;[:space:]]/, "", $2); print $2; exit }' "$PROJECT_FILE")"
sed "s/TEAM_ID_PLACEHOLDER/$TEAM_ID/g" "$ROOT_DIR/ExportOptions-TestFlight.template.plist" > "$EXPORT_OPTIONS"

echo "Archiving Understood for TestFlight..."
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE_PATH" \
  -allowProvisioningUpdates \
  archive

echo "Exporting Understood archive for App Store Connect..."
xcodebuild \
  -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist "$EXPORT_OPTIONS" \
  -allowProvisioningUpdates

echo "Archive/export complete: $EXPORT_PATH"
