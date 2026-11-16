"""Every model of the world Japan: Tokyo by night (glass towers, neon streets, Tokyo Tower), old
Kyoto (pagodas, temple halls, torii, machiya houses, lanterns), the castle, gardens, cherry trees,
maples, bamboo and pines, sumo and geishas, the bullet train, the waterfall with the secret dojo,
and the battle (the samurai who throws shuriken, oni, ninjas, fox spirits and the dragon).

    blender --background --python assets/blender/japan_modeller.py -- game/world/japan/models [names …]

Same rules and helpers as skargarden_modeller.py (read from that file without running its builds).
Moving models are exported as loose named parts with their origins at the joints.
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
    "vermiljon": "e0452b", "vermiljon_mork": "a8321c", "tak_gron": "5f8f7c", "tak_gra": "4a5058", "tak_mork": "34383f",
    "guld": "e0b043", "vit_puts": "f2efe6", "sten_gra": "9a9a96", "sten_mork": "6f6f6c", "tra_morkbrun": "4e3220",
    "tra_brun": "7a5030", "papper": "efe4c8", "papper_lyse": "ffd98a", "lykta_rod": "ff4a30", "neon_rosa": "ff4fb0",
    "neon_bla": "4fd0ff", "neon_gron": "6fff8f", "neon_gul": "ffd84a", "neon_lila": "b06bff", "neon_ora": "ff8a2a",
    "glas_bla": "34506e", "glas_mork": "26303c", "fonster_lyse": "ffd890", "fonster_kall": "a8dcff", "betong": "a9a8a2",
    "betong_mork": "7d7c77", "sakura": "f4b2c6", "sakura_ljus": "fbd3df", "sakura_mork": "e489a8", "lonn_rod": "c8402a",
    "lonn_ora": "e07a2a", "bambu": "5f9a3a", "bambu_ljus": "86b84a", "bambu_mork": "3f6a2a", "tall_jp": "2f5a3a",
    "tall_jp2": "3f6e48", "stam_mork": "4a3a30", "hud_jp": "e8c6a8", "kimono_rod": "c0302a", "kimono_bla": "2a4a8a",
    "kimono_lila": "7a3a8a", "obi_guld": "e0b043", "vit_smink": "f6f1ea", "har_svart": "1a1a1e", "mawashi": "3a3a6a",
    "rustning_rod": "a8281f", "rustning_svart": "2a2a2e", "stal": "9aa2aa", "oni_rod": "c83a2a", "oni_bla": "3a6ac8",
    "tiger": "e0a030", "ninja_svart": "24242a", "ninja_bla": "2a3048", "kitsune_vit": "f2ede2", "kitsune_eld": "6fd0ff",
    "drake_rod": "c0302a", "drake_gron": "2f8a5a", "drake_guld": "e0b043", "vatten_fall": "dff0f8", "vatten_skum": "f6fbff",
    "torn_rod": "e8501a", "torn_vit": "f4f1ea", "torn_lyse": "ffb060", "shinkansen_vit": "f4f6f8", "shinkansen_bla": "1f4aa0",
    "dohyo_lera": "c9a46a", "rep": "e6dcc0", "tofs_bla": "2a5ad0", "tofs_rod": "d02a2a", "tofs_vit": "f4f4f0",
    "tofs_svart": "1a1a1e", "automat_vit": "eef0f2", "automat_lyse": "e8f4ff", "portal": "6fe8ff", "sand_kratt": "e4ddc8",
    "dimma": "c8d0e0", "rod_ljus": "ff2a2a",
    # Street life
    "kostym": "2a2e3a", "skoluniform": "f2f2ee", "kjol_bla": "1f2a4a", "bil_vit_jp": "eef0ee", "bil_bla_jp": "6f9acf",
    "kraka": "1c1c22", "koi_ora": "f07a2a", "koi_vit": "f4f0e8", "batskrov": "5a3a22", "post_rod": "d0281f",
    # Temple, village and paddies
    "tanuki_brun": "8a6a4a", "tanuki_ljus": "d8c8a8", "munk_ora": "d0782a", "halm_jp": "c8a860", "hager_vit": "f2f2ec",
    "hager_gul": "e0b030", "vimpel_bla": "2a4ab0", "vimpel_rod": "d03a2a", "vimpel_svart": "26262a", "turist_rod": "c84a3a",
    # The bigger Japan: cedars, tea, ginkgo, the gassho valley, the inn, Odaiba and the fishing port
    "sugi": "2c4632", "sugi_ljus": "3e5c3c", "te_gron": "3d7430", "te_ljus": "6a9e3e", "ginkgo": "9cc24e",
    "ginkgo_mork": "76a03c", "halm_tak": "7d6a4a", "halm_tak_mork": "5c4e38", "skrov_vit": "eef2f2",
    "skrov_bla": "2a5a9a", "lampa_vit": "fff2d0", "fyr_rod": "d8301f", "hjul_vit": "e6eaf0", "mosen": "c8281f",
    # The living Japan: people, animals, vehicles and the festival
    "miko_rod": "c8281f", "randoseru": "b0201c", "hatt_gul": "f2c230", "happi_bla": "2a4a9a", "happi_rod": "c83a2a",
    "yukata_bla": "3a5ab0", "yukata_rosa": "e88aa8", "kasuri": "2a3a5a", "taxi_svart": "1c1c22", "taxi_gul": "e8b830",
    "gronsak": "5a9a3a", "apelsin": "e88a2a", "svan_vit": "f2f2ee", "nab_gul": "e0a020", "hjort_brun": "8a5a34",
    "hjort_ljus": "e8dcc0", "trana_vit": "f6f6f2", "trana_svart": "1c1c20", "trana_rod": "d0202a", "katt_vit": "f0ece4",
    "katt_ora": "d8822a", "katt_svart": "26242a", "apa_fall": "8a7a68", "apa_ansikte": "d86a6a", "shiba": "c8803a",
    "shiba_ljus": "f0e4d0", "pachinko_vagg": "e8e4dc", "telefon_gron": "3a9a5a", "brons": "8a6a3a", "ema_tra": "c8a070",
    "nobori_rod": "d0302a", "nobori_bla": "2a4ab0", "nobori_gul": "e8c040", "nobori_vit": "f4f2ea",
    "markis_rod_jp": "d02a2a", "markis_vit_jp": "f4f2ea", "kingyo_bla": "3a7ad0", "trafik_gra": "8a9098",
    "lampa_gron": "3affb0", "lampa_rod": "ff3a2a", "lampa_av": "2a3a34", "neon_vit": "f4f8ff",
})
EMISSIVE.update({"papper_lyse": 0.8, "lykta_rod": 1.1, "neon_rosa": 0.7, "neon_bla": 0.7, "neon_gron": 0.6,
                 "neon_gul": 0.6, "neon_lila": 0.8, "neon_ora": 0.6, "fonster_lyse": 0.55, "fonster_kall": 0.5,
                 "torn_lyse": 1.4, "kitsune_eld": 2.5, "automat_lyse": 0.8, "portal": 1.4, "rod_ljus": 3.0,
                 "lampa_vit": 1.6, "lampa_gron": 2.2, "lampa_rod": 2.2, "neon_vit": 0.7})


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


def hip_roof(hw, hd, z, h, material, ridge=0.25, lift=0.35):
    """A hipped Japanese roof: wide eaves (half-sizes hw, hd at height z) rising to a short ridge,
    the corners lifted a little like the curved eaves of temples."""
    # The eave runs flat at z along most of each side and sweeps up to z + lift only at the corners,
    # so the roof rests on the walls; the underside is flat at z (it used to lift as a whole).
    bm = bmesh.new()
    rw, rd = hw * ridge, max(hd * 0.04, 0.05)
    corners = ((-hw, -hd), (hw, -hd), (hw, hd), (-hw, hd))
    ring = []                                    # per side: corner, then two points along the edge
    for i in range(4):
        (x0, y0), (x1, y1) = corners[i], corners[(i + 1) % 4]
        ring.append(bm.verts.new((x0, y0, z + lift)))
        for t in (0.22, 0.78):
            ring.append(bm.verts.new((x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, z + lift * 0.12)))
    hi = [bm.verts.new((x, y, z + h)) for x, y in ((-rw, -rd), (rw, -rd), (rw, rd), (-rw, rd))]
    under = bm.verts.new((0, 0, z))
    flat = [bm.verts.new((x * 0.7, y * 0.7, z)) for x, y in corners]
    bm.faces.new(hi)
    for i in range(4):
        j = (i + 1) % 4
        c0, e1, e2, c1 = ring[i * 3], ring[i * 3 + 1], ring[i * 3 + 2], ring[(i * 3 + 3) % 12]
        bm.faces.new((c0, e1, hi[i]))
        bm.faces.new((e1, e2, hi[j], hi[i]))
        bm.faces.new((e2, c1, hi[j]))
        # Underside: a flat square at z (on the walls) and a sloping band out to the eave.
        bm.faces.new((flat[j], flat[i], under))
        bm.faces.new((e1, c0, flat[i]))
        bm.faces.new((e2, e1, flat[i], flat[j]))
        bm.faces.new((c1, e2, flat[j]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new("tak")
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new("tak", me)
    bpy.context.collection.objects.link(o)
    o.data.materials.append(mat(material))
    return o


def railing(hw, hd, z, material):
    """A low balcony railing round a square storey."""
    for side in (-1, 1):
        box((hw * 2, 0.08, 0.08), (0, side * hd, z + 0.6), material)
        box((0.08, hd * 2, 0.08), (side * hw, 0, z + 0.6), material)
        for k in range(5):
            t = -hw + (k + 0.5) * hw * 2 / 5
            box((0.06, 0.06, 0.6), (t, side * hd, z + 0.3), material)
            box((0.06, 0.06, 0.6), (side * hw, t, z + 0.3), material)


# --- Temples and shrines --------------------------------------------------------------------------

def pagoda(name, storeys, base, height, roof_mat, body_mat):
    """A pagoda of `storeys` floors, each a little narrower, with deep eaves, a balcony per floor,
    and the bronze spire (sorin) with its nine rings on top."""
    box((base + 3.0, base + 3.0, 1.2), (0, 0, 0.6), "sten_gra")
    z = 1.2
    step = (height * 0.72) / storeys
    for k in range(storeys):
        w = base * (1.0 - k * 0.11)
        box((w, w, step * 0.62), (0, 0, z + step * 0.31), body_mat)
        for side in (-1, 1):
            box((w * 0.5, 0.06, step * 0.4), (0, side * (w / 2 + 0.02), z + step * 0.3), "vit_puts")
            box((0.06, w * 0.5, step * 0.4), (side * (w / 2 + 0.02), 0, z + step * 0.3), "vit_puts")
        if k > 0:
            railing(w / 2 + 0.6, w / 2 + 0.6, z, body_mat)
            box((w + 1.2, w + 1.2, 0.15), (0, 0, z + 0.05), "tra_brun")
        hip_roof(w / 2 + 2.6, w / 2 + 2.6, z + step * 0.62, step * 0.42, roof_mat, ridge=0.18, lift=0.55)
        z += step
    top = z + step * 0.04 - 0.3                       # just inside the top roof's ridge
    cyl(0.25, height - top, (0, 0, (top + height) / 2), "guld", verts=8)
    for k in range(9):
        cyl(0.55, 0.12, (0, 0, top + 1.0 + k * (height - top - 2.5) / 9), "guld", verts=10)
    cone(0.4, 1.2, (0, 0, height + 0.3), "guld", verts=8)
    export(name, bevel=0.0)


def tempelhall():
    """A temple hall 30 × 18 m: stone platform and steps, vermilion pillars, white walls, a great
    hipped roof with gold ornaments at the ends of the ridge; the front faces -Y."""
    box((32.0, 20.0, 1.6), (0, 0, 0.8), "sten_gra")
    box((8.0, 3.0, 1.0), (0, -11.2, 0.5), "sten_gra")
    box((26.0, 14.0, 7.5), (0, 0, 5.35), "vit_puts")
    for x in (-12.0, -6.0, 0.0, 6.0, 12.0):
        for y in (-7.4, 7.4):
            cyl(0.45, 7.5, (x, y, 5.35), "vermiljon", verts=8)
    for x in (-9.0, -3.0, 3.0, 9.0):
        box((4.0, 0.1, 4.5), (x, -7.05, 4.6), "papper_lyse" if x in (-3.0, 3.0) else "vermiljon_mork")
    box((28.0, 16.0, 0.6), (0, 0, 9.4), "vermiljon_mork")
    hip_roof(18.5, 12.5, 9.6, 7.5, "tak_gron", ridge=0.55, lift=1.0)
    box((21.0, 0.6, 0.8), (0, 0, 17.3), "tak_mork")
    for x in (-10.2, 10.2):
        cone(0.5, 1.6, (x, 0, 18.2), "guld", verts=6)
    export("tempelhall", bevel=0.0)


def torii(name="torii", big=False):
    """A vermilion torii gate (6 m, the big one 12 m): two pillars on black feet, the black-capped
    upper beam with its ends turned up, and the tie beam."""
    s = 2.0 if big else 1.0
    for y in (-2.4 * s, 2.4 * s):
        cyl(0.24 * s, 5.4 * s, (0, y, 2.7 * s), "vermiljon", verts=8)
        cyl(0.3 * s, 0.5 * s, (0, y, 0.25 * s), "tak_mork", verts=8)
    box((0.5 * s, 6.4 * s, 0.4 * s), (0, 0, 4.6 * s), "vermiljon")                    # nuki
    box((0.6 * s, 7.4 * s, 0.45 * s), (0, 0, 5.55 * s), "vermiljon")                  # shimaki
    box((0.7 * s, 7.9 * s, 0.3 * s), (0, 0, 5.9 * s), "tak_mork")                      # kasagi
    for y in (-1, 1):
        box((0.7 * s, 0.9 * s, 0.3 * s), (0, y * 4.2 * s, 6.0 * s), "tak_mork", rot=(y * 0.3, 0, 0))
    box((0.3 * s, 0.4 * s, 1.0 * s), (0, 0, 5.1 * s), "vermiljon")
    export(name, bevel=0.0)


def stenlykta():
    """A stone lantern (toro) 2.4 m: foot, post, a lit firebox and a curved cap."""
    cyl(0.5, 0.25, (0, 0, 0.12), "sten_gra", verts=6)
    cyl(0.18, 1.0, (0, 0, 0.75), "sten_gra", verts=8)
    box((0.7, 0.7, 0.2), (0, 0, 1.3), "sten_mork")
    box((0.5, 0.5, 0.5), (0, 0, 1.65), "sten_gra")
    box((0.3, 0.52, 0.28), (0, 0, 1.65), "papper_lyse")
    box((0.52, 0.3, 0.28), (0, 0, 1.65), "papper_lyse")
    cyl(0.6, 0.35, (0, 0, 2.05), "sten_mork", verts=6, radius_top=0.12)
    dot((0, 0, 2.35), 0.1, "sten_gra")
    export("stenlykta", bevel=0.0)


def lyktsnore():
    """A string of red paper lanterns 10 m long, hung across a street (along X)."""
    tube((-5.0, 0, 5.6), (5.0, 0, 5.6), 0.02, "tak_mork", verts=3)
    for k in range(8):
        x = -4.4 + k * 1.25
        sag = 0.25 * math.sin(k / 7 * math.pi)
        tube((x, 0, 5.6), (x, 0, 5.3 - sag), 0.01, "tak_mork", verts=3)
        blob(0.24, (x, 0, 5.0 - sag), "lykta_rod", scale=(1.0, 1.0, 1.35), jitter=0.0)
        cyl(0.13, 0.08, (x, 0, 5.32 - sag), "tak_mork", verts=6)
        cyl(0.13, 0.08, (x, 0, 4.68 - sag), "tak_mork", verts=6)
    export("lyktsnore", bevel=0.0)


# --- Old town -------------------------------------------------------------------------------------

def machiya(name, seed, floors):
    """A wooden townhouse (machiya) 6 m wide facing -Y: dark lattice front, tiled roofs over each
    floor, lit paper windows, a noren curtain and a red lantern at the door."""
    rnd = random.Random(seed)
    w, d = 6.0, 9.0
    h1 = 3.2
    box((w, d, h1), (0, 0, h1 / 2), "tra_morkbrun")
    for k in range(9):
        box((0.06, 0.08, 2.2), (-2.4 + k * 0.4, -d / 2 - 0.02, 1.5), "tra_brun")             # koshi lattice
    box((3.6, 0.06, 2.0), (-0.6, -d / 2 + 0.01, 1.4), "papper_lyse")
    for x in (-w / 2, w / 2):                                                                   # corner posts
        box((0.22, 0.22, h1), (x, -d / 2, h1 / 2), "tra_brun")
    box((w + 0.1, 0.24, 0.24), (0, -d / 2, h1 - 0.1), "tra_brun")                              # lintel beam
    box((w + 0.1, 0.3, 0.3), (0, -d / 2 + 0.05, 0.15), "sten_mork")                            # stone sill
    box((1.3, 0.06, 1.2), (1.9, -d / 2 - 0.04, 2.2), "kimono_bla" if seed % 2 else "kimono_rod")  # noren
    box((1.5, 0.08, 0.08), (1.9, -d / 2 - 0.06, 2.84), "tra_brun")                            # its rod
    box((0.1, 0.5, 0.1), (2.7, -d / 2 - 0.25, 2.95), "tra_brun")                               # lantern arm
    tube((2.7, -d / 2 - 0.45, 2.95), (2.7, -d / 2 - 0.45, 2.7), 0.015, "tak_mork", verts=3)
    blob(0.22, (2.7, -d / 2 - 0.45, 2.4), "lykta_rod", scale=(1, 1, 1.4), jitter=0.0)
    for zc in (2.72, 2.08):
        cyl(0.14, 0.06, (2.7, -d / 2 - 0.45, zc), "tak_mork", verts=8)
    # A pent roof (hisashi) along the front only, between the floors, sloping out from the wall.
    front = -d / 2
    if floors > 1:
        setback = 0.75
        y_up = setback - (d - setback * 2) / 2                                                  # upper wall face
        prism([(y_up + 0.1, h1 + 0.8), (y_up + 0.1, h1 + 0.6), (front - 1.0, h1 - 0.05), (front - 1.0, h1 + 0.12)],
              w + 0.6, "tak_gra")
        box((w, d - setback * 2, 2.6), (0, setback, h1 + 1.3), "tra_morkbrun" if seed % 2 else "papper")
        for k in range(3):
            x = -1.9 + k * 1.9
            box((1.5, 0.08, 1.2), (x, y_up - 0.03, h1 + 1.4), "tra_brun")                       # frame
            box((1.3, 0.06, 1.0), (x, y_up - 0.06, h1 + 1.4), "papper_lyse")                    # paper
            for j in range(5):                                                                  # mushiko lattice
                box((0.04, 0.05, 1.0), (x - 0.52 + j * 0.26, y_up - 0.1, h1 + 1.4), "tra_morkbrun")
        z = h1 + 2.6
    else:
        z = h1
    for side in (-1, 1):                                                                         # side walls:
        for k in range(4):                                                                       # timber frame
            box((0.06, 0.14, z - 0.2), (side * (w / 2 + 0.02), -d / 2 + 1.6 + k * 2.1, z / 2), "tra_brun")
        box((0.06, d - 0.6, 0.14), (side * (w / 2 + 0.02), 0, h1 - 0.1), "tra_brun")
    hip_roof(w / 2 + 0.6, d / 2 + 0.8, z, 1.8, "tak_gra", ridge=0.9, lift=0.0)
    box((w + 0.4, 0.3, 0.3), (0, 0, z + 1.85), "tak_mork")
    export(name, bevel=0.0)


def yatai():
    """A ramen stall cart: counter, stools, a little roof, red lanterns and a noren."""
    box((2.6, 1.4, 1.0), (0, 0, 0.6), "tra_brun")
    box((2.8, 0.4, 0.08), (0, -0.85, 1.05), "tra_brun")
    for x in (-1.2, 1.2):
        cyl(0.3, 0.1, (x, 0.75, 0.3), "dack", verts=8, rot=(math.pi / 2, 0, 0))
        tube((x, -0.6, 1.0), (x, -0.6, 2.4), 0.04, "tra_morkbrun", verts=4)
    hip_roof(1.6, 1.0, 2.4, 0.5, "tak_gra", ridge=0.9, lift=0.0)
    box((2.6, 0.06, 0.06), (0, -0.95, 2.4), "tra_morkbrun")
    for k in range(3):
        box((0.75, 0.04, 0.5), (-0.85 + k * 0.85, -0.95, 2.15), "kimono_rod")
    for x in (-1.5, 1.5):
        tube((x * 0.8, -0.95, 2.4), (x, -0.95, 2.4), 0.03, "tra_morkbrun", verts=4)
        tube((x, -0.95, 2.4), (x, -0.95, 2.25), 0.012, "tak_mork", verts=3)
        blob(0.2, (x, -0.95, 2.0), "lykta_rod", scale=(1, 1, 1.4), jitter=0.0)
    for x in (-0.8, 0.0, 0.8):
        cyl(0.18, 0.6, (x, -1.4, 0.3), "tak_mork", verts=6)
    blob(0.25, (0.6, 0.1, 1.25), "metall", scale=(1, 1, 0.6), jitter=0.0)
    export("yatai", bevel=0.0)


def automat():
    """A lit drinks vending machine."""
    box((1.0, 0.8, 1.9), (0, 0, 0.95), "automat_vit")
    box((0.86, 0.04, 0.9), (0, -0.41, 1.3), "automat_lyse")
    for r in range(3):
        for c in range(5):
            box((0.12, 0.05, 0.2), (-0.32 + c * 0.16, -0.43, 1.0 + r * 0.28),
                ("neon_rosa", "neon_bla", "neon_gul", "neon_gron", "vit")[(r + c) % 5])
    box((0.6, 0.06, 0.2), (0, -0.42, 0.35), "tak_mork")
    export("automat", bevel=0.0)


def taikobashi():
    """A red arched drum bridge 12 m long over a pond, along X."""
    pts = []
    for k in range(13):
        t = k / 12
        x = -6.0 + t * 12.0
        z = 0.4 + math.sin(t * math.pi) * 2.2
        pts.append((x, z))
    for (a, b) in zip(pts, pts[1:]):
        mid = ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2)
        ang = math.atan2(b[1] - a[1], b[0] - a[0])
        box((math.hypot(b[0] - a[0], b[1] - a[1]) + 0.05, 2.4, 0.2), (mid[0], 0, mid[1]), "tra_brun", rot=(0, -ang, 0))
        for y in (-1.2, 1.2):
            box((math.hypot(b[0] - a[0], b[1] - a[1]) + 0.05, 0.1, 0.1), (mid[0], y, mid[1] + 0.8), "vermiljon",
                rot=(0, -ang, 0))
            cyl(0.06, 0.8, (a[0], y, a[1] + 0.4), "vermiljon", verts=6)
    for x in (-6.2, 6.2):
        for y in (-1.2, 1.2):
            cyl(0.12, 2.4, (x, y, -0.6), "vermiljon", verts=6)
    export("taikobashi", bevel=0.0)


# --- Tokyo ----------------------------------------------------------------------------------------

def skyskrapa(name, seed, w, d, h, glass, light):
    """A glass tower with bands of lit floors, a set-back top, roof plant and a red aircraft light."""
    rnd = random.Random(seed)
    box((w, d, h), (0, 0, h / 2), glass)
    floors = int(h / 4.0)
    for f in range(1, floors):
        z = f * 4.0
        lit = rnd.random()
        for side in (-1, 1):
            box((w * 0.92, 0.06, 1.3), (0, side * (d / 2 + 0.02), z), light if lit > 0.35 else "glas_mork")
            box((0.06, d * 0.92, 1.3), (side * (w / 2 + 0.02), 0, z), light if lit > 0.45 else "glas_mork")
    box((w * 0.7, d * 0.7, 6.0), (0, 0, h + 3.0), "betong_mork")
    box((w * 0.3, d * 0.3, 3.0), (0, 0, h + 7.5), "betong")
    cyl(0.12, 6.0, (0, 0, h + 12.0), "stal", verts=5)
    dot((0, 0, h + 15.2), 0.35, "rod_ljus")
    export(name, bevel=0.0)


def neonhus(name, seed, w, d, h):
    """A narrow Akihabara block with lit windows and big neon boards (their writing comes from the
    game): vertical boards up the front corners, wide boards across the front facing -Y."""
    rnd = random.Random(seed)
    box((w, d, h), (0, 0, h / 2), "betong_mork")
    floors = int(h / 3.4)
    for f in range(1, floors):
        z = f * 3.4
        box((w * 0.86, 0.06, 1.6), (0, -d / 2 - 0.02, z), "fonster_lyse" if rnd.random() > 0.3 else "fonster_kall")
        box((w + 0.12, d + 0.12, 0.18), (0, 0, z - 1.1), "betong")                            # floor bands
        for side in (-1, 1):                                                                    # side windows
            for k in range(2):
                y = -d / 4 + k * d / 2
                lit = rnd.random()
                box((0.06, d * 0.3, 1.3), (side * (w / 2 + 0.02), y, z),
                    "fonster_lyse" if lit > 0.55 else ("fonster_kall" if lit > 0.35 else "glas_mork"))
            if f % 2 == 0:                                                                      # AC units
                box((0.5, 0.8, 0.55), (side * (w / 2 + 0.25), d * 0.38, z - 0.6), "automat_vit")
        for k in range(3):                                                                      # back windows
            x = -w / 3 + k * w / 3
            box((w * 0.2, 0.06, 1.2), (x, d / 2 + 0.02, z), "fonster_lyse" if rnd.random() > 0.6 else "glas_mork")
    box((0.2, 0.2, h - 1.0), (w / 2 - 0.4, d / 2 + 0.1, h / 2), "stal")                       # drain pipe
    neons = ["neon_rosa", "neon_bla", "neon_gul", "neon_gron", "neon_lila", "neon_ora"]
    # Vertical boards stand out from the front corners, edge on to the facade (on brackets), as in
    # Akihabara, so they show from up and down the street; the wide ones are bolted flat to the wall.
    for side in (-1, 1):
        x = side * (w / 2 - 0.4)
        box((0.4, 1.6, h * 0.7), (x, -d / 2 - 0.8, h * 0.52), neons[(seed + side + 3) % 6])
        for k in range(4):
            box((0.12, 0.6, 0.12), (x, -d / 2 - 0.15, h * 0.2 + k * h * 0.2), "stal")
    for k in range(4):
        box((w * (0.35 + 0.1 * (k % 2)), 0.3, 1.5), ((k % 2 - 0.5) * w * 0.3, -d / 2 - 0.15, 4.0 + k * (h - 8.0) / 4),
            neons[(seed + k) % 6])
    box((w * 1.05, 0.5, 0.6), (0, -d / 2 - 0.25, 3.0), neons[(seed + 4) % 6])
    box((w * 0.9, 1.4, 0.15), (0, -d / 2 - 0.7, 2.6), "tak_mork")                              # canopy over door
    box((w * 0.5, 0.06, 2.0), (0, -d / 2 - 0.03, 1.1), "glas_bla")                             # shop window
    for k in range(4):                                                                          # lit panes
        box((w * 0.1, 0.07, 1.6), (-w * 0.18 + k * w * 0.12, -d / 2 - 0.05, 1.0), "fonster_kall" if k % 2 else "fonster_lyse")
    for k in range(5):                                                                          # mullions
        box((0.12, 0.1, 2.0), (-w * 0.24 + k * w * 0.12, -d / 2 - 0.06, 1.1), "betong")
    box((w * 0.8, d * 0.6, 1.4), (0, d * 0.1, h + 0.7), "betong")                              # roof plant
    box((w * 0.5, 0.3, 2.4), (0, -d / 2 + 0.5, h + 1.2), neons[(seed + 2) % 6])                # roof sign
    export(name, bevel=0.0)


def tokyotorn():
    """Tokyo Tower, 170 m: an orange and white lattice on four legs, two observation decks and an
    antenna, with lit members that glow at night."""
    legs = [(-1, -1), (1, -1), (1, 1), (-1, 1)]
    levels = [0.0, 20.0, 40.0, 60.0, 80.0, 100.0, 118.0, 135.0]
    half = [26.0, 18.0, 12.5, 9.0, 6.5, 5.0, 3.8, 3.0]
    for i in range(len(levels) - 1):
        z0, z1 = levels[i], levels[i + 1]
        h0, h1 = half[i], half[i + 1]
        band = "torn_rod" if i % 2 == 0 else "torn_vit"
        for (a, b) in legs:
            tube((a * h0, b * h0, z0), (a * h1, b * h1, z1), 0.9 - i * 0.08, band, verts=5)
        for k in range(4):
            (a0, b0), (a1, b1) = legs[k], legs[(k + 1) % 4]
            tube((a0 * h0, b0 * h0, z0), (a1 * h1, b1 * h1, z1), 0.25, "torn_lyse" if i % 2 else band, verts=4)
            tube((a1 * h0, b1 * h0, z0), (a0 * h1, b0 * h1, z1), 0.25, "torn_lyse" if i % 2 else band, verts=4)
            tube((a0 * h1, b0 * h1, z1), (a1 * h1, b1 * h1, z1), 0.3, band, verts=4)
    box((24.0, 24.0, 6.0), (0, 0, 45.0), "torn_vit")                                          # main deck
    box((24.4, 24.4, 2.0), (0, 0, 46.0), "fonster_lyse")
    box((9.0, 9.0, 4.0), (0, 0, 120.0), "torn_vit")                                           # top deck
    box((9.3, 9.3, 1.4), (0, 0, 120.5), "fonster_lyse")
    box((6.6, 6.6, 0.8), (0, 0, 135.0), "torn_vit")
    for k in range(4):
        z0 = 135.0 + k * 9.0
        cyl(1.6 - k * 0.3, 9.0, (0, 0, z0 + 4.5), "torn_rod" if k % 2 == 0 else "torn_vit", verts=6,
            radius_top=1.4 - k * 0.3)
    dot((0, 0, 171.0), 0.5, "rod_ljus")
    export("tokyotorn", bevel=0.0)


def slott():
    """A castle keep like Osaka's: a battered stone base, five white storeys under green roofs
    with gables and gold fish (shachihoko) on top, dark window bands."""
    cyl(23.0 * 1.414, 12.0, (0, 0, 6.0), "sten_gra", verts=4, rot=(0, 0, math.pi / 4), radius_top=19.0 * 1.414)
    z = 12.0
    for k in range(5):
        w = 30.0 - k * 4.2
        d = 24.0 - k * 3.4
        h = 6.0 - k * 0.4
        box((w, d, h), (0, 0, z + h / 2), "vit_puts")
        box((w + 0.1, d + 0.1, 1.0), (0, 0, z + h * 0.55), "tak_mork")
        for x in range(int(w / 4)):
            box((1.2, d + 0.12, 0.8), (-w / 2 + 2 + x * 4, 0, z + h * 0.55), "fonster_lyse" if (x + k) % 3 == 0 else "tak_mork")
        hip_roof(w / 2 + 2.0, d / 2 + 2.0, z + h, 2.6, "tak_gron", ridge=0.6, lift=0.8)
        prism([(-3.5, z + h + 0.2), (3.5, z + h + 0.2), (0, z + h + 3.4)], 1.0, "tak_gron", x0=0.0)
        for side in (-1, 1):
            slab_y([(-3.2, z + h + 0.3), (3.2, z + h + 0.3), (0, z + h + 3.1)], 0.3, "vit_puts", y=side * (d / 2 + 1.0))
            box((0.6, 0.1, 0.6), (0, side * (d / 2 + 1.2), z + h + 1.4), "guld")
        z += h + 1.2
    hip_roof(8.0, 6.0, z, 4.0, "tak_gron", ridge=0.6, lift=0.6)
    for x in (-4.5, 4.5):
        cone(0.6, 2.4, (x, 0, z + 5.2), "guld", verts=5)
    export("slott", bevel=0.0)


def shinkansen():
    """One bullet-train car 25 m long along X with the long pointed nose at +X (the game strings a
    few together, the last one turned round)."""
    box((19.0, 3.3, 3.2), (-3.0, 0, 2.2), "shinkansen_vit")
    bm_profile = [(-1.65, 0.6), (1.65, 0.6), (1.6, 3.4), (-1.6, 3.4)]
    prism([(-1.65, 0.6), (1.65, 0.6), (1.2, 2.6), (0.0, 3.2), (-1.2, 2.6)], 7.0, "shinkansen_vit", x0=10.0)
    cone(1.6, 4.0, (14.5, 0, 1.6), "shinkansen_vit", verts=8)
    for side in (-1, 1):
        box((19.0, 0.06, 0.35), (-3.0, side * 1.66, 1.6), "shinkansen_bla")
        box((17.0, 0.06, 0.6), (-3.0, side * 1.67, 2.75), "fonster_lyse")
    box((3.0, 2.4, 0.3), (12.0, 0, 2.95), "glas_mork", rot=(0, math.radians(-14), 0))
    for x in (-10.0, 4.0):
        box((2.5, 2.8, 0.9), (x, 0, 0.5), "tak_mork")
    export("shinkansen", bevel=0.0)


def viadukt():
    """One 20 m span of the railway viaduct along X: a concrete pier and the deck with its walls."""
    box((2.0, 3.0, 9.0), (0, 0, 4.5), "betong")
    box((20.0, 6.0, 1.2), (0, 0, 9.6), "betong")
    for y in (-2.9, 2.9):
        box((20.0, 0.2, 1.0), (0, y, 10.7), "betong_mork")
    for y in (-0.75, 0.75):
        box((20.0, 0.12, 0.1), (0, y, 10.25), "stal")
    export("viadukt", bevel=0.0)


def gatlykta():
    cyl(0.08, 5.5, (0, 0, 2.75), "tak_mork", verts=6)
    box((0.9, 0.12, 0.1), (0.35, 0, 5.5), "tak_mork")
    box((0.4, 0.3, 0.2), (0.75, 0, 5.4), "fonster_lyse")
    export("gatlykta", bevel=0.0)


# --- Plants ---------------------------------------------------------------------------------------

def korsbar(seed):
    """A cherry tree in full bloom: a dark, spreading trunk and clouds of pink blossom."""
    rnd = random.Random(seed)
    taper((0, 0, 0), (0.2, 0, 2.2), 0.35, 0.25, "stam_mork", verts=7)
    ends = []
    for k in range(5):
        a = k / 5 * math.tau + rnd.uniform(-0.3, 0.3)
        e = Vector((0.2 + math.cos(a) * 2.6, math.sin(a) * 2.6, 3.6 + rnd.uniform(-0.3, 0.8)))
        tube((0.2, 0, 2.2), e, 0.12, "stam_mork", verts=5)
        ends.append(e)
    for k, e in enumerate(ends):
        for j in range(3):
            c = e + Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(-0.2, 0.7)))
            blob(rnd.uniform(1.1, 1.5), c, ("sakura", "sakura_ljus", "sakura_mork")[(k + j) % 3],
                 scale=(1.3, 1.3, 0.85), jitter=0.2, seed=seed * 31 + k * 3 + j)
    blob(1.6, (0.2, 0, 4.6), "sakura_ljus", scale=(1.3, 1.3, 0.8), jitter=0.2, seed=seed + 99)
    export("korsbar_%d" % seed, bevel=0.0)


def lonn(seed):
    """A Japanese maple in autumn red."""
    rnd = random.Random(seed)
    taper((0, 0, 0), (0, 0, 2.0), 0.2, 0.14, "stam_mork", verts=6)
    for k in range(6):
        a = k / 6 * math.tau + rnd.uniform(-0.3, 0.3)
        c = Vector((math.cos(a) * 1.4, math.sin(a) * 1.4, 2.6 + rnd.uniform(0, 1.0)))
        tube((0, 0, 1.8), c, 0.07, "stam_mork", verts=4)
        blob(rnd.uniform(0.9, 1.2), c, "lonn_rod" if k % 3 else "lonn_ora", scale=(1.3, 1.3, 0.7), jitter=0.25,
             seed=seed * 17 + k)
    export("lonn_%d" % seed, bevel=0.0)


def bambu(seed):
    """A clump of bamboo 10–14 m high: jointed stalks and leafy tops."""
    rnd = random.Random(seed)
    for k in range(9):
        x, y = rnd.uniform(-1.0, 1.0), rnd.uniform(-1.0, 1.0)
        h = rnd.uniform(10.0, 14.0)
        lean = Vector((rnd.uniform(-0.8, 0.8), rnd.uniform(-0.8, 0.8), 0))
        top = Vector((x, y, h)) + lean
        tube((x, y, 0), top, 0.07, "bambu" if k % 2 else "bambu_ljus", verts=5)
        for j in range(1, 6):
            p = Vector((x, y, 0)).lerp(top, j / 6)
            cyl(0.085, 0.08, p, "bambu_mork", verts=5)
        for j in range(3):
            blob(0.8, top + Vector((rnd.uniform(-0.6, 0.6), rnd.uniform(-0.6, 0.6), -j * 1.4)),
                 "bambu" if j % 2 else "bambu_mork", scale=(1.4, 1.4, 0.45), jitter=0.3, seed=seed * 50 + k * 3 + j)
    export("bambu_%d" % seed, bevel=0.0)


def tall_jp(seed):
    """A Japanese black pine: a leaning, twisted trunk and flat cloud-like pads of needles."""
    rnd = random.Random(seed)
    pts = [Vector((0, 0, 0)), Vector((0.8, 0.2, 2.0)), Vector((0.2, 0.6, 3.8)), Vector((1.0, 0.4, 5.6))]
    for a, b in zip(pts, pts[1:]):
        taper(a, b, 0.3, 0.22, "stam_mork", verts=6)
    for k in range(6):
        base = pts[1 + k % 3]
        a = rnd.uniform(0, math.tau)
        end = base + Vector((math.cos(a) * 2.0, math.sin(a) * 2.0, rnd.uniform(-0.2, 0.6)))
        tube(base, end, 0.09, "stam_mork", verts=4)
        blob(1.0, end + Vector((0, 0, 0.3)), "tall_jp" if k % 2 else "tall_jp2", scale=(1.6, 1.6, 0.4), jitter=0.2,
             seed=seed * 7 + k)
    blob(1.1, pts[3] + Vector((0, 0, 0.4)), "tall_jp", scale=(1.7, 1.7, 0.45), jitter=0.2, seed=seed + 40)
    export("tall_jp_%d" % seed, bevel=0.0)


# --- People and sport -----------------------------------------------------------------------------

def dohyo():
    """An outdoor sumo ring: a raised clay square with the straw-bale circle, under a shrine roof on
    four posts with the coloured tassels of the four seasons."""
    box((7.0, 7.0, 0.6), (0, 0, 0.3), "dohyo_lera")
    bpy.ops.mesh.primitive_torus_add(major_radius=2.3, minor_radius=0.1, major_segments=24, minor_segments=4,
                                     location=(0, 0, 0.62))
    _finish(bpy.context.object, "rep")
    for (x, y, c) in ((-3.8, -3.8, "tofs_bla"), (3.8, -3.8, "tofs_rod"), (3.8, 3.8, "tofs_vit"), (-3.8, 3.8, "tofs_svart")):
        cyl(0.15, 6.0, (x, y, 3.0), "tra_brun", verts=6)
        blob(0.35, (x, y, 5.2), c, scale=(1, 1, 1.6), jitter=0.1)
    hip_roof(5.2, 5.2, 6.0, 2.4, "tak_gron", ridge=0.3, lift=0.6)
    export("dohyo", bevel=0.0)


def sumo():
    """A sumo wrestler in the shiko stance, life-size and broad. Parts: Kropp (body, origin at the
    hips) and BenV/BenH (legs, origins at the hips) so the game can stamp."""
    blob(0.62, (0, 0, 1.15), "hud_jp", scale=(0.9, 1.05, 1.0), jitter=0.04, subdiv=2)
    box((0.95, 1.2, 0.35), (0, 0, 0.82), "mawashi")
    for k in range(5):
        box((0.04, 0.06, 0.35), (0.48, -0.3 + k * 0.15, 0.55), "mawashi")
    blob(0.25, (0.05, 0, 1.85), "hud_jp", scale=(1, 1, 1.05), jitter=0.0)
    blob(0.12, (-0.05, 0, 2.12), "har_svart", scale=(1.3, 0.7, 0.6), jitter=0.0)
    for y in (-0.62, 0.62):
        tube((0, y, 1.45), (0.25, y * 1.15, 0.95), 0.16, "hud_jp", verts=6)
    part("Kropp", (0, 0, 0.85))
    for side, name in ((1, "BenV"), (-1, "BenH")):
        y = side * 0.38
        taper((0, y, 0.85), (0.05, y * 1.4, 0.1), 0.24, 0.17, "hud_jp", verts=6)
        part(name, (0, y, 0.85))
    export_parts("sumo")


def geisha():
    """A geisha in a long kimono with a gold obi, white face and black hair with ornaments, holding a
    red parasol; she glides, so she is one piece. Faces +X."""
    cyl(0.32, 1.4, (0, 0, 0.7), "kimono_lila", verts=8, radius_top=0.24)
    box((0.42, 0.52, 0.32), (0, 0, 1.15), "obi_guld")
    box((0.2, 0.3, 0.3), (-0.25, 0, 1.18), "obi_guld")
    taper((0, 0, 1.3), (0, 0, 1.55), 0.22, 0.16, "kimono_lila", verts=8)
    blob(0.12, (0.02, 0, 1.68), "vit_smink", jitter=0.0)
    blob(0.15, (-0.02, 0, 1.78), "har_svart", scale=(1.0, 1.1, 0.9), jitter=0.0)
    dot((0.0, 0.12, 1.84), 0.04, "kimono_rod")
    dot((0.11, 0, 1.66), 0.02, "kimono_rod")
    for y in (-0.22, 0.22):
        tube((0, y, 1.48), (0.12, y * 0.7, 1.15), 0.06, "kimono_lila", verts=5)
    tube((0.12, 0.15, 1.15), (0.1, 0.18, 2.1), 0.015, "tra_brun", verts=3)
    cone(0.7, 0.35, (0.1, 0.18, 2.15), "kimono_rod", verts=10)
    export("geisha", bevel=0.0)


def gyoji():
    """The sumo referee in his bright robe and black hat, holding his fan."""
    cyl(0.3, 1.2, (0, 0, 0.6), "kimono_bla", verts=8, radius_top=0.25)
    taper((0, 0, 1.2), (0, 0, 1.5), 0.26, 0.2, "obi_guld", verts=8)
    tube((0.01, 0, 1.45), (0.02, 0, 1.6), 0.05, "hud_jp", verts=6)
    blob(0.12, (0.02, 0, 1.64), "hud_jp", jitter=0.0, subdiv=2)
    cone(0.13, 0.35, (0, 0, 1.88), "har_svart", verts=6)
    for y in (-0.22, 0.22):
        tube((0, y, 1.42), (0.22, y * 0.6, 1.25), 0.07, "kimono_bla", verts=6)
        tube((0.22, y * 0.6, 1.25), (0.33, y * 0.2, 1.32), 0.06, "kimono_bla", verts=6)
        blob(0.045, (0.35, y * 0.15, 1.33), "hud_jp", jitter=0.0)
    box((0.05, 0.3, 0.25), (0.38, 0, 1.42), "obi_guld")                                           # gunbai fan
    tube((0.37, 0, 1.3), (0.37, 0, 1.36), 0.02, "tra_brun", verts=4)
    export("gyoji", bevel=0.0)


# --- The waterfall and the secret dojo ------------------------------------------------------------

def vattenfall():
    """A cliff 40 m wide with a waterfall 45 m high in a cleft, the spray pool at its foot; behind
    the falling water (at -X) the dark mouth of the dojo cave. The cliff faces +X."""
    rnd = random.Random(12)
    for k in range(10):
        y = rnd.uniform(-22.0, 22.0)
        if abs(y) < 5.0:
            y = math.copysign(6.0 + abs(y), y)
        blob(rnd.uniform(8.0, 13.0), (-9.0 - rnd.uniform(0, 6), y, rnd.uniform(10, 32)),
             "sten_mork" if k % 2 else "sten_gra", scale=(0.8, 1.0, 1.6), jitter=0.2, subdiv=1, seed=k)
    blob(14.0, (-14.0, 0, 46.0), "sten_gra", scale=(1.0, 1.6, 0.6), jitter=0.2, subdiv=1, seed=31)
    box((6.0, 9.0, 18.0), (-10.0, 0, 39.0), "sten_mork")                                         # arch over the
    box((0.6, 7.0, 46.0), (-4.5, 0, 24.0), "vatten_fall")                                        # gorge; the fall
    for k in range(6):
        box((0.3, 1.0, 46.0), (-4.1, -3.0 + k * 1.2, 24.0), "vatten_skum")
    for k in range(8):
        a = k / 8 * math.tau
        blob(1.4, (-2.0 + math.cos(a) * 3.0, math.sin(a) * 4.0, 0.6), "vatten_skum", scale=(1, 1, 0.5), jitter=0.3,
             seed=k + 60)
    export("vattenfall", bevel=0.0)


def dojo():
    """The secret dojo: a dark wooden hall with paper screens lit from inside, a plaque over the
    door and two stone lanterns; the samurai's armour waits on a stand in front. Front at -Y."""
    box((14.0, 10.0, 0.8), (0, 0, 0.4), "sten_gra")
    box((12.0, 8.0, 4.2), (0, 0, 2.9), "tra_morkbrun")
    for x in (-4.5, -1.5, 1.5, 4.5):
        box((2.4, 0.06, 2.6), (x, -4.02, 2.6), "papper_lyse")
    box((3.0, 0.12, 0.9), (0, -4.05, 4.6), "tak_mork")
    hip_roof(8.0, 6.0, 5.0, 3.2, "tak_gra", ridge=0.5, lift=0.7)
    for x in (-5.6, 5.6):
        cyl(0.2, 4.2, (x, -4.2, 2.9), "vermiljon_mork", verts=6)
    export("dojo", bevel=0.0)


def teleporttorii():
    """The teleport gate of Japan: a vermilion torii with a glowing ring inside it, on a short stone
    bridge-deck plinth. The road passes along X."""
    for y in (-3.4, 3.4):
        cyl(0.3, 7.0, (0, y, 3.5), "vermiljon", verts=8)
        cyl(0.36, 0.5, (0, y, 0.25), "tak_mork", verts=8)
    box((0.6, 8.6, 0.5), (0, 0, 6.0), "vermiljon")
    box((0.8, 9.6, 0.4), (0, 0, 7.1), "tak_mork")
    bpy.ops.mesh.primitive_torus_add(major_radius=2.8, minor_radius=0.2, major_segments=24, minor_segments=6,
                                     location=(0, 0, 3.4), rotation=(0, math.pi / 2, 0))
    _finish(bpy.context.object, "portal")
    export("teleportport", bevel=0.0)      # the same name as the stone gate: Japan's folder is searched first


# --- The battle -----------------------------------------------------------------------------------

def samurai():
    """The samurai you become: red lacquered armour, a horned helmet with a gold crest and a katana
    at the hip, in mid-stride. Parts: Kaross (hips and skirt), BenV/BenH (legs, origins at the hips),
    Torn (chest, head and the left arm, origin at the waist; it turns to aim) and Pipa (the right,
    throwing arm, origin at the shoulder, along +X)."""
    box((0.5, 0.6, 0.35), (0, 0, 1.0), "rustning_svart")
    for k in range(5):
        a = k / 5 * math.tau
        box((0.28, 0.12, 0.4), (math.cos(a) * 0.3, math.sin(a) * 0.32, 0.8), "rustning_rod", rot=(0, 0, a))
    tube((-0.1, -0.35, 0.95), (-0.7, -0.4, 1.2), 0.03, "rustning_svart", verts=4)                # katana
    part("Kaross", (0, 0, 0))
    for side, name in ((1, "BenV"), (-1, "BenH")):
        y = side * 0.14
        taper((0, y, 0.95), (0.02, y, 0.12), 0.11, 0.08, "rustning_svart", verts=6)
        box((0.24, 0.12, 0.25), (0.02, y, 0.55), "rustning_rod")
        box((0.28, 0.12, 0.14), (0.08, y, 0.07), "tra_morkbrun")
        part(name, (0, y, 0.95))
    taper((0, 0, 1.15), (0, 0, 1.6), 0.24, 0.28, "rustning_rod", verts=8)
    for k in range(4):
        box((0.42, 0.62, 0.05), (0.01, 0, 1.2 + k * 0.1), "rustning_svart")
    for y in (-0.36, 0.36):
        box((0.35, 0.22, 0.28), (0, y, 1.55), "rustning_rod", rot=(math.copysign(0.4, y), 0, 0))       # sode
    tube((0.01, 0, 1.55), (0.03, 0, 1.75), 0.06, "hud_jp", verts=6)
    blob(0.12, (0.03, 0, 1.78), "hud_jp", jitter=0.0, subdiv=2)
    box((0.08, 0.2, 0.08), (0.14, 0, 1.74), "rustning_svart")                                   # mask
    blob(0.17, (0, 0, 1.88), "rustning_svart", scale=(1.1, 1.1, 0.7), jitter=0.0)              # kabuto
    cyl(0.3, 0.05, (0, 0, 1.82), "rustning_svart", verts=10, radius_top=0.2)
    for y in (-0.1, 0.1):
        tube((0.1, y, 1.95), (0.22, y * 3.0, 2.25), 0.02, "guld", verts=3)                       # crest
    tube((0, -0.3, 1.55), (0.3, -0.35, 1.2), 0.06, "rustning_rod", verts=5)                      # left arm
    part("Torn", (0, 0, 1.15))
    tube((0, 0.3, 1.55), (0.45, 0.32, 1.55), 0.06, "rustning_rod", verts=5)
    blob(0.07, (0.5, 0.32, 1.55), "hud_jp", jitter=0.0)
    part("Pipa", (0, 0.3, 1.55))
    export_parts("samurai")


def oni():
    """An oni: a big red ogre with horns, wild hair, a tiger-skin loincloth and an iron club. Same
    joints as the zombie: Kropp, ArmV (the club arm), ArmH, BenV, BenH."""
    blob(0.4, (0.05, 0, 1.25), "oni_rod", scale=(0.9, 1.1, 1.15), jitter=0.05, subdiv=2)
    box((0.5, 0.65, 0.3), (0.02, 0, 0.98), "tiger")
    for k in range(4):
        box((0.04, 0.6, 0.05), (0.27, 0, 0.9 + k * 0.07), "tak_mork")
    blob(0.2, (0.12, 0, 1.78), "oni_rod", scale=(1, 1, 1.05), jitter=0.05)
    blob(0.2, (0.05, 0, 1.88), "har_svart", scale=(1.1, 1.2, 0.7), jitter=0.3, seed=4)
    for y in (-0.1, 0.1):
        cone(0.05, 0.25, (0.12, y * 1.4, 2.05), "tofs_vit", verts=5)
        box((0.04, 0.05, 0.04), (0.3, y * 0.7, 1.82), "neon_gul")
    box((0.04, 0.2, 0.04), (0.32, 0, 1.7), "tofs_vit")
    part("Kropp", (0, 0, 0.95))
    for side, name in ((1, "ArmV"), (-1, "ArmH")):
        y = side * 0.42
        tube((0.05, y, 1.5), (0.55, y, 1.35), 0.11, "oni_rod", verts=6)
        blob(0.12, (0.6, y, 1.33), "oni_rod", jitter=0.1)
        if side > 0:
            taper((0.6, y, 1.33), (0.65, y, 2.4), 0.06, 0.13, "stal", verts=6)                 # kanabo
        part(name, (0.05, y, 1.5))
    for side, name in ((1, "BenV"), (-1, "BenH")):
        y = side * 0.17
        taper((0, y, 0.95), (0.02, y, 0.08), 0.13, 0.1, "oni_rod", verts=6)
        part(name, (0, y, 0.95))
    export_parts("oni")


def ninja():
    """A ninja in black with a dark blue sash, ready to throw. Joints like the zombie."""
    taper((0, 0, 0.95), (0.03, 0, 1.45), 0.15, 0.17, "ninja_svart", verts=7)
    box((0.32, 0.36, 0.08), (0.02, 0, 1.0), "ninja_bla")
    tube((0.03, 0, 1.4), (0.06, 0, 1.56), 0.06, "ninja_svart", verts=6)
    blob(0.12, (0.06, 0, 1.6), "ninja_svart", jitter=0.0, subdiv=2)
    box((0.04, 0.16, 0.035), (0.17, 0, 1.62), "hud_jp")
    tube((-0.14, 0.05, 1.4), (-0.1, -0.2, 1.75), 0.02, "stal", verts=3)                          # sword on back
    part("Kropp", (0, 0, 0.95))
    for side, name in ((1, "ArmV"), (-1, "ArmH")):
        y = side * 0.2
        tube((0.03, y, 1.4), (0.45, y, 1.35), 0.04, "ninja_svart", verts=5)
        part(name, (0.03, y, 1.4))
    for side, name in ((1, "BenV"), (-1, "BenH")):
        y = side * 0.09
        taper((0, y, 0.95), (0.02, y, 0.06), 0.07, 0.05, "ninja_svart", verts=5)
        part(name, (0, y, 0.95))
    export_parts("ninja")


def kitsune():
    """A fox spirit: a white fox with three tails tipped with blue fox-fire; it dashes at you and
    bursts into blue flame. Faces +X."""
    blob(0.35, (0, 0, 0.5), "kitsune_vit", scale=(1.6, 0.8, 0.8), jitter=0.05, subdiv=2)
    blob(0.2, (0.6, 0, 0.75), "kitsune_vit", scale=(1.3, 0.9, 0.9), jitter=0.0)
    cone(0.12, 0.35, (0.88, 0, 0.72), "kitsune_vit", verts=5)
    for y in (-0.08, 0.08):
        cone(0.06, 0.18, (0.55, y, 0.98), "kitsune_vit", verts=4)
        box((0.03, 0.04, 0.02), (0.72, y * 0.9, 0.8), "kimono_rod")
    for (x, y) in ((0.3, -0.12), (0.3, 0.12), (-0.3, -0.12), (-0.3, 0.12)):
        tube((x, y, 0.4), (x, y, 0.0), 0.04, "kitsune_vit", verts=4)
    for k in range(3):
        a = (k - 1) * 0.5
        tip = Vector((-0.9, math.sin(a) * 0.5, 0.9 + math.cos(a) * 0.3))
        tube((-0.5, 0, 0.55), tip, 0.08, "kitsune_vit", verts=5)
        blob(0.13, tip, "kitsune_eld", scale=(1, 1, 1.5), jitter=0.2, seed=k)
    export("kitsune", bevel=0.0)


def drake():
    """The dragon: a long serpentine body (about 26 m) in red and gold with a green crest, a horned
    head with whiskers, and small clawed legs. Head at +X."""
    rnd = random.Random(9)
    segs = 16
    for k in range(segs):
        t = k / (segs - 1)
        x = 12.0 - t * 26.0
        y = math.sin(t * math.pi * 2.0) * 2.2
        z = math.sin(t * math.pi * 1.5) * 1.6
        r = 1.0 - t * 0.6
        blob(r, (x, y, z), "drake_rod" if k % 2 else "drake_guld", scale=(1.3, 1.0, 1.0), jitter=0.05, seed=k)
        cone(0.3 * r + 0.1, 0.9 * r, (x, y, z + r * 0.9), "drake_gron", verts=4)
        if k in (3, 9):
            for side in (-1, 1):
                tube((x, y + side * r * 0.6, z - r * 0.4), (x + 0.6, y + side * 1.6, z - 1.4), 0.15, "drake_guld", verts=4)
    blob(1.2, (13.2, 0, 0.3), "drake_rod", scale=(1.4, 0.9, 0.9), jitter=0.05, seed=50)
    box((1.4, 1.0, 0.4), (14.6, 0, -0.1), "drake_guld")                                         # snout
    for side in (-1, 1):
        tube((13.0, side * 0.5, 1.0), (11.6, side * 1.4, 2.6), 0.12, "drake_guld", verts=4)        # horns
        tube((14.8, side * 0.4, 0.0), (16.8, side * 1.6, -0.8), 0.04, "drake_guld", verts=3)       # whiskers
        dot((14.0, side * 0.55, 0.65), 0.15, "neon_gul")
    export("drake", bevel=0.0)


def shuriken():
    """A throwing star: four points, steel with a dark centre, 0.3 m across; it spins as it flies."""
    for k in range(4):
        a = k / 4 * math.tau
        slab_y([(0.0, 0.0), (0.16, 0.035), (0.0, 0.07)], 0.015, "stal", y=0.0)
        o = bpy.context.collection.objects[-1]
        o.rotation_euler = (0, 0, a)
        o.location = (0, 0, 0)
    cyl(0.04, 0.02, (0, 0, 0.0), "tak_mork", verts=8, rot=(math.pi / 2, 0, 0))
    export("shuriken", bevel=0.0)


# --- Street life (texture round) -------------------------------------------------------------------

def elstolpe():
    """A concrete utility pole 9.5 m high: two cross-arms with insulators (the wires run along X),
    a transformer drum, step bolts and a yellow-and-black band. Origin at the foot."""
    cyl(0.17, 9.5, (0, 0, 4.75), "betong", verts=8, radius_top=0.11)
    for z, w in ((8.2, 1.9), (7.6, 1.5)):
        box((0.12, w, 0.12), (0, 0, z), "stal")
        for y in (-w / 2 + 0.1, 0.0, w / 2 - 0.1):
            cyl(0.05, 0.16, (0, y, z + 0.13), "torn_vit", verts=6)
    cyl(0.28, 0.75, (0.36, 0, 6.6), "stal", verts=10)
    box((0.2, 0.12, 0.5), (0.16, 0, 6.6), "stal")
    for k in range(10):
        box((0.22, 0.04, 0.04), (0.14, 0, 2.2 + k * 0.45), "stal", rot=(0, 0, math.pi / 2 * (k % 2)))
    for k in range(4):
        cyl(0.172, 0.12, (0, 0, 1.4 + k * 0.12), "tofs_svart" if k % 2 else "neon_gul", verts=8)
    export("elstolpe", bevel=0.0)


def cyklar():
    """Four parked city bikes (mamachari) side by side with baskets; they stand along Y."""
    for k, frame in enumerate(("stal", "kimono_rod", "bil_bla_jp", "stal")):
        y = -0.9 + k * 0.6
        for x in (-0.55, 0.55):
            bpy.ops.mesh.primitive_torus_add(major_radius=0.32, minor_radius=0.025, major_segments=12, minor_segments=4,
                                             location=(x, y, 0.34), rotation=(math.pi / 2, 0, 0))
            _finish(bpy.context.object, "tofs_svart")
        tube((-0.55, y, 0.34), (0.0, y, 0.34), 0.025, frame, verts=4)
        tube((0.0, y, 0.34), (-0.15, y, 0.85), 0.025, frame, verts=4)
        tube((0.0, y, 0.34), (0.45, y, 0.8), 0.025, frame, verts=4)
        tube((0.45, y, 0.8), (0.55, y, 0.34), 0.02, frame, verts=4)
        box((0.24, 0.1, 0.05), (-0.17, y, 0.9), "tofs_svart")
        tube((0.45, y, 0.8), (0.4, y, 1.0), 0.02, frame, verts=4)
        tube((0.4, y - 0.25, 1.0), (0.4, y + 0.25, 1.0), 0.015, "stal", verts=3)
        box((0.3, 0.32, 0.22), (0.6, y, 0.88), "stal")
    export("cyklar", bevel=0.0)


def keibil():
    """A small boxy kei van, white, with dark windows, a tall roof and black bumpers; front +X."""
    box((3.2, 1.45, 1.1), (0, 0, 0.75), "bil_vit_jp")
    box((2.6, 1.42, 0.75), (-0.25, 0, 1.68), "bil_vit_jp")
    box((0.1, 1.3, 0.6), (1.06, 0, 1.6), "glas_mork", rot=(0, math.radians(-12), 0))
    for y in (-0.715, 0.715):
        box((1.9, 0.04, 0.5), (-0.2, y, 1.68), "glas_mork")
    box((0.12, 1.5, 0.22), (1.62, 0, 0.42), "tofs_svart")
    box((0.12, 1.5, 0.22), (-1.62, 0, 0.42), "tofs_svart")
    for y in (-0.5, 0.5):
        box((0.06, 0.22, 0.14), (1.61, y, 0.85), "torn_lyse")
    for x in (1.05, -1.05):
        for y in (-0.68, 0.68):
            cyl(0.27, 0.18, (x, y, 0.27), "tofs_svart", verts=10, rot=(math.pi / 2, 0, 0))
    export("keibil", bevel=0.02)


def postlada():
    """A red Japanese post box: a pillar with a rounded cap, two slots and a white sign."""
    cyl(0.28, 1.2, (0, 0, 0.6), "post_rod", verts=12)
    blob(0.29, (0, 0, 1.2), "post_rod", scale=(1.0, 1.0, 0.45), jitter=0.0)
    for z in (1.0, 0.82):
        box((0.04, 0.24, 0.04), (0.28, 0, z), "tofs_svart")
    box((0.03, 0.16, 0.12), (0.285, 0, 0.6), "torn_vit")
    box((0.4, 0.4, 0.06), (0, 0, 0.03), "betong")
    export("postlada", bevel=0.0)


def jizo():
    """Three small stone Jizō statues side by side on a stone ledge, with red bibs and caps."""
    box((0.8, 2.2, 0.3), (0, 0, 0.15), "sten_mork")
    for k, y in enumerate((-0.65, 0.0, 0.65)):
        h = 0.75 if k != 1 else 0.85
        cyl(0.2, h, (0, y, 0.3 + h / 2), "sten_gra", verts=8, radius_top=0.16)
        blob(0.15, (0, y, 0.38 + h), "sten_gra", jitter=0.05)
        cone(0.26, 0.2, (0, y, 0.25 + h * 0.75), "kimono_rod", verts=8)
        cyl(0.16, 0.08, (0, y, 0.52 + h), "kimono_rod", verts=8)
    box((0.15, 0.15, 0.1), (0.3, 0.3, 0.35), "kimono_rod")                                        # offerings
    export("jizo", bevel=0.0)


def lykta_par():
    """A wooden stand with two big red paper lanterns (chōchin) that glow, for a shop front."""
    for y in (-0.6, 0.6):
        box((0.12, 0.12, 2.6), (0, y, 1.3), "tra_morkbrun")
    box((0.12, 1.5, 0.12), (0, 0, 2.55), "tra_morkbrun")
    for y in (-0.38, 0.38):
        tube((0, y, 2.5), (0, y, 2.3), 0.02, "tofs_svart", verts=3)
        blob(0.24, (0, y, 1.95), "lykta_rod", scale=(1.0, 1.0, 1.35), jitter=0.0)
        cyl(0.16, 0.06, (0, y, 2.28), "tofs_svart", verts=8)
        cyl(0.16, 0.06, (0, y, 1.62), "tofs_svart", verts=8)
    export("lykta_par", bevel=0.0)


def krukor():
    """A cluster of potted plants outside a house: pots and small round shrubs and a pine bonsai."""
    rnd = random.Random(4)
    for k in range(5):
        x, y = rnd.uniform(-0.6, 0.6), -0.8 + k * 0.4
        r = rnd.uniform(0.14, 0.22)
        cyl(r, r * 1.6, (x, y, r * 0.8), "tra_brun", verts=8, radius_top=r * 1.15)
        blob(r * 1.5, (x, y, r * 1.9), "bambu" if k % 2 else "tall_jp2", jitter=0.2, seed=k)
    cyl(0.3, 0.2, (0.2, 1.1, 0.1), "sten_gra", verts=10)
    tube((0.2, 1.1, 0.2), (0.3, 1.0, 0.6), 0.05, "stam_mork", verts=4)
    blob(0.3, (0.32, 1.0, 0.72), "tall_jp", scale=(1.4, 1.2, 0.6), jitter=0.1)
    export("krukor", bevel=0.0)


def kraka():
    """A crow for the sky: black body and two wings (it wheels like Skärgården's gulls)."""
    blob(0.16, (0, 0, 0), "kraka", scale=(2.2, 0.8, 0.8), jitter=0.0)
    blob(0.08, (0.32, 0, 0.04), "kraka", jitter=0.0)
    tube((0.38, 0, 0.04), (0.48, 0, 0.02), 0.025, "kraka", verts=3)
    for side in (-1, 1):
        bm = bmesh.new()
        v = [bm.verts.new(c) for c in ((0.15, 0, 0), (-0.2, 0, 0), (-0.05, side * 0.75, 0.1))]
        bm.faces.new(v if side > 0 else list(reversed(v)))
        me = bpy.data.meshes.new("vinge")
        bm.to_mesh(me)
        bm.free()
        o = bpy.data.objects.new("vinge", me)
        bpy.context.collection.objects.link(o)
        o.data.materials.append(mat("kraka"))
    export("kraka", bevel=0.0)


def yakatabune():
    """A river pleasure boat (yakatabune): a long low hull, a cabin with glowing paper windows, a
    dark roof and a row of red lanterns along the eaves. Bow towards +X."""
    hull(14.0, 3.6, 0.9, "batskrov")
    box((11.0, 3.2, 0.1), (-0.3, 0, 0.18), "tra_brun")
    box((10.0, 3.0, 1.9), (-0.6, 0, 1.15), "tra_morkbrun")
    for y in (-1.52, 1.52):
        for k in range(6):
            box((1.3, 0.04, 1.0), (-5.0 + k * 1.75, y, 1.2), "papper_lyse")
    box((11.0, 3.6, 0.18), (-0.6, 0, 2.2), "tak_mork")
    box((11.4, 0.6, 0.2), (-0.6, 0, 2.35), "tak_mork")
    for y in (-1.8, 1.8):
        for k in range(8):
            blob(0.18, (-5.6 + k * 1.45, y, 1.95), "lykta_rod", scale=(1.0, 1.0, 1.3), jitter=0.0)
    export("yakatabune", bevel=0.0)


def koi():
    """A koi carp 0.7 m long, orange and white, for the pond; swims towards +X."""
    blob(0.12, (0.04, 0, 0), "koi_ora", scale=(2.4, 1.0, 0.85), jitter=0.0, subdiv=2)              # body
    taper((-0.18, 0, 0.0), (-0.34, 0, 0.0), 0.085, 0.03, "koi_ora", verts=8)                       # tail stalk
    blob(0.07, (0.0, 0, 0.055), "koi_vit", scale=(2.2, 1.2, 0.6), jitter=0.0)                       # white saddle
    blob(0.05, (0.22, 0, 0.05), "koi_vit", scale=(1.3, 1.2, 0.6), jitter=0.0)                       # white head spot
    for y in (-0.035, 0.035):
        dot((0.3, y, 0.02), 0.012, "tofs_svart")                                                    # eyes
        tube((0.32, y, -0.02), (0.36, y * 2.5, -0.04), 0.004, "koi_ora", verts=3)                   # barbels
    for side in (-1, 1):                                                                            # pectoral fins
        box((0.1, 0.08, 0.01), (0.15, side * 0.13, -0.04), "koi_ora", rot=(side * 0.3, 0, side * 0.5))
    box((0.16, 0.01, 0.07), (0.0, 0, 0.11), "koi_ora")                                              # dorsal fin
    bm = bmesh.new()
    v = [bm.verts.new(c) for c in ((-0.32, 0, 0), (-0.48, 0.12, 0), (-0.48, -0.12, 0))]
    bm.faces.new(v)
    me = bpy.data.meshes.new("stjart")
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new("stjart", me)
    bpy.context.collection.objects.link(o)
    o.data.materials.append(mat("koi_ora"))
    export("koi", bevel=0.0)


def kontorist():
    """An office worker in a dark suit with a white shirt and a briefcase, walking; faces +X."""
    for y in (-0.1, 0.1):
        tube((0, y, 0.0), (0, y, 0.9), 0.07, "kostym", verts=6)
    box((0.26, 0.15, 0.08), (0.05, -0.1, 0.04), "tofs_svart")
    box((0.26, 0.15, 0.08), (0.05, 0.1, 0.04), "tofs_svart")
    taper((0, 0, 0.85), (0, 0, 1.45), 0.2, 0.22, "kostym", verts=8)
    box((0.05, 0.12, 0.35), (0.19, 0, 1.3), "skoluniform")
    box((0.04, 0.05, 0.3), (0.2, 0, 1.28), "kimono_rod")
    for y in (-0.25, 0.25):
        tube((0, y, 1.42), (0.02, y * 1.1, 0.9), 0.055, "kostym", verts=5)
    box((0.35, 0.1, 0.26), (0.0, 0.32, 0.78), "tra_morkbrun")
    box((0.04, 0.04, 0.14), (0.02, 0.3, 0.97), "tra_morkbrun")                                   # handle
    tube((0.01, 0, 1.4), (0.02, 0, 1.56), 0.05, "hud_jp", verts=6)
    blob(0.11, (0.02, 0, 1.6), "hud_jp", jitter=0.0, subdiv=2)
    blob(0.115, (-0.01, 0, 1.66), "har_svart", scale=(1.0, 1.0, 0.7), jitter=0.0)
    export("kontorist", bevel=0.0)


def skolelev():
    """A schoolgirl in a sailor uniform (white top, navy collar and pleated skirt) with a bag."""
    for y in (-0.08, 0.08):
        tube((0, y, 0.0), (0, y, 0.6), 0.05, "hud_jp", verts=6)
        box((0.2, 0.1, 0.07), (0.03, y, 0.035), "tofs_svart")
    cyl(0.22, 0.32, (0, 0, 0.72), "kjol_bla", verts=10, radius_top=0.15)
    taper((0, 0, 0.86), (0, 0, 1.3), 0.15, 0.17, "skoluniform", verts=8)
    box((0.14, 0.32, 0.12), (-0.08, 0, 1.28), "kjol_bla")
    box((0.04, 0.1, 0.1), (0.15, 0, 1.18), "kimono_rod")
    for y in (-0.2, 0.2):
        tube((0, y, 1.27), (0.02, y * 1.1, 0.85), 0.045, "skoluniform", verts=5)
    box((0.3, 0.12, 0.24), (-0.05, 0.27, 0.95), "tofs_svart")
    tube((0.01, 0, 1.26), (0.02, 0, 1.4), 0.045, "hud_jp", verts=6)
    blob(0.1, (0.02, 0, 1.43), "hud_jp", jitter=0.0, subdiv=2)
    blob(0.12, (-0.02, 0, 1.47), "har_svart", scale=(1.0, 1.05, 0.95), jitter=0.0)
    export("skolelev", bevel=0.0)


# --- Temple, village and paddies --------------------------------------------------------------------

def tanuki():
    """A ceramic tanuki statue (shop luck charm): big belly, straw hat, sake flask; faces +X."""
    blob(0.42, (0, 0, 0.45), "tanuki_brun", scale=(1.0, 1.1, 1.05), jitter=0.0)
    blob(0.3, (0.18, 0, 0.42), "tanuki_ljus", scale=(0.8, 1.0, 1.0), jitter=0.0)                 # belly
    blob(0.26, (0.05, 0, 1.0), "tanuki_brun", jitter=0.0)
    blob(0.1, (0.28, 0, 0.98), "tanuki_ljus", jitter=0.0)
    for y in (-0.15, 0.15):
        dot((0.27, y * 0.6, 1.06), 0.03, "tofs_svart")
        blob(0.08, (0.0, y, 1.22), "tanuki_brun", jitter=0.0)
    cone(0.4, 0.18, (0.02, 0, 1.3), "halm_jp", verts=10)
    cyl(0.1, 0.25, (0.2, 0.38, 0.4), "tra_brun", verts=6)
    box((0.7, 0.7, 0.08), (0, 0, 0.04), "sten_gra")
    export("tanuki", bevel=0.0)


def komainu():
    """A stone guardian lion-dog (komainu) sitting on its plinth, mane and open mouth; faces +X."""
    box((1.1, 1.1, 0.9), (0, 0, 0.45), "sten_mork")
    box((1.25, 1.25, 0.15), (0, 0, 0.97), "sten_gra")
    for k in range(3):                                                                           # carved panel
        box((0.02, 0.7 - k * 0.2, 0.5 - k * 0.14), (0.56, 0, 0.45), "sten_gra" if k % 2 else "sten_mork")
    # Sitting on its haunches: the rump on the plinth, the chest up, the forelegs straight down.
    blob(0.36, (-0.15, 0, 1.3), "sten_gra", scale=(1.1, 0.85, 0.75), jitter=0.06, subdiv=2)       # haunches
    blob(0.3, (0.1, 0, 1.58), "sten_gra", scale=(0.9, 0.85, 1.15), jitter=0.06, subdiv=2, seed=2) # chest
    for y in (-0.17, 0.17):
        taper((0.22, y, 1.6), (0.28, y, 1.06), 0.09, 0.07, "sten_gra", verts=6)                   # forelegs
        blob(0.09, (0.33, y, 1.08), "sten_gra", scale=(1.4, 1.0, 0.6), jitter=0.0)                # paws
        blob(0.13, (-0.12, y * 1.6, 1.2), "sten_gra", scale=(1.4, 0.7, 0.8), jitter=0.0)          # hind legs
    blob(0.3, (0.18, 0, 1.98), "sten_gra", jitter=0.18, seed=4, subdiv=2)                         # mane
    for k in range(6):                                                                            # mane curls
        a = k / 6 * math.tau
        blob(0.08, (0.1, math.cos(a) * 0.27, 1.98 + math.sin(a) * 0.27), "sten_mork", jitter=0.0)
    blob(0.2, (0.36, 0, 1.94), "sten_gra", scale=(1.1, 1.0, 0.9), jitter=0.0, subdiv=2)            # face
    box((0.18, 0.26, 0.14), (0.52, 0, 1.88), "sten_gra")                                         # snout
    box((0.06, 0.22, 0.05), (0.6, 0, 1.82), "sten_mork")                                         # open mouth
    for y in (-0.08, 0.08):
        dot((0.53, y, 2.0), 0.03, "sten_mork")                                                     # eyes
        cone(0.06, 0.12, (0.32, y * 2.0, 2.16), "sten_gra", verts=5)                              # ears
    blob(0.16, (-0.48, 0, 1.6), "sten_gra", scale=(0.8, 0.9, 1.4), jitter=0.2, seed=7)            # tail flame
    tube((-0.42, 0, 1.38), (-0.48, 0, 1.55), 0.07, "sten_gra", verts=5)
    export("komainu", bevel=0.0)


def temizuya():
    """A purification pavilion: a stone basin with bamboo ladles under a small roof on four posts."""
    box((2.4, 1.0, 0.7), (0, 0, 0.35), "sten_gra")
    box((2.2, 0.8, 0.12), (0, 0, 0.66), "vatten_fall")
    for k in range(4):
        tube((-0.8 + k * 0.5, 0.2, 0.74), (-0.6 + k * 0.5, 0.48, 0.72), 0.02, "bambu", verts=3)
    tube((1.25, 0, 0.0), (1.25, 0, 1.45), 0.07, "bambu_mork", verts=6)
    tube((1.25, 0, 1.4), (0.9, 0, 0.9), 0.06, "bambu", verts=5)
    for x in (-1.5, 1.5):
        for y in (-0.9, 0.9):
            box((0.16, 0.16, 2.4), (x, y, 1.2), "vermiljon")
    hip_roof(1.9, 1.2, 2.4, 1.0, "tak_gra", ridge=0.4, lift=0.3)
    export("temizuya", bevel=0.0)


def hokora():
    """A tiny roadside shrine on a stone base: a wooden house with a gabled roof, a mini torii in
    front and a red bib on the little statue inside."""
    box((0.9, 0.9, 0.7), (0, 0, 0.35), "sten_mork")
    box((0.7, 0.6, 0.6), (0, 0, 1.0), "tra_morkbrun")
    box((0.05, 0.4, 0.4), (0.36, 0, 1.0), "tofs_svart")
    for side in (-1, 1):
        box((0.95, 0.5, 0.06), (0, side * 0.2, 1.42), "tak_gra", rot=(side * math.radians(30), 0, 0))
    blob(0.08, (0.3, 0, 0.95), "sten_gra", jitter=0.0)
    box((0.06, 0.16, 0.1), (0.36, 0, 0.88), "kimono_rod")
    for y in (-0.3, 0.3):
        box((0.06, 0.06, 0.8), (0.75, y, 0.4), "vermiljon")
    box((0.08, 0.8, 0.06), (0.75, 0, 0.82), "vermiljon")
    box((0.06, 0.7, 0.05), (0.75, 0, 0.7), "vermiljon")
    export("hokora", bevel=0.0)


def takegaki():
    """A bamboo fence 4 m long: posts, two rails and close vertical canes tied with black cord;
    runs along X."""
    for x in (-2.0, 0.0, 2.0):
        cyl(0.06, 1.6, (x, 0, 0.8), "tra_morkbrun", verts=6)
    for z in (0.5, 1.2):
        tube((-2.0, 0.06, z), (2.0, 0.06, z), 0.03, "bambu_mork", verts=4)
        box((4.0, 0.03, 0.04), (0, 0.1, z), "tofs_svart")
    for k in range(40):
        x = -1.95 + k * 0.1
        cyl(0.035, 1.5, (x, 0, 0.75), "bambu_ljus" if k % 3 else "bambu", verts=5)
    export("takegaki", bevel=0.0)


def kakashi():
    """A scarecrow for the rice paddies: a cross of poles, a faded kimono, a cloth face and a
    straw hat."""
    cyl(0.04, 2.0, (0, 0, 1.0), "tra_brun", verts=5)
    tube((0, -0.8, 1.45), (0, 0.8, 1.45), 0.03, "tra_brun", verts=4)
    taper((0, 0, 0.8), (0, 0, 1.5), 0.32, 0.22, "kimono_bla", verts=8)
    for side in (-1, 1):
        tube((0, 0, 1.45), (0, side * 0.75, 1.42), 0.08, "kimono_bla", verts=5)
    blob(0.16, (0, 0, 1.75), "papper", jitter=0.0)
    dot((0.15, -0.05, 1.78), 0.02, "tofs_svart")
    dot((0.15, 0.05, 1.78), 0.02, "tofs_svart")
    cone(0.45, 0.2, (0, 0, 1.95), "halm_jp", verts=10)
    export("kakashi", bevel=0.0)


def hager():
    """A great white egret standing in a paddy: long neck, yellow bill, black legs; faces +X."""
    blob(0.14, (0, 0, 0.75), "hager_vit", scale=(2.0, 0.8, 0.9), jitter=0.0)
    tube((0.18, 0, 0.82), (0.3, 0, 1.15), 0.035, "hager_vit", verts=4)
    blob(0.055, (0.32, 0, 1.18), "hager_vit", scale=(1.4, 1.0, 1.0), jitter=0.0)
    tube((0.38, 0, 1.18), (0.52, 0, 1.15), 0.015, "hager_gul", verts=3)
    for y in (-0.04, 0.04):
        tube((0, y, 0.65), (0.02, y, 0.0), 0.012, "tofs_svart", verts=3)
    export("hager", bevel=0.0)


def koinobori():
    """A carp-streamer pole for Children's Day: a tall pole with a pinwheel top, a striped
    streamer and three carp (black, red, blue) that stream out along +X."""
    cyl(0.07, 9.0, (0, 0, 4.5), "tra_brun", verts=6)
    for k in range(4):
        a = k / 4 * math.tau
        box((0.5, 0.05, 0.15), (math.cos(a) * 0.25, math.sin(a) * 0.25, 9.0), "guld", rot=(0, 0, a))
    for k, (m, z, l) in enumerate((("vimpel_svart", 7.8, 2.6), ("vimpel_rod", 6.4, 2.2), ("vimpel_bla", 5.1, 1.8))):
        taper((0.1, 0, z), (0.1 + l, 0, z - 0.3), 0.35 - k * 0.04, 0.18, m, verts=8)
        bm_x = 0.1 + l
        cone(0.3 - k * 0.03, 0.4, (bm_x + 0.1, 0, z - 0.32), m, verts=6)
        dot((0.35, -0.3 + k * 0.03, z + 0.05), 0.07, "torn_vit")
        dot((0.35, 0.3 - k * 0.03, z + 0.05), 0.07, "torn_vit")
    box((2.85, 0.04, 0.5), (1.45, 0, 8.6), "kimono_rod")
    export("koinobori", bevel=0.0)


def munk():
    """A Buddhist monk in an orange robe over grey, shaven head, walking; faces +X."""
    cyl(0.3, 1.25, (0, 0, 0.62), "munk_ora", verts=8, radius_top=0.22)
    taper((0, 0, 1.2), (0, 0, 1.5), 0.24, 0.17, "munk_ora", verts=8)
    box((0.05, 0.35, 0.9), (0.18, 0.05, 1.1), "tak_gra", rot=(math.radians(20), 0, 0))
    for y in (-0.22, 0.22):
        tube((0, y, 1.42), (0.15, y * 0.5, 1.05), 0.06, "munk_ora", verts=5)
    tube((0.01, 0, 1.45), (0.02, 0, 1.6), 0.05, "hud_jp", verts=6)
    blob(0.12, (0.02, 0, 1.64), "hud_jp", jitter=0.0, subdiv=2)
    for y in (-0.22, 0.22):
        blob(0.045, (0.17, y * 0.5, 1.02), "hud_jp", jitter=0.0)
    export("munk", bevel=0.0)


def turist():
    """A tourist with a sun hat, a red shirt, shorts and a camera on its strap; faces +X."""
    for y in (-0.09, 0.09):
        tube((0, y, 0.0), (0, y, 0.55), 0.055, "hud_jp", verts=6)
        box((0.24, 0.11, 0.08), (0.04, y, 0.04), "torn_vit")
    taper((0, 0, 0.5), (0, 0, 0.85), 0.17, 0.18, "kimono_bla", verts=8)
    taper((0, 0, 0.85), (0, 0, 1.42), 0.2, 0.2, "turist_rod", verts=8)
    for y in (-0.24, 0.24):
        tube((0, y, 1.38), (0.05, y * 1.05, 0.95), 0.05, "hud_jp", verts=5)
    box((0.12, 0.16, 0.1), (0.2, 0, 1.2), "tofs_svart")
    tube((0.2, -0.08, 1.2), (0.05, -0.1, 1.42), 0.008, "tofs_svart", verts=3)                    # strap
    tube((0.01, 0, 1.38), (0.02, 0, 1.54), 0.05, "hud_jp", verts=6)
    blob(0.11, (0.02, 0, 1.58), "hud_jp", jitter=0.0, subdiv=2)
    cyl(0.22, 0.05, (0.02, 0, 1.68), "halm_jp", verts=10)
    cyl(0.11, 0.12, (0.02, 0, 1.74), "halm_jp", verts=8)
    export("turist", bevel=0.0)


def busskur():
    """A country bus stop: a small shelter with a bench, a round sign on a pole and a timetable."""
    box((2.6, 1.2, 0.1), (0, 0, 0.05), "betong")
    for x in (-1.2, 1.2):
        box((0.08, 0.08, 2.3), (x, 0.55, 1.15), "stal")
        box((0.06, 1.1, 2.2), (x, 0, 1.1), "glas_bla")
    box((2.5, 0.06, 2.2), (0, 0.6, 1.1), "glas_bla")
    box((2.8, 1.5, 0.1), (0, 0.05, 2.35), "tak_gra")
    box((2.0, 0.4, 0.06), (0, 0.3, 0.5), "tra_brun")
    for x in (-0.8, 0.8):
        box((0.06, 0.06, 0.45), (x, 0.3, 0.25), "stal")
    cyl(0.04, 2.4, (1.8, -0.4, 1.2), "stal", verts=5)
    cyl(0.3, 0.04, (1.8, -0.4, 2.4), "vimpel_bla", verts=12, rot=(math.pi / 2, 0, 0))
    box((0.4, 0.03, 0.5), (1.8, -0.43, 1.6), "torn_vit")
    export("busskur", bevel=0.0)


# --- The bigger Japan ------------------------------------------------------------------------------

def sugi(seed):
    """A Japanese cedar 22–27 m: a straight trunk and a narrow, clumpy cone of dark foliage."""
    rnd = random.Random(seed)
    h = 22.0 + seed * 2.5
    taper((0, 0, 0), (0, 0, h), 0.45, 0.08, "stam_mork", verts=7)
    layers = 7
    for k in range(layers):
        t = k / (layers - 1)
        z = h * (0.28 + 0.7 * t)
        r = 3.0 * (1.0 - t) + 0.7
        for j in range(3 if k < layers - 2 else 1):
            a = j / 3 * math.tau + k * 0.9
            off = Vector((math.cos(a), math.sin(a), 0)) * r * 0.35 * (1 if j else 0)
            blob(r * rnd.uniform(0.85, 1.05), Vector((0, 0, z)) + off, "sugi" if (k + j) % 2 else "sugi_ljus",
                 scale=(1.0, 1.0, 0.9), jitter=0.22, seed=seed * 41 + k * 3 + j)
    export("sugi_%d" % seed, bevel=0.0)


def tebuske():
    """A clipped row of tea bushes 6 m long along X: a rounded hedge with a lighter top of new leaves."""
    profile = [(-0.62, 0.0), (-0.66, 0.35), (-0.58, 0.66), (-0.38, 0.86), (-0.12, 0.94), (0.12, 0.94),
               (0.38, 0.86), (0.58, 0.66), (0.66, 0.35), (0.62, 0.0)]
    prism(profile, 6.0, "te_gron")
    prism([(-0.5, 0.7), (-0.32, 0.9), (-0.1, 0.99), (0.1, 0.99), (0.32, 0.9), (0.5, 0.7)], 5.9, "te_ljus")
    export("tebuske_1", bevel=0.0)


def ginkgo(seed):
    """A ginkgo 12 m high: a straight grey trunk and a tall crown of fresh fan-leaf green."""
    rnd = random.Random(seed)
    taper((0, 0, 0), (0, 0, 9.0), 0.32, 0.14, "sten_mork", verts=6)
    for k in range(7):
        a = k / 7 * math.tau + rnd.uniform(-0.3, 0.3)
        z = 4.5 + k * 0.9
        r = 2.4 - k * 0.22
        c = Vector((math.cos(a) * r * 0.6, math.sin(a) * r * 0.6, z))
        tube((0, 0, z - 1.0), c, 0.08, "sten_mork", verts=4)
        blob(r, c, "ginkgo" if k % 2 else "ginkgo_mork", scale=(1.1, 1.1, 0.95), jitter=0.22, seed=seed * 13 + k)
    blob(1.4, (0, 0, 11.0), "ginkgo", scale=(1.0, 1.0, 1.2), jitter=0.2, seed=seed + 70)
    export("ginkgo_%d" % seed, bevel=0.0)


def chaya():
    """A tea house at the pass: a small wooden hut under a deep thatched hip roof, an open front with a
    blue noren, a red-clothed bench outside under a big red parasol, and a lantern. Faces -Y."""
    box((6.0, 4.5, 0.3), (0, 0, 0.15), "sten_gra")
    box((5.6, 4.0, 2.6), (0, 0.2, 1.6), "tra_brun")
    box((3.6, 0.06, 1.9), (0, -1.82, 1.25), "tra_morkbrun")
    for k in range(3):
        box((1.1, 0.03, 0.9), (-1.2 + k * 1.2, -1.86, 2.35), "kimono_bla")
    for x in (-2.85, 2.85):
        box((0.18, 0.18, 2.9), (x, -1.9, 1.45), "tra_morkbrun")
    hip_roof(4.0, 3.4, 2.9, 2.4, "halm_tak", ridge=0.35, lift=0.2)
    box((2.6, 0.7, 0.45), (-0.4, -3.3, 0.45), "mosen")
    for x in (-1.6, 0.8):
        box((0.1, 0.6, 0.45), (x, -3.3, 0.22), "tra_morkbrun")
    cyl(0.04, 3.2, (1.6, -3.6, 1.6), "tra_brun", verts=5)
    cone(1.8, 0.7, (1.6, -3.6, 3.15), "mosen", verts=16)
    box((0.1, 0.6, 0.1), (-2.85, -2.15, 2.55), "tra_morkbrun")
    tube((-2.85, -2.35, 2.55), (-2.85, -2.35, 2.35), 0.015, "tak_mork", verts=3)
    blob(0.3, (-2.85, -2.35, 1.95), "lykta_rod", scale=(1, 1, 1.4), jitter=0.0)
    export("chaya", bevel=0.0)


def gassho():
    """A gassho farmhouse like those of Shirakawa-gō: dark wooden walls under a huge steep thatched
    roof (hands pressed together in prayer), the gable ends boarded with rows of small lit windows.
    The ridge runs along X; 10 m wide, 16 m long, 13 m high."""
    box((16.0, 10.0, 0.4), (0, 0, 0.2), "sten_mork")
    box((15.0, 9.0, 2.8), (0, 0, 1.8), "tra_morkbrun")
    for y in (-4.52, 4.52):
        for k in range(5):
            box((1.6, 0.05, 1.0), (-6.0 + k * 3.0, y, 1.9), "papper_lyse")
    prism([(-6.4, 3.0), (6.4, 3.0), (0.0, 13.2)], 17.2, "halm_tak")
    prism([(-0.7, 12.4), (0.7, 12.4), (0.0, 13.6)], 17.4, "halm_tak_mork")
    for x in (-8.55, 8.55):
        slab_x = [(-5.6, 3.0), (5.6, 3.0), (0.0, 12.0)]
        o = slab_y([(y, z) for y, z in slab_x], 0.2, "tra_brun")
        o.rotation_euler = (0, 0, math.pi / 2)
        o.location = (x, 0, 0)
        for z, n in ((4.4, 4), (6.9, 3), (9.2, 2)):
            for k in range(n):
                box((0.1, 0.9, 0.7), (x + (0.1 if x > 0 else -0.1), -(n - 1) * 0.75 + k * 1.5, z), "fonster_lyse")
    export("gassho", bevel=0.0)


def ryokan():
    """A two-storey hot-spring inn 24 m wide: a stone base, dark timber, rows of lit paper windows on
    both floors, a balcony, layered tiled hip roofs, and a noren and two lanterns at the entrance.
    Faces -Y."""
    box((25.0, 13.0, 0.6), (0, 0, 0.3), "sten_gra")
    box((24.0, 12.0, 3.2), (0, 0, 2.2), "tra_morkbrun")
    box((22.0, 11.0, 3.0), (0, 0.4, 5.3), "tra_brun")
    for k in range(8):
        x = -10.5 + k * 3.0
        box((2.2, 0.05, 1.6), (x, -6.03, 2.3), "papper_lyse")
        box((2.2, 0.05, 1.5), (x, -5.13, 5.3), "papper_lyse")
    box((23.0, 1.0, 0.12), (0, -5.6, 4.0), "tra_morkbrun")
    for k in range(12):
        box((0.06, 0.06, 0.9), (-11.0 + k * 2.0, -6.05, 4.45), "tra_morkbrun")
    box((23.0, 0.08, 0.08), (0, -6.05, 4.9), "tra_morkbrun")
    hip_roof(13.4, 7.4, 3.8, 1.2, "tak_mork", ridge=0.9, lift=0.25)
    hip_roof(12.4, 6.6, 6.8, 2.8, "tak_mork", ridge=0.6, lift=0.4)
    box((3.0, 0.06, 1.4), (0, -6.1, 2.6), "kimono_bla")
    for x in (-2.4, 2.4):
        box((0.1, 0.75, 0.1), (x, -6.35, 3.2), "tra_morkbrun")
        tube((x, -6.65, 3.2), (x, -6.65, 2.95), 0.015, "tak_mork", verts=3)
        blob(0.35, (x, -6.65, 2.5), "lykta_rod", scale=(1, 1, 1.4), jitter=0.0)
    export("ryokan", bevel=0.0)


def pariserhjul():
    """The Odaiba Ferris wheel, 86 m high: two A-frame legs and a station (Stativ), and the wheel (Hjul,
    origin at the hub, turning about Y) with its rim, spokes, lit rim lights and 24 round gondolas."""
    hub = (0, 0, 46.0)
    for y in (-3.0, 3.0):
        for x in (-16.0, 16.0):
            tube((x, y * 2.2, 0), (0, y, hub[2]), 0.7, "hjul_vit", verts=6)
        tube((-10.0, y * 1.9, 16.0), (10.0, y * 1.9, 16.0), 0.35, "hjul_vit", verts=5)
    box((20.0, 12.0, 4.0), (0, 0, 2.0), "glas_mork")
    box((21.0, 13.0, 0.4), (0, 0, 4.2), "betong")
    tube((0, -3.6, hub[2]), (0, 3.6, hub[2]), 0.8, "stal", verts=8)
    part("Stativ", (0, 0, 0))
    r = 40.0
    for side in (-1.6, 1.6):
        bpy.ops.mesh.primitive_torus_add(major_radius=r, minor_radius=0.45, major_segments=48, minor_segments=4,
                                         location=(0, side, hub[2]), rotation=(math.pi / 2, 0, 0))
        _finish(bpy.context.object, "hjul_vit")
    for k in range(24):
        a = k / 24 * math.tau
        rim = Vector((math.cos(a) * r, 0, hub[2] + math.sin(a) * r))
        for side in (-1.6, 1.6):
            tube((0, side * 0.4, hub[2]), (rim.x, side, rim.z), 0.12, "hjul_vit", verts=4)
        gondola = Vector((rim.x * 1.06, 0, hub[2] + (rim.z - hub[2]) * 1.06))
        tube((rim.x, 0, rim.z), gondola, 0.14, "hjul_vit", verts=4)
        for side in (-1.6, 1.6):
            tube((rim.x, side, rim.z), (rim.x, 0, rim.z), 0.1, "hjul_vit", verts=4)
        blob(1.3, gondola, ("neon_bla", "neon_rosa", "neon_gul", "neon_gron")[k % 4]
             if k % 2 else "glas_bla", scale=(1, 1.1, 1), jitter=0.0)
    for k in range(96):
        a = k / 96 * math.tau
        for side in (-1.6, 1.6):
            dot((math.cos(a) * (r + 0.5), side, hub[2] + math.sin(a) * (r + 0.5)), 0.35,
                ("neon_bla", "neon_lila", "neon_rosa")[(k // 8) % 3])
    cyl(1.6, 4.0, hub, "stal", verts=10, rot=(math.pi / 2, 0, 0))
    part("Hjul", hub)
    export_parts("pariserhjul")


def fiskebat_jp():
    """A Japanese squid-fishing boat 15 m: a white hull with a blue sheer stripe, the wheelhouse aft,
    a mast and a line of big lamps along the whole boat, and flags. Bow towards +X."""
    hull(15.0, 4.0, 1.4, "skrov_vit", stripe="skrov_bla")
    box((13.0, 3.6, 0.1), (-0.4, 0, 0.22), "tra_brun")
    box((3.4, 2.8, 2.4), (-4.2, 0, 1.45), "skrov_vit")
    box((3.0, 2.85, 0.7), (-4.0, 0, 2.25), "glas_mork")
    box((3.8, 3.2, 0.2), (-4.2, 0, 2.75), "skrov_bla")
    cyl(0.1, 7.0, (-3.6, 0, 6.3), "stal", verts=6)
    tube((-6.5, 0, 1.4), (6.5, 0, 4.4), 0.05, "stal", verts=3)
    for k in range(10):
        x = -5.5 + k * 1.25
        z = 1.4 + (x + 6.5) / 13.0 * 3.0 - 0.5
        tube((x, 0, z + 0.5), (x, 0, z + 0.2), 0.015, "stal", verts=3)
        blob(0.28, (x, 0, z), "lampa_vit", jitter=0.0)
    for k, c in enumerate(("vimpel_rod", "vimpel_bla", "neon_gul")):
        box((0.04, 0.9, 0.5), (-3.6, 0.45, 9.4 - k * 0.6), c)
    export("fiskebat_jp", bevel=0.0)


def fyr_jp():
    """A red harbour light at the end of a breakwater: a concrete foot, a red tower 11 m, a lantern
    room with a red light and a small gallery."""
    cyl(2.2, 1.2, (0, 0, 0.6), "betong", verts=10)
    cyl(1.25, 9.5, (0, 0, 5.95), "fyr_rod", verts=10, radius_top=1.0)
    cyl(1.5, 0.15, (0, 0, 10.8), "betong", verts=10)
    cyl(0.75, 1.3, (0, 0, 11.5), "rod_ljus", verts=8)
    cone(0.9, 0.7, (0, 0, 12.5), "fyr_rod", verts=8)
    box((0.7, 0.05, 1.6), (0, -1.15, 4.0), "torn_vit")
    export("fyr_jp", bevel=0.0)


# --- The living Japan: people, animals, vehicles and the festival ------------------------------------

def person(top, bottom, skin="hud_jp", hair="har_svart", shoes="tofs_svart", lean=0.0, arms="down", scale=1.0,
           skirt=False, at=(0, 0, 0)):
    """A figure 1.6 m tall (times `scale`) facing +X at `at`: legs or a long skirt, a torso tilted
    forward by `lean` radians at the hips, a head with hair, and arms 'down', 'forward', 'up' or
    'none'. Returns the head's centre and the two hands."""
    s, o = scale, Vector(at)
    hip = o + Vector((0, 0, 0.85 * s))
    if skirt:
        cyl(0.24 * s, 0.85 * s, o + Vector((0, 0, 0.43 * s)), bottom, verts=10, radius_top=0.17 * s)
    else:
        for y in (-0.1, 0.1):
            tube(o + Vector((0, y * s, 0.0)), o + Vector((0, y * s, 0.88 * s)), 0.07 * s, bottom, verts=6)
    for y in (-0.1, 0.1):
        box((0.24 * s, 0.11 * s, 0.07 * s), o + Vector((0.04 * s, y * s, 0.035 * s)), shoes)
    up = Vector((math.sin(lean), 0, math.cos(lean)))
    neck = hip + up * 0.6 * s
    taper(hip, neck, 0.19 * s, 0.21 * s, top, verts=8)
    blob(0.2 * s, neck - up * 0.03 * s, top, scale=(0.75, 1.15, 0.45), jitter=0.0)        # rounded shoulders
    head = neck + up * 0.17 * s
    tube(neck - up * 0.04 * s, head, 0.05 * s, skin, verts=6)                              # the neck (no gap)
    blob(0.11 * s, head, skin, scale=(1.0, 0.92, 1.08), jitter=0.0, subdiv=2)
    dot(head + Vector((0.105 * s, 0, -0.01 * s)), 0.022 * s, skin)                         # nose
    for y in (-0.04, 0.04):
        dot(head + Vector((0.095 * s, y * s, 0.025 * s)), 0.013 * s, "tofs_svart")       # eyes
    if hair:
        blob(0.118 * s, head + Vector((-0.03 * s, 0, 0.045 * s)), hair, scale=(1.0, 1.0, 0.78), jitter=0.0, subdiv=2)
    hands = []
    for y in (-0.25, 0.25):
        sh = hip + up * 0.55 * s + Vector((0, y * s, 0))
        if arms == "none":
            hands.append(sh)
            continue
        if arms == "forward":
            hand = sh + Vector((0.38 * s, -y * 0.45 * s, -0.25 * s))
        elif arms == "up":
            hand = sh + Vector((0.08 * s, y * 0.15 * s, 0.42 * s))
        else:
            hand = sh + Vector((0.03 * s, y * 0.12 * s, -0.5 * s))
        elbow = sh + (hand - sh) * 0.5 + Vector((-0.04 * s, y * 0.08 * s, 0))
        tube(sh, elbow, 0.058 * s, top, verts=6)
        tube(elbow, hand, 0.05 * s, top, verts=6)
        blob(0.045 * s, hand + (hand - elbow).normalized() * 0.03 * s, skin, jitter=0.0)  # hand
        hands.append(hand)
    return head, hands


def wheel(x, y, z, r, material="tofs_svart", thick=0.03, spokes=0, spoke_mat="stal"):
    """A thin wheel in the XZ plane (rolling along X) with optional spokes."""
    bpy.ops.mesh.primitive_torus_add(major_radius=r, minor_radius=thick, major_segments=14, minor_segments=4,
                                     location=(x, y, z), rotation=(math.pi / 2, 0, 0))
    _finish(bpy.context.object, material)
    for k in range(spokes):
        a = k / spokes * math.tau
        tube((x, y, z), (x + math.cos(a) * r, y, z + math.sin(a) * r), 0.012, spoke_mat, verts=3)


def miko():
    """A shrine maiden (miko): white kosode, wide red hakama, long black hair tied with a white
    ribbon, sweeping with a bamboo broom. Faces +X."""
    head, hands = person("tofs_vit", "miko_rod", shoes="tofs_vit", lean=0.25, arms="forward", skirt=True)
    box((0.07, 0.13, 0.45), head + Vector((-0.13, 0, -0.3)), "har_svart")
    box((0.04, 0.15, 0.05), head + Vector((-0.13, 0, -0.08)), "tofs_vit")
    tube((0.45, 0.0, 1.05), (0.85, 0.05, 0.1), 0.02, "bambu_ljus", verts=4)
    blob(0.22, (0.9, 0.05, 0.1), "halm_jp", scale=(1.4, 0.8, 0.45), jitter=0.15)
    export("miko", bevel=0.0)


def skolbarn():
    """A primary-school child in a yellow cap with the red randoseru on the back; 1.2 m, faces +X."""
    head, hands = person("skoluniform", "kjol_bla", scale=0.72)
    box((0.16, 0.25, 0.28), (-0.17, 0, 0.8), "randoseru")
    cyl(0.1, 0.08, head + Vector((0.0, 0, 0.07)), "hatt_gul", verts=10)
    cyl(0.14, 0.015, head + Vector((0.03, 0, 0.04)), "hatt_gul", verts=10)
    export("skolbarn", bevel=0.0)


def mamachari():
    """A rider on a mamachari: a step-through city bike with a front basket, the rider sitting upright
    in a lilac jacket. Front +X."""
    for x in (-0.55, 0.55):
        wheel(x, 0, 0.33, 0.33, spokes=8)
    tube((-0.55, 0, 0.33), (-0.1, 0, 0.75), 0.03, "bil_bla_jp", verts=5)
    tube((-0.1, 0, 0.75), (-0.05, 0, 0.35), 0.03, "bil_bla_jp", verts=5)
    tube((-0.05, 0, 0.35), (0.42, 0, 0.8), 0.03, "bil_bla_jp", verts=5)
    tube((0.55, 0, 0.33), (0.42, 0, 0.98), 0.025, "stal", verts=5)
    box((0.04, 0.55, 0.03), (0.36, 0, 1.0), "stal")
    box((0.3, 0.36, 0.22), (0.6, 0, 0.88), "stal")
    box((0.22, 0.12, 0.05), (-0.1, 0, 0.79), "tofs_svart")
    hip = Vector((-0.1, 0, 0.85))
    for y in (-0.1, 0.1):
        tube(hip + Vector((0, y, 0)), (0.18, y, 0.62), 0.065, "kjol_bla", verts=5)
        tube((0.18, y, 0.62), (0.05, y, 0.22), 0.055, "kjol_bla", verts=5)
    taper(hip, hip + Vector((0.12, 0, 0.58)), 0.18, 0.2, "kimono_lila", verts=8)
    head = hip + Vector((0.16, 0, 0.75))
    tube(hip + Vector((0.12, 0, 0.56)), head, 0.05, "hud_jp", verts=6)
    blob(0.11, head, "hud_jp", jitter=0.0, subdiv=2)
    blob(0.115, head + Vector((-0.03, 0, 0.05)), "har_svart", scale=(1, 1, 0.75), jitter=0.0)
    for y in (-0.22, 0.22):
        tube(hip + Vector((0.1, y, 0.52)), (0.34, y * 1.1, 1.0), 0.05, "kimono_lila", verts=5)
    export("mamachari", bevel=0.0)


def rikscha():
    """A rickshaw (jinrikisha) with its runner: two tall spoked wheels, a red seat under a black hood,
    long shafts forward, the runner in a happi coat and headband, and a passenger in a kimono.
    Runner towards +X."""
    for y in (-0.6, 0.6):
        wheel(0, y, 0.68, 0.68, thick=0.04, spokes=8, spoke_mat="tra_brun")
    tube((0, -0.65, 0.68), (0, 0.65, 0.68), 0.03, "stal", verts=5)
    box((0.7, 1.0, 0.12), (0.05, 0, 0.95), "tra_morkbrun")
    box((0.5, 0.9, 0.4), (-0.1, 0, 1.2), "kimono_rod")
    box((0.12, 0.95, 0.6), (-0.32, 0, 1.45), "kimono_rod")
    box((0.65, 1.0, 0.05), (-0.15, 0, 1.98), "tofs_svart", rot=(0, 0.3, 0))
    box((0.05, 1.0, 0.6), (-0.42, 0, 1.72), "tofs_svart")
    for y in (-0.45, 0.45):
        tube((0.3, y, 0.95), (2.0, y * 0.8, 0.8), 0.03, "tra_morkbrun", verts=4)
    tube((2.0, -0.36, 0.8), (2.0, 0.36, 0.8), 0.03, "tra_morkbrun", verts=4)
    phip = Vector((-0.05, 0, 1.35))
    taper(phip, phip + Vector((0, 0, 0.55)), 0.18, 0.2, "kimono_lila", verts=8)
    ph = phip + Vector((0.02, 0, 0.7))
    tube(phip + Vector((0, 0, 0.5)), ph, 0.05, "vit_smink", verts=6)
    blob(0.11, ph, "vit_smink", jitter=0.0, subdiv=2)
    blob(0.12, ph + Vector((-0.03, 0, 0.06)), "har_svart", scale=(1.0, 1.05, 0.9), jitter=0.0)
    for y in (-0.1, 0.1):
        tube(phip + Vector((0.05, y, 0)), (0.4, y, 1.3), 0.065, "kimono_lila", verts=5)
        tube((0.4, y, 1.3), (0.4, y, 0.98), 0.055, "kimono_lila", verts=5)
    head, hands = person("happi_bla", "happi_bla", lean=0.3, arms="down", at=(1.75, 0, 0))
    cyl(0.12, 0.05, head + Vector((0, 0, 0.04)), "tofs_vit", verts=10)
    export("rikscha", bevel=0.0)


def mikoshi():
    """A portable shrine (mikoshi) carried by eight bearers in blue and red happi coats: a black
    lacquered shrine with gold panels, roof and phoenix on two long poles. Front +X."""
    for y in (-0.55, 0.55):
        tube((-2.6, y, 1.45), (2.6, y, 1.45), 0.06, "tra_brun", verts=6)
    for x in (-1.0, 1.0):
        tube((x, -0.7, 1.45), (x, 0.7, 1.45), 0.05, "tra_brun", verts=5)
    box((1.3, 1.3, 0.25), (0, 0, 1.65), "rustning_svart")
    box((0.9, 0.9, 0.8), (0, 0, 2.15), "rustning_svart")
    for y in (-0.46, 0.46):
        box((0.6, 0.02, 0.5), (0, y, 2.15), "guld")
    for x in (-0.46, 0.46):
        box((0.02, 0.6, 0.5), (x, 0, 2.15), "guld")
    hip_roof(0.85, 0.85, 2.55, 0.6, "guld", ridge=0.15, lift=0.25)
    blob(0.15, (0, 0, 3.22), "guld", scale=(1.5, 0.6, 1.2), jitter=0.1)
    cyl(0.04, 0.12, (0, 0, 3.08), "guld", verts=5)
    for x in (-1.9, -0.7, 0.7, 1.9):
        for y in (-0.55, 0.55):
            head, _ = person("happi_bla" if (x > 0) == (y > 0) else "happi_rod", "tofs_svart", arms="up",
                             at=(x, y * 1.25, 0))
            cyl(0.12, 0.05, head + Vector((0, 0, 0.04)), "tofs_vit", verts=10)
    export("mikoshi", bevel=0.0)


def taxi():
    """A Tokyo taxi: a boxy black sedan with a yellow side line, a white roof with the lit roof sign
    (andon), dark glass, mirrors on the front wings. Front +X."""
    box((4.4, 1.7, 0.62), (0, 0, 0.6), "taxi_svart")
    box((4.42, 1.72, 0.07), (0, 0, 0.74), "taxi_gul")
    box((2.2, 1.6, 0.55), (-0.25, 0, 1.18), "taxi_svart")
    box((2.0, 1.64, 0.36), (-0.25, 0, 1.22), "glas_mork")
    box((0.1, 1.5, 0.42), (0.88, 0, 1.18), "glas_mork", rot=(0, math.radians(-20), 0))
    box((2.0, 1.5, 0.06), (-0.25, 0, 1.48), "tofs_vit")
    box((0.45, 0.2, 0.24), (-0.1, 0, 1.63), "torn_lyse")
    for x in (1.35, -1.35):
        for y in (-0.78, 0.78):
            cyl(0.32, 0.2, (x, y, 0.32), "tofs_svart", verts=10, rot=(math.pi / 2, 0, 0))
    for y in (-0.6, 0.6):
        box((0.05, 0.28, 0.12), (2.2, y, 0.72), "lampa_vit")
        box((0.05, 0.3, 0.12), (-2.2, y, 0.72), "lykta_rod")
        tube((1.7, y * 1.25, 0.9), (1.7, y * 1.45, 0.98), 0.012, "taxi_svart", verts=3)
        box((0.06, 0.06, 0.14), (1.7, y * 1.5, 0.98), "taxi_svart")
    export("taxi", bevel=0.02)


def keilastbil():
    """A kei truck: a tiny white cab-over pickup with dropsides, carrying crates of vegetables and
    oranges. Front +X."""
    box((1.2, 1.4, 1.3), (1.0, 0, 1.0), "bil_vit_jp")
    box((0.08, 1.3, 0.55), (1.6, 0, 1.3), "glas_mork", rot=(0, math.radians(-10), 0))
    for y in (-0.71, 0.71):
        box((0.7, 0.03, 0.45), (1.05, y, 1.32), "glas_mork")
    box((2.0, 1.4, 0.12), (-0.6, 0, 0.62), "bil_vit_jp")
    for y in (-0.7, 0.7):
        box((2.0, 0.05, 0.3), (-0.6, y, 0.82), "bil_vit_jp")
    box((0.05, 1.4, 0.3), (-1.6, 0, 0.82), "bil_vit_jp")
    for k in range(3):
        for j, y in enumerate((-0.32, 0.32)):
            c = Vector((-1.15 + k * 0.55, y, 0.86))
            box((0.5, 0.5, 0.32), c, "tra_brun")
            for m in range(3):
                blob(0.1, c + Vector((-0.12 + m * 0.12, 0.05 * (m - 1), 0.2)), "apelsin" if (k + j) % 2 else "gronsak",
                     jitter=0.1, seed=k * 7 + j * 3 + m)
    for x in (0.95, -1.05):
        for y in (-0.62, 0.62):
            cyl(0.27, 0.18, (x, y, 0.27), "tofs_svart", verts=10, rot=(math.pi / 2, 0, 0))
    for y in (-0.5, 0.5):
        box((0.05, 0.22, 0.14), (1.61, y, 0.6), "lampa_vit")
    export("keilastbil", bevel=0.02)


def moped():
    """A delivery moped like a Super Cub with its rider: leg shield, seat, a red delivery box on the
    rack, the rider in a white helmet and blue jacket. Front +X."""
    for x in (-0.6, 0.6):
        wheel(x, 0, 0.28, 0.28, thick=0.05)
    box((0.25, 0.4, 0.6), (0.35, 0, 0.65), "kimono_rod")
    box((0.9, 0.3, 0.18), (-0.15, 0, 0.55), "kimono_rod")
    box((0.6, 0.3, 0.1), (-0.2, 0, 0.78), "tofs_svart")
    tube((0.6, 0, 0.28), (0.45, 0, 1.05), 0.03, "stal", verts=5)
    box((0.06, 0.6, 0.04), (0.45, 0, 1.05), "stal")
    box((0.45, 0.42, 0.42), (-0.65, 0, 1.0), "kimono_rod")
    box((0.47, 0.44, 0.06), (-0.65, 0, 1.22), "tofs_vit")
    hip = Vector((-0.2, 0, 0.88))
    for y in (-0.12, 0.12):
        tube(hip + Vector((0, y, 0)), (0.15, y, 0.7), 0.065, "kostym", verts=5)
        tube((0.15, y, 0.7), (0.2, y, 0.45), 0.055, "kostym", verts=5)
    taper(hip, hip + Vector((0.15, 0, 0.55)), 0.18, 0.2, "kimono_bla", verts=8)
    head = hip + Vector((0.2, 0, 0.73))
    tube(hip + Vector((0.15, 0, 0.53)), head, 0.05, "hud_jp", verts=6)
    blob(0.11, head, "hud_jp", jitter=0.0, subdiv=2)
    blob(0.14, head + Vector((-0.02, 0, 0.04)), "tofs_vit", scale=(1.05, 1.0, 0.85), jitter=0.0)
    for y in (-0.2, 0.2):
        tube(hip + Vector((0.12, y, 0.5)), (0.45, y * 1.3, 1.05), 0.05, "kimono_bla", verts=5)
    export("moped", bevel=0.0)


def svanbat():
    """A swan pedal boat for two: a white hull, the swan's body, long neck and head with an orange
    beak, and a blue bench. Front +X."""
    hull(2.8, 1.5, 0.5, "svan_vit")
    blob(0.6, (-0.2, 0, 0.35), "svan_vit", scale=(1.6, 1.15, 0.6), jitter=0.05)
    taper((0.7, 0, 0.35), (1.15, 0, 1.45), 0.18, 0.09, "svan_vit", verts=8)
    blob(0.18, (1.25, 0, 1.52), "svan_vit", scale=(1.5, 0.8, 0.9), jitter=0.0)
    tube((1.4, 0, 1.5), (1.62, 0, 1.43), 0.05, "nab_gul", verts=5)
    for y in (-0.08, 0.08):
        dot((1.33, y, 1.58), 0.02, "tofs_svart")
    box((0.5, 1.0, 0.1), (-0.1, 0, 0.66), "kimono_bla")
    box((0.08, 1.0, 0.4), (-0.4, 0, 0.85), "kimono_bla")
    export("svanbat", bevel=0.0)


def fiskare():
    """An angler sitting on a cool box with his rod out over the water: body (Kropp) and rod (Spo,
    origin at the hands) so the rod can dip. Faces +X."""
    box((0.5, 0.35, 0.36), (-0.1, 0, 0.18), "tofs_vit")
    hip = Vector((-0.1, 0, 0.45))
    for y in (-0.1, 0.1):
        tube(hip + Vector((0, y, 0)), (0.28, y, 0.48), 0.07, "kimono_bla", verts=5)
        tube((0.28, y, 0.48), (0.32, y, 0.05), 0.06, "kimono_bla", verts=5)
        box((0.24, 0.11, 0.07), (0.36, y, 0.035), "tofs_svart")
    taper(hip, hip + Vector((0.1, 0, 0.58)), 0.19, 0.22, "gronsak", verts=8)
    head = hip + Vector((0.13, 0, 0.75))
    tube(hip + Vector((0.1, 0, 0.56)), head, 0.05, "hud_jp", verts=6)
    blob(0.11, head, "hud_jp", jitter=0.0, subdiv=2)
    cyl(0.13, 0.12, head + Vector((0, 0, 0.08)), "halm_jp", verts=10)
    cyl(0.2, 0.02, head + Vector((0, 0, 0.03)), "halm_jp", verts=12)
    for y in (-0.22, 0.22):
        tube(hip + Vector((0.08, y, 0.52)), (0.38, y * 0.3, 0.78), 0.055, "gronsak", verts=5)
    part("Kropp", (0, 0, 0))
    tube((0.38, 0, 0.78), (3.4, 0, 2.3), 0.02, "tofs_svart", verts=4)
    cyl(0.05, 0.12, (0.5, 0.06, 0.85), "stal", verts=6)
    part("Spo", (0.38, 0, 0.78))
    export_parts("fiskare")


def teplockare():
    """A tea picker bent over the bushes: an indigo kasuri kimono with a red sash, a conical sedge
    hat and a basket on the back. Faces +X."""
    head, hands = person("kasuri", "kasuri", lean=0.55, arms="forward", skirt=True)
    box((0.44, 0.44, 0.1), (0.04, 0, 0.92), "kimono_rod")
    cone(0.34, 0.2, head + Vector((0, 0, 0.1)), "halm_jp", verts=12)
    cyl(0.18, 0.36, head + Vector((-0.42, 0, -0.32)), "halm_jp", verts=8)
    export("teplockare", bevel=0.0)


def risbonde():
    """A rice farmer bent double in the paddy: a white shirt, indigo trousers rolled up, a straw hat
    and a bunch of green seedlings in one hand. Faces +X."""
    head, hands = person("tofs_vit", "kasuri", lean=0.85, arms="forward")
    cone(0.32, 0.18, head + Vector((0.02, 0, 0.1)), "halm_jp", verts=12)
    blob(0.1, hands[0] + Vector((0.04, 0, -0.05)), "gronsak", scale=(0.7, 0.7, 1.4), jitter=0.2)
    export("risbonde", bevel=0.0)


def pilgrim():
    """A pilgrim (henro) in white with a sedge hat, a purple stole, a bag and a wooden staff. Faces
    +X."""
    head, hands = person("tofs_vit", "tofs_vit", shoes="halm_jp", arms="down")
    cone(0.31, 0.18, head + Vector((0, 0, 0.1)), "halm_jp", verts=12)
    box((0.04, 0.09, 0.45), (0.2, 0.07, 1.15), "kimono_lila")
    box((0.04, 0.09, 0.45), (0.2, -0.07, 1.15), "kimono_lila")
    tube(hands[1] + Vector((0.06, 0, -0.85)), hands[1] + Vector((0.06, 0, 0.65)), 0.025, "tra_brun", verts=5)
    box((0.26, 0.08, 0.3), (-0.04, -0.3, 0.82), "tofs_vit")
    export("pilgrim", bevel=0.0)


def forsaljare():
    """A street vendor in a happi coat and apron with a twisted headband, a spatula in his hand,
    calling out. Faces +X."""
    head, hands = person("happi_bla", "tofs_svart", arms="forward")
    box((0.06, 0.36, 0.6), (0.21, 0, 0.92), "tofs_vit")
    cyl(0.12, 0.05, head + Vector((0, 0, 0.05)), "tofs_vit", verts=10)
    box((0.16, 0.08, 0.02), hands[0] + Vector((0.08, 0, 0.0)), "stal")
    export("forsaljare", bevel=0.0)


def taiko():
    """A festival drummer at a big taiko drum on its stand: the drum and the drummer's body (Trumma)
    and two arms with sticks (ArmV, ArmH, origins at the shoulders) that swing. Faces +X."""
    cyl(0.55, 0.8, (0.85, 0, 1.0), "tra_brun", verts=16, rot=(0, math.pi / 2, 0))
    for x in (0.44, 1.26):
        cyl(0.56, 0.04, (x, 0, 1.0), "tofs_vit", verts=16, rot=(0, math.pi / 2, 0))
    for y in (-0.35, 0.35):
        tube((0.6, y, 0.0), (0.85, y * 0.7, 0.55), 0.05, "tra_morkbrun", verts=5)
        tube((1.1, y, 0.0), (0.85, y * 0.7, 0.55), 0.05, "tra_morkbrun", verts=5)
    head, _ = person("happi_rod", "tofs_svart", arms="none")
    cyl(0.12, 0.05, head + Vector((0, 0, 0.04)), "tofs_vit", verts=10)
    part("Trumma", (0, 0, 0))
    for side, name in ((-1, "ArmV"), (1, "ArmH")):
        sh = Vector((0, side * 0.25, 1.4))
        tube(sh, (0.32, side * 0.2, 1.18), 0.055, "happi_rod", verts=5)
        tube((0.32, side * 0.2, 1.18), (0.62, side * 0.12, 1.3), 0.022, "tra_brun", verts=4)
        part(name, sh)
    export_parts("taiko")


def yukatapar():
    """A couple in summer yukata walking side by side: he in navy, she in pink with a red obi, her hair
    up, holding a round fan. Faces +X."""
    person("yukata_bla", "yukata_bla", shoes="tra_brun", skirt=True, at=(0, -0.35, 0))
    box((0.44, 0.44, 0.08), (0.0, -0.35, 0.9), "tofs_svart")
    head, hands = person("yukata_rosa", "yukata_rosa", shoes="tra_brun", skirt=True, scale=0.94, at=(0, 0.35, 0))
    box((0.42, 0.42, 0.14), (0.0, 0.35, 0.86), "kimono_rod")
    blob(0.07, head + Vector((-0.07, 0, 0.11)), "har_svart", jitter=0.0)
    cyl(0.12, 0.01, hands[1] + Vector((0.06, 0, 0.12)), "kimono_rod", verts=12, rot=(math.pi / 2, 0, 0))
    export("yukatapar", bevel=0.0)


def hjort():
    """A sika deer like those of Nara: a slender brown body with white spots and rump, thin legs, the
    head held up with small antlers. Faces +X."""
    rnd = random.Random(5)
    blob(0.32, (0, 0, 0.95), "hjort_brun", scale=(1.6, 0.7, 0.75), jitter=0.05, subdiv=2)
    for k in range(12):
        y = (0.2 if k % 2 else -0.2)
        dot((rnd.uniform(-0.35, 0.35), y, rnd.uniform(1.0, 1.12)), 0.035, "hjort_ljus")
    blob(0.15, (-0.48, 0, 0.98), "hjort_ljus", scale=(0.6, 1.0, 1.0), jitter=0.0)
    for x in (-0.33, 0.33):
        for y in (-0.12, 0.12):
            taper((x, y, 0.8), (x, y, 0.0), 0.06, 0.03, "hjort_brun", verts=5)
    taper((0.4, 0, 1.05), (0.62, 0, 1.45), 0.12, 0.08, "hjort_brun", verts=6)
    blob(0.12, (0.72, 0, 1.5), "hjort_brun", scale=(1.5, 0.75, 0.8), jitter=0.0)
    for y in (-0.08, 0.08):
        cone(0.04, 0.14, (0.66, y * 1.6, 1.62), "hjort_brun", verts=4)
        tube((0.68, y, 1.6), (0.62, y * 2.0, 1.85), 0.015, "tanuki_ljus", verts=3)
    export("hjort", bevel=0.0)


def trana():
    """A red-crowned crane: a white body with black tail plumes, a black neck, the red crown and long
    dark legs. Faces +X."""
    blob(0.22, (0, 0, 1.0), "trana_vit", scale=(1.8, 0.8, 0.8), jitter=0.0)
    blob(0.15, (-0.36, 0, 0.95), "trana_svart", scale=(1.5, 0.8, 0.7), jitter=0.1)
    taper((0.3, 0, 1.05), (0.46, 0, 1.55), 0.06, 0.04, "trana_svart", verts=5)
    blob(0.06, (0.48, 0, 1.58), "trana_vit", jitter=0.0)
    dot((0.47, 0, 1.64), 0.03, "trana_rod")
    tube((0.53, 0, 1.58), (0.68, 0, 1.55), 0.012, "nab_gul", verts=3)
    for y in (-0.05, 0.05):
        tube((0, y, 0.85), (0.02, y, 0.0), 0.014, "tofs_svart", verts=3)
    export("trana", bevel=0.0)


def katt():
    """A calico cat sitting with its tail curled round: white with orange and black patches. Faces +X."""
    blob(0.13, (-0.02, 0, 0.13), "katt_vit", scale=(1.2, 0.9, 1.0), jitter=0.0, subdiv=2)         # haunches
    taper((0.0, 0, 0.12), (0.05, 0, 0.3), 0.09, 0.065, "katt_vit", verts=8)                        # chest
    blob(0.07, (-0.08, 0.07, 0.18), "katt_ora", scale=(1.0, 0.6, 1.0), jitter=0.0)               # patches
    blob(0.06, (0.0, -0.09, 0.12), "katt_svart", scale=(1.0, 0.5, 1.0), jitter=0.0)
    for y in (-0.035, 0.035):
        tube((0.08, y, 0.22), (0.09, y, 0.01), 0.02, "katt_vit", verts=5)                           # forelegs
        blob(0.025, (0.11, y, 0.015), "katt_vit", scale=(1.4, 1.0, 0.6), jitter=0.0)
    blob(0.075, (0.07, 0, 0.35), "katt_vit", scale=(1.0, 1.1, 0.95), jitter=0.0, subdiv=2)         # head
    blob(0.045, (0.05, 0.035, 0.39), "katt_ora", scale=(1.0, 0.8, 0.7), jitter=0.0)
    dot((0.145, 0, 0.335), 0.012, "kimono_rod")                                                      # nose
    for y in (-0.03, 0.03):
        dot((0.135, y, 0.36), 0.01, "tofs_svart")                                                    # eyes
        cone(0.028, 0.06, (0.06, y * 1.6, 0.43), "katt_vit" if y < 0 else "katt_ora", verts=4)      # ears
    tube((-0.14, 0, 0.04), (-0.05, 0.14, 0.02), 0.022, "katt_ora", verts=5)                         # tail
    tube((-0.05, 0.14, 0.02), (0.1, 0.11, 0.02), 0.02, "katt_ora", verts=5)
    export("katt", bevel=0.0)


def apa():
    """A Japanese macaque bathing in a hot spring: shaggy grey-brown head and shoulders and a red face,
    sitting in the water up to its chest (origin at the water line). Faces +X."""
    blob(0.2, (0, 0, 0.0), "apa_fall", scale=(0.9, 1.15, 1.0), jitter=0.12, subdiv=2)            # shoulders
    for y in (-0.17, 0.17):                                                                         # arms resting
        tube((0.02, y, 0.05), (0.2, y * 1.15, -0.02), 0.06, "apa_fall", verts=6)                    # on the water
        blob(0.045, (0.23, y * 1.15, -0.02), "apa_ansikte", scale=(1.3, 1.0, 0.6), jitter=0.0)
    blob(0.14, (0.02, 0, 0.26), "apa_fall", scale=(1.0, 1.05, 0.95), jitter=0.12, subdiv=2)      # furry head
    blob(0.09, (0.05, 0, 0.36), "apa_fall", scale=(1.1, 1.2, 0.6), jitter=0.2, subdiv=1, seed=3)  # crown
    blob(0.08, (0.12, 0, 0.24), "apa_ansikte", scale=(0.55, 1.0, 1.15), jitter=0.0, subdiv=2)     # red face
    dot((0.17, 0, 0.215), 0.018, "apa_ansikte")                                                      # nose
    for y in (-0.035, 0.035):
        dot((0.165, y, 0.26), 0.013, "tofs_svart")                                                   # eyes
        blob(0.035, (0.03, y * 3.7, 0.27), "apa_ansikte", scale=(0.5, 0.8, 1.0), jitter=0.0)        # ears
    export("apa", bevel=0.0)


def shiba():
    """A shiba inu trotting: a fox-red coat with a cream belly and face, pricked ears and a curled tail.
    Faces +X."""
    blob(0.18, (0, 0, 0.38), "shiba", scale=(1.6, 0.75, 0.8), jitter=0.0, subdiv=2)
    blob(0.1, (0.02, 0, 0.3), "shiba_ljus", scale=(2.2, 0.8, 0.5), jitter=0.0)
    for x in (-0.18, 0.18):
        for y in (-0.07, 0.07):
            taper((x, y, 0.32), (x, y, 0.0), 0.04, 0.03, "shiba", verts=5)
    blob(0.11, (0.32, 0, 0.55), "shiba", jitter=0.0)
    blob(0.06, (0.42, 0, 0.52), "shiba_ljus", scale=(1.2, 0.9, 0.8), jitter=0.0)
    for y in (-0.05, 0.05):
        cone(0.035, 0.08, (0.3, y, 0.66), "shiba", verts=4)
    bpy.ops.mesh.primitive_torus_add(major_radius=0.07, minor_radius=0.035, major_segments=10, minor_segments=5,
                                     location=(-0.26, 0, 0.55), rotation=(math.pi / 2, 0, 0))
    _finish(bpy.context.object, "shiba")
    export("shiba", bevel=0.0)


def pachinko():
    """A pachinko parlour: a two-storey box with a bright facade of neon panels and bands, a lit
    entrance and a sign board on the roof (the game writes パチンコ on it). Faces -Y."""
    box((16.0, 12.0, 8.0), (0, 0, 4.0), "pachinko_vagg")
    for k, c in enumerate(("neon_rosa", "neon_gul", "neon_bla", "neon_lila", "neon_ora", "neon_gron")):
        box((2.2, 0.1, 5.0), (-6.5 + k * 2.6, -6.05, 4.8), c)
    for z in (7.5, 2.0):
        box((16.2, 0.12, 0.4), (0, -6.07, z), "neon_vit")
    box((4.0, 0.12, 2.0), (0, -6.06, 1.0), "automat_lyse")
    box((10.0, 0.4, 2.2), (0, -4.5, 9.4), "rustning_svart")
    for x in (-4.0, 4.0):
        tube((x, -4.5, 8.0), (x, -4.5, 8.3), 0.12, "stal", verts=6)
    export("pachinko", bevel=0.0)


def telefonkiosk():
    """A green public phone booth: a glass box in a green frame under a lit roof band, the grey phone
    on its shelf inside. Faces -Y."""
    box((1.1, 1.1, 0.1), (0, 0, 0.05), "betong")
    for x in (-0.48, 0.48):
        for y in (-0.48, 0.48):
            box((0.07, 0.07, 2.1), (x, y, 1.1), "telefon_gron")
    for y in (-0.48, 0.48):
        box((0.9, 0.03, 1.7), (0, y, 1.15), "glas_bla")
    for x in (-0.48, 0.48):
        box((0.03, 0.9, 1.7), (x, 0, 1.15), "glas_bla")
    box((1.12, 1.12, 0.1), (0, 0, 2.08), "automat_lyse")
    box((1.12, 1.12, 0.16), (0, 0, 2.21), "telefon_gron")
    box((0.6, 0.3, 0.04), (0, 0.32, 1.05), "trafik_gra")
    box((0.28, 0.16, 0.35), (0, 0.38, 1.25), "telefon_gron")
    export("telefonkiosk", bevel=0.0)


def tempelklocka():
    """A temple bell tower (shōrō): a stone base, four vermilion posts under a hipped roof, the big
    bronze bell hanging inside (Paviljong), and the log striker on ropes (Stock, origin at the top
    of its ropes) that swings back to strike."""
    box((4.6, 4.6, 0.6), (0, 0, 0.3), "sten_gra")
    for x in (-1.8, 1.8):
        for y in (-1.8, 1.8):
            cyl(0.14, 3.4, (x, y, 2.3), "vermiljon", verts=8)
    for y in (-1.8, 1.8):
        box((4.0, 0.2, 0.25), (0, y, 3.9), "vermiljon")
    box((3.8, 0.25, 0.25), (0, 0, 3.9), "vermiljon")                                             # bell beam
    hip_roof(3.0, 3.0, 4.0, 1.6, "tak_gra", ridge=0.25, lift=0.5)
    cyl(0.6, 1.3, (0, 0, 2.75), "brons", verts=14, radius_top=0.48)
    blob(0.48, (0, 0, 3.4), "brons", scale=(1.0, 1.0, 0.5), jitter=0.0)
    cyl(0.62, 0.12, (0, 0, 2.15), "brons", verts=14)
    tube((0, 0, 3.6), (0, 0, 3.95), 0.05, "stal", verts=5)
    part("Paviljong", (0, 0, 0))
    tube((-2.1, 0, 2.7), (-0.7, 0, 2.7), 0.11, "tra_brun", verts=8)
    for x in (-1.8, -1.0):
        tube((x, 0, 2.7), (x - 0.0, 0, 3.85), 0.015, "rep", verts=3)
    part("Stock", (-1.4, 0, 3.85))
    export_parts("tempelklocka")


def maneki_neko():
    """A beckoning cat (maneki-neko) for a shop front, 0.9 m: white with a red collar and gold bell,
    holding a gold coin; the raised paw (Tass, origin at the shoulder) beckons. Faces +X."""
    box((0.5, 0.5, 0.1), (0, 0, 0.05), "kimono_rod")
    blob(0.27, (0, 0, 0.42), "katt_vit", scale=(0.9, 1.0, 1.15), jitter=0.0, subdiv=2)
    blob(0.25, (0.03, 0, 0.9), "katt_vit", scale=(1.0, 1.1, 0.95), jitter=0.0, subdiv=2)
    for y in (-0.13, 0.13):
        cone(0.08, 0.14, (0.0, y, 1.13), "katt_vit", verts=4)
        dot((0.26, y * 0.6, 0.93), 0.025, "tofs_svart")
    cyl(0.2, 0.05, (0.03, 0, 0.68), "kimono_rod", verts=12)
    dot((0.22, 0, 0.64), 0.05, "guld")
    box((0.04, 0.22, 0.14), (0.26, -0.1, 0.45), "guld")
    blob(0.07, (0.18, 0.17, 0.95), "katt_ora", jitter=0.0)
    part("Katt", (0, 0, 0))
    tube((0.05, 0.2, 0.72), (0.14, 0.28, 1.08), 0.07, "katt_vit", verts=6)
    blob(0.08, (0.15, 0.28, 1.12), "katt_vit", jitter=0.0)
    part("Tass", (0.05, 0.2, 0.72))
    export_parts("maneki_neko")


def wagasa():
    """Three open paper umbrellas (wagasa) on a stand outside a tea house: red, blue and cream, on
    bamboo shafts."""
    box((1.6, 0.6, 0.12), (0, 0, 0.06), "tra_morkbrun")
    for k, (c, x, tilt) in enumerate((("kimono_rod", -0.7, 0.2), ("kimono_bla", 0.1, -0.1), ("papper", 0.8, 0.25))):
        top = Vector((x + math.sin(tilt) * 1.7, 0, 0.1 + math.cos(tilt) * 1.7))
        tube((x, 0, 0.1), top, 0.02, "bambu_ljus", verts=4)
        bpy.ops.mesh.primitive_cone_add(vertices=16, radius1=0.95, radius2=0.05, depth=0.32, location=top)
        o = bpy.context.object
        _finish(o, c, rot=(0, tilt, 0))
    export("wagasa", bevel=0.0)


def kingyo():
    """A goldfish-scooping stall (kingyo-sukui): a blue tub of orange fish under a red-and-white
    striped awning on four posts, with red lanterns along the front. Faces -Y."""
    for x in (-1.4, 1.4):
        for y in (-0.9, 0.9):
            box((0.08, 0.08, 2.3), (x, y, 1.15), "tra_brun")
    for k in range(8):
        box((0.37, 2.0, 0.05), (-1.3 + k * 0.37, 0, 2.32), "markis_rod_jp" if k % 2 else "markis_vit_jp",
            rot=(math.radians(8), 0, 0))
    box((2.4, 1.2, 0.4), (0, 0, 0.2), "kingyo_bla")
    box((2.3, 1.1, 0.02), (0, 0, 0.39), "glas_bla")
    rnd = random.Random(9)
    for k in range(14):
        blob(0.05, (rnd.uniform(-1.0, 1.0), rnd.uniform(-0.45, 0.45), 0.41), "apelsin", scale=(1.6, 0.7, 0.5), jitter=0.0)
    for k in range(5):
        blob(0.15, (-1.2 + k * 0.6, -0.95, 1.95), "lykta_rod", scale=(1.0, 1.0, 1.3), jitter=0.0)
    export("kingyo", bevel=0.0)


def nobori():
    """A tall shop banner (nobori) on its pole: a narrow red cloth with a white band at the top and a
    yellow one at the foot, standing in a weighted base. The cloth hangs along +Y."""
    cyl(0.2, 0.25, (0, 0, 0.12), "betong", verts=8)
    tube((0, 0, 0.2), (0, 0, 3.7), 0.025, "stal", verts=5)
    tube((0, 0, 3.6), (0, 0.65, 3.6), 0.015, "stal", verts=4)
    box((0.02, 0.6, 2.4), (0, 0.33, 2.35), "nobori_rod")
    box((0.025, 0.6, 0.35), (0, 0.33, 3.38), "nobori_vit")
    box((0.025, 0.6, 0.25), (0, 0.33, 1.25), "nobori_gul")
    export("nobori", bevel=0.0)


def ema():
    """A rack of ema, the wooden votive plaques worshippers hang up, under a little gabled roof. Faces
    -Y."""
    for x in (-1.0, 1.0):
        box((0.1, 0.1, 1.9), (x, 0, 0.95), "tra_morkbrun")
    for z in (1.1, 1.5):
        box((2.1, 0.06, 0.06), (0, 0, z), "tra_morkbrun")
    hip_roof(1.3, 0.45, 1.85, 0.35, "tak_gra", ridge=0.8, lift=0.05)
    rnd = random.Random(3)
    for z in (1.0, 1.4):
        for k in range(10):
            box((0.15, 0.02, 0.1), (-0.9 + k * 0.2 + rnd.uniform(-0.02, 0.02), -0.05, z), "ema_tra",
                rot=(0, rnd.uniform(-0.2, 0.2), 0))
    export("ema", bevel=0.0)


def trafikljus():
    """A Japanese traffic light: a grey pole, an arm out along +Y with the horizontal signal (green,
    yellow, red) and a pedestrian signal on the pole; the lit lamps are parts (Gron, Rod) the game
    turns on and off. The lamps face +X."""
    cyl(0.1, 5.6, (0, 0, 2.8), "trafik_gra", verts=8)
    tube((0, 0, 5.3), (0, 3.2, 5.3), 0.06, "trafik_gra", verts=6)
    box((0.3, 1.45, 0.45), (0, 2.6, 5.3), "trafik_gra")
    for y in (2.15, 2.6, 3.05):
        cyl(0.15, 0.05, (0.16, y, 5.3), "lampa_av", verts=12, rot=(0, math.pi / 2, 0))
        box((0.2, 0.36, 0.04), (0.22, y, 5.5), "trafik_gra")
    box((0.22, 0.32, 0.6), (0.14, 0, 2.7), "trafik_gra")
    part("Stolpe", (0, 0, 0))
    cyl(0.152, 0.06, (0.17, 2.15, 5.3), "lampa_gron", verts=12, rot=(0, math.pi / 2, 0))
    box((0.04, 0.24, 0.22), (0.26, 0, 2.55), "lampa_gron")
    part("Gron", (0, 0, 0))
    cyl(0.152, 0.06, (0.17, 3.05, 5.3), "lampa_rod", verts=12, rot=(0, math.pi / 2, 0))
    box((0.04, 0.24, 0.22), (0.26, 0, 2.85), "lampa_rod")
    part("Rod", (0, 0, 0))
    export_parts("trafikljus")


bpy.ops.wm.read_factory_settings(use_empty=True)
only = sys.argv[sys.argv.index("--") + 2:] if "--" in sys.argv else []
BUILDS = [
    ("pagod5", lambda: pagoda("pagod5", 5, 9.0, 38.0, "tak_gra", "vermiljon")),
    ("pagod3", lambda: pagoda("pagod3", 3, 7.0, 25.0, "tak_gron", "vermiljon")),
    ("tempelhall", tempelhall), ("torii", torii), ("torii_stor", lambda: torii("torii_stor", big=True)),
    ("stenlykta", stenlykta), ("lyktsnore", lyktsnore),
    ("machiya_1", lambda: machiya("machiya_1", 1, 2)), ("machiya_2", lambda: machiya("machiya_2", 2, 2)),
    ("machiya_3", lambda: machiya("machiya_3", 3, 1)),
    ("yatai", yatai), ("automat", automat), ("taikobashi", taikobashi),
    ("skyskrapa_1", lambda: skyskrapa("skyskrapa_1", 1, 30.0, 30.0, 120.0, "glas_bla", "fonster_kall")),
    ("skyskrapa_2", lambda: skyskrapa("skyskrapa_2", 2, 24.0, 36.0, 84.0, "glas_mork", "fonster_lyse")),
    ("skyskrapa_3", lambda: skyskrapa("skyskrapa_3", 3, 20.0, 20.0, 56.0, "betong_mork", "fonster_lyse")),
    ("neonhus_1", lambda: neonhus("neonhus_1", 1, 14.0, 12.0, 26.0)),
    ("neonhus_2", lambda: neonhus("neonhus_2", 2, 11.0, 12.0, 20.0)),
    ("neonhus_3", lambda: neonhus("neonhus_3", 3, 16.0, 12.0, 32.0)),
    ("tokyotorn", tokyotorn), ("slott", slott), ("shinkansen", shinkansen), ("viadukt", viadukt), ("gatlykta", gatlykta),
    ("korsbar_1", lambda: korsbar(1)), ("korsbar_2", lambda: korsbar(2)), ("lonn_1", lambda: lonn(1)),
    ("bambu_1", lambda: bambu(1)), ("bambu_2", lambda: bambu(2)), ("tall_jp_1", lambda: tall_jp(1)),
    ("tall_jp_2", lambda: tall_jp(2)),
    ("dohyo", dohyo), ("sumo", sumo), ("geisha", geisha), ("gyoji", gyoji),
    ("vattenfall", vattenfall), ("dojo", dojo), ("teleportport", teleporttorii),
    ("samurai", samurai), ("oni", oni), ("ninja", ninja), ("kitsune", kitsune), ("drake", drake), ("shuriken", shuriken),
    ("elstolpe", elstolpe), ("cyklar", cyklar), ("keibil", keibil), ("postlada", postlada), ("jizo", jizo),
    ("lykta_par", lykta_par), ("krukor", krukor), ("kraka", kraka), ("yakatabune", yakatabune), ("koi", koi),
    ("kontorist", kontorist), ("skolelev", skolelev),
    ("tanuki", tanuki), ("komainu", komainu), ("temizuya", temizuya), ("hokora", hokora), ("takegaki", takegaki),
    ("kakashi", kakashi), ("hager", hager), ("koinobori", koinobori), ("munk", munk), ("turist", turist),
    ("busskur", busskur),
    ("sugi_1", lambda: sugi(1)), ("sugi_2", lambda: sugi(2)), ("tebuske_1", tebuske), ("ginkgo_1", lambda: ginkgo(1)),
    ("chaya", chaya), ("gassho", gassho), ("ryokan", ryokan), ("pariserhjul", pariserhjul),
    ("fiskebat_jp", fiskebat_jp), ("fyr_jp", fyr_jp),
    # the living Japan
    ("miko", miko), ("skolbarn", skolbarn), ("mamachari", mamachari), ("rikscha", rikscha), ("mikoshi", mikoshi),
    ("taxi", taxi), ("keilastbil", keilastbil), ("moped", moped), ("svanbat", svanbat), ("fiskare", fiskare),
    ("teplockare", teplockare), ("risbonde", risbonde), ("pilgrim", pilgrim), ("forsaljare", forsaljare),
    ("taiko", taiko), ("yukatapar", yukatapar), ("hjort", hjort), ("trana", trana), ("katt", katt), ("apa", apa),
    ("shiba", shiba), ("pachinko", pachinko), ("telefonkiosk", telefonkiosk), ("tempelklocka", tempelklocka),
    ("maneki_neko", maneki_neko), ("wagasa", wagasa), ("kingyo", kingyo), ("nobori", nobori), ("ema", ema),
    ("trafikljus", trafikljus),
]
for name, build in BUILDS:
    if not only or name in only:
        build()
print("JAPANS MODELLER KLARA")
