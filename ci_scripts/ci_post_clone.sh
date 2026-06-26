#!/bin/sh
set -eu

echo "Xcode Cloud post-clone: Understood"

if [ ! -d "Understood.xcodeproj" ]; then
  echo "Missing Understood.xcodeproj. The Xcode Cloud workflow needs the project committed at repo root."
  exit 1
fi

if [ ! -f "Understood.xcodeproj/xcshareddata/xcschemes/Understood.xcscheme" ]; then
  echo "Missing shared Understood scheme. Share the scheme before running Xcode Cloud."
  exit 1
fi

echo "Post-clone check complete."
