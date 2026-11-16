"""Paint the tank in TextureCraft through its control channel (a test of TextureCraft).

1. blender --background --python assets/blender/textur_prov.py -- game/world/skargarden/models/stridsvagn.glb assets/texturer/stridsvagn/stridsvagn_tc.glb
2. /Applications/TextureCraft.app/Contents/MacOS/TextureCraft assets/texturer/stridsvagn/stridsvagn_tc.glb --control 7878
3. python3 assets/texturer/stridsvagn/bygg_textur.py
4. Export: file.exportTextures (glTF PBR Metal Roughness) to export/, copied into game/world/skargarden/texturprov/.

Armour: the smart material Military Paint, two camouflage colours (clouds noise sharpened with a
histogram scan, the worn edges kept showing through) and mud thrown up from the ground. Tracks:
dark matte steel worn bright on the sharp edges, dirt in the gaps, mud from the ground.
"""
import os, sys, json, base64, time
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from tc import call, cmd
N = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.abspath(__file__))

def shot(name):
    time.sleep(0.8)
    s = call("viewport.screenshot", {"view": "3d"})
    open(f"{N}/{name}.png", "wb").write(base64.b64decode(s["png"]))

def find(layers, name):
    for l in layers:
        if l["name"] == name:
            return l["id"]
        hit = find(l.get("children", []), name)
        if hit is not None:
            return hit

cmd("file.open", {"path": f"{ROOT}/stridsvagn_tc.glb"})
sets = {s["name"]: s["index"] for s in cmd("textureSet.list")}
print("set:", sets)
P, B = sets["pansar"], sets["larvband"]
print("bake:", cmd("bake.run", {"ts": [P, B]}))

# --- Armour: military paint, two-colour camouflage under the wear, mud thrown up from the ground.
cmd("textureSet.select", {"ts": P})
cmd("material.apply", {"material": "military_paint"})
olive = find(call("session.inspect")["layers"], "Olive drab")
for name, colour, seed, pos in (("Kamo mörkgrön", "#2c3824", 4, 0.5), ("Kamo brun", "#57452d", 11, 0.62)):
    cmd("layer.select", {"layer": olive})
    lid = cmd("layer.add.fill", {"name": name, "color": colour, "roughness": 0.75})["layer"]
    cmd("mask.add.black", {"layer": lid})
    cmd("effect.add.fill", {"layer": lid, "target": "mask", "procedural": "Clouds", "scale": 4.0, "seed": seed})
    cmd("effect.add.filter", {"layer": lid, "target": "mask", "filter": "histogramScan", "position": pos, "contrast": 1.0})
    wear = cmd("effect.add.generator", {"layer": lid, "generator": "edgeWear", "invert": True, "level": 0.35})
    wear_id = wear.get("effect") if isinstance(wear, dict) else wear
    if wear_id is not None:
        cmd("effect.set", {"effect": wear_id, "blend": "Multiply"})
    olive = lid
group = find(call("session.inspect")["layers"], "Military Paint")
cmd("layer.select", {"layer": group})
mud = cmd("layer.add.fill", {"name": "Lera", "color": "#4a3b29", "roughness": 0.95})["layer"]
cmd("mask.smart.apply", {"name": "ground_dirt", "layer": mud})
shot("tc_pansar")

# --- Tracks and road wheels: dark steel worn bright on the edges, mud and dirt in the gaps.
cmd("textureSet.select", {"ts": B})
base = cmd("layer.add.fill", {"name": "Band", "color": "#2a2b29", "metallic": 0.0, "roughness": 0.8})["layer"]
bright = cmd("layer.add.fill", {"name": "Blanknött", "color": "#8d9298", "metallic": 1.0, "roughness": 0.4})["layer"]
cmd("mask.smart.apply", {"name": "edges_sharp", "layer": bright})
dirt = cmd("layer.add.fill", {"name": "Smuts", "color": "#2a241c", "roughness": 0.95})["layer"]
cmd("mask.smart.apply", {"name": "dirt_cavities", "layer": dirt})
mud2 = cmd("layer.add.fill", {"name": "Lera", "color": "#4a3b29", "roughness": 0.95})["layer"]
cmd("mask.smart.apply", {"name": "ground_dirt", "layer": mud2})
cmd("textureSet.select", {"ts": P})
shot("tc_klar")
print("lager:", json.dumps([(l["id"], l["name"]) for l in call("session.inspect")["layers"]], ensure_ascii=False))
