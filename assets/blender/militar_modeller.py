"""The secret military base, the tank and the monsters of free riding ("Tryck ej här").

    blender --background --python assets/blender/militar_modeller.py -- game/world/skargarden/models

Same rules as skargarden_modeller.py (Blender Z-up, +X forward, low-poly with flat shading and
shared named colours). Its helpers (box, cyl, blob, taper, tube, prism, slab_y, ring, export,
gable_house, window …) are read from that file without running its model builds, so the two
scripts always draw with the same tools and palette.

Models with moving parts (tank, zombie, alien, radar) are exported as loose named parts in one
GLB, with each part's origin at its joint, like the cyclist.
"""
import ast
import math
import os
import random
import sys

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
_src_path = os.path.join(HERE, "skargarden_modeller.py")
_tree = ast.parse(open(_src_path, encoding="utf-8").read())
# Keep imports, constants and function definitions; skip the top-level build calls and loops.
_tree.body = [n for n in _tree.body if isinstance(n, (ast.Import, ast.ImportFrom, ast.Assign, ast.FunctionDef))]
exec(compile(_tree, _src_path, "exec"), globals())
os.makedirs(OUT, exist_ok=True)

PALETTE.update({
    "kamo_gron": "55663f", "kamo_mork": "36442c", "kamo_brun": "6e5b3c", "kamo_svart": "2b2e27",
    "band": "2c2d2b", "hjul_mork": "3d413d", "betong": "aeaca5", "betong_mork": "84827c", "stal": "7b838b",
    "stal_mork": "4d545b", "varning_gul": "e9c32b", "sand": "bfa877", "sand_mork": "a38f62", "militar_gron": "5a6b48",
    "plat_gron": "65774f", "zombie_hud": "93b07a", "zombie_skjorta": "7c6d8c", "zombie_byxor": "3f4e63",
    "zombie_har": "3b342e", "zombie_oga": "ff6a3d", "alien_hud": "a5dcae", "alien_drakt": "56688c",
    "alien_oga": "0d1015", "plasma": "7dff9a", "pysare": "5d9a3d", "pysare_ljus": "82bf55", "pysare_mork": "3f6e2a",
    "pysare_oga": "ffd94a", "pysare_stubin": "ff4b2b", "ufo_metall": "c4ccd5", "ufo_mork": "7d8792",
    "ufo_ljus": "8ff0ff", "kupol": "9fd6e8", "radar_vit": "eceeea",
})
EMISSIVE.update({"zombie_oga": 2.5, "plasma": 4.0, "pysare_oga": 3.0, "pysare_stubin": 3.0, "ufo_ljus": 4.0})


def part(name, origin):
    """Join everything built since the last part into one named object with its origin at `origin`."""
    objs = [o for o in bpy.data.objects if o.type == "MESH" and not o.get("done")]
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    if len(objs) > 1:
        bpy.ops.object.join()
    o = bpy.context.object
    o.name = name
    o.data.name = name
    bpy.context.scene.cursor.location = origin
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
    bpy.ops.object.shade_flat()
    o["done"] = True
    o.select_set(False)


def export_parts(name):
    bpy.ops.object.select_all(action="DESELECT")
    for o in bpy.data.objects:
        o.select_set(o.type == "MESH")
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, name + ".glb"), export_format="GLB", use_selection=True)
    print("exporterad", name, [o.name for o in bpy.data.objects])
    clear()


def wheel_y(x, z, y, r, width, material):
    cyl(r, width, (x, y, z), material, verts=10, rot=(math.pi / 2, 0, 0))


# --- The tank -------------------------------------------------------------------------------------

def stridsvagn():
    """A green camouflaged tank, 6.6 m long. Parts: Skrov (hull and tracks), Torn (turret with the
    cyclist in the hatch, origin on the turret ring) and Kanon (barrel, origin at the trunnion)."""
    for side in (-1, 1):
        y = side * 1.36
        # Track run: a rounded loop seen from the side, wheels and guard over it.
        slab_y([(-2.75, 0.05), (2.75, 0.05), (3.3, 0.55), (3.15, 0.95), (-3.1, 0.95), (-3.35, 0.5)], 0.62, "band", y=y)
        for k in range(6):
            wheel_y(-2.25 + k * 0.9, 0.42, y + side * 0.33, 0.34, 0.08, "hjul_mork")
        wheel_y(2.95, 0.6, y + side * 0.33, 0.28, 0.08, "hjul_mork")
        wheel_y(-3.0, 0.55, y + side * 0.33, 0.3, 0.08, "hjul_mork")
        for k in range(26):
            box((0.1, 0.64, 0.05), (-2.6 + k * 0.205, y, 0.05), "kamo_svart")      # track shoes
        box((6.6, 0.7, 0.08), (0.0, y, 1.02), "kamo_gron")
        box((0.08, 0.7, 0.4), (3.27, y, 0.84), "kamo_gron", rot=(0, math.radians(-30), 0))
        for x in (-1.5, 0.6):
            box((1.1, 0.06, 0.32), (x, y + side * 0.36, 0.85), "kamo_mork")          # side skirts
    # Hull between the tracks with a sloping glacis, camouflage patches on the deck.
    slab_y([(-3.1, 0.5), (3.0, 0.5), (3.38, 1.02), (2.2, 1.72), (-3.0, 1.72), (-3.28, 1.15)], 2.1, "kamo_gron")
    box((4.6, 2.9, 0.1), (-0.5, 0, 1.72), "kamo_gron")
    for (x, y, sx, sy, m) in ((1.4, 0.7, 1.2, 0.8, "kamo_brun"), (-1.2, -0.6, 1.6, 0.9, "kamo_svart"),
                              (-2.4, 0.8, 0.9, 0.7, "kamo_brun"), (2.4, -0.5, 0.7, 0.9, "kamo_mork")):
        box((sx, sy, 0.04), (x, y, 1.78), m, rot=(0, 0, 0.3))
    for y in (-0.8, 0.8):
        box((0.22, 0.3, 0.18), (3.0, y, 1.22), "fonster")                           # headlights
        box((0.25, 0.12, 0.25), (-3.3, y, 0.95), "kamo_svart")                      # tow hooks
    for y in (-1.15, 1.15):
        box((0.5, 0.25, 0.45), (-2.7, y, 1.35), "kamo_mork")                        # jerry cans
    cyl(0.12, 0.6, (-3.15, 0.55, 1.5), "stal_mork", verts=8, rot=(0, math.pi / 2, 0))   # exhaust
    box((1.5, 1.2, 0.06), (-2.2, 0, 1.76), "stal_mork")                             # engine grille
    part("Skrov", (0, 0, 0))
    # Turret: angled sides, a bustle at the back, the cyclist in the commander's hatch.
    slab_y([(-2.05, 1.76), (1.45, 1.76), (1.8, 2.2), (1.3, 2.68), (-1.55, 2.68), (-2.15, 2.3)], 2.3, "kamo_gron")
    for (x, y, sx, sy, m) in ((0.4, 0.5, 1.0, 0.7, "kamo_brun"), (-1.1, -0.4, 0.9, 0.8, "kamo_svart")):
        box((sx, sy, 0.04), (x, y, 2.7), m, rot=(0, 0, -0.4))
    box((0.55, 0.95, 0.65), (1.75, 0, 2.22), "kamo_mork")                           # mantlet
    for side in (-1, 1):
        for k in range(3):
            cyl(0.07, 0.35, (0.6 + k * 0.18, side * 1.2, 2.45), "kamo_svart", verts=6,
                rot=(side * math.radians(-60), 0, 0))                                 # smoke dischargers
    box((0.9, 0.7, 0.08), (0.7, -0.5, 2.73), "kamo_mork")                          # gunner's hatch
    ring((-0.4, 0.45, 2.74), 0.42, 0.07, "kamo_mork", axis="z")
    tube((-1.6, -0.8, 2.68), (-1.75, -0.85, 4.6), 0.02, "svart", verts=4)            # antenna
    # The cyclist pokes out of the hatch: blue jersey with the yellow cross, white helmet.
    taper((-0.4, 0.45, 2.55), (-0.4, 0.45, 3.3), 0.24, 0.2, "trika", verts=8)
    box((0.05, 0.12, 0.7), (-0.18, 0.45, 2.95), "flagga_gul")
    box((0.05, 0.42, 0.1), (-0.18, 0.45, 3.06), "flagga_gul")
    blob(0.14, (-0.38, 0.45, 3.5), "hud", scale=(1, 0.95, 1.1), jitter=0.0, subdiv=2)
    blob(0.165, (-0.4, 0.45, 3.6), "hjalm", scale=(1.2, 1.0, 0.75), jitter=0.0, subdiv=2)
    box((0.06, 0.24, 0.06), (-0.25, 0.45, 3.52), "svart")                          # sunglasses
    for side in (-1, 1):
        y = 0.45 + side * 0.26
        tube((-0.4, y, 3.2), (-0.1, y + side * 0.1, 2.85), 0.06, "trika", verts=6)
        tube((-0.1, y + side * 0.1, 2.85), (0.05, y + side * 0.1, 2.76), 0.05, "svart", verts=6)
    part("Torn", (-0.1, 0, 1.76))
    # Barrel with a thermal sleeve, fume extractor and muzzle brake.
    tube((1.95, 0, 2.22), (5.6, 0, 2.22), 0.1, "kamo_mork", verts=8)
    tube((2.0, 0, 2.22), (3.3, 0, 2.22), 0.135, "kamo_gron", verts=8)
    tube((3.8, 0, 2.22), (4.3, 0, 2.22), 0.15, "kamo_gron", verts=8)
    box((0.32, 0.3, 0.26), (5.7, 0, 2.22), "stal_mork")
    part("Kanon", (1.75, 0, 2.22))
    export_parts("stridsvagn")


# --- Monsters -------------------------------------------------------------------------------------

def zombie():
    """A shambling zombie, 1.75 m, arms out in front. Parts with origins at the joints: Kropp (hips),
    ArmV/ArmH (shoulders, arms along +X) and BenV/BenH (hips, legs hanging down)."""
    taper((0, 0, 0.95), (0.08, 0, 1.5), 0.2, 0.25, "zombie_skjorta", verts=7)       # hunched torso
    box((0.2, 0.42, 0.12), (0.06, 0, 0.98), "zombie_byxor")                         # belt line
    for (x, y, z) in ((0.22, 0.12, 1.15), (0.2, -0.1, 1.32), (0.18, 0.05, 1.42)):
        box((0.05, 0.12, 0.1), (x, y, z), "zombie_hud", rot=(0.5, 0, 0.3))           # rips in the shirt
    taper((0.08, 0, 1.5), (0.14, 0, 1.6), 0.08, 0.07, "zombie_hud", verts=6)
    blob(0.15, (0.2, 0.02, 1.72), "zombie_hud", scale=(1.0, 0.9, 1.15), jitter=0.08, subdiv=1, seed=3)
    blob(0.15, (0.16, 0.02, 1.8), "zombie_har", scale=(1.0, 0.95, 0.6), jitter=0.25, subdiv=1, seed=4)
    for y in (-0.06, 0.07):
        box((0.04, 0.05, 0.035), (0.34, y + 0.02, 1.74), "zombie_oga")
    box((0.04, 0.12, 0.03), (0.34, 0.02, 1.64), "svart")                             # mouth
    part("Kropp", (0, 0, 0.95))
    for side, name in ((1, "ArmV"), (-1, "ArmH")):
        y = side * 0.27
        tube((0.05, y, 1.45), (0.62, y + side * 0.02, 1.38), 0.055, "zombie_skjorta", verts=6)
        blob(0.06, (0.68, y + side * 0.02, 1.37), "zombie_hud", jitter=0.2, seed=side + 5)
        part(name, (0.05, y, 1.45))
    for side, name in ((1, "BenV"), (-1, "BenH")):
        y = side * 0.11
        taper((0, y, 0.95), (0.02, y, 0.08), 0.085, 0.065, "zombie_byxor", verts=6)
        box((0.26, 0.11, 0.08), (0.07, y, 0.04), "svart")
        part(name, (0, y, 0.95))
    export_parts("zombie")


def alien():
    """A little green alien on a hover disc, 1.4 m, with a big head, black eyes, antennae and a ray
    gun. Parts: Kropp (origin between the feet) and Skiva (the disc, origin at its centre)."""
    for y in (-0.08, 0.08):
        taper((0, y, 0.05), (0, y, 0.55), 0.05, 0.06, "alien_drakt", verts=6)
    taper((0, 0, 0.5), (0, 0, 0.95), 0.15, 0.12, "alien_drakt", verts=7)
    box((0.02, 0.18, 0.12), (0.13, 0, 0.82), "plasma")                               # chest light
    taper((0, 0, 0.95), (0, 0, 1.03), 0.04, 0.035, "alien_hud", verts=6)
    blob(0.22, (0.02, 0, 1.22), "alien_hud", scale=(1.0, 1.05, 1.15), jitter=0.0, subdiv=2)
    for y in (-0.085, 0.085):
        blob(0.06, (0.19, y, 1.22), "alien_oga", scale=(0.5, 1.0, 1.4), jitter=0.0, subdiv=1)
        tube((0, y * 0.6, 1.4), (-0.04, y * 1.8, 1.62), 0.012, "alien_hud", verts=4)
        dot((-0.04, y * 1.8, 1.64), 0.03, "plasma")
    tube((0.0, 0.14, 0.9), (0.12, 0.2, 0.62), 0.03, "alien_drakt", verts=5)          # left arm hangs
    tube((0.0, -0.14, 0.9), (0.28, -0.16, 0.8), 0.03, "alien_drakt", verts=5)        # right arm aims
    box((0.3, 0.06, 0.08), (0.4, -0.16, 0.8), "ufo_mork")                           # ray gun
    box((0.08, 0.05, 0.12), (0.32, -0.16, 0.73), "ufo_mork")
    dot((0.57, -0.16, 0.8), 0.04, "plasma")
    part("Kropp", (0, 0, 0))
    cyl(0.4, 0.06, (0, 0, 0.0), "ufo_metall", verts=10, radius_top=0.34)
    cyl(0.18, 0.08, (0, 0, -0.06), "ufo_ljus", verts=8)
    for k in range(6):
        a = k / 6 * math.tau
        dot((0.37 * math.cos(a), 0.37 * math.sin(a), 0.0), 0.03, "ufo_ljus")
    part("Skiva", (0, 0, 0))
    export_parts("alien")


def pysare():
    """The Pysare: a round mossy creature about 1.1 m across that rolls up, hisses and goes off.
    Glowing yellow eyes, a grumpy mouth, stubby feet and a twig fuse with a burning tip. Front +X."""
    blob(0.55, (0, 0, 0.62), "pysare", scale=(1.0, 1.0, 0.9), jitter=0.12, subdiv=2, seed=1)
    rnd = random.Random(8)
    for k in range(14):
        a = rnd.uniform(0, math.tau)
        e = rnd.uniform(-0.2, 1.1)
        p = Vector((math.cos(a) * math.cos(e), math.sin(a) * math.cos(e), math.sin(e))) * 0.5
        blob(0.13, (p.x, p.y, 0.62 + p.z * 0.9), "pysare_ljus" if k % 3 else "pysare_mork",
             jitter=0.3, subdiv=1, seed=k + 10)
    for y in (-0.17, 0.17):
        blob(0.085, (0.47, y, 0.74), "pysare_oga", scale=(0.45, 1.0, 0.75), jitter=0.0, subdiv=1)
        box((0.05, 0.16, 0.04), (0.5, y * 1.05, 0.84), "pysare_mork", rot=(y * 2.5, 0, 0))   # angry brows
    box((0.06, 0.34, 0.05), (0.5, 0, 0.5), "svart", rot=(0, 0, 0))
    for y in (-0.22, 0.22):
        blob(0.13, (0.06, y, 0.1), "pysare_mork", scale=(1.4, 1.0, 0.6), jitter=0.1, seed=int(y * 100))
    taper((-0.05, 0, 1.1), (-0.12, 0.04, 1.42), 0.035, 0.02, "tra_mork", verts=5)
    dot((-0.13, 0.045, 1.46), 0.05, "pysare_stubin")
    export("pysare", bevel=0.0)


def ufo():
    """A flying saucer 12 m across with a glass dome, a ring of lights and a glowing beam ring."""
    cyl(6.0, 0.9, (0, 0, 0), "ufo_metall", verts=16, radius_top=4.2)
    cyl(6.0, 0.7, (0, 0, -0.8), "ufo_mork", verts=16, radius_top=6.0)
    cyl(2.4, 0.7, (0, 0, -1.4), "ufo_metall", verts=16, radius_top=5.4)
    cyl(1.5, 0.12, (0, 0, -1.8), "ufo_ljus", verts=12)
    blob(2.6, (0, 0, 0.6), "kupol", scale=(1.0, 1.0, 0.65), jitter=0.0, subdiv=2)
    for k in range(16):
        a = k / 16 * math.tau
        dot((6.05 * math.cos(a), 6.05 * math.sin(a), -0.8), 0.18, "ufo_ljus")
    for k in range(3):
        a = k / 3 * math.tau
        cyl(0.5, 0.5, (3.2 * math.cos(a), 3.2 * math.sin(a), -1.7), "ufo_mork", verts=8, radius_top=0.3)
    export("ufo", bevel=0.0)


# --- The base -------------------------------------------------------------------------------------

def bergrum():
    """The entrance to the rock shelter: a concrete portal with blast doors, one ajar with light
    inside, set into a granite knoll about 30 m across. Origin at the portal floor, doors facing +X."""
    rnd = random.Random(21)
    for k in range(9):
        x = rnd.uniform(-14.0, -4.0)
        y = rnd.uniform(-12.0, 12.0)
        r = rnd.uniform(5.0, 8.0)
        blob(r, (x, y, rnd.uniform(-1.5, 2.5)), "granit" if k % 3 else "granit_mork",
             scale=(1.1, 1.0, 0.75), jitter=0.22, subdiv=1, seed=k + 30)
    blob(9.0, (-9.0, 0.0, 1.0), "granit", scale=(1.0, 1.25, 0.8), jitter=0.18, subdiv=2, seed=40)
    for y in (-5.3, 5.3):
        box((3.2, 1.2, 7.4), (-0.6, y, 3.1), "betong")                              # portal piers
    box((3.2, 11.8, 1.4), (-0.6, 0, 7.1), "betong")                                 # lintel
    box((0.2, 9.4, 0.5), (1.0, 0, 6.2), "betong_mork")
    for k in range(9):
        box((0.12, 0.45, 0.9), (1.02, -4.0 + k * 1.0, 6.2), "varning_gul" if k % 2 else "svart",
            rot=(0.6, 0, 0))                                                          # hazard stripes
    box((0.5, 4.4, 5.9), (-0.9, -2.35, 2.95), "stal")                               # left door, shut
    box((0.5, 4.4, 5.9), (-0.3, 2.7, 2.95), "stal", rot=(0, 0, math.radians(-14)))    # right door, ajar
    for y in (-3.8, -2.35, -0.9):
        box((0.56, 0.12, 5.6), (-0.9, y, 2.95), "stal_mork")
    box((0.2, 8.8, 5.9), (-2.2, 0, 2.95), "svart")                                  # dark inside
    box((0.25, 1.4, 5.0), (-1.9, 0.9, 2.7), "fonster")                              # light through the gap
    box((0.4, 0.6, 0.3), (1.0, 0, 7.95), "stal_mork")
    box((0.2, 0.5, 0.15), (1.1, 0, 7.8), "fonster")                                 # lamp
    box((0.08, 1.6, 0.9), (1.05, -5.3, 4.6), "varning_gul")                         # sign plate (text in Godot)
    box((4.0, 12.8, 0.25), (1.2, 0, 0.12), "betong_mork")                           # apron
    for y in (-3.0, 3.0):
        cyl(0.45, 2.6, (-8.0, y, 9.0), "stal", verts=8)                             # ventilation shafts
        cyl(0.6, 0.3, (-8.0, y, 10.4), "stal_mork", verts=8)
    export("bergrum", bevel=0.03)


def hangar():
    """An arched corrugated hangar 18 m long, its big door at +X. Origin at floor centre."""
    cyl(6.2, 18.0, (0, 0, 0), "kamo_gron", verts=14, rot=(0, math.pi / 2, 0))
    for k in range(7):
        ring((-8.4 + k * 2.8, 0, 0), 6.25, 0.08, "kamo_mork", axis="x", segments=14)
    box((0.3, 8.2, 5.2), (9.05, 0, 2.6), "stal_mork")
    for y in (-2.05, 0.0, 2.05):
        box((0.36, 0.12, 5.0), (9.1, y, 2.5), "stal")
    box((0.4, 9.2, 0.5), (9.1, 0, 5.4), "kamo_mork")
    box((0.4, 0.5, 0.3), (9.12, 0, 6.0), "fonster")
    for (x, y, sx, sy, m) in ((2.0, 4.5, 4.0, 1.5, "kamo_brun"), (-4.0, -4.3, 3.5, 1.6, "kamo_svart"),
                              (-1.0, 0.0, 3.0, 2.5, "kamo_brun")):
        box((sx, sy, 0.08), (x, y, 6.15 if abs(y) < 1 else 4.6), m,
            rot=(math.copysign(0.75, y) if abs(y) > 1 else 0, 0, 0))
    export("hangar", bevel=0.02)


def barack():
    """A green wooden barracks block with a sheet roof, windows and a door on the -Y side."""
    box((14.4, 6.4, 0.5), (0, 0, 0.1), "grund")
    gable_house(14.0, 6.0, 2.7, 1.3, "militar_gron", "takgra", trim=False)
    for x in (-5.0, -2.5, 2.5, 5.0):
        window(x, -3.0, 1.6, -1, w=1.0, h=0.9)
    box((1.0, 0.1, 2.0), (0.0, -3.04, 1.25), "dorr")
    box((1.8, 1.0, 0.3), (0.0, -3.5, 0.15), "betong_mork")
    box((0.4, 0.3, 0.25), (0.0, -3.1, 2.45), "fonster")
    export("barack", bevel=0.02)


def radar():
    """A lattice radar tower 11 m high. Parts: Torn (tower) and Antenn (the dish, origin on the
    turning post, which the game spins)."""
    for (x, y) in ((-1.6, -1.6), (1.6, -1.6), (1.6, 1.6), (-1.6, 1.6)):
        tube((x, y, 0), (x * 0.4, y * 0.4, 10.0), 0.09, "stal", verts=5)
    for k in range(5):
        z0, z1 = k * 2.0, k * 2.0 + 2.0
        s0, s1 = 1.6 - k * 0.19, 1.6 - (k + 1) * 0.19
        for (a, b) in (((-1, -1), (1, -1)), ((1, -1), (1, 1)), ((1, 1), (-1, 1)), ((-1, 1), (-1, -1))):
            tube((a[0] * s0, a[1] * s0, z0), (b[0] * s1, b[1] * s1, z1), 0.04, "stal", verts=4)
    box((2.2, 2.2, 0.25), (0, 0, 10.05), "stal_mork")
    for (x, y) in ((-1.05, 0), (1.05, 0)):
        box((0.05, 2.2, 0.7), (x, y, 10.5), "stal")
    part("Torn", (0, 0, 0))
    cyl(0.18, 1.0, (0, 0, 10.7), "stal_mork", verts=8)
    box((0.3, 4.6, 1.8), (0.25, 0, 11.6), "radar_vit", rot=(0, math.radians(-15), 0))
    for z in (11.0, 11.6, 12.2):
        box((0.36, 4.7, 0.08), (0.27, 0, z), "stal", rot=(0, math.radians(-15), 0))
    tube((0.3, 0, 11.6), (1.4, 0, 11.7), 0.04, "stal_mork", verts=4)
    part("Antenn", (0, 0, 10.7))
    export_parts("radar")


def vakttorn():
    """A wooden watchtower with a cabin 5 m up, a sheet roof and a ladder on the +X side."""
    for (x, y) in ((-1.3, -1.3), (1.3, -1.3), (1.3, 1.3), (-1.3, 1.3)):
        tube((x * 1.2, y * 1.2, 0), (x, y, 5.0), 0.12, "tra_mork", verts=5)
    for z in (1.6, 3.3):
        for (a, b) in (((-1, -1), (1, 1)), ((1, -1), (-1, 1))):
            tube((a[0] * 1.45, a[1] * 1.45, z - 1.3), (b[0] * 1.35, b[1] * 1.35, z + 0.4), 0.06, "tra_mork", verts=4)
    box((3.2, 3.2, 0.2), (0, 0, 5.0), "tra")
    for side in (-1, 1):
        box((3.2, 0.1, 1.1), (0, side * 1.55, 5.65), "militar_gron")
        box((0.1, 3.2, 1.1), (side * 1.55, 0, 5.65), "militar_gron")
    for (x, y) in ((-1.5, -1.5), (1.5, -1.5), (1.5, 1.5), (-1.5, 1.5)):
        box((0.12, 0.12, 2.3), (x, y, 6.2), "tra_mork")
    cyl(2.6, 1.0, (0, 0, 7.85), "takgra", verts=4, radius_top=0.0, rot=(0, 0, math.pi / 4))   # on the posts
    for side in (-0.35, 0.35):
        tube((1.75, side, 0), (1.62, side, 5.0), 0.04, "tra", verts=4)
    for k in range(12):
        box((0.06, 0.75, 0.05), (1.74 - k * 0.011, 0, 0.35 + k * 0.4), "tra")
    export("vakttorn", bevel=0.0)


def bom():
    """A red and white barrier arm across the track (along +Y) on a post with a counterweight."""
    box((0.3, 0.3, 1.1), (0, 0, 0.55), "stal")
    box((0.5, 0.6, 0.4), (0, -0.42, 1.05), "betong_mork")
    for k in range(8):
        box((0.12, 0.75, 0.12), (0, 0.45 + k * 0.75, 1.05), "skylt_rod" if k % 2 == 0 else "vit")
    box((0.25, 0.25, 0.9), (0, 6.3, 0.45), "stal")
    export("bom", bevel=0.0)


def skylt_skydd():
    """A big yellow warning board on two posts (the text is added in Godot), facing +X."""
    for y in (-0.6, 0.6):
        box((0.08, 0.08, 2.2), (0, y, 1.1), "stal")
    box((0.06, 1.6, 1.05), (0.04, 0, 1.75), "varning_gul")
    box((0.065, 1.66, 0.05), (0.04, 0, 2.28), "svart")
    box((0.065, 1.66, 0.05), (0.04, 0, 1.22), "svart")
    export("skylt_skydd", bevel=0.0)


def stangsel():
    """A 3 m fence panel along +X: steel posts, a coarse wire mesh and barbed wire on top."""
    for x in (0.0, 3.0):
        cyl(0.05, 2.4, (x, 0, 1.2), "stal", verts=5)
        tube((x, 0, 2.3), (x, 0.3, 2.7), 0.03, "stal", verts=4)
    for k in range(1, 10):
        box((0.02, 0.02, 2.2), (k * 0.3, 0, 1.12), "stal_mork")
    for z in (0.08, 0.6, 1.15, 1.7, 2.2):
        box((3.0, 0.02, 0.02), (1.5, 0, z), "stal_mork")
    for k in range(3):
        box((3.0, 0.015, 0.015), (1.5, 0.1 + k * 0.1, 2.4 + k * 0.1), "stal")
    export("stangsel", bevel=0.0)


def lastbil():
    """A green military truck with a camouflage canvas over the load bed; front towards +X."""
    box((2.0, 2.3, 1.7), (2.3, 0, 1.75), "kamo_gron")                               # cab
    box((1.0, 2.2, 0.9), (3.65, 0, 1.3), "kamo_gron")                               # bonnet
    box((0.1, 2.0, 0.75), (1.5, 0, 2.2), "glas_mork")
    box((0.06, 1.9, 0.7), (3.32, 0, 2.15), "glas_mork", rot=(0, math.radians(20), 0))
    box((4.6, 2.4, 0.3), (-1.2, 0, 1.05), "kamo_mork")
    prism([(-1.2, 1.2), (1.2, 1.2), (1.2, 2.7), (0.8, 3.1), (-0.8, 3.1), (-1.2, 2.7)], 4.5, "kamo_brun", x0=-1.2)
    for (x, y, sx) in ((-0.2, 1.21, 1.4), (-2.4, -1.21, 1.2)):
        box((sx, 0.02, 0.9), (x, y, 2.1), "kamo_svart")
    box((5.8, 1.2, 0.35), (0.6, 0, 0.75), "svart")                                 # chassis
    for x in (3.0, -0.7, -2.2):
        for y in (-1.05, 1.05):
            cyl(0.52, 0.38, (x, y, 0.52), "dack", verts=10, rot=(math.pi / 2, 0, 0))
            cyl(0.26, 0.4, (x, y, 0.52), "hjul_mork", verts=8, rot=(math.pi / 2, 0, 0))
    for y in (-0.8, 0.8):
        box((0.1, 0.25, 0.2), (4.17, y, 1.25), "fonster")
    export("lastbil", bevel=0.02)


def drivmedel():
    """Two fuel tanks on concrete saddles with a ladder and a hose pump."""
    for y in (-1.6, 1.6):
        cyl(1.25, 6.0, (0, y, 1.6), "militar_gron", verts=12, rot=(0, math.pi / 2, 0))
        for x in (-2.0, 2.0):
            box((0.5, 2.2, 0.8), (x, y, 0.4), "betong_mork")
    box((0.08, 0.6, 2.8), (3.1, 0, 1.4), "stal")
    box((0.8, 0.6, 1.2), (3.6, -1.0, 0.6), "skylt_rod")
    export("drivmedel", bevel=0.02)


def sandsackar():
    """A curved wall of sandbags, three courses high and about 5 m long."""
    rnd = random.Random(5)
    for row in range(3):
        n = 9 - row
        for k in range(n):
            a = ((k + 0.5 * row) / 8.0 - 0.5) * 1.2
            x, y = 4.0 * (math.cos(a) - 1.0), 4.0 * math.sin(a)
            box((0.62, 0.38, 0.25), (x, y, 0.14 + row * 0.24), "sand" if (k + row) % 3 else "sand_mork",
                rot=(0, 0, a + math.pi / 2 + rnd.uniform(-0.08, 0.08)))
    export("sandsackar", bevel=0.04)


def lador():
    """A stack of olive ammunition crates with yellow stencilled bands."""
    for (x, y, z, r) in ((0, 0, 0.25, 0.0), (1.0, 0.05, 0.25, 0.1), (0.45, 0.02, 0.75, -0.05), (0.0, 0.9, 0.25, 0.2)):
        box((0.95, 0.6, 0.5), (x, y, z), "militar_gron", rot=(0, 0, r))
        box((0.97, 0.62, 0.06), (x, y, z + 0.12), "varning_gul", rot=(0, 0, r))
    export("lador", bevel=0.02)


def helipad():
    """A concrete landing pad 16 m across with a white H and a ring."""
    box((16.0, 16.0, 0.3), (0, 0, 0.0), "betong")
    for y in (-2.0, 2.0):
        box((5.5, 0.9, 0.04), (0, y, 0.17), "vit")
    box((0.9, 3.2, 0.04), (0, 0, 0.17), "vit")
    for k in range(24):
        a = k / 24 * math.tau
        box((1.3, 0.4, 0.04), (6.2 * math.cos(a), 6.2 * math.sin(a), 0.17), "varning_gul",
            rot=(0, 0, a + math.pi / 2))
    export("helipad", bevel=0.0)


def kamonat():
    """A camouflage net, 9 × 7 m, draped over four poles: green, brown and black patches."""
    import bmesh
    bm = bmesh.new()
    nx, ny = 10, 8
    rnd = random.Random(3)
    verts = {}
    for i in range(nx + 1):
        for j in range(ny + 1):
            x = -4.5 + i * 0.9
            y = -3.5 + j * 0.875
            sag = 3.0 - 0.6 * (abs(x) / 4.5) ** 2 - 0.5 * (abs(y) / 3.5) ** 2 + rnd.uniform(-0.12, 0.12)
            if i in (0, nx) or j in (0, ny):
                sag = 1.4 + rnd.uniform(-0.2, 0.2)
            verts[(i, j)] = bm.verts.new((x, y, sag))
    names = ["kamo_gron", "kamo_mork", "kamo_brun", "kamo_svart"]
    me = bpy.data.meshes.new("nat")
    faces = []
    for i in range(nx):
        for j in range(ny):
            f = bm.faces.new((verts[(i, j)], verts[(i + 1, j)], verts[(i + 1, j + 1)], verts[(i, j + 1)]))
            f.material_index = rnd.randrange(4)
            faces.append(f)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new("nat", me)
    bpy.context.collection.objects.link(o)
    for n in names:
        o.data.materials.append(mat(n))
    mod = o.modifiers.new("tjocklek", "SOLIDIFY")
    mod.thickness = 0.05
    bpy.context.view_layer.objects.active = o
    o.select_set(True)
    bpy.ops.object.modifier_apply(modifier=mod.name)
    o.select_set(False)
    for (x, y) in ((-3.0, -2.2), (3.0, -2.2), (3.0, 2.2), (-3.0, 2.2)):
        tube((x, y, 0), (x * 1.0, y, 2.6), 0.05, "tra_mork", verts=4)
    export("kamonat", bevel=0.0)


bpy.ops.wm.read_factory_settings(use_empty=True)
only = sys.argv[sys.argv.index("--") + 2:] if "--" in sys.argv else []
for build in (stridsvagn, zombie, alien, pysare, ufo, bergrum, hangar, barack, radar, vakttorn, bom,
              skylt_skydd, stangsel, lastbil, drivmedel, sandsackar, lador, helipad, kamonat):
    if not only or build.__name__ in only:
        build()
print("MILITÄRA MODELLER KLARA")
