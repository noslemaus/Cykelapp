"""Wraps the user-facing Swedish literals in tr() (or TranslationServer.translate in static functions)
in the UI and engine scripts, so formatted and joined texts are translated too (plain labels are
translated by Godot on their own). Leaves constants, comparisons, dict keys, defaults and developer
code alone. python3 -I sprak_tr.py <game dir> <files…>"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sprak_tabell import EN  # noqa: E402

GAME = sys.argv[1]
DEV_FUNCS = re.compile(r"^func (_flowtest|_selftest|_stravatest|_closetest|_bridgecheck|_worldshot|_worldmap|_worldthumb|_dev_\w+|_free_check|_arrival_ok|_japan_battle|_egypt_battle|_teleport_check|_run_dev|_fake_browser|_press|_click_card|_dev_options)\b")
LIT = re.compile(r'"((?:[^"\\]|\\.)*)"')


def runtime(s):
    return s.encode("utf-8").decode("unicode_escape").encode("latin-1").decode("utf-8") if "\\" in s else s


total = 0
for rel in sys.argv[2:]:
    path = os.path.join(GAME, rel)
    lines = open(path, encoding="utf-8").read().split("\n")
    in_dev = False
    in_static = False
    in_const = False
    out = []
    changed = 0
    for line in lines:
        if re.match(r"^(static )?func ", line):
            in_dev = bool(DEV_FUNCS.match(line))
            in_static = line.startswith("static func")
            in_const = False
        if re.match(r"^\s*static func ", line):
            in_static = True
        elif re.match(r"^\s*func ", line):
            in_static = False
        if re.match(r"^(const|var|@export|enum|signal|class_name|extends) ", line):
            in_const = line.startswith("const") or line.startswith("var")
        elif in_const and line and not line[0].isspace() and not line.startswith(("}", "]", ")")):
            in_const = False
        stripped = line.strip()
        skip = (in_dev or in_const or stripped.startswith("#") or "print(" in line or "push_" in line
                or re.match(r"^\s*(static )?func ", line) or stripped.startswith("const ")
                or re.match(r"^\s*var \w+ *(:[^=]*)?:?= *\"", line) is not None and not line.startswith("    "))
        if skip:
            out.append(line)
            continue

        def wrap(m):
            global total
            nonlocal_changed[0]
            s = m.group(1)
            if runtime(s) not in EN:
                return m.group(0)
            before = line[:m.start()]
            after = line[m.end():]
            if re.search(r"(==|!=)\s*$", before) or re.match(r"\s*(==|!=)", after) or re.match(r"\s*:", after):
                return m.group(0)
            if re.search(r"(tr|translate|atr)\(\s*$", before) or before.rstrip().endswith("in ["):
                return m.group(0)
            if re.search(r"\b(match|case)\b", before):
                return m.group(0)
            nonlocal_changed[0] += 1
            if in_static:
                return 'str(TranslationServer.translate("%s"))' % s
            return 'tr("%s")' % s
        nonlocal_changed = [0]
        new = LIT.sub(wrap, line)
        changed += nonlocal_changed[0]
        out.append(new)
    if changed:
        open(path, "w", encoding="utf-8").write("\n".join(out))
    total += changed
    print(f"{rel}: {changed}")
print("totalt", total)
