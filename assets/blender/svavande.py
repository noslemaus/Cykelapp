"""Find parts that float: mesh islands that touch neither the ground nor, through a chain of touching
parts, anything that does.

    blender --background --python assets/blender/svavande.py -- <models folder> [name,name,…]

Prints one line per model with floating parts: the material, size and position of each loose island.
Two islands count as touching when a corner of one lies within 3 cm of the other's surface, or they cross.
"""
import os
import sys

import bmesh
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

argv = sys.argv[sys.argv.index("--") + 1:]
SRC = argv[0]
ONLY = set(argv[1].split(",")) if len(argv) > 1 and argv[1] else set()
GAP = 0.03

names = sorted({f[:-4] for f in os.listdir(SRC) if f.endswith(".glb") and not f.endswith("_tex.glb")})
if ONLY:
    names = [n for n in names if n in ONLY]


def islands(obj):
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.transform(obj.matrix_world)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0005)   # flat shading splits every face apart
    bm.faces.ensure_lookup_table()
    seen = set()
    out = []
    for f in bm.faces:
        if f.index in seen:
            continue
        stack = [f]
        group = []
        seen.add(f.index)
        while stack:
            g = stack.pop()
            group.append(g)
            for e in g.edges:
                for h in e.link_faces:
                    if h.index not in seen:
                        seen.add(h.index)
                        stack.append(h)
        verts = {v for g in group for v in g.verts}
        idx = {v: i for i, v in enumerate(verts)}
        co = [v.co.copy() for v in verts]
        polys = [[idx[v] for v in g.verts] for g in group]
        mats = {g.material_index for g in group}
        mat = obj.material_slots[min(mats)].name if obj.material_slots else "?"
        lo = Vector((min(c.x for c in co), min(c.y for c in co), min(c.z for c in co)))
        hi = Vector((max(c.x for c in co), max(c.y for c in co), max(c.z for c in co)))
        out.append({"tree": BVHTree.FromPolygons(co, polys), "co": co, "lo": lo, "hi": hi, "mat": mat})
    bm.free()
    return out


def touching(a, b):
    """True when a corner of one lies within GAP of the other's surface, or the two cross."""
    for p, q in ((a, b), (b, a)):
        for c in p["co"]:
            if all(q["lo"][k] - GAP <= c[k] <= q["hi"][k] + GAP for k in range(3)):
                hit = q["tree"].find_nearest(c, GAP)
                if hit[0] is not None:
                    return True
    return bool(a["tree"].overlap(b["tree"]))


for name in names:
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    bpy.ops.import_scene.gltf(filepath=os.path.join(SRC, name + ".glb"))
    parts = []
    for o in bpy.data.objects:
        if o.type == "MESH":
            parts += islands(o)
    if not parts:
        continue
    floor = min(p["lo"].z for p in parts)
    n = len(parts)
    linked = [[] for _ in range(n)]
    for i in range(n):
        for j in range(i + 1, n):
            a, b = parts[i], parts[j]
            if any(a["lo"][k] > b["hi"][k] + GAP or b["lo"][k] > a["hi"][k] + GAP for k in range(3)):
                continue
            if touching(a, b):
                linked[i].append(j)
                linked[j].append(i)
    grounded = set(i for i in range(n) if parts[i]["lo"].z - floor < 0.05)
    stack = list(grounded)
    while stack:
        i = stack.pop()
        for j in linked[i]:
            if j not in grounded:
                grounded.add(j)
                stack.append(j)
    loose = [parts[i] for i in range(n) if i not in grounded]
    if loose:
        desc = ", ".join("%s %.2fx%.2fx%.2f @ (%.1f,%.1f,%.1f)" % (p["mat"], *(p["hi"] - p["lo"]), *((p["lo"] + p["hi"]) / 2))
                         for p in loose[:6])
        print("SVÄVAR %s: %d av %d delar: %s%s" % (name, len(loose), n, desc, " …" if len(loose) > 6 else ""))
print("KLART", len(names), "modeller")
