"""Skärgården's summer life: people at the water and the café, midsommar dancers, animals, boats on
the move, a tractor, a camp fire. Kept apart from skargarden_modeller.py (whose helpers it reads,
the same way egypten_modeller.py does) so the two scripts can be worked on at the same time.

    blender --background --python assets/blender/skargarden_liv.py -- game/world/skargarden/models [names …]

Blender Z-up, +X forward, low-poly with flat shading, named colours.
"""
import ast
import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
_src_path = os.path.join(HERE, "skargarden_modeller.py")
_tree = ast.parse(open(_src_path, encoding="utf-8").read())
_tree.body = [n for n in _tree.body if isinstance(n, (ast.Import, ast.ImportFrom, ast.Assign, ast.FunctionDef))]
exec(compile(_tree, _src_path, "exec"), globals())
os.makedirs(OUT, exist_ok=True)

PALETTE.update({
    "hud_sol": "e8b494", "klanning_vit": "f4f0e6", "klanning_bla": "6f9fd0", "klanning_rod": "d0504a",
    "jeans": "3f5a80", "shorts_kaki": "b8a47a", "folkdrakt_rod": "b23a2e", "folkdrakt_gul": "e2b84a",
    "vast_svart": "2a2a2a", "krans_gron": "5a8a3a", "krans_blom": "f0d040", "flytvast": "f07a20",
    "handduk_rod": "d84a4a", "handduk_bla": "3a7ac0", "sal_gra": "7a7f86", "sal_mork": "4a4f56", "svan_vit": "f6f4ee",
    "nabb_ora": "e8782a", "hast_brun": "7a4a2a", "man_svart": "2a2220", "rad_brun": "9a6a40", "rumpa_vit": "efe8dc",
    "talt_gron": "4f7a3a", "talt_ora": "e07a2a", "motorbat_vit": "f0eee8", "traktor_rod": "c0302a",
    "traktor_gra": "8a8f94", "hund_guld": "d8a050", "hangmatta": "e8d8a8", "glass": "f0e0c0", "glass_strut": "c8904a",
    "eld": "ffa53a", "eld_gul": "ffd34a", "keps_rod": "c8302e", "trojan_gron": "4f8a5a", "trojan_gul": "e8c040",
    "segel_vit": "f4f2ea", "jolle_vit": "f0f0ea", "halm": "c9a65a",
})
EMISSIVE.update({"eld": 4.0, "eld_gul": 4.5})


def manniska(x=0.0, y=0.0, z0=0.0, top="trika", legs="jeans", skin="hud_sol", hat=None, hat_col=None, pose="sides",
             h=1.75, seated=False, dress=None):
    """A person facing +X with the feet at z0: a top, trousers or bare legs with shorts (legs="bare"),
    or a dress to the knee; arms posed (sides, forward, wave, wide, lap, cup, rod); a hat (keps,
    solhatt, krans). Seated people sit on something 0.45 m high."""
    k = h / 1.75
    if seated:
        hip = z0 + 0.48 * k
        for side in (-1, 1):
            thigh = dress or (legs if legs != "bare" else "shorts_kaki")
            tube((x, y + side * 0.1 * k, hip), (x + 0.42 * k, y + side * 0.1 * k, hip), 0.085 * k, thigh, verts=6)
            shin = skin if legs == "bare" or dress else legs
            tube((x + 0.42 * k, y + side * 0.1 * k, hip), (x + 0.46 * k, y + side * 0.1 * k, z0 + 0.06 * k), 0.065 * k, shin, verts=6)
            box((0.2 * k, 0.09 * k, 0.06 * k), (x + 0.52 * k, y + side * 0.1 * k, z0 + 0.03 * k), "sko")
        taper((x, y, hip), (x, y, hip + 0.56 * k), 0.2 * k, 0.19 * k, dress or top, verts=8)
        shoulder = hip + 0.52 * k
    else:
        leg = skin if legs == "bare" or dress else legs
        for side in (-1, 1):
            tube((x, y + side * 0.09 * k, z0 + 0.05 * k), (x, y + side * 0.09 * k, z0 + 0.95 * k), 0.065 * k, leg, verts=6)
            box((0.22 * k, 0.09 * k, 0.07 * k), (x + 0.04 * k, y + side * 0.09 * k, z0 + 0.035 * k), "sko")
        if dress:
            taper((x, y, z0 + 0.45 * k), (x, y, z0 + 1.0 * k), 0.3 * k, 0.17 * k, dress, verts=10)
        elif legs == "bare":
            taper((x, y, z0 + 0.62 * k), (x, y, z0 + 0.98 * k), 0.19 * k, 0.18 * k, "shorts_kaki", verts=8)
        taper((x, y, z0 + 0.92 * k), (x, y, z0 + 1.46 * k), 0.19 * k, 0.2 * k, dress or top, verts=8)
        shoulder = z0 + 1.41 * k
    hands = {"sides": ((0.04, -0.26, -0.45), (0.04, 0.26, -0.45)), "forward": ((0.42, -0.2, -0.3), (0.42, 0.2, -0.3)),
             "wave": ((0.04, -0.26, -0.45), (0.06, 0.34, 0.45)), "wide": ((0.05, -0.62, -0.12), (0.05, 0.62, -0.12)),
             "lap": ((0.3, -0.12, -0.3), (0.3, 0.12, -0.3)), "cup": ((0.3, -0.14, -0.3), (0.2, 0.1, 0.06)),
             "rod": ((0.38, -0.08, -0.22), (0.32, 0.08, -0.18))}[pose]
    blob(0.2 * k, (x, y, shoulder + 0.02 * k), dress or top, scale=(0.75, 1.15, 0.4), jitter=0.0)  # shoulders
    for side, hand in zip((-1, 1), hands):
        a = (x, y + side * 0.17 * k, shoulder)
        b = (x + hand[0] * k, y + hand[1] * k, shoulder + hand[2] * k)
        tube(a, b, 0.05 * k, dress or top, verts=5)
        blob(0.05 * k, b, skin, jitter=0.0)
    hz = shoulder + 0.2 * k
    tube((x, y, shoulder), (x, y, hz - 0.04 * k), 0.05 * k, skin, verts=5)
    blob(0.11 * k, (x + 0.01 * k, y, hz + 0.05 * k), skin, scale=(1.0, 0.92, 1.08), jitter=0.0, subdiv=2)
    dot((x + 0.115 * k, y, hz + 0.04 * k), 0.022 * k, skin)                                          # nose
    for side in (-1, 1):
        dot((x + 0.105 * k, y + side * 0.04 * k, hz + 0.075 * k), 0.013 * k, "svart")             # eyes
    blob(0.115 * k, (x - 0.02 * k, y, hz + 0.09 * k), "man_svart" if hat != "krans" else "krans_blom",
         scale=(1.0, 1.0, 0.7), jitter=0.0)                                                          # hair
    if hat == "keps":
        cyl(0.115 * k, 0.08 * k, (x, y, hz + 0.14 * k), hat_col or "keps_rod", verts=10)
        box((0.14 * k, 0.18 * k, 0.02 * k), (x + 0.15 * k, y, hz + 0.11 * k), hat_col or "keps_rod")
    elif hat == "solhatt":
        cyl(0.24 * k, 0.03 * k, (x, y, hz + 0.12 * k), hat_col or "halm", verts=12)
        cyl(0.11 * k, 0.11 * k, (x, y, hz + 0.18 * k), hat_col or "halm", verts=10)
    elif hat == "krans":
        bpy.ops.mesh.primitive_torus_add(major_radius=0.12 * k, minor_radius=0.03 * k, major_segments=10, minor_segments=4,
                                         location=(x, y, hz + 0.13 * k))
        _finish(bpy.context.object, "krans_gron")
        for n in range(8):
            a = n / 8 * math.tau
            dot((x + math.cos(a) * 0.12 * k, y + math.sin(a) * 0.12 * k, hz + 0.16 * k), 0.025 * k,
                "krans_blom" if n % 2 else "klanning_vit")
    return hz


def fiskare_brygga():
    """A man sitting on the edge of a jetty with his legs over the water, fishing with a rod, a bucket
    beside him; faces +X (out over the water). The seat is at 0 (the jetty's deck)."""
    manniska(-0.3, 0, -0.45, top="jacka", legs="jeans", hat="keps", hat_col="trojan_gron", pose="rod", seated=True)
    tube((0.05, 0.0, 0.75), (2.6, 0.0, 2.0), 0.015, "svart", verts=3)
    tube((2.6, 0.0, 2.0), (2.75, 0.0, -0.5), 0.004, "svart", verts=3)
    cyl(0.14, 0.28, (-0.4, 0.45, 0.14), "metall", verts=8)
    box((0.3, 0.2, 0.15), (-0.5, -0.4, 0.08), "tra_mork")
    export("fiskare_brygga", bevel=0.0)


def badare():
    """A swimmer doing breaststroke: head, shoulders and arms just above the water line (0)."""
    blob(1.0, (0, 0, -0.08), "hud_sol", scale=(0.32, 0.2, 0.1), jitter=0.0)
    blob(0.11, (0.3, 0, 0.06), "hud_sol", jitter=0.0)
    blob(0.12, (0.28, 0, 0.12), "klanning_rod", scale=(1.0, 1.0, 0.6), jitter=0.0)                  # bathing cap
    blob(0.13, (0.16, 0, -0.02), "hud_sol", scale=(0.8, 1.5, 0.5), jitter=0.0)                     # shoulders
    for side in (-1, 1):
        tube((0.14, side * 0.14, -0.03), (0.55, side * 0.35, -0.02), 0.045, "hud_sol", verts=5)
        blob(0.05, (0.58, side * 0.36, -0.02), "hud_sol", scale=(1.3, 1.0, 0.6), jitter=0.0)
    export("badare", bevel=0.0)


def solbadare():
    """Someone sunbathing on a striped towel, lying on the back with a hat over the face and a
    book beside; lies along X with the head at +X. Ground at 0."""
    box((1.9, 0.8, 0.02), (0, 0, 0.01), "handduk_bla")
    for n in range(4):
        box((0.18, 0.81, 0.021), (-0.7 + n * 0.45, 0, 0.012), "klanning_vit")
    taper((-0.1, 0, 0.12), (0.42, 0, 0.13), 0.15, 0.18, "hud_sol", verts=8)                         # torso
    blob(0.18, (0.38, 0, 0.13), "hud_sol", scale=(0.6, 1.15, 0.55), jitter=0.0)                       # shoulders
    blob(0.15, (-0.12, 0, 0.12), "klanning_rod", scale=(0.9, 1.1, 0.8), jitter=0.0)                  # swimwear
    box((0.16, 0.3, 0.1), (0.25, 0, 0.17), "klanning_rod")
    for side in (-1, 1):
        tube((-0.18, side * 0.09, 0.1), (-0.95, side * 0.12, 0.07), 0.065, "hud_sol", verts=6)        # legs
        blob(0.05, (-0.99, side * 0.12, 0.09), "hud_sol", scale=(0.8, 1.0, 1.4), jitter=0.0)          # feet
        tube((0.38, side * 0.17, 0.12), (0.08, side * 0.3, 0.06), 0.048, "hud_sol", verts=6)         # arms
        blob(0.045, (0.04, side * 0.31, 0.06), "hud_sol", jitter=0.0)
    tube((0.45, 0, 0.13), (0.58, 0, 0.13), 0.05, "hud_sol", verts=6)                                  # neck
    blob(0.11, (0.64, 0, 0.13), "hud_sol", jitter=0.0, subdiv=2)
    blob(0.115, (0.67, 0, 0.13), "man_svart", scale=(0.8, 1.0, 1.0), jitter=0.0)
    cyl(0.22, 0.04, (0.64, 0, 0.26), "halm", verts=12)                                               # hat over
    cyl(0.11, 0.08, (0.64, 0, 0.3), "halm", verts=10)                                                # the face
    box((0.2, 0.15, 0.04), (0.5, 0.5, 0.03), "handduk_rod")
    export("solbadare", bevel=0.0)


def jolle():
    """An Optimist dinghy: a short pram hull, a sprit sail, and a child in an orange life jacket at
    the tiller; faces +X."""
    hull(2.3, 1.15, 0.4, "jolle_vit", stripe="handduk_bla")
    tube((0.6, 0, 0.0), (0.6, 0, 2.4), 0.03, "metall", verts=4)
    slab_y([(0.65, 0.35), (1.2, 2.3), (-0.3, 2.0), (-0.3, 0.4)], 0.02, "segel_vit", y=0.04)
    tube((0.6, 0, 0.4), (-0.4, 0, 0.45), 0.02, "metall", verts=3)
    manniska(-0.5, 0, -0.25, top="flytvast", legs="bare", hat="keps", pose="lap", seated=True, h=1.3)
    export("jolle", bevel=0.0)


def fikagast(name, seat):
    """Someone at a café table: a woman in a summer dress with a coffee cup, or a man in a cap with
    a newspaper. Seated on a chair (built in) facing +X."""
    box((0.42, 0.42, 0.05), (-0.05, 0, 0.45), "tra")
    for x in (-0.22, 0.12):
        for y in (-0.18, 0.18):
            tube((x, y, 0.0), (x, y, 0.45), 0.02, "tra_mork", verts=3)
    box((0.05, 0.42, 0.45), (-0.27, 0, 0.7), "tra")
    if seat == 1:
        manniska(0.0, 0, 0.0, dress="klanning_bla", hat="solhatt", pose="cup", seated=True, h=1.68)
        cyl(0.04, 0.08, (0.2, 0.1, 1.1), "vit", verts=6)
    else:
        manniska(0.0, 0, 0.0, top="trojan_gul", legs="jeans", hat="keps", pose="lap", seated=True)
        box((0.02, 0.5, 0.35), (0.34, 0, 0.8), "vit", rot=(0, -0.4, 0))                              # newspaper
    export(name, bevel=0.0)


def dansare(name, female):
    """A midsommar dancer, arms out to hold the next in the ring: a white dress and a flower wreath,
    or a folk costume with a red vest and yellow knee breeches; faces +X (towards the pole)."""
    if female:
        manniska(dress="klanning_vit", hat="krans", pose="wide", h=1.68)
    else:
        manniska(top="vit", legs="folkdrakt_gul", pose="wide")
        taper((0.0, 0, 0.98), (0.0, 0, 1.4), 0.205, 0.21, "folkdrakt_rod", verts=8)                 # vest
        for side in (-1, 1):
            box((0.05, 0.08, 0.3), (0.0, side * 0.09, 0.32), "klanning_vit")                       # stockings
    export(name, bevel=0.0)


def sal():
    """A grey seal hauled out on a rock, head and hind flippers raised; faces +X."""
    blob(1.0, (0.05, 0, 0.25), "sal_gra", scale=(0.7, 0.3, 0.25), jitter=0.03, subdiv=2, seed=2)  # body
    taper((-0.45, 0, 0.24), (-0.85, 0, 0.3), 0.2, 0.07, "sal_gra", verts=8)                       # tail end
    taper((0.5, 0, 0.32), (0.7, 0, 0.44), 0.17, 0.13, "sal_gra", verts=8)                          # neck
    blob(0.17, (0.75, 0, 0.47), "sal_gra", scale=(1.3, 0.9, 0.85), jitter=0.0, subdiv=2)             # head
    blob(0.07, (0.92, 0, 0.44), "sal_mork", scale=(1.0, 1.1, 0.8), jitter=0.0)                       # muzzle
    for side in (-1, 1):
        dot((0.85, side * 0.07, 0.53), 0.025, "svart")                                               # eyes
        box((0.26, 0.1, 0.04), (0.33, side * 0.32, 0.08), "sal_mork", rot=(0, 0.3, side * 0.5))      # flippers
        box((0.3, 0.14, 0.04), (-0.96, side * 0.08, 0.34), "sal_mork", rot=(0, -0.3, side * 0.35))   # hind
    rnd = random.Random(3)
    for n in range(8):
        sx = rnd.uniform(-0.5, 0.55)
        sy = rnd.uniform(-0.15, 0.15)
        top = 0.25 + 0.25 * math.sqrt(max(0.0, 1.0 - (sx - 0.05) ** 2 / 0.49 - sy ** 2 / 0.09))
        dot((sx, sy, top), 0.035, "sal_mork")
    export("sal", bevel=0.0)


def svan():
    """A mute swan gliding: white body, an S-curved neck and an orange bill; faces +X. Water at 0."""
    blob(1.0, (0, 0, 0.12), "svan_vit", scale=(0.5, 0.25, 0.2), jitter=0.0)
    blob(0.5, (-0.15, 0, 0.25), "svan_vit", scale=(0.5, 0.45, 0.25), jitter=0.0)                     # raised wings
    tube((0.35, 0, 0.2), (0.42, 0, 0.55), 0.05, "svan_vit", verts=5)
    tube((0.42, 0, 0.55), (0.36, 0, 0.78), 0.045, "svan_vit", verts=5)
    blob(0.07, (0.4, 0, 0.8), "svan_vit", scale=(1.3, 0.8, 0.8), jitter=0.0)
    tube((0.47, 0, 0.79), (0.58, 0, 0.74), 0.025, "nabb_ora", verts=4)
    dot((0.47, 0, 0.82), 0.025, "svart")
    tube((-0.4, 0, 0.17), (-0.6, 0, 0.28), 0.04, "svan_vit", verts=4)
    export("svan", bevel=0.0)


def hast():
    """A brown horse with a black mane and tail, standing; faces +X."""
    blob(1.0, (0, 0, 1.25), "hast_brun", scale=(0.85, 0.33, 0.38), jitter=0.03, seed=1)
    for x in (-0.55, 0.55):
        for y in (-0.17, 0.17):
            tube((x, y, 1.05), (x + 0.03, y, 0.08), 0.07, "hast_brun", verts=5)
            box((0.14, 0.12, 0.1), (x + 0.04, y, 0.05), "man_svart")
    tube((0.7, 0, 1.4), (1.0, 0, 1.95), 0.16, "hast_brun", verts=6)
    blob(0.3, (1.15, 0, 1.95), "hast_brun", scale=(1.3, 0.55, 0.55), jitter=0.0)
    blob(0.1, (1.45, 0, 1.85), "man_svart", jitter=0.0)
    for y in (-0.07, 0.07):
        cone(0.04, 0.14, (1.02, y, 2.14), "hast_brun")
    box((0.6, 0.08, 0.22), (0.85, 0, 1.85), "man_svart", rot=(0, -1.05, 0))                          # mane
    tube((-0.62, 0, 1.4), (-1.0, 0, 0.75), 0.07, "man_svart", verts=4)                               # tail
    export("hast", bevel=0.0)


def radjur():
    """A roe deer standing alert: slim legs, a white rump patch, short antlers; faces +X."""
    blob(1.0, (0, 0, 0.75), "rad_brun", scale=(0.5, 0.18, 0.22), jitter=0.03, seed=3)
    blob(0.15, (-0.45, 0, 0.78), "rumpa_vit", scale=(0.6, 1.0, 1.1), jitter=0.0)
    for x in (-0.32, 0.32):
        for y in (-0.08, 0.08):
            tube((x, y, 0.62), (x, y, 0.0), 0.03, "rad_brun", verts=4)
    tube((0.4, 0, 0.85), (0.55, 0, 1.15), 0.07, "rad_brun", verts=5)
    blob(0.1, (0.65, 0, 1.17), "rad_brun", scale=(1.5, 0.8, 0.8), jitter=0.0)
    dot((0.8, 0, 1.13), 0.03, "svart")
    for y in (-0.05, 0.05):
        cone(0.035, 0.12, (0.58, y * 1.6, 1.3), "rad_brun")
        tube((0.62, y, 1.25), (0.6, y * 1.4, 1.45), 0.012, "tra_mork", verts=3)
    export("radjur", bevel=0.0)


def lagereld():
    """A camp fire in a ring of stones, logs leaning into a cone, flames glowing, and a log to sit
    on beside it."""
    rnd = random.Random(7)
    for n in range(9):
        a = n / 9 * math.tau
        blob(0.13, (math.cos(a) * 0.55, math.sin(a) * 0.55, 0.06), "grund", scale=(1.2, 1.0, 0.7), jitter=0.2, seed=n)
    for n in range(6):
        a = n / 6 * math.tau + 0.3
        tube((math.cos(a) * 0.4, math.sin(a) * 0.4, 0.0), (0.0, 0.0, 0.55), 0.045, "tra_mork", verts=4)
    blob(0.22, (0, 0, 0.28), "eld", scale=(1.0, 1.0, 1.6), jitter=0.3, seed=2)
    blob(0.12, (0.02, 0.02, 0.55), "eld_gul", scale=(1.0, 1.0, 1.8), jitter=0.3, seed=3)
    tube((-0.6, 1.3, 0.2), (0.7, 1.4, 0.2), 0.18, "tra", verts=7)
    tube((-1.4, -0.4, 0.2), (-1.3, 0.8, 0.2), 0.18, "tra", verts=7)
    export("lagereld", bevel=0.0)


def talt():
    """A green dome tent with an orange fly, the door rolled up and a sleeping mat sticking out;
    the door faces +X."""
    bm_r = 1.1
    blob(1.0, (0, 0, 0.0), "talt_gron", scale=(1.3, bm_r, 1.05), jitter=0.0, subdiv=2)
    box((3.0, 2.6, 0.1), (0, 0, -0.06), "grund")                     # under the floor (hidden in the ground)
    for a in (0.6, -0.6):
        box((2.7, 0.12, 0.04), (0, 0, 1.06), "talt_ora", rot=(0, 0, a))                            # the fly's ridge
    box((0.06, 0.8, 0.8), (1.25, 0, 0.4), "svart")                                                    # the door
    box((0.9, 0.55, 0.04), (1.6, 0, 0.03), "trojan_gul")
    for side in (-1, 1):
        tube((0.0, side * 0.5, 0.92), (0.0, side * 1.7, 0.0), 0.006, "svart", verts=3)
    export("talt", bevel=0.0)


def cykel_parkerad():
    """A blue ladies' bike with a basket, standing on its kickstand; faces +X."""
    for x in (-0.55, 0.55):
        bpy.ops.mesh.primitive_torus_add(major_radius=0.34, minor_radius=0.025, major_segments=14, minor_segments=4,
                                         location=(x, 0, 0.35), rotation=(math.pi / 2, 0, 0))
        _finish(bpy.context.object, "dack")
    for a, b in (((-0.55, 0, 0.35), (-0.05, 0, 0.38)), ((-0.05, 0, 0.38), (0.42, 0, 0.8)), ((-0.55, 0, 0.35), (-0.15, 0, 0.88)),
                 ((-0.05, 0, 0.38), (-0.15, 0, 0.88)), ((0.55, 0, 0.35), (0.42, 0, 0.8)), ((0.42, 0, 0.8), (0.4, 0, 1.0)),
                 ((0.4, -0.25, 1.0), (0.4, 0.25, 1.0))):
        tube(a, b, 0.022, "klanning_bla", verts=4)
    box((0.26, 0.12, 0.06), (-0.17, 0, 0.92), "svart")
    box((0.3, 0.32, 0.22), (0.62, 0, 0.92), "halm")
    tube((-0.05, 0.02, 0.36), (-0.15, 0.25, 0.0), 0.015, "metall", verts=3)
    export("cykel_parkerad", bevel=0.0)


def motorbat():
    """A small white open motorboat with a console, an outboard engine and its driver; faces +X."""
    hull(5.0, 2.0, 0.7, "motorbat_vit", stripe="handduk_bla")
    box((0.5, 0.7, 0.8), (0.4, 0.3, 0.45), "motorbat_vit")
    box((0.06, 0.7, 0.35), (0.66, 0.3, 0.95), "glas")
    box((0.5, 1.6, 0.35), (-1.6, 0, 0.2), "handduk_bla")
    box((0.35, 0.3, 0.7), (-2.6, 0, 0.35), "svart")
    manniska(-0.1, 0.3, -0.05, top="jacka", legs="jeans", hat="keps", pose="forward", seated=True)
    export("motorbat", bevel=0.0)


def promenerare():
    """A walker in a sun hat with a dog lead in one hand; faces +X."""
    manniska(top="trojan_gron", legs="shorts_kaki", hat="solhatt", pose="forward", h=1.72)
    export("promenerare", bevel=0.0)


def hund():
    """A golden retriever trotting; faces +X."""
    blob(1.0, (0, 0, 0.45), "hund_guld", scale=(0.38, 0.14, 0.15), jitter=0.0)
    for x in (-0.25, 0.25):
        for y in (-0.07, 0.07):
            tube((x, y, 0.38), (x + 0.04, y, 0.0), 0.035, "hund_guld", verts=4)
    tube((0.3, 0, 0.5), (0.42, 0, 0.66), 0.07, "hund_guld", verts=5)
    blob(0.1, (0.5, 0, 0.67), "hund_guld", scale=(1.3, 0.85, 0.85), jitter=0.0)
    dot((0.64, 0, 0.64), 0.03, "svart")
    for y in (-0.07, 0.07):
        box((0.06, 0.04, 0.12), (0.45, y, 0.63), "hund_guld")
    tube((-0.3, 0, 0.5), (-0.6, 0, 0.62), 0.03, "hund_guld", verts=4)
    export("hund", bevel=0.0)


def traktor():
    """A small old grey tractor (Grålle style) with big rear wheels and the farmer on it; faces +X."""
    box((1.6, 0.6, 0.6), (0.6, 0, 1.0), "traktor_gra")
    box((0.5, 0.65, 0.65), (1.35, 0, 0.95), "traktor_gra")
    box((0.05, 0.5, 0.4), (1.62, 0, 0.95), "svart")
    tube((1.0, 0.2, 1.3), (1.0, 0.2, 1.85), 0.04, "svart", verts=5)
    box((0.7, 0.9, 0.5), (-0.4, 0, 0.9), "traktor_gra")
    for y in (-0.7, 0.7):
        cyl(0.62, 0.32, (-0.35, y, 0.62), "dack", verts=12, rot=(math.pi / 2, 0, 0))
        cyl(0.36, 0.34, (-0.35, y, 0.62), "traktor_rod", verts=10, rot=(math.pi / 2, 0, 0))
        cyl(0.36, 0.18, (1.15, y * 0.75, 0.36), "dack", verts=10, rot=(math.pi / 2, 0, 0))
        box((0.9, 0.3, 0.05), (-0.35, y, 1.28), "traktor_gra")
    box((1.9, 0.42, 0.35), (0.55, 0, 0.55), "traktor_gra")                                         # chassis
    tube((1.15, -0.62, 0.36), (1.15, 0.62, 0.36), 0.06, "svart", verts=6)                          # axles
    tube((-0.35, -0.82, 0.62), (-0.35, 0.82, 0.62), 0.07, "svart", verts=6)
    box((0.3, 0.4, 0.06), (-0.45, 0, 1.18), "svart")
    manniska(-0.45, 0, 0.72, top="jacka", legs="jeans", hat="keps", hat_col="traktor_rod", pose="forward", seated=True)
    tube((0.15, 0, 1.2), (0.0, 0, 1.6), 0.02, "svart", verts=4)
    cyl(0.18, 0.03, (0.0, 0, 1.62), "svart", verts=10, rot=(0, -0.6, 0))
    export("traktor", bevel=0.0)


def hangmatta():
    """A hammock slung between two posts with someone reading in it; it runs along Y."""
    for y in (-1.8, 1.8):
        tube((0, y, 0.0), (0, y, 1.6), 0.07, "tra_mork", verts=5)
    bm = bmesh.new()
    segs = 10
    rows = []
    for i in range(segs + 1):
        t = i / segs
        y = -1.6 + 3.2 * t
        z = 1.35 - math.sin(t * math.pi) * 0.55
        w = 0.15 + math.sin(t * math.pi) * 0.4
        rows.append([bm.verts.new((-w, y, z + 0.05 * math.sin(t * math.pi))), bm.verts.new((0.0, y, z - 0.08)),
                     bm.verts.new((w, y, z + 0.05 * math.sin(t * math.pi)))])
    for a, b in zip(rows, rows[1:]):
        bm.faces.new((a[0], a[1], b[1], b[0]))
        bm.faces.new((a[1], a[2], b[2], b[1]))
    me = bpy.data.meshes.new("matta")
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new("matta", me)
    bpy.context.collection.objects.link(o)
    o.data.materials.append(mat("hangmatta"))
    for side in (-1, 1):
        tube((0, side * 1.8, 1.5), (0, side * 1.6, 1.35), 0.015, "tra", verts=3)
    taper((0.0, -0.6, 0.9), (0.0, 0.45, 0.9), 0.14, 0.17, "klanning_rod", verts=8)
    tube((0.0, 0.42, 0.95), (0.0, 0.55, 1.02), 0.05, "hud_sol", verts=6)
    blob(0.11, (0.0, 0.6, 1.05), "hud_sol", jitter=0.0, subdiv=2)
    blob(0.115, (0.0, 0.64, 1.1), "man_svart", scale=(1.0, 1.0, 0.7), jitter=0.0)
    for x in (-0.08, 0.08):
        tube((x, -0.55, 0.88), (x, -1.25, 1.02), 0.06, "hud_sol", verts=6)
        blob(0.05, (x, -1.3, 1.04), "hud_sol", scale=(1.0, 1.4, 0.8), jitter=0.0)
    box((0.25, 0.04, 0.32), (0.0, 0.25, 1.2), "handduk_bla", rot=(0.6, 0, 0))
    export("hangmatta", bevel=0.0)


def barn_glass():
    """A child with an ice-cream cone; faces +X."""
    manniska(top="trojan_gul", legs="bare", hat="keps", hat_col="handduk_bla", pose="cup", h=1.2)
    cone(0.035, 0.12, (0.12, 0.07, 0.95), "glass_strut")
    blob(0.045, (0.12, 0.07, 1.04), "glass", jitter=0.0)
    export("barn_glass", bevel=0.0)


bpy.ops.wm.read_factory_settings(use_empty=True)
only = sys.argv[sys.argv.index("--") + 2:] if "--" in sys.argv else []
BUILDS = [
    ("fiskare_brygga", fiskare_brygga), ("badare", badare), ("solbadare", solbadare), ("jolle", jolle),
    ("fikagast_1", lambda: fikagast("fikagast_1", 1)), ("fikagast_2", lambda: fikagast("fikagast_2", 2)),
    ("dansare_1", lambda: dansare("dansare_1", True)), ("dansare_2", lambda: dansare("dansare_2", False)),
    ("sal", sal), ("svan", svan), ("hast", hast), ("radjur", radjur), ("lagereld", lagereld), ("talt", talt),
    ("cykel_parkerad", cykel_parkerad), ("motorbat", motorbat), ("promenerare", promenerare), ("hund", hund),
    ("traktor", traktor), ("hangmatta", hangmatta), ("barn_glass", barn_glass),
]
for name, build in BUILDS:
    if not only or name in only:
        build()
print("SKÄRGÅRDENS LIV KLART")
