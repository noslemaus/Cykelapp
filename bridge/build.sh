#!/bin/zsh
# Builds Cykelbrygga.app (ad-hoc signed so macOS can grant it Bluetooth access).
set -e
cd "${0:A:h}"
rm -rf Cykelbrygga.app && mkdir -p Cykelbrygga.app/Contents/MacOS
cp Info.plist Cykelbrygga.app/Contents/
swiftc -O -swift-version 5 -target arm64-apple-macos13.0 main.swift -o Cykelbrygga.app/Contents/MacOS/Cykelbrygga
codesign --force --sign - Cykelbrygga.app
echo "Byggd: $PWD/Cykelbrygga.app"
