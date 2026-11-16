#!/bin/zsh
# Bygger ClickTest.app, som läser knapptryck från Zwift Click via Bluetooth.
# Kör sedan: open -W -n ClickTest.app --args "$PWD/clicktest.log" 240
cd "${0:A:h}"
rm -rf ClickTest.app && mkdir -p ClickTest.app/Contents/MacOS
cp Info.plist ClickTest.app/Contents/
swiftc -O -swift-version 5 main.swift -o ClickTest.app/Contents/MacOS/ClickTest
codesign --force --sign - ClickTest.app
