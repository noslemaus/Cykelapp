"""Build a textured game model from what TextureCraft exported.

    blender --background --python assets/blender/textur_bygg.py -- <model> [<model> ...]

Reads assets/texturer/<model>/<model>_tc.glb (from textur_prep.py) and the colour maps in
assets/texturer/<model>/export/ (from textur_mala.py), and writes <model>_tex.glb into the world's
model folder the model came from, where the game prefers it over <model>.glb.

Only the colour map goes into the game: the painted roughness barely shows in the game's light, so
each surface kind gets one roughness value. Parts, names and origins are kept (the cyclist's
joints). Windows and other glowing colours keep their flat materials.
"""
import glob
import json
import os
import sys

import bpy

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ROUGH = {"vagg": 0.92, "puts": 0.9, "tak_tegel": 0.8, "tak_plat": 0.6, "vitt": 0.75, "grund": 0.9, "tra": 0.85, "skorsten": 0.9,
         "farg": 0.7, "batfarg": 0.55, "metall": 0.4, "gummi": 0.9, "tyg": 0.85, "hud": 0.6, "lack": 0.35,
         "segel": 0.85, "halm": 0.95, "sten_kalk": 0.9, "sandsten": 0.9, "hieroglyf": 0.9, "lertegel": 0.92, "fasad": 0.25}


def build(model):
    model = model.replace("@", "_")          # name@world (see textur_prep.py)
    folder = os.path.join(ROOT, "assets", "texturer", model)
    info = json.load(open(os.path.join(folder, model + "_tc.json")))
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=os.path.join(folder, model + "_tc.glb"))
    for mat in bpy.data.materials:
        full = mat.name.split(".")[0]
        name = full[3:] if full.startswith("tx_") else full       # the tank test's sets have no prefix
        if name not in info["sets"]:
            continue
        spec = info["sets"][name]
        found = glob.glob(os.path.join(folder, "export", f"*_{full}_BaseColor.png"))
        if not found:   # TextureCraft writes non-ASCII letters as "_" (trä_ljus -> tr__ljus)
            ascii_name = "".join(c if c.isascii() else "_" for c in full)
            found = glob.glob(os.path.join(folder, "export", f"*_{ascii_name}_BaseColor.png"))
        if not found:
            print("saknar färgkarta för", name)
            continue
        img = bpy.data.images.load(found[0])
        img.name = f"{model}_{name}"
        mat.use_nodes = True
        nodes, links = mat.node_tree.nodes, mat.node_tree.links
        nodes.clear()
        out = nodes.new("ShaderNodeOutputMaterial")
        bsdf = nodes.new("ShaderNodeBsdfPrincipled")
        tex = nodes.new("ShaderNodeTexImage")
        tex.image = img
        links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
        links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
        bsdf.inputs["Roughness"].default_value = ROUGH.get(spec["recipe"], 0.85)
        bsdf.inputs["Metallic"].default_value = 0.0
    dst = os.path.join(ROOT, "game", info.get("dir", "world/skargarden/models"), f"{info.get('name', model)}_tex.glb")
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=dst, export_format="GLB", use_selection=True, export_image_format="JPEG",
                              export_jpeg_quality=90)
    print("byggde", os.path.basename(dst), os.path.getsize(dst) // 1024, "kB")


for model in sys.argv[sys.argv.index("--") + 1:]:
    build(model)
