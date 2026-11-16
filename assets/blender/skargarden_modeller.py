"""Builds every Skärgården model in Blender and exports one GLB per model.

    blender --background --python assets/blender/skargarden_modeller.py -- game/world/skargarden/models

Blender is Z-up with +X as "forward"; the glTF exporter turns that into Godot's Y-up.
All models stand on the origin. Low-poly style: few faces, flat shading, a small
angle-limited bevel so edges catch the light. Colours are shared named materials.
The cyclist is exported in loose parts (frame, wheels, crank, legs …) whose origins sit
at the joints, so Godot can pedal the legs from the real cadence.
"""
import math
import os
import random
import sys

import bmesh
import bpy
import mathutils.noise
from mathutils import Vector

OUT = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "models"
os.makedirs(OUT, exist_ok=True)

PALETTE = {
    "falu": "8f2a1f", "vit": "f1ece2", "tegel": "c4542f", "takgra": "4a4e57", "grund": "8c8a8f",
    "granit": "c98f7f", "granit_mork": "a87064", "tra": "9a6a43", "tra_mork": "6e4a2e", "tra_gra": "8d8579",
    "fonster": "ffd27a", "dorr": "2f5d4a", "stam_lag": "6b5446", "stam_hog": "c46d3b", "barr": "3f6b3a",
    "barr_ljus": "557f43", "gran": "2f5634", "ljung": "94508f", "ljung_ljus": "c08ac6", "ljung_ris": "4a5a32", "gras": "6f8f45",
    "gras_gul": "b3b04a", "gras_gron": "7f9a3c", "blomma": "f6f2ea", "moln": "f5ece4",
    "bjork_stam": "ece8df", "bjork_lov": "9cbb4e", "bjork_lov2": "b6cc62", "en": "5d7f55", "vass": "c4b56c",
    "vass_gron": "8e9c4e", "nackros": "4f7d3b", "kummel": "efece4", "prick_rod": "c0392b", "prick_gron": "2e7d4f",
    "ved": "a7764a", "ved_ande": "d9b58a", "stang": "8f7f66", "gul": "e2bd5a", "flyttblock": "9b9790",
    "segel": "f4f1ea", "mas_vit": "f7f7f2", "mas_gra": "9aa3ad", "brevlada": "c9c4b8", "fyr_rod": "c8302c",
    "fyr_vit": "f4f1ea", "fyr_ljus": "fff1b0", "bat_vit": "eeeeea", "bat_bla": "2f5f8f", "bat_rod": "b5352d",
    "flagga_bla": "1f5aa6", "flagga_gul": "f2c230", "metall": "8a9099", "svart": "1f2124",
    "ram": "c8302c", "dack": "202226", "falg": "9aa1aa", "hud": "e0b394", "trika": "1f5aa6",
    "trika_vit": "f4f5f7", "byxor": "1d2128", "hjalm": "f4f5f7", "sko": "f4f5f7", "sadel": "2a2d33",
    # Round 4: harbour, gardens, shore plants, sea life, signs.
    "livboj": "e8592a", "nat": "4b5a48", "nat_brun": "7a5a3c", "kork": "e39a3c", "glas": "a9c9d8",
    "glas_mork": "36444f", "kajak": "e8b02a", "jacka": "c8402f", "ejder_vit": "f2efe6", "ejder_svart": "2a2c2f",
    "ejder_brun": "7d6045", "eka_gron": "4d7a62", "farja_gron": "2c4a3f", "syren": "4d7838", "syren2": "5f8a42",
    "apple_lov": "6a973e", "apple_lov2": "7fa648", "apple": "c8322a", "al_stam": "4b4540", "al_lov": "466a33",
    "al_lov2": "557a3b", "ronn_stam": "8a8478", "ronn_lov": "7c9e46", "ronn_lov2": "93b052", "ronnbar": "e0502a",
    "havtorn": "7f8f72", "havtorn2": "95a084", "havtorn_bar": "f08a1e", "salg": "8a9d68", "salg2": "a0ae7c",
    "ris": "4a6a36", "ris2": "5a7a3e", "blabar": "3d4a8f", "lingonris": "3b5b30", "lingon": "c8282b",
    "mossa": "86a33c", "mossa2": "a3b04a", "renlav": "b4bb9a", "renlav2": "a1aa88", "kaveldun": "5b3a22",
    "strandkal": "8aa6a3", "strandkal_fro": "c0c9a0", "skylt_vit": "f4f4f0", "skylt_rod": "c8282b",
    "skylt_svart": "1d1f22", "tvatt_bla": "4f7fc0", "tvatt_rod": "d0503c", "tvatt_gul": "e8c44a",
    "stolpe": "9aa0a6",
    # Round 6: plants closer to the concept art.
    "ljung_rosa": "b0659f", "ljung_bas": "52633a", "gras_guld": "d6ae58", "gras_torr": "bd9a4e",
    "rallarros": "cf4f97", "rallarros2": "e27cb4", "rallarros_blad": "4c7838", "barr_mork": "2c5230",
    "tegel_mork": "a6452c", "takgra_ljus": "5d636c",
    # Round 7: church village, pastures and the marina.
    "hassel": "6f9a45", "hassel2": "5a873b", "nypon_lov": "4a7536", "nypon": "d03a28", "nypon_blomma": "ec8fb6",
    "kyrktak": "3c4048", "kyrkfonster": "3a4a5c", "guld": "e0b043", "ko_rod": "9a4b34", "ko_svart": "2c2a2a",
    "ko_vit": "efe9df", "ko_horn": "d9cfb8", "ull": "ece4d2", "bil_bla": "86aed0", "bil_tak": "efe6cf",
    # Texture round 2: more house colours.
    "bla_gra": "86a2c0", "ljusgul": "efd897", "ljusgron": "92b57e",
}
EMISSIVE = {"fonster": 1.2, "fyr_ljus": 4.0}
_materials = {}


def srgb_to_linear(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def mat(name):
    if name not in _materials:
        hexcol = PALETTE[name]
        rgb = [srgb_to_linear(int(hexcol[i:i + 2], 16) / 255) for i in (0, 2, 4)]
        m = bpy.data.materials.new(name)
        m.use_nodes = True
        bsdf = m.node_tree.nodes["Principled BSDF"]
        bsdf.inputs["Base Color"].default_value = (*rgb, 1)
        bsdf.inputs["Roughness"].default_value = 0.85
        if name in EMISSIVE:
            bsdf.inputs["Emission Color"].default_value = (*rgb, 1)
            bsdf.inputs["Emission Strength"].default_value = EMISSIVE[name]
        _materials[name] = m
    return _materials[name]


def clear():
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    for me in list(bpy.data.meshes):
        if me.users == 0:
            bpy.data.meshes.remove(me)


def _finish(o, material, rot=None):
    if rot:
        o.rotation_euler = rot
    bpy.context.view_layer.objects.active = o
    o.select_set(True)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    o.select_set(False)
    o.data.materials.append(mat(material))
    return o


def box(size, loc, material, rot=None):
    bpy.ops.mesh.primitive_cube_add(location=loc)
    o = bpy.context.object
    o.scale = (size[0] / 2, size[1] / 2, size[2] / 2)
    return _finish(o, material, rot)


def cyl(radius, depth, loc, material, verts=8, rot=None, radius_top=None):
    if radius_top is None:
        bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=radius, depth=depth, location=loc)
    else:
        bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=radius, radius2=radius_top, depth=depth, location=loc)
    return _finish(bpy.context.object, material, rot)


def cone(radius, depth, loc, material, verts=8):
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=radius, radius2=0, depth=depth, location=loc)
    return _finish(bpy.context.object, material)


def blob(radius, loc, material, scale=(1, 1, 1), jitter=0.18, subdiv=1, seed=0):
    """Faceted lump: an icosphere with jittered vertices (canopies, boulders, bushes)."""
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdiv, radius=radius, location=loc)
    o = bpy.context.object
    rnd = random.Random(seed)
    for v in o.data.vertices:
        v.co *= 1 + rnd.uniform(-jitter, jitter)
    o.scale = scale
    return _finish(o, material)


def dot(loc, r, material):
    """A tiny pyramid for berries, apples and floats: six triangles instead of a sphere's twenty."""
    bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=r * 1.2, radius2=0, depth=r * 2.2, location=loc)
    return _finish(bpy.context.object, material)


def taper(a, b, r1, r2, material, verts=6):
    """A tapering trunk piece from point a (radius r1) to point b (radius r2)."""
    a, b = Vector(a), Vector(b)
    d = b - a
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r1, radius2=r2, depth=d.length, location=(a + b) / 2)
    o = bpy.context.object
    o.rotation_mode = "QUATERNION"
    o.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(d.normalized())
    return _finish(o, material)


def tube(a, b, radius, material, verts=6):
    """Cylinder from point a to point b."""
    a, b = Vector(a), Vector(b)
    d = b - a
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=radius, depth=d.length, location=(a + b) / 2)
    o = bpy.context.object
    o.rotation_mode = "QUATERNION"
    o.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(d.normalized())
    return _finish(o, material)


def prism(profile, length, material, x0=0.0):
    """Extrude a 2D profile [(y, z), …] along X from x0 - length/2 to x0 + length/2."""
    bm = bmesh.new()
    left = [bm.verts.new((x0 - length / 2, y, z)) for y, z in profile]
    right = [bm.verts.new((x0 + length / 2, y, z)) for y, z in profile]
    bm.faces.new(list(reversed(left)))
    bm.faces.new(right)
    n = len(profile)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((left[i], left[j], right[j], right[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new("prism")
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new("prism", me)
    bpy.context.collection.objects.link(o)
    o.data.materials.append(mat(material))
    return o


def slab_y(points, thickness, material, y=0.0):
    """Extrude a 2D polygon [(x, z), …] across Y (a board, a pennant, a gable end facing ±Y)."""
    bm = bmesh.new()
    front = [bm.verts.new((x, y - thickness / 2, z)) for x, z in points]
    back = [bm.verts.new((x, y + thickness / 2, z)) for x, z in points]
    bm.faces.new(front)
    bm.faces.new(list(reversed(back)))
    n = len(points)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((front[i], back[i], back[j], front[j]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new("slab")
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new("slab", me)
    bpy.context.collection.objects.link(o)
    o.data.materials.append(mat(material))
    return o


def ring(loc, radius, thick, material, axis="y", segments=12):
    """A torus whose hole looks along `axis` (life rings, the wheels on the cycle sign)."""
    rot = {"x": (0, math.pi / 2, 0), "y": (math.pi / 2, 0, 0), "z": (0, 0, 0)}[axis]
    bpy.ops.mesh.primitive_torus_add(major_radius=radius, minor_radius=thick, major_segments=segments,
                                     minor_segments=4, location=loc, rotation=rot)
    return _finish(bpy.context.object, material)


def livboj(loc, axis="y", r=0.3):
    """Orange life ring with four white bands."""
    ring(loc, r, r * 0.24, "livboj", axis)
    for k in range(4):
        a = math.pi / 4 + k * math.pi / 2
        if axis == "x":
            p = (loc[0], loc[1] + r * math.cos(a), loc[2] + r * math.sin(a))
            box((r * 0.55, r * 0.34, r * 0.55), p, "vit", rot=(a, 0, 0))
        else:
            p = (loc[0] + r * math.cos(a), loc[1], loc[2] + r * math.sin(a))
            box((r * 0.34, r * 0.55, r * 0.55), p, "vit", rot=(0, -a, 0))


# MODELLER=a,b builds and exports only those models (the rest are built and thrown away).
ONLY = set(filter(None, os.environ.get("MODELLER", "").split(",")))


def export(name, bevel=0.03, origin=(0, 0, 0)):
    """Join everything in the scene into one object, bevel sharp edges, flat-shade and export."""
    if ONLY and name not in ONLY:
        clear()
        return
    objs = [o for o in bpy.data.objects if o.type == "MESH"]
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
    if bevel > 0:
        mod = o.modifiers.new("Fas", "BEVEL")
        mod.width = bevel
        mod.segments = 1
        mod.limit_method = "ANGLE"
        mod.angle_limit = math.radians(40)
        mod.use_clamp_overlap = True
    bpy.ops.object.shade_flat()
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, name + ".glb"), export_format="GLB",
                              use_selection=True, export_apply=True)
    print("exporterad", name, len(o.data.polygons), "ytor")
    clear()


# --- Buildings -----------------------------------------------------------------------------------

def gable_house(width, depth, wall_h, roof_h, wall_mat, roof_mat, trim=True):
    """Walls plus gable ends as one prism along X, a two-slab roof with overhang and white trim."""
    d, w = depth / 2, width
    prism([(-d, 0), (d, 0), (d, wall_h), (0, wall_h + roof_h), (-d, wall_h)], w, wall_mat)
    slope = math.atan2(roof_h, d)
    slab_len = math.hypot(d, roof_h) + 0.35
    for side in (-1, 1):
        cy = side * (d / 2 + 0.08)
        cz = wall_h + roof_h / 2 + 0.06
        theta = -side * slope
        box((w + 0.5, slab_len, 0.14), (0, cy, cz), roof_mat, rot=(theta, 0, 0))
        along = Vector((0, math.cos(theta), math.sin(theta)))      # down the slope towards the eave
        out = Vector((0, -math.sin(theta), math.cos(theta)))       # the roof's outward normal
        centre = Vector((0, cy, cz))
        if roof_mat == "tegel":
            # Rows of tiles: a small step every 0.3 m, every other row a shade darker.
            n = int(slab_len / 0.3)
            for k in range(n):
                t = -slab_len / 2 + (k + 0.5) * slab_len / n
                box((w + 0.5, 0.06, 0.05), centre + along * t + out * 0.09, "tegel_mork" if k % 2 else "tegel",
                    rot=(theta, 0, 0))
        else:
            # Standing seams of a sheet roof, running down the slope.
            x = -w / 2 - 0.15
            while x < w / 2 + 0.2:
                box((0.04, slab_len, 0.04), centre + out * 0.09 + Vector((x, 0, 0)), "takgra_ljus", rot=(theta, 0, 0))
                x += 0.5
        box((w + 0.5, 0.06, 0.2), centre + along * (slab_len / 2 - 0.02) + out * 0.0, "vit", rot=(theta, 0, 0))
    box((w + 0.55, 0.24, 0.14), (0, 0, wall_h + roof_h + 0.16), "tegel_mork" if roof_mat == "tegel" else "takgra_ljus")
    if trim:
        for x in (-w / 2, w / 2):
            for y in (-d, d):
                box((0.16, 0.16, wall_h), (x, y, wall_h / 2), "vit")
            for side in (-1, 1):  # barge boards along the gable edges
                box((0.12, math.hypot(d, roof_h) + 0.2, 0.18),
                    (x + math.copysign(0.07, x), side * d / 2, wall_h + roof_h / 2 + 0.02), "vit",
                    rot=(-side * slope, 0, 0))


def window(x, y, z, facing, w=0.8, h=0.95):
    """White frame with a glowing pane, on a wall facing ±Y (facing = ±1) or ±X (facing = ±2)."""
    if abs(facing) == 1:
        box((w + 0.16, 0.08, h + 0.16), (x, y + facing * 0.03, z), "vit")
        box((w, 0.09, h), (x, y + facing * 0.05, z), "fonster")
        box((0.06, 0.1, h), (x, y + facing * 0.06, z), "vit")
        box((w, 0.1, 0.05), (x, y + facing * 0.06, z + h * 0.08), "vit")
        box((w + 0.3, 0.16, 0.06), (x, y + facing * 0.08, z - h / 2 - 0.1), "vit")   # sill
    else:
        s = 1 if facing > 0 else -1
        box((0.08, w + 0.16, h + 0.16), (x + s * 0.03, y, z), "vit")
        box((0.09, w, h), (x + s * 0.05, y, z), "fonster")
        box((0.1, 0.06, h), (x + s * 0.06, y, z), "vit")
        box((0.1, w, 0.05), (x + s * 0.06, y, z + h * 0.08), "vit")
        box((0.16, w + 0.3, 0.06), (x + s * 0.08, y, z - h / 2 - 0.1), "vit")


def farstukvist(x, roof, yw=-2.0):
    """Small gabled porch over the front door: deck, steps, two posts and white gable boards."""
    box((2.0, 1.3, 0.42), (x, yw - 0.65, 0.21), "tra_gra")
    box((1.3, 0.45, 0.2), (x, yw - 1.5, 0.1), "tra_gra")
    for dx in (-0.85, 0.85):
        box((0.13, 0.13, 2.25), (x + dx, yw - 1.18, 1.53), "vit")
        box((0.06, 1.1, 0.06), (x + dx, yw - 0.65, 0.95), "vit")       # side rail
    rise, half = 0.6, 1.1
    slope = math.atan2(rise, half)
    for side in (-1, 1):
        box((math.hypot(half, rise) + 0.12, 1.55, 0.1), (x + side * half / 2, yw - 0.68, 2.7 + rise / 2 + 0.04),
            roof, rot=(0, side * slope, 0))
    slab_y([(x - half, 2.66), (x + half, 2.66), (x, 2.66 + rise)], 0.08, "vit", y=yw - 1.4)
    box((2.1, 0.14, 0.14), (x, yw - 1.38, 2.62), "vit")


def rodstuga():
    box((6.4, 4.4, 0.45), (0, 0, 0.12), "grund")
    gable_house(6.0, 4.0, 2.7, 1.9, "falu", "tegel")
    for x in (-1.7, 1.7):
        window(x, -2.0, 1.55, -1)
        window(x, 2.0, 1.55, 1)
    window(-3.0, 0, 1.6, -2, w=0.7)
    window(3.0, 0, 1.6, 2, w=0.7)
    window(-3.0, 0, 3.4, -2, w=0.5, h=0.6)
    box((0.95, 0.1, 1.9), (0.2, -2.04, 1.25), "dorr")
    box((1.25, 0.08, 2.15), (0.2, -2.01, 1.3), "vit")
    farstukvist(0.2, "tegel")
    box((0.5, 0.5, 1.4), (1.6, 0.6, 4.3), "tegel_mork")
    box((0.62, 0.62, 0.12), (1.6, 0.6, 5.0), "grund")
    export("rodstuga", bevel=0.025)


def sjobod():
    box((4.4, 5.4, 0.3), (0, 0, 0.05), "grund")
    prism([(-2.6, 0), (2.6, 0), (2.6, 2.4), (0, 3.9), (-2.6, 2.4)], 4.0, "falu", x0=0)
    # Gable towards -Y (the water) is the long side here: rotate the whole thing later in Godot if needed.
    slope = math.atan2(1.5, 2.6)
    for side in (-1, 1):
        box((4.5, math.hypot(2.6, 1.5) + 0.35, 0.14), (0, side * 1.38, 3.2), "takgra", rot=(-side * slope, 0, 0))
    for x in (-2.0, 2.0):
        for y in (-2.6, 2.6):
            box((0.16, 0.16, 2.4), (x, y, 1.2), "vit")
    box((0.1, 2.0, 2.0), (2.03, 0, 1.0), "tra_mork")
    box((0.08, 2.3, 2.25), (2.0, 0, 1.12), "vit")
    box((0.12, 0.06, 2.0), (2.06, 0, 1.0), "vit")
    window(-2.0, 1.2, 1.5, -2, w=0.6, h=0.6)
    livboj((-2.1, -1.0, 1.55), "x")
    livboj((0.6, 2.68, 1.5), "y")
    box((0.08, 0.9, 0.8), (-2.02, 0, 2.9), "tra_mork")       # loft hatch in the gable
    box((0.06, 1.05, 0.95), (-2.0, 0, 2.9), "vit")
    for y in (-1.6, 1.6):
        cyl(0.08, 0.6, (2.6, y, 0.3), "tra_mork", verts=6)   # mooring posts by the door
    export("sjobod", bevel=0.025)


def brygga():
    length, width = 12.0, 2.2
    x = -length / 2 + 0.1
    while x < length / 2:
        box((0.22, width, 0.08), (x, 0, 0), "tra_gra")
        x += 0.27
    for x in (-length / 2 + 0.3, -2, 2, length / 2 - 0.3):
        for y in (-width / 2 + 0.1, width / 2 - 0.1):
            cyl(0.13, 3.0, (x, y, -1.45), "tra_mork", verts=6)
    for y in (-width / 2 - 0.05, width / 2 + 0.05):
        box((length, 0.12, 0.16), (0, y, -0.1), "tra_mork")
    export("brygga", bevel=0.01)


def hull(length, beam, depth, outer, stripe=None, double=False):
    """Low-poly boat hull lofted from cross-sections along X (bow at +X). `double` gives a pointed
    stern too (snipa, kayak)."""
    sections = [(-0.5, 0.80, 0.85), (-0.25, 0.98, 1.0), (0.1, 1.0, 1.0), (0.35, 0.78, 0.92), (0.5, 0.05, 0.75)]
    if double:
        sections = [(-0.5, 0.05, 0.75), (-0.33, 0.8, 0.93), (-0.1, 1.0, 1.0), (0.12, 1.0, 1.0), (0.34, 0.78, 0.92),
                    (0.5, 0.05, 0.75)]
    bm = bmesh.new()
    rings = []
    for fx, fw, fd in sections:
        x = fx * length
        hw = beam / 2 * fw
        ring = [bm.verts.new((x, -hw, depth * 0.15)), bm.verts.new((x, -hw * 0.7, -depth * 0.55 * fd)),
                bm.verts.new((x, 0, -depth * fd)), bm.verts.new((x, hw * 0.7, -depth * 0.55 * fd)),
                bm.verts.new((x, hw, depth * 0.15))]
        rings.append(ring)
    for a, b in zip(rings, rings[1:]):
        for i in range(4):
            bm.faces.new((a[i], b[i], b[i + 1], a[i + 1]))
    bm.faces.new(rings[0])
    bm.faces.new(list(reversed(rings[-1])))
    deck = [r[0] for r in rings] + [r[4] for r in reversed(rings)]
    bm.faces.new(deck)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new("hull")
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new("hull", me)
    bpy.context.collection.objects.link(o)
    o.data.materials.append(mat(outer))
    if stripe:
        box((length * 0.82, beam * 1.02, 0.08), (-0.02 * length, 0, -depth * 0.05), stripe)
    return o


def roddbat():
    hull(3.2, 1.25, 0.45, "bat_vit", stripe="bat_bla")
    box((2.6, 1.0, 0.04), (-0.1, 0, 0.0), "tra")
    for x in (-0.9, 0.0, 0.8):
        box((0.22, 1.05, 0.06), (x, 0, 0.12), "tra")
    export("roddbat", bevel=0.01)


def fiskebat():
    hull(6.0, 2.2, 0.9, "bat_vit", stripe="bat_bla")
    box((5.0, 1.9, 0.06), (-0.2, 0, 0.14), "tra")
    box((1.8, 1.5, 1.3), (-0.6, 0, 0.8), "bat_vit")
    box((1.95, 1.65, 0.12), (-0.6, 0, 1.5), "bat_bla")
    for y in (-0.76, 0.76):
        box((1.2, 0.06, 0.45), (-0.5, y, 1.0), "fonster")
    cyl(0.05, 3.2, (0.6, 0, 1.75), "vit", verts=6)
    for x in (1.6, -2.0):
        tube((x, 1.0, 0.14), (x, 1.12, -0.12), 0.012, "vit", verts=3)
        blob(0.16, (x, 1.14, -0.3), "bat_rod", scale=(1.0, 1.0, 1.4), jitter=0.0)
    export("fiskebat", bevel=0.015)


def fyr():
    cyl(1.9, 1.0, (0, 0, 0.5), "grund", verts=8)
    bands = ["fyr_vit", "fyr_rod", "fyr_vit", "fyr_rod"]
    z, r = 1.0, 1.45
    for i, band in enumerate(bands):
        h = 1.9
        cyl(r, h, (0, 0, z + h / 2), band, verts=8, radius_top=r - 0.12)
        z += h
        r -= 0.12
    cyl(r + 0.55, 0.15, (0, 0, z + 0.07), "svart", verts=8)
    for i in range(16):
        a = i / 16 * math.tau
        cyl(0.03, 0.65, ((r + 0.5) * math.cos(a), (r + 0.5) * math.sin(a), z + 0.42), "svart", verts=4)
    ring((0, 0, z + 0.74), r + 0.5, 0.03, "svart", axis="z", segments=16)
    cyl(r - 0.1, 1.3, (0, 0, z + 0.8), "fyr_ljus", verts=8)
    cyl(r + 0.05, 0.12, (0, 0, z + 1.5), "fyr_rod", verts=8)
    cone(r + 0.15, 0.9, (0, 0, z + 2.0), "fyr_rod", verts=8)
    cyl(0.12, 0.4, (0, 0, z + 2.6), "svart", verts=6)
    box((0.9, 0.2, 1.7), (0, -1.42, 1.85), "tra_mork", rot=(math.radians(-4), 0, 0))
    export("fyr", bevel=0.03)


# --- Nature ---------------------------------------------------------------------------------------

def tall(seed, height):
    """Scots pine (tall) like the concept art: a tall, slightly curved trunk, grey-brown at the
    foot and orange higher up, and an irregular layered crown of many small needle clumps."""
    rnd = random.Random(seed)
    lean = Vector((rnd.uniform(-0.7, 0.7), rnd.uniform(-0.7, 0.7), 0))
    pts = [Vector((0, 0, -0.3)), Vector((0, 0, height * 0.35)) + lean * 0.2,
           Vector((0, 0, height * 0.7)) + lean * 0.65, Vector((0, 0, height)) + lean]
    taper(pts[0], pts[1], 0.42, 0.31, "stam_lag", verts=7)
    taper(pts[1], pts[2], 0.31, 0.22, "stam_hog", verts=7)
    taper(pts[2], pts[3], 0.22, 0.12, "stam_hog", verts=6)
    needles = ("barr", "barr_ljus", "barr_mork", "barr")
    n_branch = 9
    for i in range(n_branch):
        t = rnd.uniform(0.45, 0.96)
        seg = min(int(t * 3), 2)
        start = pts[seg].lerp(pts[seg + 1], t * 3 - seg)
        a = i / n_branch * math.tau + rnd.uniform(-0.5, 0.5)
        reach = rnd.uniform(1.4, 2.8) * (1.2 - t * 0.5)
        end = start + Vector((math.cos(a) * reach, math.sin(a) * reach, rnd.uniform(0.2, 0.9)))
        tube(start, end, 0.1, "stam_hog", verts=4)
        for k in range(3):
            c = end + Vector((rnd.uniform(-0.7, 0.7), rnd.uniform(-0.7, 0.7), rnd.uniform(-0.1, 0.4)))
            blob(rnd.uniform(0.75, 1.05), c, needles[(i + k) % 4], scale=(1.55, 1.55, 0.55), seed=seed * 101 + i * 7 + k)
    for k in range(3):
        c = pts[3] + Vector((rnd.uniform(-0.7, 0.7), rnd.uniform(-0.7, 0.7), rnd.uniform(0.0, 0.6)))
        blob(rnd.uniform(0.85, 1.15), c, needles[k], scale=(1.45, 1.45, 0.6), seed=seed * 131 + k)
    roots(rnd, 0.42)
    export("tall_%d" % seed, bevel=0.0)


def roots(rnd, r0):
    """Pine roots snaking over the rock from the foot of the trunk (trees are sunk 0.3 m in Godot)."""
    for i in range(5):
        a = i / 5 * math.tau + rnd.uniform(-0.4, 0.4)
        reach = rnd.uniform(1.2, 2.1)
        mid = Vector((math.cos(a) * reach * 0.45, math.sin(a) * reach * 0.45, 0.42))
        end = Vector((math.cos(a + 0.25) * reach, math.sin(a + 0.25) * reach, 0.22))
        tube((0, 0, 0.62), mid, r0 * 0.38, "stam_lag", verts=5)
        tube(mid, end, r0 * 0.22, "stam_lag", verts=4)


def gran(seed, height):
    rnd = random.Random(seed)
    cyl(0.18, height * 0.3, (0, 0, height * 0.12), "stam_lag", verts=6)
    levels = 4
    for i in range(levels):
        f = i / levels
        r = (1.0 - f * 0.75) * height * 0.28
        z = height * (0.18 + f * 0.62)
        bpy.ops.mesh.primitive_cone_add(vertices=7, radius1=r, radius2=0, depth=height * 0.38, location=(0, 0, z + height * 0.15))
        o = bpy.context.object
        o.rotation_euler = (0, 0, rnd.uniform(0, math.tau))
        _finish(o, "gran")
    export("gran_%d" % seed, bevel=0.0)


def sten(seed, size):
    blob(size, (0, 0, size * 0.25), "granit", scale=(1.4, 1.1, 0.7), jitter=0.22, subdiv=2, seed=seed)
    export("sten_%d" % seed, bevel=0.0)


def ljung(seed):
    """A tussock of heather: a low mound of dark twiggy green, crowded with thin upright purple
    flower spikes (it was a few purple lumps)."""
    rnd = random.Random(seed)
    mounds = []
    for i in range(3):
        p = (rnd.uniform(-0.35, 0.35), rnd.uniform(-0.35, 0.35), 0.06)
        r = rnd.uniform(0.3, 0.42)
        mounds.append((p, r))
        blob(r, p, "ljung_ris" if i % 2 else "gras", scale=(1, 1, 0.45), jitter=0.25, seed=seed * 11 + i)
    for i in range(40):                                       # many short, thin flower spikes
        (mx, my, _), r = mounds[i % 3]
        a, d = rnd.uniform(0, math.tau), rnd.uniform(0.0, 0.85) * r               # over its mound
        x, y = mx + math.cos(a) * d, my + math.sin(a) * d
        h = rnd.uniform(0.07, 0.15) * (1.0 - d / r * 0.4)
        z0 = 0.06 + 0.45 * r * math.sqrt(max(0.0, 1.0 - (d / r) ** 2)) - 0.05    # just under the mound's top
        bpy.ops.mesh.primitive_cone_add(vertices=3, radius1=0.024, radius2=0.0, depth=h,
                                        location=(x, y, z0 + h / 2))
        o = bpy.context.object
        o.rotation_euler = (rnd.uniform(-0.3, 0.3), rnd.uniform(-0.3, 0.3), rnd.uniform(0, math.tau))
        _finish(o, "ljung_ljus" if i % 4 == 0 else "ljung")
    export("ljung_%d" % seed, bevel=0.0)


def hall(seed):
    """A rounded granite slab with big facets, the backbone of the archipelago look."""
    rnd = random.Random(seed)
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=3, radius=1.0, location=(0, 0, 0))
    o = bpy.context.object
    off = Vector((rnd.uniform(0, 99), rnd.uniform(0, 99), rnd.uniform(0, 99)))
    for v in o.data.vertices:
        n = mathutils.noise.fractal(v.co * 1.2 + off, 0.7, 2.0, 3)
        v.co *= 1.0 + n * 0.25
        v.co.z = max(v.co.z, -0.2)
    o.scale = (rnd.uniform(1.3, 1.9), rnd.uniform(1.0, 1.4), rnd.uniform(0.5, 0.8))
    _finish(o, "granit")
    o.select_set(True)
    dec = o.modifiers.new("Dec", "DECIMATE")
    dec.ratio = 0.16
    bpy.ops.object.modifier_apply(modifier="Dec")
    o.data.materials.append(mat("granit_mork"))
    o.data.materials.append(mat("ris"))
    for poly in o.data.polygons:
        r = rnd.random()
        if poly.normal.z > 0.85 and r < 0.05:
            poly.material_index = 2          # a tuft of moss on top
        elif r < 0.22:
            poly.material_index = 1
    o.select_set(False)
    export("hall_%d" % seed, bevel=0.0)


def ljungtuva(seed):
    """Heather (ljung) in late summer: a low dark mound, and thin stems that carry a slim spike of
    tiny flowers on their upper half, deep purple to pale lilac, leaning a little this way and that.
    About as many triangles as before: it covers the heaths in thousands."""
    rnd = random.Random(seed)
    for i in range(3):
        a = rnd.uniform(0, math.tau)
        r = rnd.uniform(0.0, 0.3)
        blob(rnd.uniform(0.34, 0.44), (math.cos(a) * r, math.sin(a) * r, 0.1), "ljung_bas", scale=(1.5, 1.5, 0.55),
             jitter=0.22, seed=seed * 7 + i)
    for i in range(30):
        a = rnd.uniform(0, math.tau)
        r = math.sqrt(rnd.random()) * 0.6
        # From as deep as the mound goes (it sits sunk in the ground), so no stem stands loose on a slope.
        base = Vector((math.cos(a) * r, math.sin(a) * r, -0.15))
        h = rnd.uniform(0.5, 0.72) * (1.0 - r * 0.3)
        lean = Vector((rnd.uniform(-0.08, 0.08), rnd.uniform(-0.08, 0.08), 0)) + base.normalized() * 0.07 * r
        top = base + Vector((0, 0, h)) + lean
        bloom = base.lerp(top, 0.55)
        tube(base, bloom, 0.012, "ljung_ris", verts=3)
        # The flower spike: a slim spindle over the stem's upper half (as heather flowers sit).
        waist = bloom.lerp(top, 0.4)
        colour = ("ljung", "ljung_rosa", "ljung_ljus")[i % 3]
        taper(bloom, waist, 0.012, 0.038, colour, verts=4)
        taper(waist, top, 0.038, 0.004, "ljung_ljus" if i % 3 else colour, verts=4)
    export("ljungtuva_%d" % seed, bevel=0.0)


def rallarros(seed):
    """Fireweed (rallarros), in bloom in August: tall stems with narrow leaves and a pink spike."""
    rnd = random.Random(seed)
    for i in range(6):
        x, y = rnd.uniform(-0.35, 0.35), rnd.uniform(-0.35, 0.35)
        h = rnd.uniform(0.9, 1.45)
        lean = Vector((rnd.uniform(-0.08, 0.08), rnd.uniform(-0.08, 0.08), 0))
        foot = Vector((x, y, -0.05))
        neck = foot + Vector((0, 0, h * 0.6)) + lean * 0.6
        tube(foot, neck, 0.018, "rallarros_blad", verts=3)
        for k in range(3):
            p = foot.lerp(neck, 0.3 + k * 0.25)
            a = rnd.uniform(0, math.tau)
            tube(p, p + Vector((math.cos(a) * 0.2, math.sin(a) * 0.2, 0.12)), 0.022, "rallarros_blad", verts=3)
        for k in range(4):
            z = neck + lean * (k * 0.1) + Vector((0, 0, h * 0.1 * k))
            bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=0.065 * (1.0 - k * 0.18), radius2=0.0, depth=0.16,
                                            location=z + Vector((0, 0, 0.06)))
            _finish(bpy.context.object, "rallarros" if k % 2 == 0 else "rallarros2")
    export("rallarros_%d" % seed, bevel=0.0)


def grastuva(seed):
    """A tuft of dry late-summer grass: thin golden blades leaning outwards, a few still green."""
    rnd = random.Random(seed)
    for i in range(16):
        a = rnd.uniform(0, math.tau)
        r = rnd.uniform(0.0, 0.18)
        h = rnd.uniform(0.35, 0.8)
        foot = Vector((math.cos(a) * r, math.sin(a) * r, -0.02))
        tip = foot + Vector((math.cos(a) * h * 0.35, math.sin(a) * h * 0.35, h))
        bpy.ops.mesh.primitive_cone_add(vertices=3, radius1=0.035, radius2=0.0, depth=(tip - foot).length,
                                        location=(foot + tip) / 2)
        o = bpy.context.object
        o.rotation_mode = "QUATERNION"
        o.rotation_quaternion = Vector((0, 0, 1)).rotation_difference((tip - foot).normalized())
        _finish(o, ("gras_guld", "gras_torr", "gras_guld", "gras_gron")[i % 4])
    export("grastuva_%d" % seed, bevel=0.0)


def buske(seed):
    rnd = random.Random(seed)
    blob(0.6, (0, 0, 0.45), "barr_ljus", scale=(1.3, 1.3, 0.9), seed=seed)
    blob(0.45, (0.4, 0.2, 0.35), "gras_gron", scale=(1.2, 1.2, 0.8), seed=seed + 5)
    if seed % 2:
        for i in range(10):
            a = rnd.uniform(0, math.tau)
            blob(0.07, (math.cos(a) * 0.7, math.sin(a) * 0.65, rnd.uniform(0.4, 0.95)), "blomma", jitter=0.0)
    export("buske_%d" % seed, bevel=0.0)


def moln(seed):
    """A faceted cloud: a few flattened lumps in a row."""
    rnd = random.Random(seed)
    for i in range(rnd.randint(5, 7)):
        blob(rnd.uniform(0.7, 1.3), (i * 0.9 - 2.5, rnd.uniform(-0.4, 0.4), rnd.uniform(0, 0.5)), "moln",
             scale=(1.5, 1.0, 0.65), jitter=0.12, seed=seed * 13 + i)
    export("moln_%d" % seed, bevel=0.0)


def bjork(seed, height):
    """Birch: slender white trunk with black marks and a light, airy canopy."""
    rnd = random.Random(seed)
    lean = Vector((rnd.uniform(-0.4, 0.4), rnd.uniform(-0.4, 0.4), 0))
    top = Vector((0, 0, height)) + lean
    tube((0, 0, -0.2), top, 0.16, "bjork_stam", verts=6)
    for k in range(5):
        z = rnd.uniform(0.6, height * 0.7)
        p = Vector((0, 0, z)) + lean * (z / height)
        box((0.36, 0.36, 0.08), p, "svart", rot=(0, 0, rnd.uniform(0, math.tau)))
    for i in range(6):
        a = rnd.uniform(0, math.tau)
        r = rnd.uniform(0.5, 1.4)
        c = top + Vector((math.cos(a) * r, math.sin(a) * r, rnd.uniform(-1.8, 0.6)))
        blob(rnd.uniform(0.8, 1.2), c, "bjork_lov" if i % 2 else "bjork_lov2", scale=(1.0, 1.0, 1.2), seed=seed * 9 + i)
    export("bjork_%d" % seed, bevel=0.0)


def en(seed):
    """Juniper: an irregular dark blue-green bush, typical on the granite."""
    rnd = random.Random(seed)
    h = rnd.uniform(0.9, 1.6)
    for i in range(5):
        z = h * (0.25 + i * 0.16)
        blob(rnd.uniform(0.45, 0.65) * (1.0 - i * 0.14), (rnd.uniform(-0.3, 0.3), rnd.uniform(-0.3, 0.3), z),
             "en" if i % 2 else "barr_ljus", scale=(1.2, 1.2, 1.0), jitter=0.2, seed=seed * 7 + i)
    export("en_%d" % seed, bevel=0.0)


def vindtall(seed):
    """Wind-bent pine of the outer skerries: low, leaning hard, canopy swept to one side."""
    rnd = random.Random(seed)
    a = Vector((0, 0, -0.2))
    b = Vector((1.2, 0, 2.0))
    c = Vector((3.0, 0.3, 3.0))
    tube(a, b, 0.32, "stam_lag", verts=7)
    tube(b, c, 0.22, "stam_hog", verts=7)
    for i in range(4):
        p = c + Vector((rnd.uniform(-0.8, 1.6), rnd.uniform(-1.0, 1.0), rnd.uniform(-0.3, 0.4)))
        blob(1.1, p, "barr" if i % 2 else "barr_ljus", scale=(1.9, 1.3, 0.45), seed=seed * 5 + i)
    roots(rnd, 0.32)
    export("vindtall_%d" % seed, bevel=0.0)


def vass(seed):
    rnd = random.Random(seed)
    for i in range(26):
        x, y = rnd.uniform(-0.9, 0.9), rnd.uniform(-0.9, 0.9)
        h = rnd.uniform(1.3, 2.4)
        bpy.ops.mesh.primitive_cone_add(vertices=3, radius1=0.04, radius2=0.0, depth=h, location=(x, y, h / 2 - 0.3))
        o = bpy.context.object
        o.rotation_euler = (rnd.uniform(-0.18, 0.18), rnd.uniform(-0.18, 0.18), rnd.uniform(0, math.tau))
        _finish(o, "vass" if i % 3 else "vass_gron")
    export("vass_%d" % seed, bevel=0.0)


def nackrosor(seed):
    rnd = random.Random(seed)
    for i in range(9):
        p = (rnd.uniform(-1.6, 1.6), rnd.uniform(-1.6, 1.6), 0.03)
        cyl(rnd.uniform(0.25, 0.4), 0.02, p, "nackros", verts=8)
        if i % 3 == 0:
            blob(0.09, (p[0], p[1], 0.08), "blomma", jitter=0.0)
    export("nackrosor_%d" % seed, bevel=0.0)


def segelbat(name="segelbat", hull_mat="bat_vit", sail=True):
    hull(7.0, 2.4, 0.9, hull_mat, stripe="bat_bla" if hull_mat == "bat_vit" else "vit")
    box((5.6, 2.0, 0.06), (-0.3, 0, 0.15), "tra")
    box((1.6, 1.4, 0.5), (-0.5, 0, 0.4), "bat_vit")
    cyl(0.07, 9.5, (0.6, 0, 4.9), "metall", verts=6)
    tube((0.6, 0, 1.0), (-2.6, 0, 1.0), 0.06, "metall", verts=5)
    if sail:
        slab_y([(0.55, 1.1), (0.55, 9.0), (-2.5, 1.1)], 0.03, "segel")
    else:
        taper((0.5, 0, 1.15), (-2.5, 0, 1.15), 0.14, 0.09, "bat_bla", verts=6)        # furled sail under its cover
        tube((0.6, 0, 9.3), (3.4, 0, 0.3), 0.012, "metall", verts=3)                   # forestay
    export(name, bevel=0.01)


def kummel():
    """Whitewashed stone cairn, an old sea mark on the outer rocks."""
    rnd = random.Random(4)
    z, prev = 0.35, None
    for i in range(5):
        r = 1.3 - i * 0.24
        if prev is not None:
            z += 0.55 * (prev + r) * 0.75                                                         # overlap a little
        blob(r, (0, 0, z), "kummel", scale=(1.0, 1.0, 0.55), jitter=0.12, seed=40 + i)
        prev = r
    export("kummel", bevel=0.0)


def prick(color):
    cyl(0.22, 2.6, (0, 0, 0.9), color, verts=6)
    cone(0.24, 0.5, (0, 0, 2.45), color, verts=6) if color == "prick_gron" else cyl(0.26, 0.3, (0, 0, 2.3), color, verts=6)
    export("prick_" + ("rod" if color == "prick_rod" else "gron"), bevel=0.0)


def vedtrave():
    rnd = random.Random(7)
    for row in range(4):
        for k in range(9 - row):
            x = (k - (8 - row) / 2) * 0.24
            z = 0.12 + row * 0.21
            cyl(0.11, 1.1, (x, 0, z), "ved", verts=6, rot=(math.pi / 2, 0, 0))
            cyl(0.1, 0.02, (x, 0.56, z), "ved_ande", verts=6, rot=(math.pi / 2, 0, 0))
    export("vedtrave", bevel=0.0)


def gardsgard():
    """One 3 m bay of a Swedish roundpole fence: pole pairs and leaning rails."""
    for x in (-1.5, -0.75, 0.0, 0.75, 1.5):
        for y in (-0.075, 0.075):
            cyl(0.04, 1.4, (x, y, 0.65), "stang", verts=5)
        for z in (0.55, 1.05):                                                                  # willow ties
            box((0.06, 0.24, 0.05), (x, 0, z), "tra_mork")
    for k in range(6):
        x = -1.25 + k * 0.5
        tube((x - 0.45, 0, 0.15), (x + 0.45, 0, 1.1), 0.035, "stang", verts=5)
    export("gardsgard", bevel=0.0)


def brevlada():
    cyl(0.05, 1.1, (0, 0, 0.55), "tra_mork", verts=5)
    box((0.42, 0.26, 0.3), (0, 0, 1.2), "brevlada")
    box((0.44, 0.28, 0.05), (0, 0, 1.37), "fyr_rod")
    export("brevlada", bevel=0.01)


def uthus():
    box((2.6, 2.2, 0.2), (0, 0, 0.05), "grund")
    gable_house(2.4, 2.0, 2.0, 0.9, "falu", "takgra")
    box((0.7, 0.08, 1.5), (0.2, -1.03, 0.85), "tra_mork")
    export("uthus", bevel=0.02)


def stuga_variant(name, wall, roof):
    box((6.4, 4.4, 0.45), (0, 0, 0.12), "grund")
    gable_house(6.0, 4.0, 2.7, 1.9, wall, roof)
    for x in (-1.7, 1.7):
        window(x, -2.0, 1.55, -1)
        window(x, 2.0, 1.55, 1)
    window(-3.0, 0, 1.6, -2, w=0.7)
    window(3.0, 0, 1.6, 2, w=0.7)
    window(3.0, 0, 3.4, 2, w=0.5, h=0.6)
    box((0.95, 0.1, 1.9), (0.2, -2.04, 1.25), "dorr")
    box((1.25, 0.08, 2.15), (0.2, -2.01, 1.3), "vit")
    farstukvist(0.2, roof)
    box((0.5, 0.5, 1.4), (-1.6, 0.6, 4.3), "tegel_mork")
    box((0.62, 0.62, 0.12), (-1.6, 0.6, 5.0), "grund")
    export(name, bevel=0.025)


def blastuga():
    """A pale grey-blue cottage, a little smaller, with a sheet roof and a glazed veranda on the
    +X gable."""
    box((5.6, 4.4, 0.4), (0, 0, 0.1), "grund")
    gable_house(5.2, 4.0, 2.6, 1.8, "bla_gra", "takgra")
    for x in (-1.4, 1.4):
        window(x, 2.0, 1.5, 1)
    window(-1.4, -2.0, 1.5, -1)
    window(-2.6, 0, 1.5, -2, w=0.7)
    window(-2.6, 0, 3.25, -2, w=0.5, h=0.6)
    box((0.95, 0.1, 1.9), (0.9, -2.04, 1.25), "dorr")
    box((1.25, 0.08, 2.15), (0.9, -2.01, 1.3), "vit")
    farstukvist(0.9, "takgra")
    # Glazed veranda: wooden floor, white posts and panels, panes of glass, a low lean-to roof.
    box((2.3, 3.3, 0.36), (3.75, 0, 0.18), "tra_gra")
    for x, y in ((4.8, -1.55), (4.8, 1.55), (2.7, -1.55), (2.7, 1.55)):
        box((0.12, 0.12, 2.3), (x, y, 1.45), "vit")
    box((0.06, 3.0, 1.35), (4.8, 0, 1.4), "glas")
    box((0.1, 3.1, 0.55), (4.82, 0, 0.62), "vit")
    for y in (-1.55, 1.55):
        box((2.0, 0.06, 1.35), (3.75, y, 1.4), "glas")
        box((2.1, 0.1, 0.55), (3.75, y * 1.01, 0.62), "vit")
    box((0.1, 3.2, 0.12), (4.82, 0, 2.6), "vit")
    box((2.5, 3.6, 0.1), (3.8, 0, 2.72), "takgra", rot=(0, math.radians(10), 0))
    box((0.5, 0.5, 1.2), (-1.3, 0.6, 3.75), "tegel_mork")
    box((0.62, 0.62, 0.12), (-1.3, 0.6, 4.35), "grund")
    export("blastuga", bevel=0.025)


def storgard():
    """A two-storey pale yellow farmhouse (mangårdsbyggnad): two rows of windows, a tiled roof with
    two chimneys and a porch at the front door."""
    box((9.4, 6.0, 0.5), (0, 0, 0.12), "grund")
    gable_house(9.0, 5.6, 5.2, 2.4, "ljusgul", "tegel")
    for x in (-3.3, -1.5, 1.5, 3.3):
        for z in (1.6, 4.0):
            window(x, -2.8, z, -1)
            window(x, 2.8, z, 1)
    window(0.0, -2.8, 4.0, -1)
    for z in (1.6, 4.0):
        window(-4.5, 0, z, -2, w=0.7)
        window(4.5, 0, z, 2, w=0.7)
    window(-4.5, 0, 6.0, -2, w=0.5, h=0.6)
    window(4.5, 0, 6.0, 2, w=0.5, h=0.6)
    box((0.95, 0.1, 1.9), (0.0, -2.84, 1.25), "dorr")
    box((1.25, 0.08, 2.15), (0.0, -2.81, 1.3), "vit")
    farstukvist(0.0, "tegel", yw=-2.8)
    for x in (-2.4, 2.4):
        box((0.5, 0.5, 1.4), (x, 0.5, 7.3), "tegel_mork")
        box((0.62, 0.62, 0.12), (x, 0.5, 8.0), "grund")
    export("storgard", bevel=0.025)


def gronstuga():
    """A small pale green summer cottage with a tiled roof, white corners, a canopy over the door
    and wooden steps."""
    box((4.9, 3.9, 0.4), (0, 0, 0.1), "grund")
    gable_house(4.6, 3.6, 2.4, 1.6, "ljusgron", "tegel")
    window(-1.1, -1.8, 1.4, -1)
    for x in (-1.1, 1.1):
        window(x, 1.8, 1.4, 1)
    window(2.3, 0, 1.4, 2, w=0.7)
    window(-2.3, 0, 1.4, -2, w=0.7)
    window(-2.3, 0, 2.95, -2, w=0.45, h=0.5)
    box((0.9, 0.1, 1.85), (0.9, -1.84, 1.2), "dorr")
    box((1.2, 0.08, 2.1), (0.9, -1.81, 1.25), "vit")
    box((1.4, 0.9, 0.36), (0.9, -2.3, 0.18), "tra_gra")
    box((1.5, 1.0, 0.08), (0.9, -2.25, 2.4), "tegel", rot=(math.radians(-14), 0, 0))
    for dx in (-0.6, 0.6):
        box((0.05, 0.5, 0.05), (0.9 + dx, -2.05, 2.25), "vit", rot=(math.radians(35), 0, 0))
    box((0.42, 0.42, 1.0), (-1.0, 0.5, 3.65), "tegel_mork")
    box((0.54, 0.54, 0.1), (-1.0, 0.5, 4.15), "grund")
    export("gronstuga", bevel=0.02)


def vaderkvarn():
    """A post windmill (stubbkvarn) on its stone base: a red timber body with a pitched roof and a
    small door up a ladder, four lattice sails facing +X and the tail pole down to the ground."""
    box((2.4, 2.4, 0.8), (0, 0, 0.4), "grund")
    cyl(0.35, 2.6, (0, 0, 2.1), "tra_mork", verts=8)
    box((3.4, 3.0, 3.6), (0, 0, 5.0), "falu")
    prism([(-1.7, 6.75), (1.7, 6.75), (0, 8.2)], 3.8, "takgra", x0=0.0)
    box((0.1, 1.0, 1.8), (-1.72, 0, 4.4), "tra_mork")
    for y in (-0.47, 0.47):
        tube((-2.05, y, 3.95), (-4.15, y, -0.05), 0.05, "tra_mork", verts=4)
    for k in range(8):
        box((0.3, 0.9, 0.06), (-2.3 - k * 0.25, 0, 3.6 - k * 0.5), "tra_mork")                   # ladder
    tube((-1.7, 0, 3.4), (-4.6, 0, 0.3), 0.08, "tra_mork", verts=5)                             # tail pole
    cyl(0.22, 0.6, (1.95, 0, 6.0), "tra_mork", verts=8, rot=(0, math.pi / 2, 0))                # axle
    for k in range(4):
        a = k * math.pi / 2 + math.pi / 4
        d = Vector((0, math.cos(a), math.sin(a)))
        c = Vector((2.3, 0, 6.0))
        tube(c, c + d * 6.2, 0.07, "tra_mork", verts=4)
        side = Vector((0, -math.sin(a), math.cos(a)))
        for j in range(5):
            t = 1.4 + j * 1.15
            box((0.04, 1.0, 0.04), c + d * t + side * 0.5, "vit", rot=(a, 0, 0))
        box((0.03, 0.9, 4.6), c + d * 3.9 + side * 0.5, "segel", rot=(a - math.pi / 2, 0, 0))
    export("vaderkvarn", bevel=0.02)


def utkikstorn():
    """A wooden lookout tower 9 m high: four splayed legs with cross bracing, a stair up the side,
    a railed platform with a little pyramid roof."""
    for sx in (-1, 1):
        for sy in (-1, 1):
            tube((sx * 1.6, sy * 1.6, 0.0), (sx * 0.9, sy * 0.9, 8.0), 0.1, "tra_mork", verts=5)
    for z in (2.5, 5.0):
        k = 1.6 - (z / 8.0) * 0.7
        for (a, b) in (((-k, -k), (k, k)), ((k, -k), (-k, k))):
            tube((a[0], a[1], z - 1.2), (b[0], b[1], z + 1.2), 0.05, "tra", verts=4)
    box((2.6, 2.6, 0.15), (0, 0, 8.0), "tra")
    for sx in (-1, 1):
        box((0.08, 2.6, 0.9), (sx * 1.26, 0, 8.5), "tra")
        box((2.6, 0.08, 0.9), (0, sx * 1.26, 8.5), "tra")
    for sx in (-1, 1):
        for sy in (-1, 1):
            box((0.1, 0.1, 1.8), (sx * 1.2, sy * 1.2, 8.9), "tra_mork")
    cyl(2.0, 1.2, (0, 0, 10.4), "takgra", verts=4, radius_top=0.0, rot=(0, 0, math.pi / 4))
    for y in (-0.33, -0.87):                                                                   # stair
        tube((2.35, y, 0.0), (1.35, y, 8.0), 0.05, "tra_mork", verts=4)
    for k in range(14):
        z = 0.3 + k * 0.55
        box((0.28, 0.58, 0.05), (2.35 - z / 8.0, -0.6, z), "tra")
    tube((2.35, -0.9, 0.9), (1.35, -0.9, 8.9), 0.025, "tra_mork", verts=4)                     # handrail
    for k in range(4):
        z = 1.0 + k * 2.4
        tube((2.35 - (z - 0.9) / 8.0, -0.9, z - 0.9), (2.35 - (z - 0.9) / 8.0, -0.9, z), 0.025, "tra_mork", verts=3)
    export("utkikstorn", bevel=0.01)


def bastu():
    """A small lakeside sauna of grey timber with a sheet roof, a chimney puffing from the stove,
    a tiny window and a bench on the porch."""
    box((3.4, 2.8, 0.3), (0, 0, 0.15), "grund")
    gable_house(3.0, 2.4, 2.1, 0.9, "tra_gra", "takgra", trim=False)
    box((0.8, 0.08, 1.7), (0.6, -1.23, 1.15), "tra_mork")
    window(-0.8, -1.2, 1.5, -1, w=0.4, h=0.35)
    cyl(0.14, 1.4, (-0.9, 0.5, 3.4), "metall", verts=8)
    box((2.4, 1.0, 0.12), (0.2, -1.9, 0.45), "tra_gra")
    for x in (-0.9, 1.3):
        for y in (-1.5, -2.3):
            box((0.1, 0.1, 0.45), (x, y, 0.22), "tra_mork")
    box((1.8, 0.35, 0.08), (0.2, -2.1, 0.75), "tra")
    for x in (-0.6, 1.0):
        box((0.08, 0.3, 0.26), (x, -2.1, 0.6), "tra_mork")
    export("bastu", bevel=0.02)


def flyttblock(seed):
    blob(1.0, (0, 0, 0.45), "flyttblock", scale=(1.3, 1.1, 0.95), jitter=0.2, subdiv=2, seed=seed)
    export("flyttblock_%d" % seed, bevel=0.0)


def mas():
    """A gull for the sky: body and two wings (Godot flaps them)."""
    blob(0.18, (0, 0, 0), "mas_vit", scale=(2.0, 0.8, 0.8), jitter=0.0)
    for side in (-1, 1):
        bm = bmesh.new()
        v = [bm.verts.new(c) for c in ((0.15, 0, 0), (-0.2, 0, 0), (0.0, side * 0.9, 0.12))]
        bm.faces.new(v if side > 0 else list(reversed(v)))
        me = bpy.data.meshes.new("vinge")
        bm.to_mesh(me)
        bm.free()
        o = bpy.data.objects.new("vinge", me)
        bpy.context.collection.objects.link(o)
        o.data.materials.append(mat("mas_gra"))
    export("mas", bevel=0.0)


def flaggstang():
    cyl(0.07, 8.0, (0, 0, 4.0), "vit", verts=6)
    blob(0.12, (0, 0, 8.08), "flagga_gul", seed=1, jitter=0.0)
    fx, fz, fw, fh = 0.85, 7.4, 1.6, 1.0
    box((fw, 0.03, fh), (fx, 0, fz), "flagga_bla")
    box((0.2, 0.05, fh), (fx - 0.2, 0, fz), "flagga_gul")
    box((fw, 0.05, 0.2), (fx, 0, fz), "flagga_gul")
    export("flaggstang", bevel=0.0)


def hamnprylar():
    # Lobster pots, barrels and a bench as one cluster for the harbour.
    for i, (x, y) in enumerate(((0, 0), (0.7, 0.1), (0.35, 0.05))):
        z = 0.225 if i < 2 else 0.675
        box((0.65, 0.45, 0.45), (x, y, z), "tra")
        box((0.6, 0.4, 0.4), (x, y, z), "bat_bla")
    for x, y in ((-1.2, 0.2), (-1.7, -0.2)):
        cyl(0.28, 0.85, (x, y, 0.42), "tra_mork", verts=8)
        cyl(0.3, 0.06, (x, y, 0.62), "metall", verts=8)
    box((1.5, 0.4, 0.08), (2.2, 0, 0.45), "tra")
    for x in (1.6, 2.8):
        box((0.08, 0.35, 0.45), (x, 0, 0.22), "tra_mork")
    export("hamnprylar", bevel=0.01)


def boj():
    blob(0.35, (0, 0, 0.2), "bat_rod", scale=(1, 1, 0.9), jitter=0.0, subdiv=1)
    cyl(0.05, 0.6, (0, 0, 0.7), "fyr_vit", verts=5)
    export("boj", bevel=0.0)


# --- Round 4: harbour --------------------------------------------------------------------------

def eka(name, outer):
    """Wooden rowing boat (eka) with thwarts and a pair of oars resting inside."""
    hull(3.8, 1.4, 0.5, outer, stripe="tra_mork")
    box((3.0, 1.1, 0.04), (-0.1, 0, 0.0), "tra")
    for x in (-1.1, -0.1, 0.8):
        box((0.24, 1.15, 0.06), (x, 0, 0.12), "tra")
    for y in (-0.25, 0.25):
        tube((-1.4, y, 0.16), (1.2, y * 1.6, 0.2), 0.03, "tra_mork", verts=4)
    export(name, bevel=0.01)


def snipa():
    """Double-ended open motorboat with a small windscreen, typical of the archipelago."""
    hull(5.6, 2.0, 0.75, "bat_vit", stripe="tra", double=True)
    box((4.4, 1.6, 0.05), (0, 0, 0.1), "tra")
    box((0.9, 0.75, 0.5), (-0.3, 0, 0.35), "tra")                   # engine box
    box((0.4, 1.5, 0.08), (-1.4, 0, 0.32), "tra")                   # aft seat
    box((0.36, 0.08, 0.2), (-1.4, 0, 0.2), "tra")
    box((0.08, 1.4, 0.45), (0.95, 0, 0.36), "glas", rot=(0, math.radians(-25), 0))
    box((0.1, 1.5, 0.06), (1.05, 0, 0.565), "tra_mork")
    box((0.3, 1.5, 0.12), (0.85, 0, 0.16), "tra")
    cyl(0.03, 1.0, (-2.3, 0, 0.6), "vit", verts=5)
    export("snipa", bevel=0.01)


def badbrygga():
    """Narrow bathing jetty with a steel ladder down into the water at the far end (+X)."""
    length, width = 8.0, 1.4
    x = -length / 2 + 0.1
    while x < length / 2:
        box((0.2, width, 0.07), (x, 0, 0), "tra_gra")
        x += 0.26
    for y in (-width / 2 + 0.1, width / 2 - 0.1):                                            # joists
        box((length, 0.12, 0.15), (0, y, -0.11), "tra_mork")
    for x in (-length / 2 + 0.3, 0.0, length / 2 - 0.3):
        for y in (-width / 2 + 0.1, width / 2 - 0.1):
            cyl(0.11, 3.0, (x, y, -1.45), "tra_mork", verts=6)
    for y in (-0.3, 0.3):
        tube((3.75, y, 0.0), (3.85, y, 0.85), 0.03, "metall", verts=5)
        tube((3.85, y, 0.85), (4.15, y, 0.85), 0.03, "metall", verts=5)
        tube((4.15, y, 0.85), (4.2, y, -1.4), 0.03, "metall", verts=5)
    for z in (-0.3, -0.7, -1.1):
        tube((4.19, -0.3, z), (4.19, 0.3, z), 0.025, "metall", verts=4)
    box((1.4, 0.4, 0.06), (-2.5, 0.45, 0.45), "tra")                   # bench
    for x in (-3.0, -2.0):
        box((0.07, 0.35, 0.42), (x, 0.45, 0.22), "tra_mork")
    export("badbrygga", bevel=0.01)


def natstallning():
    """Net rack on the shore: posts, a top pole and nets hung to dry, with cork floats."""
    rnd = random.Random(5)
    for x in (-2.0, 0.0, 2.0):
        cyl(0.06, 2.1, (x, 0, 1.0), "tra_mork", verts=5)
    box((4.5, 0.1, 0.1), (0, 0, 2.0), "tra_mork")
    box((1.8, 0.04, 1.35), (-1.0, 0, 1.28), "nat")
    box((1.7, 0.04, 1.1), (1.05, 0.03, 1.4), "nat_brun")
    for k in range(12):
        x = -1.85 + k * 0.33
        dot((x, 0.05, 1.9 - rnd.uniform(0.0, 0.05)), 0.06, "kork")
    box((0.7, 0.45, 0.3), (1.6, 0.6, 0.15), "tra")                     # fish crate
    box((0.66, 0.42, 0.05), (1.6, 0.6, 0.3), "nat")
    export("natstallning", bevel=0.0)


def livbojsstall():
    """Post with a life ring, at the start of the jetty."""
    box((0.1, 0.1, 1.6), (0, 0, 0.8), "vit")
    box((0.5, 0.12, 0.1), (0, 0, 1.55), "fyr_rod")
    livboj((0, -0.12, 1.1), "y", r=0.32)
    export("livbojsstall", bevel=0.0)


def vimpelstang():
    """White flagpole flying the long Swedish pennant (vimpel), blue over yellow."""
    cyl(0.07, 9.0, (0, 0, 4.5), "vit", verts=6)
    blob(0.13, (0, 0, 9.08), "flagga_gul", jitter=0.0)
    slab_y([(0.08, 8.85), (4.3, 8.32), (0.08, 8.62)], 0.03, "flagga_bla")
    slab_y([(0.08, 8.62), (3.9, 8.12), (0.08, 8.42)], 0.03, "flagga_gul")
    export("vimpelstang", bevel=0.0)


def bak():
    """Wooden beacon (båk) on an outer skerry: four legs, boarded white top and a red cap."""
    for sx in (-1, 1):
        for sy in (-1, 1):
            tube((sx * 1.6, sy * 1.6, -0.3), (sx * 0.45, sy * 0.45, 7.2), 0.12, "tra_mork", verts=5)
    cyl(1.25, 3.6, (0, 0, 5.2), "vit", verts=4, radius_top=0.55, rot=(0, 0, math.pi / 4))
    cyl(0.62, 0.9, (0, 0, 7.35), "fyr_rod", verts=4, radius_top=0.0, rot=(0, 0, math.pi / 4))
    box((3.7, 0.12, 0.12), (0, 0, 2.0), "tra_mork", rot=(0, 0, math.pi / 4))
    box((3.7, 0.12, 0.12), (0, 0, 2.0), "tra_mork", rot=(0, 0, -math.pi / 4))
    export("bak", bevel=0.0)


def skargardsbat():
    """A white archipelago passenger boat for the horizon: long hull, two decks, wheelhouse, funnel."""
    o = hull(26.0, 6.0, 3.0, "bat_vit")
    o.location.z = 1.9
    box((25.0, 6.1, 0.5), (-0.4, 0, 0.35), "farja_gron")               # boot topping at the waterline
    box((15.0, 4.8, 2.3), (-1.5, 0, 3.4), "bat_vit")
    box((14.6, 4.9, 0.8), (-1.5, 0, 3.6), "glas_mork")
    box((9.0, 4.4, 2.0), (-0.5, 0, 5.5), "bat_vit")
    box((8.6, 4.5, 0.7), (-0.5, 0, 5.7), "glas_mork")
    box((3.0, 4.2, 1.8), (4.8, 0, 7.4), "bat_vit")
    box((3.05, 4.25, 0.7), (4.8, 0, 7.7), "glas_mork")
    box((3.4, 4.6, 0.15), (4.8, 0, 8.35), "bat_vit")
    cyl(0.75, 2.6, (-2.8, 0, 7.7), "svart", verts=8)
    cyl(0.78, 0.7, (-2.8, 0, 6.8), "vit", verts=8)
    cyl(0.08, 4.0, (5.5, 0, 10.4), "vit", verts=5)
    for y in (-2.95, 2.95):
        box((24.0, 0.06, 0.7), (-0.5, y, 2.6), "vit")                 # railing
    export("skargardsbat", bevel=0.0)


def ejdrar():
    """A small raft of eiders on the water: drakes white and black, ducks brown."""
    rnd = random.Random(9)
    spots = [(0, 0), (1.3, 0.6), (-1.1, 0.9), (0.5, -1.2), (-1.6, -0.6), (2.2, -0.4)]
    for k, (x, y) in enumerate(spots):
        drake = k % 2 == 0
        a = rnd.uniform(0, math.tau)
        fwd = Vector((math.cos(a), math.sin(a), 0))
        body = Vector((x, y, 0.06))
        blob(0.2, body, "ejder_vit" if drake else "ejder_brun", scale=(1.7, 1.0, 0.7), jitter=0.0)
        if drake:
            blob(0.21, body + Vector((0, 0, -0.06)) - fwd * 0.08, "ejder_svart", scale=(1.6, 1.05, 0.6), jitter=0.0)
        head = body + fwd * 0.3 + Vector((0, 0, 0.2))
        blob(0.1, head, "ejder_vit" if drake else "ejder_brun", jitter=0.0)
        if drake:
            blob(0.07, head + Vector((0, 0, 0.05)), "ejder_svart", jitter=0.0)
        tube(head, head + fwd * 0.14 + Vector((0, 0, -0.03)), 0.03, "gras_gul", verts=4)
    export("ejdrar", bevel=0.0)


def kajak():
    """Yellow kayak with a paddler in a red jacket and orange life vest."""
    hull(4.6, 0.62, 0.32, "kajak", double=True)
    box((0.7, 0.42, 0.06), (0, 0, 0.06), "svart")                     # cockpit
    tube((0, 0, 0.05), (0.06, 0, 0.62), 0.16, "jacka", verts=6)
    box((0.3, 0.36, 0.3), (0.04, 0, 0.42), "livboj")
    tube((0.06, 0, 0.6), (0.07, 0, 0.74), 0.05, "hud", verts=6)
    blob(0.11, (0.07, 0, 0.78), "hud", jitter=0.0, subdiv=2)
    blob(0.12, (0.06, 0, 0.84), "bat_bla", scale=(1.1, 1.1, 0.6), jitter=0.0)
    a, b = Vector((0.36, -1.15, 0.45)), Vector((0.36, 1.15, 0.7))
    tube(a, b, 0.02, "svart", verts=4)
    for p in (a, b):
        box((0.22, 0.4, 0.03), p, "kajak", rot=(0.4, 0, 0))
    for y in (-0.17, 0.17):
        tube((0.06, y, 0.52), (0.36, y * 2.4, 0.5 + (0.12 if y > 0 else 0.0)), 0.04, "jacka", verts=5)
    export("kajak", bevel=0.0)


# --- Round 4: gardens -----------------------------------------------------------------------------

def staket():
    """One 3 m bay of white picket fence (spjälstaket)."""
    for x in (-1.5, 1.5):
        box((0.1, 0.1, 1.1), (x, 0, 0.5), "vit")
    for z in (0.3, 0.75):
        box((3.0, 0.05, 0.08), (0, 0.04, z), "vit")
    for k in range(13):
        x = -1.38 + k * 0.23
        slab_y([(x - 0.035, 0.05), (x + 0.035, 0.05), (x + 0.035, 0.86), (x, 0.96), (x - 0.035, 0.86)], 0.025,
               "vit", y=0.004)
    export("staket", bevel=0.0)


def syren():
    """Lilac (syren) bush by the house: tall, dense and multi-stemmed (past bloom in August)."""
    rnd = random.Random(21)
    for i in range(4):
        a = i / 4 * math.tau
        tube((0, 0, -0.1), (math.cos(a) * 0.6, math.sin(a) * 0.6, 1.4), 0.07, "stam_lag", verts=5)
    for i in range(9):
        a = rnd.uniform(0, math.tau)
        r = rnd.uniform(0.2, 1.1)
        blob(rnd.uniform(0.6, 0.85), (math.cos(a) * r, math.sin(a) * r, rnd.uniform(1.0, 2.5)),
             "syren" if i % 2 else "syren2", scale=(1.0, 1.0, 0.9), jitter=0.22, seed=210 + i)
    export("syren", bevel=0.0)


def appeltrad(seed):
    """Old apple tree: short crooked trunk, wide round crown with red apples (August)."""
    rnd = random.Random(seed)
    fork = Vector((rnd.uniform(-0.2, 0.2), rnd.uniform(-0.2, 0.2), 1.2))
    tube((0, 0, -0.2), fork, 0.17, "stam_lag", verts=6)
    tips = []
    for i in range(3):
        a = i / 3 * math.tau + rnd.uniform(-0.3, 0.3)
        tip = fork + Vector((math.cos(a) * 1.2, math.sin(a) * 1.2, 1.1))
        tube(fork, tip, 0.1, "stam_lag", verts=5)
        tips.append(tip)
    for i in range(7):
        c = tips[i % 3] + Vector((rnd.uniform(-0.8, 0.8), rnd.uniform(-0.8, 0.8), rnd.uniform(-0.2, 0.8)))
        blob(rnd.uniform(0.85, 1.1), c, "apple_lov" if i % 2 else "apple_lov2", scale=(1.15, 1.15, 0.85),
             seed=seed * 17 + i)
    for i in range(16):
        a = rnd.uniform(0, math.tau)
        c = fork + Vector((math.cos(a) * rnd.uniform(1.6, 2.1), math.sin(a) * rnd.uniform(1.6, 2.1), rnd.uniform(0.6, 1.9)))
        dot(c, 0.065, "apple")
    export("appeltrad_%d" % seed, bevel=0.0)


def tvattlina():
    """Washing line between two T-posts with sheets and towels."""
    for x in (-2.0, 2.0):
        box((0.08, 0.08, 1.9), (x, 0, 0.95), "tra_gra")
        box((0.06, 1.0, 0.07), (x, 0, 1.85), "tra_gra")
    for y in (-0.4, 0.0, 0.4):
        tube((-2.0, y, 1.83), (2.0, y, 1.83), 0.012, "vit", verts=3)
    laundry = [(-1.2, -0.4, 1.0, 0.8, "vit"), (0.1, -0.4, 0.5, 0.6, "tvatt_bla"), (0.9, -0.4, 0.45, 0.5, "tvatt_rod"),
               (-0.9, 0.4, 0.5, 0.55, "tvatt_gul"), (0.4, 0.4, 1.1, 0.75, "vit"), (1.5, 0.4, 0.4, 0.45, "tvatt_bla")]
    for x, y, w, h, m in laundry:
        box((w, 0.02, h), (x, y, 1.82 - h / 2), m)
    export("tvattlina", bevel=0.0)


def utemobler():
    """White garden table with two chairs."""
    box((1.2, 0.8, 0.05), (0, 0, 0.74), "vit")
    for sx in (-0.5, 0.5):
        for sy in (-0.32, 0.32):
            box((0.05, 0.05, 0.72), (sx, sy, 0.36), "vit")
    for x in (-0.95, 0.95):
        s = 1 if x > 0 else -1
        box((0.45, 0.45, 0.05), (x, 0, 0.45), "vit")
        box((0.05, 0.45, 0.5), (x + s * 0.22, 0, 0.7), "vit")
        for dx in (-0.2, 0.2):
            for dy in (-0.2, 0.2):
                box((0.04, 0.04, 0.45), (x + dx, dy, 0.22), "vit")
    export("utemobler", bevel=0.0)


# --- Round 4: trees, shrubs and ground cover ------------------------------------------------------

def al(seed, height):
    """Black alder (al): dark trunk, dense dark-green oval crown; grows by the water."""
    rnd = random.Random(seed)
    lean = Vector((rnd.uniform(-0.3, 0.3), rnd.uniform(-0.3, 0.3), 0))
    tube((0, 0, -0.2), Vector((0, 0, height * 0.8)) + lean * 0.8, 0.2, "al_stam", verts=6)
    for i in range(7):
        a = rnd.uniform(0, math.tau)
        r = rnd.uniform(0.2, 1.2)
        z = rnd.uniform(height * 0.42, height * 0.95)
        blob(rnd.uniform(1.0, 1.35), Vector((math.cos(a) * r, math.sin(a) * r, z)) + lean * (z / height),
             "al_lov" if i % 2 else "al_lov2", scale=(1.0, 1.0, 1.2), seed=seed * 23 + i)
    export("al_%d" % seed, bevel=0.0)


def ronn(seed, height):
    """Rowan (rönn): slim grey trunk, airy light crown and clusters of orange-red berries."""
    rnd = random.Random(seed)
    top = Vector((rnd.uniform(-0.4, 0.4), rnd.uniform(-0.4, 0.4), height))
    tube((0, 0, -0.2), top * 0.85, 0.13, "ronn_stam", verts=6)
    crown = []
    for i in range(7):
        a = rnd.uniform(0, math.tau)
        r = rnd.uniform(0.4, 1.4)
        c = top * 0.8 + Vector((math.cos(a) * r, math.sin(a) * r, rnd.uniform(-1.2, 0.8)))
        blob(rnd.uniform(0.65, 0.95), c, "ronn_lov" if i % 2 else "ronn_lov2", scale=(1.1, 1.1, 0.8), jitter=0.25,
             seed=seed * 29 + i)
        crown.append((c, a))
    for c, a in crown[:6]:
        p = c + Vector((math.cos(a) * 0.7, math.sin(a) * 0.7, -0.35))
        for k in range(3):
            dot(p + Vector((rnd.uniform(-0.12, 0.12), rnd.uniform(-0.12, 0.12), -k * 0.08)), 0.1, "ronnbar")
    export("ronn_%d" % seed, bevel=0.0)


def havtorn(seed):
    """Sea buckthorn (havtorn): silvery thorny shrub with orange berries along the shore."""
    rnd = random.Random(seed)
    for i in range(5):
        a = rnd.uniform(0, math.tau)
        tip = Vector((math.cos(a) * 0.6, math.sin(a) * 0.6, rnd.uniform(1.3, 2.0)))
        tube((0, 0, -0.1), tip, 0.05, "stam_lag", verts=4)
        blob(rnd.uniform(0.4, 0.55), tip * 0.8, "havtorn" if i % 2 else "havtorn2", scale=(0.9, 0.9, 1.5), jitter=0.3,
             seed=seed * 31 + i)
    for i in range(18):
        a = rnd.uniform(0, math.tau)
        r = rnd.uniform(0.35, 0.75)
        dot((math.cos(a) * r, math.sin(a) * r, rnd.uniform(0.5, 1.6)), 0.06, "havtorn_bar")
    export("havtorn_%d" % seed, bevel=0.0)


def salg(seed):
    """Goat willow (sälg): a few stems fanning out into a soft grey-green crown."""
    rnd = random.Random(seed)
    for i in range(4):
        a = i / 4 * math.tau + rnd.uniform(-0.3, 0.3)
        tip = Vector((math.cos(a) * 1.0, math.sin(a) * 1.0, rnd.uniform(2.6, 3.4)))
        tube((0, 0, -0.2), tip, 0.09, "ronn_stam", verts=5)
        blob(rnd.uniform(0.9, 1.15), tip + Vector((0, 0, 0.2)), "salg" if i % 2 else "salg2", scale=(1.15, 1.15, 0.9),
             seed=seed * 37 + i)
    blob(1.0, (0, 0, 3.4), "salg2", scale=(1.2, 1.2, 0.8), seed=seed * 41)
    export("salg_%d" % seed, bevel=0.0)


def ris(name, leaf, leaf2, berry, seed, height=0.28):
    """A low dwarf-shrub carpet (blueberry or lingonberry) with ripe berries on top."""
    rnd = random.Random(seed)
    for i in range(9):
        a = rnd.uniform(0, math.tau)
        r = rnd.uniform(0.0, 0.7)
        blob(rnd.uniform(0.18, 0.28), (math.cos(a) * r, math.sin(a) * r, height * 0.5), leaf if i % 2 else leaf2,
             scale=(1.2, 1.2, height * 2.6), jitter=0.25, seed=seed * 43 + i)
    for i in range(10):
        a = rnd.uniform(0, math.tau)
        r = rnd.uniform(0.0, 0.75)
        dot((math.cos(a) * r, math.sin(a) * r, height * 0.9), 0.05, berry)
    export(name, bevel=0.0)


def tuvor(name, col1, col2, seed, flat=0.35, count=6):
    """Low cushions on the rock: moss (mossa) or reindeer lichen (renlav)."""
    rnd = random.Random(seed)
    for i in range(count):
        a = rnd.uniform(0, math.tau)
        r = rnd.uniform(0.0, 0.6)
        blob(rnd.uniform(0.18, 0.4), (math.cos(a) * r, math.sin(a) * r, 0.02), col1 if i % 2 else col2,
             scale=(1.2, 1.2, flat), jitter=0.2, seed=seed * 47 + i)
    export(name, bevel=0.0)


def kaveldun(seed):
    """Bulrush (kaveldun): tall flat leaves and brown cigar heads, in sheltered shallows."""
    rnd = random.Random(seed)
    for i in range(14):
        x, y = rnd.uniform(-0.6, 0.6), rnd.uniform(-0.6, 0.6)
        h = rnd.uniform(1.2, 1.9)
        bpy.ops.mesh.primitive_cone_add(vertices=3, radius1=0.05, radius2=0.0, depth=h, location=(x, y, h / 2 - 0.3))
        o = bpy.context.object
        o.rotation_euler = (rnd.uniform(-0.2, 0.2), rnd.uniform(-0.2, 0.2), rnd.uniform(0, math.tau))
        _finish(o, "vass_gron" if i % 3 else "gras_gron")
    for i in range(5):
        x, y = rnd.uniform(-0.45, 0.45), rnd.uniform(-0.45, 0.45)
        h = rnd.uniform(1.5, 2.0)
        tube((x, y, -0.3), (x, y, h), 0.015, "vass_gron", verts=3)
        cyl(0.055, 0.28, (x, y, h - 0.32), "kaveldun", verts=6)
    export("kaveldun_%d" % seed, bevel=0.0)


def strandkal(seed):
    """Sea kale (strandkål): a rosette of big blue-grey leaves on the shingle, gone to seed."""
    rnd = random.Random(seed)
    for i in range(7):
        a = i / 7 * math.tau + rnd.uniform(-0.2, 0.2)
        c = (math.cos(a) * 0.38, math.sin(a) * 0.38, 0.14)
        o = blob(0.32, c, "strandkal", scale=(1.6, 0.9, 0.35), jitter=0.25, seed=seed * 53 + i)
        o.rotation_euler = (0, -0.35, a)
        bpy.context.view_layer.objects.active = o
        o.select_set(True)
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
        o.select_set(False)
    for i in range(3):
        a = rnd.uniform(0, math.tau)
        top = (math.cos(a) * 0.15, math.sin(a) * 0.15, rnd.uniform(0.55, 0.75))
        tube((0, 0, 0.1), top, 0.025, "strandkal", verts=4)
        blob(0.13, top, "strandkal_fro", scale=(1.3, 1.3, 0.8), jitter=0.3, seed=seed * 59 + i)
    export("strandkal_%d" % seed, bevel=0.0)


def stenar(seed):
    """A handful of smaller stones and pebbles (the rock shader gives them grain)."""
    rnd = random.Random(seed)
    for i in range(rnd.randint(4, 7)):
        a = rnd.uniform(0, math.tau)
        r = rnd.uniform(0.0, 0.9)
        size = rnd.uniform(0.1, 0.42)
        blob(size, (math.cos(a) * r, math.sin(a) * r, size * 0.2), "granit" if i % 3 else "flyttblock",
             scale=(1.3, 1.0, 0.65), jitter=0.25, seed=seed * 61 + i)
    export("stenar_%d" % seed, bevel=0.0)


def tall_fjarran(seed):
    """A cheap pine silhouette for the far islands."""
    rnd = random.Random(seed)
    h = rnd.uniform(7.0, 9.0)
    tube((0, 0, -0.3), (0, 0, h * 0.95), 0.25, "stam_hog", verts=5)
    blob(1.5, (0, 0, h), "barr", scale=(1.5, 1.5, 0.6), seed=seed * 67)
    blob(1.2, (rnd.uniform(-0.8, 0.8), rnd.uniform(-0.8, 0.8), h * 0.75), "barr_ljus", scale=(1.6, 1.6, 0.55),
         seed=seed * 71)
    export("tall_fjarran_%d" % seed, bevel=0.0)


# --- Round 4: road signs --------------------------------------------------------------------------

def skylt_vag(name, flip):
    """Local destination sign: white arrow board with a black edge on a grey post (text in Godot).
    `flip` points the arrow left (-X) instead of right."""
    f = -1 if flip else 1
    outer = [(-0.7, 1.95), (0.55, 1.95), (0.8, 2.175), (0.55, 2.4), (-0.7, 2.4)]
    inner = [(-0.66, 1.99), (0.53, 1.99), (0.74, 2.175), (0.53, 2.36), (-0.66, 2.36)]
    cyl(0.045, 2.5, (-0.5 * f, 0.06, 1.25), "stolpe", verts=6)
    slab_y([(x * f, z) for x, z in outer], 0.04, "skylt_svart", y=0.0)
    slab_y([(x * f, z) for x, z in inner], 0.03, "skylt_vit", y=-0.012)
    export(name, bevel=0.0)


def skylt_cykel():
    """Cycle route sign: white board, red edge and a red bicycle (text in Godot)."""
    cyl(0.045, 2.2, (0, 0.06, 1.1), "stolpe", verts=6)
    box((1.4, 0.04, 0.46), (0, 0, 1.85), "skylt_rod")
    box((1.32, 0.03, 0.38), (0, -0.015, 1.85), "skylt_vit")
    y = -0.04
    for cx in (-0.56, -0.36):
        ring((cx, y, 1.8), 0.065, 0.012, "skylt_rod", axis="y", segments=10)
    for a, b in (((-0.56, 1.8), (-0.47, 1.88)), ((-0.47, 1.88), (-0.38, 1.88)), ((-0.38, 1.88), (-0.36, 1.8)),
                 ((-0.47, 1.88), (-0.48, 1.8)), ((-0.48, 1.8), (-0.56, 1.8)), ((-0.39, 1.88), (-0.41, 1.92))):
        tube((a[0], y, a[1]), (b[0], y, b[1]), 0.01, "skylt_rod", verts=4)
    export("skylt_cykel", bevel=0.0)


def kantstolpe():
    """Swedish roadside marker post: white with a black band and a small reflector."""
    box((0.1, 0.12, 1.0), (0, 0, 0.45), "vit")
    box((0.105, 0.125, 0.22), (0, 0, 0.78), "svart")
    box((0.04, 0.13, 0.1), (0, 0, 0.78), "gul")
    export("kantstolpe", bevel=0.0)


# --- Round 7: the bigger island ---------------------------------------------------------------------

def hassel(seed):
    """Hazel (hassel): a big rounded thicket of many stems, the 'buskage' along fields and lanes."""
    rnd = random.Random(seed)
    for i in range(6):
        a = i / 6 * math.tau + rnd.uniform(-0.3, 0.3)
        tube((0, 0, -0.2), (math.cos(a) * 1.0, math.sin(a) * 1.0, rnd.uniform(1.8, 2.6)), 0.06, "stam_lag", verts=4)
    for i in range(11):
        a = rnd.uniform(0, math.tau)
        r = rnd.uniform(0.2, 1.5)
        blob(rnd.uniform(0.8, 1.15), (math.cos(a) * r, math.sin(a) * r, rnd.uniform(1.0, 3.0)), "hassel" if i % 2 else "hassel2",
             scale=(1.1, 1.1, 0.9), jitter=0.22, seed=seed * 71 + i)
    export("hassel_%d" % seed, bevel=0.0)


def nypon(seed):
    """Dog rose (nypon): a dense dark bush with red hips and the last pink flowers of August."""
    rnd = random.Random(seed)
    for i in range(6):
        a = rnd.uniform(0, math.tau)
        r = rnd.uniform(0.0, 0.6)
        blob(rnd.uniform(0.45, 0.6), (math.cos(a) * r, math.sin(a) * r, rnd.uniform(0.4, 1.1)), "nypon_lov",
             scale=(1.1, 1.1, 0.9), jitter=0.25, seed=seed * 73 + i)
    for i in range(10):
        a = rnd.uniform(0, math.tau)
        r = rnd.uniform(0.5, 0.85)
        dot((math.cos(a) * r, math.sin(a) * r, rnd.uniform(0.4, 1.3)), 0.035, "nypon" if i % 3 else "nypon_blomma")
    export("nypon_%d" % seed, bevel=0.0)


def kyrka():
    """A white archipelago church: nave and lower chancel under steep dark roofs, a west tower with
    a tall spire, tall arched windows and a gilded weathervane. Front (tower) towards -X."""
    box((17.0, 9.0, 0.6), (0, 0, 0.1), "grund")
    gable_house(14.0, 8.0, 6.5, 5.0, "vit", "kyrktak", trim=False)
    box((5.0, 6.0, 0.4), (9.0, 0, 0.1), "grund")
    prism([(-3.0, 0), (3.0, 0), (3.0, 5.2), (0, 8.8), (-3.0, 5.2)], 4.5, "vit", x0=9.2)
    slope = math.atan2(3.6, 3.0)
    for side in (-1, 1):
        box((4.8, math.hypot(3.0, 3.6) + 0.3, 0.14), (9.2, side * 1.58, 5.2 + 1.8 + 0.06), "kyrktak", rot=(-side * slope, 0, 0))
    for x in (-4.5, -1.5, 1.5, 4.5):
        for side in (-1, 1):
            y = side * 4.03
            box((1.2, 0.08, 2.8), (x, y, 3.2), "vit")
            box((0.95, 0.1, 2.5), (x, y + side * 0.02, 3.1), "kyrkfonster")
            bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=0.48, depth=0.1, location=(x, y + side * 0.02, 4.35),
                                                rotation=(math.pi / 2, 0, 0))
            _finish(bpy.context.object, "kyrkfonster")
    tx = -9.4
    box((5.2, 5.2, 15.0), (tx, 0, 7.5), "vit")
    box((5.5, 5.5, 0.35), (tx, 0, 15.0), "grund")
    for side in (-1, 1):
        box((0.1, 1.2, 1.6), (tx + side * 2.62, 0, 12.4), "svart")
        box((1.2, 0.1, 1.6), (tx, side * 2.62, 12.4), "svart")
    cyl(3.0, 10.0, (tx, 0, 20.2), "kyrktak", verts=4, radius_top=0.0, rot=(0, 0, math.pi / 4))
    cyl(0.06, 1.6, (tx, 0, 25.9), "guld", verts=5)
    box((0.7, 0.08, 0.3), (tx + 0.2, 0, 26.4), "guld")
    blob(0.18, (tx, 0, 25.4), "guld", jitter=0.0)
    box((0.1, 1.5, 2.6), (tx - 2.62, 0, 1.4), "tra_mork")
    box((0.08, 1.8, 2.9), (tx - 2.6, 0, 1.5), "grund")
    export("kyrka", bevel=0.03)


def klockstapel():
    """A red wooden bell tower beside the church: splayed legs, a boarded belfry and a pointed roof."""
    for sx in (-1, 1):
        for sy in (-1, 1):
            tube((sx * 1.8, sy * 1.8, -0.2), (sx * 1.0, sy * 1.0, 6.0), 0.16, "falu", verts=5)
    box((2.3, 2.3, 2.6), (0, 0, 7.2), "falu")
    for side in (-1, 1):
        box((0.06, 1.3, 1.2), (side * 1.17, 0, 7.4), "svart")
        box((1.3, 0.06, 1.2), (0, side * 1.17, 7.4), "svart")
    cyl(1.9, 3.4, (0, 0, 10.2), "kyrktak", verts=4, radius_top=0.0, rot=(0, 0, math.pi / 4))
    cyl(0.04, 1.0, (0, 0, 12.3), "guld", verts=5)
    box((4.0, 0.15, 0.15), (0, 0, 3.0), "falu", rot=(0, 0, math.pi / 4))
    box((4.0, 0.15, 0.15), (0, 0, 3.0), "falu", rot=(0, 0, -math.pi / 4))
    export("klockstapel", bevel=0.0)


def kyrkmur():
    """One 4 m bay of a whitewashed churchyard wall with a grey stone cap."""
    box((4.0, 0.55, 1.05), (0, 0, 0.5), "vit")
    box((4.05, 0.7, 0.14), (0, 0, 1.08), "grund")
    export("kyrkmur", bevel=0.02)


def gravstenar():
    """A row of old gravestones and two crosses on the churchyard."""
    rnd = random.Random(12)
    for k in range(6):
        x = k * 1.6 - 4.0
        h = rnd.uniform(0.6, 1.0)
        box((0.6, 0.14, h), (x, rnd.uniform(-0.1, 0.1), h / 2), "flyttblock" if k % 2 else "grund")
        box((0.7, 0.9, 0.08), (x, 0.6, 0.04), "gras_gron")
    for x in (-4.8, 5.6):
        box((0.1, 0.1, 1.1), (x, 0, 0.55), "svart")
        box((0.5, 0.1, 0.1), (x, 0, 0.85), "svart")
    export("gravstenar", bevel=0.0)


def midsommarstang():
    """A maypole dressed in birch leaves and flowers, two rings on the crossbar, blue and yellow ribbons."""
    rnd = random.Random(6)
    cyl(0.1, 6.5, (0, 0, 3.25), "stang", verts=6)
    tube((-1.6, 0, 4.8), (1.6, 0, 4.8), 0.07, "stang", verts=5)
    for x in (-1.45, 1.45):
        ring((x, 0, 3.9), 0.55, 0.09, "bjork_lov", axis="y", segments=10)
        tube((x, 0, 4.8), (x, 0, 4.45), 0.03, "stang", verts=3)
    for k in range(18):
        z = 0.6 + k * 0.33
        blob(0.18, (rnd.uniform(-0.08, 0.08), rnd.uniform(-0.08, 0.08), z), "bjork_lov" if k % 2 else "bjork_lov2", jitter=0.3)
    for k in range(10):
        x = -1.5 + k * 0.33
        blob(0.15, (x, 0, 4.85), "bjork_lov", jitter=0.3)
    for k in range(26):
        a = rnd.uniform(0, math.tau)
        dot((math.cos(a) * 0.17, math.sin(a) * 0.17, rnd.uniform(0.6, 6.0)), 0.06,
            ("blomma", "flagga_gul", "ljung_ljus", "nypon_blomma")[k % 4])
    for x, m in ((-0.8, "flagga_bla"), (-0.5, "flagga_gul"), (0.5, "flagga_bla"), (0.8, "flagga_gul")):
        box((0.06, 0.02, 1.4), (x, 0.05, 4.1), m)
    cyl(0.3, 0.12, (0, 0, 6.54), "flagga_gul", verts=6)
    export("midsommarstang", bevel=0.0)


def ko(name, coat, patch, grazing=False):
    """A cow (a Swedish red, or black-and-white): a deep body from shoulders, belly and hips with
    white patches, an udder, legs in two parts with knees and hocks and dark hooves, a long head with
    a pale muzzle, nostrils, eyes, ears out to the sides and short curved horns, a tail with a tuft."""
    # The body: chest, barrel and hips, so the back is long and straight and the belly hangs.
    blob(0.5, (0.5, 0, 1.08), coat, scale=(1.0, 0.82, 0.9), jitter=0.04, subdiv=2, seed=1)
    blob(0.56, (0.0, 0, 1.02), coat, scale=(1.15, 0.86, 0.88), jitter=0.04, subdiv=2, seed=2)
    blob(0.48, (-0.52, 0, 1.1), coat, scale=(1.0, 0.82, 0.86), jitter=0.04, subdiv=2, seed=3)
    blob(0.2, (-0.78, 0, 1.3), coat, scale=(1.2, 1.6, 0.7), jitter=0.04, seed=4)          # hip bones
    blob(0.3, (-0.15, 0.36, 1.12), patch, scale=(1.4, 0.4, 0.9), jitter=0.08, seed=5)
    blob(0.24, (0.42, -0.36, 1.0), patch, scale=(1.2, 0.4, 0.8), jitter=0.08, seed=6)
    blob(0.18, (-0.45, -0.35, 1.2), patch, scale=(1.1, 0.4, 0.7), jitter=0.08, seed=7)
    # The udder between the hind legs, with four teats.
    blob(0.17, (-0.42, 0, 0.62), "hud", scale=(1.1, 1.0, 0.75), jitter=0.0, subdiv=2)
    for x in (-0.48, -0.36):
        for y in (-0.07, 0.07):
            taper((x, y, 0.52), (x, y, 0.44), 0.025, 0.018, "hud", verts=4)
    # Legs: the front ones straight with a knee, the hind ones with the hock bent back.
    for y in (-0.22, 0.22):
        taper((0.55, y, 0.85), (0.58, y, 0.45), 0.11, 0.07, coat, verts=6)
        blob(0.07, (0.58, y, 0.45), coat, jitter=0.0)
        taper((0.58, y, 0.45), (0.57, y, 0.08), 0.06, 0.05, patch if coat == "ko_svart" else coat, verts=6)
        cyl(0.065, 0.09, (0.57, y, 0.045), "svart", verts=6)
        taper((-0.55, y, 0.95), (-0.68, y, 0.48), 0.14, 0.07, coat, verts=6)
        blob(0.07, (-0.68, y, 0.48), coat, jitter=0.0)
        taper((-0.68, y, 0.48), (-0.6, y, 0.08), 0.06, 0.05, coat, verts=6)
        cyl(0.065, 0.09, (-0.6, y, 0.045), "svart", verts=6)
    # Neck with a dewlap, and the head (down in the grass when grazing).
    neck_end = Vector((1.12, 0, 0.55)) if grazing else Vector((1.1, 0, 1.3))
    taper((0.75, 0, 1.15), neck_end, 0.3, 0.17, coat, verts=8)
    blob(0.14, (0.92, 0, 0.82) if not grazing else (0.95, 0, 0.72), coat, scale=(1.2, 0.5, 1.2), jitter=0.0)
    down = Vector((0.18, 0, -0.32)) if grazing else Vector((0.22, 0, -0.08))
    head = neck_end + down * 0.5
    snout = neck_end + down * 1.6
    taper(head, snout, 0.16, 0.12, coat, verts=8)
    blob(0.15, head, coat, scale=(1.0, 0.95, 1.0), jitter=0.0)
    blob(0.13, snout, "hud", scale=(0.8, 1.0, 0.8), jitter=0.0, subdiv=2)
    for y in (-0.05, 0.05):
        dot(snout + Vector((0.1, y, 0.0)), 0.02, "svart")
    side = Vector((0, 1, 0))
    for sgn in (-1, 1):
        dot(head + Vector((0.05, 0.13 * sgn, 0.05)), 0.025, "svart")
        blob(0.08, head + Vector((-0.05, 0.2 * sgn, 0.06)), coat, scale=(0.6, 1.4, 0.45), jitter=0.0)
        base = head + Vector((-0.06, 0.1 * sgn, 0.14))
        bend = base + Vector((0.0, 0.08 * sgn, 0.06))
        tube(base, bend, 0.025, "ko_horn", verts=5)
        tube(bend, bend + Vector((0.05, 0.03 * sgn, 0.05)), 0.018, "ko_horn", verts=5)
    blob(0.09, head + Vector((-0.1, 0, 0.14)), patch, scale=(1.0, 1.4, 0.5), jitter=0.0)      # the poll tuft
    # Tail from the tail head down the back of the thighs, with a dark tuft.
    taper((-0.9, 0, 1.28), (-0.98, 0, 0.55), 0.04, 0.025, coat, verts=5)
    blob(0.07, (-0.98, 0, 0.5), "svart", scale=(0.8, 0.8, 1.6), jitter=0.1)
    export(name, bevel=0.0)


def far(name, grazing=False):
    """A sheep: a cloud of wool from several lumps, a dark face with a wool cap, ears out to the
    sides, pale eyes, thin dark legs in two parts with woolly tops, and a short woolly tail."""
    rnd = random.Random(7 if grazing else 3)
    for i, (x, y, z, r) in enumerate(((0.0, 0, 0.66, 0.36), (0.28, 0, 0.7, 0.3), (-0.28, 0, 0.68, 0.33),
            (0.12, 0.2, 0.7, 0.26), (0.12, -0.2, 0.7, 0.26), (-0.15, 0.2, 0.66, 0.27), (-0.15, -0.2, 0.66, 0.27),
            (0.0, 0, 0.88, 0.25), (-0.3, 0, 0.84, 0.22), (0.3, 0, 0.86, 0.2))):
        blob(r, (x, y, z), "ull", jitter=0.06, subdiv=2, seed=rnd.randint(0, 999))
    for x in (-0.25, 0.25):
        for y in (-0.13, 0.13):
            blob(0.07, (x, y, 0.4), "ull", jitter=0.1)
            tube((x, y, 0.4), (x + 0.01, y, 0.2), 0.03, "ejder_svart", verts=5)
            blob(0.035, (x + 0.01, y, 0.2), "ejder_svart", jitter=0.0)
            tube((x + 0.01, y, 0.2), (x, y, 0.03), 0.027, "ejder_svart", verts=5)
            cyl(0.035, 0.05, (x, y, 0.025), "svart", verts=5)
    head = Vector((0.6, 0, 0.36)) if grazing else Vector((0.58, 0, 0.82))
    taper((0.38, 0, 0.74), head, 0.15, 0.1, "ull", verts=6)
    nose = head + (Vector((0.14, 0, -0.1)) if grazing else Vector((0.18, 0, -0.05)))
    taper(head, nose, 0.1, 0.06, "ejder_svart", verts=6)
    blob(0.1, head, "ejder_svart", scale=(1.2, 0.9, 1.0), jitter=0.0)
    blob(0.09, head + Vector((-0.04, 0, 0.08)), "ull", scale=(1.0, 1.1, 0.7), jitter=0.05, subdiv=2)  # wool cap
    for sgn in (-1, 1):
        blob(0.06, head + Vector((-0.02, 0.15 * sgn, 0.03)), "ejder_svart", scale=(0.5, 1.6, 0.45), jitter=0.0)
        dot(head + Vector((0.06, 0.08 * sgn, 0.03)), 0.018, "ko_horn")
    blob(0.09, (-0.55, 0, 0.72), "ull", scale=(0.9, 0.8, 1.2), jitter=0.05, subdiv=2)        # the tail
    export(name, bevel=0.0)


def lada():
    """A big red barn (lada) with a grey sheet roof, white-trimmed double doors and a ramp."""
    box((12.4, 8.4, 0.5), (0, 0, 0.0), "grund")
    gable_house(12.0, 8.0, 4.6, 3.8, "falu", "takgra")
    box((3.4, 0.1, 3.4), (0, -4.04, 1.9), "tra_mork")
    box((3.7, 0.08, 3.7), (0, -4.01, 2.0), "vit")
    for rot in (math.atan2(3.3, 3.3), -math.atan2(3.3, 3.3)):
        box((4.6, 0.12, 0.16), (0, -4.1, 1.9), "vit", rot=(0, rot, 0))
    box((3.6, 2.4, 0.3), (0, -5.2, 0.15), "grund", rot=(math.radians(-6), 0, 0))
    window(-4.2, -4.0, 2.4, -1, w=0.7, h=0.7)
    window(4.2, -4.0, 2.4, -1, w=0.7, h=0.7)
    for x in (-6.03, 6.03):
        box((0.08, 1.2, 1.0), (x, 0, 6.0), "tra_mork")
        box((0.06, 1.4, 1.2), (x, 0, 6.0), "vit")
    export("lada", bevel=0.02)


def gammal_bil():
    """An old rounded 1960s family car in pale blue with cream roof, chrome bumpers and whitewalls.
    Front towards +X."""
    side = [(-2.15, 0.38), (2.15, 0.38), (2.2, 0.55), (2.1, 0.78), (1.4, 0.88), (0.65, 0.92), (-1.2, 0.92),
            (-1.85, 0.86), (-2.2, 0.7)]
    slab_y(side, 1.66, "bil_bla")                                                                  # body
    slab_y([(-1.5, 0.9), (0.6, 0.9), (0.25, 1.38), (-1.2, 1.38), (-1.55, 1.12)], 1.5, "glas_mork")  # glasshouse
    slab_y([(-1.35, 1.36), (0.3, 1.36), (0.25, 1.42), (-1.25, 1.42)], 1.42, "bil_tak")            # roof
    for x in (-0.6, 0.12):                                                                       # pillars
        box((0.08, 1.52, 0.46), (x, 0, 1.14), "bil_tak")
    box((0.1, 1.52, 0.5), (0.43, 0, 1.13), "bil_tak", rot=(0, math.radians(-40), 0))
    box((1.2, 1.7, 0.04), (1.55, 0, 0.88), "bil_bla")                                             # bonnet line
    for x in (2.22, -2.22):
        box((0.14, 1.7, 0.14), (x, 0, 0.44), "metall")                                            # bumpers
    for y in (-0.55, 0.55):
        cyl(0.12, 0.06, (2.16, y, 0.66), "vit", verts=10, rot=(0, math.pi / 2, 0))                # headlights
        box((0.06, 0.14, 0.1), (-2.2, y * 1.1, 0.62), "bat_rod")
    box((0.06, 0.6, 0.2), (2.18, 0, 0.62), "metall")                                              # grille
    for y in (-0.84, 0.84):
        box((3.6, 0.04, 0.05), (0.0, y, 0.62), "metall")                                         # chrome strip
        box((0.12, 0.04, 0.04), (0.3, y, 0.78), "metall")                                         # door handle
    for x in (1.35, -1.35):
        for y in (-0.78, 0.78):
            bpy.ops.mesh.primitive_torus_add(major_radius=0.25, minor_radius=0.1, major_segments=12, minor_segments=5,
                                             location=(x, y, 0.33), rotation=(math.pi / 2, 0, 0))
            _finish(bpy.context.object, "dack")
            cyl(0.17, 0.205, (x, y, 0.33), "vit", verts=10, rot=(math.pi / 2, 0, 0))
            cyl(0.1, 0.215, (x, y, 0.33), "metall", verts=8, rot=(math.pi / 2, 0, 0))
    export("gammal_bil", bevel=0.0)


def cafe():
    """A small yellow summer café with a terrace, big windows and a striped awning (sign in Godot)."""
    box((8.4, 5.4, 0.45), (0, 0, 0.12), "grund")
    gable_house(8.0, 5.0, 3.0, 2.0, "gul", "tegel")
    for x in (-2.6, 0.0, 2.6):
        window(x, -2.5, 1.6, -1, w=1.4, h=1.3)
    box((1.0, 0.1, 2.0), (3.5, -2.54, 1.25), "dorr")
    box((9.0, 3.2, 0.25), (0, -4.1, 0.25), "tra_gra")
    for k in range(8):
        box((1.1, 1.5, 0.06), (-3.85 + k * 1.1, -3.2, 2.85), "vit" if k % 2 else "bat_bla", rot=(math.radians(-25), 0, 0))
    box((2.2, 0.08, 0.55), (-1.0, -2.56, 3.45), "vit")
    export("cafe", bevel=0.02)


def cafebord():
    """A round café table with four chairs under a parasol."""
    cyl(0.4, 0.04, (0, 0, 0.74), "vit", verts=10)
    cyl(0.04, 0.74, (0, 0, 0.37), "metall", verts=5)
    for k in range(4):
        a = k / 4 * math.tau + 0.4
        x, y = math.cos(a) * 0.7, math.sin(a) * 0.7
        box((0.4, 0.4, 0.04), (x, y, 0.45), "tra")
        box((0.04, 0.4, 0.42), (x + math.cos(a) * 0.2, y + math.sin(a) * 0.2, 0.68), "tra", rot=(0, 0, a))
        for d in ((-0.17, -0.17), (0.17, -0.17), (-0.17, 0.17), (0.17, 0.17)):
            box((0.03, 0.03, 0.45), (x + d[0], y + d[1], 0.22), "metall")
    cyl(0.03, 2.3, (0, 0, 1.15), "tra", verts=5)
    cyl(1.25, 0.5, (0, 0, 2.25), "trika_vit", verts=8, radius_top=0.05)
    export("cafebord", bevel=0.0)


def gastbrygga():
    """A marina pier (gästbrygga): a 40 m walkway with mooring fingers on both sides (+X out to sea)."""
    length, width = 40.0, 2.4
    box((length, width, 0.12), (length / 2, 0, 0), "tra_gra")
    for k in range(int(length / 0.6)):
        box((0.04, width + 0.02, 0.125), (0.3 + k * 0.6, 0, 0.0), "tra_mork")
    for x in range(0, int(length) + 1, 5):
        for y in (-width / 2, width / 2):
            cyl(0.13, 3.0, (x, y, -1.4), "tra_mork", verts=6)
    for k in range(6):
        x = 6.0 + k * 6.0
        for side in (-1, 1):
            box((0.6, 7.0, 0.1), (x, side * (width / 2 + 3.5), 0.0), "tra_gra")
            cyl(0.1, 0.25, (x, side * (width / 2 + 6.8), 0.15), "metall", verts=6)
    for x in range(4, int(length), 8):
        cyl(0.07, 1.0, (x, width / 2 - 0.1, 0.5), "vit", verts=5)
        cyl(0.07, 1.0, (x, -width / 2 + 0.1, 0.5), "vit", verts=5)
    export("gastbrygga", bevel=0.0)


# --- Cyclist (loose parts, origins at the joints) ----------------------------------------------

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


def annulus(center, r_out, r_in, thickness, material, segments=24):
    """A flat ring across Y (a deep wheel rim, a chainring)."""
    cx, cy, cz = center
    bm = bmesh.new()
    rings = []
    for y in (cy - thickness / 2, cy + thickness / 2):
        outer = [bm.verts.new((cx + r_out * math.cos(a), y, cz + r_out * math.sin(a)))
                 for a in (k / segments * math.tau for k in range(segments))]
        inner = [bm.verts.new((cx + r_in * math.cos(a), y, cz + r_in * math.sin(a)))
                 for a in (k / segments * math.tau for k in range(segments))]
        rings.append((outer, inner))
    (o0, i0), (o1, i1) = rings
    for k in range(segments):
        j = (k + 1) % segments
        bm.faces.new((o0[k], o0[j], i0[j], i0[k]))
        bm.faces.new((o1[k], i1[k], i1[j], o1[j]))
        bm.faces.new((o0[k], o1[k], o1[j], o0[j]))
        bm.faces.new((i0[k], i0[j], i1[j], i1[k]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new("ring")
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new("ring", me)
    bpy.context.collection.objects.link(o)
    o.data.materials.append(mat(material))
    return o


def cyklist():
    """Bike and rider, more detailed. Bike forward is +X, left is +Y; lengths in metres. The joints
    (hip, bottom bracket, axles) and leg lengths are the ones rider.gd pedals with."""
    R, BB, S = Vector((-0.50, 0, 0.34)), Vector((0.0, 0, 0.29)), Vector((-0.13, 0, 0.82))
    H, HB, F = Vector((0.53, 0, 0.80)), Vector((0.56, 0, 0.66)), Vector((0.60, 0, 0.34))
    # Frame: chunkier tubes, an aero down tube, tapered fork.
    taper(BB, S, 0.026, 0.022, "ram", verts=8)
    taper(S + Vector((0.01, 0, -0.02)), H, 0.021, 0.024, "ram", verts=8)
    taper(BB, HB, 0.034, 0.028, "ram", verts=8)
    taper(HB, H, 0.03, 0.028, "ram", verts=8)
    for side in (-0.06, 0.06):
        tube((BB.x, side * 0.6, BB.z), (R.x, side, R.z), 0.015, "ram", verts=6)
        tube((S.x, side * 0.5, S.z - 0.03), (R.x, side, R.z), 0.012, "ram", verts=6)
        taper((HB.x, side * 0.55, HB.z), (F.x, side, F.z), 0.019, 0.011, "ram", verts=6)
    box((0.1, 0.03, 0.05), (0.28, 0, 0.55), "trika_vit", rot=(0, math.radians(-38), 0))      # logo on the down tube
    taper(S, S + Vector((-0.02, 0, 0.08)), 0.014, 0.014, "svart", verts=6)                    # seat post
    bpy.ops.mesh.primitive_cone_add(vertices=8, radius1=0.075, radius2=0.03, depth=0.27, location=(-0.16, 0, 0.915))
    _finish(bpy.context.object, "sadel", rot=(0, math.radians(-90), 0))
    box((0.12, 0.13, 0.03), (-0.21, 0, 0.91), "sadel")
    # Stem, handlebar with drops, brake hoods.
    tube(H, (0.63, 0, 0.84), 0.017, "svart", verts=6)
    tube((0.63, -0.21, 0.845), (0.63, 0.21, 0.845), 0.013, "svart", verts=6)
    for y in (-0.21, 0.21):
        tube((0.63, y, 0.845), (0.71, y, 0.835), 0.012, "svart", verts=5)
        tube((0.71, y, 0.835), (0.73, y, 0.77), 0.012, "svart", verts=5)
        tube((0.73, y, 0.77), (0.66, y, 0.73), 0.012, "svart", verts=5)
        box((0.07, 0.03, 0.045), (0.705, y, 0.86), "svart", rot=(0, math.radians(15), 0))
    # Bottle and cage on the down tube, cassette, derailleur and chain on the drive side (-Y).
    bottle_at = BB.lerp(HB, 0.45) + Vector((-0.03, 0, 0.05))
    taper(bottle_at - Vector((0.07, 0, 0.05)), bottle_at + Vector((0.07, 0, 0.05)), 0.034, 0.034, "trika_vit", verts=8)
    cyl(0.036, 0.03, (-0.5, -0.045, 0.34), "metall", verts=10, rot=(math.pi / 2, 0, 0))
    box((0.04, 0.02, 0.09), (-0.49, -0.06, 0.26), "svart")
    for z0, z1 in ((0.39, 0.375), (0.19, 0.30)):
        tube((0.0, -0.05, z0), (-0.5, -0.05, z1), 0.006, "svart", verts=4)
    part("Ram", (0, 0, 0))

    for name, c in (("HjulBak", R), ("HjulFram", F)):
        bpy.ops.mesh.primitive_torus_add(major_radius=0.325, minor_radius=0.018, major_segments=32, minor_segments=6,
                                         location=c, rotation=(math.pi / 2, 0, 0))
        _finish(bpy.context.object, "dack")
        annulus(c, 0.312, 0.262, 0.022, "svart", segments=32)                            # deep carbon rim
        annulus(c, 0.3125, 0.3, 0.024, "falg", segments=32)                                # braking track
        for i in range(12):
            a = i / 12 * math.tau
            y = 0.012 if i % 2 else -0.012
            tube((c.x + 0.02 * math.cos(a), y * 2, c.z + 0.02 * math.sin(a)),
                 (c.x + 0.262 * math.cos(a), y * 0.3, c.z + 0.262 * math.sin(a)), 0.0035, "falg", verts=3)
        cyl(0.025, 0.1, c, "metall", verts=8, rot=(math.pi / 2, 0, 0))
        part(name, c)

    annulus((0, -0.055, 0.29), 0.105, 0.08, 0.008, "metall", segments=24)                 # chainring
    annulus((0, -0.06, 0.29), 0.085, 0.03, 0.006, "svart", segments=12)
    for side, sign in ((0.075, 1), (-0.075, -1)):
        taper((0, side, 0.29), (sign * 0.17, side, 0.29), 0.016, 0.012, "svart", verts=6)
        box((0.09, 0.07, 0.02), (sign * 0.17, side + math.copysign(0.035, side), 0.29), "svart")
    part("Vev", BB)

    # Rider: a shaped torso (jersey blue with the yellow cross on the back), arms to the hoods,
    # neck, head, helmet with vents and dark glasses.
    hip, shoulder = Vector((-0.12, 0, 0.95)), Vector((0.33, 0, 1.27))
    spine = (shoulder - hip).normalized()
    up = Vector((-spine.z, 0, spine.x))
    seg = 16
    profile = [(-0.08, 0.15, 0.11), (0.3, 0.165, 0.12), (0.55, 0.19, 0.125), (0.7, 0.2, 0.125), (0.9, 0.2, 0.11),
               (1.04, 0.15, 0.08)]
    bm = bmesh.new()
    rings = []
    for t, wy, wz in profile:
        c = hip.lerp(shoulder, t) + up * 0.01
        rings.append([bm.verts.new(c + Vector((0, math.cos(a) * wy, 0)) + up * (math.sin(a) * wz))
                      for a in (k / seg * math.tau for k in range(seg))])
    for r in range(len(rings) - 1):
        for k in range(seg):
            j = (k + 1) % seg
            f = bm.faces.new((rings[r][k], rings[r][j], rings[r + 1][j], rings[r + 1][k]))
            centre_a = (k + 0.5) / seg * math.tau
            on_back = math.sin(centre_a) > 0.35
            vertical = abs(math.cos(centre_a)) < 0.25
            band = r == 2
            f.material_index = 1 if on_back and (vertical or band) else 0
    bm.faces.new(list(reversed(rings[0])))
    bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new("torso")
    bm.to_mesh(me)
    bm.free()
    torso = bpy.data.objects.new("torso", me)
    bpy.context.collection.objects.link(torso)
    torso.data.materials.append(mat("trika"))
    torso.data.materials.append(mat("flagga_gul"))
    blob(0.16, hip + Vector((0.0, 0, -0.03)), "byxor", scale=(1.15, 0.95, 0.8), jitter=0.0, subdiv=2)
    neck_a, neck_b = shoulder + Vector((0.02, 0, 0.03)), Vector((0.43, 0, 1.37))
    taper(neck_a, neck_b, 0.05, 0.045, "hud", verts=8)
    blob(0.095, (0.465, 0, 1.415), "hud", scale=(1.15, 0.92, 1.0), jitter=0.0, subdiv=2)
    blob(0.13, (0.445, 0, 1.475), "hjalm", scale=(1.4, 1.02, 0.78), jitter=0.0, subdiv=2)
    for y in (-0.05, 0.0, 0.05):
        box((0.24, 0.018, 0.02), (0.43, y, 1.565 - abs(y) * 0.3), "svart")
    box((0.03, 0.17, 0.035), (0.555, 0, 1.425), "svart")                                    # glasses
    for y in (-0.17, 0.17):
        s_pt = Vector((0.33, y, 1.27))
        elbow = Vector((0.47, y * 1.15, 1.06))
        wrist = Vector((0.66, y * 1.2, 0.875))
        blob(0.07, s_pt, "trika", jitter=0.0)
        taper(s_pt, s_pt.lerp(elbow, 0.55), 0.055, 0.047, "trika", verts=8)
        taper(s_pt.lerp(elbow, 0.55), elbow, 0.044, 0.04, "hud", verts=8)
        taper(elbow, wrist, 0.039, 0.03, "hud", verts=8)
        blob(0.045, (0.69, y * 1.2, 0.865), "svart", scale=(1.4, 1.0, 1.0), jitter=0.0)
    part("Kropp", (0, 0, 0))

    # Legs hang along -Z from their joint; rider.gd aims them with two-bone IK.
    for side, y in (("V", 0.09), ("H", -0.09)):
        taper((0, y, 0.03), (0, y, -0.33), 0.08, 0.062, "byxor", verts=10)
        taper((0, y, -0.33), (0, y, -0.44), 0.058, 0.05, "hud", verts=10)
        part("Lar" + side, (0, y, 0))
        blob(0.052, (0, y, 0.0), "hud", jitter=0.0)
        taper((0, y, -0.01), (0, y, -0.15), 0.05, 0.058, "hud", verts=10)
        taper((0, y, -0.15), (0, y, -0.31), 0.058, 0.038, "hud", verts=10)
        taper((0, y, -0.31), (0, y, -0.41), 0.037, 0.036, "sko", verts=8)
        box((0.25, 0.085, 0.07), (0.05, y, -0.455), "sko")
        box((0.26, 0.09, 0.025), (0.05, y, -0.49), "svart")
        part("Ben" + side, (0, y, 0))
    if ONLY and "cyklist" not in ONLY:
        clear()
        return
    bpy.ops.object.select_all(action="DESELECT")
    for o in bpy.data.objects:
        o.select_set(o.type == "MESH")
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "cyklist.glb"), export_format="GLB", use_selection=True)
    print("exporterad cyklist", [o.name for o in bpy.data.objects])
    clear()


bpy.ops.wm.read_factory_settings(use_empty=True)
rodstuga()
sjobod()
brygga()
roddbat()
fiskebat()
fyr()
for seed, h in ((1, 10.5), (2, 9.0), (3, 12.5), (4, 11.0)):
    tall(seed, h)
for seed, h in ((1, 7.0), (2, 5.5)):
    gran(seed, h)
for seed, s in ((1, 1.0), (2, 1.6), (3, 2.6)):
    sten(seed, s)
for seed in (1, 2):
    ljung(seed)
for seed in range(1, 6):
    hall(seed)
for seed in (1, 2):
    ljungtuva(seed)
    grastuva(seed)
    buske(seed)
for seed in (1, 2, 3):
    moln(seed)
for seed, h in ((1, 8.0), (2, 6.5)):
    bjork(seed, h)
for seed in (1, 2, 3):
    en(seed)
for seed in (1, 2):
    vindtall(seed)
    vass(seed)
    nackrosor(seed)
    flyttblock(seed)
segelbat()
segelbat("segelbat_forto", "bat_vit", sail=False)
segelbat("segelbat_bla", "bat_bla", sail=False)
kummel()
prick("prick_rod")
prick("prick_gron")
vedtrave()
gardsgard()
brevlada()
uthus()
stuga_variant("vitstuga", "vit", "takgra")
stuga_variant("gulstuga", "gul", "tegel")
blastuga()
storgard()
gronstuga()
vaderkvarn()
utkikstorn()
bastu()
mas()
flaggstang()
hamnprylar()
boj()
# Round 4
eka("eka", "tra")
eka("eka_gron", "eka_gron")
snipa()
badbrygga()
natstallning()
livbojsstall()
vimpelstang()
bak()
skargardsbat()
ejdrar()
kajak()
staket()
syren()
for seed in (1, 2):
    appeltrad(seed)
tvattlina()
utemobler()
for seed, h in ((1, 8.5), (2, 7.0)):
    al(seed, h)
for seed, h in ((1, 6.5), (2, 5.5)):
    ronn(seed, h)
for seed in (1, 2):
    rallarros(seed)
for seed in (1, 2):
    havtorn(seed)
    salg(seed)
    kaveldun(seed)
    strandkal(seed)
ris("blabarsris_1", "ris", "ris2", "blabar", 1)
ris("blabarsris_2", "ris2", "ris", "blabar", 2)
ris("lingonris_1", "lingonris", "ris", "lingon", 3, height=0.2)
tuvor("mossa_1", "mossa", "mossa2", 1)
tuvor("mossa_2", "mossa2", "mossa", 2)
tuvor("renlav_1", "renlav", "renlav2", 3, flat=0.55, count=8)
for seed in (1, 2, 3):
    stenar(seed)
for seed in (1, 2):
    tall_fjarran(seed)
skylt_vag("skylt_vag_h", False)
skylt_vag("skylt_vag_v", True)
skylt_cykel()
kantstolpe()
# Round 7
for seed in (1, 2):
    hassel(seed)
    nypon(seed)
kyrka()
klockstapel()
kyrkmur()
gravstenar()
midsommarstang()
ko("ko_rod", "ko_rod", "ko_vit")
ko("ko_svart", "ko_svart", "ko_vit", grazing=True)
ko("ko_bete", "ko_rod", "ko_vit", grazing=True)
far("far_1")
far("far_2", grazing=True)
lada()
gammal_bil()
cafe()
cafebord()
gastbrygga()
cyklist()
print("ALLA MODELLER KLARA")
