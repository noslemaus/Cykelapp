"""Every model of the world Egypten: monuments, Cairo and its bazaar, the Nile and the desert, and
the battle (the pickup with its machine gun, mummies, scarabs and the pharaoh).

    blender --background --python assets/blender/egypten_modeller.py -- game/world/egypten/models [names …]

Same rules and helpers as skargarden_modeller.py (read from that file without running its builds):
Blender Z-up, +X forward, low-poly with flat shading, named colours. Moving models (pickup, mummy,
pharaoh) are exported as loose named parts with their origins at the joints.
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
    "shutter_gron": "4f7a5a", "shutter_bla": "3f6a8f", "sten_sokel": "8a7a66",
    "kalksten": "d8bb8a", "kalksten_mork": "c4a475", "kalksten_ljus": "eadcc0", "sfinx": "c9a46d",
    "sfinx_mork": "a8844f", "sandsten": "c98f5a", "sandsten_mork": "a8703f", "guld": "e0b043", "guld_mork": "b8862a",
    "relief_bla": "2f6fa6", "relief_rod": "b2452f", "relief_gron": "4f8a5a", "relief_gul": "e0b84a",
    "puts_sand": "d8b98a", "puts_rosa": "d6a38b", "puts_vit": "e9dfcc", "puts_ockra": "c9964f", "lera": "b88a5a",
    "fonster_mork": "3a2e2a", "trä_ljus": "b07a4a", "mashrabiya": "6e4426", "kupol_gron": "4f8a6e", "kupol_sand": "d1b07a",
    "markis_rod": "c0392b", "markis_gul": "e6b53a", "markis_gron": "2f7d5a", "markis_bla": "2f5f9f", "markis_vit": "efe6d6",
    "krydda_rod": "c2401f", "krydda_gul": "e7b524", "krydda_ora": "e07a1f", "krydda_gron": "7b8f2a", "krydda_brun": "8a4f2a",
    "lykta_rod": "ff6040", "lykta_gul": "ffc94a", "lykta_bla": "4ab0ff", "lykta_gron": "60e070",
    "matta_rod": "9b2a2a", "matta_bla": "2a3f7a", "matta_beige": "d8c49a", "terrakotta": "b5603a",
    "palmstam": "8a6a45", "palmstam_mork": "6b4f33", "palmblad": "5f8f3a", "palmblad_mork": "476f2c", "dadel": "c8642a",
    "banan": "6fa040", "banan_mork": "4f8030", "papyrus": "6f9a3a", "papyrus_ljus": "a8c25a", "akacia": "7a8a45",
    "buske_torr": "9a8a55", "kamel": "c49a62", "kamel_mork": "9c7444", "sadel_rod": "a83a2a", "felucca": "f1ead8",
    "skrov_bla": "2f5f8f", "talt_svart": "3b3430", "talt_vit": "ece4d0", "brons": "5e4a32", "portal": "6fe8ff",
    "bil_vit": "e8e4da", "bil_smuts": "c2b190", "dack": "202226", "falg": "9aa1aa", "vapen": "3a3d40", "metall_mork": "4d545b",
    "linne": "d9c9a3", "linne_mork": "b3a07a", "mumie_oga": "7dff6a", "skarabe": "1f5f6a", "skarabe_ljus": "2f8f8a",
    "nemes_bla": "1f4f9a", "farao_oga": "ff5a2a", "obelisk": "d4b27f", "asfalt": "5e5955",
    # Abu Simbel, the terrace temple, the citadel and the balloons
    "hieroglyf": "d2a06a", "klippa_sand": "c48a55", "klippa_mork": "a46a3a", "eg_rod": "c8102e", "eg_svart": "1a1a1a",
    "ballong_rod": "d8402a", "ballong_gul": "f0b830", "ballong_bla": "2f6fbf", "ballong_gron": "3f9a5a", "korg": "8a6238",
    # The countryside
    "halm": "c9a65a", "asna": "8a8178", "asna_ljus": "c9c1b4", "kruka": "a8573a", "sack": "d6c7a0",
    # The bigger Egypt: the White Desert's chalk, Aswan's granite, Nubian paint, Alexandria's marble
    "krita": "f1ebdd", "krita_skugga": "dcd2bf", "krita_gul": "e8d6b0", "granit": "8a645a", "granit_rosa": "b48474",
    "granit_mork": "56463f", "nubisk_bla": "3f7fc0", "nubisk_gul": "e6bd45", "nubisk_rosa": "df979c",
    "nubisk_turkos": "3aa9a0", "nubisk_vit": "f3eee4", "marmor": "ece6da", "marmor_mork": "d2c8b6", "eld": "ffa53a",
    "brons_gron": "4f8a78", "kvartsit": "b8926a", "kvartsit_mork": "94704c",
    # People, animals and traffic
    "hud_eg": "a8754e", "hud_ljus": "e2b08c", "galabeya_vit": "ece5d4", "galabeya_bla": "4f6f9a", "galabeya_gra": "9a958a",
    "galabeya_brun": "8a6a4a", "sloja_svart": "2c2828", "sloja_rod": "a8343a", "sko": "3a2e26", "byxor": "4a4a52",
    "khaki": "b8a47a", "turist_skjorta": "e8743a", "turist_shorts": "c8b48a", "keps_bla": "2f5f9f", "shorts_svart": "2a2a30",
    "trikot_rod": "c8302e", "trikot_bla": "2f63b0", "fotboll_vit": "f2f2ee", "taxi_svart": "232427", "taxi_vit": "ecebe6",
    "tuktuk_rod": "b8322a", "tuktuk_bla": "2d5f9a", "ruta": "4f6576", "brod": "c98a4a", "apelsin": "f08a24",
    "melon": "5f9a3a", "banan_gul": "e8c840", "mango": "e0a030", "get_svart": "2f2a28", "get_brun": "8a5a3a",
    "get_vit": "e6e0d4", "ibis_vit": "f2efe8", "ibis_svart": "1e1c1c", "katt_ora": "d28a3e", "katt_gra": "8a8580",
    "buffel": "3a3432", "horn": "c8b89a", "pram_skrov": "3b3a3c", "rost": "8a4a2a", "sockerror": "a8b45a",
    "kryss_vit": "f2f0ea", "kryss_bla": "2f5f8f", "parabol_vit": "e8e6e0", "shisha_glas": "3a8a7a", "te_glas": "c87a3a",
    "nat_bla": "3f6f8a",
})
EMISSIVE.update({"eld": 4.0, "lykta_rod": 3.0, "lykta_gul": 3.0, "lykta_bla": 3.0, "lykta_gron": 3.0, "portal": 1.4,
                 "mumie_oga": 3.0, "farao_oga": 3.5})


def part(name, origin):
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


def square_pyramid(half, height, z0, material):
    """A smooth square pyramid (edges along the axes) from z0 up to a point."""
    cyl(half * math.sqrt(2), height, (0, 0, z0 + height / 2), material, verts=4, rot=(0, 0, math.pi / 4),
        radius_top=0.0)


# --- Monuments ------------------------------------------------------------------------------------

def pyramid(name, base, height, courses, cap=0.0, broken_top=0.0):
    """A pyramid of stepped stone courses (alternating shades). `cap` is the share of the height
    still covered by the smooth white casing at the top (the middle pyramid at Giza);
    `broken_top` cuts the tip off (the Great Pyramid lost its capstone)."""
    top = height * (1.0 - broken_top)
    smooth_from = height * (1.0 - cap) if cap > 0 else top
    n = courses
    step = height / n
    for k in range(n):
        z0 = k * step
        if z0 >= min(top, smooth_from):
            break
        z1 = min(z0 + step, top, smooth_from)
        half = base / 2 * (1.0 - z0 / height)
        box((half * 2, half * 2, z1 - z0), (0, 0, (z0 + z1) / 2), "kalksten" if k % 2 else "kalksten_mork")
    if cap > 0:
        half = base / 2 * (1.0 - smooth_from / height)
        square_pyramid(half, height - smooth_from, smooth_from, "kalksten_ljus")
    # The entrance on the north face (+Y in Blender, which the game turns as it likes).
    box((3.0, 1.5, 4.0), (0, -base * 0.5 * (1.0 - 17.0 / height) + 0.6, 17.0), "fonster_mork")
    export(name, bevel=0.0)


def sfinx():
    """The Great Sphinx, about 57 m long and 20 m high, lying with its paws out towards +X."""
    rnd = random.Random(4)
    blob(1.0, (-8.0, 0, 6.5), "sfinx", scale=(19.0, 8.0, 6.8), jitter=0.06, subdiv=2, seed=1)       # body
    blob(1.0, (-22.0, 0, 5.0), "sfinx_mork", scale=(7.0, 8.5, 5.5), jitter=0.08, subdiv=1, seed=2)   # haunches
    for y in (-4.6, 4.6):
        blob(1.0, (10.5, y, 1.6), "sfinx", scale=(10.5, 1.7, 1.6), jitter=0.04, subdiv=2, seed=int(y + 20))  # forelegs
        blob(1.0, (20.4, y, 1.1), "sfinx_mork", scale=(1.9, 1.8, 1.1), jitter=0.06, subdiv=2, seed=int(y + 30))  # paws
        for t in (-1.05, -0.35, 0.35, 1.05):                                                     # toes
            blob(0.45, (22.0, y + t, 0.5), "sfinx_mork", scale=(1.2, 0.9, 1.0), jitter=0.05)
        blob(1.0, (-19.0, y * 1.25, 2.0), "sfinx_mork", scale=(5.0, 1.8, 2.0), jitter=0.1, seed=int(y + 9))  # hind legs
    box((7.0, 9.0, 8.0), (6.5, 0, 12.0), "sfinx")                                                  # chest and neck
    box((6.0, 6.6, 8.5), (8.5, 0, 18.5), "sfinx")                                                  # head
    prism([(-5.6, 13.0), (5.6, 13.0), (3.6, 22.6), (-3.6, 22.6)], 6.4, "sfinx_mork", x0=7.0)        # nemes headdress
    for k in range(6):
        box((6.5, 11.4 - k * 0.6, 0.25), (7.0, 0, 13.8 + k * 1.4), "kalksten_mork")                # its stripes
    box((0.6, 4.0, 1.0), (11.6, 0, 20.0), "sfinx_mork")                                            # brow
    box((1.4, 1.2, 2.0), (11.9, 0, 18.4), "sfinx_mork")                                            # nose (worn)
    box((0.5, 3.0, 0.5), (11.65, 0, 16.6), "sfinx_mork")                                           # mouth
    for y in (-1.5, 1.5):
        box((0.4, 1.1, 0.5), (11.65, y, 19.3), "fonster_mork")                                     # eyes
    box((1.5, 1.5, 4.0), (10.4, 0, 12.0), "sfinx_mork")                                            # beard stump
    for k in range(5):                                                                             # weathered
        box((30.0 - k * 3.0, 15.6 - k * 0.4, 0.3), (-8.0, 0, 3.2 + k * 1.6), "sfinx_mork")          # rock layers
    box((24.0, 22.0, 0.6), (4.0, 0, -0.1), "kalksten_mork")                                        # floor of its pit
    export("sfinx", bevel=0.0)


def obelisk():
    """A granite obelisk 22 m high with a gilded tip and hieroglyph columns."""
    box((3.6, 3.6, 1.6), (0, 0, 0.8), "kalksten_mork")
    cyl(1.25 * math.sqrt(2), 20.0, (0, 0, 11.6), "obelisk", verts=4, rot=(0, 0, math.pi / 4), radius_top=0.82 * math.sqrt(2))
    square_pyramid(0.82, 1.6, 21.6, "guld")
    rnd = random.Random(2)
    for face in range(4):
        for k in range(12):
            z = 3.0 + k * 1.4
            half = 1.25 - (z - 1.6) / 20.0 * 0.43
            dx, dy = ((half + 0.01, 0), (0, half + 0.01), (-half - 0.01, 0), (0, -half - 0.01))[face]
            size = (0.05, 0.5, rnd.uniform(0.4, 0.9)) if face % 2 == 0 else (0.5, 0.05, rnd.uniform(0.4, 0.9))
            box(size, (dx, dy, z), "sandsten_mork")
    export("obelisk", bevel=0.0)


def pylon():
    """A temple gateway: two sloping towers 18 m high with painted reliefs, a cornice, flagpoles in
    their grooves and the gate between them. The front faces +X."""
    for y in (-10.5, 10.5):
        prism([(y - 7.0, 0), (y + 7.0, 0), (y + 5.6, 18.0), (y - 5.6, 18.0)], 6.0, "sandsten")
        box((6.6, 11.6, 0.9), (0, y, 18.4), "sandsten_mork")                                     # cornice
        for (dz, w, m) in ((5.0, 9.0, "relief_bla"), (8.5, 8.4, "relief_rod"), (12.0, 7.8, "relief_gul")):
            box((0.1, w, 2.2), (3.04, y, dz), m)
            box((0.12, w * 0.3, 1.4), (3.08, y - w * 0.25, dz), "sandsten_mork")                  # figure
            box((0.12, w * 0.2, 1.6), (3.08, y + w * 0.25, dz), "relief_gron")
        for k in (-1.8, 1.8):
            tube((3.4, y + k, 0), (3.4, y + k, 24.0), 0.12, "tra_mork", verts=5)
            slab_y([(3.4, 24.0), (3.4, 22.6), (5.6, 23.4)], 0.04, "relief_rod" if k < 0 else "relief_bla", y=y + k)
    for y in (-3.05, 3.05):
        box((5.0, 1.9, 13.0), (0, y, 6.5), "sandsten")                                             # jambs
    box((5.0, 8.0, 5.0), (0, 0, 10.5), "sandsten")                                                # lintel; the
    box((5.4, 8.6, 1.2), (0, 0, 13.2), "relief_bla")                                              # gate is open
    box((0.2, 2.2, 1.0), (2.75, 0, 13.2), "guld")                                                 # winged sun
    export("pylon", bevel=0.0)


def kolonnad():
    """Part of a hypostyle hall: two rows of four papyrus columns 12 m high with painted bands,
    lotus capitals and the beams laid across them. Rows run along X."""
    for y in (-3.5, 3.5):
        for x in (-9.0, -3.0, 3.0, 9.0):
            cyl(1.1, 10.0, (x, y, 5.0), "sandsten", verts=10)
            for (z, m) in ((1.0, "relief_bla"), (2.0, "relief_rod"), (7.5, "relief_gron"), (8.3, "relief_gul")):
                cyl(1.13, 0.35, (x, y, z), m, verts=10)
            cyl(1.1, 2.0, (x, y, 11.0), "sandsten_mork", verts=10, radius_top=1.8)
            box((2.6, 2.6, 0.6), (x, y, 12.3), "sandsten")
        box((22.0, 2.2, 1.4), (0, y, 13.3), "sandsten_mork")
    for x in (-9.0, -3.0, 3.0, 9.0):
        box((2.0, 9.5, 0.9), (x, 0, 14.4), "sandsten")
    export("kolonnad", bevel=0.0)


def sfinx_liten():
    """A small sphinx 6 m long on a plinth, for the avenue to the temple; faces +X."""
    box((6.6, 2.4, 1.2), (0, 0, 0.6), "kalksten_mork")
    blob(1.0, (-0.8, 0, 2.0), "sfinx", scale=(2.4, 1.0, 0.9), jitter=0.05, subdiv=1, seed=3)
    for y in (-0.6, 0.6):
        box((2.4, 0.5, 0.45), (1.6, y, 1.42), "sfinx")
    box((0.9, 1.0, 1.2), (1.6, 0, 2.6), "sfinx")
    prism([(-0.75, 2.2), (0.75, 2.2), (0.48, 3.5), (-0.48, 3.5)], 1.0, "nemes_bla", x0=1.5)
    for k in range(4):
        box((1.02, 1.5 - k * 0.1, 0.06), (1.5, 0, 2.4 + k * 0.28), "guld")
    export("sfinx_liten", bevel=0.0)


def staty_farao():
    """A seated colossus 14 m high on its throne, hands on knees, double crown; faces +X."""
    box((6.0, 5.0, 2.0), (0, 0, 1.0), "kalksten_mork")
    box((3.4, 4.0, 4.6), (-1.0, 0, 4.3), "sandsten")                                              # throne
    box((4.0, 3.6, 1.2), (0.6, 0, 6.6), "sandsten")                                               # lap
    for y in (-0.9, 0.9):
        box((1.1, 1.1, 4.4), (2.2, y, 4.2), "sandsten")                                           # shins
        box((1.8, 1.2, 0.5), (2.6, y, 2.25), "sandsten")
    taper((0, 0, 7.0), (0.1, 0, 10.8), 1.3, 1.0, "sandsten", verts=8)                             # torso
    for y in (-1.5, 1.5):
        tube((0.1, y, 10.2), (1.8, y, 7.4), 0.42, "sandsten", verts=6)                            # arms
    box((1.4, 1.5, 1.6), (0.3, 0, 11.7), "sandsten")                                              # head
    prism([(-1.4, 10.6), (1.4, 10.6), (0.9, 12.6), (-0.9, 12.6)], 1.5, "nemes_bla", x0=0.1)
    cyl(0.75, 1.8, (0.1, 0, 13.5), "kalksten_ljus", verts=8, radius_top=0.4)                       # crown
    blob(0.32, (0.1, 0, 14.5), "kalksten_ljus", jitter=0.0)
    box((0.3, 0.4, 0.9), (1.05, 0, 10.9), "sandsten_mork")                                        # beard
    export("staty_farao", bevel=0.0)


def standing_figure(x, y, z0, h, crown="kung", arms="sides", mat_body="sandsten"):
    """A standing Egyptian figure h metres tall facing +X with its feet at z0: a king with the double
    crown, or a queen with sun disc and plumes; arms at the sides or crossed on the chest."""
    k = h / 10.0
    box((1.6 * k, 0.7 * k, 0.5 * k), (x + 0.3 * k, y - 0.42 * k, z0 + 0.25 * k), mat_body)        # feet
    box((1.6 * k, 0.7 * k, 0.5 * k), (x + 0.6 * k, y + 0.42 * k, z0 + 0.25 * k), mat_body)
    for dy, dx in ((-0.42, 0.0), (0.42, 0.35)):                                                   # left leg forward
        box((0.8 * k, 0.75 * k, 3.6 * k), (x + dx * k, y + dy * k, z0 + 2.3 * k), mat_body)
    taper((x, y, z0 + 3.9 * k), (x, y, z0 + 5.4 * k), 1.25 * k, 1.0 * k, mat_body, verts=8)         # kilt
    taper((x, y, z0 + 5.3 * k), (x, y, z0 + 7.9 * k), 0.95 * k, 1.2 * k, mat_body, verts=8)         # torso
    if arms == "crossed":
        tube((x + 0.5 * k, y - 1.1 * k, z0 + 7.5 * k), (x + 0.95 * k, y + 0.5 * k, z0 + 6.6 * k), 0.3 * k, mat_body, verts=6)
        tube((x + 0.5 * k, y + 1.1 * k, z0 + 7.5 * k), (x + 0.95 * k, y - 0.5 * k, z0 + 6.6 * k), 0.3 * k, mat_body, verts=6)
        tube((x + 1.1 * k, y - 0.4 * k, z0 + 6.4 * k), (x + 1.2 * k, y - 0.3 * k, z0 + 8.6 * k), 0.09 * k, "guld_mork", verts=4)
        tube((x + 1.1 * k, y + 0.4 * k, z0 + 6.4 * k), (x + 1.25 * k, y + 0.7 * k, z0 + 8.3 * k), 0.09 * k, "guld_mork", verts=4)
    else:
        for side in (-1, 1):
            tube((x, y + side * 1.2 * k, z0 + 7.6 * k), (x + 0.1 * k, y + side * 1.15 * k, z0 + 4.8 * k), 0.32 * k, mat_body, verts=6)
    box((0.9 * k, 0.9 * k, 1.1 * k), (x + 0.05 * k, y, z0 + 8.5 * k), mat_body)                     # head
    prism([(y - 0.85 * k, z0 + 7.7 * k), (y + 0.85 * k, z0 + 7.7 * k), (y + 0.55 * k, z0 + 9.2 * k), (y - 0.55 * k, z0 + 9.2 * k)],
          1.0 * k, "sandsten_mork", x0=x - 0.15 * k)                                                 # headdress
    box((0.25 * k, 0.3 * k, 0.6 * k), (x + 0.55 * k, y, z0 + 7.8 * k), "sandsten_mork")              # beard
    if crown == "kung":
        cyl(0.5 * k, 1.6 * k, (x, y, z0 + 9.9 * k), "kalksten_ljus", verts=8, radius_top=0.28 * k)
        blob(0.26 * k, (x, y, z0 + 10.75 * k), "kalksten_ljus", jitter=0.0)
    else:
        cyl(0.6 * k, 0.4 * k, (x, y, z0 + 9.4 * k), mat_body, verts=8)
        cyl(0.45 * k, 0.12 * k, (x + 0.1 * k, y, z0 + 10.0 * k), "guld", verts=10, rot=(0, math.pi / 2, 0))
        for side in (-1, 1):
            box((0.12 * k, 0.22 * k, 1.6 * k), (x - 0.0 * k, y + side * 0.15 * k, z0 + 10.6 * k), mat_body)


def abusimbel():
    """The small temple at Abu Simbel cut into a sandstone cliff: six standing colossi (kings with
    the double crown, queens with sun disc and plumes) in niches between buttresses carved with
    hieroglyphs, the door in a carved centre block, a frieze along the top and the cliff around it.
    The facade faces +X; about 60 m wide and 24 m high."""
    rnd = random.Random(8)
    # The cliff: a core block, a ragged top and sloping flanks.
    box((16.0, 46.0, 21.0), (-8.6, 0, 10.5), "klippa_sand")
    for k in range(16):
        y = rnd.uniform(-26.0, 26.0)
        blob(1.0, (rnd.uniform(-14.0, -1.0), y, rnd.uniform(19.0, 23.0) - abs(y) * 0.18), "klippa_sand" if k % 3 else "klippa_mork",
             scale=(rnd.uniform(4, 8), rnd.uniform(4, 8), rnd.uniform(2, 4)), jitter=0.25, seed=k)
    for side in (-1, 1):
        for k in range(5):
            y = side * (22.0 + k * 3.2)
            blob(1.0, (rnd.uniform(-9.0, -2.0), y, 9.0 - k * 1.6), "klippa_sand" if k % 2 else "klippa_mork",
                 scale=(rnd.uniform(5, 8), rnd.uniform(3, 5), rnd.uniform(7, 10) - k), jitter=0.25, seed=20 + k + 10 * side)
    # The facade: buttresses with hieroglyphs, niches with colossi, the door block in the middle.
    y = -18.9
    figures = 0
    for piece in ["b", "n", "b", "n", "b", "n", "d", "n", "b", "n", "b", "n", "b"]:
        if piece == "b":
            w = 2.2
            box((2.4, w, 12.6), (0.4, y + w / 2, 6.3), "hieroglyf")
        elif piece == "n":
            w = 3.4
            box((1.2, w, 12.0), (-0.9, y + w / 2, 6.0), "sandsten")
            queen = figures in (1, 4)
            standing_figure(0.2, y + w / 2, 0.4, 10.4, crown="drottning" if queen else "kung")
            box((0.8, 0.8, 2.6), (0.6, y + w / 2 + 1.25, 1.7), "sandsten_mork")              # a child at its feet
            figures += 1
        else:
            w = 4.2
            box((2.8, w, 12.6), (0.6, y + w / 2, 6.3), "hieroglyf")
            box((0.25, 2.2, 4.4), (2.0, y + w / 2, 2.3), "sandsten_mork")                    # door frame
            box((0.3, 1.5, 3.7), (2.08, y + w / 2, 1.95), "fonster_mork")                    # the doorway
        y += w
    box((3.0, 38.6, 1.4), (0.5, 0, 13.3), "hieroglyf")                                         # frieze
    box((3.4, 39.4, 0.5), (0.6, 0, 14.25), "sandsten_mork")
    for k in range(12):
        box((0.9, 0.9, 0.5), (4.2, -18.0 + k * 3.27, 0.25), "kalksten_ljus")                    # bases out front
    box((6.0, 40.0, 0.3), (2.0, 0, 0.05), "kalksten_mork")
    export("abusimbel", bevel=0.0)


def terrasstempel():
    """A terrace temple against a sheer cliff (after Deir el-Bahari): three terraces stepping back,
    each with a colonnade of square pillars, ramps up the middle, statues on the top terrace, and
    the layered cliff towering behind. Faces +X; about 130 m wide, the cliff 45 m high."""
    rnd = random.Random(12)
    box((30.0, 140.0, 44.0), (-36.0, 0, 22.0), "klippa_sand")                                    # the cliff
    for k in range(26):
        y = rnd.uniform(-68.0, 68.0)
        box((rnd.uniform(2.0, 5.0), rnd.uniform(5.0, 16.0), rnd.uniform(14.0, 40.0)),
            (rnd.uniform(-22.5, -20.0), y, rnd.uniform(8.0, 22.0)), "klippa_mork" if k % 3 == 0 else "klippa_sand")
    for k in range(18):
        y = rnd.uniform(-70.0, 70.0)
        blob(1.0, (rnd.uniform(-44.0, -24.0), y, rnd.uniform(43.0, 48.0)), "klippa_sand",
             scale=(rnd.uniform(6, 12), rnd.uniform(6, 12), rnd.uniform(2, 5)), jitter=0.3, seed=40 + k)
    for (z0, z1, front, depth, width) in ((0.0, 7.0, 14.0, 26.0, 86.0), (7.0, 13.0, -5.0, 14.0, 70.0)):
        box((depth, width, z1 - z0), (front - depth / 2, 0, (z0 + z1) / 2), "kalksten_ljus")   # terraces
    for (z0, front, width, n) in ((0.0, 17.0, 80.0, 26), (7.0, 0.0, 66.0, 22), (13.0, -9.0, 54.0, 18)):
        h = 6.0
        box((4.0, width, h), (front - 4.0, 0, z0 + h / 2), "hieroglyf")                          # back wall
        for k in range(n):
            yk = -width / 2 + (k + 0.5) * width / n
            if abs(yk) < 5.0:
                continue                                                                          # the ramp
            box((1.2, 1.2, h), (front, yk, z0 + h / 2), "kalksten_ljus")                          # pillars
        box((5.6, width + 1.0, 0.8), (front - 2.2, 0, z0 + h + 0.4), "kalksten")                  # roof slab
    slope1 = math.atan2(7.0, 18.0)
    box((math.hypot(18.0, 7.0), 9.0, 0.8), (23.0, 0, 3.3), "kalksten", rot=(0, -slope1, 0))       # lower ramp
    slope2 = math.atan2(6.0, 12.0)
    box((math.hypot(12.0, 6.0), 8.0, 0.8), (6.0, 0, 9.8), "kalksten", rot=(0, -slope2, 0))        # upper ramp
    for k in range(8):
        yk = -24.0 + k * (48.0 / 7.0)
        if abs(yk) < 5.0:
            continue
        standing_figure(-8.0, yk, 13.0, 5.6, arms="crossed")                                     # top terrace
    box((40.0, 100.0, 0.3), (24.0, 0, 0.05), "kalksten_mork")                                     # forecourt
    export("terrasstempel", bevel=0.0)


def staty_staende():
    """A standing colossus 12 m high against its back pillar (after the Ramesseum and Luxor):
    double crown, arms crossed holding crook and flail, on a plinth. Faces +X."""
    box((3.6, 3.4, 1.2), (0, 0, 0.6), "kalksten_mork")
    box((1.2, 2.6, 11.0), (-0.9, 0, 6.6), "sandsten_mork")                                       # back pillar
    standing_figure(0.2, 0, 1.2, 10.8, arms="crossed")
    for k in range(6):
        box((0.06, 0.9, 0.5), (-0.28, 0, 2.2 + k * 1.3), "hieroglyf")                            # inscription
    export("staty_staende", bevel=0.0)


def citadell():
    """A seaside citadel (after Qaitbay in Alexandria): a curtain wall with round corner bastions and
    crenellations, a gate with two towers, and the square keep with four round towers and a small
    top tower flying the flag. About 56 x 48 m; the gate faces +X."""
    W, D, H = 56.0, 48.0, 9.0

    def merlons(x0, y0, x1, y1, z, thick):
        n = int(math.hypot(x1 - x0, y1 - y0) / 2.0)
        for k in range(n):
            t = (k + 0.5) / n
            ang = math.atan2(y1 - y0, x1 - x0)
            box((1.0, thick, 1.0), (x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, z + 0.5), "kalksten_ljus", rot=(0, 0, ang))

    def round_tower(x, y, r, h, m="kalksten_ljus"):
        cyl(r, h, (x, y, h / 2), m, verts=14)
        cyl(r + 0.35, 0.6, (x, y, h - 0.3), m, verts=14)
        for k in range(10):
            a = k / 10 * math.tau
            box((0.9, 0.9, 1.0), (x + math.cos(a) * r, y + math.sin(a) * r, h + 0.5), m, rot=(0, 0, a))

    for (x0, y0, x1, y1) in ((-W / 2, -D / 2, W / 2, -D / 2), (W / 2, -D / 2, W / 2, D / 2), (W / 2, D / 2, -W / 2, D / 2),
                             (-W / 2, D / 2, -W / 2, -D / 2)):
        length = math.hypot(x1 - x0, y1 - y0)
        ang = math.atan2(y1 - y0, x1 - x0)
        box((length, 2.6, H), ((x0 + x1) / 2, (y0 + y1) / 2, H / 2), "kalksten_ljus", rot=(0, 0, ang))
        merlons(x0, y0, x1, y1, H, 0.6)
    for x in (-W / 2, W / 2):
        for y in (-D / 2, D / 2):
            round_tower(x, y, 3.6, 11.0)
    for y in (-4.0, 4.0):
        round_tower(W / 2 + 0.8, y, 2.6, 12.0)                                                    # gate towers
    box((0.4, 3.0, 4.6), (W / 2 + 1.35, 0, 2.3), "fonster_mork")                                  # the gate
    box((0.5, 3.8, 0.6), (W / 2 + 1.4, 0, 4.9), "kalksten_mork")
    # The keep.
    box((20.0, 20.0, 16.0), (0, 0, 8.0), "kalksten")
    box((21.0, 21.0, 0.6), (0, 0, 16.3), "kalksten_mork")
    merlons(-10, -10, 10, -10, 16.6, 0.7)
    merlons(10, -10, 10, 10, 16.6, 0.7)
    merlons(10, 10, -10, 10, 16.6, 0.7)
    merlons(-10, 10, -10, -10, 16.6, 0.7)
    for x in (-10.0, 10.0):
        for y in (-10.0, 10.0):
            round_tower(x, y, 3.0, 18.5, "kalksten")
    for z in (5.0, 10.5):
        for k in (-5.0, 0.0, 5.0):
            box((0.3, 1.0, 1.8), (10.05, k, z), "fonster_mork")
            box((1.0, 0.3, 1.8), (k, -10.05, z), "fonster_mork")
            box((1.0, 0.3, 1.8), (k, 10.05, z), "fonster_mork")
    box((7.0, 7.0, 5.0), (0, 0, 19.0), "kalksten")
    merlons(-3.5, -3.5, 3.5, -3.5, 21.5, 0.6)
    merlons(3.5, 3.5, -3.5, 3.5, 21.5, 0.6)
    tube((0, 0, 21.5), (0, 0, 29.0), 0.08, "metall", verts=5)
    for k, m in enumerate(("eg_rod", "vit", "eg_svart")):
        box((3.0, 0.06, 0.6), (1.55, 0, 28.6 - k * 0.6), m)                                        # the flag
    box((0.5, 0.08, 0.4), (1.55, 0, 28.0), "guld")
    export("citadell", bevel=0.0)


def ballong(name, colours):
    """A hot-air balloon: an envelope of twelve gores in alternating colours, ropes, a wicker basket
    and the burner's glow. Origin at the bottom of the basket."""
    profile = [(0.9, 4.2), (2.6, 5.6), (4.4, 7.8), (5.4, 10.4), (5.6, 12.6), (5.0, 15.0), (3.4, 16.9), (0.0, 17.8)]
    n = 12
    bm = bmesh.new()
    rings = [[bm.verts.new((r * math.cos(k / n * math.tau), r * math.sin(k / n * math.tau), z)) for k in range(n)]
             for r, z in profile[:-1]]
    top = bm.verts.new((0, 0, profile[-1][1]))
    faces = []
    for a, b in zip(rings, rings[1:]):
        for k in range(n):
            faces.append((bm.faces.new((a[k], a[(k + 1) % n], b[(k + 1) % n], b[k])), k))
    for k in range(n):
        faces.append((bm.faces.new((rings[-1][k], rings[-1][(k + 1) % n], top)), k))
    for f, k in faces:
        f.material_index = k % len(colours)
    bmesh.ops.recalc_face_normals(bm, faces=[f for f, _ in faces])
    me = bpy.data.meshes.new("kupol")
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new("kupol", me)
    bpy.context.collection.objects.link(o)
    for c in colours:
        o.data.materials.append(mat(c))
    box((1.5, 1.5, 1.1), (0, 0, 0.55), "korg")
    box((1.6, 1.6, 0.12), (0, 0, 1.12), "tra_mork")
    for x in (-0.7, 0.7):
        for y in (-0.7, 0.7):
            tube((x, y, 1.1), (x * 0.91, y * 0.91, 4.25), 0.03, "tra_mork", verts=3)
            tube((x * 0.98, y * 0.98, 1.8), (0, 0, 2.1), 0.025, "metall_mork", verts=3)      # burner frame
    cyl(0.25, 0.4, (0, 0, 2.1), "metall_mork", verts=8)
    blob(0.3, (0, 0, 2.45), "lykta_gul", jitter=0.0)
    export(name, bevel=0.0)


def duvtorn():
    """A mud-brick pigeon tower (common in the Nile countryside): a tapering tower 7 m high studded
    with clay pots for nests, rows of perch sticks, a rounded top; on a square plinth."""
    box((4.2, 4.2, 1.2), (0, 0, 0.6), "lera")
    taper((0, 0, 1.2), (0, 0, 7.0), 1.9, 1.1, "lera", verts=10)
    blob(1.15, (0, 0, 7.1), "lera", scale=(1.0, 1.0, 0.8), jitter=0.0)
    rnd = random.Random(3)
    for ring in range(9):
        z = 1.8 + ring * 0.6
        r = 1.9 - (z - 1.2) / 5.8 * 0.8
        for k in range(10):
            a = (k + 0.5 * (ring % 2)) / 10 * math.tau
            box((0.2, 0.22, 0.22), (math.cos(a) * (r + 0.02), math.sin(a) * (r + 0.02), z), "kruka", rot=(0, 0, a))
        if ring % 3 == 1:
            for k in range(6):
                a = (k + 0.25) / 6 * math.tau
                tube((math.cos(a) * (r - 0.15), math.sin(a) * (r - 0.15), z + 0.3), (math.cos(a) * (r + 0.9), math.sin(a) * (r + 0.9), z + 0.3),
                     0.035, "tra_mork", verts=3)
    box((1.0, 0.1, 1.6), (0, -1.92, 2.0), "tra_mork")                                            # door
    export("duvtorn", bevel=0.0)


def vattenhjul():
    """A wooden water wheel (sakia) over a canal: a big wheel with clay pots on its rim on two
    posts, a trough carrying the water off to the fields. The wheel turns about Y."""
    box((6.0, 1.8, 0.6), (0, 0, -0.3), "lera")                                                   # the channel lip
    for y in (-1.1, 1.1):
        box((0.4, 0.4, 4.4), (0, y, 2.2), "tra_mork")
    tube((0, -1.3, 3.6), (0, 1.3, 3.6), 0.12, "tra_mork", verts=6)
    annulus((0, 0, 3.6), 3.0, 2.7, 0.5, "tra")
    for k in range(8):
        a = k / 8 * math.tau
        tube((0, 0, 3.6), (math.cos(a) * 2.8, 0, 3.6 + math.sin(a) * 2.8), 0.06, "tra", verts=4)
    for k in range(16):
        a = k / 16 * math.tau
        box((0.35, 0.55, 0.35), (math.cos(a) * 3.15, 0, 3.6 + math.sin(a) * 3.15), "kruka", rot=(0, -a, 0))
    box((5.0, 0.8, 0.4), (3.0, 1.6, 4.4), "tra_mork", rot=(0, math.radians(8), 0))                # trough
    box((0.3, 0.3, 4.2), (5.0, 1.6, 1.9), "tra_mork")
    box((0.3, 0.3, 4.6), (1.2, 1.6, 2.2), "tra_mork")
    export("vattenhjul", bevel=0.0)


def lerhus():
    """A village house of mud brick: one storey, a flat roof of palm fronds and straw with sticks
    poking out, small dark windows, a blue door and a low yard wall."""
    box((7.0, 5.5, 3.0), (0, 0, 1.5), "lera")
    box((7.4, 5.9, 0.35), (0, 0, 3.15), "halm")
    rnd = random.Random(6)
    for k in range(14):
        x, y = rnd.uniform(-3.4, 3.4), rnd.uniform(-2.6, 2.6)
        tube((x, y, 3.3), (x + rnd.uniform(-0.6, 0.6), y + rnd.uniform(-0.6, 0.6), 3.7 + rnd.uniform(0, 0.4)), 0.04,
             "palmstam_mork", verts=3)
    blob(1.0, (1.8, 1.2, 3.6), "halm", scale=(1.3, 1.0, 0.5), jitter=0.2, seed=2)               # straw pile
    for x in (-2.2, 2.0):
        box((0.7, 0.12, 0.8), (x, -2.76, 1.8), "fonster_mork")
    box((1.0, 0.12, 2.0), (0.0, -2.78, 1.0), "skrov_bla")
    for (x0, y0, x1, y1) in ((-3.5, -2.75, -6.5, -2.75), (-6.5, -2.75, -6.5, 2.75), (-6.5, 2.75, -3.5, 2.75)):
        length = math.hypot(x1 - x0, y1 - y0)
        box((length, 0.4, 1.4), ((x0 + x1) / 2, (y0 + y1) / 2, 0.7), "lera", rot=(0, 0, math.atan2(y1 - y0, x1 - x0)))
    export("lerhus", bevel=0.0)


def asnekarra():
    """A donkey pulling a two-wheeled cart with sacks and green fodder; faces +X."""
    blob(1.0, (1.6, 0, 1.0), "asna", scale=(0.75, 0.3, 0.32), jitter=0.0, subdiv=1)
    for x in (1.2, 2.0):
        for y in (-0.17, 0.17):
            tube((x, y, 0.85), (x, y, 0.0), 0.06, "asna", verts=4)
    tube((2.25, 0, 1.15), (2.6, 0, 1.5), 0.13, "asna", verts=5)
    blob(0.2, (2.75, 0, 1.45), "asna", scale=(1.4, 0.9, 0.9), jitter=0.0)
    blob(0.1, (2.95, 0, 1.4), "asna_ljus", jitter=0.0)
    for y in (-0.09, 0.09):
        tube((2.66, y, 1.55), (2.5, y, 1.95), 0.04, "asna", verts=3)                               # ears
    for y in (-0.45, 0.45):
        tube((1.9, y, 1.0), (-0.2, y, 0.75), 0.04, "tra_mork", verts=4)                           # shafts
    box((1.8, 1.4, 0.12), (-0.6, 0, 0.75), "tra")
    for y in (-0.72, 0.72):
        bpy.ops.mesh.primitive_torus_add(major_radius=0.48, minor_radius=0.05, major_segments=12, minor_segments=4,
                                         location=(-0.6, y, 0.5), rotation=(math.pi / 2, 0, 0))
        _finish(bpy.context.object, "tra_mork")
        for j in range(6):
            a = j / 6 * math.tau
            tube((-0.6, y, 0.5), (-0.6 + math.cos(a) * 0.48, y, 0.5 + math.sin(a) * 0.48), 0.02, "tra_mork", verts=3)
    tube((-0.6, -0.75, 0.5), (-0.6, 0.75, 0.5), 0.04, "metall_mork", verts=5)
    for y in (-0.6, 0.6):
        box((0.12, 0.1, 0.25), (-0.6, y, 0.6), "tra_mork")
    for k in range(3):
        blob(0.28, (-1.0 + k * 0.45, -0.25 + (k % 2) * 0.4, 0.98), "sack", scale=(1.0, 0.8, 0.7), jitter=0.1, seed=k)
    blob(0.5, (-0.3, 0.2, 1.0), "banan", scale=(1.0, 0.9, 0.5), jitter=0.25, seed=5)              # fodder
    export("asnekarra", bevel=0.0)


# --- Cairo and the bazaar -------------------------------------------------------------------------

def hus_kairo(name, seed, w, d, floors, wall):
    """A flat-roofed town house in plaster: small windows (some lit), a wooden mashrabiya bay, a
    parapet, and roof clutter (water tank, dish, washing)."""
    rnd = random.Random(seed)
    h = floors * 3.2
    box((w, d, h), (0, 0, h / 2), wall)
    box((w + 0.2, d + 0.2, 0.25), (0, 0, h + 0.12), "puts_vit" if wall != "puts_vit" else "puts_sand")
    for side in (-1, 1):
        box((w + 0.2, 0.2, 0.8), (0, side * (d / 2 + 0.05), h + 0.5), wall)
        box((0.2, d + 0.2, 0.8), (side * (w / 2 + 0.05), 0, h + 0.5), wall)
    n = max(1, int(w / 2.6))
    door_k = rnd.randrange(n)
    shutter = "tra_mork"                              # an existing material: no extra draw call
    for f in range(floors):
        z = 1.7 + f * 3.2
        box((w + 0.1, d + 0.1, 0.14), (0, 0, f * 3.2 + 0.07 if f else 0.12), "puts_vit")                   # bands
        for k in range(n):
            x = -w / 2 + (k + 0.5) * w / n
            lit = rnd.random() < 0.3
            for side in (-1, 1):
                if f == 0 and side < 0 and k == door_k:
                    continue
                box((0.9, 0.12, 1.3), (x, side * (d / 2 + 0.01), z), "fonster" if lit and side < 0 else "fonster_mork")
                box((1.1, 0.16, 0.12), (x, side * (d / 2 + 0.03), z - 0.72), "puts_vit")
                if side < 0:
                    box((1.1, 0.14, 0.1), (x, side * (d / 2 + 0.03), z + 0.7), "puts_vit")         # lintel
                if side < 0 and rnd.random() < 0.55:                                               # open shutters
                    for sx in (-1, 1):
                        box((0.42, 0.06, 1.3), (x + sx * 0.68, side * (d / 2 + 0.04), z), shutter)
                if f > 0 and side < 0 and rnd.random() < 0.25:                                     # balcony
                    box((1.5, 0.7, 0.12), (x, side * (d / 2 + 0.35), z - 0.75), "puts_vit")
                    box((1.5, 0.05, 0.75), (x, side * (d / 2 + 0.68), z - 0.32), "metall")
                    for sx in (-1, 1):
                        box((0.05, 0.7, 0.75), (x + sx * 0.73, side * (d / 2 + 0.35), z - 0.32), "metall")
                elif f > 0 and side < 0 and rnd.random() < 0.15:                                    # AC unit
                    box((0.7, 0.45, 0.45), (x + 0.9, side * (d / 2 + 0.22), z - 0.5), "vit")
        if f == floors - 1 or rnd.random() < 0.3:
            for side in (-1, 1):
                box((0.12, 0.9, 1.3), (side * (w / 2 + 0.01), 0, z), "fonster_mork")
    if floors >= 2:
        x = rnd.uniform(-w / 4, w / 4)
        box((2.2, 1.1, 2.4), (x, -d / 2 - 0.55, 4.6), "mashrabiya")
        for k in range(5):
            box((0.05, 1.12, 2.3), (x - 0.9 + k * 0.45, -d / 2 - 0.55, 4.6), "tra_mork")
        box((2.4, 1.3, 0.15), (x, -d / 2 - 0.55, 5.9), "tra_mork")
        for sx in (-0.85, 0.85):                                                                 # corbels
            box((0.18, 1.0, 0.18), (x + sx, -d / 2 - 0.45, 3.3), "tra_mork", rot=(math.radians(-35), 0, 0))
    door_x = -w / 2 + (door_k + 0.5) * w / n
    box((1.2, 0.12, 2.2), (door_x, -d / 2 - 0.02, 1.1), "dorr" if rnd.random() < 0.5 else "tra_mork")
    box((1.5, 0.16, 0.2), (door_x, -d / 2 - 0.04, 2.3), "puts_vit")                                # door lintel
    roof = h + 0.25
    tx, ty = w / 2 - 1.2, d / 2 - 1.2
    for lx in (-0.45, 0.45):                                                                    # water tank
        for ly in (-0.45, 0.45):                                                                # on a stand
            box((0.08, 0.08, 0.5), (tx + lx, ty + ly, roof + 0.25), "metall")
    box((1.1, 1.1, 0.08), (tx, ty, roof + 0.52), "metall")
    cyl(0.6, 1.2, (tx, ty, roof + 1.16), "vit", verts=8)
    if rnd.random() < 0.7:                                                                      # dish on a mast
        dx, dy = -w / 2 + 1.2, d / 2 - 1.5
        tube((dx, dy, roof), (dx, dy, roof + 0.7), 0.03, "metall", verts=4)
        blob(0.5, (dx, dy - 0.15, roof + 0.85), "metall", scale=(1.0, 0.3, 1.0), jitter=0.0)
    if rnd.random() < 0.6:                                                                      # washing line
        x0, x1, ly = -w / 2 + 0.6, w / 2 - 0.6, -d / 2 + 1.0
        for lx in (x0, x1):
            tube((lx, ly, roof), (lx, ly, h + 1.45), 0.03, "metall", verts=4)
        tube((x0, ly, h + 1.4), (x1, ly, h + 1.4), 0.015, "metall", verts=3)
        for k in range(4):
            box((0.5, 0.04, 0.7), (-w / 4 + k * 0.9, ly, h + 1.06),
                ("tvatt_bla", "tvatt_rod", "tvatt_gul", "vit")[k % 4])
    box((2.4, 2.0, 2.2), (-w / 2 + 1.6, -d / 2 + 1.4 + 2.2, roof + 1.1), wall)
    box((0.9, 0.08, 1.8), (-w / 2 + 1.6, -d / 2 + 1.4 + 1.18, roof + 0.9), "tra_mork")
    export(name, bevel=0.0)


def moske():
    """A mosque: a white cube with arched doorway and windows, crenellated parapet, a drum and a
    green dome and four small corner domes. 18 × 18 m."""
    box((18.0, 18.0, 9.0), (0, 0, 4.5), "puts_vit")
    for side in (-1, 1):
        for k in range(9):
            box((1.0, 0.6, 0.8), (-8.0 + k * 2.0, side * 8.9, 9.4), "puts_vit")
            box((0.6, 1.0, 0.8), (side * 8.9, -8.0 + k * 2.0, 9.4), "puts_vit")
    box((3.0, 0.4, 5.0), (0, -9.0, 2.5), "fonster_mork")
    blob(1.5, (0, -9.0, 5.0), "fonster_mork", scale=(1.0, 0.27, 0.6), jitter=0.0)
    for x in (-5.5, 5.5):
        box((1.4, 0.3, 2.6), (x, -9.0, 4.5), "fonster_mork")
    cyl(5.5, 3.0, (0, 0, 10.5), "puts_vit", verts=16)
    blob(5.6, (0, 0, 12.0), "kupol_gron", scale=(1.0, 1.0, 1.05), jitter=0.0, subdiv=2)
    cyl(0.12, 2.5, (0, 0, 18.6), "guld", verts=6)
    blob(0.35, (0, 0, 19.6), "guld", jitter=0.0)
    for (x, y) in ((-6.5, -6.5), (6.5, -6.5), (6.5, 6.5), (-6.5, 6.5)):
        cyl(1.6, 1.2, (x, y, 9.6), "puts_vit", verts=10)
        blob(1.6, (x, y, 10.2), "kupol_gron", jitter=0.0)
    export("moske", bevel=0.0)


def minaret():
    """A slender minaret 38 m high: square base, octagonal shaft with two balconies, a lantern and a
    bulb with a golden crescent."""
    box((4.0, 4.0, 10.0), (0, 0, 5.0), "puts_vit")
    cyl(1.6, 14.0, (0, 0, 17.0), "puts_sand", verts=8)
    for z in (17.0, 27.5):
        cyl(2.4, 0.5, (0, 0, z + 7.0 if z == 17.0 else z), "puts_vit", verts=8)
        for k in range(8):
            a = k / 8 * math.tau
            box((0.15, 0.6, 0.9), (2.3 * math.cos(a), 2.3 * math.sin(a), (z + 7.0 if z == 17.0 else z) + 0.7), "puts_vit",
                rot=(0, 0, a))
    cyl(1.3, 8.0, (0, 0, 28.0), "puts_vit", verts=8)
    for k in range(8):
        a = k / 8 * math.tau + 0.2
        box((0.4, 0.15, 1.4), (1.3 * math.cos(a), 1.3 * math.sin(a), 30.5), "fonster_mork", rot=(0, 0, a))
    cyl(1.1, 2.0, (0, 0, 33.0), "puts_sand", verts=8)
    blob(1.3, (0, 0, 34.6), "kupol_gron", scale=(1.0, 1.0, 1.4), jitter=0.0, subdiv=2)
    cyl(0.08, 2.0, (0, 0, 37.0), "guld", verts=5)
    ring((0, 0, 38.2), 0.4, 0.07, "guld", axis="y", segments=10)
    export("minaret", bevel=0.0)


def basarstand(name, awning, goods, seed):
    """A bazaar stall about 4 m wide facing -Y: a wooden frame with a striped awning, a counter and
    its goods (spices, carpets, lanterns or pots)."""
    rnd = random.Random(seed)
    for x in (-1.9, 1.9):
        for y in (-1.2, 1.2):
            box((0.12, 0.12, 2.6), (x, y, 1.3), "tra_mork")
    for k in range(8):
        box((0.5, 1.9, 0.06), (-1.75 + k * 0.5, -1.65, 2.55), awning if k % 2 == 0 else "markis_vit",
            rot=(math.radians(-18), 0, 0))
    box((4.0, 2.6, 0.08), (0, 0.1, 2.65), "tra_mork")
    box((3.8, 1.0, 0.9), (0, -0.7, 0.45), "tra")
    if goods == "kryddor":
        cols = ("krydda_rod", "krydda_gul", "krydda_ora", "krydda_gron", "krydda_brun", "krydda_rod")
        for k in range(6):
            x = -1.5 + k * 0.6
            cyl(0.26, 0.12, (x, -0.7, 0.96), "tra", verts=8)
            cone(0.22, 0.3, (x, -0.7, 1.17), cols[k], verts=8)
        for k in range(4):
            box((0.5, 0.5, 0.5), (-1.4 + k * 0.9, 0.6, 0.25), "matta_beige")                         # sacks
            cone(0.25, 0.2, (-1.4 + k * 0.9, 0.6, 0.6), cols[(k + 2) % 6], verts=6)
    elif goods == "mattor":
        box((3.9, 0.08, 0.08), (0, 1.15, 2.32), "tra_mork")
        for k in range(4):
            c = ("matta_rod", "matta_bla", "matta_rod", "matta_beige")[k]
            box((0.9, 0.05, 2.0), (-1.4 + k * 0.95, 1.15, 1.3), c)
            box((0.6, 0.06, 1.4), (-1.4 + k * 0.95, 1.12, 1.3), ("matta_beige", "markis_gul", "matta_beige", "matta_rod")[k])
        for k in range(3):
            cyl(0.18, 1.4, (-1.2 + k * 1.2, -0.7, 1.05), ("matta_rod", "matta_bla", "matta_beige")[k], verts=6,
                rot=(0, math.pi / 2, 0))
    elif goods == "lyktor":
        cols = ("lykta_rod", "lykta_gul", "lykta_bla", "lykta_gron")
        for k in range(9):
            x = -1.6 + (k % 5) * 0.8
            y = -1.0 + (k // 5) * 1.2
            tube((x, y, 2.6), (x, y, 2.2), 0.01, "metall", verts=3)
            blob(0.17, (x, y, 2.05), cols[k % 4], scale=(1.0, 1.0, 1.4), jitter=0.0)
            cone(0.12, 0.15, (x, y, 2.3), "guld", verts=6)
        for k in range(4):
            blob(0.15, (-1.2 + k * 0.8, -0.7, 1.05), cols[(k + 1) % 4], scale=(1.0, 1.0, 1.3), jitter=0.0)
    else:   # krukor
        for k in range(7):
            x = -1.6 + k * 0.53
            blob(0.24, (x, -0.7, 1.12), "terrakotta", scale=(1.0, 1.0, 1.3), jitter=0.05, seed=k)
            cyl(0.1, 0.12, (x, -0.7, 1.45), "terrakotta", verts=6)
        for k in range(5):
            blob(0.4, (-1.6 + k * 0.8 + rnd.uniform(-0.1, 0.1), 0.7, 0.5), "terrakotta", scale=(1.0, 1.0, 1.25),
                 jitter=0.05, seed=k + 20)
    export(name, bevel=0.0)


def markis():
    """Strips of coloured cloth hung across a bazaar lane, 10 m wide, 6 m up."""
    for k in range(6):
        c = ("markis_rod", "markis_gul", "markis_gron", "markis_bla", "markis_vit", "markis_rod")[k]
        slab_y([(-5.0, 6.2), (5.0, 6.2), (5.0, 5.9), (0.0, 5.2 + (k % 2) * 0.3), (-5.0, 5.9)], 0.03, c, y=-2.5 + k * 1.0)
    tube((-5.0, -3.0, 6.25), (-5.0, 3.0, 6.25), 0.05, "tra_mork", verts=4)
    tube((5.0, -3.0, 6.25), (5.0, 3.0, 6.25), 0.05, "tra_mork", verts=4)
    export("markis", bevel=0.0)


# --- The Nile, the jungle and the desert ----------------------------------------------------------

def palm(seed, height):
    """A date palm: a ringed, slightly curved trunk, a crown of drooping fronds and dates."""
    rnd = random.Random(seed)
    lean = Vector((rnd.uniform(-1.2, 1.2), rnd.uniform(-1.2, 1.2), 0))
    pts = [Vector((0, 0, -0.3))]
    for k in range(1, 7):
        t = k / 6
        pts.append(Vector((0, 0, height * t)) + lean * (t * t))
    for k in range(6):
        taper(pts[k], pts[k + 1], 0.34 - k * 0.025, 0.31 - k * 0.025, "palmstam" if k % 2 == 0 else "palmstam_mork", verts=7)
        for j in range(3):
            c = pts[k].lerp(pts[k + 1], (j + 0.5) / 3)
            cyl(0.36 - k * 0.025, 0.12, c, "palmstam_mork", verts=7)
    top = pts[-1]
    for i in range(12):
        a = i / 12 * math.tau + rnd.uniform(-0.2, 0.2)
        up = rnd.uniform(-0.1, 0.5)
        d = Vector((math.cos(a), math.sin(a), 0))
        p0 = top
        p1 = top + d * 1.6 + Vector((0, 0, 0.8 + up))
        p2 = top + d * 3.4 + Vector((0, 0, 0.4 + up * 0.5))
        p3 = top + d * 4.6 + Vector((0, 0, -0.9))
        mat_name = "palmblad" if i % 2 else "palmblad_mork"
        for (a0, a1, w) in ((p0, p1, 0.55), (p1, p2, 0.7), (p2, p3, 0.45)):
            mid = (a0 + a1) / 2
            seg = a1 - a0
            o = box((seg.length, w, 0.05), mid, mat_name)
            o.rotation_mode = "QUATERNION"
            o.rotation_quaternion = Vector((1, 0, 0)).rotation_difference(seg.normalized())
    for k in range(3):
        a = k / 3 * math.tau + 0.4
        bunch = top + Vector((math.cos(a) * 0.5, math.sin(a) * 0.5, -0.6))
        tube(top + Vector((math.cos(a) * 0.15, math.sin(a) * 0.15, -0.1)), bunch, 0.04, "palmblad_mork", verts=4)
        blob(0.3, bunch, "dadel", scale=(1, 1, 1.4), jitter=0.2, seed=seed * 7 + k)
    export("palm_%d" % seed, bevel=0.0)


def bananplanta(seed):
    """A banana plant for the riverside jungle: a short stem and broad, arching leaves."""
    rnd = random.Random(seed)
    taper((0, 0, 0), (0, 0, 2.4), 0.22, 0.16, "banan_mork", verts=6)
    for i in range(7):
        a = i / 7 * math.tau + rnd.uniform(-0.3, 0.3)
        d = Vector((math.cos(a), math.sin(a), 0))
        base = Vector((0, 0, 2.2 + rnd.uniform(-0.2, 0.4)))
        tip = base + d * rnd.uniform(1.8, 2.6) + Vector((0, 0, rnd.uniform(-0.4, 0.8)))
        seg = tip - base
        o = box((seg.length, 0.75, 0.04), (base + tip) / 2, "banan" if i % 2 else "banan_mork")
        o.rotation_mode = "QUATERNION"
        o.rotation_quaternion = Vector((1, 0, 0)).rotation_difference(seg.normalized())
    export("bananplanta_%d" % seed, bevel=0.0)


def papyrus(seed):
    """A clump of papyrus: thin stems 2–3 m high with feathery umbels."""
    rnd = random.Random(seed)
    for k in range(9):
        x, y = rnd.uniform(-0.6, 0.6), rnd.uniform(-0.6, 0.6)
        h = rnd.uniform(1.8, 3.0)
        top = Vector((x * 1.6, y * 1.6, h))
        tube((x, y, 0), top, 0.025, "papyrus", verts=3)
        cone(0.45, 0.35, top + Vector((0, 0, 0.1)), "papyrus_ljus" if k % 2 else "papyrus", verts=6)
    export("papyrus_%d" % seed, bevel=0.0)


def akacia(seed):
    """A desert acacia with a forked trunk and a flat umbrella crown."""
    rnd = random.Random(seed)
    taper((0, 0, 0), (0.2, 0, 2.0), 0.18, 0.13, "palmstam_mork", verts=6)
    for k in range(3):
        a = k / 3 * math.tau + rnd.uniform(-0.3, 0.3)
        end = Vector((0.2 + math.cos(a) * 1.6, math.sin(a) * 1.6, 3.6))
        tube((0.2, 0, 2.0), end, 0.08, "palmstam_mork", verts=4)
    blob(1.0, (0.2, 0, 4.0), "akacia", scale=(3.2, 3.0, 0.6), jitter=0.25, seed=seed)
    blob(1.0, (1.0, 0.6, 3.7), "palmblad_mork", scale=(1.8, 1.6, 0.45), jitter=0.25, seed=seed + 3)
    export("akacia_%d" % seed, bevel=0.0)


def buske_torr(seed):
    blob(0.7, (0, 0, 0.4), "buske_torr", scale=(1.2, 1.0, 0.7), jitter=0.3, seed=seed)
    export("buske_torr_%d" % seed, bevel=0.0)


def klippa(seed):
    """A weathered sandstone rock with layered ledges."""
    rnd = random.Random(seed)
    blob(1.0, (0, 0, 0.6), "sandsten", scale=(2.2, 1.6, 1.3), jitter=0.22, subdiv=1, seed=seed)
    for k in range(3):
        box((rnd.uniform(1.5, 3.0) - k * 0.4, rnd.uniform(1.0, 2.0) - k * 0.2, 0.25), (rnd.uniform(-0.4, 0.4), rnd.uniform(-0.3, 0.3),
            0.3 + k * 0.35), "sandsten_mork", rot=(0, 0, rnd.uniform(0, 3)))
    export("klippa_%d" % seed, bevel=0.0)


def kamel(name, lying=False):
    """A dromedary with a red saddle blanket; head towards +X."""
    z = -0.3 if lying else 1.15                       # lying: the belly rests on the ground
    blob(1.0, (0, 0, z + 0.85), "kamel", scale=(1.2, 0.5, 0.5), jitter=0.05, subdiv=1, seed=1)
    blob(0.5, (-0.05, 0, z + 1.35), "kamel", scale=(1.0, 0.8, 0.9), jitter=0.05, seed=2)              # hump
    box((1.0, 1.05, 0.5), (-0.05, 0, z + 1.25), "sadel_rod")
    tube((0.95, 0, z + 1.0), (1.45, 0, z + 1.8), 0.16, "kamel", verts=6)                              # neck
    tube((1.45, 0, z + 1.8), (1.75, 0, z + 1.85), 0.15, "kamel", verts=6)
    blob(0.2, (1.85, 0, z + 1.85), "kamel_mork", scale=(1.4, 0.8, 0.8), jitter=0.0)                  # head
    for y in (-0.08, 0.08):
        dot((1.75, y, z + 2.02), 0.04, "kamel_mork")                                                  # ears
    if lying:
        for y in (-0.28, 0.28):                       # forelegs folded under the chest, knees forward
            blob(0.3, (0.75, y, 0.16), "kamel", scale=(1.4, 0.8, 0.55), jitter=0.0, subdiv=2)
            blob(0.13, (1.1, y, 0.12), "kamel_mork", scale=(1.0, 1.0, 0.8), jitter=0.0)
        for y in (-0.36, 0.36):                       # hind legs folded along the flanks
            blob(0.35, (-0.7, y, 0.22), "kamel", scale=(1.5, 0.7, 0.62), jitter=0.0, subdiv=2)
            blob(0.11, (-0.2, y, 0.1), "kamel_mork", scale=(1.0, 1.0, 0.8), jitter=0.0)
    else:
        for (x, y) in ((0.75, -0.25), (0.75, 0.25), (-0.75, -0.25), (-0.75, 0.25)):
            tube((x, y, z + 0.6), (x + 0.05, y, 0.0), 0.09, "kamel", verts=5)
            box((0.22, 0.2, 0.06), (x + 0.07, y, 0.03), "kamel_mork")
    export(name, bevel=0.0)


def felucca():
    """A felucca: a white Nile sailboat with a tall slanting yard and a big lateen sail."""
    hull(8.0, 2.4, 0.8, "felucca", stripe="skrov_bla")
    box((6.4, 2.0, 0.06), (-0.4, 0, 0.12), "tra")
    cyl(0.08, 5.5, (1.2, 0, 2.9), "tra_mork", verts=6)
    tube((3.8, 0, 1.0), (-2.8, 0, 11.0), 0.06, "tra_mork", verts=5)                                  # the yard
    slab_y([(3.6, 1.2), (-2.6, 10.6), (-2.0, 1.2)], 0.03, "felucca")
    export("felucca", bevel=0.0)


def talt_beduin():
    """A low black Bedouin tent on poles with rugs and cushions in front; opening towards -Y."""
    prism([(-2.5, 0.0), (2.5, 0.0), (2.0, 1.6), (0.0, 2.2), (-2.0, 1.6)], 6.0, "talt_svart")
    box((5.6, 0.1, 1.6), (0, -2.55, 0.8), "fonster_mork")
    for x in (-2.8, 0.0, 2.8):
        tube((x, -3.4, 0), (x, -2.5, 1.7), 0.04, "tra_mork", verts=4)
    box((3.0, 2.0, 0.04), (0, -4.0, 0.02), "matta_rod")
    box((2.0, 1.2, 0.05), (-0.4, -4.1, 0.03), "matta_beige")
    for k in range(3):
        box((0.6, 0.4, 0.25), (-1.0 + k * 1.0, -3.2, 0.15), ("markis_gul", "matta_bla", "markis_rod")[k])
    blob(0.25, (2.2, -4.5, 0.33), "terrakotta", scale=(1, 1, 1.3), jitter=0.0)
    for x in (-2.8, 2.8):                                                                          # guy ropes
        tube((x, -2.5, 1.6), (x * 1.15, -4.2, 0.0), 0.012, "tra_mork", verts=3)
    export("talt_beduin", bevel=0.0)


def lejonstaty():
    """A bronze lion lying on a stone plinth, guarding the end of the Nile bridge; faces +X."""
    box((4.6, 1.8, 2.2), (0, 0, 1.1), "kalksten_mork")
    box((4.8, 2.0, 0.25), (0, 0, 2.08), "kalksten")                                              # cornice
    box((5.0, 2.2, 0.3), (0, 0, 0.15), "kalksten")                                               # foot
    box((0.04, 1.2, 1.0), (2.31, 0, 1.0), "hieroglyf")                                           # inscription
    body = 2.2
    blob(1.0, (-0.45, 0, body + 0.5), "brons", scale=(1.55, 0.55, 0.5), jitter=0.03, subdiv=2, seed=1)  # body
    blob(0.5, (-1.5, 0, body + 0.4), "brons", scale=(1.0, 1.1, 0.8), jitter=0.0, subdiv=2)         # haunch
    for y in (-0.36, 0.36):
        blob(0.3, (-1.35, y, body + 0.25), "brons", scale=(1.3, 0.6, 0.8), jitter=0.0)              # hind legs
        box((1.25, 0.26, 0.22), (1.25, y, body + 0.11), "brons")                                    # forelegs
        blob(0.14, (1.85, y, body + 0.12), "brons", scale=(1.3, 1.1, 0.8), jitter=0.0)              # paws
    blob(0.6, (0.95, 0, body + 1.0), "brons", scale=(0.9, 1.0, 1.05), jitter=0.12, subdiv=2, seed=2)  # mane
    blob(0.36, (1.45, 0, body + 0.95), "brons", scale=(1.1, 0.9, 0.95), jitter=0.0, subdiv=2)      # face
    box((0.3, 0.32, 0.22), (1.75, 0, body + 0.85), "brons")                                      # muzzle
    dot((1.92, 0, body + 0.9), 0.05, "eg_svart")                                                   # nose
    for y in (-0.12, 0.12):
        dot((1.7, y, body + 1.1), 0.04, "eg_svart")                                                # eyes
        cone(0.1, 0.14, (1.2, y * 2.2, body + 1.5), "brons", verts=5)                              # ears
    tube((-1.9, 0, body + 0.45), (-2.35, 0.25, body + 0.12), 0.07, "brons", verts=5)               # tail
    tube((-2.35, 0.25, body + 0.12), (-1.8, 0.6, body + 0.08), 0.06, "brons", verts=5)
    blob(0.1, (-1.75, 0.62, body + 0.1), "brons", jitter=0.0)
    export("lejonstaty", bevel=0.0)


def teleportport():
    """The teleport gate on a bridge: two stone pillars and an arch with a glowing ring, 9 m high.
    The road passes through it along X."""
    for y in (-3.6, 3.6):
        box((1.4, 1.4, 7.0), (0, y, 3.5), "kalksten")
        box((1.8, 1.8, 0.6), (0, y, 0.3), "kalksten_mork")
        for k in range(4):
            box((1.42, 0.5, 0.35), (0, y, 1.6 + k * 1.3), "relief_bla" if k % 2 else "relief_gul")
    box((1.6, 9.0, 1.2), (0, 0, 7.6), "kalksten_mork")
    bpy.ops.mesh.primitive_torus_add(major_radius=3.0, minor_radius=0.22, major_segments=24, minor_segments=6,
                                     location=(0, 0, 4.2), rotation=(0, math.pi / 2, 0))
    _finish(bpy.context.object, "portal")
    for k in range(8):
        a = k / 8 * math.tau
        dot((0.0, 3.0 * math.cos(a), 4.2 + 3.0 * math.sin(a)), 0.28, "guld")
    export("teleportport", bevel=0.0)


# --- The dig camp by the pyramids -----------------------------------------------------------------

def talt_vit():
    """A white expedition tent with its flaps tied up; opening towards -Y."""
    prism([(-2.2, 0.0), (2.2, 0.0), (2.2, 1.4), (0.0, 2.8), (-2.2, 1.4)], 5.0, "talt_vit")
    box((1.6, 0.1, 1.6), (0, -2.52, 0.8), "fonster_mork")
    for x in (-2.6, 2.6):
        tube((x, 0, 0), (x, 0, 3.0), 0.04, "tra_mork", verts=4)
    export("talt_vit", bevel=0.0)


def stralkastare():
    """A floodlight mast with two lamps over the dig and a generator at its foot."""
    tube((0, 0, 0), (0, 0, 6.0), 0.08, "metall_mork", verts=5)
    for k in range(3):
        a = k / 3 * math.tau
        tube((0, 0, 2.0), (math.cos(a) * 1.2, math.sin(a) * 1.2, 0), 0.04, "metall_mork", verts=4)
    box((0.3, 1.6, 0.12), (0, 0, 6.0), "metall_mork")
    for y in (-0.6, 0.6):
        box((0.4, 0.5, 0.4), (0.15, y, 6.2), "metall_mork")
        box((0.05, 0.4, 0.3), (0.36, y, 6.2), "fonster")
    box((1.4, 0.9, 0.9), (1.4, 0.8, 0.45), "markis_gul")
    export("stralkastare", bevel=0.0)


def sarkofag():
    """A stone sarcophagus with its lid pushed askew, and a painted mummy case beside it."""
    box((2.6, 1.2, 1.0), (0, 0, 0.5), "kalksten_mork")
    box((2.7, 1.25, 0.2), (0.3, 0.25, 1.1), "kalksten", rot=(0, 0, 0.18))
    box((2.3, 0.9, 0.08), (-0.1, 0, 0.96), "fonster_mork")
    blob(1.0, (0, 1.6, 0.35), "guld", scale=(1.0, 0.36, 0.3), jitter=0.0, subdiv=2)
    box((0.5, 0.6, 0.05), (0.6, 1.6, 0.66), "nemes_bla")
    export("sarkofag", bevel=0.0)


# --- The battle -----------------------------------------------------------------------------------

def flakbil():
    """A pickup with a heavy machine gun on the load bed, white and dusty, 5.3 m long. Parts: Kaross
    (body and wheels), Torn (the gun mount that turns, origin on its pivot) and Pipa (the gun, origin
    at its trunnion). The cyclist mans the gun."""
    box((2.0, 1.9, 0.75), (1.4, 0, 0.95), "bil_vit")                                             # bonnet/nose
    box((1.6, 1.9, 1.05), (0.0, 0, 1.4), "bil_vit")                                              # cab
    box((0.06, 1.7, 0.6), (0.82, 0, 1.6), "glas_mork", rot=(0, math.radians(-25), 0))
    for y in (-0.96, 0.96):
        box((1.1, 0.04, 0.5), (0.0, y, 1.6), "glas_mork")
    box((1.5, 1.95, 0.1), (0.0, 0, 1.95), "bil_vit")
    box((2.4, 1.9, 0.12), (-2.0, 0, 0.75), "bil_vit")                                            # bed floor
    for y in (-0.92, 0.92):
        box((2.4, 0.08, 0.55), (-2.0, y, 1.05), "bil_vit")
    box((0.08, 1.9, 0.55), (-3.2, 0, 1.05), "bil_vit")
    box((5.0, 1.85, 0.25), (-0.3, 0, 0.55), "bil_smuts")                                         # dust sills
    box((0.15, 1.7, 0.5), (2.45, 0, 0.75), "metall_mork")                                        # bull bar
    for y in (-0.6, 0.6):
        box((0.05, 0.3, 0.2), (2.42, y, 1.05), "fonster")
        box((0.2, 0.18, 0.18), (0.3, y * 0.9, 2.1), "fonster")                                   # roof lights
    for x in (1.5, -2.0):
        for y in (-0.95, 0.95):
            cyl(0.42, 0.32, (x, y, 0.42), "dack", verts=10, rot=(math.pi / 2, 0, 0))
            cyl(0.22, 0.34, (x, y, 0.42), "falg", verts=8, rot=(math.pi / 2, 0, 0))
    cyl(0.42, 0.3, (-3.35, 0, 0.9), "dack", verts=10, rot=(0, math.pi / 2, 0))                     # spare wheel
    box((0.5, 0.4, 0.4), (-1.3, -0.6, 1.0), "markis_gul")                                         # jerrycan
    part("Kaross", (0, 0, 0))
    # The mount and the cyclist standing behind the gun.
    cyl(0.12, 0.9, (-1.9, 0, 1.25), "metall_mork", verts=6)
    box((0.5, 0.5, 0.12), (-1.9, 0, 1.72), "metall_mork")
    for y in (-0.1, 0.1):
        tube((-2.6, y, 0.8), (-2.6, y, 1.75), 0.075, "byxor", verts=6)
        box((0.24, 0.1, 0.07), (-2.55, y, 0.83), "svart")
    taper((-2.6, 0, 1.75), (-2.55, 0, 2.4), 0.22, 0.2, "trika", verts=8)
    box((0.05, 0.12, 0.55), (-2.36, 0, 2.08), "flagga_gul")
    box((0.05, 0.4, 0.09), (-2.36, 0, 2.18), "flagga_gul")
    tube((-2.55, 0, 2.35), (-2.53, 0, 2.52), 0.055, "hud", verts=6)
    blob(0.13, (-2.52, 0, 2.58), "hud", jitter=0.0, subdiv=2)
    blob(0.155, (-2.55, 0, 2.66), "hjalm", scale=(1.2, 1.0, 0.75), jitter=0.0)
    box((0.06, 0.22, 0.05), (-2.4, 0, 2.6), "svart")
    for y in (-0.22, 0.22):
        tube((-2.55, y, 2.3), (-2.2, y * 0.6, 1.95), 0.05, "trika", verts=5)
    part("Torn", (-1.9, 0, 1.75))
    box((0.7, 0.22, 0.24), (-1.75, 0, 1.92), "vapen")                                            # receiver
    tube((-1.4, 0, 1.92), (-0.1, 0, 1.92), 0.05, "vapen", verts=6)                               # barrel
    cyl(0.07, 0.2, (-0.1, 0, 1.92), "vapen", verts=6, rot=(0, math.pi / 2, 0))
    box((0.3, 0.3, 0.25), (-1.75, 0.25, 1.85), "relief_gron")                                    # ammo box
    box((0.08, 0.7, 0.5), (-1.25, 0, 2.05), "metall_mork")                                       # shield
    part("Pipa", (-1.9, 0, 1.92))
    export_parts("flakbil")


def mumie(name="mumie", scale_y=1.0):
    """A shambling mummy in linen bandages with glowing green eyes, arms out in front. Parts with
    their origins at the joints, like the zombie: Kropp (hips), ArmV/ArmH, BenV/BenH."""
    taper((0, 0, 0.95), (0.05, 0, 1.5), 0.19, 0.24, "linne", verts=7)
    for k in range(6):
        cyl(0.24 - abs(k - 2.5) * 0.01, 0.05, (0.02 + k * 0.01, 0, 1.0 + k * 0.09), "linne_mork", verts=7,
            rot=(0.3 * (1 if k % 2 else -1), 0, 0))
    taper((0.05, 0, 1.5), (0.1, 0, 1.6), 0.08, 0.07, "linne", verts=6)
    blob(0.15, (0.14, 0, 1.73), "linne", scale=(1.0, 0.9, 1.15), jitter=0.06, seed=3)
    for k in range(3):
        cyl(0.15, 0.03, (0.14, 0, 1.64 + k * 0.08), "linne_mork", verts=8, rot=(0.25 * (1 if k % 2 else -1), 0, 0))
    for y in (-0.06, 0.06):
        box((0.04, 0.05, 0.035), (0.28, y, 1.75), "mumie_oga")
    box((0.2, 0.06, 0.4), (0.0, 0.2, 0.75), "linne_mork", rot=(0.4, 0, 0))                      # loose strip
    part("Kropp", (0, 0, 0.95))
    for side, pname in ((1, "ArmV"), (-1, "ArmH")):
        y = side * 0.27
        tube((0.05, y, 1.45), (0.62, y, 1.4), 0.055, "linne", verts=6)
        for k in range(3):
            cyl(0.06, 0.03, (0.2 + k * 0.15, y, 1.43), "linne_mork", verts=6, rot=(0, math.pi / 2, 0))
        blob(0.06, (0.67, y, 1.4), "linne", jitter=0.2, seed=side + 5)
        part(pname, (0.05, y, 1.45))
    for side, pname in ((1, "BenV"), (-1, "BenH")):
        y = side * 0.11
        taper((0, y, 0.95), (0.02, y, 0.08), 0.085, 0.065, "linne", verts=6)
        for k in range(4):
            cyl(0.085, 0.03, (0.01, y, 0.25 + k * 0.18), "linne_mork", verts=6)
        box((0.24, 0.11, 0.08), (0.06, y, 0.04), "linne_mork")
        part(pname, (0, y, 0.95))
    export_parts(name)


def farao():
    """The pharaoh: a mummy king with a blue and gold striped nemes headdress, a golden mask and a
    cobra on the brow, arms out. Built life-size (the game makes him huge). Same parts as the mummy."""
    taper((0, 0, 0.95), (0.05, 0, 1.5), 0.21, 0.26, "linne", verts=8)
    box((0.06, 0.5, 0.55), (0.22, 0, 1.25), "guld")                                             # pectoral
    for k in range(3):
        box((0.065, 0.46 - k * 0.08, 0.05), (0.23, 0, 1.08 + k * 0.17), "nemes_bla")
    box((0.3, 0.55, 0.12), (0.05, 0, 0.98), "guld")                                              # belt
    blob(0.16, (0.14, 0, 1.75), "guld", scale=(1.0, 0.9, 1.15), jitter=0.0)                     # mask
    prism([(-0.32, 1.45), (0.32, 1.45), (0.2, 1.95), (-0.2, 1.95)], 0.36, "nemes_bla", x0=0.05)
    for k in range(5):
        box((0.38, 0.62 - k * 0.07, 0.03), (0.05, 0, 1.52 + k * 0.09), "guld")
    for y in (-0.06, 0.06):
        box((0.04, 0.05, 0.035), (0.3, y, 1.77), "farao_oga")
    box((0.06, 0.06, 0.18), (0.3, 0, 1.6), "guld")                                               # beard
    tube((0.22, 0, 1.9), (0.28, 0, 2.0), 0.02, "guld", verts=4)                                  # cobra
    part("Kropp", (0, 0, 0.95))
    for side, pname in ((1, "ArmV"), (-1, "ArmH")):
        y = side * 0.3
        tube((0.05, y, 1.45), (0.62, y, 1.4), 0.06, "linne", verts=6)
        cyl(0.075, 0.08, (0.5, y, 1.41), "guld", verts=6, rot=(0, math.pi / 2, 0))
        blob(0.065, (0.67, y, 1.4), "linne", jitter=0.2, seed=side + 15)
        if side > 0:
            tube((0.68, y, 1.1), (0.7, y, 1.9), 0.02, "guld", verts=4)                           # crook
            ring((0.78, y, 1.95), 0.08, 0.02, "guld", axis="y", segments=8)
        part(pname, (0.05, y, 1.45))
    for side, pname in ((1, "BenV"), (-1, "BenH")):
        y = side * 0.12
        taper((0, y, 0.95), (0.02, y, 0.08), 0.095, 0.07, "linne", verts=6)
        box((0.25, 0.12, 0.08), (0.06, y, 0.04), "guld")
        part(pname, (0, y, 0.95))
    export_parts("farao")


def skarabe():
    """A sacred scarab beetle 1 m long, blue-green with gold edges, that scuttles up and bursts."""
    blob(0.45, (-0.05, 0, 0.35), "skarabe", scale=(1.25, 1.0, 0.6), jitter=0.0, subdiv=2)
    box((0.04, 0.9, 0.04), (-0.05, 0, 0.62), "guld")
    tube((0.45, 0, 0.6), (-0.55, 0, 0.56), 0.015, "guld", verts=3)
    blob(0.18, (0.5, 0, 0.3), "skarabe_ljus", scale=(1.0, 1.3, 0.7), jitter=0.0)
    for y in (-0.12, 0.12):
        tube((0.62, y, 0.3), (0.82, y * 1.6, 0.3), 0.025, "guld", verts=3)
        dot((0.6, y * 1.2, 0.38), 0.035, "mumie_oga")
    for k in range(3):
        for y in (-1, 1):
            x = 0.25 - k * 0.3
            tube((x, y * 0.35, 0.25), (x + 0.15, y * 0.75, 0.0), 0.025, "svart", verts=3)
    export("skarabe", bevel=0.0)


# --- The bigger Egypt: Alexandria, the White Desert, Thebes, Aswan and Nubia ----------------------

def half_annulus(r0, r1, z0, z1, material, a0, a1, segs=16):
    """A curved step: the part of a ring between radii r0 and r1 from angle a0 to a1, z0 to z1."""
    bm = bmesh.new()
    rows = []
    for k in range(segs + 1):
        a = a0 + (a1 - a0) * k / segs
        c, s_ = math.cos(a), math.sin(a)
        rows.append([bm.verts.new((r * c, r * s_, z)) for (r, z) in ((r0, z0), (r1, z0), (r1, z1), (r0, z1))])
    for k in range(segs):
        a, b = rows[k], rows[k + 1]
        for i in range(4):
            j = (i + 1) % 4
            bm.faces.new((a[i], a[j], b[j], b[i]))
    bm.faces.new(rows[0])
    bm.faces.new(list(reversed(rows[-1])))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new("ring")
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new("ring", me)
    bpy.context.collection.objects.link(o)
    o.data.materials.append(mat(material))
    return o


def faros():
    """The lighthouse of Alexandria as it was: a square tower on a stepped platform, an octagonal
    middle storey, a round lantern of columns with the fire inside, and a bronze statue on top;
    tritons on the corners and a ramp up to the door. About 60 m high; the door faces +X."""
    box((32.0, 32.0, 1.2), (0, 0, 0.6), "kalksten_mork")
    box((26.0, 26.0, 1.2), (0, 0, 1.8), "marmor_mork")
    cyl(8.4 * math.sqrt(2), 27.0, (0, 0, 15.9), "marmor", verts=4, rot=(0, 0, math.pi / 4), radius_top=7.2 * math.sqrt(2))
    for z in (8.0, 14.0, 20.0, 25.0):
        w = 8.4 - (z - 2.4) / 27.0 * 1.2
        for t in (-3.6, 0.0, 3.6):
            if z == 8.0 and t == 0.0:
                continue
            box((0.3, 0.8, 1.6), (w + 0.02, t, z), "fonster_mork")
            box((0.3, 0.8, 1.6), (-w - 0.02, t, z), "fonster_mork")
            box((0.8, 0.3, 1.6), (t, w + 0.02, z), "fonster_mork")
            box((0.8, 0.3, 1.6), (t, -w - 0.02, z), "fonster_mork")
    box((0.5, 2.4, 3.6), (8.35, 0, 7.0), "fonster_mork")                                          # the door
    box((0.6, 3.2, 0.6), (8.4, 0, 9.1), "kalksten_mork")
    slope = math.atan2(5.2, 15.0)
    box((math.hypot(15.0, 5.2), 3.0, 0.8), (15.5, 0, 4.6), "marmor_mork", rot=(0, slope, 0))      # the ramp
    box((16.2, 16.2, 0.9), (0, 0, 29.85), "kalksten_mork")
    for x in (-7.2, 7.2):
        for y in (-7.2, 7.2):
            standing_figure(x, y, 30.3, 3.4, arms="sides", mat_body="brons_gron")                 # tritons
    cyl(5.4, 14.0, (0, 0, 37.3), "marmor", verts=8, radius_top=4.7)
    for z in (34.0, 39.0):
        for k in range(8):
            a = (k + 0.5) / 8 * math.tau
            r = 5.15 - (z - 30.3) / 14.0 * 0.7
            box((0.3, 0.8, 1.5), (math.cos(a) * r, math.sin(a) * r, z), "fonster_mork", rot=(0, 0, a))
    cyl(5.3, 0.7, (0, 0, 44.6), "kalksten_mork", verts=8)
    cyl(2.2, 6.4, (0, 0, 48.1), "fonster_mork", verts=10)
    blob(1.5, (0, 0, 47.0), "eld", scale=(1.0, 1.0, 1.5), jitter=0.25, seed=3)                     # the fire
    for k in range(10):
        a = k / 10 * math.tau
        tube((math.cos(a) * 3.2, math.sin(a) * 3.2, 45.0), (math.cos(a) * 3.2, math.sin(a) * 3.2, 51.2), 0.28, "marmor", verts=6)
    cyl(3.9, 0.6, (0, 0, 51.5), "kalksten_mork", verts=12)
    cone(3.6, 2.4, (0, 0, 53.0), "marmor", verts=12)
    standing_figure(0, 0, 54.0, 5.0, arms="sides", mat_body="brons_gron")                         # the statue
    export("faros", bevel=0.0)


def vit_klippa(seed):
    """A chalk formation of the White Desert, carved by the wind: a mushroom, a stack or a low
    ridge, white with a yellowish band and grey hollows."""
    rnd = random.Random(seed)
    if seed == 1:
        blob(1.0, (0, 0, 1.9), "krita_skugga", scale=(1.3, 1.1, 2.0), jitter=0.2, seed=seed)
        blob(1.0, (0.2, 0.1, 4.4), "krita", scale=(3.6, 3.0, 1.4), jitter=0.22, seed=seed + 10)
        blob(1.0, (0.1, 0.0, 3.6), "krita_gul", scale=(2.6, 2.2, 0.5), jitter=0.15, seed=seed + 20)
    elif seed == 2:
        blob(1.0, (0, 0, 1.0), "krita", scale=(2.8, 2.3, 1.3), jitter=0.2, seed=seed)
        blob(1.0, (0.3, 0.0, 3.1), "krita_skugga", scale=(1.4, 1.2, 1.6), jitter=0.22, seed=seed + 10)
        blob(1.0, (0.6, 0.2, 5.3), "krita", scale=(2.1, 1.6, 1.1), jitter=0.25, seed=seed + 20)
        blob(1.0, (1.7, 0.3, 5.9), "krita_gul", scale=(0.9, 0.6, 0.6), jitter=0.2, seed=seed + 30)
    else:
        blob(1.0, (0, 0, 1.3), "krita", scale=(7.0, 3.4, 2.4), jitter=0.22, seed=seed)
        blob(1.0, (-2.6, 0.4, 3.2), "krita_skugga", scale=(2.4, 2.0, 1.3), jitter=0.25, seed=seed + 10)
        blob(1.0, (2.4, -0.2, 2.6), "krita_gul", scale=(3.0, 2.2, 0.8), jitter=0.2, seed=seed + 20)
        for k in range(4):
            blob(0.6, (rnd.uniform(-7, 7), rnd.uniform(-4, 4), 0.3), "krita_skugga", jitter=0.3, seed=seed + 40 + k)
    export("vit_klippa_%d" % seed, bevel=0.0)


def granit(seed):
    """Rounded granite boulders of the cataract at Aswan, dark and smooth with pink veins."""
    if seed == 1:
        blob(1.0, (0, 0, 1.0), "granit_mork", scale=(2.8, 2.2, 1.7), jitter=0.12, subdiv=2, seed=seed)
        blob(1.0, (0.4, 0.3, 2.2), "granit", scale=(1.6, 1.3, 0.9), jitter=0.12, subdiv=1, seed=seed + 5)
    else:
        blob(1.0, (0, 0, 0.9), "granit", scale=(2.2, 1.9, 1.5), jitter=0.12, subdiv=2, seed=seed)
        blob(1.0, (1.9, 0.8, 0.7), "granit_mork", scale=(1.6, 1.4, 1.1), jitter=0.14, subdiv=1, seed=seed + 5)
        blob(1.0, (-0.6, -0.5, 2.3), "granit_rosa", scale=(1.1, 1.0, 0.8), jitter=0.12, subdiv=1, seed=seed + 9)
    export("granit_%d" % seed, bevel=0.0)


def gravport():
    """A royal tomb's entrance in the Valley of the Kings: a doorway framed in limestone cut into the
    rock, a painted lintel, an iron gate, and the sloping cut down to it. Faces +X."""
    rnd = random.Random(4)
    box((9.0, 16.0, 11.0), (-4.5, 0, 5.5), "klippa_sand")
    for k in range(9):
        y = rnd.uniform(-7.0, 7.0)
        blob(1.0, (rnd.uniform(-8.0, -1.5), y, rnd.uniform(10.0, 12.0)), "klippa_sand" if k % 3 else "klippa_mork",
             scale=(rnd.uniform(3, 5), rnd.uniform(3, 5), rnd.uniform(1.5, 3)), jitter=0.25, seed=k)
    box((1.0, 5.0, 5.4), (0.1, 0, 2.7), "kalksten_ljus")                                         # frame
    box((1.04, 2.8, 3.9), (0.12, 0, 1.95), "fonster_mork")                                       # doorway
    for k, m in enumerate(("relief_bla", "relief_gul", "relief_rod", "relief_gul", "relief_bla")):
        box((0.2, 0.8, 0.6), (0.65, -1.8 + k * 0.9, 4.6), m)                                     # painted lintel
    for k in range(7):
        tube((0.75, -1.2 + k * 0.4, 0.0), (0.75, -1.2 + k * 0.4, 3.8), 0.04, "metall_mork", verts=4)  # gate
    tube((0.75, -1.4, 3.8), (0.75, 1.4, 3.8), 0.05, "metall_mork", verts=4)
    tube((0.75, -1.4, 1.9), (0.75, 1.4, 1.9), 0.05, "metall_mork", verts=4)
    box((6.0, 5.6, 0.3), (3.2, 0, 0.05), "kalksten_mork")                                         # the cut
    for side in (-1, 1):
        box((6.0, 0.6, 1.0), (3.2, side * 3.1, 0.5), "kalksten")
    box((0.15, 1.2, 0.8), (6.1, 2.4, 1.3), "markis_bla")                                          # tomb plate
    tube((6.1, 2.4, 0.0), (6.1, 2.4, 1.0), 0.05, "metall_mork", verts=4)
    export("gravport", bevel=0.0)


def memnon():
    """One of the Colossi of Memnon: a seated king 18 m high, worn by three thousand years of sand
    and floods, on a big plinth; reliefs on the throne's side. Faces +X."""
    k = 1.3
    box((8.0 * k, 6.0 * k, 2.4 * k), (0, 0, 1.2 * k), "kvartsit_mork")
    box((4.0 * k, 4.6 * k, 5.0 * k), (-1.2 * k, 0, 4.9 * k), "kvartsit")                             # throne
    for side in (-1, 1):
        box((3.0 * k, 0.12, 3.2 * k), (-1.2 * k, side * 2.32 * k, 4.6 * k), "hieroglyf")            # side relief
    box((4.4 * k, 3.8 * k, 1.3 * k), (0.6 * k, 0, 7.6 * k), "kvartsit")                             # lap
    for y in (-0.95, 0.95):
        box((1.2 * k, 1.2 * k, 5.0 * k), (2.4 * k, y * k, 4.9 * k), "kvartsit")                      # shins
        box((1.9 * k, 1.3 * k, 0.6 * k), (2.8 * k, y * k, 2.7 * k), "kvartsit_mork")
    taper((0, 0, 8.1 * k), (0.1 * k, 0, 12.2 * k), 1.45 * k, 1.1 * k, "kvartsit", verts=8)          # torso
    for y in (-1.6, 1.6):
        tube((0.1 * k, y * k, 11.6 * k), (2.0 * k, y * k, 8.4 * k), 0.46 * k, "kvartsit", verts=6)   # arms
    blob(1.0 * k, (0.25 * k, 0, 13.1 * k), "kvartsit_mork", scale=(0.9, 0.85, 1.0), jitter=0.22, seed=7)  # worn head
    prism([(-1.5 * k, 11.8 * k), (1.5 * k, 11.8 * k), (1.0 * k, 13.9 * k), (-1.0 * k, 13.9 * k)], 1.6 * k, "kvartsit", x0=-0.15 * k)
    for n in range(4):                                                                              # cracks
        box((0.06, 0.08 * k, (1.2 + n * 0.5) * k), (0.82 * k, (-1.8 + n * 1.2) * k, (4.0 + n * 0.6) * k), "kvartsit_mork")
    export("memnon", bevel=0.0)


def philae():
    """The temple of Isis at Philae on its island: a pylon with reliefs, a court between two
    colonnades, the sanctuary, and Trajan's kiosk with its fourteen columns, on a stone quay.
    About 70 x 46 m; the pylon faces +X."""
    box((74.0, 50.0, 1.6), (-4.0, 4.0, 0.8), "kalksten_mork")                                      # quay
    for side in (-1, 1):
        prism([(side * 2.2, 1.6), (side * 13.0, 1.6), (side * 12.0, 18.0), (side * 3.2, 18.0)], 5.0, "hieroglyf", x0=22.0)
        box((5.6, 10.0, 0.8), (22.0, side * 7.6, 18.3), "kalksten")
        for t in (-2.0, 2.0):
            box((0.3, 1.2, 9.0), (24.6, side * 7.6 + t, 9.0), "relief_bla" if t < 0 else "relief_rod")
    box((5.2, 4.4, 1.2), (22.0, 0, 9.5), "kalksten")                                               # gate lintel
    box((0.3, 3.0, 7.4), (24.5, 0, 5.3), "fonster_mork")
    for side in (-1, 1):
        for n in range(6):
            x = 15.0 - n * 4.4
            tube((x, side * 11.0, 1.6), (x, side * 11.0, 10.0), 0.75, "kalksten_ljus", verts=8)
            cyl(1.2, 1.4, (x, side * 11.0, 10.6), "relief_gron", verts=8, radius_top=1.5)          # papyrus capitals
        box((28.0, 4.0, 0.9), (4.0, side * 11.6, 11.7), "kalksten")
        box((28.0, 0.8, 9.0), (4.0, side * 13.6, 6.1), "hieroglyf")
    box((18.0, 18.0, 11.0), (-16.0, 0, 7.1), "hieroglyf")                                          # sanctuary
    box((18.8, 18.8, 1.0), (-16.0, 0, 13.1), "kalksten")
    box((0.3, 3.0, 5.0), (-6.9, 0, 4.1), "fonster_mork")
    # Trajan's kiosk on the quay's corner.
    kx, ky = -22.0, 22.0
    for i in range(5):
        for j in range(4):
            if 0 < i < 4 and 0 < j < 3:
                continue
            x, y = kx - 8.0 + i * 4.0, ky - 6.0 + j * 4.0
            tube((x, y, 1.6), (x, y, 13.0), 0.7, "kalksten_ljus", verts=8)
            cyl(0.9, 2.2, (x, y, 14.1), "relief_gron", verts=8, radius_top=1.3)
            box((2.0, 2.0, 1.6), (x, y, 16.0), "kalksten")
    box((18.0, 14.0, 1.4), (kx, ky, 17.4), "kalksten")
    for (x0, y0, x1, y1) in ((kx - 8, ky - 6, kx + 8, ky - 6), (kx - 8, ky + 6, kx + 8, ky + 6), (kx - 8, ky - 6, kx - 8, ky + 6),
                             (kx + 8, ky - 6, kx + 8, ky - 2), (kx + 8, ky + 2, kx + 8, ky + 6)):
        length = math.hypot(x1 - x0, y1 - y0)
        box((length, 0.6, 4.6), ((x0 + x1) / 2, (y0 + y1) / 2, 3.9), "kalksten", rot=(0, 0, math.atan2(y1 - y0, x1 - x0)))
    export("philae", bevel=0.0)


def hus_nubisk(name, wall, door, seed):
    """A Nubian house by the Nile: painted walls with white zigzag bands and diamonds, two white
    barrel vaults on the roof, a crenellated parapet, an arched door in a painted frame with a
    plate above, and small windows with coloured shutters. The door faces -Y."""
    rnd = random.Random(seed)
    W, D, H = 8.0, 7.0, 3.6
    box((W, D, H), (0, 0, H / 2), wall)
    for y in (-1.75, 1.75):
        cyl(1.7, W - 0.6, (0, y, H), "nubisk_vit", verts=12, rot=(0, math.pi / 2, 0))                # vaults
    for k in range(13):
        x = -W / 2 + 0.3 + k * (W - 0.6) / 12
        slab_y([(x - 0.15, H), (x + 0.15, H), (x, H + 0.45)], 0.14, "nubisk_vit", y=-D / 2 + 0.05)          # merlons
    for k in range(16):
        x = -W / 2 + 0.25 + k * (W - 0.5) / 15
        box((0.32, 0.06, 0.32), (x, -D / 2 - 0.03, H - 0.55), "nubisk_vit", rot=(0, math.pi / 4, 0))  # diamond band
    box((W, 0.05, 0.08), (0, -D / 2 - 0.03, H - 0.9), "nubisk_vit")
    box((2.2, 0.08, 3.0), (0, -D / 2 - 0.03, 1.5), "nubisk_vit")                                   # door frame
    box((1.3, 0.1, 2.2), (0, -D / 2 - 0.06, 1.1), door)                                            # the door
    cyl(0.65, 0.1, (0, -D / 2 - 0.06, 2.2), door, verts=10, rot=(math.pi / 2, 0, 0))                # its arch
    box((0.9, 0.1, 0.5), (0, -D / 2 - 0.07, 2.75), "nubisk_gul" if wall != "nubisk_gul" else "nubisk_bla")
    for x in (-2.6, 2.6):
        box((0.8, 0.08, 0.8), (x, -D / 2 - 0.04, 1.9), "fonster_mork")
        box((0.25, 0.1, 0.9), (x - 0.55, -D / 2 - 0.06, 1.9), door)
        box((0.25, 0.1, 0.9), (x + 0.55, -D / 2 - 0.06, 1.9), door)
    if rnd.random() < 0.7:
        box((3.0, 0.4, 1.2), (W / 2 + 1.5, -D / 2 + 0.2, 0.6), wall)                              # yard wall
        box((0.4, 4.0, 1.2), (W / 2 + 3.0, -D / 2 + 2.0, 0.6), wall)
    export(name, bevel=0.0)


def obelisk_oavslutad():
    """The unfinished obelisk at Aswan: a 42 m obelisk still lying in the bedrock of the quarry,
    cracked and abandoned, with the trenches the workers pounded round it and a walkway for
    visitors. About 52 x 18 m; the top of the rock is at 1.5 m."""
    box((52.0, 18.0, 3.0), (0, 0, 0.0), "granit_rosa")                                             # bedrock
    rnd = random.Random(2)
    for k in range(10):
        blob(1.0, (rnd.uniform(-26, 26), rnd.choice((-1, 1)) * rnd.uniform(8, 10), 1.2), "granit",
             scale=(rnd.uniform(2, 4), rnd.uniform(1.5, 3), rnd.uniform(0.8, 1.6)), jitter=0.2, seed=k)
    for side in (-1, 1):
        box((44.0, 1.2, 0.4), (0.5, side * 2.9, 1.35), "granit_mork")                              # trenches
    prism([(-2.1, -0.4), (2.1, -0.4), (2.1, 1.9), (-2.1, 1.9)], 40.0, "granit", x0=1.0)              # the shaft
    prism([(-1.3, -0.4), (1.3, -0.4), (0.0, 1.9)], 2.0, "granit", x0=-20.0)                        # its point, end on
    box((0.15, 4.4, 2.0), (6.0, 0, 1.0), "granit_mork")                                            # the crack
    box((30.0, 2.4, 0.25), (0.0, -6.0, 3.2), "tra")                                                # walkway
    for n in range(11):
        x = -15.0 + n * 3.0
        tube((x, -7.15, 1.5), (x, -7.15, 4.3), 0.05, "metall", verts=4)
        tube((x, -6.0, 1.5), (x, -6.0, 3.1), 0.08, "tra_mork", verts=4)
    tube((-15.0, -7.15, 4.2), (15.0, -7.15, 4.2), 0.05, "metall", verts=4)
    export("obelisk_oavslutad", bevel=0.0)


def pelare_pompejus():
    """Pompey's Pillar in Alexandria: a red granite column 27 m high with a Corinthian capital on a
    stepped pedestal."""
    box((7.0, 7.0, 1.0), (0, 0, 0.5), "kalksten_mork")
    box((5.0, 5.0, 3.6), (0, 0, 2.8), "granit_rosa")
    box((5.6, 5.6, 0.5), (0, 0, 4.85), "granit")
    cyl(1.7, 0.8, (0, 0, 5.5), "granit", verts=14)
    cyl(1.4, 20.4, (0, 0, 16.1), "granit_rosa", verts=14, radius_top=1.18)
    cyl(1.25, 2.6, (0, 0, 27.6), "granit", verts=14, radius_top=1.8)
    for k in range(8):
        a = k / 8 * math.tau
        blob(0.45, (math.cos(a) * 1.5, math.sin(a) * 1.5, 28.2), "granit", scale=(1.0, 1.0, 1.4), jitter=0.1, seed=k)
    box((4.0, 4.0, 0.9), (0, 0, 29.35), "granit_rosa")
    export("pelare_pompejus", bevel=0.0)


def teater():
    """The Roman theatre of Alexandria: thirteen curved tiers of white marble round a paved
    orchestra, a portico of columns along the top and the stumps of a colonnade in front. The
    open side faces +X; about 44 m across."""
    box((10.0, 46.0, 0.3), (2.0, 0, 0.15), "kalksten_mork")
    half_annulus(0.0, 6.5, 0.0, 0.35, "marmor_mork", math.pi / 2, 3 * math.pi / 2, segs=14)           # orchestra
    for k in range(13):
        r0 = 7.0 + k * 1.15
        half_annulus(r0, r0 + 1.15, 0.0, 0.5 + k * 0.5, "marmor" if k % 2 == 0 else "marmor_mork",
                     math.pi / 2, 3 * math.pi / 2, segs=18)
    rtop = 7.0 + 13 * 1.15 - 0.55                    # on the top tier
    for n in range(15):
        a = math.pi / 2 + (n + 0.5) / 15 * math.pi
        x, y = math.cos(a) * rtop, math.sin(a) * rtop
        tube((x, y, 6.5), (x, y, 11.0), 0.32, "marmor", verts=8)
    half_annulus(rtop - 0.6, rtop + 0.6, 11.0, 11.7, "marmor_mork", math.pi / 2, 3 * math.pi / 2, segs=18)
    for n in range(9):
        y = -16.0 + n * 4.0
        tube((6.0, y, 0.3), (6.0, y, 1.0 + (n * 37 % 5) * 0.9), 0.4, "granit_rosa", verts=8)           # stumps
    export("teater", bevel=0.0)


# --- Life: people at work, animals, traffic -------------------------------------------------------

def gestalt(x=0.0, y=0.0, z0=0.0, robe="galabeya_vit", skin="hud_eg", hat=None, hat_col=None, pose="sides",
            legs="robe", shirt=None, h=1.75, seated=False):
    """A person facing +X with the feet at z0, h metres tall: a galabeya to the ankles (legs="robe"),
    or trousers in a colour, or bare legs with dark shorts (legs="bare"); a shirt colour over a
    robe; arms posed (sides, forward, wave, head, lap, work, cup); a hat (kepa, turban, sloja,
    hatt, keps). Seated people sit on something 0.45 m high."""
    k = h / 1.75
    top = shirt or robe
    if seated:
        hip = z0 + 0.48 * k
        for side in (-1, 1):
            tube((x, y + side * 0.1 * k, hip), (x + 0.42 * k, y + side * 0.1 * k, hip), 0.085 * k, robe, verts=6)
            shin = robe if legs == "robe" else ("hud_eg" if legs == "bare" else legs)
            tube((x + 0.42 * k, y + side * 0.1 * k, hip), (x + 0.46 * k, y + side * 0.1 * k, z0 + 0.06 * k), 0.065 * k, shin, verts=6)
            box((0.2 * k, 0.09 * k, 0.06 * k), (x + 0.52 * k, y + side * 0.1 * k, z0 + 0.03 * k), "sko")
        taper((x, y, hip), (x, y, hip + 0.56 * k), 0.2 * k, 0.19 * k, top, verts=8)
        shoulder = hip + 0.52 * k
    else:
        if legs == "robe":
            taper((x, y, z0 + 0.06 * k), (x, y, z0 + 1.0 * k), 0.25 * k, 0.19 * k, robe, verts=8)
        else:
            leg = skin if legs == "bare" else legs
            for side in (-1, 1):
                tube((x, y + side * 0.09 * k, z0 + 0.05 * k), (x, y + side * 0.09 * k, z0 + 0.95 * k), 0.065 * k, leg, verts=6)
            if legs == "bare":
                taper((x, y, z0 + 0.62 * k), (x, y, z0 + 0.98 * k), 0.19 * k, 0.18 * k, "shorts_svart" if shirt else robe, verts=8)
        for side in (-1, 1):
            box((0.22 * k, 0.09 * k, 0.07 * k), (x + 0.04 * k, y + side * 0.09 * k, z0 + 0.035 * k), "sko")
        taper((x, y, z0 + 0.92 * k), (x, y, z0 + 1.46 * k), 0.19 * k, 0.2 * k, top, verts=8)
        shoulder = z0 + 1.41 * k
    hands = {"sides": ((0.04, -0.26, -0.45), (0.04, 0.26, -0.45)), "forward": ((0.42, -0.2, -0.3), (0.42, 0.2, -0.3)),
             "wave": ((0.04, -0.26, -0.45), (0.06, 0.34, 0.45)), "head": ((0.02, -0.13, 0.42), (0.02, 0.13, 0.42)),
             "lap": ((0.3, -0.12, -0.3), (0.3, 0.12, -0.3)), "work": ((0.42, -0.15, -0.45), (0.36, 0.2, -0.25)),
             "cup": ((0.3, -0.14, -0.3), (0.2, 0.1, 0.06))}[pose]
    blob(0.2 * k, (x, y, shoulder + 0.02 * k), top, scale=(0.75, 1.15, 0.4), jitter=0.0)          # shoulders
    for side, hand in zip((-1, 1), hands):
        a = (x, y + side * 0.17 * k, shoulder)
        b = (x + hand[0] * k, y + hand[1] * k, shoulder + hand[2] * k)
        tube(a, b, 0.05 * k, top, verts=5)
        blob(0.05 * k, b, skin, jitter=0.0)
    hz = shoulder + 0.2 * k
    tube((x, y, shoulder), (x, y, hz - 0.04 * k), 0.05 * k, skin, verts=5)
    blob(0.11 * k, (x + 0.01 * k, y, hz + 0.05 * k), skin, scale=(1.0, 0.92, 1.08), jitter=0.0, subdiv=2)
    dot((x + 0.115 * k, y, hz + 0.04 * k), 0.022 * k, skin)                                         # nose
    for side in (-1, 1):
        dot((x + 0.105 * k, y + side * 0.04 * k, hz + 0.075 * k), 0.013 * k, "eg_svart")           # eyes
    if hat == "kepa":
        cyl(0.1 * k, 0.07 * k, (x, y, hz + 0.14 * k), hat_col or "galabeya_vit", verts=8)
    elif hat == "turban":
        cyl(0.135 * k, 0.11 * k, (x, y, hz + 0.13 * k), hat_col or "galabeya_vit", verts=10)
        blob(0.1 * k, (x, y, hz + 0.19 * k), hat_col or "galabeya_vit", scale=(1, 1, 0.6), jitter=0.0)
    elif hat == "sloja":
        blob(0.135 * k, (x - 0.035 * k, y, hz + 0.06 * k), hat_col or "sloja_svart", scale=(1.0, 1.0, 1.1), jitter=0.0)
        taper((x - 0.03 * k, y, hz - 0.04 * k), (x - 0.03 * k, y, shoulder - 0.12 * k), 0.12 * k, 0.24 * k, hat_col or "sloja_svart", verts=8)
    elif hat == "hatt":
        cyl(0.24 * k, 0.03 * k, (x, y, hz + 0.11 * k), hat_col or "khaki", verts=12)
        cyl(0.11 * k, 0.12 * k, (x, y, hz + 0.17 * k), hat_col or "khaki", verts=10)
    elif hat == "keps":
        cyl(0.115 * k, 0.08 * k, (x, y, hz + 0.13 * k), hat_col or "keps_bla", verts=10)
        box((0.14 * k, 0.18 * k, 0.02 * k), (x + 0.15 * k, y, hz + 0.1 * k), hat_col or "keps_bla")
    return hz


def turn_new(before, yaw, offset):
    """Turn everything made since `before` about the origin by yaw and move it by offset (to seat a
    person built facing +X at a table)."""
    c, sn = math.cos(yaw), math.sin(yaw)
    for o in set(bpy.data.objects) - before:
        x, y, z = o.location
        o.location = (x * c - y * sn + offset[0], x * sn + y * c + offset[1], z + offset[2])
        o.rotation_mode = "XYZ"          # tubes are left in quaternion mode, which ignored the turn
        o.rotation_euler = (0, 0, yaw)


def man_galabeya():
    gestalt(robe="galabeya_gra", hat="kepa")
    export("man_galabeya", bevel=0.0)


def kvinna_kruka():
    """A woman in a black dress and headscarf carrying a water jar on her head."""
    hz = gestalt(robe="sloja_svart", hat="sloja", hat_col="sloja_rod", pose="head", h=1.68)
    blob(0.16, (0.0, 0, hz + 0.32), "kruka", scale=(1.0, 1.0, 1.2), jitter=0.0)
    cyl(0.07, 0.1, (0.0, 0, hz + 0.52), "kruka", verts=8)
    export("kvinna_kruka", bevel=0.0)


def handlare_karra():
    """A trader pushing a handcart heaped with oranges and melons; faces +X."""
    gestalt(robe="galabeya_bla", hat="turban", pose="forward")
    box((1.3, 0.85, 0.08), (1.3, 0, 0.78), "tra")
    for side in (-1, 1):
        box((1.3, 0.05, 0.18), (1.3, side * 0.43, 0.9), "tra_mork")
        tube((0.42, side * 0.2, 1.05), (0.7, side * 0.38, 0.82), 0.03, "tra_mork", verts=4)
        bpy.ops.mesh.primitive_torus_add(major_radius=0.36, minor_radius=0.04, major_segments=12, minor_segments=4,
                                         location=(1.3, side * 0.5, 0.38), rotation=(math.pi / 2, 0, 0))
        _finish(bpy.context.object, "tra_mork")
        for j in range(6):
            a = j / 6 * math.tau
            tube((1.3, side * 0.5, 0.38), (1.3 + math.cos(a) * 0.36, side * 0.5, 0.38 + math.sin(a) * 0.36), 0.015,
                 "tra_mork", verts=3)
        box((0.1, 0.12, 0.42), (1.3, side * 0.42, 0.56), "tra_mork")                               # bracket
    tube((1.3, -0.5, 0.38), (1.3, 0.5, 0.38), 0.03, "metall_mork", verts=4)
    box((0.06, 0.06, 0.78), (1.9, 0, 0.39), "tra_mork")
    rnd = random.Random(3)
    for n in range(16):
        dot((rnd.uniform(0.75, 1.85), rnd.uniform(-0.33, 0.33), 0.88 + rnd.uniform(0, 0.03)), 0.07, "apelsin")
    for n in range(3):
        blob(0.15, (1.0 + n * 0.32, 0.1 - n * 0.1, 0.94), "melon", scale=(1.2, 1.0, 0.9), jitter=0.0)
    export("handlare_karra", bevel=0.0)


def budcykel():
    """A bread delivery boy on a bicycle, steering with one hand and balancing a tray of round
    loaves on his head with the other; faces +X."""
    for x in (-0.55, 0.55):
        bpy.ops.mesh.primitive_torus_add(major_radius=0.33, minor_radius=0.03, major_segments=14, minor_segments=4,
                                         location=(x, 0, 0.34), rotation=(math.pi / 2, 0, 0))
        _finish(bpy.context.object, "dack")
    for a, b in (((-0.55, 0, 0.34), (0.0, 0, 0.36)), ((0.0, 0, 0.36), (0.45, 0, 0.85)), ((-0.1, 0, 0.9), (0.45, 0, 0.85)),
                 ((-0.55, 0, 0.34), (-0.1, 0, 0.9)), ((0.0, 0, 0.36), (-0.1, 0, 0.9)), ((0.55, 0, 0.34), (0.45, 0, 0.85)),
                 ((0.45, 0, 0.85), (0.42, 0, 1.08)), ((0.42, -0.26, 1.08), (0.42, 0.26, 1.08))):
        tube(a, b, 0.022, "metall_mork", verts=4)
    box((0.24, 0.1, 0.05), (-0.1, 0, 0.93), "sko")
    hip = 0.98
    for side in (-1, 1):
        tube((-0.1, side * 0.12, hip), (0.2, side * 0.13, 0.78 + side * 0.08), 0.07, "byxor", verts=6)
        tube((0.2, side * 0.13, 0.78 + side * 0.08), (0.05, side * 0.13, 0.3 + side * 0.12), 0.055, "byxor", verts=6)
    taper((-0.1, 0, hip), (0.0, 0, hip + 0.55), 0.19, 0.19, "galabeya_vit", verts=8)
    tube((0.0, -0.21, hip + 0.5), (0.42, -0.24, 1.1), 0.045, "galabeya_vit", verts=5)
    tube((0.0, 0.21, hip + 0.5), (0.0, 0.3, hip + 1.0), 0.045, "galabeya_vit", verts=5)
    tube((0.0, 0, hip + 0.5), (0.02, 0, hip + 0.72), 0.05, "hud_eg", verts=6)
    blob(0.11, (0.02, 0, hip + 0.76), "hud_eg", jitter=0.0, subdiv=2)
    blob(0.045, (0.42, -0.24, 1.1), "hud_eg", jitter=0.0)
    blob(0.045, (0.0, 0.3, hip + 0.88), "hud_eg", jitter=0.0)
    box((1.1, 0.5, 0.04), (0.0, 0.1, hip + 0.89), "tra")
    for i in range(4):
        for j in range(2):
            cyl(0.1, 0.06, (-0.38 + i * 0.25, -0.03 + j * 0.26, hip + 0.94), "brod", verts=8)
    export("budcykel", bevel=0.0)


def taxi_kairo():
    """An old Cairo taxi: a black saloon with white wings and a sign on the roof; faces +X."""
    box((4.1, 1.62, 0.62), (0, 0, 0.62), "taxi_svart")
    for x in (-1.5, 1.5):
        box((1.0, 1.66, 0.36), (x, 0, 0.72), "taxi_vit")                                          # white wings
    box((2.1, 1.5, 0.55), (-0.25, 0, 1.2), "taxi_svart")
    box((2.12, 1.4, 0.4), (-0.25, 0, 1.2), "ruta")
    box((0.6, 0.3, 0.16), (-0.25, 0, 1.56), "taxi_vit")                                           # roof sign
    for x in (-1.3, 1.3):
        for y in (-0.76, 0.76):
            cyl(0.32, 0.22, (x, y, 0.32), "dack", verts=10, rot=(math.pi / 2, 0, 0))
            cyl(0.18, 0.24, (x, y, 0.32), "falg", verts=8, rot=(math.pi / 2, 0, 0))
    for y in (-0.55, 0.55):
        box((0.05, 0.25, 0.14), (2.06, y, 0.72), "lykta_gul")
        box((0.05, 0.22, 0.12), (-2.06, y, 0.72), "lykta_rod")
    box((0.06, 1.3, 0.12), (2.07, 0, 0.45), "metall")
    box((1.4, 1.2, 0.08), (-0.3, 0, 1.52), "metall_mork")                                          # roof rack
    box((0.8, 0.6, 0.35), (-0.5, 0.1, 1.73), "matta_rod")
    export("taxi_kairo", bevel=0.0)


def tuktuk():
    """A tuk-tuk: a red three-wheeler with a blue canopy, open sides and the driver; faces +X."""
    box((1.6, 1.3, 0.5), (-0.3, 0, 0.6), "tuktuk_rod")
    box((0.7, 0.9, 0.9), (0.85, 0, 0.75), "tuktuk_rod")
    box((0.08, 0.86, 0.5), (1.22, 0, 1.4), "ruta")
    box((2.5, 1.36, 0.08), (0.05, 0, 1.85), "tuktuk_bla")
    for x, y in ((-1.15, -0.64), (-1.15, 0.64), (1.15, -0.4), (1.15, 0.4)):
        tube((x, y, 0.9), (x, y, 1.85), 0.03, "metall_mork", verts=4)
    box((0.9, 1.2, 0.3), (-0.6, 0, 1.0), "matta_rod")                                              # back seat
    box((0.2, 1.2, 0.5), (-1.05, 0, 1.25), "matta_rod")
    for x, y in ((-0.8, -0.62), (-0.8, 0.62), (1.0, 0.0)):
        cyl(0.26, 0.16, (x, y, 0.26), "dack", verts=10, rot=(math.pi / 2, 0, 0))
    box((0.05, 0.2, 0.14), (1.21, 0, 0.9), "lykta_gul")
    gestalt(0.35, 0, 0.42, robe="galabeya_brun", hat="kepa", pose="forward", legs="byxor", seated=True, h=1.6)
    export("tuktuk", bevel=0.0)


def flodpram():
    """A river barge on the Nile: a long dark steel hull with rust streaks, a load of sugar cane and
    a white wheelhouse at the stern; 30 m, faces +X."""
    hull(30.0, 7.0, 1.8, "pram_skrov")
    for x in (-10.0, -2.0, 6.0):
        box((1.2, 7.06, 0.6), (x, 0, -0.2), "rost")
    for k in range(5):
        box((3.6, 5.6, 1.4), (-6.0 + k * 3.9, 0, 0.9), "sockerror")
        box((3.6, 5.62, 0.12), (-6.0 + k * 3.9, 0, 1.2), "tra_mork")
    box((3.4, 4.6, 2.6), (-12.0, 0, 1.55), "kryss_vit")
    box((3.42, 4.0, 0.7), (-12.0, 0, 2.3), "ruta")
    box((3.8, 5.0, 0.15), (-12.0, 0, 2.9), "metall_mork")
    tube((-13.6, 0, 3.0), (-13.6, 0, 5.5), 0.05, "metall", verts=4)
    for k, m in enumerate(("eg_rod", "vit", "eg_svart")):
        box((0.06, 1.2, 0.25), (-13.6, 0.6, 5.3 - k * 0.25), m)
    export("flodpram", bevel=0.0)


def kryssningsbat():
    """A Nile cruise boat: a white hull with a blue stripe, three decks of windows (some lit), a
    sun deck with awnings and loungers, and the bridge forward; 56 m, faces +X."""
    hull(56.0, 11.0, 2.4, "kryss_vit", stripe="kryss_bla")
    for d in range(3):
        z = 1.4 + d * 2.6
        box((48.0 - d * 2.0, 10.4, 2.6), (-2.0 - d * 0.6, 0, z), "kryss_vit")
        n = 22 - d
        for k in range(n):
            x = -25.0 + d * 0.8 + (k + 0.5) * (46.0 - d * 2.0) / n
            for side in (-1, 1):
                box((1.1, 0.06, 1.0), (x, side * 5.22, z + 0.2), "fonster" if (k * 7 + d * 3) % 5 == 0 else "ruta")
        box((48.4 - d * 2.0, 10.6, 0.15), (-2.0 - d * 0.6, 0, z + 1.33), "kryss_bla")
    top = 1.4 + 2 * 2.6 + 1.4                                                                       # sun deck
    box((5.0, 9.0, 2.2), (18.0, 0, top + 1.1), "kryss_vit")                                         # bridge
    box((0.1, 8.0, 1.0), (20.55, 0, top + 1.4), "ruta")
    for k in range(4):
        box((6.0, 9.6, 0.1), (-20.0 + k * 9.0, 0, top + 2.4), "markis_vit")
        for side in (-1, 1):
            tube((-22.8 + k * 9.0, side * 4.6, top), (-22.8 + k * 9.0, side * 4.6, top + 2.4), 0.05, "metall", verts=4)
        for j in range(3):
            box((1.8, 0.7, 0.3), (-21.0 + k * 9.0 + (j % 2), -3.0 + j * 3.0, top + 0.15), "tuktuk_bla")
    box((6.0, 4.0, 0.3), (6.0, 0, top + 0.15), "nubisk_turkos")                                     # pool
    for side in (-1, 1):                                                                          # deck rails
        box((43.0, 0.06, 0.06), (-3.5, side * 5.0, top + 1.0), "metall")
        for k in range(12):
            box((0.05, 0.05, 1.0), (-25.0 + k * 3.9, side * 5.0, top + 0.5), "metall")
    for k, m in enumerate(("eg_rod", "vit", "eg_svart")):
        box((0.06, 1.4, 0.3), (-24.5, 0.7, top + 3.3 - k * 0.3), m)
    tube((-24.5, 0, top), (-24.5, 0, top + 3.5), 0.06, "metall", verts=4)
    export("kryssningsbat", bevel=0.0)


def fiskebat_nil():
    """A Nile fishing boat: a small blue wooden boat, one fisherman standing to cast the net and one
    sitting at the oars; faces +X."""
    hull(4.6, 1.5, 0.5, "skrov_bla", stripe="relief_gul")
    box((0.3, 1.3, 0.06), (-0.3, 0, 0.12), "tra")
    gestalt(-0.3, 0, -0.05, robe="galabeya_vit", hat="kepa", pose="lap", legs="byxor", seated=True, h=1.65)
    for side in (-1, 1):
        tube((-0.02, side * 0.12, 0.6), (0.6, side * 1.4, 0.0), 0.03, "tra_mork", verts=4)
    gestalt(1.3, 0, 0.02, robe="galabeya_brun", hat="turban", pose="work", h=1.7)
    blob(0.3, (1.75, 0.2, 1.05), "nat_bla", scale=(1.0, 1.6, 0.6), jitter=0.3, seed=4)
    export("fiskebat_nil", bevel=0.0)


def barn(name, trikot):
    gestalt(robe=trikot, legs="bare", shirt=trikot, pose="sides", h=1.25)
    export(name, bevel=0.0)


def fotboll():
    blob(0.11, (0, 0, 0.11), "fotboll_vit", jitter=0.0, subdiv=2)
    for a, b in ((0, 0), (1.2, 0.6), (2.4, -0.4), (3.6, 0.9), (4.8, -0.8), (1.0, 2.6)):
        dot((math.cos(a) * math.cos(b) * 0.1, math.sin(a) * math.cos(b) * 0.1, 0.11 + math.sin(b) * 0.1), 0.017, "eg_svart")
    export("fotboll", bevel=0.0)


def kamel_kropp(z=1.15):
    blob(1.0, (0, 0, z + 0.85), "kamel", scale=(1.2, 0.5, 0.5), jitter=0.05, subdiv=1, seed=1)
    blob(0.5, (-0.05, 0, z + 1.35), "kamel", scale=(1.0, 0.8, 0.9), jitter=0.05, seed=2)
    tube((0.95, 0, z + 1.0), (1.45, 0, z + 1.8), 0.16, "kamel", verts=6)
    tube((1.45, 0, z + 1.8), (1.75, 0, z + 1.85), 0.15, "kamel", verts=6)
    blob(0.2, (1.85, 0, z + 1.85), "kamel_mork", scale=(1.4, 0.8, 0.8), jitter=0.0)
    for y in (-0.08, 0.08):
        dot((1.75, y, z + 2.02), 0.04, "kamel_mork")
    for (x, y) in ((0.75, -0.25), (0.75, 0.25), (-0.75, -0.25), (-0.75, 0.25)):
        tube((x, y, z + 0.6), (x + 0.05, y, 0.0), 0.09, "kamel", verts=5)
        box((0.22, 0.2, 0.06), (x + 0.07, y, 0.03), "kamel_mork")


def turist_kamel():
    """A tourist in a sun hat riding a camel with a tasselled saddle and rugs; faces +X."""
    kamel_kropp()
    box((1.0, 1.1, 0.35), (-0.05, 0, 2.5), "matta_rod")
    box((1.04, 1.14, 0.08), (-0.05, 0, 2.3), "markis_gul")
    for side in (-1, 1):
        for k in range(4):
            dot((-0.45 + k * 0.3, side * 0.58, 2.2), 0.05, "markis_gul")
    gestalt(-0.25, 0, 2.2, robe="turist_shorts", skin="hud_ljus", shirt="turist_skjorta", hat="hatt", hat_col="halm",
            pose="lap", legs="turist_shorts", seated=True)
    export("turist_kamel", bevel=0.0)


def arkeolog(name):
    if name == "arkeolog_1":
        """Kneeling at a sieve with a brush."""
        box((0.35, 0.35, 0.3), (-0.05, 0, 0.15), "tra")
        gestalt(0.0, 0, -0.15, robe="khaki", skin="hud_ljus", hat="hatt", pose="work", legs="khaki", seated=True)
        box((0.7, 0.5, 0.08), (0.7, 0.05, 0.3), "tra_mork")
        cyl(0.25, 0.3, (0.75, -0.6, 0.15), "markis_gul", verts=8)
        box((0.4, 0.3, 0.1), (0.5, 0.5, 0.05), "kalksten_ljus")
    else:
        """Standing with a clipboard, a tape measure at the belt."""
        gestalt(robe="khaki", skin="hud_ljus", hat="hatt", pose="lap", legs="khaki", shirt="vit")
        box((0.05, 0.25, 0.32), (0.33, 0, 1.12), "tra_mork")
        box((0.03, 0.22, 0.28), (0.36, 0, 1.12), "vit")
        cyl(0.06, 0.06, (0.0, -0.2, 0.95), "markis_gul", verts=8, rot=(math.pi / 2, 0, 0))
    export(name, bevel=0.0)


def guide_paraply():
    """A tour guide holding up a closed red umbrella as the group's flag."""
    gestalt(robe="galabeya_bla", hat="kepa", hat_col="vit", pose="wave", legs="byxor", shirt="vit")
    tube((0.06, 0.34, 1.8), (0.06, 0.34, 2.55), 0.015, "metall_mork", verts=4)
    cyl(0.07, 0.5, (0.06, 0.34, 2.35), "markis_rod", verts=8, radius_top=0.02)
    cone(0.03, 0.08, (0.06, 0.34, 2.6), "metall_mork", verts=5)
    export("guide_paraply", bevel=0.0)


def turist(name):
    if name == "turist_1":
        gestalt(robe="turist_shorts", skin="hud_ljus", shirt="turist_skjorta", hat="hatt", hat_col="halm", pose="cup",
                legs="bare")
        box((0.12, 0.16, 0.1), (0.3, 0.1, 1.48), "eg_svart")                                       # camera
    else:
        gestalt(robe="khaki", skin="hud_ljus", shirt="nubisk_turkos", hat="keps", pose="sides", legs="khaki")
        box((0.25, 0.36, 0.45), (-0.27, 0, 1.2), "markis_bla")                                     # backpack
    export(name, bevel=0.0)


def asna():
    """A donkey with a red blanket and saddlebags, standing; faces +X."""
    blob(1.0, (0, 0, 0.82), "asna", scale=(0.62, 0.26, 0.28), jitter=0.0)
    for x in (-0.38, 0.38):
        for y in (-0.14, 0.14):
            tube((x, y, 0.7), (x, y, 0.0), 0.05, "asna", verts=4)
            box((0.1, 0.08, 0.06), (x + 0.02, y, 0.03), "asna_ljus")
    tube((0.5, 0, 0.95), (0.8, 0, 1.25), 0.11, "asna", verts=5)
    blob(0.17, (0.92, 0, 1.2), "asna", scale=(1.5, 0.85, 0.85), jitter=0.0)
    blob(0.08, (1.12, 0, 1.13), "asna_ljus", jitter=0.0)
    for y in (-0.07, 0.07):
        tube((0.84, y, 1.28), (0.74, y * 1.5, 1.62), 0.035, "asna", verts=3)
    tube((-0.52, 0, 0.9), (-0.68, 0, 0.55), 0.025, "asna", verts=3)
    blob(0.04, (-0.69, 0, 0.53), "eg_svart", scale=(1, 1, 1.6), jitter=0.0)                       # tail tuft
    box((0.6, 0.58, 0.06), (0.0, 0, 1.08), "sadel_rod")
    for side in (-1, 1):
        box((0.35, 0.14, 0.35), (0.0, side * 0.32, 0.85), "sack")
    export("asna", bevel=0.0)


def get(name, body, patch):
    """A goat grazing-ready: short legs, swept-back horns, a beard; faces +X."""
    blob(1.0, (0, 0, 0.55), body, scale=(0.42, 0.17, 0.2), jitter=0.05, seed=2)
    blob(0.5, (-0.1, 0.08, 0.6), patch, scale=(0.4, 0.2, 0.3), jitter=0.0)
    for x in (-0.25, 0.25):
        for y in (-0.09, 0.09):
            tube((x, y, 0.45), (x, y, 0.0), 0.035, body, verts=4)
    tube((0.32, 0, 0.6), (0.48, 0, 0.82), 0.07, body, verts=5)
    blob(0.1, (0.56, 0, 0.82), body, scale=(1.5, 0.75, 0.8), jitter=0.0)
    for y in (-0.04, 0.04):
        tube((0.5, y, 0.9), (0.38, y * 2.0, 1.02), 0.02, "horn", verts=3)
        tube((0.52, y * 1.5, 0.86), (0.5, y * 3.5, 0.84), 0.02, body, verts=3)
    tube((0.62, 0, 0.75), (0.6, 0, 0.66), 0.02, patch, verts=3)
    tube((-0.34, 0, 0.6), (-0.48, 0, 0.72), 0.025, body, verts=3)
    export(name, bevel=0.0)


def ibis():
    """A sacred ibis: white body, black head and neck, a long down-curved bill, black plumes."""
    blob(1.0, (0, 0, 0.55), "ibis_vit", scale=(0.24, 0.1, 0.11), jitter=0.0)
    blob(0.5, (-0.24, 0, 0.53), "ibis_svart", scale=(0.25, 0.14, 0.12), jitter=0.2, seed=3)
    tube((0.18, 0, 0.6), (0.26, 0, 0.78), 0.03, "ibis_svart", verts=4)
    blob(0.045, (0.29, 0, 0.8), "ibis_svart", jitter=0.0)
    tube((0.32, 0, 0.79), (0.42, 0, 0.73), 0.012, "ibis_svart", verts=3)
    tube((0.42, 0, 0.73), (0.48, 0, 0.62), 0.01, "ibis_svart", verts=3)
    for y in (-0.04, 0.04):
        tube((0.0, y, 0.5), (0.02, y, 0.0), 0.012, "ibis_svart", verts=3)
    export("ibis", bevel=0.0)


def katt(name, fur, lying):
    """A street cat, sitting up or lying stretched out; faces +X."""
    if lying:
        blob(1.0, (0, 0, 0.09), fur, scale=(0.24, 0.1, 0.085), jitter=0.0, subdiv=2)
        blob(0.07, (0.25, 0, 0.12), fur, scale=(1.0, 1.05, 0.95), jitter=0.0, subdiv=2)
        for y in (-0.05, 0.05):
            tube((0.12, y, 0.04), (0.3, y, 0.02), 0.022, fur, verts=5)                          # forelegs
        tube((-0.2, 0, 0.08), (-0.45, 0.1, 0.03), 0.02, fur, verts=4)
        for y in (-0.03, 0.03):
            cone(0.025, 0.05, (0.26, y, 0.19), fur)
            dot((0.31, y, 0.13), 0.009, "eg_svart")
    else:
        blob(1.0, (-0.02, 0, 0.12), fur, scale=(0.13, 0.09, 0.12), jitter=0.0, subdiv=2)             # haunches
        taper((0.0, 0, 0.12), (0.05, 0, 0.28), 0.08, 0.06, fur, verts=6)                            # chest
        for y in (-0.035, 0.035):
            tube((0.07, y, 0.22), (0.08, y, 0.01), 0.018, fur, verts=5)                            # forelegs
        blob(0.065, (0.06, 0, 0.32), fur, scale=(1.0, 1.1, 0.95), jitter=0.0, subdiv=2)
        dot((0.12, 0, 0.31), 0.012, "eg_svart")
        for y in (-0.03, 0.03):
            cone(0.025, 0.05, (0.05, y, 0.39), fur)
            dot((0.115, y, 0.335), 0.009, "eg_svart")
        tube((-0.12, 0, 0.04), (-0.15, 0.12, 0.02), 0.018, fur, verts=4)
        tube((-0.15, 0.12, 0.02), (-0.05, 0.16, 0.02), 0.018, fur, verts=4)
    export(name, bevel=0.0)


def vattenbuffel():
    """A water buffalo, dark grey with big swept-back horns; faces +X."""
    blob(1.0, (0, 0, 1.0), "buffel", scale=(1.05, 0.45, 0.5), jitter=0.05, seed=3)
    for x in (-0.65, 0.65):
        for y in (-0.25, 0.25):
            tube((x, y, 0.75), (x, y, 0.0), 0.1, "buffel", verts=5)
    blob(0.3, (1.15, 0, 1.05), "buffel", scale=(1.2, 0.9, 0.9), jitter=0.05, seed=4)
    blob(0.15, (1.45, 0, 0.92), "eg_svart", scale=(0.9, 1.0, 0.8), jitter=0.0)
    for side in (-1, 1):
        tube((1.12, side * 0.14, 1.2), (1.0, side * 0.55, 1.35), 0.05, "horn", verts=4)
        tube((1.0, side * 0.55, 1.35), (0.8, side * 0.6, 1.5), 0.035, "horn", verts=4)
    tube((-0.8, 0, 1.2), (-1.1, 0, 0.55), 0.035, "buffel", verts=4)
    export("vattenbuffel", bevel=0.0)


def tehus():
    """A tea house: an open shopfront with a counter and kettle, a striped awning, and three low
    tables on the street where men sit over glasses of tea; faces +X."""
    box((1.6, 5.0, 3.0), (-1.8, 0, 1.5), "puts_sand")
    box((0.1, 3.6, 2.2), (-0.98, 0, 1.1), "fonster_mork")
    box((0.6, 2.8, 1.0), (-0.6, 0, 0.5), "trä_ljus")
    cyl(0.18, 0.4, (-0.6, -0.8, 1.2), "guld", verts=8)
    for k in range(5):
        box((2.6, 1.0, 0.05), (0.3, -2.0 + k * 1.0, 2.6), "markis_rod" if k % 2 == 0 else "markis_vit", rot=(0, 0.25, 0))
    tube((1.55, -2.45, 0.0), (1.55, -2.45, 2.3), 0.04, "tra_mork", verts=4)
    tube((1.55, 2.45, 0.0), (1.55, 2.45, 2.3), 0.04, "tra_mork", verts=4)
    rnd = random.Random(5)
    for t, (tx, ty) in enumerate(((0.9, -1.4), (1.1, 0.6), (2.6, -0.3))):
        cyl(0.35, 0.05, (tx, ty, 0.55), "trä_ljus", verts=10)
        tube((tx, ty, 0.0), (tx, ty, 0.55), 0.04, "metall_mork", verts=4)
        for n in range(3):
            cyl(0.03, 0.08, (tx + rnd.uniform(-0.15, 0.15), ty + rnd.uniform(-0.15, 0.15), 0.62), "te_glas", verts=6)
        seats = ((tx - 0.75, ty, 0.0), (tx + 0.75, ty, math.pi)) if t < 2 else ((tx, ty - 0.75, math.pi / 2),)
        for (sx, sy, yaw) in seats:
            box((0.4, 0.4, 0.45), (sx - math.cos(yaw) * 0.1, sy - math.sin(yaw) * 0.1, 0.22), "tra_mork")
    # The men, built facing +X and turned to their tables.
    for (sx, sy, yaw, robe, hat, pose) in ((0.15, -1.4, 0.0, "galabeya_gra", "kepa", "cup"), (1.85, 0.6, math.pi, "galabeya_bla", "turban", "lap"),
                                           (0.35, 0.6, 0.0, "galabeya_vit", None, "cup"), (2.6, -1.05, math.pi / 2, "galabeya_brun", "kepa", "lap")):
        before = set(bpy.data.objects)
        gestalt(robe=robe, hat=hat, pose=pose, seated=True)
        turn_new(before, yaw, (sx, sy, 0.0))
    export("tehus", bevel=0.0)


def vattenpipscafe():
    """A shisha café: low stools round brass trays, men smoking water pipes, a hanging lantern and
    a green awning; faces +X."""
    box((1.4, 6.0, 3.2), (-1.8, 0, 1.6), "puts_ockra")
    box((0.1, 4.6, 2.3), (-1.08, 0, 1.15), "fonster_mork")
    box((3.0, 6.2, 0.06), (0.35, 0, 2.7), "markis_gron", rot=(0, 0.2, 0))
    for y in (-3.0, 3.0):
        tube((1.7, y, 0.0), (1.7, y, 2.45), 0.04, "metall_mork", verts=4)
    cyl(0.12, 0.3, (0.8, 0, 2.2), "lykta_gul", verts=6)
    tube((0.8, 0, 2.35), (0.8, 0, 2.62), 0.01, "metall_mork", verts=3)
    for (tx, ty) in ((0.6, -1.6), (1.4, 1.2)):
        cyl(0.4, 0.04, (tx, ty, 0.45), "guld", verts=12)
        tube((tx, ty, 0.0), (tx, ty, 0.45), 0.05, "tra_mork", verts=4)
        blob(0.15, (tx + 0.45, ty + 0.3, 0.18), "shisha_glas", scale=(1, 1, 1.2), jitter=0.0)        # the pipe
        tube((tx + 0.45, ty + 0.3, 0.25), (tx + 0.45, ty + 0.3, 0.75), 0.025, "guld", verts=5)
        cyl(0.07, 0.08, (tx + 0.45, ty + 0.3, 0.8), "terrakotta", verts=6)
        tube((tx + 0.45, ty + 0.3, 0.4), (tx - 0.3, ty + 0.1, 0.95), 0.015, "eg_svart", verts=3)
    for (sx, sy, yaw, robe, hat) in ((-0.15, -1.6, 0.0, "galabeya_gra", "kepa"), (1.35, -1.6, math.pi, "galabeya_vit", "turban"),
                                     (0.65, 1.2, 0.0, "galabeya_brun", None), (1.4, 1.95, -math.pi / 2, "galabeya_bla", "kepa")):
        box((0.38, 0.38, 0.4), (sx - math.cos(yaw) * 0.12, sy - math.sin(yaw) * 0.12, 0.2), "tra_mork")
        before = set(bpy.data.objects)
        gestalt(robe=robe, hat=hat, pose="cup", seated=True)
        turn_new(before, yaw, (sx, sy, 0.0))
    export("vattenpipscafe", bevel=0.0)


def tvattlina_eg():
    """Washing hung out between two poles: galabeyas, shirts and towels in many colours."""
    for y in (-3.0, 3.0):
        tube((0, y, 0.0), (0, y, 2.6), 0.04, "tra_mork", verts=4)
    tube((0, -3.0, 2.5), (0, 3.0, 2.5), 0.01, "eg_svart", verts=3)
    cols = ["galabeya_bla", "markis_rod", "galabeya_vit", "markis_gul", "nubisk_turkos", "galabeya_gra", "matta_rod", "markis_vit"]
    for k, m in enumerate(cols):
        y = -2.6 + k * 0.74
        h = 1.1 if k % 3 == 0 else 0.7
        box((0.03, 0.55, h), (0, y, 2.5 - h / 2), m)
    export("tvattlina_eg", bevel=0.0)


def parabol():
    """A satellite dish on a roof stand."""
    tube((0, 0, 0.0), (0, 0, 0.6), 0.03, "metall", verts=4)
    for a in (0.0, 2.1, 4.2):
        tube((math.cos(a) * 0.3, math.sin(a) * 0.3, 0.0), (0, 0, 0.4), 0.015, "metall", verts=3)
    tube((0, 0, 0.55), (0.06, 0, 0.78), 0.03, "metall", verts=4)
    cyl(0.42, 0.1, (0.1, 0, 0.8), "parabol_vit", verts=12, radius_top=0.38, rot=(0, math.radians(60), 0))
    tube((0.12, 0, 0.8), (0.55, 0, 0.62), 0.012, "metall", verts=3)
    box((0.08, 0.06, 0.06), (0.55, 0, 0.62), "metall_mork")
    export("parabol", bevel=0.0)


def fruktstand():
    """A fruit stall under an umbrella: crates of oranges, mangoes, bananas and melons on a trestle
    table, the seller sitting behind it; faces +X."""
    box((1.2, 2.6, 0.06), (0.4, 0, 0.85), "tra")
    for y in (-1.1, 1.1):
        for x in (-0.1, 0.9):
            tube((x, y, 0.0), (x, y, 0.85), 0.03, "tra_mork", verts=4)
    fruit = (("apelsin", 0.07), ("mango", 0.07), ("banan_gul", 0.05), ("melon", 0.13))
    for k, (m, r) in enumerate(fruit):
        y = -0.95 + k * 0.63
        box((0.9, 0.55, 0.12), (0.45, y, 0.94), "tra_mork")
        for i in range(3 if m == "melon" else 6):
            for j in range(2):
                dot((0.15 + i * (0.6 / (2 if m == "melon" else 5)), y - 0.15 + j * 0.3, 1.04 + r * 0.5), r, m)
    tube((-0.4, 0, 0.0), (-0.4, 0, 2.4), 0.03, "metall", verts=4)
    cyl(1.6, 0.4, (-0.4, 0, 2.5), "markis_gul", verts=8, radius_top=0.05)
    box((0.4, 0.4, 0.45), (-0.6, 0.3, 0.22), "tra_mork")
    gestalt(-0.5, 0.3, 0.0, robe="galabeya_brun", hat="turban", pose="lap", seated=True)
    export("fruktstand", bevel=0.0)


def mattforsaljare():
    """A carpet seller by the road: a wooden rack hung with patterned carpets, rolls on the ground,
    the seller beckoning; faces +X."""
    for y in (-2.2, 2.2):
        tube((-0.5, y, 0.0), (-0.5, y, 2.6), 0.05, "tra_mork", verts=4)
    tube((-0.5, -2.3, 2.5), (-0.5, 2.3, 2.5), 0.04, "tra_mork", verts=4)
    for k, (m, band) in enumerate((("matta_rod", "markis_gul"), ("matta_bla", "matta_beige"), ("matta_beige", "matta_rod"),
                                   ("matta_rod", "matta_bla"))):
        y = -1.6 + k * 1.07
        box((0.04, 0.95, 2.0), (-0.48, y, 1.48), m)
        box((0.05, 0.8, 0.12), (-0.47, y, 2.2), band)
        box((0.05, 0.8, 0.12), (-0.47, y, 0.75), band)
        box((0.05, 0.3, 0.3), (-0.47, y, 1.48), band, rot=(math.pi / 4, 0, 0))
    for k, m in enumerate(("matta_bla", "matta_rod", "matta_beige")):
        cyl(0.16, 1.6, (0.3 + k * 0.35, -1.2, 0.16), m, verts=8, rot=(math.pi / 2, 0, 0))
    gestalt(0.4, 1.0, 0.0, robe="galabeya_vit", hat="kepa", pose="wave")
    export("mattforsaljare", bevel=0.0)


bpy.ops.wm.read_factory_settings(use_empty=True)
only = sys.argv[sys.argv.index("--") + 2:] if "--" in sys.argv else []
BUILDS = [
    ("pyramid_stor", lambda: pyramid("pyramid_stor", 200.0, 125.0, 80, broken_top=0.04)),
    ("pyramid_mellan", lambda: pyramid("pyramid_mellan", 180.0, 115.0, 72, cap=0.18)),
    ("pyramid_liten", lambda: pyramid("pyramid_liten", 100.0, 62.0, 40)),
    ("pyramid_drottning", lambda: pyramid("pyramid_drottning", 40.0, 26.0, 16)),
    ("sfinx", sfinx), ("obelisk", obelisk), ("pylon", pylon), ("kolonnad", kolonnad), ("sfinx_liten", sfinx_liten),
    ("staty_farao", staty_farao),
    ("hus_kairo_1", lambda: hus_kairo("hus_kairo_1", 1, 8.0, 8.0, 3, "puts_sand")),
    ("hus_kairo_2", lambda: hus_kairo("hus_kairo_2", 2, 10.0, 7.0, 4, "puts_rosa")),
    ("hus_kairo_3", lambda: hus_kairo("hus_kairo_3", 3, 7.0, 7.0, 2, "puts_vit")),
    ("hus_kairo_4", lambda: hus_kairo("hus_kairo_4", 4, 9.0, 8.0, 3, "puts_ockra")),
    ("moske", moske), ("minaret", minaret),
    ("basar_kryddor", lambda: basarstand("basar_kryddor", "markis_rod", "kryddor", 1)),
    ("basar_mattor", lambda: basarstand("basar_mattor", "markis_gron", "mattor", 2)),
    ("basar_lyktor", lambda: basarstand("basar_lyktor", "markis_bla", "lyktor", 3)),
    ("basar_krukor", lambda: basarstand("basar_krukor", "markis_gul", "krukor", 4)),
    ("markis", markis),
    ("palm_1", lambda: palm(1, 9.0)), ("palm_2", lambda: palm(2, 11.5)), ("palm_3", lambda: palm(3, 7.0)),
    ("bananplanta_1", lambda: bananplanta(1)), ("bananplanta_2", lambda: bananplanta(2)),
    ("papyrus_1", lambda: papyrus(1)), ("papyrus_2", lambda: papyrus(2)),
    ("akacia_1", lambda: akacia(1)), ("akacia_2", lambda: akacia(2)),
    ("buske_torr_1", lambda: buske_torr(1)), ("buske_torr_2", lambda: buske_torr(2)),
    ("klippa_1", lambda: klippa(1)), ("klippa_2", lambda: klippa(2)), ("klippa_3", lambda: klippa(3)),
    ("kamel", lambda: kamel("kamel")), ("kamel_ligg", lambda: kamel("kamel_ligg", lying=True)),
    ("felucca", felucca), ("talt_beduin", talt_beduin), ("lejonstaty", lejonstaty), ("teleportport", teleportport),
    ("talt_vit", talt_vit), ("stralkastare", stralkastare), ("sarkofag", sarkofag),
    ("flakbil", flakbil), ("mumie", mumie), ("farao", farao), ("skarabe", skarabe),
    ("abusimbel", abusimbel), ("terrasstempel", terrasstempel), ("staty_staende", staty_staende),
    ("citadell", citadell),
    ("ballong_1", lambda: ballong("ballong_1", ["ballong_rod", "ballong_gul"])),
    ("ballong_2", lambda: ballong("ballong_2", ["ballong_bla", "ballong_gul", "ballong_gron", "vit"])),
    ("duvtorn", duvtorn), ("vattenhjul", vattenhjul), ("lerhus", lerhus), ("asnekarra", asnekarra),
    ("faros", faros), ("vit_klippa_1", lambda: vit_klippa(1)), ("vit_klippa_2", lambda: vit_klippa(2)),
    ("vit_klippa_3", lambda: vit_klippa(3)), ("granit_1", lambda: granit(1)), ("granit_2", lambda: granit(2)),
    ("gravport", gravport), ("memnon", memnon), ("philae", philae),
    ("hus_nubisk_1", lambda: hus_nubisk("hus_nubisk_1", "nubisk_bla", "nubisk_gul", 1)),
    ("hus_nubisk_2", lambda: hus_nubisk("hus_nubisk_2", "nubisk_gul", "nubisk_turkos", 2)),
    ("hus_nubisk_3", lambda: hus_nubisk("hus_nubisk_3", "nubisk_rosa", "nubisk_bla", 3)),
    ("obelisk_oavslutad", obelisk_oavslutad), ("pelare_pompejus", pelare_pompejus), ("teater", teater),
    ("man_galabeya", man_galabeya), ("kvinna_kruka", kvinna_kruka), ("handlare_karra", handlare_karra),
    ("budcykel", budcykel), ("taxi_kairo", taxi_kairo), ("tuktuk", tuktuk), ("flodpram", flodpram),
    ("kryssningsbat", kryssningsbat), ("fiskebat_nil", fiskebat_nil), ("barn_1", lambda: barn("barn_1", "trikot_rod")),
    ("barn_2", lambda: barn("barn_2", "trikot_bla")), ("fotboll", fotboll), ("turist_kamel", turist_kamel),
    ("arkeolog_1", lambda: arkeolog("arkeolog_1")), ("arkeolog_2", lambda: arkeolog("arkeolog_2")),
    ("guide_paraply", guide_paraply), ("turist_1", lambda: turist("turist_1")), ("turist_2", lambda: turist("turist_2")),
    ("asna", asna), ("get_1", lambda: get("get_1", "get_svart", "get_vit")), ("get_2", lambda: get("get_2", "get_brun", "get_vit")),
    ("ibis", ibis), ("katt_1", lambda: katt("katt_1", "katt_ora", False)), ("katt_2", lambda: katt("katt_2", "katt_gra", True)),
    ("vattenbuffel", vattenbuffel), ("tehus", tehus), ("vattenpipscafe", vattenpipscafe), ("tvattlina_eg", tvattlina_eg),
    ("parabol", parabol), ("fruktstand", fruktstand), ("mattforsaljare", mattforsaljare),
]
for name, build in BUILDS:
    if not only or name in only:
        build()
print("EGYPTENS MODELLER KLARA")
