"""Prepare a model for texture painting in TextureCraft (a test with the tank).

    blender --background --python assets/blender/textur_prov.py -- <in.glb> <out.glb>

Reads the game model (loose named parts), gives every armour face one shared material, "pansar"
(and the tracks and road wheels another, "larvband"),
and unwraps both over all parts into one UV atlas, so TextureCraft paints each as one
texture set. The cyclist in the hatch and the glowing headlights keep their own materials. The
parts keep their names and origins, so the game can still turn the turret and raise the barrel.
"""
import sys

import bpy

args = sys.argv[sys.argv.index("--") + 1:]
SRC, DST = args[0], args[1]
KEEP = {"trika", "flagga_gul", "hud", "hjalm", "svart", "fonster"}   # not armour: left as they are

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
meshes = [o for o in bpy.data.objects if o.type == "MESH"]

pansar = bpy.data.materials.new("pansar")
pansar.use_nodes = True
pansar.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.09, 0.13, 0.05, 1)
band = bpy.data.materials.new("larvband")
band.use_nodes = True
band.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.03, 0.03, 0.03, 1)
TRACK = {"band", "hjul_mork"}            # track runs and road wheels: steel and rubber, not paint

for o in meshes:
    mats = [s.material for s in o.material_slots]
    o.data.materials.append(pansar)
    target = len(o.material_slots) - 1
    o.data.materials.append(band)
    track = len(o.material_slots) - 1
    for poly in o.data.polygons:
        m = mats[poly.material_index] if poly.material_index < len(mats) else None
        name = m.name.split(".")[0] if m else ""
        if name in TRACK or (name == "kamo_svart" and poly.center.z < 0.2):   # the track shoes too
            poly.material_index = track
        elif name not in KEEP:
            poly.material_index = target
    # Drop the slots no face uses any more.
    used = {p.material_index for p in o.data.polygons}
    for idx in reversed(range(len(o.material_slots))):
        if idx not in used:
            o.active_material_index = idx
            bpy.context.view_layer.objects.active = o
            bpy.ops.object.material_slot_remove()

# One atlas over the armour of every part: all parts in edit mode together, armour faces selected.
bpy.ops.object.select_all(action="DESELECT")
for o in meshes:
    o.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="DESELECT")
bpy.ops.object.mode_set(mode="OBJECT")
for o in meshes:
    slots = {i for i, s in enumerate(o.material_slots) if s.material in (pansar, band)}
    for poly in o.data.polygons:
        poly.select = poly.material_index in slots
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.uv.smart_project(angle_limit=1.15, island_margin=0.006, area_weight=0.0, scale_to_bounds=False)
bpy.ops.uv.pack_islands(margin=0.004)
bpy.ops.object.mode_set(mode="OBJECT")

bpy.ops.export_scene.gltf(filepath=DST, export_format="GLB", use_selection=True)
print("förberedd", DST, [(o.name, [s.material.name for s in o.material_slots]) for o in meshes])
