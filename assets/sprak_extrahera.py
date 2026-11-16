"""Lists the game's user-facing Swedish texts (string literals in the UI, the engine's messages and the
worlds' signs and toasts) for the translation table game/lang/texter.csv.
python3 -I sprak_extrahera.py <game dir>  → prints one literal per line (unique, in file order)."""
import os
import re
import sys

GAME = sys.argv[1]
FILES = ["main.gd"] + [os.path.join(d, f) for d in ("ui", "core", "world", "world/skargarden", "world/egypten", "world/japan")
                       for f in sorted(os.listdir(os.path.join(GAME, d))) if f.endswith(".gd")]
SKIP_FILES = {"core/fit_writer.gd", "core/metrics.gd", "core/physics.gd", "core/zones.gd", "core/lap_tracker.gd",
              "core/power_curve.gd", "core/trainer_sim.gd", "world/rider.gd", "world/fartljud.gd", "world/ljud.gd"}
# Developer and test code in main.gd prints Swedish for the developer only.
DEV_FUNCS = re.compile(r"^func (_flowtest|_selftest|_stravatest|_closetest|_bridgecheck|_worldshot|_worldmap|_worldthumb|_dev_\w+|_free_check|_arrival_ok|_japan_battle|_egypt_battle|_teleport_check|_run_dev|_fake_browser|_press|_click_card)\b")
LIT = re.compile(r'"((?:[^"\\]|\\.)*)"')
SV = re.compile(r"[åäöÅÄÖ]")


def wanted(s: str) -> bool:
    if not re.search(r"[A-Za-zåäöÅÄÖ]", s):
        return False
    if s.startswith(("res://", "user://", "http", "%s/", "/")) or s.endswith((".gd", ".png", ".glb", ".json", ".cfg", ".wav")):
        return False
    if re.fullmatch(r"[a-z0-9_\-./:]+", s) and not SV.search(s):
        return False        # ids, keys, file names
    if re.fullmatch(r"[a-z_]+:[a-z_0-9]+", s):
        return False
    if re.fullmatch(r"[0-9a-f]{6}", s):
        return False
    return True


seen = []
for rel in FILES:
    if rel in SKIP_FILES:
        continue
    in_dev = False
    for line in open(os.path.join(GAME, rel), encoding="utf-8"):
        if line.startswith("func ") or line.startswith("static func "):
            in_dev = bool(DEV_FUNCS.match(line))
        if in_dev:
            continue
        code = line.split("#", 1)[0] if '"' not in line.split("#", 1)[0][-1:] else line
        stripped = line.strip()
        if stripped.startswith("##") or stripped.startswith("#") or "print(" in line or "push_error" in line or "push_warning" in line:
            continue
        for m in LIT.finditer(line):
            s = m.group(1)
            if wanted(s) and s not in seen:
                seen.append(s)
for s in seen:
    print(s)
