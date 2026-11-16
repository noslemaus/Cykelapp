"""Render every model in a world folder from two corners and tile them into contact sheets.

    blender --background --python assets/blender/kontaktark.py -- <models folder> <out folder> [name,name,…]

Uses the textured <name>_tex.glb where it exists, as the game does. Each tile shows the model from the
front-left and the back-right with its name under it; 20 models per sheet.
"""
import math
import os
import sys

import bpy
import numpy as np
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
SRC, OUT = argv[0], argv[1]
ONLY = set(argv[2].split(",")) if len(argv) > 2 and argv[2] else set()
os.makedirs(OUT, exist_ok=True)
TILE = int(os.environ.get("TILE", 300))
COLS, ROWS = int(os.environ.get("COLS", 4)), int(os.environ.get("ROWS", 5))
# VYER="x,y,z;x,y,z" sets the camera directions (default: front-left and back-right).
VIEWS = [tuple(map(float, v.split(","))) for v in os.environ.get("VYER", "-1,-1.3,0.75;1.2,1,0.6").split(";")]
NV = len(VIEWS)

names = sorted({f[:-4] for f in os.listdir(SRC) if f.endswith(".glb") and not f.endswith("_tex.glb")})
if ONLY:
    names = [n for n in names if n in ONLY]

scene = bpy.context.scene
scene.render.engine = "BLENDER_WORKBENCH"
scene.display.shading.light = "STUDIO"
scene.display.shading.show_cavity = True
scene.display.shading.cavity_type = "BOTH"
scene.display.shading.show_shadows = True
scene.display.shading.show_object_outline = False
scene.render.resolution_x = TILE
scene.render.resolution_y = TILE
scene.render.film_transparent = False
scene.world = bpy.data.worlds.new("w") if scene.world is None else scene.world
scene.display.shading.background_type = "VIEWPORT"
scene.display.shading.background_color = (0.62, 0.68, 0.74)
cam_data = bpy.data.cameras.new("cam")
cam = bpy.data.objects.new("cam", cam_data)
scene.collection.objects.link(cam)
scene.camera = cam


def clear_models():
    for o in list(bpy.data.objects):
        if o.name != "cam":
            bpy.data.objects.remove(o, do_unlink=True)
    for coll in (bpy.data.meshes, bpy.data.materials, bpy.data.images):
        for b in list(coll):
            if b.users == 0:
                coll.remove(b)


def render(path, direction):
    objs = [o for o in bpy.data.objects if o.type == "MESH"]
    lo = Vector((1e9, 1e9, 1e9))
    hi = Vector((-1e9, -1e9, -1e9))
    for o in objs:
        for c in o.bound_box:
            w = o.matrix_world @ Vector(c)
            lo = Vector(map(min, lo, w))
            hi = Vector(map(max, hi, w))
    centre = (lo + hi) / 2
    radius = max((hi - lo).length / 2, 0.2)
    d = Vector(direction).normalized()
    cam_data.lens = 50
    dist = radius / math.tan(cam_data.angle / 2) * 1.05
    cam.location = centre + d * dist
    cam.rotation_euler = (centre - cam.location).to_track_quat("-Z", "Y").to_euler()
    cam_data.clip_start = dist / 100
    cam_data.clip_end = dist * 4
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


def load(path):
    img = bpy.data.images.load(path)
    px = np.array(img.pixels[:], dtype=np.float32).reshape(img.size[1], img.size[0], 4)
    bpy.data.images.remove(img)
    return px


# Tiny 3x5 bitmap font for the labels (lowercase names, digits, _ and @).
FONT = {
    "a": "010101111101101", "b": "110101110101110", "c": "011100100100011", "d": "110101101101110",
    "e": "111100110100111", "f": "111100110100100", "g": "011100101101011", "h": "101101111101101",
    "i": "111010010010111", "j": "001001001101010", "k": "101101110101101", "l": "100100100100111",
    "m": "101111111101101", "n": "110101101101101", "o": "010101101101010", "p": "110101110100100",
    "q": "010101101110011", "r": "110101110101101", "s": "011100010001110", "t": "111010010010010",
    "u": "101101101101111", "v": "101101101101010", "w": "101101111111101", "x": "101101010101101",
    "y": "101101010010010", "z": "111001010100111", "_": "000000000000111", "0": "111101101101111",
    "1": "010110010010111", "2": "110001010100111", "3": "110001010001110", "4": "101101111001001",
    "5": "111100110001110", "6": "011100111101111", "7": "111001010010010", "8": "111101111101111",
    "9": "111101111001110", "@": "010101111100011", "-": "000000111000000",
}


def label(sheet, text, x0, y0, scale=3):
    for k, ch in enumerate(text.lower()):
        bits = FONT.get(ch)
        if not bits:
            continue
        for r in range(5):
            for c in range(3):
                if bits[r * 3 + c] == "1":
                    x = x0 + (k * 4 + c) * scale
                    y = y0 - r * scale
                    sheet[y - scale + 1:y + 1, x:x + scale, :3] = 0.05


tmp = os.path.join(OUT, "_tmp")
os.makedirs(tmp, exist_ok=True)
per = COLS * ROWS
for start in range(0, len(names), per):
    batch = names[start:start + per]
    rows = (len(batch) + COLS - 1) // COLS
    W, H = COLS * TILE * NV, rows * (TILE + 24)
    sheet = np.ones((H, W, 4), dtype=np.float32)
    for i, name in enumerate(batch):
        clear_models()
        tex = os.path.join(SRC, name + "_tex.glb")
        bpy.ops.import_scene.gltf(filepath=tex if os.path.exists(tex) else os.path.join(SRC, name + ".glb"))
        scene.display.shading.color_type = "TEXTURE" if os.path.exists(tex) else "MATERIAL"
        col, row = i % COLS, i // COLS
        y_top = H - row * (TILE + 24)            # numpy rows run bottom-up like Blender's pixels
        for v, direction in enumerate(VIEWS):
            p = os.path.join(tmp, "%s_%d.png" % (name, v))
            render(p, direction)
            px = load(p)
            x = (col * NV + v) * TILE
            sheet[y_top - 24 - TILE:y_top - 24, x:x + TILE] = px
        label(sheet, name + (" t" if os.path.exists(tex) else ""), col * NV * TILE + 6, y_top - 5)
    img = bpy.data.images.new("ark", W, H, alpha=True)
    img.pixels = sheet.ravel()
    img.filepath_raw = os.path.join(OUT, "ark_%02d.png" % (start // per + 1))
    img.file_format = "PNG"
    img.save()
    bpy.data.images.remove(img)
    print("ark", start // per + 1, batch)
