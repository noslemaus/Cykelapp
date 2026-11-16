"""Prepare any game model for painting in TextureCraft.

    blender --background --python assets/blender/textur_prep.py -- <model> [<model> ...]

Reads <model>.glb from a world's model folder (Egypten's first, then Skärgården's) and writes
assets/texturer/<model>/<model>_tc.glb plus <model>_tc.json, which assets/texturer/textur_mala.py
paints from; the JSON remembers the folder, so textur_bygg.py puts <model>_tex.glb back beside it.

Every flat colour of the model becomes a texture set of its own ("tx_<colour>"), so the painter
knows the colour and what the surface is: the RECIPE table says how each colour is painted (falu
red on a building is boards, on a boat it is hull paint). A few colours merge (the darker tile rows
into the roof) and a few become sets of their own by shape: on buildings, the large walls of a
white house (boards, or plaster on the church) apart from its white trim, and the chimney apart from the roof. Glowing,
glass and tiny colours keep their flat material.

UVs: buildings get "up is up" UVs (each face projected along its main axis, walls with V = height),
so boards and tile rows run the right way; other models get Smart UV Project. Each set is packed on
its own, with the other sets hidden and UV sync selection off (packed together, the atlas got so
small that one board was seven pixels). Multi-part models (the cyclist) keep their parts and
origins.
"""
import json
import os
import sys

import bmesh
import bpy

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
MODEL_DIRS = ["world/japan/models", "world/egypten/models", "world/skargarden/models"]   # under game/, in order
BUILDINGS = {"rodstuga", "sjobod", "gulstuga", "vitstuga", "blastuga", "storgard", "gronstuga", "kyrka", "cafe", "lada",
             "uthus", "klockstapel", "barack", "vakttorn",
             # Egypten
             "pyramid_stor", "pyramid_mellan", "pyramid_liten", "pyramid_drottning", "sfinx", "sfinx_liten",
             "obelisk", "pylon", "kolonnad", "staty_farao", "hus_kairo_1", "hus_kairo_2", "hus_kairo_3",
             "hus_kairo_4", "moske", "minaret", "basar_kryddor", "basar_mattor", "basar_lyktor", "basar_krukor",
             "markis", "lejonstaty", "abusimbel", "terrasstempel", "staty_staende", "citadell", "duvtorn", "lerhus",
             # Japan
             "dohyo", "dojo", "machiya_1", "machiya_2", "machiya_3", "neonhus_1", "neonhus_2", "neonhus_3", "pagod3",
             "pagod5", "skyskrapa_1", "skyskrapa_2", "skyskrapa_3", "slott", "stenlykta", "taikobashi", "tempelhall",
             "tokyotorn", "torii", "torii_stor", "viadukt", "yatai", "automat", "elstolpe", "postlada", "jizo",
             "temizuya", "hokora", "busskur", "komainu", "vaderkvarn", "bastu",
             # the bigger Japan
             "ryokan", "gassho", "chaya",
             # the living Japan
             "pachinko", "telefonkiosk", "tempelklocka", "kingyo", "ema",
             # the bigger Egypt
             "faros", "gravport", "memnon", "philae", "hus_nubisk_1", "hus_nubisk_2", "hus_nubisk_3",
             "obelisk_oavslutad", "pelare_pompejus", "teater"}
# On these the sandstone is covered in carved hieroglyphs.
HIEROGLYPH_MODELS = {"pylon", "kolonnad", "obelisk"}
CYCLIST = {"cyklist"}
# Pixels per metre the painted textures aim at (the cyclist is always close to the camera).
DENSITY = {"building": 170, "cyclist": 1200, "other": 180}

# colour -> recipe, per kind of model. Colours not listed (and glowing ones) keep their material.
RECIPE_BUILDING = {
    "falu": "vagg", "gul": "vagg", "bla_gra": "vagg", "ljusgul": "vagg", "ljusgron": "vagg",
    "vit": "vitt", "tegel": "tak_tegel", "tegel_mork": "tak_tegel", "takgra": "tak_plat", "kyrktak": "tak_plat", "grund": "grund", "tra": "tra", "tra_gra": "tra",
    "tra_mork": "tra", "dorr": "farg", "bat_bla": "tyg",
    # the secret base
    "militar_gron": "vagg", "plat_gron": "tak_plat", "betong": "puts", "betong_mork": "puts", "stal": "metall",
    "stal_mork": "metall",
    # Egypten: stone, plaster, mud brick, wood and cloth
    "kalksten": "sten_kalk", "kalksten_mork": "sten_kalk", "kalksten_ljus": "sten_kalk", "sfinx": "sten_kalk",
    "sfinx_mork": "sten_kalk", "sandsten": "sandsten", "sandsten_mork": "sandsten", "klippa_sand": "sandsten",
    "klippa_mork": "sandsten", "obelisk": "sandsten", "hieroglyf": "hieroglyf", "puts_sand": "puts", "puts_rosa": "puts",
    "puts_vit": "puts", "puts_ockra": "puts", "lera": "lertegel", "mashrabiya": "tra", "trä_ljus": "tra",
    "kupol_gron": "farg", "kupol_sand": "farg", "relief_bla": "farg", "relief_rod": "farg", "relief_gron": "farg",
    "relief_gul": "farg", "nemes_bla": "farg", "terrakotta": "farg", "markis_rod": "tyg", "markis_gul": "tyg",
    "markis_gron": "tyg", "markis_bla": "tyg", "markis_vit": "tyg", "matta_rod": "tyg", "matta_bla": "tyg",
    "matta_beige": "tyg", "brons": "metall", "halm": "tra", "kruka": "farg", "skrov_bla": "farg",
    "palmstam_mork": "tra",
    # Japan: lacquered wood, tiled and copper roofs, plaster, stone, paper, glass towers
    "vermiljon": "farg", "vermiljon_mork": "farg", "tak_gron": "tak_plat", "tak_gra": "tak_tegel", "tak_mork": "tak_tegel",
    "vit_puts": "puts", "sten_gra": "grund", "sten_mork": "grund", "tra_morkbrun": "tra", "tra_brun": "tra",
    "papper": "tyg", "glas_bla": "fasad", "glas_mork": "fasad", "torn_rod": "farg", "torn_vit": "farg",
    "dohyo_lera": "puts", "rep": "tyg", "sand_kratt": "puts", "automat_vit": "lack", "post_rod": "lack",
    "segel": "segel", "metall": "metall",
    # the bigger Japan: thatch, the tea house's red cloth, noren
    "halm_tak": "halm", "halm_tak_mork": "halm", "mosen": "tyg", "kimono_bla": "tyg",
    # the living Japan: pachinko hall, phone booth, bell tower, goldfish stall, ema rack
    "pachinko_vagg": "puts", "rustning_svart": "lack", "telefon_gron": "lack", "trafik_gra": "metall",
    "markis_rod_jp": "tyg", "markis_vit_jp": "tyg", "kingyo_bla": "lack", "ema_tra": "tra",
    # the bigger Egypt: marble, granite, quartzite, Nubian paint
    "marmor": "sten_kalk", "marmor_mork": "sten_kalk", "granit": "grund", "granit_rosa": "grund", "granit_mork": "grund",
    "kvartsit": "sandsten", "kvartsit_mork": "sandsten", "nubisk_bla": "puts", "nubisk_gul": "puts", "nubisk_rosa": "puts",
    "nubisk_turkos": "farg", "nubisk_vit": "vitt", "brons_gron": "metall",
}
RECIPE_OTHER = {
    "bat_vit": "batfarg", "bat_bla": "batfarg", "bat_rod": "batfarg", "eka_gron": "batfarg", "farja_gron": "batfarg",
    "kajak": "batfarg", "vit": "farg", "tra": "tra", "tra_mork": "tra", "tra_gra": "tra", "metall": "metall",
    "fyr_rod": "farg", "fyr_vit": "farg", "bil_bla": "lack", "bil_tak": "lack", "nat": "tyg", "nat_brun": "tyg",
    "stang": "tra", "ved": "tra", "ved_ande": "tra", "brevlada": "farg", "grund": "grund", "falu": "farg",
    "gul": "farg", "kork": "farg", "tegel": "farg", "takgra": "tak_plat",
    # the secret base and the monsters
    "kamo_gron": "farg", "kamo_mork": "farg", "kamo_brun": "farg", "kamo_svart": "farg", "militar_gron": "farg",
    "plat_gron": "tak_plat", "band": "gummi", "hjul_mork": "gummi", "betong": "puts", "betong_mork": "puts",
    "stal": "metall", "stal_mork": "metall", "varning_gul": "farg", "sand": "tyg", "sand_mork": "tyg",
    "radar_vit": "farg", "ufo_metall": "metall", "ufo_mork": "metall", "zombie_hud": "hud", "zombie_skjorta": "tyg",
    "zombie_byxor": "tyg", "zombie_har": "tyg", "alien_hud": "hud", "alien_drakt": "tyg", "pysare": "hud",
    "pysare_ljus": "hud", "pysare_mork": "hud",
    # Egypten
    "kamel": "hud", "kamel_mork": "hud", "sadel_rod": "tyg", "felucca": "segel", "skrov_bla": "batfarg",
    "talt_svart": "tyg", "talt_vit": "tyg", "bil_vit": "lack", "bil_smuts": "lack", "vapen": "metall",
    "metall_mork": "metall", "linne": "tyg", "linne_mork": "tyg", "skarabe": "lack", "skarabe_ljus": "lack",
    "nemes_bla": "farg", "kalksten": "sten_kalk", "kalksten_mork": "sten_kalk", "sandsten": "sandsten",
    "sandsten_mork": "sandsten", "brons": "metall", "trä_ljus": "tra", "ballong_rod": "tyg", "ballong_gul": "tyg",
    "ballong_bla": "tyg", "ballong_gron": "tyg", "korg": "tra", "asna": "hud", "asna_ljus": "hud", "sack": "tyg",
    "kruka": "farg", "halm": "tra",
    # Japan
    "vermiljon": "farg", "vermiljon_mork": "farg", "tra_morkbrun": "tra", "tra_brun": "tra", "papper": "tyg",
    "hud_jp": "hud", "kimono_rod": "tyg", "kimono_bla": "tyg", "kimono_lila": "tyg", "obi_guld": "tyg", "vit_smink": "hud",
    "har_svart": "tyg", "mawashi": "tyg", "rustning_rod": "lack", "rustning_svart": "lack", "oni_rod": "hud",
    "oni_bla": "hud", "tiger": "tyg", "ninja_svart": "tyg", "ninja_bla": "tyg", "kitsune_vit": "hud", "drake_rod": "lack",
    "drake_gron": "lack", "drake_guld": "lack", "shinkansen_vit": "lack", "shinkansen_bla": "lack", "sten_gra": "grund",
    "sten_mork": "grund", "torn_rod": "farg", "torn_vit": "farg", "automat_vit": "lack", "rep": "tyg", "tofs_bla": "tyg",
    "tofs_rod": "tyg", "tofs_vit": "tyg", "tofs_svart": "tyg", "dohyo_lera": "puts", "tak_gra": "tak_plat",
    "kostym": "tyg", "skoluniform": "tyg", "kjol_bla": "tyg", "bil_vit_jp": "lack", "bil_bla_jp": "lack", "kraka": "tyg",
    "koi_ora": "hud", "koi_vit": "hud", "batskrov": "batfarg", "post_rod": "lack",
    "tanuki_brun": "lack", "tanuki_ljus": "lack", "munk_ora": "tyg", "halm_jp": "tra", "hager_vit": "tyg",
    "hager_gul": "lack", "vimpel_bla": "tyg", "vimpel_rod": "tyg", "vimpel_svart": "tyg", "turist_rod": "tyg",
    "bambu": "tra", "bambu_mork": "tra", "bambu_ljus": "tra",
    "falg": "metall", "svart": "gummi", "dack": "gummi", "sadel": "gummi", "segel": "segel", "jacka": "tyg",
    "livboj": "farg", "trika": "tyg", "trika_vit": "tyg", "byxor": "tyg", "flagga_gul": "tyg", "hud": "hud",
    "hjalm": "lack", "sko": "lack", "ram": "lack",
    # the bigger Japan and the teleport gates
    "skrov_vit": "batfarg", "hjul_vit": "lack", "mosen": "tyg", "tak_mork": "tak_plat", "relief_bla": "farg",
    "relief_gul": "farg",
    # Skärgården's animals, marks, poles and signs
    "ko_rod": "hud", "ko_svart": "hud", "ko_vit": "hud", "ko_horn": "lack", "ull": "tyg", "mas_vit": "tyg",
    "mas_gra": "tyg", "ejder_vit": "tyg", "ejder_svart": "tyg", "ejder_brun": "tyg", "kummel": "puts",
    "prick_rod": "farg", "prick_gron": "farg", "flagga_bla": "tyg", "tvatt_bla": "tyg", "tvatt_gul": "tyg",
    "tvatt_rod": "tyg", "skylt_vit": "lack", "skylt_rod": "lack", "skylt_svart": "lack", "stolpe": "metall",
    "flyttblock": "grund",
    # the living Japan: people, animals, vehicles and the festival
    "miko_rod": "tyg", "randoseru": "lack", "hatt_gul": "tyg", "happi_bla": "tyg", "happi_rod": "tyg",
    "yukata_bla": "tyg", "yukata_rosa": "tyg", "kasuri": "tyg", "taxi_gul": "lack", "gronsak": "farg",
    "apelsin": "farg", "svan_vit": "lack", "nab_gul": "lack", "hjort_brun": "hud", "hjort_ljus": "hud",
    "trana_vit": "tyg", "trana_svart": "tyg", "trana_rod": "hud", "katt_vit": "hud", "katt_ora": "hud",
    "katt_svart": "hud", "apa_fall": "tyg", "apa_ansikte": "hud", "shiba": "hud", "shiba_ljus": "hud",
    "telefon_gron": "lack", "ema_tra": "tra", "nobori_rod": "tyg", "nobori_bla": "tyg", "nobori_gul": "tyg",
    "nobori_vit": "tyg", "markis_rod_jp": "tyg", "markis_vit_jp": "tyg", "kingyo_bla": "lack", "trafik_gra": "metall",
    "guld": "lack", "rustning_svart": "lack", "pachinko_vagg": "puts", "rep": "tyg",
    # Egypt's people, animals and traffic
    "hud_eg": "hud", "hud_ljus": "hud", "galabeya_vit": "tyg", "galabeya_bla": "tyg", "galabeya_gra": "tyg",
    "galabeya_brun": "tyg", "sloja_svart": "tyg", "sloja_rod": "tyg", "khaki": "tyg", "turist_skjorta": "tyg",
    "turist_shorts": "tyg", "keps_bla": "tyg", "shorts_svart": "tyg", "trikot_rod": "tyg", "trikot_bla": "tyg",
    "taxi_svart": "lack", "taxi_vit": "lack", "tuktuk_rod": "lack", "tuktuk_bla": "tyg", "get_svart": "hud",
    "get_brun": "hud", "get_vit": "hud", "ibis_vit": "tyg", "ibis_svart": "tyg", "katt_gra": "hud",
    "buffel": "hud", "horn": "lack", "pram_skrov": "metall", "rost": "metall", "sockerror": "tra", "kryss_vit": "batfarg",
    "kryss_bla": "batfarg", "parabol_vit": "lack", "markis_rod": "tyg", "markis_gul": "tyg", "markis_gron": "tyg",
    "markis_bla": "tyg", "markis_vit": "tyg", "matta_rod": "tyg", "matta_bla": "tyg", "matta_beige": "tyg",
    "puts_sand": "puts", "puts_ockra": "puts", "terrakotta": "farg", "nat_bla": "tyg", "melon": "farg",
    # Skärgården's summer life
    "hud_sol": "hud", "klanning_vit": "tyg", "klanning_bla": "tyg", "klanning_rod": "tyg", "jeans": "tyg",
    "shorts_kaki": "tyg", "folkdrakt_rod": "tyg", "folkdrakt_gul": "tyg", "vast_svart": "tyg", "krans_gron": "tyg",
    "flytvast": "tyg", "handduk_rod": "tyg", "handduk_bla": "tyg", "sal_gra": "hud", "sal_mork": "hud",
    "nabb_ora": "lack", "hast_brun": "hud", "man_svart": "tyg", "rad_brun": "hud", "rumpa_vit": "hud", "talt_gron": "tyg",
    "talt_ora": "tyg", "motorbat_vit": "batfarg", "traktor_rod": "lack", "traktor_gra": "lack", "hund_guld": "hud",
    "hangmatta": "tyg", "keps_rod": "tyg", "trojan_gron": "tyg", "trojan_gul": "tyg", "segel_vit": "segel",
    "jolle_vit": "batfarg",
}
MERGE = {"tegel_mork": "tegel"}       # building colours folded into another set
# The sheet roofs' standing seams (takgra_ljus) keep their flat colour: hundreds of thin ribs became
# hundreds of UV islands, and the margins between them left the roof a few pixels per metre.


def colour_of(mat):
    try:
        c = mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value
        return [round(c[0], 4), round(c[1], 4), round(c[2], 4)]
    except (AttributeError, KeyError):
        return [0.5, 0.5, 0.5]


def glowing(mat):
    try:
        return mat.node_tree.nodes["Principled BSDF"].inputs["Emission Strength"].default_value > 0.0 and \
            max(mat.node_tree.nodes["Principled BSDF"].inputs["Emission Color"].default_value[:3]) > 0.0
    except (AttributeError, KeyError):
        return False


def islands(bm, faces):
    """Groups of linked faces among `faces`."""
    left, groups = set(faces), []
    while left:
        stack, group = [left.pop()], []
        while stack:
            f = stack.pop()
            group.append(f)
            for e in f.edges:
                for g in e.link_faces:
                    if g in left:
                        left.remove(g)
                        stack.append(g)
        groups.append(group)
    return groups


def prepare(model):
    # "name@world" picks one world's model where two share a name (teleportport@egypten); its files
    # under assets/texturer are then called name_world.
    src_name, _, world = model.partition("@")
    key = model.replace("@", "_")
    kind = "building" if src_name in BUILDINGS else "cyclist" if src_name in CYCLIST else "other"
    recipe_of = RECIPE_BUILDING if kind == "building" else RECIPE_OTHER
    folder = f"world/{world}/models" if world else \
        next(d for d in MODEL_DIRS if os.path.exists(os.path.join(ROOT, "game", d, src_name + ".glb")))
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=os.path.join(ROOT, "game", folder, src_name + ".glb"))
    model = key
    meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    total_area = sum(p.area for o in meshes for p in o.data.polygons)

    # Which set each face goes to: by colour, then by shape.
    sets = {}                    # set name -> {"recipe", "color"}
    tx = {}                      # set name -> material

    def set_material(name, recipe, color):
        if name not in tx:
            m = bpy.data.materials.new("tx_" + name)
            m.use_nodes = True
            tx[name] = m
            sets[name] = {"recipe": recipe, "color": color}
        return tx[name]

    area_by_colour = {}
    for o in meshes:
        for p in o.data.polygons:
            if p.material_index < len(o.material_slots) and o.material_slots[p.material_index].material:
                n = o.material_slots[p.material_index].material.name.split(".")[0]
                area_by_colour[n] = area_by_colour.get(n, 0.0) + p.area

    for o in meshes:
        old = [s.material for s in o.material_slots]
        cols = {m.name.split(".")[0]: colour_of(m) for m in old if m}     # colour name -> linear RGB
        bm = bmesh.new()
        bm.from_mesh(o.data)
        bm.faces.ensure_lookup_table()
        target = {}
        by_colour = {}
        for f in bm.faces:
            m = old[f.material_index] if f.material_index < len(old) else None
            if not m or glowing(m):
                continue
            name = m.name.split(".")[0]
            if name not in recipe_of or area_by_colour.get(name, 0.0) < total_area * 0.004:
                continue
            by_colour.setdefault(name, []).append(f)
        for name, faces in by_colour.items():
            base = MERGE.get(name, name) if kind == "building" else name
            base_col = cols.get(base, cols[name])
            for group in islands(bm, faces):
                xs = [v.co.x for f in group for v in f.verts]
                ys = [v.co.y for f in group for v in f.verts]
                zs = [v.co.z for f in group for v in f.verts]
                small_column = max(xs) - min(xs) < 0.9 and max(ys) - min(ys) < 0.9 and max(zs) - min(zs) > 0.6
                for f in group:
                    if kind == "building" and name == "tegel_mork" and small_column:
                        set_name, recipe, col = "skorsten", "skorsten", cols[name]
                    elif kind == "building" and name == "vit" and abs(f.normal.z) < 0.3 and f.calc_area() > 3.0:
                        # A white church is plastered; a white house has boards.
                        set_name, recipe, col = "vit_vagg", "puts" if model == "kyrka" else "vagg", base_col
                    else:
                        set_name, recipe, col = base, recipe_of.get(base, recipe_of[name]), base_col
                        if model in HIEROGLYPH_MODELS and recipe == "sandsten":
                            recipe = "hieroglyf"
                    target[f.index] = set_material(set_name, recipe, col)
        # Append the new materials to this object and assign.
        for m in tx.values():
            if m.name not in [s.material.name for s in o.material_slots if s.material]:
                o.data.materials.append(m)
        slot_of = {s.material.name: i for i, s in enumerate(o.material_slots) if s.material}
        for f in bm.faces:
            if f.index in target:
                f.material_index = slot_of[target[f.index].name]
        # Up-is-up UVs for buildings.
        if kind == "building":
            uv = bm.loops.layers.uv.active or bm.loops.layers.uv.new()
            for f in bm.faces:
                if f.index not in target:
                    continue
                n = f.normal
                ax = max(range(3), key=lambda k: abs(n[k]))
                for loop in f.loops:
                    p = loop.vert.co
                    if ax == 1:
                        loop[uv].uv = (p.x * (1 if n.y < 0 else -1), p.z)
                    elif ax == 0:
                        loop[uv].uv = (p.y * (1 if n.x > 0 else -1), p.z)
                    else:
                        loop[uv].uv = (p.x, p.y * (1 if n.z > 0 else -1))
        bm.to_mesh(o.data)
        bm.free()
        # Drop slots no face uses any more.
        bpy.context.view_layer.objects.active = o
        used = {p.material_index for p in o.data.polygons}
        for idx in reversed(range(len(o.material_slots))):
            if idx not in used:
                o.active_material_index = idx
                bpy.ops.object.material_slot_remove()

    # Unwrap (non-buildings) and pack each set on its own, over all parts at once.
    bpy.context.scene.tool_settings.use_uv_select_sync = False
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    for name, m in tx.items():
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="DESELECT")      # clears vertex and edge flags too
        bpy.ops.object.mode_set(mode="OBJECT")
        for o in meshes:
            for p in o.data.polygons:
                p.select = o.material_slots[p.material_index].material == m if p.material_index < len(o.material_slots) else False
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.hide(unselected=True)
        bpy.ops.mesh.select_all(action="SELECT")
        if kind != "building":
            bpy.ops.uv.smart_project(angle_limit=1.15, island_margin=0.01, area_weight=0.0, scale_to_bounds=False)
        bpy.ops.uv.select_all(action="SELECT")
        bpy.ops.uv.pack_islands(rotate=kind != "building", margin=0.008)
        bpy.ops.mesh.reveal(select=False)
    bpy.ops.object.mode_set(mode="OBJECT")

    # Metres per UV unit of each set (the painter scales its patterns by it) and a texture size.
    for name, m in tx.items():
        ratios = []
        for o in meshes:
            me = o.data
            uvl = me.uv_layers.active.data
            mw = o.matrix_world
            for p in me.polygons:
                if p.material_index >= len(o.material_slots) or o.material_slots[p.material_index].material != m:
                    continue
                li = list(p.loop_indices)
                for a, b in zip(li, li[1:] + li[:1]):
                    d3 = (mw @ me.vertices[me.loops[a].vertex_index].co - mw @ me.vertices[me.loops[b].vertex_index].co).length
                    d2 = (uvl[a].uv - uvl[b].uv).length
                    if d3 > 0.005 and d2 > 1e-6:
                        ratios.append(d3 / d2)
        mpu = sorted(ratios)[len(ratios) // 2] if ratios else 1.0
        px = mpu * DENSITY[kind]
        res = 256
        while res < px and res < 2048:
            res *= 2
        sets[name].update({"m_per_uv": round(mpu, 3), "res": res})

    out_dir = os.path.join(ROOT, "assets", "texturer", model)
    os.makedirs(out_dir, exist_ok=True)
    for o in meshes:
        o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=os.path.join(out_dir, model + "_tc.glb"), export_format="GLB", use_selection=True)
    info = {"model": model, "name": src_name, "kind": kind, "dir": folder, "sets": sets, "parts": [o.name for o in meshes]}
    json.dump(info, open(os.path.join(out_dir, model + "_tc.json"), "w"), indent=1, ensure_ascii=False)
    print("förberedd", model, {k: (v["recipe"], v["res"], v["m_per_uv"]) for k, v in sets.items()})


for model in sys.argv[sys.argv.index("--") + 1:]:
    prepare(model)
