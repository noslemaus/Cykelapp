extends "res://world/skargarden/skargarden.gd"
## Egypten, the second world. It runs on the same engine as Skärgården (road, terrain tiles, free
## riding, the battle) and replaces what makes the place: the ground, the route, the light, the
## buildings, the plants and the battle's cast.
##
## The Nile runs north–south through the middle with palm jungle on both banks and patchwork fields
## beyond. West of it the desert climbs to the Giza plateau with the three pyramids, the queens'
## pyramids and the Sphinx in its pit; the dig camp (with the pickup) lies behind the pyramids. East
## of the river is Cairo: a bazaar lane with stalls and awnings, flat-roofed houses, a mosque with
## minarets. To the south the oasis with Bedouin tents and camels, and a temple with an avenue of
## sphinxes, a pylon gate the road passes through, obelisks, colossi and columns. Two bridges cross
## the Nile; a small stone bridge over a canal by the corniche carries the teleport gate. North of
## Cairo the land meets the Mediterranean, with a citadel on a promontory; south-west the road runs
## below an escarpment with two cliff temples, Abu Simbel's small temple and a terrace temple, and
## hot-air balloons drift overhead. Feluccas sail the Nile and a camel caravan rounds the desert.
##
## The bigger Egypt (lap 12 km): east of Cairo the road runs out to Alexandria, with Pompey's Pillar,
## the Roman theatre and the lighthouse of Pharos on its headland, and back along the corniche. West
## of the oasis it loops through the White Desert's chalk mushrooms. After the cliff temples it turns
## south along the Theban hills past the Colossi of Memnon, through the Valley of the Kings' canyon
## with its tombs, and crosses the Nile at the first cataract by Aswan, where Philae's temple stands
## on its island. On the east bank: a Nubian village, the quarry with the unfinished obelisk, and the
## way home north along the river to the temple. Gravel tracks cut across the White Desert, the
## corniche and the east bank. Coordinates: x east, z south (metres).

const EG_MODELS := "res://world/egypten/models/"
const SAND_SHADER := preload("res://world/egypten/sand.gdshader")
const EG_SKY := preload("res://world/sky.gdshader")

## The lap, starting in the bazaar going north, out to Alexandria and the lighthouse and back
## along the corniche past the citadel, over the Nile, past the Sphinx, between the pyramids, round
## the dig camp, down to the oasis, round the White Desert, past the cliff temples, south through
## the Valley of the Kings, over the Nile at Aswan, north through Nubia and the temple and home
## through Cairo.
const EG_ROAD := [
    Vector2(620, -150), Vector2(618, -260), Vector2(640, -360), Vector2(760, -432), Vector2(900, -445),
    Vector2(1060, -440), Vector2(1220, -450), Vector2(1360, -490), Vector2(1470, -545), Vector2(1525, -600),
    Vector2(1515, -680), Vector2(1450, -712), Vector2(1388, -662), Vector2(1335, -570), Vector2(1200, -562),
    Vector2(1060, -560), Vector2(960, -552), Vector2(880, -535),
    Vector2(770, -566), Vector2(565, -535), Vector2(450, -505), Vector2(370, -475), Vector2(110, -462),
    Vector2(30, -440), Vector2(-40, -400), Vector2(-100, -322), Vector2(-108, -240), Vector2(-185, -142),
    Vector2(-330, -128), Vector2(-460, -124), Vector2(-605, -90), Vector2(-645, 40), Vector2(-585, 152),
    Vector2(-450, 152), Vector2(-330, 127), Vector2(-205, 106), Vector2(-110, 190), Vector2(-150, 330),
    Vector2(-300, 300), Vector2(-500, 290), Vector2(-660, 350), Vector2(-720, 450), Vector2(-840, 500),
    Vector2(-980, 470), Vector2(-1120, 510), Vector2(-1210, 620), Vector2(-1220, 760), Vector2(-1130, 870),
    Vector2(-980, 900), Vector2(-850, 830), Vector2(-760, 720), Vector2(-600, 630),
    Vector2(-380, 642), Vector2(-150, 600), Vector2(-90, 690), Vector2(-60, 820), Vector2(-40, 940),
    Vector2(-70, 1040), Vector2(-150, 1100), Vector2(-260, 1120), Vector2(-360, 1090), Vector2(-450, 1140),
    Vector2(-490, 1250), Vector2(-430, 1350), Vector2(-290, 1410), Vector2(-100, 1420), Vector2(60, 1405),
    Vector2(440, 1400), Vector2(560, 1370), Vector2(700, 1320), Vector2(830, 1220), Vector2(880, 1100),
    Vector2(980, 1010), Vector2(930, 900), Vector2(790, 885), Vector2(620, 860), Vector2(480, 760), Vector2(400, 620), Vector2(390, 520),
    Vector2(425, 462), Vector2(480, 452), Vector2(585, 455), Vector2(700, 452), Vector2(840, 520), Vector2(990, 450),
    Vector2(1010, 300), Vector2(900, 190), Vector2(782, 92), Vector2(682, 2), Vector2(632, -58),
]
const NILE_HALF := 65.0
## [model, centre, base width]
const PYRAMIDS := [["pyramid_stor", Vector2(-430, -255), 200.0], ["pyramid_mellan", Vector2(-310, -10), 180.0],
    ["pyramid_liten", Vector2(-190, 225), 100.0]]
const QUEENS := [Vector2(-298, -315), Vector2(-298, -262), Vector2(-298, -209)]
const SPHINX := Vector2(-165, -280)
const CAMP := Vector2(-572, -38)
const OASIS := Vector2(-610, 470)
const CANAL_Z := -420.0
const CANAL_END := 430.0
const TELEPORT := Vector2(360, -420)
const BAZAAR := [Vector2(620, -150), Vector2(640, -360)]
const TEMPLE := Vector2(585, 455)
## The Mediterranean: water north of COAST_Z, the citadel on its promontory.
const COAST_Z := -575.0
const CITADEL := Vector2(830, -600)
## The cliff temples, cut into the escarpment south of the road; their court is levelled in front.
const ABU := Vector2(-520, 700)
const TERRACE := Vector2(-300, 705)
## The camel caravan's round (centre and radii) and where the balloons drift.
const CARAVAN := Vector2(-500, 70)
const CARAVAN_R := Vector2(60.0, 40.0)
const BALLOONS := Vector2(-330, 560)
## Alexandria: the lighthouse on its headland, Pompey's Pillar and the Roman theatre.
const FAROS := Vector2(1460, -640)
const PILLAR := Vector2(1180, -505)
const THEATRE := Vector2(1240, -385)
## The White Desert's chalk plain (centre, radius) and the Bedouin camp in it.
const WHITE := Vector2(-1010, 680)
const WHITE_R := 330.0
const BEDOUIN := Vector2(-1040, 700)
## The Theban hills end at THEBES_END; the Valley of the Kings winds through them along VALLEY.
const THEBES_END := 1270.0
const VALLEY := [Vector2(-150, 1100), Vector2(-260, 1120), Vector2(-360, 1090), Vector2(-450, 1140), Vector2(-490, 1250),
    Vector2(-430, 1350)]
const MEMNON := [Vector2(-88, 922), Vector2(-88, 952)]
## Aswan: the cataract lake (centre, radii) with Philae's island and granite islets [x, z, r], the
## quarry with the unfinished obelisk, the Nubian village and the riverside temple of Kom Ombo.
const CATARACT := Vector2(240, 1250)
const CATARACT_R := Vector2(165.0, 105.0)
const PHILAE := Vector2(275, 1232)
const ISLETS := [[150.0, 1190.0, 14.0], [335.0, 1305.0, 12.0], [185.0, 1312.0, 10.0], [350.0, 1180.0, 11.0], [118.0, 1262.0, 9.0]]
const QUARRY := Vector2(912, 1250)
const NUBIA := Vector2(600, 1360)
const KOM_OMBO := Vector2(510, 1040)
const ECOL := {
    "sand": Color("e2bd85"), "sand_ljus": Color("edd09b"), "sand_mork": Color("c99d62"), "kalk": Color("dcc9a2"),
    "kalk_mork": Color("c7b085"), "gron": Color("7a9a3e"), "gron_mork": Color("5d7f30"), "djungel": Color("4f7432"),
    "falt_gul": Color("cfb55a"), "falt_brun": Color("9c7a50"), "strand": Color("b39a72"), "lera": Color("7f6a4c"),
    "botten": Color("4f6a60"), "stad": Color("cfae7e"), "torg": Color("dcc39a"), "damm": Color("d6b88a"),
    "krita": Color("eee7d8"), "krita_skugga": Color("d9cfbb"), "krita_damm": Color("e6dccb"), "berg": Color("cf9f68"),
    "berg_mork": Color("b0804f"),
}
## Places where the dunes lie down: the Nubian village, the quarry, Kom Ombo, the theatre, the
## Bedouin camp [x, z, radius].
const FLAT_SPOTS := [[600.0, 1360.0, 170.0], [912.0, 1250.0, 60.0], [510.0, 1040.0, 50.0], [1240.0, -385.0, 45.0],
    [-1040.0, 700.0, 30.0]]

var _dune := FastNoiseLite.new()


func _init() -> void:
    models_dirs = [EG_MODELS, MODELS]
    _dune.seed = 31
    _dune.frequency = 1.0 / 150.0
    _dune.fractal_octaves = 2


# --- Hooks into the shared engine ------------------------------------------------------------------

func _road_ctrl() -> Array:
    return EG_ROAD


func _core() -> Rect2:
    return Rect2(-1320, -770, 2920, 2250)


## Keep the road straight through the bazaar lane, the temple gate and over the bridges.
func _weave_calm(p: Vector2) -> float:
    var calm := 1.0
    calm = minf(calm, smoothstep(40.0, 90.0, _seg_dist(p, BAZAAR[0], BAZAAR[1])))
    calm = minf(calm, smoothstep(60.0, 120.0, p.distance_to(TEMPLE)))
    calm = minf(calm, smoothstep(NILE_HALF + 20.0, NILE_HALF + 70.0, absf(p.x - nile_x(p.y))))
    calm = minf(calm, smoothstep(20.0, 60.0, _valley_dist(p.x, p.y).x))
    calm = minf(calm, smoothstep(60.0, 110.0, p.distance_to(FAROS)))
    return calm * 0.6


func lap_name() -> String:
    return "Nilvägen"


func climate() -> String:
    return "desert"


func segments() -> Array:
    return [
        {"id": "promenaden", "name": "Promenadspurten", "kind": "sprint", "from": 1575.0, "to": 1825.0},
        {"id": "giza_12", "name": "Upp till Giza", "kind": "climb", "from": 3010.0, "to": 3380.0},
        {"id": "platan_12", "name": "Platåspurten", "kind": "sprint", "from": 3400.0, "to": 3600.0},
        {"id": "dynbacken_12", "name": "Dynbacken", "kind": "climb", "from": 4670.0, "to": 4820.0},
        {"id": "kritspurten", "name": "Kritspurten", "kind": "sprint", "from": 5625.0, "to": 5875.0},
        {"id": "kungadalen", "name": "Kungadalen", "kind": "climb", "from": 7790.0, "to": 8100.0},
        {"id": "kataraktbron", "name": "Kataraktbron", "kind": "sprint", "from": 8950.0, "to": 9200.0},
        {"id": "basarspurten_12", "name": "Basarspurten", "kind": "sprint", "from": 12070.0, "to": 12270.0},
    ]


func _make_islets() -> void:
    _islets = []


func _zone_rock(_zone: String) -> Array:
    return [0.0, 0.0]


func _ground_shader() -> Shader:
    return SAND_SHADER


func _fine_areas() -> Array:
    return [[CAMP, 60.0], [SPHINX, 90.0], [TELEPORT, 50.0], [FAROS, 60.0], [PHILAE, 60.0], [QUARRY, 45.0]]


func _kind_scale(kind: String) -> Array:
    return {"palm": [0.85, 1.25], "bananplanta": [0.8, 1.3], "papyrus": [0.8, 1.3], "akacia": [0.8, 1.3],
        "buske_torr": [0.7, 1.4], "klippa": [0.8, 2.4], "vass": [0.8, 1.2], "vit_klippa": [0.6, 1.4],
        "granit": [0.6, 1.7]}.get(kind, [1.0, 1.0])


func _variants(kind: String) -> int:
    return {"palm": 3, "bananplanta": 2, "papyrus": 2, "akacia": 2, "buske_torr": 2, "klippa": 3, "vass": 2, "stenar": 3,
        "vit_klippa": 3, "granit": 2}.get(kind, 1)


func _is_tree(kind: String) -> bool:
    return kind == "palm" or kind == "akacia"


func _sways(kind: String) -> bool:
    return kind in ["bananplanta", "papyrus", "vass", "buske_torr"]


func _is_small(kind: String) -> bool:
    return kind == "buske_torr" or kind == "stenar"


func _is_rock(kind: String) -> bool:
    return kind == "klippa" or kind == "vit_klippa" or kind == "granit"


func _view_range(kind: String, _name: String) -> float:
    return {"palm": 650.0, "bananplanta": 260.0, "papyrus": 230.0, "akacia": 800.0, "buske_torr": 200.0,
        "klippa": 700.0, "vass": 250.0, "stenar": 160.0, "vit_klippa": 1100.0, "granit": 600.0}.get(kind, 0.0)


func _place_name(p: Vector3) -> String:
    var q := Vector2(p.x, p.z)
    if q.distance_to(FAROS) < 130.0:
        return "Faros"
    if q.distance_to(CITADEL) < 110.0:
        return "Citadellet"
    if p.x > 1100.0 and p.z < -340.0:
        return "Alexandria"
    if p.z < COAST_Z + 15.0:
        return "Kusten"
    if q.distance_to(ABU) < 100.0:
        return "Abu Simbel"
    if q.distance_to(TERRACE) < 120.0:
        return "Klipptemplet"
    if q.distance_to(CAMP) < 45.0:
        return "Utgrävningen"
    if q.distance_to(SPHINX) < 70.0:
        return "Sfinxen"
    for py in PYRAMIDS:
        if q.distance_to(py[1]) < float(py[2]) * 0.9:
            return "Pyramiderna"
    if _seg_dist(q, BAZAAR[0], BAZAAR[1]) < 25.0:
        return "Basaren"
    if q.distance_to(TEMPLE) < 140.0:
        return "Templet"
    if q.distance_to(OASIS) < 130.0:
        return "Oasen"
    if _white(p.x, p.z) > 0.3:
        return "Vita öknen"
    if q.distance_to(MEMNON[0]) < 90.0:
        return "Memnonkolosserna"
    if _valley_dist(p.x, p.z).x < 60.0:
        return "Kungadalen"
    if q.distance_to(PHILAE) < 70.0:
        return "Philae"
    if Vector2((p.x - CATARACT.x) / CATARACT_R.x, (p.z - CATARACT.y) / CATARACT_R.y).length() < 1.1:
        return "Katarakten"
    if q.distance_to(QUARRY) < 100.0:
        return "Stenbrottet"
    if q.distance_to(NUBIA) < 190.0:
        return "Nubiska byn"
    if q.distance_to(KOM_OMBO) < 80.0:
        return "Kom Ombo"
    var dn := absf(p.x - nile_x(p.z)) - NILE_HALF
    if dn < 0.0:
        return "Nilen"
    if _city_mask(p.x, p.z) > 0.5:
        return "Kairo"
    if dn < 95.0:
        return "Djungeln"
    if dn < 175.0:
        return "Fälten"
    return "Öknen"


func boss_spawn() -> Vector3:
    var c: Vector2 = PYRAMIDS[0][1]
    var p := Vector2(c.x + 120.0, c.y + 30.0)
    return Vector3(p.x, height(p.x, p.y), p.y)


func battle_theme() -> Dictionary:
    return {
        "vehicle": "flakbil", "turret": "Torn", "gun": "Pipa", "muzzle": 1.95, "weapon": "kulspruta",
        "radius": 1.3, "camera": [11.0, 4.4], "monsters": [["mumie", 0.75], ["skarabe", 0.25]], "boss": "farao",
        "title": "FLAKBIL", "names": {"mumie": "Mumier", "skarabe": "Skarabéer", "farao": "Farao"},
        "found": "Du hittade utgrävningslägret! Cykeln är nu en flakbil med kulspruta.",
        "alarm": "Mumierna vaknar! Skjut med %s.",
        "boss_in": "Faraon stiger upp vid den stora pyramiden! Sextio träffar fäller honom.",
        "boss_down": "Faraon är besegrad! +500",
        "knocked": "Flakbilen är utslagen! Lägret skickar en ny …",
        "new": "Lägret skickade en ny flakbil. Kör vidare!",
    }


# --- Ground --------------------------------------------------------------------------------------

## The Nile's centre line at z.
static func nile_x(z: float) -> float:
    return 250.0 + 40.0 * sin(z / 230.0 + 0.6)


static func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
    var ab := b - a
    var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-4), 0.0, 1.0)
    return p.distance_to(a + ab * t)


## 1 on the Giza plateau west of the river (not in the south-western desert).
static func _plateau(x: float, z: float) -> float:
    return smoothstep(-60.0, -240.0, x) * (1.0 - smoothstep(200.0, 360.0, z))


## 1 in Cairo and in Alexandria, which runs on along the coast to the lighthouse's headland.
static func _city_mask(x: float, z: float) -> float:
    var cairo := smoothstep(430.0, 470.0, x) * (1.0 - smoothstep(130.0, 200.0, z)) * (1.0 - smoothstep(1090.0, 1150.0, x))
    var alexandria := smoothstep(1060.0, 1100.0, x) * (1.0 - smoothstep(1380.0, 1440.0, x)) * (1.0 - smoothstep(-400.0, -340.0, z))
    return maxf(cairo, alexandria)


## The granite country round Aswan on the east bank.
static func _aswan(x: float, z: float) -> bool:
    return x > 560.0 and x < 1150.0 and z > 1050.0 and z < 1480.0


## 1 on the Theban hills (their cliffs and top, not the court of the cliff temples below).
static func _thebes(x: float, z: float) -> float:
    var band := smoothstep(-660.0, -630.0, x) * (1.0 - smoothstep(-200.0, -170.0, x))
    return band * smoothstep(700.0, 745.0, z) * (1.0 - smoothstep(THEBES_END, THEBES_END + 130.0, z))


## 1 on the White Desert's chalk plain.
static func _white(x: float, z: float) -> float:
    return 1.0 - smoothstep(WHITE_R - 80.0, WHITE_R, Vector2(x, z).distance_to(WHITE))


## Distance from the Valley of the Kings' centre line and how far along it (0–1) the nearest point is.
static func _valley_dist(x: float, z: float) -> Vector2:
    if x < -600.0 or x > -60.0 or z < 1000.0 or z > 1460.0:
        return Vector2(1e9, 0.0)
    var p := Vector2(x, z)
    var best := 1e9
    var at := 0.0
    var run := 0.0
    var total := 0.0
    for k in VALLEY.size() - 1:
        total += (VALLEY[k] as Vector2).distance_to(VALLEY[k + 1])
    for k in VALLEY.size() - 1:
        var a: Vector2 = VALLEY[k]
        var b: Vector2 = VALLEY[k + 1]
        var ab := b - a
        var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
        var d := p.distance_to(a + ab * t)
        if d < best:
            best = d
            at = (run + ab.length() * t) / total
        run += ab.length()
    return Vector2(best, at)


func natural(x: float, z: float) -> float:
    var pl := _plateau(x, z)
    var h := 3.0 + _noise.get_noise_2d(x * 0.6, z * 0.6) * 0.8 + pl * 26.0
    h += pl * _noise.get_noise_2d(x * 1.7 + 50.0, z * 1.7) * 1.5
    var dn := absf(x - nile_x(z)) - NILE_HALF
    var city := _city_mask(x, z)
    var temple := 1.0 - smoothstep(110.0, 170.0, Vector2(x, z).distance_to(TEMPLE))
    # Dunes: away from the river and the fields, outside the city and off the plateau top.
    var desert := smoothstep(170.0, 260.0, dn) * (1.0 - city) * (1.0 - smoothstep(0.5, 0.9, pl)) * (1.0 - temple)
    for f in FLAT_SPOTS:
        var fd := Vector2(x - f[0], z - f[1]).length()
        if fd < float(f[2]) + 80.0:
            desert *= smoothstep(float(f[2]), float(f[2]) + 80.0, fd)
    if desert > 0.0:
        var ridge := 1.0 - absf(_dune.get_noise_2d(x, z * 0.45))
        var white := _white(x, z)
        h += desert * (ridge * ridge * 12.0 * (1.0 - 0.8 * white) + _dune.get_noise_2d(x * 2.3 + 100.0, z * 2.3) * 2.0)
        h += white * (2.0 + _noise.get_noise_2d(x * 1.3 + 200.0, z * 1.3) * 2.5)
    h += city * 3.0
    h = lerpf(h, 4.0, temple)
    # The oasis: a pond in a hollow.
    var od := Vector2(x, z).distance_to(OASIS)
    if od < 140.0:
        h = lerpf(minf(h, 3.0), h, smoothstep(60.0, 140.0, od))
        if od < 48.0:
            h = lerpf(-2.5, 1.0, smoothstep(30.0, 48.0, od))
    # Flat pads for the pyramids, the camp and the Sphinx's pit.
    for py in PYRAMIDS:
        var c: Vector2 = py[1]
        var r0: float = float(py[2]) * 0.62
        var pad := 3.0 + 26.0 * _plateau(c.x, c.y)
        h = lerpf(pad, h, smoothstep(r0, r0 + 35.0, Vector2(x, z).distance_to(c)))
    var cd := Vector2(x, z).distance_to(CAMP)
    h = lerpf(3.0 + 26.0 * _plateau(CAMP.x, CAMP.y), h, smoothstep(28.0, 50.0, cd))
    var sd := Vector2(x, z).distance_to(SPHINX)
    h = lerpf(3.0 + 26.0 * _plateau(SPHINX.x, SPHINX.y) - 6.0, h, smoothstep(42.0, 58.0, sd))
    # The canal by the corniche, from the river east to its basin.
    var bank := nile_x(CANAL_Z) + NILE_HALF - 10.0
    if x > bank and x < CANAL_END + 12.0 and absf(z - CANAL_Z) < 20.0:
        var cw := smoothstep(14.0, 7.0, absf(z - CANAL_Z)) * smoothstep(CANAL_END + 12.0, CANAL_END, x)
        h = lerpf(h, -2.5, cw)
    # The Nile: a channel with soft banks.
    if dn < 45.0:
        var bed := lerpf(-6.0, 1.0, smoothstep(-40.0, 0.0, dn))
        h = lerpf(bed, h, smoothstep(0.0, 45.0, dn)) if dn > 0.0 else bed
    # The first cataract: the river widens into a lake strewn with granite islets round Philae.
    var cq := Vector2((x - CATARACT.x) / CATARACT_R.x, (z - CATARACT.y) / CATARACT_R.y).length()
    if cq < 1.3:
        h = lerpf(h, minf(h, -4.5), 1.0 - smoothstep(0.8, 1.15, cq))
        h = lerpf(h, 2.4, 1.0 - smoothstep(36.0, 50.0, Vector2(x, z).distance_to(PHILAE)))
        for isl in ISLETS:
            var idist := Vector2(x, z).distance_to(Vector2(isl[0], isl[1]))
            if idist < float(isl[2]) * 1.6:
                h = lerpf(h, 1.4, 1.0 - smoothstep(float(isl[2]) * 0.6, float(isl[2]) * 1.6, idist))
    # The quarry: a shallow pit round the unfinished obelisk.
    var qd := Vector2((x - QUARRY.x) / 38.0, (z - QUARRY.y) / 18.0).length()
    if qd < 1.4:
        h -= 2.0 * (1.0 - smoothstep(0.85, 1.35, qd))
    # The cliff temples: a court levelled in front of the escarpment, the plateau rising behind it.
    var band := smoothstep(-660.0, -630.0, x) * (1.0 - smoothstep(-200.0, -170.0, x))
    if band > 0.0 and z > 640.0:
        h = lerpf(h, 4.0, band * smoothstep(648.0, 668.0, z) * (1.0 - smoothstep(708.0, 718.0, z)))
        h = lerpf(h, 32.0 + _noise.get_noise_2d(x * 0.8, z * 0.8) * 4.0,
            band * smoothstep(715.0, 745.0, z) * (1.0 - smoothstep(THEBES_END, THEBES_END + 130.0, z)))
    # The Valley of the Kings: a canyon through the hills, its floor rising to the middle.
    var vd := _valley_dist(x, z)
    if vd.x < 50.0:
        h = lerpf(5.0 + 9.0 * sin(PI * vd.y), h, smoothstep(18.0, 46.0, vd.x))
    # The Mediterranean in the north, and the citadel's promontory.
    if z < COAST_Z + 5.0:
        h = lerpf(h, -7.0, smoothstep(COAST_Z, COAST_Z - 40.0, z))
        h = lerpf(h, 2.2, 1.0 - smoothstep(36.0, 46.0, Vector2(x, z).distance_to(CITADEL)))
        h = lerpf(h, 2.6, 1.0 - smoothstep(100.0, 118.0, Vector2(x, z).distance_to(FAROS)))
    return h


func _height_near(x: float, z: float, near: Array) -> float:
    var h := natural(x, z)
    if near[0] < 30.0:
        var i: int = near[1]
        if road_bridge[i] == 1:
            return minf(h, -2.0) if near[0] < 9.0 else h
        var w := 1.0 - smoothstep(4.0, 16.0, near[0])
        h = lerpf(h, road_pos[i].y - 0.12, w)
    return h


func zone_at(s: float) -> String:
    var p: Vector3 = sample(s)["pos"]
    return _place_name(p)


func _tri(verts: PackedVector3Array, colors: PackedColorArray, a: Vector3, b: Vector3, c: Vector3, road_d: float, gthr := -0.25) -> void:
    verts.append_array([a, c, b])
    var n := (b - a).cross(c - a).normalized()
    var centre := (a + b + c) / 3.0
    var y := centre.y
    var x := centre.x
    var z := centre.z
    var col: Color
    if y < -1.0:
        col = ECOL["lera"].lerp(ECOL["botten"], clampf((-y - 1.0) / 4.0, 0.0, 1.0))
    elif y < 0.6:
        col = ECOL["strand"]
    else:
        var veg := _noise.get_noise_2d(x * 0.9 + 300.0, z * 0.9)
        var dn := absf(x - nile_x(z)) - NILE_HALF
        var od := Vector2(x, z).distance_to(OASIS)
        var canal := absf(z - CANAL_Z) < 26.0 and x > nile_x(CANAL_Z) and x < CANAL_END + 20.0
        var temple := Vector2(x, z).distance_to(TEMPLE) < 125.0
        if _city_mask(x, z) > 0.5 or temple:
            col = ECOL["torg"] if temple or fposmod(floorf(x / 9.0) + floorf(z / 9.0), 2.0) < 1.0 else ECOL["stad"]
        elif dn < 95.0 + veg * 25.0 or od < 110.0 + veg * 15.0 or canal:
            col = ECOL["djungel"].lerp(ECOL["gron"], clampf(veg + 0.5, 0.0, 1.0))
        elif dn < 175.0 + veg * 30.0:
            # Patchwork of fields: green crops, ripe wheat, freshly ploughed earth.
            var cell := Vector2i(floori(x / 26.0), floori(z / 18.0))
            var pick := fposmod(sin(cell.x * 12.9898 + cell.y * 78.233) * 43758.5453, 1.0)
            col = ECOL["gron"] if pick < 0.45 else (ECOL["gron_mork"] if pick < 0.65 else (ECOL["falt_gul"] if pick < 0.85 else ECOL["falt_brun"]))
        elif _plateau(x, z) > 0.55 and n.y > 0.8:
            col = ECOL["kalk"] if _noise.get_noise_2d(x * 3.0, z * 3.0) > -0.2 else ECOL["kalk_mork"]
        elif _thebes(x, z) > 0.3 and (n.y < 0.85 or y > 20.0):
            col = ECOL["berg_mork"] if n.y < 0.85 else ECOL["berg"]
        elif _white(x, z) > 0.5:
            col = ECOL["krita"] if n.y > 0.9 and _noise.get_noise_2d(x * 2.0, z * 2.0) > -0.3 else ECOL["krita_skugga"]
        else:
            col = ECOL["sand"]
            if n.x > 0.12:
                col = ECOL["sand_ljus"]
            elif n.x < -0.12 or n.y < 0.85:
                col = ECOL["sand_mork"]
        if road_d < 4.8 and col != ECOL["torg"]:
            col = col.lerp(ECOL["krita_damm"] if _white(x, z) > 0.5 else ECOL["damm"], 0.6)
    var jitter := fposmod(sin(centre.x * 12.9898 + centre.z * 78.233) * 43758.5453, 1.0)
    col = col.lightened(jitter * 0.03) if jitter > 0.5 else col.darkened(jitter * 0.03)
    for k in 3:
        colors.append(col)


# --- Light ---------------------------------------------------------------------------------------

## A warm desert evening: pale blue overhead, gold and peach towards the low sun, dusty haze.
func _build_environment() -> void:
    var sky_mat := ShaderMaterial.new()
    sky_mat.shader = EG_SKY
    sky_mat.set_shader_parameter("zenith_color", Color(0.36, 0.55, 0.86))
    sky_mat.set_shader_parameter("high_color", Color(0.62, 0.72, 0.92))
    sky_mat.set_shader_parameter("horizon_color", Color(1.0, 0.82, 0.6))
    sky_mat.set_shader_parameter("sun_side_color", Color(1.0, 0.72, 0.38))
    sky_mat.set_shader_parameter("ground_color", Color(0.55, 0.45, 0.35))
    var sky := Sky.new()
    sky.sky_material = sky_mat
    sky.radiance_size = Sky.RADIANCE_SIZE_256
    var env := Environment.new()
    env.background_mode = Environment.BG_SKY
    env.sky = sky
    env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
    env.ambient_light_energy = 0.8
    env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
    env.tonemap_mode = Environment.TONE_MAPPER_ACES
    env.tonemap_exposure = 0.95
    env.tonemap_white = 6.0
    env.ssao_enabled = true
    env.ssao_radius = 1.6
    env.ssao_intensity = 1.6
    env.glow_enabled = true
    env.glow_intensity = 0.6
    env.glow_bloom = 0.05
    env.glow_hdr_threshold = 1.1
    env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
    env.fog_enabled = true
    env.fog_light_color = Color("f0c896")
    env.fog_light_energy = 1.0
    env.fog_sun_scatter = 0.25
    env.fog_density = 0.0004
    env.fog_aerial_perspective = 0.6
    env.fog_sky_affect = 0.15
    env.adjustment_enabled = true
    env.adjustment_saturation = 1.1
    env.adjustment_contrast = 1.06
    env.ssil_enabled = true
    env.ssil_intensity = 1.0
    env.ssil_radius = 6.0
    environment = env
    var world_env := WorldEnvironment.new()
    world_env.environment = env
    add_child(world_env)
    _build_clouds()
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-15.0, -60.0, 0.0)
    sun.light_color = Color("ffc27a")
    sun.light_energy = 2.6
    sun.light_angular_distance = 0.8
    sun.shadow_enabled = true
    sun.shadow_blur = 1.2
    sun.directional_shadow_max_distance = 260.0
    sun.directional_shadow_split_1 = 0.06
    sun.directional_shadow_split_2 = 0.18
    sun.directional_shadow_split_3 = 0.45
    sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
    add_child(sun)


# --- Places --------------------------------------------------------------------------------------

func _place_props() -> void:
    _init_network()
    _place_pyramids()
    _place_camp()
    _place_bazaar()
    _place_alexandria()
    _place_eg_roads()
    _place_street_scenes()
    _place_city()
    _place_temple()
    _place_bridge_lions()
    _place_oasis()
    _place_monuments()
    _place_coast()
    _place_countryside()
    _place_valley()
    _place_aswan()
    _place_white_desert()
    _place_activity()
    _place_eg_teleport()
    if not _gravel_verts.is_empty():
        add_child(_mesh(_gravel_verts, _gravel_cols, 1.0))


func _place_pyramids() -> void:
    for py in PYRAMIDS:
        var c: Vector2 = py[1]
        _prop(py[0], Vector3(c.x, height(c.x, c.y) - 0.4, c.y), 0.0)
        _keep(c, float(py[2]) * 0.62)
    for q in QUEENS:
        _prop("pyramid_drottning", Vector3(q.x, height(q.x, q.y) - 0.3, q.y), 0.0)
        _keep(q, 24.0)
    var sp := Vector3(SPHINX.x, height(SPHINX.x, SPHINX.y), SPHINX.y)
    _prop("sfinx", sp, 0.0)
    _keep(SPHINX, 40.0)


## Behind the pyramids: white tents, floodlights, crates, an opened sarcophagus and the pickup.
func _place_camp() -> void:
    var c := CAMP
    _keep(c, 30.0)
    var items := [["talt_vit", 10.0, -12.0, 0.3], ["talt_vit", 16.0, 4.0, -0.4], ["talt_vit", -6.0, -16.0, 1.6],
        ["stralkastare", -10.0, 6.0, 0.8], ["stralkastare", 14.0, 16.0, 2.4], ["sarkofag", 2.0, 10.0, 0.2],
        ["lador", -4.0, -4.0, 0.5], ["lador", 6.0, -3.0, 1.9], ["kamel_ligg", 22.0, -14.0, 2.2]]
    for e in items:
        var p := Vector2(c.x + e[1], c.y + e[2])
        _prop(e[0], _ground(p.x, p.y), e[3])
    base_tank = _scene("flakbil")
    var tp := Vector2(c.x - 14.0, c.y - 4.0)
    base_tank.position = _ground(tp.x, tp.y)
    base_tank.rotation.y = PI * 0.85
    add_child(base_tank)
    var r := _road_at(tp)
    var sp: Vector3 = (r["pos"] as Vector3) + (r["right"] as Vector3) * 4.5
    var sign := _prop("skylt_vag_h", _ground(sp.x, sp.z), atan2(-(r["dir"] as Vector3).x, -(r["dir"] as Vector3).z))
    _sign_text(sign, "Utgrävning", Vector3(0.04, 2.175, 0.035), Color("1d1f22"), 32)


## The bazaar lane: stalls close on both sides facing the road, houses behind them, coloured
## awnings across. Stalls and houses are drawn as one multimesh per model.
func _place_bazaar() -> void:
    var s0 := _nearest_s(BAZAAR[0])
    var s1 := _nearest_s(BAZAAR[1])
    if s1 < s0:
        s1 += length
    var stalls := ["basar_kryddor", "basar_mattor", "basar_lyktor", "basar_krukor"]
    var tf := {}
    var k := 0
    var s := s0 + 6.0
    while s < s1 - 4.0:
        var i := int(fposmod(s, length) / STEP)
        var flat := Vector3(road_dir[i].x, 0, road_dir[i].z).normalized()
        var right := _right(i)
        for side: float in [-1.0, 1.0]:
            var p: Vector3 = road_pos[i] + right * side * 5.6
            var face := -right * side
            var name: String = stalls[(k + int(side + 1.0)) % 4]
            _add_tf(tf, name, Vector3(p.x, height(p.x, p.z), p.z), atan2(face.x, face.z))
            _block(p.x, p.z, 2.0)
            _keep(Vector2(p.x, p.z), 3.0)
            if k % 2 == 0:
                var hp: Vector3 = road_pos[i] + right * side * 12.5
                _add_tf(tf, "hus_kairo_%d" % (1 + (k / 2 + int(side + 1.0)) % 4), Vector3(hp.x, height(hp.x, hp.z) - 0.2, hp.z),
                    atan2(face.x, face.z))
                _block(hp.x, hp.z, 4.6)
                _keep(Vector2(hp.x, hp.z), 6.0)
        if k % 3 == 1:
            var m := _prop("markis", Vector3(road_pos[i].x, road_pos[i].y, road_pos[i].z), atan2(-right.z, right.x))
            m.scale = Vector3(1.4, 1.0, 1.0)
        k += 1
        s += 4.6
    _flush_tf(tf)
    var r := _road_at(BAZAAR[0])
    var sp: Vector3 = (r["pos"] as Vector3) - (r["dir"] as Vector3) * 10.0 + (r["right"] as Vector3) * 4.3
    var sign := _prop("skylt_vag_h", _ground(sp.x, sp.z), atan2(-(r["dir"] as Vector3).x, -(r["dir"] as Vector3).z))
    _sign_text(sign, "Basaren", Vector3(0.04, 2.175, 0.035), Color("1d1f22"), 34)


## Cairo: blocks of flat-roofed houses on a jittered grid, kept off the roads, and the mosque with
## two minarets.
func _place_city() -> void:
    var mosque := Vector2(732, -352)
    _prop("moske", _ground_low(mosque.x, mosque.y, 8.0), 0.15)
    _prop("minaret", _ground(mosque.x + 13.0, mosque.y + 12.0), 0.15)
    _prop("minaret", _ground(mosque.x - 13.0, mosque.y - 12.0), 0.15)
    _keep(mosque, 22.0)
    var tf := {}
    var rng := RandomNumberGenerator.new()
    rng.seed = 77
    # The roof slab of each house (floors × 3.2 m + the slab), from egypten_modeller.py. Not the
    # model's top: the water tank and stair hut stand above it, and dishes floated there.
    var roof := {"hus_kairo_1": 9.85, "hus_kairo_2": 13.05, "hus_kairo_3": 6.65, "hus_kairo_4": 9.85}
    var x := 455.0
    while x < 1440.0:
        var z := -560.0
        while z < 150.0:
            var p := Vector2(x + rng.randf_range(-2.5, 2.5), z + rng.randf_range(-2.5, 2.5))
            z += 13.0
            if _city_mask(p.x, p.y) < 0.9 or float(_nearest_road(p.x, p.y)[0]) < 15.0 or not _free_spot(p.x, p.y, 6.0):
                continue
            if absf(p.y - CANAL_Z) < 30.0 and p.x < CANAL_END + 30.0:
                continue
            if rng.randf() < 0.15:
                continue        # a little square now and then
            var yaw := rng.randi_range(0, 3) * PI * 0.5 + rng.randf_range(-0.05, 0.05)
            # Alexandria is whiter than Cairo.
            var model := "hus_kairo_%d" % rng.randi_range(1, 4)
            if p.x > 1080.0:
                model = "hus_kairo_3" if rng.randf() < 0.6 else "hus_kairo_1"
            _add_tf(tf, model, Vector3(p.x, height(p.x, p.y) - 0.3, p.y), yaw)
            if rng.randf() < 0.35:
                _add_tf(tf, "parabol", Vector3(p.x + rng.randf_range(-2.0, 2.0), height(p.x, p.y) - 0.3 + float(roof[model]),
                    p.y + rng.randf_range(-2.0, 2.0)), rng.randf() * TAU)
            _block(p.x, p.y, 4.8)
            _keep(p, 6.0)
        x += 13.0
    _flush_tf(tf)


## The temple: an avenue of sphinxes along the road, the pylon gate the road runs through, two
## obelisks and two seated colossi in front, and columns in the court beyond.
func _place_temple() -> void:
    var g := _road_at(TEMPLE)
    var dir: Vector3 = g["dir"]
    var right: Vector3 = g["right"]
    var gate: Vector3 = g["pos"]
    var pylon := _scene("pylon")
    pylon.position = Vector3(gate.x, height(gate.x, gate.z) - 0.2, gate.z)
    pylon.rotation.y = atan2(-dir.z, dir.x)
    pylon.scale = Vector3.ONE * 1.4
    add_child(pylon)
    for side: float in [-1.0, 1.0]:
        for t: float in [7.0, 14.0, 20.0]:
            var q := gate + right * side * t
            _block(q.x, q.z, 3.6)
        var ob := gate - dir * 16.0 + right * side * 9.0
        _prop("obelisk", _ground(ob.x, ob.z), 0.0)
        var co := gate - dir * 9.0 + right * side * 14.0
        _prop("staty_farao", _ground(co.x, co.z), atan2(dir.z, -dir.x))
        for t: float in [18.0, 42.0]:
            var kp := gate + dir * t + right * side * 15.0
            _prop("kolonnad", _ground(kp.x, kp.z), atan2(-dir.z, dir.x))
    _keep(Vector2(gate.x, gate.z), 26.0)
    # The avenue of sphinxes on the approach.
    var s: float = float(g["s"]) - 22.0
    var n := 0
    while n < 14:
        var i := int(fposmod(s, length) / STEP)
        var r := _right(i)
        var flat := Vector3(road_dir[i].x, 0, road_dir[i].z).normalized()
        for side: float in [-1.0, 1.0]:
            var p: Vector3 = road_pos[i] + r * side * 6.5
            var face := -r * side
            _prop("sfinx_liten", _ground(p.x, p.z), atan2(-face.z, face.x))
        s -= 9.0
        n += 1


func _place_bridge_lions() -> void:
    var count := road_pos.size()
    for i in count:
        var starts := road_bridge[i] == 1 and road_bridge[(i - 1 + count) % count] == 0
        var ends := road_bridge[i] == 1 and road_bridge[(i + 1) % count] == 0
        if not (starts or ends):
            continue
        var flat := Vector3(road_dir[i].x, 0, road_dir[i].z).normalized()
        var out := -flat if starts else flat
        for side: float in [-1.0, 1.0]:
            var p: Vector3 = road_pos[i] + out * 6.0 + _right(i) * side * 5.0
            _prop("lejonstaty", _ground(p.x, p.z), atan2(-out.z, out.x))
            _keep(Vector2(p.x, p.z), 3.5)


func _place_oasis() -> void:
    var c := OASIS
    var tents := [[70.0, -40.0, 0.4], [95.0, 10.0, -0.3], [60.0, 50.0, 1.2]]
    for t in tents:
        var p := Vector2(c.x + t[0], c.y + t[1])
        _prop("talt_beduin", _ground(p.x, p.y), t[2])
        _keep(p, 7.0)
    var camels := [["kamel", 82.0, -14.0, 0.6], ["kamel_ligg", 78.0, 28.0, 2.0], ["kamel", 110.0, 34.0, 4.0],
        ["kamel", -70.0, 60.0, 1.2], ["kamel_ligg", -82.0, 40.0, 0.2]]
    for e in camels:
        var p := Vector2(c.x + e[1], c.y + e[2])
        _prop(e[0], _ground(p.x, p.y), e[3])
        _keep(p, 3.0)


## The cliff temples south of the road, each turned to face it: Abu Simbel's small temple with two
## standing colossi beside it, and the terrace temple with four on its court; a sign at each.
func _place_monuments() -> void:
    for m in [["abusimbel", ABU, 32.0, 2, "Abu Simbel"], ["terrasstempel", TERRACE, 68.0, 4, "Klipptemplet"]]:
        var c: Vector2 = m[1]
        var r := _road_at(c)
        var rp: Vector3 = r["pos"]
        var fwd := Vector2(rp.x - c.x, rp.z - c.y).normalized()
        var lat := Vector2(-fwd.y, fwd.x)
        var yaw := atan2(-fwd.y, fwd.x)
        _prop(m[0], Vector3(c.x, height(c.x, c.y) - 0.3, c.y), yaw)
        var half: float = m[2]
        for t in [-1.0, -0.5, 0.0, 0.5, 1.0]:
            _keep(c + lat * half * t + fwd * 10.0, 26.0)
        var spots := [[12.0, 26.0]] if m[3] == 2 else [[46.0, 14.0], [46.0, 24.0]]
        for sp in spots:
            for side in [-1.0, 1.0]:
                var q: Vector2 = c + fwd * float(sp[0]) + lat * side * float(sp[1])
                _prop("staty_staende", _ground(q.x, q.y), yaw)
                _keep(q, 4.0)
        var sp3: Vector3 = rp + (r["right"] as Vector3) * (4.5 if (r["right"] as Vector3).dot(Vector3(-fwd.x, 0, -fwd.y)) > 0.0 else -4.5)
        var sign := _prop("skylt_vag_h", _ground(sp3.x, sp3.z), atan2(-(r["dir"] as Vector3).x, -(r["dir"] as Vector3).z))
        _sign_text(sign, m[4], Vector3(0.04, 2.175, 0.035), Color("1d1f22"), 30)


## The Mediterranean coast north of Cairo: the citadel on its promontory with the gate towards the
## land, fishing boats and feluccas at anchor in its lee.
func _place_coast() -> void:
    _prop("citadell", Vector3(CITADEL.x, 2.2, CITADEL.y), atan2(-1.0, 0.0))
    _keep(CITADEL, 44.0)
    var boats := [["fiskebat", -52.0, 6.0, 0.4], ["felucca", -60.0, -14.0, 1.9], ["fiskebat", 54.0, 2.0, 2.6],
        ["felucca", 62.0, -18.0, -0.6], ["roddbat", -46.0, 18.0, 1.2]]
    for b in boats:
        _boat(b[0], Vector3(CITADEL.x + b[1], 0.2, CITADEL.y + b[2]), b[3])


## The countryside along the fields: mud-brick farms with a pigeon tower, a donkey cart by the road
## at every other one, and water wheels on the Nile's banks.
func _place_countryside() -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = 21
    var farms := 0
    var s := 0.0
    while s < length and farms < 40:
        var i := int(s / STEP) % road_pos.size()
        var p: Vector3 = road_pos[i]
        s += 40.0
        if road_bridge[i] == 1:
            continue
        for side: float in [-1.0, 1.0]:
            var r: Vector3 = _right(i) * side
            var hp: Vector3 = p + r * 22.0
            var dn := absf(hp.x - nile_x(hp.z)) - NILE_HALF
            if dn < 100.0 or dn > 170.0 or height(hp.x, hp.z) < 0.8 or _city_mask(hp.x, hp.z) > 0.2:
                continue
            if not _free_spot(hp.x, hp.z, 9.0) or _road_clearance(Vector2(hp.x, hp.z)) < 15.0:
                continue
            _prop("lerhus", _ground_low(hp.x, hp.z, 3.0), atan2(-r.x, -r.z))
            _keep(Vector2(hp.x, hp.z), 9.0)
            var along := Vector3(r.z, 0, -r.x)
            var tp: Vector3 = hp + along * 9.0 + r * 4.0
            _prop("duvtorn", _ground(tp.x, tp.z), rng.randf() * TAU)
            _keep(Vector2(tp.x, tp.z), 3.5)
            if farms % 2 == 0:
                var cp: Vector3 = p + r * 6.5 + along * 4.0
                _prop("asnekarra", _ground(cp.x, cp.z), atan2(-along.z, along.x))
                _keep(Vector2(cp.x, cp.z), 2.5)
            farms += 1
            break
    for z: float in [-380.0, -300.0, 340.0, 520.0, 600.0, 760.0, 900.0, 1060.0]:
        var side := 1.0 if int(z) % 2 == 0 else -1.0
        var x := nile_x(z) + side * (NILE_HALF + 2.0)
        if not _free_spot(x, z, 4.0):
            continue
        _prop("vattenhjul", Vector3(x, maxf(height(x, z), 0.4), z), -PI * 0.5)
        _keep(Vector2(x, z), 4.0)


## A road sign by the lap at the point nearest `at`, on its right side.
func _eg_sign(at: Vector2, text: String, size := 32) -> void:
    var r := _road_at(at)
    var sp: Vector3 = (r["pos"] as Vector3) + (r["right"] as Vector3) * 4.5
    var sign := _prop("skylt_vag_h", _ground(sp.x, sp.z), atan2(-(r["dir"] as Vector3).x, -(r["dir"] as Vector3).z))
    _sign_text(sign, text, Vector3(0.04, 2.175, 0.035), Color("1d1f22"), size)
    _keep(Vector2(sp.x, sp.z), 1.5)


## Alexandria east of Cairo: the lighthouse of Pharos on its headland with boats in its lee,
## Pompey's Pillar between two sphinxes, and the Roman theatre. The town's white houses are laid
## out with Cairo's (in _place_city) and palms line the corniche (in _scatter_nature).
func _place_alexandria() -> void:
    _prop("faros", Vector3(FAROS.x, height(FAROS.x, FAROS.y) - 0.3, FAROS.y), -PI * 0.5)
    _keep(FAROS, 24.0)
    _prop("pelare_pompejus", _ground_low(PILLAR.x, PILLAR.y, 4.0), 0.2)
    _keep(PILLAR, 8.0)
    for side: float in [-1.0, 1.0]:
        var sp := PILLAR + Vector2(8.0, side * 7.0)
        _prop("sfinx_liten", _ground(sp.x, sp.y), 0.0)
        _keep(sp, 4.5)
    _prop("teater", _ground_low(THEATRE.x, THEATRE.y, 18.0), PI * 0.5)
    _keep(THEATRE, 30.0)
    var boats := [["felucca", -80.0, -122.0, 0.6], ["fiskebat", 30.0, -132.0, 2.2], ["fiskebat", -132.0, -62.0, 1.4],
        ["roddbat", 92.0, -108.0, 2.9]]
    for b in boats:
        _boat(b[0], Vector3(FAROS.x + b[1], 0.2, FAROS.y + b[2]), b[3])
    _eg_sign(Vector2(1440.0, -530.0), "Faros")


## The gravel tracks that make other loops: across the White Desert past the Bedouin camp, the short
## cut by Pompey's Pillar in Alexandria, and the riverside track past Kom Ombo on the east bank.
func _place_eg_roads() -> void:
    _cross_road("Ökenspåret", Vector2(-980.0, 470.0), Vector2(-980.0, 900.0),
        [Vector2(-960.0, 600.0), Vector2(-1000.0, 700.0), Vector2(-990.0, 800.0)], "Beduinlägret", "Beduinlägret")
    _cross_road("Pelargatan", Vector2(1220.0, -450.0), Vector2(1200.0, -562.0),
        [Vector2(1214.0, -488.0), Vector2(1206.0, -526.0)], "Pompejus pelare", "Pompejus pelare")
    _cross_road("Nilstigen", Vector2(700.0, 1320.0), Vector2(620.0, 860.0),
        [Vector2(560.0, 1200.0), Vector2(470.0, 1100.0), Vector2(475.0, 980.0)], "Kom Ombo", "Kom Ombo")


## The Theban side: the Colossi of Memnon at the foot of the hills facing the river, and the royal
## tombs cut into the walls of the Valley of the Kings, each turned to the road.
func _place_valley() -> void:
    for m: Vector2 in MEMNON:
        _prop("memnon", _ground_low(m.x, m.y, 5.0), 0.0)
        _keep(m, 9.0)
    _eg_sign(Vector2(-58.0, 860.0), "Memnonkolosserna", 24)
    var s0 := _nearest_s(VALLEY[0])
    var s1 := _nearest_s(VALLEY[VALLEY.size() - 2])
    if s1 < s0:
        s1 += length
    _eg_sign(_v2(road_pos[int(fposmod(s0 - 40.0, length) / STEP)]), "Kungadalen")
    var n := 0
    var s := s0 + 40.0
    while s < s1 - 20.0:
        var i := int(fposmod(s, length) / STEP)
        var r := _right(i) * (1.0 if n % 2 == 0 else -1.0)
        var p: Vector3 = road_pos[i] + r * 19.0
        _prop("gravport", _ground_low(p.x, p.z, 2.0) + Vector3.DOWN * 0.2, atan2(r.z, -r.x))
        _keep(Vector2(p.x, p.z), 9.0)
        n += 1
        s += 70.0


static func _v2(p: Vector3) -> Vector2:
    return Vector2(p.x, p.z)


## Aswan: Philae's temple on its island in the cataract lake with feluccas at its quay, the Nubian
## village along the road with camels and carts, the quarry with the unfinished obelisk, and Kom
## Ombo's ruins by the riverside track. Granite boulders are scattered in _scatter_nature.
func _place_aswan() -> void:
    _prop("philae", Vector3(PHILAE.x, height(PHILAE.x, PHILAE.y) - 1.0, PHILAE.y), -PI * 0.5, 0.75)
    _keep(PHILAE, 34.0)
    for b in [["felucca", -50.0, 42.0, 0.3], ["felucca", 50.0, 38.0, 2.6], ["felucca", -72.0, -18.0, 1.7], ["roddbat", 32.0, 54.0, 0.9],
            ["felucca", -150.0, 70.0, 2.0], ["fiskebat", 110.0, -60.0, 0.4]]:
        var bp := Vector2(PHILAE.x + b[1], PHILAE.y + b[2])
        if height(bp.x, bp.y) < -1.0:
            _boat(b[0], Vector3(bp.x, 0.2, bp.y), b[3])
    _eg_sign(Vector2(40.0, 1407.0), "Philae")
    # The Nubian village: painted houses on both sides of the road, their doors to it, a second row
    # behind.
    var tf := {}
    var sa := _nearest_s(Vector2(470.0, 1398.0))
    var sb := _nearest_s(Vector2(735.0, 1300.0))
    var k := 0
    var s := sa
    while s < sb:
        var i := int(s / STEP) % road_pos.size()
        for side: float in [-1.0, 1.0]:
            var r := _right(i) * side
            for depth: float in [13.0, 28.0]:
                var hp: Vector3 = road_pos[i] + r * (depth + fposmod(k * 3.7, 3.0))
                if height(hp.x, hp.z) < 1.0 or not _free_spot(hp.x, hp.z, 5.5):
                    continue
                _add_tf(tf, "hus_nubisk_%d" % (1 + k % 3), Vector3(hp.x, height(hp.x, hp.z) - 0.2, hp.z), atan2(-r.x, -r.z))
                _block(hp.x, hp.z, 4.4)
                _keep(Vector2(hp.x, hp.z), 6.0)
                k += 1
        s += 15.0
    _flush_tf(tf)
    for e in [["kamel_ligg", -40.0, 18.0, 0.4], ["kamel", 30.0, 30.0, 2.2], ["asnekarra", 60.0, -22.0, 0.3],
            ["kamel_ligg", 90.0, 24.0, 1.9], ["asnekarra", -70.0, -14.0, 3.0]]:
        var c := NUBIA + Vector2(e[1], e[2])
        if _free_spot(c.x, c.y, 2.5) and float(_nearest_road(c.x, c.y)[0]) > 5.0:
            _prop(e[0], _ground(c.x, c.y), e[3])
            _keep(c, 2.5)
    # The quarry.
    _prop("obelisk_oavslutad", Vector3(QUARRY.x, height(QUARRY.x, QUARRY.y) - 0.2, QUARRY.y), 0.15)
    _keep(QUARRY, 30.0)
    _prop("talt_vit", _ground(QUARRY.x - 10.0, QUARRY.y + 22.0), 0.5)
    _prop("lador", _ground(QUARRY.x + 4.0, QUARRY.y + 20.0), 1.2)
    _eg_sign(Vector2(835.0, 1215.0), "Stenbrottet")
    # Kom Ombo: columns, two standing colossi and an obelisk by the riverside track.
    for e in [["kolonnad", 0.0, -16.0, PI], ["kolonnad", 0.0, 16.0, PI], ["staty_staende", -14.0, -6.0, PI],
            ["staty_staende", -14.0, 6.0, PI], ["obelisk", -20.0, 0.0, 0.0]]:
        var c := KOM_OMBO + Vector2(e[1], e[2])
        _prop(e[0], _ground_low(c.x, c.y, 2.0), e[3])
        _keep(c, 8.0)


## The White Desert's Bedouin camp by the track across it.
func _place_white_desert() -> void:
    for e in [["talt_beduin", 0.0, -10.0, 0.4], ["talt_beduin", -16.0, 14.0, 1.1], ["kamel_ligg", 14.0, 10.0, 2.0],
            ["kamel_ligg", 18.0, 22.0, 0.6], ["kamel", -26.0, -8.0, 1.5]]:
        var c := BEDOUIN + Vector2(e[1], e[2])
        _prop(e[0], _ground(c.x, c.y), e[3])
        _keep(c, 6.0 if e[0] == "talt_beduin" else 3.0)
    _eg_sign(Vector2(-840.0, 500.0), "Vita öknen")


## A small stone bridge over the canal by the corniche carries the gate to Japan (the gates go
## round: Skärgården → Egypten → Japan → Skärgården).
func _place_eg_teleport() -> void:
    var y := 2.4
    _teleport_bridge(Vector3(TELEPORT.x, y, TELEPORT.y - 26.0), Vector3(TELEPORT.x, y, TELEPORT.y + 26.0), 0.5,
        "japan", "Till Japan")


# --- Life: feluccas, balloons, the caravan, gulls -----------------------------------------------

var _sailing: Array = []     # [felucca, z low, z high, speed, phase, offset from the river's centre]
var _balloons: Array = []    # [balloon, centre, radius, angular speed, phase]
var _caravan: Array = []     # [camel, distance behind the leader]


func _place_life() -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = 5
    # Feluccas sail up and down the Nile, turning before the bridges.
    var reaches := [[-400.0, 1100.0], [-400.0, 1100.0], [-300.0, 1100.0]]
    for k in 12:
        var reach: Array = reaches[k % 3]
        var boat := _scene("felucca")
        add_child(boat)
        _sailing.append([boat, reach[0], reach[1], rng.randf_range(1.6, 2.8), rng.randf() * 1000.0, rng.randf_range(-30.0, 30.0)])
    # Hot-air balloons over the west bank by the cliff temples.
    for k in 6:
        var b := _scene("ballong_%d" % (1 + k % 2))
        add_child(b)
        var c := Vector3(BALLOONS.x + rng.randf_range(-170.0, 170.0), rng.randf_range(45.0, 110.0), BALLOONS.y + rng.randf_range(-80.0, 90.0))
        _balloons.append([b, c, rng.randf_range(15.0, 45.0), rng.randf_range(0.015, 0.035) * (1.0 if k % 2 else -1.0), rng.randf() * TAU])
    # More over the Valley of the Kings at dawn, as at Luxor.
    for k in 5:
        var b := _scene("ballong_%d" % (1 + k % 2))
        add_child(b)
        var c := Vector3(-300.0 + rng.randf_range(-160.0, 160.0), rng.randf_range(55.0, 120.0), 1150.0 + rng.randf_range(-90.0, 90.0))
        _balloons.append([b, c, rng.randf_range(15.0, 45.0), rng.randf_range(0.015, 0.035) * (1.0 if k % 2 else -1.0), rng.randf() * TAU])
    # A camel caravan on its round in the desert below the pyramids.
    for k in 7:
        var camel := _scene("kamel")
        add_child(camel)
        _caravan.append([camel, k * 6.5])
    # Gulls over the citadel and the corniche.
    for k in 10:
        var gull := _scene("mas")
        add_child(gull)
        var centre := CITADEL if k % 2 == 0 else FAROS
        var cg := Vector3(centre.x + rng.randf_range(-90.0, 90.0), rng.randf_range(12.0, 30.0), centre.y + rng.randf_range(-40.0, 60.0))
        _gulls.append([gull, cg, rng.randf_range(10.0, 26.0), rng.randf_range(0.25, 0.45) * (1.0 if k % 2 else -1.0), rng.randf() * TAU])
    _place_movers()


func update_view(distance: float, speed: float, cadence: float, delta: float) -> void:
    super(distance, speed, cadence, delta)
    var now := Time.get_ticks_msec() / 1000.0
    for f in _sailing:
        var span: float = f[2] - f[1]
        var run: float = f[4] + now * f[3]
        var leg := fposmod(run, span * 2.0)
        var dir := 1.0 if leg < span else -1.0
        var z: float = f[1] + (leg if leg < span else span * 2.0 - leg)
        var slope := 40.0 * cos(z / 230.0 + 0.6) / 230.0
        var d := Vector3(slope * dir, 0.0, dir).normalized()
        var node: Node3D = f[0]
        node.position = Vector3(nile_x(z) + f[5], 0.15 + sin(now * 1.3 + f[4]) * 0.06, z)
        node.rotation = Vector3(0.0, atan2(-d.z, d.x), sin(now * 0.9 + f[4]) * 0.03)
    for b in _balloons:
        var a: float = b[4] + now * b[3]
        var node: Node3D = b[0]
        node.position = (b[1] as Vector3) + Vector3(cos(a), 0.0, sin(a)) * b[2] + Vector3.UP * sin(now * 0.2 + b[4]) * 4.0
        node.rotation.y = a * 0.3
    var mean_r := (CARAVAN_R.x + CARAVAN_R.y) * 0.5
    for c in _caravan:
        var a: float = (now * 1.2 - c[1]) / mean_r
        var p := CARAVAN + Vector2(cos(a) * CARAVAN_R.x, sin(a) * CARAVAN_R.y)
        var d := Vector2(-sin(a) * CARAVAN_R.x, cos(a) * CARAVAN_R.y).normalized()
        var node: Node3D = c[0]
        node.position = Vector3(p.x, height(p.x, p.y) + absf(sin(now * 3.0 + c[1])) * 0.08, p.y)
        node.rotation.y = atan2(-d.y, d.x)
    _update_street_life(now)


# --- Street life: people at work, animals, traffic -----------------------------------------------

var _walkers: Array = []     # [node, closed path (Vector2s), its length, speed, phase]
var _traffic: Array = []     # [node, start s, speed, lane offset]
var _match: Array = []       # [kids, ball, from kid, to kid, start time]
var _grazers: Array = []     # [node, base yaw, phase]


## A point beside the lap at distance s, `off` metres to its right (negative: left), on the ground.
func _beside(s: float, off: float) -> Vector3:
    var i := int(fposmod(s, length) / STEP) % road_pos.size()
    var p: Vector3 = road_pos[i] + _right(i) * off
    return Vector3(p.x, height(p.x, p.z), p.z)


## A prop beside the road facing it, `off` metres out on `side`, moved along until there is room.
func _roadside(name: String, s: float, side: float, off: float, room: float) -> Node3D:
    for k in 8:
        var t := s + (k / 2) * 9.0 * (1.0 if k % 2 == 0 else -1.0)
        var i := int(fposmod(t, length) / STEP) % road_pos.size()
        if road_bridge[i] == 1:
            continue
        var r := _right(i) * side
        var p: Vector3 = road_pos[i] + r * off
        if height(p.x, p.z) < 0.8 or not _free_spot(p.x, p.z, room):
            continue
        var node := _prop(name, _ground_low(p.x, p.z, 1.5), atan2(r.z, -r.x))
        _keep(Vector2(p.x, p.z), room)
        return node
    return null


## The street scenes that need room before Cairo's houses are laid out: tea houses and a shisha
## café by the road, washing lines, fruit stalls, carpet sellers, and the boys' football pitch.
func _place_street_scenes() -> void:
    for e in [["tehus", 420.0, 1.0, 10.0, 6.5], ["vattenpipscafe", 12010.0, -1.0, 10.0, 6.5], ["tehus", 1690.0, -1.0, 10.0, 6.5],
            ["vattenpipscafe", 9470.0, 1.0, 11.0, 6.5], ["tvattlina_eg", 600.0, -1.0, 12.0, 3.5],
            ["tvattlina_eg", 11880.0, 1.0, 12.0, 3.5], ["tvattlina_eg", 12160.0, -1.0, 12.0, 3.5],
            ["tvattlina_eg", 9560.0, -1.0, 20.0, 3.5], ["fruktstand", 1760.0, -1.0, 6.5, 2.5], ["fruktstand", 9400.0, -1.0, 7.0, 2.5],
            ["fruktstand", 10700.0, 1.0, 6.5, 2.5], ["mattforsaljare", 3140.0, 1.0, 7.0, 3.0],
            ["mattforsaljare", 10950.0, -1.0, 8.0, 3.0], ["fruktstand", 470.0, -1.0, 6.5, 2.5]]:
        _roadside(e[0], e[1], e[2], e[3], e[4])
    # A sandy pitch among Cairo's houses where boys play football.
    var pitch := _beside(11800.0, 26.0)
    _keep(Vector2(pitch.x, pitch.z), 14.0)
    _match = [[], null, 0, 1, 0.0, pitch]


## People and animals that stay put: archaeologists at the dig, tour groups at the Sphinx and Abu
## Simbel, donkeys tethered by farms, cats in the bazaar, goats and ibises in the fields, water
## buffalo in the shallows and fishing boats on the Nile.
func _place_activity() -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = 404
    _prop("arkeolog_1", _ground(CAMP.x + 4.0, CAMP.y + 7.0), 1.6)
    _prop("arkeolog_2", _ground(CAMP.x - 3.0, CAMP.y + 13.0), -0.7)
    # Tour groups: a guide with the red umbrella, the tourists in an arc looking at the sight.
    for spot in [[SPHINX, 52.0], [ABU, 34.0]]:
        var c: Vector2 = spot[0]
        var r := _road_at(c)
        var rp: Vector3 = r["pos"]
        var out := Vector2(rp.x - c.x, rp.z - c.y).normalized()
        var g := c + out * float(spot[1])
        _prop("guide_paraply", _ground(g.x, g.y), _yaw_to(out))
        for k in 5:
            var a := (k - 2) * 0.35
            var q := g + out.rotated(a) * 3.2
            _prop("turist_1" if k % 2 == 0 else "turist_2", _ground(q.x, q.y), _yaw_to(-out.rotated(a * 0.5)))
        _keep(g, 5.0)
    for e in [[2480.0, 1.0], [7600.0, -1.0], [9380.0, 1.0], [10600.0, -1.0], [10380.0, 1.0], [4700.0, 1.0]]:
        _roadside("asna", e[0], e[1], 6.5, 2.0)
    for k in 10:
        var s: float = [30.0, 85.0, 140.0, 195.0, 11950.0, 12200.0, 520.0, 1600.0, 9450.0, 9520.0][k]
        var c := _beside(s, (4.3 if k % 2 == 0 else -4.3))
        if _free_spot(c.x, c.z, 0.6):
            _prop("katt_1" if k % 3 else "katt_2", c, rng.randf() * TAU)
    # Herds and flocks a little off the road.
    for e in [["get_1", 2470.0, 1.0, 5], ["get_2", 8905.0, -1.0, 5], ["get_1", 10660.0, 1.0, 4], ["get_2", 9640.0, -1.0, 5],
            ["get_2", 7480.0, 1.0, 4], ["ibis", 2790.0, 1.0, 6], ["ibis", 9230.0, -1.0, 6], ["ibis", 10560.0, 1.0, 5],
            ["ibis", 7700.0, 1.0, 4]]:
        var c := _beside(e[1], float(e[2]) * 16.0)
        for k in int(e[3]):
            var q := Vector2(c.x + rng.randf_range(-6.0, 6.0), c.z + rng.randf_range(-6.0, 6.0))
            if height(q.x, q.y) < 0.4 or not _free_spot(q.x, q.y, 0.8) or float(_nearest_road(q.x, q.y)[0]) < 4.0:
                continue
            var name: String = e[0]
            if name == "get_1" and k % 2 == 1:
                name = "get_2"
            var node := _prop(name, _ground(q.x, q.y), rng.randf() * TAU)
            _grazers.append([node, node.rotation.y, rng.randf() * TAU])
    # Water buffalo standing in the shallows by both bridges, and fishing boats on the river.
    for z: float in [-428.0, -440.0, -505.0, 1440.0, 1452.0, 1470.0]:
        var side := -1.0 if z < 0.0 else 1.0
        var x := nile_x(z) + side * (NILE_HALF - 10.0 - rng.randf_range(0.0, 2.0))
        var node := _prop("vattenbuffel", Vector3(x, height(x, z), z), rng.randf() * TAU)
        _grazers.append([node, node.rotation.y, rng.randf() * TAU])
    for z: float in [-300.0, 180.0, 520.0, 700.0, 960.0]:
        var x := nile_x(z) + rng.randf_range(-35.0, 35.0)
        _boat("fiskebat_nil", Vector3(x, 0.15, z), rng.randf() * TAU)


## Yaw that turns a +X-facing model to look along d (x, z).
static func _yaw_to(d: Vector2) -> float:
    return atan2(-d.y, d.x)


## A walking loop beside the lap from s0 to s1: out along one side of the pavement, back along the
## other, so walkers meet and pass.
func _pavement_loop(s0: float, s1: float, off: float) -> PackedVector2Array:
    var pts := PackedVector2Array()
    var s := s0
    while s <= s1:
        var p := _beside(s, off)
        pts.append(Vector2(p.x, p.z))
        s += 8.0
    s = s1
    var back := off + (1.3 if off > 0.0 else -1.3)
    while s >= s0:
        var p := _beside(s, back)
        pts.append(Vector2(p.x, p.z))
        s -= 8.0
    return pts


func _walker(name: String, path: PackedVector2Array, speed: float, phase: float) -> void:
    var node := _scene(name)
    add_child(node)
    var total := 0.0
    for k in path.size():
        total += path[k].distance_to(path[(k + 1) % path.size()])
    _walkers.append([node, path, total, speed, phase * total])


## The moving street life: pedestrians in the bazaar, Cairo, Alexandria and the Nubian village, a
## string of tourists on camels by the pyramids, taxis, tuk-tuks and the bread boy driving the lap
## against the rider, barges and cruise boats on the Nile, and the boys' football game.
func _place_movers() -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = 909
    var b1 := _nearest_s(BAZAAR[1])
    var crowds := [[15.0, b1 - 10.0, 3.3, ["man_galabeya", "kvinna_kruka", "turist_1", "man_galabeya", "handlare_karra"]],
        [15.0, b1 - 10.0, -3.3, ["man_galabeya", "turist_2", "kvinna_kruka", "man_galabeya"]],
        [260.0, 700.0, 4.6, ["man_galabeya", "kvinna_kruka", "man_galabeya"]],
        [260.0, 700.0, -4.6, ["kvinna_kruka", "man_galabeya"]],
        [11720.0, 12300.0, 4.6, ["man_galabeya", "kvinna_kruka", "handlare_karra"]],
        [11720.0, 12300.0, -4.6, ["man_galabeya", "man_galabeya", "kvinna_kruka"]],
        [1560.0, 1950.0, 4.0, ["turist_1", "turist_2", "man_galabeya", "kvinna_kruka"]],
        [9320.0, 9620.0, 7.5, ["kvinna_kruka", "man_galabeya", "kvinna_kruka"]],
        [9320.0, 9620.0, -7.5, ["man_galabeya", "kvinna_kruka"]]]
    for c in crowds:
        var path := _pavement_loop(c[0], c[1], c[2])
        var names: Array = c[3]
        for k in names.size():
            var speed := 0.7 if names[k] == "handlare_karra" else rng.randf_range(1.0, 1.45)
            _walker(names[k], path, speed, (k + rng.randf() * 0.5) / names.size())
    # Tourists on camels led by a guide, nose to tail along the plateau.
    var camels := _pavement_loop(3420.0, 3640.0, -11.0)
    for k in 4:
        _walker("man_galabeya" if k == 0 else "turist_kamel", camels, 0.9, 0.5 - k * 0.012)
    # Traffic on the lap, against the rider in the other lane.
    var cars := [["taxi_kairo", 10.0], ["tuktuk", 7.0], ["taxi_kairo", 11.0], ["budcykel", 4.5], ["tuktuk", 6.5],
        ["taxi_kairo", 9.5], ["tuktuk", 7.5]]
    for k in cars.size():
        var node := _scene(cars[k][0])
        add_child(node)
        _traffic.append([node, length * k / cars.size(), cars[k][1], -1.15])
    # Barges and cruise boats on the Nile.
    for e in [["kryssningsbat", 2.2, -22.0], ["kryssningsbat", 1.9, 18.0], ["flodpram", 1.4, 42.0], ["flodpram", 1.6, -44.0]]:
        var boat := _scene(e[0])
        add_child(boat)
        _sailing.append([boat, -380.0, 1080.0, e[1], rng.randf() * 1000.0, e[2]])
    # The football game.
    if not _match.is_empty():
        var centre: Vector3 = _match[5]
        var kids := []
        for k in 5:
            var kid := _scene("barn_1" if k % 2 == 0 else "barn_2")
            add_child(kid)
            var a := k * TAU / 5.0
            kid.position = Vector3(centre.x + cos(a) * 7.0, height(centre.x + cos(a) * 7.0, centre.z + sin(a) * 4.5), centre.z + sin(a) * 4.5)
            kids.append(kid)
        var ball := _scene("fotboll")
        add_child(ball)
        _match = [kids, ball, 0, 2, 0.0, centre]


func _update_street_life(now: float) -> void:
    for w in _walkers:
        var path: PackedVector2Array = w[1]
        var d: float = fposmod(float(w[4]) + now * float(w[3]), float(w[2]))
        var k := 0
        var seg := path[0].distance_to(path[1])
        while d > seg and k < path.size() - 1:
            d -= seg
            k += 1
            seg = path[k].distance_to(path[(k + 1) % path.size()])
        var a := path[k]
        var b := path[(k + 1) % path.size()]
        var p := a.lerp(b, clampf(d / maxf(seg, 0.01), 0.0, 1.0))
        var node: Node3D = w[0]
        node.position = Vector3(p.x, height(p.x, p.y) + absf(sin(now * float(w[3]) * 5.0 + float(w[4]))) * 0.04, p.y)
        node.rotation.y = _yaw_to(b - a)
    var count := road_pos.size()
    for t in _traffic:
        var s: float = fposmod(float(t[1]) - now * float(t[2]), length)
        var i := int(s / STEP) % count
        var j := (i + 1) % count
        var f := (s - i * STEP) / STEP
        var r := _right(i)
        var pos: Vector3 = road_pos[i].lerp(road_pos[j], f) + r * float(t[3])
        var dir := road_dir[i]
        var node: Node3D = t[0]
        node.position = pos + Vector3.UP * 0.05
        node.rotation = Vector3(0.0, atan2(dir.z, -dir.x), atan2(-dir.y, Vector2(dir.x, dir.z).length()))
    for g in _grazers:
        var node: Node3D = g[0]
        var ph: float = g[2]
        node.rotation.y = float(g[1]) + sin(now * 0.12 + ph) * 0.35
        node.rotation.z = -0.22 * pow(maxf(sin(now * 0.7 + ph), 0.0), 6.0)
    if _match.size() == 6 and _match[1] != null:
        var kids: Array = _match[0]
        var ball: Node3D = _match[1]
        var t: float = (now - float(_match[4])) / 1.3
        if t >= 1.0:
            _match[2] = _match[3]
            _match[3] = (int(_match[3]) + 1 + int(fposmod(now * 7.3, 3.0))) % kids.size()
            _match[4] = now
            t = 0.0
        var from: Vector3 = (kids[_match[2]] as Node3D).position
        var to: Vector3 = (kids[_match[3]] as Node3D).position
        ball.position = from.lerp(to, t) + Vector3.UP * (sin(t * PI) * 2.2)
        ball.rotation = Vector3(now * 6.0, 0.0, now * 4.0)
        for kid: Node3D in kids:
            var dv := Vector2(ball.position.x - kid.position.x, ball.position.z - kid.position.z)
            if dv.length() > 0.1:
                kid.rotation.y = _yaw_to(dv)


# --- Plants and rocks ----------------------------------------------------------------------------

func _scatter_nature() -> void:
    var kinds := {}
    # Big chalk mushrooms close to the road through the White Desert, and palms along the corniche.
    var w0 := _nearest_s(Vector2(-840.0, 500.0))
    var w1 := _nearest_s(Vector2(-760.0, 720.0))
    var n := 0
    var ws := w0
    while ws < w1:
        var i := int(ws / STEP) % road_pos.size()
        ws += 34.0
        n += 1
        var wp: Vector3 = road_pos[i] + _right(i) * (1.0 if n % 2 == 0 else -1.0) * (17.0 + fposmod(n * 7.3, 34.0))
        if _white(wp.x, wp.z) < 0.5 or not _free_spot(wp.x, wp.z, 6.0):
            continue
        var name := "vit_klippa_%d" % (1 + n % 3)
        if not kinds.has(name):
            kinds[name] = []
        var size := 1.5 + fposmod(n * 0.37, 1.3)
        kinds[name].append(Transform3D(Basis(Vector3.UP, n * 1.7).scaled(Vector3.ONE * size), Vector3(wp.x, height(wp.x, wp.z) - 0.4, wp.z)))
        _keep(Vector2(wp.x, wp.z), 4.0 * size)
    var c0 := _nearest_s(Vector2(1335.0, -570.0))
    var c1 := _nearest_s(Vector2(880.0, -535.0))
    var cs := c0
    while cs < c1:
        var i := int(cs / STEP) % road_pos.size()
        cs += 16.0
        var cp: Vector3 = road_pos[i] + _sea_side(i) * 6.0
        if height(cp.x, cp.z) > 0.6 and _free_spot(cp.x, cp.z, 1.5):
            _put(kinds, "palm", Vector3(cp.x, height(cp.x, cp.z), cp.z))
    var step := 7.0
    var x := CORE.position.x + 30.0
    while x < CORE.end.x - 30.0:
        var z := CORE.position.y + 30.0
        while z < CORE.end.y - 30.0:
            var px := x + _rng.randf_range(-3.0, 3.0)
            var pz := z + _rng.randf_range(-3.0, 3.0)
            z += step
            var h := height(px, pz)
            var dn := absf(px - nile_x(pz)) - NILE_HALF
            var p := Vector3(px, h, pz)
            var roll := _rng.randf()
            if h < 0.5:
                if h > -1.2 and roll < 0.3 and _free_spot(px, pz, 1.0):
                    _put(kinds, "papyrus", p, 0.3)
                continue
            if float(_nearest_road(px, pz)[0]) < 4.5:
                continue
            var od := Vector2(px, pz).distance_to(OASIS)
            var canal := absf(pz - CANAL_Z) < 24.0 and px > nile_x(CANAL_Z) and px < CANAL_END + 18.0
            var lake := Vector2((px - CATARACT.x) / CATARACT_R.x, (pz - CATARACT.y) / CATARACT_R.y).length() < 1.15
            if lake:
                # The islets of the cataract: granite with a palm or two.
                if roll < 0.14 and _free_spot(px, pz, 2.0):
                    _put(kinds, "granit", p, 0.3)
                elif roll < 0.2 and _free_spot(px, pz, 2.5):
                    _put(kinds, "palm", p)
                continue
            if _city_mask(px, pz) > 0.5:
                if roll < 0.012 and _free_spot(px, pz, 3.0):
                    _put(kinds, "palm", p)
            elif dn < 95.0 or od < 110.0 or canal:
                if dn < 12.0 and roll < 0.35:
                    _put(kinds, "papyrus" if roll < 0.2 else "vass", p)
                elif roll < 0.26 and _free_spot(px, pz, 2.5):
                    _put(kinds, "palm", p)
                elif roll < 0.46 and _free_spot(px, pz, 1.5):
                    _put(kinds, "bananplanta", p)
            elif dn < 175.0:
                if roll < 0.03 and _free_spot(px, pz, 3.0):
                    _put(kinds, "palm", p)
            else:
                if _white(px, pz) > 0.5:
                    if roll < 0.004 and _free_spot(px, pz, 6.0):
                        _put(kinds, "vit_klippa", p, 0.3)
                    elif roll < 0.007:
                        _put(kinds, "buske_torr", p)
                    continue
                if _aswan(px, pz):
                    if Vector2(px, pz).distance_to(NUBIA) < 200.0 and roll < 0.02 and _free_spot(px, pz, 3.0):
                        _put(kinds, "palm", p)
                    elif roll > 0.985 and _free_spot(px, pz, 3.0):
                        _put(kinds, "granit", p, 0.4)
                    continue
                if _plateau(px, pz) > 0.5 and roll > 0.9:
                    _put(kinds, "stenar", p, 0.1)     # limestone rubble on the plateau
                    if roll > 0.985 and _free_spot(px, pz, 3.0):
                        _put(kinds, "klippa", p, 0.5)
                    continue
                if roll < 0.005 and _free_spot(px, pz, 4.0):
                    _put(kinds, "akacia", p)
                elif roll < 0.022:
                    _put(kinds, "buske_torr", p)
                elif roll < 0.03 and _free_spot(px, pz, 3.0):
                    _put(kinds, "klippa", p, 0.4)
        x += step
    _add_scattered(kinds)


# --- Small helpers -------------------------------------------------------------------------------

## Desert tracks: packed light dust, sandier verges.
func _gravel_colours() -> Array:
    return [Color("cfb48a"), Color("dcc8a4"), Color("c8a97c")]


func _add_tf(tf: Dictionary, name: String, pos: Vector3, yaw: float) -> void:
    if not tf.has(name):
        tf[name] = []
    tf[name].append(Transform3D(Basis(Vector3.UP, yaw), pos))


## One multimesh per model and 200 m square (models with glowing parts keep their surfaces). A
## multimesh is culled only as a whole, so one per model drew every house in Cairo each frame,
## behind the camera too; in squares, those out of view or far off are skipped.
const TF_CELL := 200.0

func _flush_tf(tf: Dictionary) -> void:
    for name in tf:
        var mesh := _merged(_model_mesh(name))
        var cells := {}
        for t: Transform3D in tf[name]:
            var key := Vector2i(floori(t.origin.x / TF_CELL), floori(t.origin.z / TF_CELL))
            if not cells.has(key):
                cells[key] = []
            cells[key].append(t)
        for key in cells:
            add_child(_multimesh(mesh, cells[key]))
