#!/bin/zsh
# Bygger BLETest.app (läser watt/kadens/fart/puls via Bluetooth, skickar inga kommandon till trainern).
# Kör sedan: open -n BLETest.app --args "$PWD/bletest.log" 120
cd "${0:A:h}"
rm -rf BLETest.app && mkdir -p BLETest.app/Contents/MacOS
cp Info.plist BLETest.app/Contents/
swiftc -O -swift-version 5 main.swift -o BLETest.app/Contents/MacOS/BLETest
codesign --force --sign - BLETest.app
