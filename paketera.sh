#!/bin/zsh
# Packages the game for Mac (Apple Silicon, a .dmg) and Windows (a .zip) into build/.
#   ./paketera.sh            both
#   ./paketera.sh mac        only the Mac dmg (build/mac/Cykelapp.dmg)
#   ./paketera.sh windows    only the Windows zip (build/Cykelapp-windows.zip); the Mac dmg is left alone
# Needs Godot 4.7.2 and its export templates installed (Godot's "Manage Export Templates", or the
# official .tpz unpacked into ~/Library/Application Support/Godot/export_templates/4.7.2.stable).
# Windows also needs Rust with the x86_64-pc-windows-gnu target, zig and cargo-zigbuild (README, "Package").
# Stops first if anything personal is found in what gets packaged (ANTECKNINGAR.md "Paketering", local).
set -e
cd "${0:A:h}"
WHAT=${1:-alla}
[[ $WHAT == (alla|mac|windows) ]] || { echo "Användning: ./paketera.sh [mac|windows]"; exit 1; }
MAC=$([[ $WHAT != windows ]] && echo 1 || echo 0)
WIN=$([[ $WHAT != mac ]] && echo 1 || echo 0)
VERSION=4.7.2.stable
TEMPLATES="$HOME/Library/Application Support/Godot/export_templates/$VERSION"
# Words that must never reach a package. Names and accounts are kept outside the repo, in
# .integritet (one extended regular expression, gitignored); without it, only paths and mail are checked.
PERSONAL="/Users/|@gmail|Senast i Garmin"
[[ -f .integritet ]] && PERSONAL="$PERSONAL|$(<.integritet)"

# 1. Nothing personal in the game or the bridges (hex checksums in .import files are false alarms).
hits=$(grep -rIil -E "$PERSONAL" game bridge bridge-windows \
  --exclude-dir=.godot --exclude-dir="*.app" --exclude-dir=target --exclude="*.log" --exclude="*.import" || true)
if [[ -n "$hits" ]]; then
  echo "STOPP: personliga uppgifter i:"; echo "$hits"; exit 1
fi
mkdir -p build/mallar build/mac build/windows

if (( MAC )); then
  # 2. Godot's macOS templates are universal only: an Apple Silicon template is cut out of them.
  if [[ ! -f build/mallar/macos_arm64.zip ]]; then
    rm -rf build/mallar/arbete && mkdir -p build/mallar/arbete
    (cd build/mallar/arbete && unzip -q "$TEMPLATES/macos.zip")
    bin=build/mallar/arbete/macos_template.app/Contents/MacOS
    for kind in release debug; do
      lipo -thin arm64 "$bin/godot_macos_$kind.universal" -output "$bin/godot_macos_$kind.arm64"
      rm "$bin/godot_macos_$kind.universal"
    done
    (cd build/mallar/arbete && zip -q -r ../macos_arm64.zip macos_template.app)
  fi

  # 3. The Mac bridge (Bluetooth: trainer, heart rate, Zwift Click), built fresh from
  #    bridge/main.swift for the package; the developer copy in bridge/ is left alone.
  BRIDGE=build/brygga/Cykelbrygga.app
  rm -rf build/brygga && mkdir -p $BRIDGE/Contents/MacOS
  cp bridge/Info.plist $BRIDGE/Contents/
  # Built for macOS 13 like the game (without -target it only runs on the macOS it was built on).
  swiftc -O -swift-version 5 -target arm64-apple-macos13.0 bridge/main.swift -o $BRIDGE/Contents/MacOS/Cykelbrygga
fi

if (( WIN )); then
  # 3b. The Windows bridge (bridge-windows/, Rust + btleplug), cross-built with zig as the linker.
  #     Source paths are rewritten so nothing about this Mac ends up in the exe.
  export PATH="/opt/homebrew/opt/rustup/bin:$HOME/.cargo/bin:$PATH"
  export RUSTFLAGS="--remap-path-prefix=$HOME/.cargo/registry/src=crates --remap-path-prefix=$HOME/.rustup=rust --remap-path-prefix=$PWD/bridge-windows=cykelbrygga"
  (cd bridge-windows && cargo zigbuild --release --target x86_64-pc-windows-gnu --target-dir ../build/brygga-windows)
  cp build/brygga-windows/x86_64-pc-windows-gnu/release/Cykelbrygga.exe build/windows/Cykelbrygga.exe
  if LC_ALL=C grep -a -q -i -E "$PERSONAL" build/windows/Cykelbrygga.exe; then
    echo "STOPP: personliga uppgifter i Cykelbrygga.exe"; exit 1
  fi
fi

# 4. Export (the presets are in game/export_presets.cfg).
cd game
if (( WIN )); then
  godot --headless --path . --export-release "Windows Desktop" ../build/windows/Cykelapp.exe
fi
if (( MAC )); then
  rm -rf ../build/mac/Cykelapp.app
  godot --headless --path . --export-release "macOS" ../build/mac/Cykelapp.app
fi
cd ..

if (( MAC )); then
  # 5. The bridge inside the Mac app (Contents/Helpers, where core/bridge_client.gd looks), the whole
  #    app signed again (ad hoc: inside first, then the app), and a dmg with a shortcut to Applications.
  APP=build/mac/Cykelapp.app
  # macOS asks the app that holds the bridge (Cykelapp), not the bridge, whether it may use Bluetooth.
  # Without this text in Cykelapp's Info.plist the bridge is stopped the moment it touches Bluetooth,
  # and Godot has no export setting for it.
  BT_EN="Cykelapp reads power, cadence and heart rate from your trainer and heart rate strap and sets the trainer's resistance."
  BT_SV="Cykelapp läser watt, kadens och puls från din trainer och ditt pulsband och styr trainerns motstånd."
  plutil -insert NSBluetoothAlwaysUsageDescription -string "$BT_EN" $APP/Contents/Info.plist
  # Apple Silicon only: the template still names Intel in its architecture keys.
  plutil -replace LSArchitecturePriority -json '["arm64"]' $APP/Contents/Info.plist
  plutil -remove LSMinimumSystemVersionByArchitecture.x86_64 $APP/Contents/Info.plist
  plutil -insert LSMinimumSystemVersion -string 13.0 $APP/Contents/Info.plist
  printf '"NSBluetoothAlwaysUsageDescription" = "%s";\n' "$BT_EN" >> $APP/Contents/Resources/en.lproj/InfoPlist.strings
  printf '"NSBluetoothAlwaysUsageDescription" = "%s";\n' "$BT_SV" >> $APP/Contents/Resources/sv.lproj/InfoPlist.strings
  mkdir -p $APP/Contents/Helpers
  cp -R $BRIDGE $APP/Contents/Helpers/
  codesign --force --sign - $APP/Contents/Helpers/Cykelbrygga.app
  codesign --force --sign - $APP
  codesign --verify --deep --strict $APP
  rm -rf build/mac/dmg && mkdir -p build/mac/dmg
  cp -R $APP build/mac/dmg/
  ln -s /Applications build/mac/dmg/Program
  rm -f build/mac/Cykelapp.dmg
  hdiutil create -quiet -volname Cykelapp -srcfolder build/mac/dmg -format UDZO build/mac/Cykelapp.dmg
  rm -rf build/mac/dmg
  ls -la build/mac/Cykelapp.dmg
fi

if (( WIN )); then
  # 6. The Windows zip: the game, its pck and the bridge beside it (core/bridge_client.gd looks there).
  rm -f build/Cykelapp-windows.zip
  (cd build/windows && zip -q -9 ../Cykelapp-windows.zip Cykelapp.exe Cykelapp.pck Cykelbrygga.exe)
  ls -la build/Cykelapp-windows.zip
fi
