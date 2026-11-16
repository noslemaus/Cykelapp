"""Paint a prepared model in TextureCraft over its control channel and export the colour maps.

    TEXTURECRAFT_NO_PREFS=1 /Applications/TextureCraft.app/Contents/MacOS/TextureCraft --control 7878 &
    python3 assets/texturer/textur_mala.py <model> [<model> ...] [--views <dir>] [--spara]

Reads assets/texturer/<model>/<model>_tc.glb and _tc.json (from assets/blender/textur_prep.py) and
paints every texture set with the recipe the JSON names, around the set's original flat colour, so
the model reads the same from afar and gets painterly detail up close. Writes the colour maps to
assets/texturer/<model>/export/ at the size the JSON gives; assets/blender/textur_bygg.py builds the
game model from them. --spara also saves <model>.tcraft (300+ MB for a house), --views saves three
viewport shots.

Patterns are scaled by the set's metres per UV unit, so boards stay about 18 cm and roof tiles
about 30 cm on every house. Height and normal are left off: the low-poly look comes from the
geometry. Lessons from the first houses:
  - Stripes procedurals came out soft; boards, tiles and sheet seams use our own pattern
    (hus/bradmonster.png, drawn by hus/bradmonster.py), multiplied over the paint.
  - Paint chips are nearly black and white, so a threshold cannot thin them: they are multiplied
    with sparse cloud patches.
  - Hieroglyphs come from egypten/hieroglyfer.png (drawn by egypten/hieroglyfer.py) the same way.
"""
import base64
import json
import os
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from tc import call, cmd  # noqa: E402

K = 1.25            # UV-projection scale per (metres per UV / metres per pattern tile)


def lin2hex(c):
    def s(v):
        v = max(0.0, min(1.0, v))
        v = v * 12.92 if v <= 0.0031308 else 1.055 * v ** (1 / 2.4) - 0.055
        return int(round(v * 255))
    return "#%02x%02x%02x" % tuple(s(v) for v in c)


def mul(c, k):
    return [round(min(1.0, v * k), 4) for v in c]


def lum(c):
    return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]


def flat(layer, keep_rough=True):
    for ch in ("height", "normal", "metallic") + (() if keep_rough else ("roughness",)):
        try:
            cmd("layer.blend", {"layer": layer, "channel": ch, "enabled": False})
        except RuntimeError:
            pass


def fill(name, low, high, procedural="Clouds", pscale=3.0, uv_scale=3.0, rough=0.85, rotation=0, seed=1):
    layer = cmd("layer.add.fill", {"name": name, "roughness": rough})["layer"]
    cmd("layer.fill.set", {"layer": layer, "channel": "baseColor", "procedural": procedural, "scale": pscale,
                           "seed": seed, "low": low, "high": high})
    cmd("layer.fill.projection", {"layer": layer, "projection": "uv", "rotation": rotation,
                                  "scale": max(0.25, uv_scale)})
    flat(layer)
    return layer


def smart(name, color, mask, opacity, rough=0.95):
    layer = cmd("layer.add.fill", {"name": name, "color": color, "roughness": rough})["layer"]
    cmd("mask.smart.apply", {"name": mask, "layer": layer})
    cmd("layer.blend", {"layer": layer, "channel": "all", "opacity": opacity})
    flat(layer)
    return layer


def pattern(name, uv_scale, opacity, image="bradmonster.png", rotation=0):
    """Our tiling pattern multiplied over the colour (boards, tile joints, sheet seams)."""
    layer = cmd("layer.add.fill", {"name": name})["layer"]
    cmd("layer.fill.set", {"layer": layer, "channel": "baseColor", "image": image})
    cmd("layer.fill.projection", {"layer": layer, "projection": "uv", "rotation": rotation, "scale": max(0.25, uv_scale)})
    cmd("layer.blend", {"layer": layer, "channel": "baseColor", "mode": "Multiply", "opacity": opacity})
    flat(layer, keep_rough=False)
    return layer


def patches(layer, f, level, clouds=2.0, inner="Paint chips", inner_scale=6.0, invert=True):
    """A mask of sparse patches: cloud blobs over a threshold, multiplied with a finer pattern."""
    cmd("effect.add.fill", {"layer": layer, "target": "mask", "procedural": "Clouds", "scale": clouds * f, "seed": 5})
    cmd("effect.add.filter", {"layer": layer, "target": "mask", "filter": "threshold", "level": level})
    e = cmd("effect.add.fill", {"layer": layer, "target": "mask", "procedural": inner, "scale": inner_scale * f, "seed": 3})
    cmd("effect.set", {"effect": e["effect"], "blend": "Multiply"})
    if invert:
        cmd("effect.add.filter", {"layer": layer, "target": "mask", "filter": "invert"})


# --- recipes: (colour, metres per UV) ---------------------------------------------------------

def vagg(c, mpu):
    light = lum(c) > 0.3
    f = mpu / 12.6
    fill("Trä", [0.14, 0.12, 0.095], [0.26, 0.22, 0.17], "Wood grain", 3.0, K * mpu / 1.44, rotation=90)
    paint = fill("Färg", mul(c, 0.8), mul(c, 1.24) if not light else mul(c, 1.06), "Clouds", 3.0, mpu / 4.0, rough=0.92)
    cmd("mask.add.white", {"layer": paint})
    patches(paint, f, 0.69 if not light else 0.74)
    pattern("Brädor", K * mpu / 1.44, 0.6 if light else 1.0)
    smart("Smuts nedtill", "#2c2219", "ground_dirt", 0.35 if light else 0.5)


def puts(c, mpu):
    """Lime plaster (the church): a soft cloudy white with faint grunge and dirt along the bottom."""
    fill("Puts", mul(c, 0.88), mul(c, 1.02), "Clouds", 3.0, mpu / 5.0, rough=0.9)
    g = fill("Putsyta", [0.9, 0.9, 0.9], [1.0, 1.0, 1.0], "Grunge", 4.0, mpu / 3.0)
    cmd("layer.blend", {"layer": g, "channel": "baseColor", "mode": "Multiply", "opacity": 0.7})
    flat(g, keep_rough=False)
    smart("Smuts nedtill", "#4a4034", "ground_dirt", 0.4)
    smart("Smuts i hörn", "#5a5246", "dirt_cavities", 0.3)


def sten_kalk(c, mpu):
    """Limestone (pyramids, Sphinx): sun-bleached blocks, darker weathering in the joints, sand on top."""
    fill("Kalksten", mul(c, 0.86), mul(c, 1.08), "Clouds", 3.0, mpu / 6.0, rough=0.9)
    g = fill("Vittring", [0.82, 0.82, 0.82], [1.0, 1.0, 1.0], "Grunge", 4.0, mpu / 4.0)
    cmd("layer.blend", {"layer": g, "channel": "baseColor", "mode": "Multiply", "opacity": 0.8})
    flat(g, keep_rough=False)
    smart("Smuts i fogar", "#6a5236", "dirt_cavities", 0.45)
    smart("Sand", "#e6cfa0", "dust_top", 0.3)


def sandsten(c, mpu):
    """Sandstone (statues, cliffs, temple walls): warm, faintly layered, weathered in the hollows."""
    fill("Sandsten", mul(c, 0.84), mul(c, 1.1), "Clouds", 3.0, mpu / 5.0, rough=0.9)
    lager = fill("Skikt", [0.86, 0.86, 0.86], [1.0, 1.0, 1.0], "Wood grain", 2.0, mpu / 6.0)
    cmd("layer.blend", {"layer": lager, "channel": "baseColor", "mode": "Multiply", "opacity": 0.5})
    flat(lager, keep_rough=False)
    g = fill("Vittring", [0.85, 0.85, 0.85], [1.0, 1.0, 1.0], "Grunge", 4.0, mpu / 3.0)
    cmd("layer.blend", {"layer": g, "channel": "baseColor", "mode": "Multiply", "opacity": 0.7})
    flat(g, keep_rough=False)
    smart("Skuggor", "#5a3a20", "dirt_cavities", 0.45)
    smart("Sand", "#e8cc98", "dust_top", 0.3)


def hieroglyf(c, mpu):
    """Sandstone carved with columns of hieroglyphs (egypten/hieroglyfer.png, 6 m a tile, so a sign is
    about 75 cm: at 2.4 m they shrank to specks in a 2048 px atlas)."""
    sandsten(c, mpu)
    pattern("Hieroglyfer", K * mpu / 6.0, 0.65, image="hieroglyfer.png")


def lertegel(c, mpu):
    """Sun-dried mud brick with darker mortar."""
    fill("Lertegel", mul(c, 0.7), mul(c, 1.05), "Bricks", 8.0, mpu / 1.5, rough=0.95)
    smart("Smuts", "#4a3420", "dirt_cavities", 0.45)
    smart("Damm", "#d6b88a", "dust_top", 0.3)


def fasad(c, mpu):
    """A glass curtain wall (Tokyo's towers): faintly cloudy reflections, mullions every 1.5 m and a
    line at every floor (3.5 m), both from the board pattern."""
    fill("Glas", mul(c, 0.82), mul(c, 1.18), "Clouds", 3.0, mpu / 8.0, rough=0.25)
    pattern("Spröjs", K * mpu / 12.0, 0.45)
    pattern("Våningar", K * mpu / 28.0, 0.35, rotation=90)
    smart("Smuts", "#20242a", "dirt_cavities", 0.25)


def tak_tegel(c, mpu):
    fill("Tegel", mul(c, 0.73), mul(c, 1.09), "Clouds", 4.0, mpu / 6.6, rough=0.8)
    pattern("Pannor", K * mpu / 2.4, 0.55)
    smart("Mossa", "#4f5f22", "moss_top", 0.6)
    smart("Smuts i skarvar", "#2a1a12", "dirt_cavities", 0.5)


def tak_plat(c, mpu):
    f = mpu / 9.06
    fill("Plåt", mul(c, 0.8), mul(c, 1.22), "Clouds", 3.0, mpu / 3.0, rough=0.55)
    pattern("Falsar", K * mpu / 4.4, 0.5)
    rust = cmd("layer.add.fill", {"name": "Rost", "color": "#6a3414", "roughness": 0.85})["layer"]
    cmd("layer.fill.projection", {"layer": rust, "projection": "uv", "scale": 3})
    cmd("mask.add.black", {"layer": rust})
    patches(rust, f, 0.68, clouds=5.0, inner="Grunge", inner_scale=4.0, invert=False)
    cmd("layer.blend", {"layer": rust, "channel": "all", "opacity": 0.5})
    flat(rust)
    smart("Damm", "#8a8a84", "dust_top", 0.2)


def vitt(c, mpu):
    fill("Vit färg", mul(c, 0.89), mul(c, 1.02), "Clouds", 3.0, mpu / 6.0, rough=0.75)
    smart("Smuts i hörn", "#5a5246", "dirt_cavities", 0.45)
    smart("Smuts nedtill", "#4a4034", "ground_dirt", 0.35)


def grund(c, mpu):
    fill("Sten", mul(c, 0.65), mul(c, 1.35), "Cells", 6.0, mpu / 2.6, rough=0.9)
    pattern_free = fill("Stenyta", [0.8, 0.8, 0.8], [1.0, 1.0, 1.0], "Grunge", 4.0, mpu / 2.6)
    cmd("layer.blend", {"layer": pattern_free, "channel": "baseColor", "mode": "Multiply"})
    flat(pattern_free, keep_rough=False)
    smart("Mossa", "#3a4a1a", "moss_top", 0.6)
    smart("Smuts", "#1e1a16", "dirt_cavities", 0.5)


def tra(c, mpu):
    fill("Trä", mul(c, 0.7), mul(c, 1.15), "Wood grain", 3.0, 1.73 * mpu, rotation=90)
    smart("Smuts", "#1c1610", "dirt_cavities", 0.45)


def halm(c, mpu):
    """Thatch (the gassho houses, the tea house): straw in long fibres down the slope, darker courses
    across it, grey weathering, moss and dirt in the hollows."""
    fill("Halm", mul(c, 0.7), mul(c, 1.2), "Clouds", 3.0, mpu / 3.0, rough=0.95)
    fibre = fill("Strå", [0.62, 0.62, 0.62], [1.0, 1.0, 1.0], "Wood grain", 9.0, mpu / 0.5, rotation=0)
    cmd("layer.blend", {"layer": fibre, "channel": "baseColor", "mode": "Multiply", "opacity": 0.85})
    flat(fibre, keep_rough=False)
    pattern("Varv", K * mpu / 1.6, 0.3, rotation=90)
    smart("Vittring", "#7a7266", "dust_top", 0.3)
    smart("Mossa", "#4a5a26", "moss_top", 0.55)
    smart("Smuts", "#2a2014", "dirt_cavities", 0.5)


def skorsten(c, mpu):
    fill("Tegel", [0.36, 0.34, 0.31], mul(c, 1.05), "Bricks", 8.0, mpu / 1.96, rough=0.9)
    smart("Sot och smuts", "#141210", "dirt_cavities", 0.6)


def farg(c, mpu):
    fill("Färg", mul(c, 0.88), mul(c, 1.08), "Clouds", 3.0, mpu / 2.0, rough=0.7)
    smart("Nött", lin2hex(mul([v + 0.04 for v in c], 1.3)), "edge_wear", 0.35)
    smart("Smuts", "#2a241e", "dirt_cavities", 0.35)


def batfarg(c, mpu):
    fill("Färg", mul(c, 0.86), mul(c, 1.06), "Clouds", 3.0, mpu / 2.0, rough=0.55)
    smart("Nött", lin2hex(mul([v + 0.05 for v in c], 1.3)), "edge_wear", 0.35)
    smart("Alger", "#2b3020", "ground_dirt", 0.45)
    smart("Smuts", "#2a241e", "dirt_cavities", 0.3)


def metall(c, mpu):
    fill("Metall", mul(c, 0.8), mul(c, 1.15), "Brushed", 4.0, mpu / 0.5, rough=0.4)
    smart("Smuts", "#1e1c1a", "dirt_cavities", 0.4)


def gummi(c, mpu):
    fill("Gummi", mul(c, 0.9), mul(c, 1.25), "Clouds", 4.0, mpu / 0.6, rough=0.9)
    smart("Damm", "#6a6258", "dust_top", 0.2)


def tyg(c, mpu):
    fill("Tyg", mul(c, 0.92), mul(c, 1.06), "Clouds", 3.0, mpu / 0.8, rough=0.85)
    weave = fill("Väv", [0.88, 0.88, 0.88], [1.0, 1.0, 1.0], "Weave", 8.0, mpu / 0.4)
    cmd("layer.blend", {"layer": weave, "channel": "baseColor", "mode": "Multiply", "opacity": 0.6})
    flat(weave, keep_rough=False)
    smart("Veck", "#000000", "dirt_cavities", 0.3)


def hud(c, mpu):
    fill("Hud", mul(c, 0.93), mul(c, 1.05), "Clouds", 3.0, mpu / 0.5, rough=0.6)
    smart("Skuggor", "#5a3020", "dirt_cavities", 0.2)


def lack(c, mpu):
    fill("Lack", mul(c, 0.95), mul(c, 1.05), "Clouds", 3.0, mpu / 0.6, rough=0.35)
    smart("Nött", lin2hex(mul([v + 0.05 for v in c], 1.4)), "edge_wear", 0.3)
    smart("Smuts", "#1e1c1a", "dirt_cavities", 0.3)


def segel(c, mpu):
    fill("Segelduk", mul(c, 0.9), mul(c, 1.02), "Clouds", 3.0, mpu / 3.0, rough=0.85)
    weave = fill("Väv", [0.9, 0.9, 0.9], [1.0, 1.0, 1.0], "Weave", 8.0, mpu / 0.6)
    cmd("layer.blend", {"layer": weave, "channel": "baseColor", "mode": "Multiply", "opacity": 0.5})
    flat(weave, keep_rough=False)
    smart("Smuts", "#4a4438", "dirt_cavities", 0.2)


def decal(text, position, normal, up, size, color="#ffffff", style="Bold"):
    """Text printed onto the surface: a text image projected from a frame placed at `position`
    (glTF space: x forward, y up, z right of the model) facing along `normal`."""
    name = "text_" + "".join(ch for ch in text.lower() if ch.isalnum())
    made = cmd("resource.text", {"text": text, "style": style, "size": 256, "color": color, "name": name})
    if isinstance(made, dict):
        name = made.get("name", made.get("resource", name))
    cmd("layer.add.decal", {"image": name, "position": position, "normal": normal, "up": up, "size": size,
                            "depth": 0.08, "name": "Tryck " + text})


def cyklist_extras(sets):
    """The cyclist's prints: SVERIGE across the upper back of the jersey (over both the blue and the
    yellow cross, so it reads whole), and the bike's name in white on both sides of the down tube.
    Positions come from the torso and frame in skargarden_modeller.py (Blender x, y, z becomes glTF
    x, z, -y): the back leans along the spine from the hip (-0.12, 0.95) to the shoulder (0.33, 1.27)."""
    back = [0.19, 1.322, 0.0]
    back_normal = [-0.58, 0.815, 0.0]
    spine = [0.815, 0.58, 0.0]
    for set_name in ("tx_trika", "tx_flagga_gul"):
        if set_name in sets:
            cmd("textureSet.select", {"ts": sets[set_name]})
            decal("SVERIGE", back, back_normal, spine, [0.27, 0.06])
    if "tx_ram" in sets:
        cmd("textureSet.select", {"ts": sets["tx_ram"]})
        for side in (-1.0, 1.0):
            decal("SKÄRGÅRD", [0.27, 0.47, 0.035 * side], [0.0, 0.0, side], [-0.551, 0.834, 0.0], [0.22, 0.04])


EXTRAS = {"cyklist": cyklist_extras}


RECIPES = {f.__name__: f for f in (vagg, puts, fasad, sten_kalk, sandsten, hieroglyf, lertegel, tak_tegel, tak_plat, vitt, grund, tra, skorsten, farg, batfarg, metall,
                                   gummi, tyg, hud, lack, segel, halm)}

# --- run -------------------------------------------------------------------------------------

args = sys.argv[1:]
views = args[args.index("--views") + 1] if "--views" in args else None
save = "--spara" in args
models = [a.replace("@", "_") for i, a in enumerate(args) if not a.startswith("--") and (i == 0 or args[i - 1] != "--views")]

for model in models:
    t0 = time.time()
    folder = os.path.join(HERE, model)
    info = json.load(open(os.path.join(folder, model + "_tc.json")))
    cmd("file.open", {"path": os.path.join(folder, model + "_tc.glb")})
    cmd("resource.import", {"path": os.path.join(HERE, "hus", "bradmonster.png")})
    cmd("resource.import", {"path": os.path.join(HERE, "egypten", "hieroglyfer.png")})
    sets = {s["name"]: s["index"] for s in cmd("textureSet.list")}
    plan = {"tx_" + k: v for k, v in info["sets"].items() if "tx_" + k in sets}
    for name, spec in plan.items():
        cmd("textureSet.resolution", {"ts": sets[name], "resolution": spec["res"]})
    cmd("bake.run", {"ts": [sets[n] for n in plan]})
    for name, spec in plan.items():
        cmd("textureSet.select", {"ts": sets[name]})
        RECIPES[spec["recipe"]](spec["color"], spec["m_per_uv"])
    if model in EXTRAS:
        EXTRAS[model](sets)
    if views:
        for i, (yaw, pitch) in enumerate(((-35, 14), (145, 18), (-80, 35))):
            cmd("camera.set", {"yaw": yaw, "pitch": pitch})
            time.sleep(2.0)
            png = call("viewport.screenshot", {"view": "3d"})["png"]
            open(os.path.join(views, f"{model}_vy{i}.png"), "wb").write(base64.b64decode(png))
    out = os.path.join(folder, "export")
    os.makedirs(out, exist_ok=True)
    for name, spec in plan.items():
        cmd("file.exportTextures", {"dir": out, "preset": "glTF PBR Metal Roughness", "ts": sets[name], "format": "png",
                                    "size": spec["res"], "padding": "dilationDefault"})
    if save:
        cmd("file.saveAs", {"path": os.path.join(folder, model + ".tcraft")})
    print(json.dumps({"målad": model, "set": len(plan), "sekunder": round(time.time() - t0)}, ensure_ascii=False))
