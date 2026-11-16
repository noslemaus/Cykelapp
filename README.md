# Cykelapp

An indoor cycling game for smart trainers, built with Godot 4.7 (working title).

- Three worlds (Archipelago, Egypt, Japan) and a gym screen; weather, time of day and seasons.
- 387 structured workouts and 18 training plans, plus your own; ERG and SIM with 24 virtual gears.
- Pacers with draft, segments with a ghost lap, XP levels and a garage.
- Zwift Click buttons, heart rate straps, FTMS calibration and a choice of trainer.
- FIT files, optional Strava upload, crash-safe autosave. English and Swedish.

| Platform | Status |
|---|---|
| macOS 13+, Apple Silicon | Working (Bluetooth bridge in Swift) |
| Windows 10/11, x64 | Builds; the Rust bridge is tested on macOS only so far |

## Install

- **Mac:** open `Cykelapp.dmg` and drag Cykelapp to Applications. The app is not notarized, so the
  first start is blocked: allow it under **System Settings → Privacy & Security → Open Anyway**. Then
  allow Bluetooth when macOS asks.
- **Windows:** unzip `Cykelapp-windows.zip` and start `Cykelapp.exe` (`Cykelbrygga.exe` must stay
  beside it). If SmartScreen warns, choose **More info → Run anyway**.

Close Zwift, then pick your trainer under **Settings → Hardware**. For Strava, create your own API
application at strava.com/settings/api and enter its Client ID and Secret under **Settings → Strava**.

## Build

```bash
./paketera.sh            # build/mac/Cykelapp.dmg and build/Cykelapp-windows.zip
./paketera.sh windows    # Windows only (or: mac)
```

Needs Godot 4.7.2 with its export templates; the Windows bridge also needs Rust with the
`x86_64-pc-windows-gnu` target, zig and cargo-zigbuild.

To work on the game, open `game/project.godot` in Godot. Runs from the editor use the pretend trainer
until you build the Mac bridge with `bridge/build.sh`.

## Test

```bash
cd game
godot --headless --path . -s res://tests/run_tests.gd
godot --headless --path . -- --selftest   # also --flowtest, --closetest, --kraschtest, --passtest
```

Developer runs always use the pretend trainer and never change saved settings.

## Layout

| Folder | Contents |
|---|---|
| `game/` | The Godot project: `core/` logic, `ui/`, `world/`, `workouts/`, `plans/`, `lang/` |
| `bridge/` | Mac bridge (Swift, CoreBluetooth) |
| `bridge-windows/` | Windows bridge (Rust, btleplug) |
| `assets/` | Generators for models, textures, music and animations |
| `ble-test/`, `click-test/` | Read-only Bluetooth test tools |

The game and the bridge talk JSON over UDP on 127.0.0.1 (telemetry 47010, commands 47011). The
bridge releases the trainer if the game goes quiet for 5 s.

Settings, rides and Strava tokens stay in Godot's user folder and never reach the repo or a package.
Not affiliated with Zwift, Wahoo or Strava.
