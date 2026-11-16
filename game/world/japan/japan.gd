extends "res://world/skargarden/skargarden.gd"
## Japan, the third world: a dusk ride through a compressed Japan on the same engine as Skärgården.
##
##   Tokyo (east)      a neon street to start in, glass towers with lit floors, Tokyo Tower, street
##                     lamps, vending machines, and Tokyo Bay beyond
##   the river         cherry trees along both banks, two bridges
##   old town (Kyoto)  wooden machiya houses, red lantern strings, ramen stalls, geishas walking,
##                     a koi pond with a red drum bridge
##   the temple hill   the road climbs through a tunnel of vermilion torii to a temple hall and a
##                     five-storey pagoda
##   the castle        a white keep with green roofs on its stone base inside a moat
##   the west          a bamboo grove the road runs through, then rice terraces and a village with
##                     an outdoor sumo ring
##   the south         a waterfall down the mountain with a small pagoda in front; a path leads to
##                     it, and behind the falling water a gorge opens into a hidden valley with the
##                     dojo, where the samurai's armour waits (the battle)
##   all round         the bullet train running on its viaduct, mountains, and Mount Fuji on the
##                     horizon in the north-west
## The bigger Japan (12 km, 2026-11-08) adds, in riding order:
##   Odaiba            a loop along Tokyo Bay's waterfront past a lit Ferris wheel
##   the onsen village a ryokan with steaming hot springs north of the temple hill
##   the lake          a shore road along a mountain lake with a torii standing in the water and
##                     Fuji beyond (like Lake Ashi)
##   Iroha hairpins    a switchback climb through cedars from the lake up to a pass with a tea house
##   the tea fields    rows of tea bushes on the hills the road snakes down through
##   Shirakawa         a valley of thatched gassho farmhouses among rice paddies (south-west)
##   the fishing port  the coast road south of Tokyo with fishing boats and a red harbour light
## Side roads make shorter loops for free riding: Tvärvägen, Risvägen and Fältvägen.
## Coordinates: x east, z south (metres). Lap about 12.3 km.

const JP_MODELS := "res://world/japan/models/"
const JP_SKY := preload("res://world/sky.gdshader")
const JP_GROUND := preload("res://world/japan/mark.gdshader")

const JP_ROAD := [
    # Tokyo: the neon street north, then the waterfront loop round Odaiba.
    Vector2(620, -80), Vector2(620, -250), Vector2(640, -380), Vector2(760, -390), Vector2(900, -430),
    Vector2(1040, -500), Vector2(1105, -650), Vector2(1090, -830), Vector2(980, -955), Vector2(805, -990),
    Vector2(655, -920), Vector2(605, -775), Vector2(650, -660), Vector2(560, -590), Vector2(420, -540),
    # The old town, the torii tunnel and the temple, then north past the onsen village to the lake.
    Vector2(220, -505), Vector2(120, -470), Vector2(20, -430), Vector2(-80, -380), Vector2(-150, -345),
    Vector2(-230, -330), Vector2(-300, -350), Vector2(-390, -400), Vector2(-430, -500), Vector2(-380, -590),
    Vector2(-360, -680), Vector2(-430, -740), Vector2(-540, -735), Vector2(-660, -730), Vector2(-790, -745),
    Vector2(-900, -785), Vector2(-960, -835),
    # The Iroha hairpins up to the pass.
    Vector2(-1060, -795), Vector2(-1160, -750), Vector2(-1200, -725), Vector2(-1180, -702), Vector2(-1090, -675),
    Vector2(-995, -650), Vector2(-975, -630), Vector2(-1000, -610), Vector2(-1090, -590), Vector2(-1170, -565),
    Vector2(-1200, -530),
    # Down through the tea fields, round the castle and south through the bamboo.
    Vector2(-1190, -460), Vector2(-1050, -410), Vector2(-1210, -330), Vector2(-1050, -260), Vector2(-1200, -180),
    Vector2(-1060, -110), Vector2(-980, -40), Vector2(-880, -110), Vector2(-790, -200), Vector2(-680, -250),
    Vector2(-560, -260), Vector2(-460, -190), Vector2(-440, -60), Vector2(-560, 20), Vector2(-690, -20),
    Vector2(-720, 120), Vector2(-690, 260), Vector2(-720, 400),
    # The gassho valley.
    Vector2(-820, 480), Vector2(-960, 520), Vector2(-1110, 580), Vector2(-1200, 690), Vector2(-1170, 830),
    Vector2(-1040, 910), Vector2(-880, 890), Vector2(-750, 800), Vector2(-610, 700), Vector2(-470, 620),
    # The rice terraces, the waterfall and over the river.
    Vector2(-300, 560), Vector2(-150, 640), Vector2(-20, 600), Vector2(60, 620), Vector2(160, 600),
    Vector2(260, 560), Vector2(360, 500), Vector2(480, 440),
    # South-east to the fishing port and north along the coast back into Tokyo.
    Vector2(540, 580), Vector2(600, 720), Vector2(690, 860), Vector2(800, 970), Vector2(920, 1010),
    Vector2(1000, 930), Vector2(1010, 830), Vector2(980, 720), Vector2(960, 600), Vector2(1010, 460),
    Vector2(1070, 330), Vector2(1090, 200), Vector2(1050, 100), Vector2(980, 60), Vector2(900, -40),
    Vector2(760, 40), Vector2(680, 10), Vector2(630, -30),
]
const RIVER_HALF := 36.0
const TEMPLE_HILL := Vector2(-270, -420)
const TOWER := Vector2(800, -515)
const CASTLE := Vector2(-560, -130)
const POND := Vector2(60, -330)
const VILLAGE := Vector2(-410, 525)
const FALL := Vector2(100, 682)          # foot of the waterfall
const VALLEY := Vector2(100, 728)        # the hidden valley with the dojo
## The canal with the teleport bridge: in the open fields just west of Tokyo, about 45 m south of the
## lap (1 300–1 400 m), so the glowing torii is in plain sight from the road.
const CANAL := Vector2(400, -490)
const NEON_STREET := [Vector2(620, -80), Vector2(640, -380)]
const OLD_TOWN := [Vector2(220, -505), Vector2(-80, -380)]
const TORII_TUNNEL := [Vector2(-80, -380), Vector2(-230, -330)]
const BAMBOO := [Vector2(-700, 0), Vector2(-705, 400)]
const RAIL := [Vector2(-1440, 409), Vector2(1200, 170)]
# The new places of the bigger Japan.
const LAKE := Vector2(-660, -880)        # the mountain lake (an ellipse)
const LAKE_R := Vector2(285, 122)
const LAKE_TORII := Vector2(-610, -776)  # the torii standing in the water off the shore road
const ONSEN := Vector2(-330, -640)       # the ryokan and its hot springs
const PASS := Vector2(-1200, -532)       # the top of the Iroha hairpins, with the tea house
const TEA := Rect2(-1250, -490, 330, 500) # the tea fields on the hills south of the pass
const GASSHO := Vector2(-1000, 720)      # the thatched farmhouses in the south-west valley
const PORT := Vector2(1040, 790)         # the fishing port south of Tokyo
const PORT_LIGHT := Vector2(1150, 868)   # the red light at the end of the breakwater
const WHEEL := Vector2(880, -1018)       # the Ferris wheel on the Odaiba waterfront
## Tokyo Bay's shore as [z, x] pairs: the water starts about 10 m west of x (south of Tokyo the
## coast swings in towards the south-west, with a headland at the port).
const SHORE := [[-1400.0, 1150.0], [100.0, 1150.0], [300.0, 1120.0], [500.0, 1060.0], [650.0, 1030.0],
    [780.0, 1045.0], [880.0, 1090.0], [960.0, 1060.0], [1040.0, 975.0], [1120.0, 880.0], [1400.0, 820.0]]
const NEON_TEXT := ["ラーメン", "カラオケ", "ゲーム", "寿司", "アニメ", "居酒屋", "東京", "サイクル", "パチンコ", "書店",
    "ホテル", "カフェ"]
const JCOL := {
    "gras": Color("6f9a48"), "gras_mork": Color("4f7a3a"), "skog": Color("3c6236"), "berg": Color("7a7470"),
    "stad": Color("8a8a90"), "stad_ljus": Color("a0a0a6"), "sten": Color("bdb4a4"), "grus": Color("d8d0c0"),
    "ris": Color("86b85a"), "risvatten": Color("6aa094"), "strand": Color("8a7a60"), "botten": Color("3f5a58"),
    "damm": Color("a49c8c"), "te": Color("4f7e36"), "te_mork": Color("3b6430"),
}

var _rail_y := PackedFloat32Array()     # deck height every 20 m along the railway
var _trains: Array = []                 # [cars (Array of Node3D), position along the line, speed, track offset]
var _walkers: Array = []                # geishas: [node, path (Array of Vector3), t, speed, direction]
var _sumo: Array = []                   # [node, phase]
var _blinks: Array = []                 # neon labels that flicker: [label, phase]


func _init() -> void:
    models_dirs = [JP_MODELS, MODELS]


# --- Hooks into the shared engine ------------------------------------------------------------------

func _road_ctrl() -> Array:
    return JP_ROAD


func _core() -> Rect2:
    return Rect2(-1450, -1250, 2780, 2430)


func _weave_calm(p: Vector2) -> float:
    var calm := 1.0
    for seg: Array in [NEON_STREET, OLD_TOWN, TORII_TUNNEL]:
        calm = minf(calm, smoothstep(30.0, 80.0, _seg_dist(p, seg[0], seg[1])))
    calm = minf(calm, smoothstep(RIVER_HALF + 15.0, RIVER_HALF + 60.0, absf(p.x - river_x(p.y))))
    return calm * 0.7


func lap_name() -> String:
    return "Sakuravägen"


func climate() -> String:
    return "temperate"


## The 12 km lap's segments (metres from the start line). None of the old 5.8 km lap's segments
## kept their stretch, so they all have new ids: old records do not carry over to a new stretch.
func segments() -> Array:
    return [
        {"id": "odaibaspurten", "name": "Odaibaspurten", "kind": "sprint", "from": 900.0, "to": 1150.0},
        {"id": "tempelbacken_12", "name": "Tempelbacken", "kind": "climb", "from": 2650.0, "to": 3000.0},
        {"id": "sjospurten", "name": "Sjöspurten", "kind": "sprint", "from": 3480.0, "to": 3730.0},
        {"id": "irohabacken", "name": "Irohabacken", "kind": "climb", "from": 4000.0, "to": 4750.0},
        {"id": "slottsspurten", "name": "Slottsspurten", "kind": "sprint", "from": 6150.0, "to": 6400.0},
        {"id": "gasshobacken", "name": "Gasshobacken", "kind": "climb", "from": 8450.0, "to": 8650.0},
        {"id": "kustspurten", "name": "Kustspurten", "kind": "sprint", "from": 11150.0, "to": 11400.0},
        {"id": "neonspurten_12", "name": "Neonspurten", "kind": "sprint", "from": 11990.0, "to": 12240.0},
    ]


func _make_islets() -> void:
    _islets = []


func _zone_rock(_zone: String) -> Array:
    return [0.0, 0.0]


## Japan's own ground detail (world/japan/mark.gdshader): grass with flowers and cherry petals,
## forest floor with maple leaves, rice rows and mirroring paddies, paving slabs, cobbles, strata.
func _ground_shader() -> Shader:
    return JP_GROUND


func _fine_areas() -> Array:
    return [[VALLEY, 45.0], [FALL, 40.0], [POND, 30.0], [CASTLE, 85.0], [ONSEN, 40.0], [PORT, 50.0]]


func _kind_scale(kind: String) -> Array:
    return {"korsbar": [0.85, 1.25], "lonn": [0.8, 1.2], "bambu": [0.85, 1.2], "tall_jp": [0.8, 1.3],
        "grastuva": [0.8, 1.2], "buske": [0.8, 1.3], "stenar": [0.8, 1.4], "sugi": [0.85, 1.15],
        "ginkgo": [0.85, 1.2]}.get(kind, [1.0, 1.0])


func _variants(kind: String) -> int:
    return {"korsbar": 2, "lonn": 1, "bambu": 2, "tall_jp": 2, "grastuva": 2, "buske": 2, "stenar": 3, "sugi": 2}.get(kind, 1)


func _is_tree(kind: String) -> bool:
    return kind in ["korsbar", "lonn", "tall_jp", "bambu", "sugi", "ginkgo"]


func _sways(kind: String) -> bool:
    return kind in ["grastuva", "buske"]


func _is_small(kind: String) -> bool:
    return kind in ["grastuva", "stenar", "tebuske"]


func _view_range(kind: String, _name: String) -> float:
    return {"korsbar": 700.0, "lonn": 500.0, "bambu": 450.0, "tall_jp": 600.0, "grastuva": 140.0, "buske": 260.0,
        "stenar": 160.0, "sugi": 800.0, "ginkgo": 550.0, "tebuske": 260.0}.get(kind, 0.0)


func _place_name(p: Vector3) -> String:
    var q := Vector2(p.x, p.z)
    if q.distance_to(VALLEY) < 40.0:
        return "Dojon"
    if q.distance_to(FALL) < 45.0:
        return "Vattenfallet"
    if q.distance_to(WHEEL) < 130.0 or (p.x > 600.0 and p.z < -640.0):
        return "Odaiba"
    if q.distance_to(ONSEN) < 100.0:
        return "Onsenbyn"
    if lake_d(p.x, p.z) < 90.0:
        return "Fujisjön"
    if q.distance_to(PASS) < 70.0:
        return "Passet"
    if p.x < -930.0 and p.z > -870.0 and p.z < -545.0:
        return "Irohabackarna"
    if TEA.grow(30.0).has_point(q):
        return "Teodlingarna"
    if q.distance_to(GASSHO) < 270.0:
        return "Gasshobyn"
    if q.distance_to(PORT) < 150.0:
        return "Fiskehamnen"
    if p.x > 470.0 and p.z > 260.0:
        return "Kusten"
    if _seg_dist(q, NEON_STREET[0], NEON_STREET[1]) < 30.0:
        return "Neongatan"
    if q.distance_to(TOWER) < 90.0:
        return "Tokyotornet"
    if _seg_dist(q, TORII_TUNNEL[0], TORII_TUNNEL[1]) < 20.0:
        return "Toriitunneln"
    if q.distance_to(TEMPLE_HILL) < 140.0:
        return "Templet"
    if q.distance_to(CASTLE) < 110.0:
        return "Slottet"
    if _seg_dist(q, OLD_TOWN[0], OLD_TOWN[1]) < 40.0 or q.distance_to(POND) < 40.0:
        return "Gamla stan"
    if _seg_dist(q, BAMBOO[0], BAMBOO[1]) < 60.0:
        return "Bambuskogen"
    if q.distance_to(VILLAGE) < 60.0:
        return "Sumoringen"
    if absf(p.x - river_x(p.z)) < RIVER_HALF:
        return "Floden"
    if _rice(p.x, p.z) > 0.5:
        return "Risfälten"
    if p.x > 440.0:
        return "Tokyo"
    return "Landsbygden"


func battle_theme() -> Dictionary:
    return {
        "vehicle": "samurai", "turret": "Torn", "gun": "Pipa", "muzzle": 0.55, "weapon": "shuriken",
        "radius": 0.7, "camera": [6.0, 2.6], "monsters": [["oni", 0.45], ["ninja", 0.3], ["kitsune", 0.25]],
        "boss": "drake", "boss_hp": 25, "alarm_sound": "gong",
        "title": "SAMURAJ", "names": {"oni": "Oni", "ninja": "Ninjor", "kitsune": "Kitsune", "drake": "Draken"},
        "found": "Du hittade den hemliga dojon bakom vattenfallet! Nu är du en samuraj med kaststjärnor.",
        "alarm": "Yokai vaknar i skymningen! Kasta stjärnor med %s.",
        "boss_in": "En drake slingrar sig över staden! Tjugofem träffar fäller den.",
        "boss_down": "Draken är besegrad! +500",
        "knocked": "Samurajen har fallit! Dojon skickar en ny …",
        "new": "En ny samuraj från dojon. Vidare!",
    }


# --- Ground --------------------------------------------------------------------------------------

static func river_x(z: float) -> float:
    return 300.0 + 28.0 * sin(z / 190.0 + 1.0)


static func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
    var ab := b - a
    var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-4), 0.0, 1.0)
    return p.distance_to(a + ab * t)


## 1 in the rice terraces of the south-west.
static func _rice(x: float, z: float) -> float:
    return 1.0 - smoothstep(170.0, 240.0, Vector2(x, z).distance_to(Vector2(-330, 520)))


static func _city(x: float, z: float) -> float:
    return smoothstep(420.0, 470.0, x) * (1.0 - smoothstep(140.0, 220.0, z))


## Where Tokyo Bay's water begins at this z (see SHORE).
static func shore_x(z: float) -> float:
    for k in range(1, SHORE.size()):
        var b: Array = SHORE[k]
        if z <= float(b[0]):
            var a: Array = SHORE[k - 1]
            return lerpf(a[1], b[1], smoothstep(float(a[0]), float(b[0]), z))
    return SHORE[SHORE.size() - 1][1]


## Metres from the lake's shore (negative out on the water).
static func lake_d(x: float, z: float) -> float:
    var e := Vector2((x - LAKE.x) / LAKE_R.x, (z - LAKE.y) / LAKE_R.y)
    return (e.length() - 1.0) * minf(LAKE_R.x, LAKE_R.y) * (1.0 + 0.6 * clampf(e.length() - 1.0, 0.0, 1.0))


func natural(x: float, z: float) -> float:
    var h := 3.0 + _noise.get_noise_2d(x * 0.5, z * 0.5) * 1.0
    # Mountains round the map, forested ridges: the far west, north beyond the lake, south behind
    # the waterfall, round the gassho valley, and far south past the port. The north-east and the
    # south-east are Tokyo Bay.
    var mount := smoothstep(-1270.0, -1450.0, x)
    mount = maxf(mount, smoothstep(-1040.0, -1200.0, z) * (1.0 - smoothstep(250.0, 450.0, x)))
    mount = maxf(mount, smoothstep(630.0, 760.0, z) * smoothstep(-560.0, -440.0, x) * (1.0 - smoothstep(380.0, 540.0, x)))
    mount = maxf(mount, smoothstep(960.0, 1100.0, z) * (1.0 - smoothstep(-560.0, -420.0, x)))
    mount = maxf(mount, smoothstep(1080.0, 1250.0, z))
    if mount > 0.0:
        var ridge := _noise.get_noise_2d(x * 0.35 + 77.0, z * 0.35) * 0.5 + 0.5
        h += mount * (30.0 + ridge * 50.0)
    # The western uplands: up from the lake to the pass, then hills of tea falling away south to the
    # castle plain.
    var west := smoothstep(-820.0, -1000.0, x)
    if west > 0.0 and z < 220.0:
        var fade := 1.0 - smoothstep(40.0, 200.0, z)
        var up := 40.0 * smoothstep(-830.0, -560.0, z) * (1.0 - 0.7 * smoothstep(-560.0, 40.0, z)) * fade
        up += 3.5 * sin(x / 37.0) * sin(z / 53.0) * smoothstep(-560.0, -420.0, z) * fade
        h += up * west
    # A low saddle the road climbs over out of the gassho valley.
    h += 11.0 * exp(-Vector2(x + 700.0, z - 790.0).length_squared() / (110.0 * 110.0))
    # The temple hill.
    h += 26.0 * (1.0 - smoothstep(60.0, 190.0, Vector2(x, z).distance_to(TEMPLE_HILL)))
    # Gentle rise over the old town and the countryside.
    h += smoothstep(250.0, -150.0, x) * 4.0 * (1.0 - _city(x, z))
    # Rice terraces: steps of 1.3 m on a slope rising to the south-west.
    var rice := _rice(x, z)
    if rice > 0.0:
        var slope := 4.0 + maxf(0.0, (-x - 250.0) * 0.03) + maxf(0.0, (z - 480.0) * 0.04)
        h = lerpf(h, floorf(slope / 1.3) * 1.3 + 0.25, rice)
    # The gassho valley's paddies: flat steps of water and green.
    var dg := Vector2(x, z).distance_to(GASSHO)
    if dg < 260.0:
        h = lerpf(h, floorf((h + 0.6) / 0.9) * 0.9 + 0.2, 1.0 - smoothstep(160.0, 250.0, dg))
    # Tokyo is flat, and Tokyo Bay opens to the east, and round the north-east corner.
    var city := _city(x, z)
    h = lerpf(h, 3.0, city)
    var sx := shore_x(z)
    var sea := maxf(smoothstep(sx - 40.0, sx + 40.0, x), smoothstep(-1020.0, -1090.0, z) * smoothstep(380.0, 520.0, x))
    h = lerpf(h, -7.0, sea)
    # The lake, with soft banks; the shore road runs low along it.
    var dl := lake_d(x, z)
    if dl < 160.0:
        h = lerpf(h, minf(h, 2.2 + maxf(h - 7.5, 0.0)), 1.0 - smoothstep(25.0, 160.0, dl))
    if dl < 30.0:
        var lbed := lerpf(-6.0, 1.0, smoothstep(-40.0, 0.0, dl))
        h = lerpf(lbed, h, smoothstep(0.0, 30.0, dl)) if dl > 0.0 else lbed
    # The canal under the teleport bridge.
    if absf(z - CANAL.y) < 12.0 and absf(x - CANAL.x) < 60.0:
        h = lerpf(h, -2.5, smoothstep(9.0, 5.0, absf(z - CANAL.y)) * smoothstep(60.0, 48.0, absf(x - CANAL.x)))
    # The castle on its plateau inside the moat.
    var dc := Vector2(x, z).distance_to(CASTLE)
    if dc < 120.0:
        h = lerpf(9.0, h, smoothstep(80.0, 120.0, dc))
        if dc > 38.0 and dc < 58.0:
            h = lerpf(h, -2.5, smoothstep(38.0, 42.0, dc) * smoothstep(58.0, 54.0, dc))
    # The koi pond in the old town.
    var dp := Vector2(x, z).distance_to(POND)
    if dp < 32.0:
        h = lerpf(-1.6, h, smoothstep(18.0, 30.0, dp))
    # Flat ground at the foot of the waterfall, the gorge behind it and the hidden valley.
    var df := Vector2(x, z).distance_to(FALL)
    h = lerpf(6.0, h, smoothstep(26.0, 44.0, df))
    if absf(x - FALL.x) < 9.0 and z > FALL.y and z < VALLEY.y:
        h = lerpf(6.5, h, smoothstep(4.5, 9.0, absf(x - FALL.x)))
    var dv := Vector2(x, z).distance_to(VALLEY)
    h = lerpf(7.0, h, smoothstep(20.0, 34.0, dv))
    # Flat pads on the temple hill for the hall and the pagoda.
    for pad: Vector3 in [Vector3(-300, 0, -440), Vector3(-225, 0, -455)]:
        var d := Vector2(x - pad.x, z - pad.z).length()
        if d < 40.0:
            h = lerpf(29.0, h, smoothstep(18.0, 38.0, d))
    # The river with soft banks.
    var dr := absf(x - river_x(z)) - RIVER_HALF
    if dr < 30.0:
        var bed := lerpf(-5.0, 1.0, smoothstep(-26.0, 0.0, dr))
        h = lerpf(bed, h, smoothstep(0.0, 30.0, dr)) if dr > 0.0 else bed
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
    var x := centre.x
    var z := centre.z
    var y := centre.y
    var col: Color
    if y < -1.0:
        col = JCOL["botten"]
    elif y < 0.6:
        col = JCOL["strand"]
    else:
        var veg := _noise.get_noise_2d(x * 0.9 + 300.0, z * 0.9)
        if _city(x, z) > 0.5:
            col = JCOL["stad"] if fposmod(floorf(x / 12.0) + floorf(z / 12.0), 2.0) < 1.0 else JCOL["stad_ljus"]
        elif (_rice(x, z) > 0.5 or Vector2(x, z).distance_to(GASSHO) < 200.0) and n.y > 0.97:
            var cell := Vector2i(floori(x / 22.0), floori(y / 1.3))
            var pick := fposmod(sin(cell.x * 12.9898 + cell.y * 78.233) * 43758.5453, 1.0)
            col = JCOL["risvatten"] if pick < 0.5 else JCOL["ris"]
        elif TEA.has_point(Vector2(x, z)) and y > 8.0:
            col = JCOL["te"].lerp(JCOL["te_mork"], clampf(veg + 0.5, 0.0, 1.0))
        elif n.y < 0.8 and y > 12.0:
            col = JCOL["berg"]
        elif y > 14.0 or Vector2(x, z).distance_to(VALLEY) < 40.0:
            col = JCOL["skog"].lerp(JCOL["gras_mork"], clampf(veg + 0.5, 0.0, 1.0))
        elif _seg_dist(Vector2(x, z), OLD_TOWN[0], OLD_TOWN[1]) < 14.0 or Vector2(x, z).distance_to(TEMPLE_HILL) < 55.0:
            col = JCOL["sten"]
        else:
            col = JCOL["gras"].lerp(JCOL["gras_mork"], clampf(0.5 - veg, 0.0, 1.0))
        if road_d < 4.6 and _city(x, z) < 0.5:
            col = col.lerp(JCOL["damm"], 0.5)
    var jitter := fposmod(sin(centre.x * 12.9898 + centre.z * 78.233) * 43758.5453, 1.0)
    col = col.lightened(jitter * 0.03) if jitter > 0.5 else col.darkened(jitter * 0.03)
    for k in 3:
        colors.append(col)


# --- Light: dusk ---------------------------------------------------------------------------------

func _build_environment() -> void:
    var sky_mat := ShaderMaterial.new()
    sky_mat.shader = JP_SKY
    sky_mat.set_shader_parameter("zenith_color", Color(0.10, 0.14, 0.36))
    sky_mat.set_shader_parameter("high_color", Color(0.34, 0.30, 0.60))
    sky_mat.set_shader_parameter("horizon_color", Color(1.0, 0.55, 0.48))
    sky_mat.set_shader_parameter("sun_side_color", Color(1.0, 0.58, 0.32))
    sky_mat.set_shader_parameter("ground_color", Color(0.32, 0.27, 0.32))
    var sky := Sky.new()
    sky.sky_material = sky_mat
    sky.radiance_size = Sky.RADIANCE_SIZE_256
    var env := Environment.new()
    env.background_mode = Environment.BG_SKY
    env.sky = sky
    env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
    # Golden hour rather than deep dusk (the painted textures drowned in the dark), and a warm lilac
    # fill mixed into the sky light so shadowed streets and slopes are not near black.
    env.ambient_light_energy = 1.35
    env.ambient_light_color = Color(0.62, 0.5, 0.58)
    env.ambient_light_sky_contribution = 0.55
    env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
    env.tonemap_mode = Environment.TONE_MAPPER_ACES
    env.tonemap_exposure = 1.08
    env.tonemap_white = 6.0
    env.ssao_enabled = true
    env.ssao_radius = 1.6
    env.ssao_intensity = 1.5
    env.glow_enabled = true
    env.glow_intensity = 0.8
    env.glow_bloom = 0.08
    env.glow_hdr_threshold = 1.0
    env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
    env.fog_enabled = true
    env.fog_light_color = Color("8a86b8")
    env.fog_light_energy = 0.8
    env.fog_sun_scatter = 0.3
    env.fog_density = 0.00022
    env.fog_aerial_perspective = 0.45
    env.fog_sky_affect = 0.1
    env.adjustment_enabled = true
    env.adjustment_saturation = 1.15
    env.adjustment_contrast = 1.08
    env.ssil_enabled = true
    env.ssil_intensity = 1.0
    env.ssil_radius = 6.0
    environment = env
    var world_env := WorldEnvironment.new()
    world_env.environment = env
    add_child(world_env)
    _build_clouds()
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-15.0, -120.0, 0.0)
    sun.light_color = Color("ffa77a")
    sun.light_energy = 2.3
    # Crisp shadows: with the sun this low, any angular size gave a penumbra tens of metres wide that
    # the soft-shadow filter fills with grain (it was grainy all over the shaded slopes and streets).
    sun.light_angular_distance = 0.0
    sun.shadow_enabled = true
    sun.shadow_blur = 1.2
    sun.directional_shadow_max_distance = 220.0
    sun.directional_shadow_split_1 = 0.06
    sun.directional_shadow_split_2 = 0.18
    sun.directional_shadow_split_3 = 0.45
    sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
    add_child(sun)
    _build_fuji()


## Mount Fuji on the north-western horizon: a broad cone with a concave profile, gullies down its
## flanks and a ragged snow cap, far enough away for the haze to turn it blue.
func _build_fuji() -> void:
    var centre := Vector3(-900.0, -60.0, -3500.0)
    var radius := 1750.0
    var top := 1100.0
    var n := 72
    var rings := 14
    var verts := PackedVector3Array()
    var colors := PackedColorArray()
    var pts := []
    for r in rings + 1:
        var t := float(r) / rings
        var row := []
        for k in n:
            var a := TAU * k / n
            var gully := 1.0 + 0.04 * sin(a * 9.0) + 0.02 * sin(a * 23.0)
            var rr := radius * (1.0 - t) * gully + 90.0 * t
            var y := top * pow(t, 1.7) * (1.0 - 0.05 * (1.0 - t) * sin(a * 9.0))
            row.append(centre + Vector3(cos(a) * rr, y, sin(a) * rr))
        pts.append(row)
    for r in rings:
        for k in n:
            var a: Vector3 = pts[r][k]
            var b: Vector3 = pts[r][(k + 1) % n]
            var c: Vector3 = pts[r + 1][(k + 1) % n]
            var d: Vector3 = pts[r + 1][k]
            for tri: Array in [[a, c, b], [a, d, c]]:
                verts.append_array(tri)
                var mid: Vector3 = (tri[0] + tri[1] + tri[2]) / 3.0
                var snowline := top * (0.55 + 0.1 * sin(atan2(mid.z - centre.z, mid.x - centre.x) * 7.0))
                var col := Color("f6f8fc") if mid.y - centre.y > snowline else Color("3e4a68").lerp(Color("5a6688"), (mid.y - centre.y) / top)
                for m in 3:
                    colors.append(col)
    var mesh := _mesh(verts, colors, 0.9)
    mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(mesh)


# --- Places --------------------------------------------------------------------------------------

func _place_props() -> void:
    _init_network()
    _place_jp_teleport()
    _place_neon_street()
    _place_living_city()
    _place_odaiba()
    _place_tokyo()
    _place_old_town()
    _place_temple()
    _place_onsen()
    _place_lake()
    _place_iroha()
    _place_tea()
    _place_castle()
    _place_sumo_village()
    _place_gassho()
    _place_waterfall()
    _place_port()
    _place_lanes()
    _index_paths()
    _place_railway()
    _place_street_life()
    _place_more_life()
    _place_living()
    if not _gravel_verts.is_empty():
        add_child(_mesh(_gravel_verts, _gravel_cols, 1.0))


## Stand things along the lap between two points: `each(s, i, right)` every `step` metres.
func _along(a: Vector2, b: Vector2, step: float, each: Callable) -> void:
    var s0 := _nearest_s(a)
    var s1 := _nearest_s(b)
    if s1 < s0:
        s1 += length
    var s := s0
    while s < s1:
        var i := int(fposmod(s, length) / STEP)
        each.call(s, i, _right(i))
        s += step


## The start: a street of neon blocks with glowing boards and their writing, lit windows above.
func _place_neon_street() -> void:
    var tf := {}
    var k := [0]
    _along(NEON_STREET[0], NEON_STREET[1], 13.0, func(_s: float, i: int, right: Vector3) -> void:
        for side: float in [-1.0, 1.0]:
            var p: Vector3 = road_pos[i] + right * side * 13.0
            var face := -right * side
            var name := "neonhus_%d" % (1 + (k[0] + int(side + 1.0)) % 3)
            _add_tf(tf, name, Vector3(p.x, 3.0, p.z), atan2(face.x, face.z))
            _block(p.x, p.z, 6.5)
            _keep(Vector2(p.x, p.z), 8.0)
            var label := Label3D.new()
            label.text = NEON_TEXT[(k[0] * 2 + int(side + 1.0)) % NEON_TEXT.size()]
            label.font_size = 160
            label.pixel_size = 0.012
            label.outline_size = 18
            label.outline_modulate = Color(0, 0, 0, 0.5)
            label.modulate = Color(1.0, 1.0, 1.0)
            # Just in front of the flat boards, which sit on the facade (6 m from the centre).
            label.position = Vector3(p.x, 3.0 + 9.0 + (k[0] % 3) * 3.0, p.z) + face * 6.4
            label.rotation.y = atan2(face.x, face.z)
            label.visibility_range_end = 450.0
            add_child(label)
            if (k[0] + int(side)) % 4 == 0:
                _blinks.append([label, randf() * TAU])
        if k[0] % 2 == 0:
            var lp: Vector3 = road_pos[i] + right * 5.0
            _add_tf(tf, "automat", Vector3(lp.x, height(lp.x, lp.z), lp.z), atan2(-right.x, -right.z))
        k[0] += 1)
    _flush_tf(tf)


## Tokyo: glass towers on a jittered grid off the roads, street lamps, and Tokyo Tower.
func _place_tokyo() -> void:
    _prop("tokyotorn", Vector3(TOWER.x, 3.0, TOWER.y), 0.2)
    _keep(TOWER, 40.0)
    for k in 4:
        var a := k * PI * 0.5 + 0.2
        _block(TOWER.x + cos(a) * 24.0, TOWER.y + sin(a) * 24.0, 3.0)
    var tf := {}
    var rng := RandomNumberGenerator.new()
    rng.seed = 23
    var x := 460.0
    while x < 1100.0:
        var z := -1000.0
        while z < 150.0:
            var p := Vector2(x + rng.randf_range(-4.0, 4.0), z + rng.randf_range(-4.0, 4.0))
            z += 46.0
            if _city(p.x, p.y) < 0.9 or float(_nearest_road(p.x, p.y)[0]) < 32.0 or not _free_spot(p.x, p.y, 18.0):
                continue
            if height(p.x, p.y) < 2.0 or height(p.x + 20.0, p.y) < 1.0 or height(p.x, p.y - 20.0) < 1.0:
                continue      # the waterfront
            var name := "skyskrapa_%d" % (1 + rng.randi() % 3)
            if p.x < 560.0 and rng.randf() < 0.5:
                name = "neonhus_%d" % (1 + rng.randi() % 3)
            _add_tf(tf, name, Vector3(p.x, 3.0, p.y), rng.randi_range(0, 3) * PI * 0.5)
            _block(p.x, p.y, 17.0)
            _keep(p, 20.0)
        x += 46.0
    _flush_tf(tf)
    var lamps := {}
    for i in range(0, road_pos.size(), 13):
        var q: Vector3 = road_pos[i]
        if _city(q.x, q.z) < 0.5:
            continue
        for side: float in [-1.0, 1.0]:
            var lp: Vector3 = q + _right(i) * side * 4.6
            _add_tf(lamps, "gatlykta", Vector3(lp.x, height(lp.x, lp.z), lp.z), atan2(_right(i).z * side, -_right(i).x * side))
    _flush_tf(lamps)


## The old town: machiya on both sides, lantern strings across, ramen stalls, stone lanterns,
## and the koi pond with its drum bridge; a big torii at the bridgehead.
func _place_old_town() -> void:
    var tf := {}
    var k := [0]
    _along(OLD_TOWN[0], OLD_TOWN[1], 7.0, func(_s: float, i: int, right: Vector3) -> void:
        for side: float in [-1.0, 1.0]:
            var p: Vector3 = road_pos[i] + right * side * 8.6
            var face := -right * side
            _add_tf(tf, "machiya_%d" % (1 + (k[0] + int(side + 1.0)) % 3), Vector3(p.x, height(p.x, p.z) - 0.2, p.z), atan2(face.x, face.z))
            _block(p.x, p.z, 3.4)
            _keep(Vector2(p.x, p.z), 5.0)
        if k[0] % 2 == 0:
            _add_tf(tf, "lyktsnore", Vector3(road_pos[i].x, road_pos[i].y, road_pos[i].z), atan2(-right.z, right.x))
        if k[0] % 5 == 2:
            var yp: Vector3 = road_pos[i] + right * 4.4
            _add_tf(tf, "yatai", Vector3(yp.x, height(yp.x, yp.z), yp.z), atan2(-right.x, -right.z))
        if k[0] % 4 == 1:
            var sp: Vector3 = road_pos[i] - right * 4.4
            _add_tf(tf, "stenlykta", Vector3(sp.x, height(sp.x, sp.z), sp.z), 0.0)
        k[0] += 1)
    _flush_tf(tf)
    var g := _road_at(OLD_TOWN[0])
    var gp: Vector3 = (g["pos"] as Vector3) + (g["dir"] as Vector3) * 16.0
    var gd: Vector3 = g["dir"]
    var gate := _scene("torii_stor")
    gate.position = Vector3(gp.x, height(gp.x, gp.z), gp.z)
    gate.rotation.y = atan2(-gd.z, gd.x)
    add_child(gate)
    for side: float in [-1.0, 1.0]:
        var q: Vector3 = gp + (g["right"] as Vector3) * side * 4.8
        _block(q.x, q.z, 0.8)
    # The garden: koi pond, drum bridge, pines and lanterns.
    var pond_h := height(POND.x, POND.y)
    _prop("taikobashi", Vector3(POND.x, maxf(pond_h, 0.0), POND.y), 0.3)
    for k2 in 6:
        var a := k2 * TAU / 6.0 + 0.3
        var q := POND + Vector2(cos(a), sin(a)) * 27.0
        _prop("tall_jp_%d" % (1 + k2 % 2) if k2 % 2 else "stenlykta", _ground(q.x, q.y), a)
    _keep(POND, 30.0)
    # Geishas strolling along both pavements of the old town street.
    for w in 6:
        var side := -1.0 if w % 2 else 1.0
        var path: Array = []
        _along(OLD_TOWN[0], OLD_TOWN[1], 6.0, func(_s: float, i: int, right: Vector3) -> void:
            var p: Vector3 = road_pos[i] + right * side * 4.3
            path.append(Vector3(p.x, height(p.x, p.z), p.z)))
        if path.size() < 4:
            continue
        var node := _scene("geisha")
        add_child(node)
        _walkers.append([node, path, randf() * (path.size() - 1), randf_range(0.75, 1.0), 1.0 if w < 3 else -1.0])


## The torii tunnel up the hill, the temple hall and the five-storey pagoda at the top.
func _place_temple() -> void:
    var tf := {}
    _along(TORII_TUNNEL[0], TORII_TUNNEL[1], 2.6, func(_s: float, i: int, right: Vector3) -> void:
        var d := Vector3(road_dir[i].x, 0, road_dir[i].z).normalized()
        var p: Vector3 = road_pos[i]
        tf["torii"] = tf.get("torii", [])
        tf["torii"].append(Transform3D(Basis(Vector3.UP, atan2(-d.z, d.x)).scaled(Vector3.ONE * 1.3), Vector3(p.x, p.y - 0.15, p.z)))
        for side: float in [-1.0, 1.0]:
            var q: Vector3 = p + right * side * 3.1
            _block(q.x, q.z, 0.4)
            _keep(Vector2(q.x, q.z), 1.2))
    _flush_tf(tf)
    var hall := Vector2(-300, -440)
    var to_road := (Vector2(-300, -350) - hall).normalized()
    _prop("tempelhall", Vector3(hall.x, height(hall.x, hall.y) - 0.3, hall.y), atan2(to_road.x, to_road.y))
    _keep(hall, 24.0)
    _prop("pagod5", _ground(-225.0, -455.0), 0.3)
    _keep(Vector2(-225, -455), 12.0)
    for k in 8:
        var t := k / 7.0
        var q := hall.lerp(Vector2(-290, -360), t) + Vector2(6.0, 0.0) * (1.0 if k % 2 else -1.0)
        _prop("stenlykta", _ground(q.x, q.y), 0.0)


func _place_castle() -> void:
    _prop("slott", Vector3(CASTLE.x, 9.0 - 0.3, CASTLE.y), 0.25)
    _keep(CASTLE, 60.0)


## The village by the rice terraces: farmhouses, a little shrine torii, and the sumo ring with
## two wrestlers stamping and the referee.
func _place_sumo_village() -> void:
    var c := VILLAGE
    _prop("dohyo", _ground(c.x, c.y), 0.2)
    _keep(c, 10.0)
    for side: float in [-1.0, 1.0]:
        var node := _scene("sumo")
        node.position = _ground(c.x + side * 1.3, c.y) + Vector3.UP * 0.6
        node.rotation.y = 0.2 + (0.0 if side > 0 else PI)
        add_child(node)
        _sumo.append([node, 0.0 if side > 0 else 1.5])
    var ref := _scene("gyoji")
    ref.position = _ground(c.x, c.y + 1.8) + Vector3.UP * 0.6
    ref.rotation.y = PI * 0.5
    add_child(ref)
    var houses := [[-40.0, -30.0, 0.4], [35.0, -40.0, -0.2], [55.0, 25.0, 1.2], [-55.0, 30.0, 2.6]]
    for e in houses:
        var p := Vector2(c.x + e[0], c.y + e[1])
        _prop("machiya_3", _ground_low(p.x, p.y), e[2])
    _prop("torii", _ground(c.x - 20.0, c.y + 45.0), 1.0)


## The hidden valley lies past the free-riding margin of the core (z 710): open the gorge behind the
## waterfall and the valley, or the path stops dead just behind the falling water.
func _in_ride_area(x: float, z: float) -> bool:
    return super(x, z) or (absf(x - VALLEY.x) < 34.0 and z > FALL.y and z < VALLEY.y + 16.0)


## The waterfall, the small pagoda in front of it, the path that leads there, and — behind the
## falling water — the gorge into the hidden valley with the dojo and the samurai.
func _place_waterfall() -> void:
    var fall := _scene("vattenfall")
    fall.position = Vector3(FALL.x, 6.0, FALL.y + 4.0)
    fall.rotation.y = PI * 0.5             # the cliff faces north (towards the road)
    add_child(fall)
    for side: float in [-1.0, 1.0]:
        for t: float in [7.5, 13.0, 19.0]:
            _block(FALL.x + side * t, FALL.y + 12.0, 5.0)
    _prop("pagod3", _ground(FALL.x - 42.0, FALL.y - 30.0), 0.2)
    var r := _road_at(Vector2(FALL.x - 20.0, 615.0))
    var i0 := int(float(r["s"]) / STEP) % road_pos.size()
    var p0 := road_pos[i0]
    var ctrl := [p0 + _right(i0) * 2.9, Vector3(FALL.x - 14.0, 0, FALL.y - 30.0), Vector3(FALL.x - 2.0, 0, FALL.y - 6.0),
        Vector3(FALL.x, 0, FALL.y + 8.0), Vector3(FALL.x, 0, VALLEY.y - 16.0), Vector3(VALLEY.x, 0, VALLEY.y - 6.0)]
    _add_path("Vattenfallsstigen", i0, _gravel(ctrl, 2.4))
    _prop("dojo", _ground(VALLEY.x, VALLEY.y + 10.0), PI)
    for side: float in [-1.0, 1.0]:
        _prop("stenlykta", _ground(VALLEY.x + side * 7.0, VALLEY.y), 0.0)
        _prop("korsbar_%d" % (1 if side > 0 else 2), _ground(VALLEY.x + side * 16.0, VALLEY.y + 4.0), side)
    _keep(VALLEY, 22.0)
    base_tank = _scene("samurai")
    base_tank.position = _ground(VALLEY.x, VALLEY.y - 2.0)
    base_tank.rotation.y = PI * 0.5         # facing back out towards the gorge (north)
    add_child(base_tank)


## The bullet-train viaduct across the map and two trains on it, one each way.
func _place_railway() -> void:
    var a := Vector3(RAIL[0].x, 0, RAIL[0].y)
    var b := Vector3(RAIL[1].x, 0, RAIL[1].y)
    var span := a.distance_to(b)
    var dir := (b - a) / span
    var n := int(span / 20.0)
    _rail_y.resize(n + 1)
    for k in n + 1:
        var p := a + dir * (k * 20.0)
        _rail_y[k] = maxf(height(p.x, p.z), 0.5)
    var smooth := _rail_y.duplicate()
    for k in n + 1:
        var sum := 0.0
        var cnt := 0
        for j in range(maxi(k - 3, 0), mini(k + 4, n + 1)):
            sum += _rail_y[j]
            cnt += 1
        smooth[k] = sum / cnt
    _rail_y = smooth
    var tf := []
    var yaw := atan2(-dir.z, dir.x)
    for k in n:
        var p := a + dir * (k * 20.0 + 10.0)
        var lane := road_near(p.x, p.z)
        if float(_nearest_road(p.x, p.z)[0]) < 6.0 or (not lane.is_empty() and float(lane["d"]) < 7.0):
            continue
        var y := (_rail_y[k] + _rail_y[k + 1]) * 0.5
        tf.append(Transform3D(Basis(Vector3.UP, yaw), Vector3(p.x, y, p.z)))
        _block(p.x, p.z, 1.6)
    add_child(_multimesh(_merged(_model_mesh("viadukt")), tf))
    for t in 2:
        var cars: Array = []
        for c in 6:
            var car := _scene("shinkansen")
            add_child(car)
            cars.append(car)
        _trains.append([cars, span * (0.42 if t == 0 else 0.6) + 200.0, 48.0 * (1.0 if t == 0 else -1.0), 1.4 * (1.0 if t == 0 else -1.0)])


func _rail_at(u: float) -> Vector3:
    var a := Vector3(RAIL[0].x, 0, RAIL[0].y)
    var b := Vector3(RAIL[1].x, 0, RAIL[1].y)
    var span := a.distance_to(b)
    var f := clampf(u / 20.0, 0.0, float(_rail_y.size() - 1) - 0.001)
    var k := int(f)
    var y := lerpf(_rail_y[k], _rail_y[mini(k + 1, _rail_y.size() - 1)], f - k)
    return a + (b - a) / span * u + Vector3.UP * (y + 10.25)


## A small stone bridge over the canal west of the neon street, through a glowing torii (to
## Skärgården). The bridge lies deep among Tokyo's blocks, so Portgatan leads to it: a lane straight
## from the road north of the city, kept clear of buildings, with a sign at the turn.
func _place_jp_teleport() -> void:
    var c := CANAL
    var north := Vector3(c.x, 3.4, c.y - 22.0)
    _teleport_bridge(north, Vector3(c.x, 3.4, c.y + 22.0), 0.5, "skargarden", "Till Skärgården")
    _keep(c, 34.0)
    var r := _road_at(Vector2(c.x, c.y - 140.0))
    var i0 := int(float(r["s"]) / STEP) % road_pos.size()
    var p0 := road_pos[i0]
    var out := Vector3(north.x - p0.x, 0.0, north.z - p0.z).normalized()
    var start := p0 + out * 2.9
    var end := north - out * 4.0
    _add_path("Portgatan", i0, _gravel([start, start.lerp(end, 0.5), end], 3.0))
    var n := maxi(int(start.distance_to(end) / 8.0), 1)
    for k in n + 1:
        var q := start.lerp(end, float(k) / n)
        _keep(Vector2(q.x, q.z), 8.0)
    var sp := p0 + out * 4.0 + Vector3(-out.z, 0.0, out.x) * 3.0
    var sign := _prop("skylt_vag_h", _ground(sp.x, sp.z), atan2(-out.x, -out.z))
    _sign_text(sign, "Portalen", Vector3(0.04, 2.175, 0.035), Color("1d1f22"), 30)


# --- The bigger Japan -----------------------------------------------------------------------------

var _planted := {}          # trees and tea placed with the places, added with the scattered plants
var _wheel: Node3D          # the turning part of the Ferris wheel
var _cruisers: Array = []   # boats going round: [boat, centre, radius x, radius z, angular speed, phase]
var _paved := false         # _gravel draws a paved lane instead of a gravel road while set


## The lap's sample nearest a point, and which side of the road the point lies (1 right, -1 left).
func _beside(p: Vector2) -> Array:
    var i := int(_nearest_s(p) / STEP) % road_pos.size()
    var right := _right(i)
    var side := 1.0 if right.dot(Vector3(p.x - road_pos[i].x, 0.0, p.y - road_pos[i].z)) >= 0.0 else -1.0
    return [i, side]


## Yaw that turns a model facing +Z (built facing -Y in Blender) towards `dir`.
static func _yaw_to(dir: Vector3) -> float:
    return atan2(dir.x, dir.z)


## A boat going round an ellipse on open water.
func _cruise(name: String, centre: Vector3, rx: float, rz: float, speed: float) -> void:
    var boat := _scene(name)
    add_child(boat)
    _cruisers.append([boat, centre, rx, rz, speed, randf() * TAU])


## Odaiba on the waterfront: the Ferris wheel turning with its lights, and pleasure boats on the bay.
func _place_odaiba() -> void:
    var wheel := _scene("pariserhjul")
    var r := _road_at(WHEEL)
    var to_road: Vector3 = (r["pos"] as Vector3) - Vector3(WHEEL.x, 0.0, WHEEL.y)
    to_road.y = 0.0
    wheel.position = Vector3(WHEEL.x, height(WHEEL.x, WHEEL.y), WHEEL.y)
    wheel.rotation.y = _yaw_to(to_road.normalized())
    add_child(wheel)
    _wheel = wheel.find_child("Hjul", true, false) as Node3D
    for k in 3:
        var off := Vector3(cos(wheel.rotation.y), 0.0, -sin(wheel.rotation.y)) * (k - 1) * 9.0
        _block(WHEEL.x + off.x, WHEEL.y + off.z, 6.5)
    _keep(WHEEL, 48.0)
    if diorama:
        return
    for k in 3:
        _cruise("yakatabune", Vector3(860.0 + k * 140.0, 0.12, -1140.0 - k * 25.0), 70.0, 28.0, 0.05 * (1.0 if k % 2 else -1.0))
    for k in 2:
        _cruise("yakatabune", Vector3(1230.0, 0.12, -760.0 + k * 260.0), 30.0, 90.0, 0.04 * (1.0 if k % 2 else -1.0))


## The onsen village north of the temple hill: the ryokan facing the road, a hot spring pool steaming
## beside it, a few inns and stalls along the road, lanterns, maples and ginkgo.
func _place_onsen() -> void:
    var b := _beside(ONSEN)
    var i: int = b[0]
    var out: Vector3 = _right(i) * float(b[1])
    var flat := Vector3(road_dir[i].x, 0.0, road_dir[i].z).normalized()
    var c: Vector3 = road_pos[i] + out * 22.0
    _prop("ryokan", _ground_low(c.x, c.z, 9.0), _yaw_to(-out))
    _keep(Vector2(c.x, c.z), 16.0)
    # The hot spring: a round pool of milky blue water behind a ring of stones, steaming.
    var pool := c + flat * 22.0 - out * 3.0     # beside the inn, in sight of the road
    var g := _ground_low(pool.x, pool.z, 5.0)
    var water := MeshInstance3D.new()
    var disc := CylinderMesh.new()
    disc.top_radius = 5.5
    disc.bottom_radius = 5.5
    disc.height = 0.4
    disc.radial_segments = 20
    var m := StandardMaterial3D.new()
    m.albedo_color = Color("9ad4d0")
    m.roughness = 0.08
    m.emission_enabled = true
    m.emission = Color("4a8a88")
    m.emission_energy_multiplier = 0.4
    disc.material = m
    water.mesh = disc
    water.position = g + Vector3.UP * 0.1
    add_child(water)
    var stones := {}
    for k in 14:
        var a := k * TAU / 14.0
        _add_tf(stones, "stenar_%d" % (1 + k % 3), g + Vector3(cos(a) * 6.2, -0.1, sin(a) * 6.2), a)
    _flush_tf(stones)
    _block(pool.x, pool.z, 6.0)
    _keep(Vector2(pool.x, pool.z), 9.0)
    _steam(g + Vector3.UP * 1.5, Vector3(4.5, 1.0, 4.5), 90)
    _onsen_pool = g
    _steam(c + Vector3.UP * 10.0 + out * 4.0, Vector3(8.0, 1.0, 3.0), 40)
    for side: float in [-1.0, 1.0]:
        var l: Vector3 = road_pos[i] + out * 8.0 + flat * side * 9.0
        _prop("stenlykta", _ground(l.x, l.z), 0.0)
        _keep(Vector2(l.x, l.z), 1.5)
    # The village street: inns and a stall on both sides either side of the ryokan.
    var tf := {}
    for k in 10:
        var s := float(i) * STEP + (-1.0 if k < 5 else 1.0) * (48.0 + (k % 5) * 14.0)
        var j := int(fposmod(s, length) / STEP)
        for side: float in [-1.0, 1.0]:
            if (k + int(side)) % 3 == 0:
                continue
            var p: Vector3 = road_pos[j] + _right(j) * side * 9.0
            if not _free_spot(p.x, p.z, 4.0):
                continue
            _add_tf(tf, "machiya_%d" % (1 + (k + int(side + 1.0)) % 3), Vector3(p.x, height(p.x, p.z) - 0.2, p.z), _yaw_to(-_right(j) * side))
            _block(p.x, p.z, 3.4)
            _keep(Vector2(p.x, p.z), 5.0)
    _flush_tf(tf)
    for e in [[30.0, 6.0, "ginkgo"], [-30.0, 7.0, "lonn"], [40.0, -9.0, "lonn"]]:
        var q: Vector3 = c + flat * float(e[0]) + out * float(e[1])
        _put(_planted, e[2], _ground(q.x, q.z))
        _keep(Vector2(q.x, q.z), 3.0)


## Steam rising from hot water: soft white puffs drifting up and fading.
func _steam(centre: Vector3, extents: Vector3, amount: int) -> void:
    if diorama:
        return
    var p := GPUParticles3D.new()
    p.amount = amount
    p.lifetime = 5.0
    p.preprocess = 5.0
    p.visibility_aabb = AABB(-extents - Vector3(2, 2, 2), extents * 2.0 + Vector3(4, 14, 4))
    var pm := ParticleProcessMaterial.new()
    pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
    pm.emission_box_extents = extents
    pm.direction = Vector3(0.2, 1.0, 0.1)
    pm.spread = 20.0
    pm.initial_velocity_min = 0.5
    pm.initial_velocity_max = 1.1
    pm.gravity = Vector3(0.15, 0.25, 0.0)
    pm.scale_min = 1.0
    pm.scale_max = 2.2
    var fade := Gradient.new()
    fade.set_color(0, Color(1, 1, 1, 0))
    fade.add_point(0.25, Color(1, 1, 1, 0.28))
    fade.set_color(fade.get_point_count() - 1, Color(1, 1, 1, 0))
    var ramp := GradientTexture1D.new()
    ramp.gradient = fade
    pm.color_ramp = ramp
    p.process_material = pm
    var q := QuadMesh.new()
    q.size = Vector2(2.2, 2.2)
    var m := StandardMaterial3D.new()
    m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
    m.vertex_color_use_as_albedo = true
    m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    m.albedo_color = Color(0.95, 0.96, 1.0)
    var tex := GradientTexture2D.new()
    var soft := Gradient.new()
    soft.set_color(0, Color(1, 1, 1, 1))
    soft.set_color(1, Color(1, 1, 1, 0))
    tex.gradient = soft
    tex.fill = GradientTexture2D.FILL_RADIAL
    tex.fill_from = Vector2(0.5, 0.5)
    tex.fill_to = Vector2(1.0, 0.5)
    m.albedo_texture = tex
    q.material = m
    p.draw_pass_1 = q
    p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    p.position = centre
    add_child(p)


## The lake: a great torii standing in the water off the shore road with Fuji beyond it, stone
## lanterns along the shore, a jetty with rowing boats, and pleasure boats going round.
func _place_lake() -> void:
    var t := LAKE_TORII
    var gate := _scene("torii_stor")
    gate.position = Vector3(t.x, minf(height(t.x, t.y), -0.6), t.y)
    gate.rotation.y = PI * 0.5            # the way through it points north, across the lake to Fuji
    gate.scale = Vector3.ONE * 1.25
    add_child(gate)
    var s0 := _nearest_s(Vector2(-450.0, -742.0))
    var s1 := _nearest_s(Vector2(-900.0, -785.0))
    var tf := {}
    var s := s0
    while s < s1:
        var i := int(s / STEP) % road_pos.size()
        var r := _right(i)
        var side := 1.0 if lake_d(road_pos[i].x + r.x * 8.0, road_pos[i].z + r.z * 8.0) < lake_d(road_pos[i].x, road_pos[i].z) else -1.0
        var p: Vector3 = road_pos[i] + r * side * 5.5
        if height(p.x, p.z) > 0.8 and _free_spot(p.x, p.z, 1.0):
            _add_tf(tf, "stenlykta", Vector3(p.x, height(p.x, p.z), p.z), 0.0)
            _block(p.x, p.z, 0.5)
            _keep(Vector2(p.x, p.z), 1.5)
        s += 46.0
    _flush_tf(tf)
    # The jetty below the road west of the torii, with rowing boats.
    var j := Vector2(-720.0, -760.0)
    var shore := Vector3(j.x, 0.0, j.y)
    for k in 40:
        if height(shore.x, shore.z) < 0.2:
            break
        shore.z -= 1.0
    var jetty := _scene("brygga")
    jetty.position = Vector3(shore.x, 0.5, shore.z - 3.0)
    _lake_jetty = jetty.position
    jetty.rotation.y = PI * 0.5
    add_child(jetty)
    for k in 3:
        _boat("roddbat", Vector3(shore.x - 4.0 + k * 3.5, 0.1, shore.z - 7.0 - k * 1.5), PI * 0.5 + k * 0.3)
    if diorama:
        return
    _cruise("yakatabune", Vector3(LAKE.x - 60.0, 0.12, LAKE.y - 10.0), 150.0, 55.0, 0.035)
    _cruise("yakatabune", Vector3(LAKE.x + 110.0, 0.12, LAKE.y + 15.0), 90.0, 40.0, -0.05)


## The Iroha hairpins: tall cedars lining the climb, Jizō statues and a shrine at the bends, and the
## tea house at the top looking out over the lake towards Fuji.
func _place_iroha() -> void:
    var s0 := _nearest_s(Vector2(-960.0, -835.0))
    var s1 := _nearest_s(PASS)
    var s := s0
    while s < s1 + 40.0:
        var i := int(s / STEP) % road_pos.size()
        for side: float in [-1.0, 1.0]:
            var q: Vector3 = road_pos[i] + _right(i) * side * _rng.randf_range(7.5, 10.5)
            if float(_nearest_road(q.x, q.z)[0]) > 6.5 and _free_spot(q.x, q.z, 3.0):
                _put(_planted, "sugi", _ground(q.x, q.z), 0.3)
                _keep(Vector2(q.x, q.z), 3.0)
        s += 11.0
    for bend: Vector2 in [Vector2(-1200.0, -725.0), Vector2(-975.0, -630.0)]:
        var b := _beside(bend)
        var i: int = b[0]
        var out: Vector3 = _right(i) * float(b[1])
        var q: Vector3 = road_pos[i] + out * 6.5
        _prop("jizo", _ground(q.x, q.z), _yaw_to(-out) - PI * 0.5)
        _keep(Vector2(q.x, q.z), 2.0)
        var h: Vector3 = road_pos[i] + out * 10.0 + Vector3(road_dir[i].x, 0.0, road_dir[i].z).normalized() * 4.0
        _prop("hokora", _ground(h.x, h.z), _yaw_to(-out))
        _keep(Vector2(h.x, h.z), 2.0)
    # The tea house on the lake side of the pass.
    var pi := int(_nearest_s(PASS) / STEP) % road_pos.size()
    var pr := _right(pi)
    var north := 1.0 if pr.z < 0.0 else -1.0
    var out2 := pr * north
    var ch: Vector3 = road_pos[pi] + out2 * 11.0
    _prop("chaya", _ground_low(ch.x, ch.z, 4.0), _yaw_to(-out2))
    _keep(Vector2(ch.x, ch.z), 8.0)
    var fl := Vector3(road_dir[pi].x, 0.0, road_dir[pi].z).normalized()
    for e in [[9.0, 7.0, "stenlykta"], [-9.0, 7.0, "stenlykta"], [14.0, 16.0, "lonn"], [-15.0, 15.0, "korsbar"]]:
        var q2: Vector3 = road_pos[pi] + fl * float(e[0]) + out2 * float(e[1])
        if e[2] == "stenlykta":
            _prop("stenlykta", _ground(q2.x, q2.z), 0.0)
        else:
            _put(_planted, e[2], _ground(q2.x, q2.z))
        _keep(Vector2(q2.x, q2.z), 2.5)


## The tea fields: clipped rows of tea bushes along the hills, wavy with the slope, with narrow
## gaps to walk between them; field edges follow the noise so the fields come in patches.
func _place_tea() -> void:
    var list: Array = []
    var z := TEA.position.y
    while z < TEA.end.y:
        var x := TEA.position.x
        while x < TEA.end.x:
            var px := x
            var wave := 2.6 * sin(px / 33.0 + z * 0.01)
            var pz := z + wave
            x += 5.9
            var edge := minf(minf(px - TEA.position.x, TEA.end.x - px), minf(pz - TEA.position.y, TEA.end.y - pz))
            if edge < 12.0 * (_noise.get_noise_2d(px * 2.0, pz * 2.0) + 1.0):
                continue
            if _noise.get_noise_2d(px * 1.3 + 500.0, pz * 1.3) < -0.35:
                continue      # a gap between fields
            var h := height(px, pz)
            if h < 8.0 or float(_nearest_road(px, pz)[0]) < 5.0 or not _free_spot(px, pz, 2.0):
                continue
            var slope := absf(height(px + 3.0, pz) - height(px - 3.0, pz)) / 6.0
            if slope > 0.35:
                continue
            var yaw := -atan(2.6 / 33.0 * cos(px / 33.0 + z * 0.01))
            list.append(Transform3D(Basis(Vector3.UP, yaw), Vector3(px, h - 0.12, pz)))
        z += 2.3
    _planted["tebuske_1"] = list
    # A few cherries and stone lanterns at the field edges along the road.
    var s := _nearest_s(Vector2(-1190.0, -460.0))
    var s1 := _nearest_s(Vector2(-980.0, -40.0))
    while s < s1:
        var i := int(s / STEP) % road_pos.size()
        var side := 1.0 if int(s / 97.0) % 2 == 0 else -1.0
        var q: Vector3 = road_pos[i] + _right(i) * side * 6.0
        if _free_spot(q.x, q.z, 2.0):
            if int(s / 97.0) % 3 == 0:
                _prop("stenlykta", _ground(q.x, q.z), 0.0)
            else:
                _put(_planted, "korsbar", _ground(q.x, q.z))
            _keep(Vector2(q.x, q.z), 3.0)
        s += 97.0


## The gassho valley: thatched farmhouses scattered among the paddies with their ridges running
## north–south like Shirakawa-gō, ginkgo by the houses, scarecrows and a shrine.
func _place_gassho() -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = 71
    var houses: Array[Vector2] = []
    for t in 600:
        if houses.size() >= 16:
            break
        var a := rng.randf() * TAU
        var r := sqrt(rng.randf()) * 230.0
        var p := GASSHO + Vector2(cos(a), sin(a)) * r
        var near := float(_nearest_road(p.x, p.y)[0])
        if near < 16.0 or (near > 70.0 and houses.size() < 10) or not _free_spot(p.x, p.y, 10.0):
            continue
        var ok := true
        for o in houses:
            if o.distance_to(p) < 34.0:
                ok = false
                break
        if not ok:
            continue
        houses.append(p)
        var yaw := PI * 0.5 + rng.randf_range(-0.15, 0.15)
        _prop("gassho", _ground_low(p.x, p.y, 7.0) - Vector3(0, 0.3, 0), yaw)
        _keep(p, 12.0)
        var g := p + Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)).normalized() * 15.0
        if _free_spot(g.x, g.y, 2.0):
            _put(_planted, "ginkgo" if rng.randf() < 0.6 else "korsbar", _ground(g.x, g.y))
            _keep(g, 3.0)
    var placed := 0
    for t in 200:
        if placed >= 6:
            break
        var p := GASSHO + Vector2(rng.randf_range(-170.0, 170.0), rng.randf_range(-170.0, 170.0))
        if float(_nearest_road(p.x, p.y)[0]) < 8.0 or not _free_spot(p.x, p.y, 3.0):
            continue
        _prop("kakashi", _ground(p.x, p.y), rng.randf() * TAU)
        _keep(p, 2.5)
        placed += 1
    var sh := _beside(GASSHO + Vector2(-60.0, -150.0))
    var si: int = sh[0]
    var so: Vector3 = _right(si) * float(sh[1])
    var tp: Vector3 = road_pos[si] + so * 12.0
    _prop("torii", _ground(tp.x, tp.z), atan2(-so.z, so.x))
    var hp: Vector3 = road_pos[si] + so * 20.0
    _prop("hokora", _ground(hp.x, hp.z), _yaw_to(-so))
    _keep(Vector2(hp.x, hp.z), 4.0)


## The fishing port: boats moored off the quay with their lamps, jetties, the breakwater out to
## the red harbour light, fishermen's houses and vans by the road.
func _place_port() -> void:
    var boats := 0
    var z := PORT.y - 70.0
    while z < PORT.y + 60.0:
        var wx := shore_x(z) - 12.0
        var jetty := _scene("brygga")
        jetty.position = Vector3(wx - 2.0, 0.5, z)
        jetty.rotation.y = 0.0
        add_child(jetty)
        for side: float in [-1.0, 1.0]:
            var b := _scene("fiskebat_jp")
            b.position = Vector3(wx + 14.0, 0.15, z + side * 5.5)
            b.rotation.y = PI if (boats % 2) else 0.0
            add_child(b)
            _bobbers.append([b, 0.15, boats * 1.1])
            boats += 1
        z += 26.0
    # The breakwater: a long line of concrete blocks with the light at its end.
    var start := Vector3(shore_x(PORT_LIGHT.y) - 14.0, 0.0, PORT_LIGHT.y)
    var end := Vector3(PORT_LIGHT.x, 0.0, PORT_LIGHT.y)
    var tf := []
    var n := int(start.distance_to(end) / 3.0)
    for k in n + 1:
        var p := start.lerp(end, float(k) / n)
        for side: float in [-1.0, 1.0]:
            var jit := sin(k * 3.7 + side) * 0.3
            tf.append(Transform3D(Basis(Vector3.UP, jit).scaled(Vector3(3.0, 3.4, 2.6)), Vector3(p.x, 0.6, p.z + side * 1.4)))
        _block(p.x, p.z, 3.0)
    var blocks := _multimesh(_box_mesh(Vector3.ONE, Color("a9a8a2")), tf)
    add_child(blocks)
    _prop("fyr_jp", Vector3(end.x + 3.0, 2.2, end.z), 0.0)
    # Fishermen's houses, vans and nets between the road and the quay.
    var htf := {}
    var k2 := 0
    var s := _nearest_s(Vector2(1008.0, 900.0))
    var s1 := _nearest_s(Vector2(975.0, 690.0))
    while s < s1:
        var i := int(s / STEP) % road_pos.size()
        var r := _right(i)
        # The houses stand on the land side, so the boats and the light are in view across the quay.
        var sea := 1.0 if (road_pos[i] + r * 10.0).x > road_pos[i].x else -1.0
        var p: Vector3 = road_pos[i] - r * sea * 11.0
        if k2 % 4 != 3 and _free_spot(p.x, p.z, 4.0) and height(p.x, p.z) > 1.0:
            _add_tf(htf, "machiya_%d" % (1 + k2 % 3), Vector3(p.x, height(p.x, p.z) - 0.2, p.z), _yaw_to(r * sea))
            _block(p.x, p.z, 3.4)
            _keep(Vector2(p.x, p.z), 5.0)
        var q: Vector3 = road_pos[i] + r * sea * 7.0
        if k2 % 3 == 1 and _free_spot(q.x, q.z, 2.0):
            var fl := Vector3(road_dir[i].x, 0.0, road_dir[i].z).normalized()
            _prop("keibil", _ground(q.x, q.z), atan2(-fl.z, fl.x))
            _keep(Vector2(q.x, q.z), 2.5)
        k2 += 1
        s += 17.0
    _flush_tf(htf)


## Paved lanes off the lap: shorter loops for free riding, each with a name sign at both ends.
func _place_lanes() -> void:
    _paved = true
    for lane in [
            ["Tvärvägen", Vector2(-460.0, -190.0), [Vector2(-370.0, -250.0), Vector2(-230.0, -250.0), Vector2(-100.0, -290.0), Vector2(-20.0, -360.0)], Vector2(20.0, -430.0)],
            ["Slottsvägen", Vector2(-540.0, -735.0), [Vector2(-560.0, -600.0), Vector2(-610.0, -460.0), Vector2(-650.0, -330.0)], Vector2(-680.0, -250.0)],
            ["Risvägen", Vector2(-560.0, 20.0), [Vector2(-470.0, 140.0), Vector2(-390.0, 270.0), Vector2(-335.0, 400.0)], Vector2(-300.0, 560.0)],
            ["Fältvägen", Vector2(480.0, 440.0), [Vector2(600.0, 320.0), Vector2(760.0, 260.0), Vector2(880.0, 180.0)], Vector2(1050.0, 100.0)]]:
        var a := int(_nearest_s(lane[1]) / STEP) % road_pos.size()
        var b := int(_nearest_s(lane[3]) / STEP) % road_pos.size()
        var pts: Array = lane[2]
        var first := Vector3(pts[0].x, 0.0, pts[0].y)
        var last := Vector3(pts[pts.size() - 1].x, 0.0, pts[pts.size() - 1].y)
        var pa := road_pos[a]
        var pb := road_pos[b]
        var ctrl: Array = [pa + Vector3(first.x - pa.x, 0.0, first.z - pa.z).normalized() * 2.9]
        for p: Vector2 in pts:
            ctrl.append(Vector3(p.x, 0.0, p.y))
        ctrl.append(pb + Vector3(last.x - pb.x, 0.0, last.z - pb.z).normalized() * 2.9)
        _add_path(lane[0], a, _gravel(ctrl, 3.4), b)
        for end in [[a, first], [b, last]]:
            var i: int = end[0]
            var to: Vector3 = end[1]
            var flat := Vector3(road_dir[i].x, 0, road_dir[i].z).normalized()
            var rr := _right(i)
            var right_turn := Vector2(rr.x, rr.z).dot(Vector2(to.x - road_pos[i].x, to.z - road_pos[i].z)) > 0.0
            var sp: Vector3 = road_pos[i] - flat * 10.0 + rr * 4.3
            var sign := _prop("skylt_vag_h" if right_turn else "skylt_vag_v", _ground(sp.x, sp.z), atan2(-flat.x, -flat.z))
            _sign_text(sign, lane[0], Vector3(0.04 * (1.0 if right_turn else -1.0), 2.175, 0.035), Color("1d1f22"), 30)
            _keep(Vector2(sp.x, sp.z), 1.2)
    _paved = false


## Japan's lanes are narrow and paved, with white edge lines (the waterfall path stays gravel).
func _gravel(ctrl: Array, width: float) -> PackedVector3Array:
    if not _paved:
        return super(ctrl, width)
    var pts: Array[Vector2] = []
    var n := ctrl.size()
    for i in n - 1:
        var a0 := Vector2((ctrl[maxi(i - 1, 0)] as Vector3).x, (ctrl[maxi(i - 1, 0)] as Vector3).z)
        var a1 := Vector2((ctrl[i] as Vector3).x, (ctrl[i] as Vector3).z)
        var a2 := Vector2((ctrl[i + 1] as Vector3).x, (ctrl[i + 1] as Vector3).z)
        var a3 := Vector2((ctrl[mini(i + 2, n - 1)] as Vector3).x, (ctrl[mini(i + 2, n - 1)] as Vector3).z)
        var steps := maxi(int(a1.distance_to(a2) / 1.5), 1)
        for k in steps:
            var t := float(k) / steps
            var t2 := t * t
            var t3 := t2 * t
            pts.append(0.5 * ((2.0 * a1) + (-a0 + a2) * t + (2.0 * a0 - 5.0 * a1 + 4.0 * a2 - a3) * t2
                + (-a0 + 3.0 * a1 - 3.0 * a2 + a3) * t3))
    var last: Vector3 = ctrl[n - 1]
    pts.append(Vector2(last.x, last.z))
    var hw := width / 2.0
    var across := [-hw - 0.4, -hw, -hw + 0.14, hw - 0.14, hw, hw + 0.4]
    var asphalt := Color("55555a")
    var line := Color("d8d8d0")
    var verge := Color("8a8270")
    var cols := [verge, line, asphalt, line, verge]
    var prev: Array = []
    var centre := PackedVector3Array()
    for k in pts.size():
        var d: Vector2 = (pts[mini(k + 1, pts.size() - 1)] - pts[maxi(k - 1, 0)]).normalized()
        var right := Vector2(-d.y, d.x)
        var row: Array = []
        for a in across:
            var p: Vector2 = pts[k] + right * float(a)
            row.append(Vector3(p.x, _mesh_height(p.x, p.y) + (0.05 if absf(a) > hw else 0.1), p.y))
        centre.append(((row[2] as Vector3) + (row[3] as Vector3)) * 0.5)
        if k % 2 == 0:
            _keep(pts[k], hw + 1.5)
        if not prev.is_empty():
            for c in cols.size():
                var p1: Vector3 = prev[c]
                var p2: Vector3 = prev[c + 1]
                var p3: Vector3 = row[c + 1]
                var p4: Vector3 = row[c]
                _gravel_verts.append_array([p1, p3, p2, p1, p4, p3])
                var col: Color = cols[c]
                var j := fposmod(sin(p1.x * 12.9898 + p1.z * 78.233) * 43758.5453, 1.0)
                col = col.lightened(j * 0.04) if j > 0.5 else col.darkened(j * 0.04)
                for m in 6:
                    _gravel_cols.append(col)
        prev = row
    return centre


# --- The living Japan (2026-11-09): people, animals, traffic and a festival -------------------------

var _drivers: Array = []     # vehicles on the oncoming lane: [node, s, speed (m/s, < 0 against the lap), lateral, s0, s1]
var _swayers: Array = []     # [node, base rotation, amplitude, speed, phase, axis: 0 bend forward, 1 turn]
var _movers: Array = []      # moving parts: [node, kind, phase]
var _lights: Array = []      # traffic lights: [green part, red part, phase]
var _onsen_pool := Vector3.ZERO
var _lake_jetty := Vector3.ZERO


## Hide a lively prop's meshes beyond `range` metres: people and animals are small, there is no need
## to draw them from across the map.
func _near(node: Node3D, range: float) -> Node3D:
    for g in node.find_children("*", "GeometryInstance3D", true, false):
        (g as GeometryInstance3D).visibility_range_end = range
    return node


## A lively prop: placed, turned and only drawn within `range` metres.
func _live(name: String, pos: Vector3, yaw: float, range := 200.0) -> Node3D:
    var node := _scene(name)
    node.position = pos
    node.rotation.y = yaw
    add_child(node)
    return _near(node, range)


## Yaw that turns a model facing +X (people, animals, vehicles) towards `dir`.
static func _face_x(dir: Vector3) -> float:
    return atan2(-dir.z, dir.x)


## Waypoints on the ground resampled every 6 m (what the walkers expect), there and back.
func _path6(points: Array) -> Array:
    var out: Array = []
    for k in range(points.size() - 1):
        var a: Vector2 = points[k]
        var b: Vector2 = points[k + 1]
        var n := maxi(int(a.distance_to(b) / 6.0), 1)
        for j in n:
            var p := a.lerp(b, float(j) / n)
            out.append(_ground(p.x, p.y))
    var last: Vector2 = points[points.size() - 1]
    out.append(_ground(last.x, last.y))
    return out


## A path along the lap from s0 to s1, `side` metres right of the centre line (6 m steps).
func _lap_path(s0: float, s1: float, side: float) -> Array:
    var out: Array = []
    var s := s0
    while s < s1:
        var i := int(fposmod(s, length) / STEP) % road_pos.size()
        var p: Vector3 = road_pos[i] + _right(i) * side
        out.append(Vector3(p.x, maxf(height(p.x, p.z), road_pos[i].y - 0.1) if absf(side) < 4.5 else height(p.x, p.z), p.z))
        s += 6.0
    return out


func _walk(name: String, path: Array, speed: float, t := -1.0, range := 180.0) -> Node3D:
    if path.size() < 3:
        return null
    var node := _scene(name)
    add_child(node)
    _near(node, range)
    _walkers.append([node, path, t if t >= 0.0 else randf() * (path.size() - 1), speed, 1.0 if randf() < 0.5 else -1.0])
    return node


func _drive(name: String, s0: float, s1: float, speed: float, lateral: float, count: int, range := 300.0) -> void:
    for k in count:
        var node := _scene(name)
        add_child(node)
        _near(node, range)
        _drivers.append([node, s0 + (s1 - s0) * (k + _rng.randf_range(0.1, 0.6)) / count, speed, lateral, s0, s1])


## Before Tokyo's towers are placed: the pachinko hall, the phone booths and the traffic lights claim
## their spots.
func _place_living_city() -> void:
    # The pachinko hall facing the lap just before the finish, its sign blinking.
    var i := int(_nearest_s(Vector2(720.0, 38.0)) / STEP) % road_pos.size()
    var r := _right(i)
    var c: Vector3 = road_pos[i] + r * 17.0
    var hall := _prop("pachinko", Vector3(c.x, 3.0, c.z), _yaw_to(-r))
    _keep(Vector2(c.x, c.z), 15.0)
    var sign := Label3D.new()
    sign.text = "パチンコ"
    sign.font_size = 240
    sign.pixel_size = 0.016
    sign.outline_size = 24
    sign.outline_modulate = Color(0.1, 0.0, 0.1, 0.8)
    sign.modulate = Color(1.0, 0.45, 0.85)
    sign.position = Vector3(0.0, 9.4, 4.75)
    sign.visibility_range_end = 500.0
    hall.add_child(sign)
    _blinks.append([sign, 0.4])
    # Traffic lights on the left verge, the lamps facing the rider: the neon street, the way into
    # Odaiba and the coast road into Tokyo.
    for at: Vector2 in [Vector2(618.0, -180.0), Vector2(1014.0, -475.0), Vector2(1073.0, 130.0)]:
        var j := int(_nearest_s(at) / STEP) % road_pos.size()
        var flat := Vector3(road_dir[j].x, 0.0, road_dir[j].z).normalized()
        var p: Vector3 = road_pos[j] - _right(j) * 3.6
        var light := _live("trafikljus", Vector3(p.x, height(p.x, p.z), p.z), atan2(flat.z, -flat.x), 400.0)
        _block(p.x, p.z, 0.3)
        _keep(Vector2(p.x, p.z), 2.0)
        _lights.append([light.find_child("Gron", true, false), light.find_child("Rod", true, false), randf() * 14.0])
    # Phone booths on the neon street's left pavement.
    for at: Vector2 in [Vector2(618.0, -140.0), Vector2(625.0, -300.0)]:
        var j := int(_nearest_s(at) / STEP) % road_pos.size()
        var p: Vector3 = road_pos[j] - _right(j) * 6.0
        _prop("telefonkiosk", Vector3(p.x, height(p.x, p.z), p.z), _yaw_to(_right(j)))
        _keep(Vector2(p.x, p.z), 1.5)


## People, animals and traffic all round the lap: a festival on the Odaiba waterfront, a rickshaw,
## schoolchildren and beckoning cats in the old town, a shrine maiden, deer and the bell at the
## temple, monkeys in the hot spring, swan boats and anglers at the lake, pilgrims on the hairpins,
## tea pickers, rice farmers and cranes, anglers and cats at the port, and taxis, kei trucks,
## mopeds and bikes on the road.
func _place_living() -> void:
    if diorama:
        return
    var rng := RandomNumberGenerator.new()
    rng.seed = 91
    # The festival on the Odaiba waterfront, between the road and the bay by the Ferris wheel.
    var fs0 := _nearest_s(Vector2(1000.0, -945.0))
    var fs1 := _nearest_s(Vector2(760.0, -975.0))
    var fi := int(fs0 / STEP)
    var sea := 1.0 if _right(fi).z < 0.0 else -1.0
    var stalls := ["kingyo", "yatai", "kingyo", "yatai"]
    for k in stalls.size():
        var s := fs0 + (fs1 - fs0) * (0.12 + k * 0.24)
        var i := int(s / STEP) % road_pos.size()
        var out := _right(i) * sea
        var p: Vector3 = road_pos[i] + out * 9.5
        if stalls[k] == "yatai":
            _prop("yatai", _ground(p.x, p.z), atan2(-out.x, -out.z))
            var v: Vector3 = p + out * 1.6
            _live("forsaljare", _ground(v.x, v.z), _face_x(-out))
        else:
            _prop("kingyo", _ground(p.x, p.z), _yaw_to(-out))
        _keep(Vector2(p.x, p.z), 3.0)
        for side: float in [-1.0, 1.0]:
            var fl := Vector3(road_dir[i].x, 0.0, road_dir[i].z).normalized()
            var b: Vector3 = p + fl * side * 3.2 - out * 1.0
            var banner := _live("nobori", _ground(b.x, b.z), atan2(-fl.x, -fl.z) + (PI if side > 0 else 0.0), 260.0)
            _swayers.append([banner, banner.rotation, 0.12, 1.6, rng.randf() * TAU, 1])
    for k in 2:
        var s := fs0 + (fs1 - fs0) * (0.35 + k * 0.3)
        var i := int(s / STEP) % road_pos.size()
        var out := _right(i) * sea
        var p: Vector3 = road_pos[i] + out * 17.0
        var drum := _live("taiko", _ground(p.x, p.z), _face_x(-out), 260.0)
        _block(p.x, p.z, 1.0)
        for arm in ["ArmV", "ArmH"]:
            _movers.append([drum.find_child(arm, true, false), "arm", k * 0.7 + (PI if arm == "ArmH" else 0.0)])
    _walk("mikoshi", _lap_path(fs0 + 20.0, fs1 - 20.0, 13.0 * sea), 0.45, -1.0, 300.0)
    for k in 3:
        _walk("yukatapar", _lap_path(fs0, fs1, (12.0 + k * 1.5) * sea), rng.randf_range(0.6, 0.8))
    # The old town: a rickshaw on the oncoming lane, schoolchildren, beckoning cats, banners, cats,
    # umbrellas and vendors at the ramen stalls.
    var o0 := _nearest_s(OLD_TOWN[0])
    var o1 := _nearest_s(OLD_TOWN[1])
    _drive("rikscha", o0, o1, -2.6, -1.25, 1, 220.0)
    var k3 := 0
    var s := o0 + 12.0
    while s < o1 - 10.0:
        var i := int(s / STEP) % road_pos.size()
        var side := 1.0 if k3 % 2 == 0 else -1.0
        var out := _right(i) * side
        var p: Vector3 = road_pos[i] + out * 5.4
        if k3 % 3 == 0:
            var cat := _live("maneki_neko", _ground(p.x, p.z), _face_x(-out))
            _movers.append([cat.find_child("Tass", true, false), "tass", k3 * 0.9])
        elif k3 % 3 == 1:
            var banner := _live("nobori", _ground(p.x, p.z), atan2(out.x, out.z), 260.0)
            _swayers.append([banner, banner.rotation, 0.1, 1.4, k3 * 1.3, 1])
        else:
            _live("katt", _ground(p.x, p.z) + Vector3.UP * 0.02, _face_x(-out) + rng.randf_range(-0.8, 0.8), 120.0)
        _keep(Vector2(p.x, p.z), 1.0)
        k3 += 1
        s += 23.0
    var wi := int(fmod(o0 + 52.0, length) / STEP)
    var wp: Vector3 = road_pos[wi] - _right(wi) * 6.0
    _live("wagasa", _ground(wp.x, wp.z), _yaw_to(_right(wi)))
    for g in 2:
        var side := 3.4 if g == 0 else -3.4
        var path := _lap_path(o0, o1, side)
        var t0 := rng.randf() * (path.size() - 4)
        for kid in 3:
            _walk("skolbarn", path, 0.95, t0 + kid * 0.2, 150.0)
    var vk := 0
    s = o0
    while s < o1:
        var i := int(s / STEP) % road_pos.size()
        if vk % 5 == 2 and vk < 12:
            var v: Vector3 = road_pos[i] + _right(i) * 5.7
            _live("forsaljare", _ground(v.x, v.z), _face_x(-_right(i)))
        vk += 1
        s += 7.0
    # The temple: shrine maidens sweeping the approach, the bell tower, an ema rack, Nara-style deer.
    var hall := Vector2(-300, -440)
    var gate := Vector2(-290, -360)
    var up := (hall - gate).normalized()
    var across := Vector2(-up.y, up.x)
    for k in 2:
        var m := gate.lerp(hall, 0.28 + k * 0.3) + across * (2.6 if k == 0 else -2.6)
        var miko := _live("miko", _ground(m.x, m.y), _face_x(Vector3(across.x, 0, across.y) * (-1.0 if k == 0 else 1.0)))
        _swayers.append([miko, miko.rotation, 0.35, 1.1, k * 2.0, 1])
    # The village bell tower on level ground across the road from the onsen inn.
    var bb := _beside(ONSEN)
    var bi: int = bb[0]
    var bo: Vector3 = _right(bi) * -float(bb[1])
    var bp: Vector3 = road_pos[bi] + bo * 13.0 + Vector3(road_dir[bi].x, 0.0, road_dir[bi].z).normalized() * 30.0
    var bell := Vector2(bp.x, bp.z)
    var tower := _live("tempelklocka", _ground_low(bell.x, bell.y, 2.5), atan2(bo.z, -bo.x) + PI * 0.5, 500.0)
    _block(bell.x, bell.y, 2.6)
    _keep(bell, 4.0)
    _movers.append([tower.find_child("Stock", true, false), "stock", 0.0])
    var em := Vector2(-225.0 - 9.0, -455.0 + 8.0)
    _prop("ema", _ground(em.x, em.y), _yaw_to(Vector3(0, 0, 1)))
    _keep(em, 2.0)
    for k in 5:
        var c := gate + across * rng.randf_range(-22.0, 22.0) - up * rng.randf_range(6.0, 22.0)
        var pts: Array = []
        for j in 4:
            pts.append(c + Vector2(rng.randf_range(-12.0, 12.0), rng.randf_range(-12.0, 12.0)))
        _walk("hjort", _path6(pts), 0.35, -1.0, 160.0)
    # The onsen: monkeys soaking in the hot spring, deer by the inn, a couple strolling.
    for k in 5:
        var a := k * TAU / 5.0 + 0.3
        var mk := _live("apa", _onsen_pool + Vector3(cos(a) * 3.2, 0.32, sin(a) * 3.2), atan2(sin(a), -cos(a)) + PI, 120.0)
        _bobbers.append([mk, _onsen_pool.y + 0.32, k * 1.7])
    var on := _beside(ONSEN)
    var oi: int = on[0]
    var os := float(oi) * STEP
    _walk("yukatapar", _lap_path(os - 90.0, os + 90.0, -4.0 * float(on[1])), 0.7)
    for k in 2:
        var c := ONSEN + Vector2(rng.randf_range(-30.0, 30.0), rng.randf_range(-30.0, 30.0))
        _walk("hjort", _path6([c, c + Vector2(10, 4), c + Vector2(4, 12), c + Vector2(-6, 6)]), 0.3, -1.0, 160.0)
    # The lake: swan boats near the shore, anglers on the jetty, couples on the shore path.
    for c: Vector2 in [Vector2(-560, -792), Vector2(-690, -800), Vector2(-780, -808), Vector2(-850, -822)]:
        _cruise("svanbat", Vector3(c.x, 0.1, c.y), 22.0, 9.0, rng.randf_range(0.06, 0.1) * (1.0 if rng.randf() < 0.5 else -1.0))
    for k in 2:
        var f := _live("fiskare", _lake_jetty + Vector3(-0.6 + k * 1.2, 0.05, -4.2 - k * 1.3), PI * 0.5, 160.0)
        _movers.append([f.find_child("Spo", true, false), "spo", k * 2.3])
    var l0 := _nearest_s(Vector2(-450.0, -742.0))
    var l1 := _nearest_s(Vector2(-900.0, -785.0))
    var li := int(l0 / STEP)
    var lake_side := 1.0 if lake_d(road_pos[li].x + _right(li).x * 8.0, road_pos[li].z + _right(li).z * 8.0) < lake_d(road_pos[li].x, road_pos[li].z) else -1.0
    for k in 2:
        _walk("yukatapar", _lap_path(l0, l1, (7.0 + k) * lake_side), 0.7)
    # The Iroha hairpins: pilgrims walking up and down the verge; ema by the bend shrines; umbrellas
    # at the tea house.
    var h0 := _nearest_s(Vector2(-960.0, -835.0))
    var h1 := _nearest_s(PASS)
    for k in 3:
        _walk("pilgrim", _lap_path(h0, h1, 3.7 if k % 2 == 0 else -3.7), rng.randf_range(0.55, 0.7), -1.0, 160.0)
    for bend: Vector2 in [Vector2(-1200.0, -725.0), Vector2(-975.0, -630.0)]:
        var b := _beside(bend)
        var i: int = b[0]
        var out: Vector3 = _right(i) * float(b[1])
        var e: Vector3 = road_pos[i] + out * 10.0 - Vector3(road_dir[i].x, 0.0, road_dir[i].z).normalized() * 3.5
        _prop("ema", _ground(e.x, e.z), _yaw_to(-out))
        _keep(Vector2(e.x, e.z), 2.0)
    var pi2 := int(_nearest_s(PASS) / STEP) % road_pos.size()
    var pr := _right(pi2) * (1.0 if _right(pi2).z < 0.0 else -1.0)
    var wg: Vector3 = road_pos[pi2] + pr * 7.0 + Vector3(road_dir[pi2].x, 0.0, road_dir[pi2].z).normalized() * 5.0
    _live("wagasa", _ground(wg.x, wg.z), _yaw_to(-pr))
    # The tea fields: pickers bent over the rows near the road, a kei truck parked at a field edge.
    var rows: Array = _planted.get("tebuske_1", [])
    var picked := 0
    for t in 400:
        if picked >= 10 or rows.is_empty():
            break
        var tr: Transform3D = rows[rng.randi() % rows.size()]
        var near := float(_nearest_road(tr.origin.x, tr.origin.z)[0])
        if near < 6.0 or near > 28.0:
            continue
        var along := tr.basis.x.normalized()
        var p := tr.origin + tr.basis.z.normalized() * 1.15
        var picker := _live("teplockare", _ground(p.x, p.z), _face_x(along * (1.0 if picked % 2 else -1.0)), 160.0)
        _swayers.append([picker, picker.rotation, 0.12, 0.8, picked * 1.1, 0])
        picked += 1
    var ti := int(_nearest_s(Vector2(-1050.0, -260.0)) / STEP) % road_pos.size()
    var tp: Vector3 = road_pos[ti] + _right(ti) * 5.5
    _live("keilastbil", _ground(tp.x, tp.z), _face_x(Vector3(road_dir[ti].x, 0, road_dir[ti].z)), 300.0)
    _block(tp.x, tp.z, 1.3)
    # The gassho valley and the rice terraces: farmers bent over the paddies, cranes wading, cats by
    # the houses, a walker with a shiba along the road.
    for area in [[GASSHO, 170.0, 6, 6], [Vector2(-330, 520), 150.0, 3, 2]]:
        var centre: Vector2 = area[0]
        var farmers := 0
        var cranes := 0
        for t in 400:
            if farmers >= int(area[2]) and cranes >= int(area[3]):
                break
            var a := rng.randf() * TAU
            var p := centre + Vector2(cos(a), sin(a)) * sqrt(rng.randf()) * float(area[1])
            var near := float(_nearest_road(p.x, p.y)[0])
            if near < 10.0 or near > 90.0 or not _free_spot(p.x, p.y, 3.0):
                continue
            var g := _ground(p.x, p.y)
            if farmers < int(area[2]):
                var f := _live("risbonde", g, rng.randf() * TAU, 160.0)
                _swayers.append([f, f.rotation, 0.1, 0.7, farmers * 1.3, 0])
                farmers += 1
            else:
                var crane := _scene("trana")
                crane.position = g
                add_child(crane)
                _near(crane, 160.0)
                _egrets.append([crane, g, rng.randf() * TAU])
                cranes += 1
            _keep(p, 3.0)
    var gs := _nearest_s(GASSHO + Vector2(-150.0, -150.0))
    var walker := _lap_path(gs, gs + 300.0, -3.8)
    var wt := rng.randf() * (walker.size() - 3)
    _walk("turist", walker, 0.7, wt)
    var dog := _walk("shiba", _lap_path(gs, gs + 300.0, -4.6), 0.7, wt)
    if dog:
        _walkers[_walkers.size() - 1][4] = _walkers[_walkers.size() - 2][4]
    for k in 2:
        var c := GASSHO + Vector2(rng.randf_range(-120.0, 120.0), rng.randf_range(-120.0, 120.0))
        if _free_spot(c.x, c.y, 1.0):
            _live("katt", _ground(c.x, c.y), rng.randf() * TAU, 120.0)
    # The port: anglers on the breakwater, harbour cats on the quay.
    var bw0 := Vector3(shore_x(PORT_LIGHT.y) - 14.0, 0.0, PORT_LIGHT.y)
    var bw1 := Vector3(PORT_LIGHT.x, 0.0, PORT_LIGHT.y)
    for k in 4:
        var p := bw0.lerp(bw1, 0.25 + k * 0.17)
        var south := k % 2 == 0
        var f := _live("fiskare", Vector3(p.x, 2.3, p.z + (1.3 if south else -1.3)), -PI * 0.5 if south else PI * 0.5, 200.0)
        _movers.append([f.find_child("Spo", true, false), "spo", k * 1.9])
    for k in 3:
        var z := PORT.y - 50.0 + k * 40.0
        var x := shore_x(z) - 20.0
        if height(x, z) > 0.8:
            _live("katt", _ground(x, z), rng.randf() * TAU, 120.0)
    # Traffic on the oncoming lane: taxis and mopeds in Tokyo, kei trucks and bikes in the country.
    var tokyo0 := _nearest_s(Vector2(1073.0, 130.0))
    _drive("taxi", tokyo0, length + 2100.0, -11.0, -1.15, 6)
    _drive("moped", tokyo0, length + 2100.0, -8.0, -1.5, 2)
    _drive("moped", o0, _nearest_s(Vector2(-360.0, -680.0)), -7.5, -1.5, 2)
    _drive("keilastbil", _nearest_s(Vector2(-1190.0, -460.0)), _nearest_s(Vector2(-560.0, -260.0)), -8.0, -1.15, 2)
    _drive("keilastbil", _nearest_s(Vector2(-820.0, 480.0)), _nearest_s(Vector2(-470.0, 620.0)), -8.5, -1.15, 2)
    _drive("keilastbil", _nearest_s(Vector2(540.0, 580.0)), tokyo0, -9.0, -1.15, 2)
    _drive("mamachari", o0, o1, -4.0, -1.6, 2)
    _drive("mamachari", _nearest_s(Vector2(-360.0, -680.0)), _nearest_s(Vector2(-900.0, -785.0)), -4.5, -1.6, 2)
    _drive("mamachari", _nearest_s(Vector2(-300.0, 560.0)), _nearest_s(Vector2(260.0, 560.0)), -4.5, -1.6, 2)
    _drive("mamachari", _nearest_s(Vector2(1010.0, 830.0)), _nearest_s(Vector2(1070.0, 330.0)), -4.5, -1.6, 2)


func _update_living(now: float, delta: float) -> void:
    for d in _drivers:
        var s0: float = d[4]
        var s1: float = d[5]
        var s: float = float(d[1]) + float(d[2]) * delta
        if s < s0:
            s += s1 - s0
        elif s > s1:
            s -= s1 - s0
        d[1] = s
        var at := sample(s)
        var dir: Vector3 = at["dir"]
        var flat := Vector3(dir.x, 0.0, dir.z).normalized()
        var forward := flat * signf(d[2])
        var node: Node3D = d[0]
        node.position = (at["pos"] as Vector3) + flat.cross(Vector3.UP).normalized() * float(d[3]) \
            + Vector3.UP * absf(sin(now * 9.0 + s)) * 0.015
        node.rotation = Vector3(0.0, atan2(-forward.z, forward.x), atan(float(at["grade"]) / 100.0 * signf(d[2])))
    for w in _swayers:
        var node: Node3D = w[0]
        var base: Vector3 = w[1]
        var v := sin(now * float(w[3]) + float(w[4])) * float(w[2])
        if int(w[5]) == 0:
            node.rotation = Vector3(base.x, base.y, base.z - absf(v))
        else:
            node.rotation = Vector3(base.x, base.y + v, base.z)
    for m in _movers:
        var part: Node3D = m[0]
        if part == null:
            continue
        var ph: float = m[2]
        match String(m[1]):
            "tass":
                part.rotation.z = sin(now * 3.2 + ph) * 0.45
            "arm":
                part.rotation.z = maxf(0.0, sin(now * 5.5 + ph)) * 0.9 - 0.2
            "stock":
                part.rotation.z = -0.5 * maxf(0.0, sin(now * 0.55 + ph))
            "spo":
                part.rotation.z = sin(now * 0.7 + ph) * 0.04 - (0.12 if sin(now * 0.23 + ph) > 0.93 else 0.0)
    for l in _lights:
        var green: Node3D = l[0]
        var red: Node3D = l[1]
        var on := fposmod(now + float(l[2]), 14.0) < 8.0
        if green:
            green.visible = on
        if red:
            red.visible = not on


# --- Life ----------------------------------------------------------------------------------------

func _process(delta: float) -> void:
    if diorama or _rail_y.is_empty():
        return
    var now := Time.get_ticks_msec() / 1000.0
    # Trains: six cars, the last one turned round; they run off one end and come back at the other.
    var span := Vector2(RAIL[0]).distance_to(RAIL[1])
    var dir := (Vector3(RAIL[1].x, 0, RAIL[1].y) - Vector3(RAIL[0].x, 0, RAIL[0].y)).normalized()
    var side := Vector3(-dir.z, 0, dir.x)
    for tr in _trains:
        tr[1] = fposmod(float(tr[1]) + float(tr[2]) * delta, span + 400.0)
        var cars: Array = tr[0]
        for c in cars.size():
            var u: float = tr[1] - c * 25.5 * signf(tr[2]) - 200.0
            var car: Node3D = cars[c]
            car.visible = u > 0.0 and u < span
            if not car.visible:
                continue
            car.position = _rail_at(u) + side * float(tr[3])
            var forward := dir * signf(tr[2])
            var last := c == cars.size() - 1
            car.rotation.y = atan2(-forward.z, forward.x) + (PI if last else 0.0)
    for w in _walkers:
        var path: Array = w[1]
        w[2] = float(w[2]) + float(w[3]) * float(w[4]) * delta / 6.0
        if w[2] >= path.size() - 1:
            w[2] = path.size() - 1.001
            w[4] = -1.0
        elif w[2] <= 0.0:
            w[2] = 0.001
            w[4] = 1.0
        var k := int(w[2])
        var p: Vector3 = (path[k] as Vector3).lerp(path[k + 1], float(w[2]) - k)
        var node: Node3D = w[0]
        var step := (path[k + 1] as Vector3) - (path[k] as Vector3)
        if float(w[4]) < 0.0:
            step = -step
        node.position = p + Vector3.UP * absf(sin(now * 5.0 + k)) * 0.03
        node.rotation = Vector3(0.0, atan2(-step.z, step.x), sin(now * 2.5 + k) * 0.03)
    for s in _sumo:
        var node: Node3D = s[0]
        var t := fposmod(now * 0.35 + float(s[1]), 1.0)
        var lift := sin(clampf(t / 0.45, 0.0, 1.0) * PI) if t < 0.45 else 0.0
        var right_leg := int(floorf(now * 0.35 + float(s[1]))) % 2 == 0
        var legs := ["BenV", "BenH"]
        for l in 2:
            var leg := node.find_child(legs[l], true, false) as Node3D
            if leg:
                var up := lift if (l == 0) == right_leg else 0.0
                leg.rotation.x = up * 1.1 * (1.0 if l == 0 else -1.0)
        var body := node.find_child("Kropp", true, false) as Node3D
        if body:
            body.rotation.x = lift * 0.25 * (1.0 if right_leg else -1.0)
    for b in _blinks:
        var label: Label3D = b[0]
        label.modulate.a = 1.0 if sin(now * 3.0 + float(b[1])) > -0.7 else 0.25
    if _wheel:
        _wheel.rotation.z = now * 0.035          # one turn in three minutes
    for c in _cruisers:
        var a: float = float(c[5]) + now * float(c[4])
        var node: Node3D = c[0]
        node.position = (c[1] as Vector3) + Vector3(cos(a) * float(c[2]), sin(now * 1.1 + float(c[5])) * 0.05, sin(a) * float(c[3]))
        var v := Vector2(-sin(a) * float(c[2]), cos(a) * float(c[3])) * signf(c[4])
        node.rotation = Vector3(0.0, atan2(-v.y, v.x), sin(now * 0.8 + float(c[5])) * 0.02)
    _update_street_life(now)
    _update_living(now, delta)


# --- Street life: poles and wires, shop fronts, walkers, crows, boats, koi, petals -----------------

var _boats: Array = []      # yakatabune: [boat, z low, z high, speed, phase, offset from the river's centre]
var _koi: Array = []        # [fish, radius, angular speed, phase]


## The things that make the world feel lived in: utility poles with sagging wires along the old
## town, the neon street and through the village; lanterns, potted plants, parked bikes, post boxes,
## kei vans and Jizō statues; office workers and schoolgirls on the pavements of the neon street,
## crows over the temple hill, pleasure boats on the river, koi in the pond and cherry petals
## drifting over the river.
func _place_street_life() -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = 33
    var poles := {}
    var wires: Array = []
    var vr := _road_at(VILLAGE)
    var va: Vector3 = sample(float(vr["s"]) - 260.0)["pos"]
    var vb: Vector3 = sample(float(vr["s"]) + 260.0)["pos"]
    _pole_line(OLD_TOWN[0], OLD_TOWN[1], -1.0, 6.2, 28.0, poles, wires)
    _pole_line(NEON_STREET[0], NEON_STREET[1], -1.0, 6.5, 26.0, poles, wires)
    _pole_line(Vector2(va.x, va.z), Vector2(vb.x, vb.z), 1.0, 6.0, 34.0, poles, wires)
    _flush_tf(poles)
    if not wires.is_empty():
        add_child(_multimesh(_box_mesh(Vector3.ONE, Color("1c1c20")), wires))
    # The old town's shop fronts: lanterns, plants, bikes and a post box now and then.
    var k := [0]
    _along(OLD_TOWN[0], OLD_TOWN[1], 21.0, func(_s: float, i: int, right: Vector3) -> void:
        var across := atan2(-right.z, right.x)
        var kind: int = k[0] % 4
        var p: Vector3 = road_pos[i] + right * (6.6 if kind % 2 == 0 else -6.4)
        var name: String = ["lykta_par", "krukor", "cyklar", "postlada"][kind]
        _prop(name, _ground(p.x, p.z), across)
        _keep(Vector2(p.x, p.z), 1.5)
        k[0] += 1)
    # The neon street: bikes by the vending machines, kei vans at the kerb, a post box.
    k[0] = 0
    _along(NEON_STREET[0], NEON_STREET[1], 39.0, func(_s: float, i: int, right: Vector3) -> void:
        var flat := Vector3(road_dir[i].x, 0, road_dir[i].z).normalized()
        var bp: Vector3 = road_pos[i] + right * 8.0
        _prop("cyklar", _ground(bp.x, bp.z), atan2(-right.z, right.x))
        if k[0] % 2 == 0:
            var cp: Vector3 = road_pos[i] - right * 8.5
            _prop("keibil", _ground(cp.x, cp.z), atan2(-flat.z, flat.x))
        if k[0] == 3:
            var pp: Vector3 = road_pos[i] - right * 7.4 + flat * 6.0
            _prop("postlada", _ground(pp.x, pp.z), atan2(right.z, -right.x))
        k[0] += 1)
    # The village: Jizō statues by the road, a kei van, plants by the houses.
    for e in [["jizo", -60.0, 7.0], ["keibil", -25.0, -7.5], ["krukor", 30.0, 7.0], ["jizo", 90.0, -7.0]]:
        var vi := int(fposmod(float(vr["s"]) + float(e[1]), length) / STEP) % road_pos.size()
        var right2 := _right(vi)
        var flat2 := Vector3(road_dir[vi].x, 0, road_dir[vi].z).normalized()
        var p: Vector3 = road_pos[vi] + right2 * float(e[2])
        var to_road := -right2 * signf(e[2])
        _prop(e[0], _ground(p.x, p.z), atan2(-flat2.z, flat2.x) if e[0] == "keibil" else atan2(-to_road.z, to_road.x))
        _keep(Vector2(p.x, p.z), 2.5)
    if diorama:
        return
    # Office workers and schoolgirls on both pavements of the neon street.
    for w in 8:
        var side := -1.0 if w % 2 else 1.0
        var path: Array = []
        _along(NEON_STREET[0], NEON_STREET[1], 6.0, func(_s: float, i: int, right: Vector3) -> void:
            var p: Vector3 = road_pos[i] + right * side * 6.8
            path.append(Vector3(p.x, height(p.x, p.z), p.z)))
        if path.size() < 4:
            continue
        var node := _scene("kontorist" if w % 3 else "skolelev")
        add_child(node)
        _walkers.append([node, path, rng.randf() * (path.size() - 1), rng.randf_range(1.0, 1.4), 1.0 if w < 4 else -1.0])
    # Crows wheeling over the temple hill and the old town.
    var mid_old := (OLD_TOWN[0] + OLD_TOWN[1]) * 0.5
    for c in 12:
        var crow := _scene("kraka")
        add_child(crow)
        var at2: Vector2 = TEMPLE_HILL if c % 2 == 0 else mid_old
        var centre := Vector3(at2.x + rng.randf_range(-60.0, 60.0), 0.0, at2.y + rng.randf_range(-60.0, 60.0))
        centre.y = height(centre.x, centre.z) + rng.randf_range(18.0, 34.0)
        _gulls.append([crow, centre, rng.randf_range(8.0, 22.0), rng.randf_range(0.3, 0.5) * (1.0 if c % 2 else -1.0), rng.randf() * TAU])
    # Pleasure boats on the river, turning before the bridges.
    var zs: Array = []
    for i in road_pos.size():
        if road_bridge[i] == 1 and absf(road_pos[i].x - river_x(road_pos[i].z)) < RIVER_HALF + 8.0:
            zs.append(road_pos[i].z)
    zs.sort()
    var cuts: Array = [-600.0]
    var j := 0
    while j < zs.size():
        var lo: float = zs[j]
        var hi := lo
        while j + 1 < zs.size() and float(zs[j + 1]) - hi < 30.0:
            j += 1
            hi = zs[j]
        cuts.append(lo - 35.0)
        cuts.append(hi + 35.0)
        j += 1
    cuts.append(700.0)
    for r in range(0, cuts.size() - 1, 2):
        var lo: float = cuts[r]
        var hi: float = cuts[r + 1]
        if hi - lo < 120.0:
            continue
        for b in 2:
            var boat := _scene("yakatabune")
            add_child(boat)
            _boats.append([boat, lo, hi, rng.randf_range(1.2, 2.0), rng.randf() * 500.0, rng.randf_range(-14.0, 14.0)])
    # Koi circling in the pond.
    for f in 9:
        var fish := _scene("koi")
        add_child(fish)
        _koi.append([fish, rng.randf_range(4.0, 12.0), rng.randf_range(0.15, 0.35) * (1.0 if f % 2 else -1.0), rng.randf() * TAU])
    # Cherry petals drifting over the river and the old town.
    for z: float in [-470.0, -220.0, 60.0, 330.0, 560.0]:
        var x := river_x(z)
        _petals(Vector3(x, maxf(height(x, z), 0.0) + 8.0, z), Vector3(RIVER_HALF + 30.0, 5.0, 90.0))
    _petals(Vector3(mid_old.x, height(mid_old.x, mid_old.y) + 8.0, mid_old.y), Vector3(60.0, 5.0, 60.0))


## Utility poles along a stretch of the lap, `offset` metres to one side every `step` metres, with
## four sagging wires from pole to pole (the wires of all lines are one multimesh).
func _pole_line(a: Vector2, b: Vector2, side: float, offset: float, step: float, poles: Dictionary, wires: Array) -> void:
    var prev: Array = []
    _along(a, b, step, func(_s: float, i: int, right: Vector3) -> void:
        var p: Vector3 = road_pos[i] + right * side * offset
        var g := height(p.x, p.z)
        if road_bridge[i] == 1 or g < 0.4:
            prev.clear()
            return
        var flat := Vector3(road_dir[i].x, 0, road_dir[i].z).normalized()
        var yaw := atan2(-flat.z, flat.x)
        var foot := Vector3(p.x, g - 0.1, p.z)
        _add_tf(poles, "elstolpe", foot, yaw)
        _block(p.x, p.z, 0.35)
        var basis := Basis(Vector3.UP, yaw)
        var tops: Array = []
        for att in [[8.4, -0.85], [8.4, 0.85], [7.8, -0.65], [7.8, 0.65]]:
            tops.append(foot + basis * Vector3(0.0, float(att[0]), -float(att[1])))
        if prev.size() == 4:
            for w in 4:
                _wire(prev[w], tops[w], wires)
        prev.clear()
        prev.append_array(tops))


## A wire from a to b, sagging a little in the middle: two thin stretched boxes.
func _wire(a: Vector3, b: Vector3, wires: Array) -> void:
    var mid := (a + b) * 0.5 - Vector3.UP * a.distance_to(b) * 0.014
    for seg in [[a, mid], [mid, b]]:
        var p0: Vector3 = seg[0]
        var p1: Vector3 = seg[1]
        var d := p1 - p0
        wires.append(Transform3D(Basis.looking_at(d.normalized(), Vector3.UP) * Basis.from_scale(Vector3(0.03, 0.03, d.length())),
            (p0 + p1) * 0.5))


## Pink petals drifting and tumbling down through a box around `centre`.
func _petals(centre: Vector3, extents: Vector3) -> void:
    var p := GPUParticles3D.new()
    p.amount = 500
    p.lifetime = 14.0
    p.preprocess = 14.0
    p.visibility_aabb = AABB(-extents - Vector3(0, 14, 0), extents * 2.0 + Vector3(0, 16, 0))
    var pm := ParticleProcessMaterial.new()
    pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
    pm.emission_box_extents = extents
    pm.direction = Vector3(1.0, -0.2, 0.3)
    pm.spread = 40.0
    pm.initial_velocity_min = 0.4
    pm.initial_velocity_max = 1.2
    pm.gravity = Vector3(0.0, -0.35, 0.0)
    pm.angular_velocity_min = -120.0
    pm.angular_velocity_max = 120.0
    pm.turbulence_enabled = true
    pm.turbulence_noise_strength = 1.5
    p.process_material = pm
    var q := QuadMesh.new()
    q.size = Vector2(0.13, 0.1)
    var m := StandardMaterial3D.new()
    m.albedo_color = Color("f7c0d2")
    m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
    m.cull_mode = BaseMaterial3D.CULL_DISABLED
    q.material = m
    p.draw_pass_1 = q
    p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    p.position = centre
    add_child(p)


func _update_street_life(now: float) -> void:
    for f in _boats:
        var span: float = f[2] - f[1]
        var leg := fposmod(f[4] + now * f[3], span * 2.0)
        var dir := 1.0 if leg < span else -1.0
        var z: float = f[1] + (leg if leg < span else span * 2.0 - leg)
        var slope := 28.0 * cos(z / 190.0 + 1.0) / 190.0
        var d := Vector3(slope * dir, 0.0, dir).normalized()
        var node: Node3D = f[0]
        node.position = Vector3(river_x(z) + f[5], 0.12 + sin(now * 1.1 + f[4]) * 0.05, z)
        node.rotation = Vector3(0.0, atan2(-d.z, d.x), sin(now * 0.8 + f[4]) * 0.02)
    for f in _koi:
        var a: float = f[3] + now * f[2]
        var node: Node3D = f[0]
        node.position = Vector3(POND.x + cos(a) * f[1], -0.12, POND.y + sin(a) * f[1])
        var v := Vector2(-sin(a), cos(a)) * signf(f[2])
        node.rotation.y = atan2(-v.y, v.x)
    for f in _egrets:
        # Wading slowly round a small circle, stopping to stand now and then.
        var a: float = f[2] + now * 0.12 * (0.5 + 0.5 * sin(now * 0.3 + f[2]))
        var c: Vector3 = f[1]
        var node: Node3D = f[0]
        node.position = c + Vector3(cos(a), 0.0, sin(a)) * 1.6
        node.rotation.y = atan2(-cos(a), -sin(a))
    for f in _streamers:
        var node: Node3D = f[0]
        node.rotation = Vector3(0.0, float(f[1]) + sin(now * 0.7 + f[2]) * 0.35, sin(now * 1.3 + f[2]) * 0.015)


# --- More life: the temple, the old town, the paddies and fireflies --------------------------------

var _egrets: Array = []     # [egret, centre, phase]
var _streamers: Array = []  # carp streamers: [pole, wind yaw, phase]


## Komainu, a purification pavilion, bamboo fences and monks at the temple; tanuki and tourists in
## the old town; scarecrows, egrets, carp streamers, roadside shrines and a bus stop by the paddies;
## fireflies over the river and the fields at dusk.
func _place_more_life() -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = 47
    # The temple approach from the road up to the hall.
    var hall := Vector2(-300, -440)
    var gate := Vector2(-290, -360)
    var up := (hall - gate).normalized()
    var across := Vector2(-up.y, up.x)
    var out_yaw := atan2(up.y, -up.x)              # +X facing down the approach, towards the road
    for side in [-1.0, 1.0]:
        var q: Vector2 = gate + across * side * 4.2 + up * 2.0
        _prop("komainu", _ground(q.x, q.y), out_yaw)
        _keep(q, 1.5)
        for k in 5:
            var f: Vector2 = gate.lerp(hall, 0.2 + k * 0.13) + across * side * 10.0
            _prop("takegaki", _ground(f.x, f.y), atan2(-up.y, up.x))
            _keep(f, 2.5)
    var tz := gate.lerp(hall, 0.45) + across * 7.0
    _prop("temizuya", _ground(tz.x, tz.y), atan2(across.y, -across.x))
    _keep(tz, 3.0)
    var hk := Vector2(-225.0 + 9.0, -455.0 + 7.0)
    _prop("hokora", _ground(hk.x, hk.y), 0.4)
    _keep(hk, 1.5)
    # The old town: tanuki outside shops.
    var k2 := [0]
    _along(OLD_TOWN[0], OLD_TOWN[1], 35.0, func(_s: float, i: int, right: Vector3) -> void:
        var p: Vector3 = road_pos[i] + right * (5.9 if k2[0] % 2 == 0 else -5.9)
        _prop("tanuki", _ground(p.x, p.z), atan2((right * (-1.0 if k2[0] % 2 == 0 else 1.0)).z * -1.0, (right * (-1.0 if k2[0] % 2 == 0 else 1.0)).x))
        k2[0] += 1)
    # The village and the rice terraces.
    var vr := _road_at(VILLAGE)
    var vs: float = vr["s"]
    for e in [["hokora", -120.0, 6.5], ["hokora", 160.0, -6.5], ["busskur", 150.0, 6.0]]:
        var vi := int(fposmod(vs + float(e[1]), length) / STEP) % road_pos.size()
        var right2 := _right(vi)
        var p: Vector3 = road_pos[vi] + right2 * float(e[2])
        var to_road := -right2 * signf(e[2])
        _prop(e[0], _ground(p.x, p.z), atan2(-to_road.z, to_road.x))
        _keep(Vector2(p.x, p.z), 2.0)
    for e in [[25.0, -35.0], [-45.0, 20.0]]:
        var p := Vector2(VILLAGE.x + e[0], VILLAGE.y + e[1])
        var pole := _scene("koinobori")
        pole.position = _ground(p.x, p.y)
        add_child(pole)
        _streamers.append([pole, 0.6, rng.randf() * TAU])
        _keep(p, 2.0)
    var paddies := Vector2(-330, 520)
    var placed := [0, 0]
    for t in 400:
        if placed[0] >= 7 and placed[1] >= 12:
            break
        var a := rng.randf() * TAU
        var r := sqrt(rng.randf()) * 165.0
        var p := paddies + Vector2(cos(a), sin(a)) * r
        if _rice(p.x, p.y) < 0.6 or float(_nearest_road(p.x, p.y)[0]) < 8.0 or not _free_spot(p.x, p.y, 3.0):
            continue
        var g := _ground(p.x, p.y)
        if g.y < 0.8:
            continue
        if placed[0] < 7:
            _prop("kakashi", g, rng.randf() * TAU)
            _keep(p, 3.0)
            placed[0] += 1
        elif not diorama:
            var egret := _scene("hager")
            egret.position = g
            add_child(egret)
            _egrets.append([egret, g, rng.randf() * TAU])
            _keep(p, 2.5)
            placed[1] += 1
    if diorama:
        return
    # Monks walking the lantern path, tourists on the old town pavements.
    for m in 3:
        var path: Array = []
        for k in 12:
            var q: Vector2 = gate.lerp(hall, k / 11.0) + across * (2.5 if m % 2 else -2.5)
            path.append(_ground(q.x, q.y))
        var node := _scene("munk")
        add_child(node)
        _walkers.append([node, path, rng.randf() * 10.0, rng.randf_range(0.6, 0.8), 1.0 if m % 2 else -1.0])
    for w in 4:
        var side := -1.0 if w % 2 else 1.0
        var path2: Array = []
        _along(OLD_TOWN[0], OLD_TOWN[1], 6.0, func(_s: float, i: int, right: Vector3) -> void:
            var p: Vector3 = road_pos[i] + right * side * 4.6
            path2.append(Vector3(p.x, height(p.x, p.z), p.z)))
        if path2.size() < 4:
            continue
        var tourist := _scene("turist")
        add_child(tourist)
        _walkers.append([tourist, path2, rng.randf() * (path2.size() - 1), rng.randf_range(0.8, 1.1), 1.0 if w < 2 else -1.0])
    # Fireflies over the river banks and the paddies.
    for z: float in [-300.0, 200.0]:
        var x := river_x(z)
        _fireflies(Vector3(x, maxf(height(x, z), 0.0) + 1.6, z), Vector3(RIVER_HALF + 20.0, 1.5, 80.0))
    for c in [Vector2(-330, 520), Vector2(-260, 600), Vector2(-420, 450)]:
        _fireflies(Vector3(c.x, height(c.x, c.y) + 1.4, c.y), Vector3(45.0, 1.2, 45.0))


## Glowing fireflies drifting about slowly in a box around `centre`.
func _fireflies(centre: Vector3, extents: Vector3) -> void:
    var p := GPUParticles3D.new()
    p.amount = 160
    p.lifetime = 6.0
    p.preprocess = 6.0
    p.visibility_aabb = AABB(-extents - Vector3.ONE * 3.0, extents * 2.0 + Vector3.ONE * 6.0)
    var pm := ParticleProcessMaterial.new()
    pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
    pm.emission_box_extents = extents
    pm.spread = 180.0
    pm.initial_velocity_min = 0.1
    pm.initial_velocity_max = 0.4
    pm.gravity = Vector3.ZERO
    pm.turbulence_enabled = true
    pm.turbulence_noise_strength = 0.8
    pm.scale_curve = null
    var fade := Gradient.new()
    fade.set_color(0, Color(1, 1, 1, 0))
    fade.add_point(0.3, Color(1, 1, 1, 1))
    fade.add_point(0.7, Color(1, 1, 1, 1))
    fade.set_color(fade.get_point_count() - 1, Color(1, 1, 1, 0))
    var ramp := GradientTexture1D.new()
    ramp.gradient = fade
    pm.color_ramp = ramp
    p.process_material = pm
    var q := QuadMesh.new()
    q.size = Vector2(0.09, 0.09)
    var m := StandardMaterial3D.new()
    m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
    m.vertex_color_use_as_albedo = true
    m.albedo_color = Color(0.85, 1.0, 0.45)
    m.emission_enabled = true
    m.emission = Color(0.75, 1.0, 0.35)
    m.emission_energy_multiplier = 3.0
    m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    q.material = m
    p.draw_pass_1 = q
    p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    p.position = centre
    add_child(p)


# --- Plants --------------------------------------------------------------------------------------

func _scatter_nature() -> void:
    var kinds := _planted
    var step := 7.0
    var x := CORE.position.x + 30.0
    while x < CORE.end.x - 30.0:
        var z := CORE.position.y + 30.0
        while z < CORE.end.y - 30.0:
            var px := x + _rng.randf_range(-3.0, 3.0)
            var pz := z + _rng.randf_range(-3.0, 3.0)
            z += step
            var h := height(px, pz)
            if h < 0.6:
                continue
            var road := float(_nearest_road(px, pz)[0])
            if road < 4.0:
                continue
            var p := Vector3(px, h, pz)
            var roll := _rng.randf()
            var q := Vector2(px, pz)
            var dr := absf(px - river_x(pz)) - RIVER_HALF
            if _city(px, pz) > 0.5:
                if roll < 0.01 and _free_spot(px, pz, 4.0):
                    _put(kinds, "korsbar", p)
                continue
            if _seg_dist(q, BAMBOO[0], BAMBOO[1]) < 70.0:
                if roll < 0.55 and road > 3.5 and _free_spot(px, pz, 1.6):
                    _put(kinds, "bambu", p)
                continue
            if _rice(px, pz) > 0.6 or q.distance_to(GASSHO) < 170.0:
                if roll < 0.004 and _free_spot(px, pz, 4.0):
                    _put(kinds, "korsbar", p)
                continue
            if dr < 26.0:
                if roll < 0.35 and _free_spot(px, pz, 3.5):
                    _put(kinds, "korsbar", p)      # cherry trees along both banks
                continue
            var dl := lake_d(px, pz)
            if dl < 45.0:
                if roll < 0.2 and _free_spot(px, pz, 3.5):
                    _put(kinds, "korsbar" if roll < 0.15 else "lonn", p)    # cherry and maple along the lake shore
                continue
            if TEA.has_point(q) and h > 8.0:
                if roll < 0.002 and _free_spot(px, pz, 4.0):
                    _put(kinds, "korsbar", p)
                continue
            if px > 480.0 and pz > 240.0 and px > shore_x(pz) - 110.0:
                # The pine belt along the coast south of Tokyo.
                if roll < 0.22 and _free_spot(px, pz, 3.0):
                    _put(kinds, "tall_jp", p)
                continue
            if h > 14.0:
                # Forested mountains and the temple hill: cedars, pines, maples, cherry.
                if roll < 0.3 and _free_spot(px, pz, 3.0):
                    _put(kinds, "sugi" if roll < 0.13 else ("tall_jp" if roll < 0.2 else ("lonn" if roll < 0.25 else "korsbar")), p)
                continue
            if roll < 0.05 and _free_spot(px, pz, 3.5):
                _put(kinds, "korsbar" if roll < 0.03 else "lonn", p)
            elif roll < 0.09:
                _put(kinds, "grastuva", p)
            elif roll < 0.1 and _free_spot(px, pz, 2.0):
                _put(kinds, "buske", p)
        x += step
    _add_scattered(kinds)


# --- Small helpers -------------------------------------------------------------------------------

func _add_tf(tf: Dictionary, name: String, pos: Vector3, yaw: float) -> void:
    if not tf.has(name):
        tf[name] = []
    tf[name].append(Transform3D(Basis(Vector3.UP, yaw), pos))


## One multimesh per model and 200 m square: a multimesh is culled only as a whole, so one per
## model drew every copy each frame, behind the camera too.
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
