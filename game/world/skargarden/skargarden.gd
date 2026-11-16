extends Node3D
## Skärgården: a ~3 km loop through a low-poly Swedish archipelago, built in code when loaded.
## The road decides everything: the terrain is flattened along it, bridges appear wherever it
## crosses water, and the grade sent to the trainer comes from its height profile.
##
## Map in metres (x east, z south): Huvudön with the harbour on its south shore, the lighthouse
## hill (Fyrberget) in the east, and Lillön to the west, reached over two wooden bridges.

const Rider = preload("res://world/rider.gd")
const Atmosphere = preload("res://world/atmosphere.gd")
const PORTAL_BEAM := preload("res://world/portal_beam.gdshader")
## Broadleaf trees: their leaves turn in autumn and fall in winter (world/vaxt.gdshader).
const LEAFY_KINDS := ["bjork", "al", "ronn", "salg", "lonn", "korsbar", "akacia", "ginkgo"]
## Small ground cover that does not sway but still goes under the winter snow.
const STILL_PLANTS := ["mossa", "renlav", "nackrosor", "tebuske"]
const MODELS := "res://world/skargarden/models/"
const STEP := 2.0                     # road sample spacing in metres
const ROAD_HALF := 2.1                # asphalt half-width
const RIDE_OFFSET := 1.0              # ride right of the centre line
const MAX_GRADE := 7.0                # percent; steeper hills are cut down

## [centre x, centre z, radius x, radius z, peak height]
const ISLANDS := [
    [200.0, 20.0, 520.0, 360.0, 14.0],
    [600.0, -120.0, 230.0, 200.0, 30.0],
    [-460.0, 140.0, 140.0, 210.0, 13.0],
    [-55.0, 222.0, 70.0, 58.0, 24.0],
    [-395.0, -385.0, 195.0, 135.0, 15.0],     # Norrskär, the bare outer island in the north-west
    [-305.0, -205.0, 60.0, 48.0, 7.0],        # Kobben, a stepping stone on the way out
    [-175.0, -335.0, 58.0, 44.0, 6.0],        # Mellanskär, a stepping stone on the way back
    [620.0, 395.0, 170.0, 105.0, 8.0],        # Udden, the low point reaching south-east
    [850.0, 528.0, 155.0, 125.0, 8.0],        # Gästholmen with the marina
    # The 12 km lap (2026-11-08): three more islands, each reached over two bridges.
    [300.0, -700.0, 340.0, 165.0, 14.0],      # Norrholmen in the north, a fishing hamlet
    [1500.0, 200.0, 470.0, 450.0, 26.0],      # Storön in the east: village, manor, mill, Storberget
    [1050.0, 470.0, 55.0, 45.0, 6.0],         # Bryggholmen, the stepping stone out to Storön
    [1060.0, 640.0, 50.0, 40.0, 5.0],         # Kvarnholmen, the stepping stone back
    [80.0, 800.0, 450.0, 170.0, 16.0],        # Långön in the south: beach, farm and lighthouse
]
## Road control points (x, z) in riding order, about 12.4 km. The lap starts at the harbour heading
## west with the water on the left and the lighthouse knoll ahead, crosses to Lillön, out over two
## bridges to Norrskär, along the north shore with a loop round Norrholmen, inland through Kyrkbyn
## and past the pastures, over Fyrberget and out along Udden to Gästholmen's marina, round Storön
## in the east, back past the harbour's side and round Långön in the south to the start.
const ROAD := [
    Vector2(200, 346), Vector2(0, 326), Vector2(-100, 290), Vector2(-230, 180), Vector2(-400, 300),
    Vector2(-500, 220), Vector2(-520, 80), Vector2(-420, 0), Vector2(-260, -80),
    Vector2(-310, -200), Vector2(-430, -290), Vector2(-555, -390), Vector2(-480, -480), Vector2(-320, -460),
    Vector2(-185, -350), Vector2(-60, -290), Vector2(140, -330),
    Vector2(170, -460), Vector2(190, -600), Vector2(150, -700), Vector2(250, -820), Vector2(420, -800),   # Norrholmen
    Vector2(560, -770), Vector2(590, -660), Vector2(500, -590), Vector2(340, -460),
    Vector2(320, -320),
    Vector2(350, -200), Vector2(260, -110), Vector2(140, -70), Vector2(40, 40), Vector2(150, 150),
    Vector2(300, 120), Vector2(420, 40), Vector2(470, -80), Vector2(530, -150), Vector2(585, -100),
    Vector2(605, 0), Vector2(575, 110), Vector2(510, 215), Vector2(585, 300), Vector2(690, 370),
    Vector2(815, 438), Vector2(930, 448),
    Vector2(1050, 470), Vector2(1140, 440), Vector2(1200, 330), Vector2(1210, 180), Vector2(1250, 40),   # Storön
    Vector2(1380, 90), Vector2(1510, 120), Vector2(1560, -20), Vector2(1610, -170), Vector2(1750, -100), Vector2(1850, 30),
    Vector2(1900, 190), Vector2(1870, 350), Vector2(1770, 480), Vector2(1620, 560), Vector2(1460, 590),
    Vector2(1320, 600), Vector2(1180, 610), Vector2(1060, 640), Vector2(960, 620),
    Vector2(860, 600), Vector2(760, 575),
    Vector2(650, 495), Vector2(540, 435), Vector2(450, 332), Vector2(340, 320),
    Vector2(320, 420), Vector2(360, 600), Vector2(450, 710), Vector2(390, 830), Vector2(220, 905),    # Långön
    Vector2(20, 925), Vector2(-150, 880), Vector2(-330, 860), Vector2(-260, 790), Vector2(-140, 700), Vector2(40, 660),
    Vector2(90, 600), Vector2(110, 440),
]
## Open, gently rolling ground for the church village and the pastures (centre x, z, radius):
## the rock humps and bumps fade out here.
const FLATS := [[230.0, -95.0, 110.0], [95.0, 60.0, 120.0], [290.0, 110.0, 90.0],
    [1320.0, 520.0, 120.0], [1680.0, 260.0, 130.0], [40.0, 800.0, 130.0]]
## The harbour sits where the road meets the south shore, a little way into the lap.
const HARBOUR := Vector2(-10.0, 324.0)
## Bays carved into the coast [centre x, centre z, radius x, radius z]. The harbour bay brings the
## water, the jetty and the boats right up beside the road.
const BAYS := [[-20.0, 384.0, 95.0, 50.0]]
## Lakes inside the islands [centre x, centre z, radius x, radius z]: Storsjön on Storön. Unlike a
## bay the ground starts sinking well outside the shore, so the lake lies in a gentle basin.
const LAKES := [[1650.0, 100.0, 70.0, 45.0]]
## Zones along the lap (start metre, name). Each has its own plants and things, like a real
## archipelago: harbour village, bare outer skerries, a sheltered bay, forest, rock, meadow.
const ZONES := [[0.0, "hamn"], [424.0, "ytterskar"], [1004.0, "vik"], [1388.0, "norrskar"], [2162.0, "skog"],
    [2650.0, "ytterskar"], [3100.0, "hamn"], [3400.0, "ytterskar"], [3760.0, "skog"],          # Norrholmen
    [4280.0, "kyrkby"], [4556.0, "hage"], [4948.0, "ang"], [5150.0, "berg"], [5746.0, "ang"], [5914.0, "marina"],
    [6320.0, "ytterskar"], [6520.0, "skog"], [6980.0, "berg"], [7450.0, "skog"], [7700.0, "ang"],   # Storön
    [8000.0, "hage"], [8450.0, "kyrkby"], [8850.0, "ytterskar"],
    [9300.0, "marina"], [9684.0, "ang"], [9980.0, "hamn"],
    [10060.0, "ytterskar"], [10450.0, "ang"], [10700.0, "vik"], [11250.0, "berg"], [11500.0, "hage"],   # Långön
    [11820.0, "hamn"]]
## Per zone: how much granite crowds the road, which trees grow and how often, the ground cover in
## the verge and on the rock ("cover", "fine" = the small stuff between), and what grows at the
## water's edge ("shore" on land just above the sea, "reeds" standing in the shallows).
const ZONE_STYLE := {
    "hamn": {"slab": 0.45, "trees": ["tall", "tall", "bjork", "ronn", "al"], "tree_p": 0.18,
        "cover": ["ljungtuva", "grastuva", "grastuva", "ljungtuva", "rallarros"], "fine": ["stenar", "blabarsris", "mossa", "grastuva"],
        "shore": ["havtorn", "strandkal", "stenar"], "reeds": ["vass", "kaveldun"]},
    "ytterskar": {"slab": 0.95, "trees": ["vindtall", "vindtall", "en", "en", "tall"], "tree_p": 0.3,
        "cover": ["ljungtuva", "ljungtuva", "grastuva", "en"], "fine": ["renlav", "stenar", "mossa", "lingonris", "renlav"],
        "shore": ["havtorn", "strandkal", "stenar", "stenar"], "reeds": []},
    "vik": {"slab": 0.4, "trees": ["bjork", "bjork", "al", "al", "salg", "tall", "gran"], "tree_p": 0.35,
        "cover": ["grastuva", "ljungtuva", "rallarros", "ljungtuva", "buske"], "fine": ["blabarsris", "mossa", "grastuva", "stenar"],
        "shore": ["salg", "strandkal", "stenar"], "reeds": ["vass", "kaveldun", "kaveldun"]},
    "skog": {"slab": 0.3, "trees": ["gran", "gran", "tall", "bjork", "ronn", "al"], "tree_p": 0.55,
        "cover": ["buske", "blabarsris", "grastuva", "en", "rallarros"], "fine": ["blabarsris", "blabarsris", "lingonris", "mossa", "stenar"],
        "shore": ["al", "stenar"], "reeds": ["vass"]},
    "berg": {"slab": 0.95, "trees": ["en", "en", "vindtall", "tall"], "tree_p": 0.25,
        "cover": ["ljungtuva", "ljungtuva", "grastuva", "en"], "fine": ["renlav", "renlav", "stenar", "lingonris", "mossa"],
        "shore": ["havtorn", "strandkal", "stenar"], "reeds": []},
    "norrskar": {"slab": 1.0, "trees": ["vindtall", "vindtall", "en", "en", "tall"], "tree_p": 0.22,
        "cover": ["ljungtuva", "ljungtuva", "grastuva", "en"], "fine": ["renlav", "renlav", "stenar", "mossa", "lingonris"],
        "shore": ["havtorn", "strandkal", "stenar", "stenar"], "reeds": []},
    "kyrkby": {"slab": 0.2, "trees": ["bjork", "ronn", "al", "bjork", "tall"], "tree_p": 0.18,
        "cover": ["grastuva", "rallarros", "nypon", "grastuva"], "fine": ["grastuva", "stenar", "grastuva"], "thicket": ["hassel", "nypon"],
        "shore": ["al", "stenar"], "reeds": ["vass"]},
    "hage": {"slab": 0.12, "trees": ["bjork", "al", "ronn"], "tree_p": 0.1,
        "cover": ["grastuva", "nypon", "grastuva", "rallarros"], "fine": ["grastuva", "grastuva", "stenar"], "thicket": ["hassel", "hassel", "nypon"],
        "shore": ["al", "stenar"], "reeds": ["vass"]},
    "marina": {"slab": 0.4, "trees": ["tall", "tall", "bjork", "al"], "tree_p": 0.16,
        "cover": ["ljungtuva", "grastuva", "nypon", "ljungtuva", "rallarros"], "fine": ["stenar", "grastuva", "mossa"],
        "shore": ["havtorn", "strandkal", "stenar"], "reeds": ["vass"]},
    "ang": {"slab": 0.25, "trees": ["bjork", "bjork", "tall", "ronn", "salg"], "tree_p": 0.2,
        "cover": ["grastuva", "grastuva", "rallarros", "ljungtuva", "buske"], "fine": ["stenar", "grastuva", "blabarsris", "mossa"],
        "shore": ["havtorn", "strandkal", "salg"], "reeds": ["vass", "kaveldun"]},
}
## Per zone: how high the rounded rock humps rise, and how much of the ground is grass (the
## vegetation noise must be above this; higher means more bare rock).
const ZONE_ROCK := {"norrskar": [1.4, 0.3], "kyrkby": [0.2, -0.35], "hage": [0.12, -0.45], "marina": [0.4, 0.05],
    "hamn": [0.35, 0.08], "ytterskar": [1.3, 0.25], "vik": [0.7, -0.15], "skog": [0.45, -0.3],
    "berg": [1.3, 0.2], "ang": [0.3, -0.3]}
const VARIANTS := {"tall": 4, "rallarros": 2, "hassel": 2, "nypon": 2, "gran": 2, "bjork": 2, "vindtall": 2, "en": 3, "ljungtuva": 2, "grastuva": 2, "buske": 2,
    "flyttblock": 2, "vass": 2, "nackrosor": 2, "al": 2, "ronn": 2, "salg": 2, "havtorn": 2, "kaveldun": 2,
    "strandkal": 2, "blabarsris": 2, "lingonris": 1, "mossa": 2, "renlav": 1, "stenar": 3, "tall_fjarran": 2}
const KIND_SCALE := {"tall": [0.9, 1.3], "gran": [0.9, 1.3], "bjork": [1.0, 1.35], "vindtall": [0.9, 1.3], "en": [0.9, 1.5],
    "ljungtuva": [1.0, 1.7], "grastuva": [0.8, 1.4], "buske": [0.55, 0.95], "flyttblock": [1.2, 2.6], "vass": [0.9, 1.3],
    "nackrosor": [0.8, 1.3], "al": [0.9, 1.3], "ronn": [0.9, 1.3], "salg": [0.8, 1.2], "havtorn": [0.8, 1.3],
    "kaveldun": [0.9, 1.2], "strandkal": [0.8, 1.3], "blabarsris": [0.8, 1.5], "lingonris": [0.8, 1.5],
    "mossa": [0.8, 1.6], "renlav": [0.7, 1.4], "stenar": [0.6, 1.5], "tall_fjarran": [0.8, 1.3], "rallarros": [0.8, 1.2], "hassel": [0.8, 1.3], "nypon": [0.8, 1.3]}
## Small skerries in sight of the road [x, z, radius x, radius z, peak, what stands on it]: a lone
## cottage (red, green or blue) with a pennant and a boat, a boathouse, a wooden beacon (båk) or a stone cairn.
const SKERRIES := [
    [60.0, 470.0, 38.0, 24.0, 5.0, ""], [-160.0, 462.0, 30.0, 22.0, 4.5, "sjobod"],
    [230.0, 520.0, 52.0, 32.0, 7.0, "stuga"], [-60.0, 528.0, 18.0, 14.0, 3.5, "kummel"],
    [390.0, 470.0, 26.0, 18.0, 4.0, "bak"], [-300.0, 478.0, 36.0, 26.0, 5.0, ""],
    [-680.0, 300.0, 36.0, 26.0, 5.5, "stuga"], [-650.0, 430.0, 24.0, 18.0, 4.0, "bak"],
    [100.0, -478.0, 40.0, 26.0, 6.0, "sjobod"], [-210.0, -425.0, 26.0, 18.0, 4.0, "kummel"],
    [330.0, -482.0, 32.0, 22.0, 5.0, ""], [960.0, 140.0, 40.0, 30.0, 6.0, "stuga"],
]
## Gravel side roads (where they leave the lap, side: -1 left, 1 right, destination, cycle sign text).
const SIDE_ROADS := [[Vector2(560.0, 437.0), -1.0, "Ängsviken", "Hamnen 0,8"], [Vector2(445.0, -20.0), 1.0, "Skogsbacken", "Fyren 0,5"]]
const GROUND_SHADER := preload("res://world/ground.gdshader")
const SKY_SHADER := preload("res://world/sky.gdshader")
const ROAD_SHADER := preload("res://world/vag.gdshader")
## The granite knoll west of the harbour with the harbour lighthouse on top.
const KNOLL := Vector2(-55.0, 222.0)
const BASE := Vector3(685.0, 27.0, -165.0)   # the secret military base: yard centre and height
const BASE_R := 38.0                         # its fence

const COL := {
    "granit": Color("bf8a7c"), "granit_ljus": Color("cf9f90"), "granit_mork": Color("a8716a"),
    "mossa": Color("7c9440"), "gras": Color("a2ad4c"), "strand": Color("8d6f68"), "sand": Color("c9b48c"),
    "botten": Color("5f7473"), "grus": Color("a69a88"), "asfalt": Color("5e5955"), "linje": Color("eeeeea"),
    "planka": Color("a27a52"), "balk": Color("6e4a2e"), "kant": Color("857a70"), "racke": Color("8e6440"),
}

var length := 0.0
var road_pos := PackedVector3Array()
var road_dir := PackedVector3Array()
var road_grade := PackedFloat32Array()
var road_bridge := PackedByteArray()
var rider: Node3D
var camera: Camera3D
var environment: Environment

var _noise := FastNoiseLite.new()
var _rund := FastNoiseLite.new()     # the rounded rock humps
var _islets: Array = []
var _road_hash := {}
var _rng := RandomNumberGenerator.new()
var _bobbers: Array = []        # boats and buoys that rock on the water
var _sommarliv = null           # Skärgården's summer life (sommarliv.gd), only in Skärgården
var _cam_pos := Vector3.ZERO
var _cam_ready := false
var orbit := 0.0          # radians the camera is swung around the rider (look left/right)
var lateral := 0.0        # metres the rider has steered across the road from the right lane
var base_tank: Node3D     # the tank parked at the secret base
var _radar_dish: Node3D

## Diorama mode (set before the node enters the tree): the same world cut out as a floating
## miniature for the world-select card, with houses, trees and road scaled up to read from afar.
var diorama := false
const DIO_CENTER := Vector2(40.0, 10.0)
const DIO_R := 700.0
var _ps := 1.0      # prop scale
var _rw := 1.0      # road width scale
var _dens := 1.0    # vegetation density
var _vy := 1.0      # vertical exaggeration (diorama only)


func _ready() -> void:
    CORE = _core()
    _rng.seed = 20261108
    _noise.seed = 7
    _noise.frequency = 1.0 / 70.0
    _noise.fractal_octaves = 3
    _rund.seed = 11
    _rund.frequency = 1.0 / 24.0
    _rund.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
    _rund.fractal_octaves = 2
    if diorama:
        _ps = 3.5
        _rw = 2.6
        _dens = 0.3
        _vy = 3.0
    _make_islets()
    _build_road()
    if _vy != 1.0:
        for i in road_pos.size():
            road_pos[i].y *= _vy
    if diorama:
        _build_diorama()
        return
    _build_environment()
    _build_terrain()
    _build_road_mesh()
    _build_water()
    _place_props()
    _place_life()
    _scatter_nature()
    _fit_render_scale()
    get_viewport().size_changed.connect(_fit_render_scale)
    rider = Rider.new()
    add_child(rider)
    camera = Camera3D.new()
    camera.fov = 56.0
    camera.far = 6000.0
    add_child(camera)
    camera.make_current()
    update_view(0.0, 0.0, 0.0, 0.0)
    atmosphere = Atmosphere.new()
    atmosphere.world = self
    add_child(atmosphere)


## Time of day, weather and season over the world's own look (world/atmosphere.gd).
var atmosphere: Node


## "nordic": seasons and sea ice (Egypten and Japan say otherwise).
func climate() -> String:
    return "nordic"


## In very large windows (full-screen Retina) draw the 3D scene at most ~3.4 million pixels and
## let FSR sharpen it up to the screen; 1600×900 and the like are drawn at full size.
func _fit_render_scale() -> void:
    var vp := get_viewport()
    var px := float(vp.size.x * vp.size.y)
    var scale_3d := clampf(sqrt(3.4e6 / maxf(px, 1.0)), 0.67, 1.0)
    vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if scale_3d < 1.0 else Viewport.SCALING_3D_MODE_BILINEAR
    vp.scaling_3d_scale = scale_3d
    vp.fsr_sharpness = 0.25


func _exit_tree() -> void:
    if diorama or not is_inside_tree():
        return
    var vp := get_viewport()
    if vp.size_changed.is_connected(_fit_render_scale):
        vp.size_changed.disconnect(_fit_render_scale)
    vp.scaling_3d_scale = 1.0
    vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR


# --- Public API used by the ride screen --------------------------------------------------------

## Position, direction and grade at distance s along the loop.
func sample(s: float) -> Dictionary:
    var n := road_pos.size()
    var f := fposmod(s, length) / STEP
    var i := int(f) % n
    var j := (i + 1) % n
    var t := f - floorf(f)
    return {
        "pos": road_pos[i].lerp(road_pos[j], t),
        "dir": road_dir[i].lerp(road_dir[j], t).normalized(),
        "grade": lerpf(road_grade[i], road_grade[j], t),
        "bridge": road_bridge[i] == 1,
    }


## Place the rider at `distance` and move the camera behind. Called every frame by the ride screen.
## In free riding the world keeps its own place (fri) and moves it on by the distance ridden.
func update_view(distance: float, speed: float, cadence: float, delta: float) -> void:
    var pos: Vector3
    var flat: Vector3
    var look_ahead: Vector3
    var back := 2.9
    var up := 1.75
    if roam:
        var ds := distance - _roam_last
        _roam_last = distance
        if strid and strid.knocked_out():
            ds = 0.0
        fri.advance(maxf(ds, 0.0), delta)
        pos = fri.pos
        flat = Vector3(fri.heading.x, 0.0, fri.heading.y)
        var ahead := pos + flat * 18.0
        if strid:
            strid.place_tank(fri, delta)
            var cam: Array = battle_theme().get("camera", [10.5, 4.6])
            back = cam[0]
            up = cam[1]
            look_ahead = Vector3(ahead.x, ride_height(ahead.x, ahead.z) + 1.8, ahead.z)
        else:
            rider.place(pos, fri.direction())
            rider.animate(speed, cadence, delta)
            look_ahead = Vector3(ahead.x, ride_height(ahead.x, ahead.z) + 0.55, ahead.z)
            if base_tank and Vector2(pos.x - base_tank.position.x, pos.z - base_tank.position.z).length() < 7.5:
                take_tank()
        _update_falling(delta)
        _check_teleport()
    else:
        var here := sample(distance + lap_offset)
        var ahead_s := sample(distance + lap_offset + 18.0)
        var dir: Vector3 = here["dir"]
        flat = Vector3(dir.x, 0, dir.z).normalized()
        var right := flat.cross(Vector3.UP).normalized()
        pos = here["pos"] + right * (RIDE_OFFSET + lateral)
        rider.place(pos, dir)
        rider.animate(speed, cadence, delta)
        look_ahead = (ahead_s["pos"] as Vector3) + right * RIDE_OFFSET * 0.4 + Vector3.UP * 0.55
    var behind := flat.rotated(Vector3.UP, orbit)
    var target_pos := pos - behind * back + Vector3.UP * up
    if not _cam_ready or delta <= 0.0 or _cam_pos.distance_to(target_pos) > 30.0:
        _cam_pos = target_pos
        _cam_ready = true
    else:
        _cam_pos = _cam_pos.lerp(target_pos, clampf(delta * 4.0, 0.0, 1.0))
    # Never let the camera dip into a hillside or under a bridge deck.
    _cam_pos.y = maxf(_cam_pos.y, height(_cam_pos.x, _cam_pos.z) + 1.3)
    camera.position = _cam_pos
    camera.look_at(look_ahead.lerp(pos + Vector3.UP * (up * 0.63), clampf(absf(orbit) / 0.6, 0.0, 1.0)), Vector3.UP)
    if strid and strid.shake > 0.0:
        var a: float = strid.shake
        camera.position += Vector3(randf_range(-a, a), randf_range(-a, a), randf_range(-a, a)) * 0.5
    var now := Time.get_ticks_msec() / 1000.0
    for g in _gulls:
        var a: float = g[4] + now * g[3]
        var v := Vector3(-sin(a), 0.0, cos(a)) * signf(g[3])
        var node: Node3D = g[0]
        node.position = (g[1] as Vector3) + Vector3(cos(a), 0.0, sin(a)) * g[2] + Vector3.UP * sin(now * 0.7 + g[4]) * 1.5
        node.rotation = Vector3(0.0, atan2(-v.z, v.x), 0.35 * signf(g[3]))
    for p in _paddlers:
        var a: float = p[4] + now * p[3]
        var v := Vector3(-sin(a), 0.0, cos(a)) * signf(p[3])
        var node: Node3D = p[0]
        node.position = (p[1] as Vector3) + Vector3(cos(a), 0.0, sin(a)) * p[2] + Vector3.UP * sin(now * 2.1 + a) * 0.03
        node.rotation = Vector3(sin(now * 3.0) * 0.04, atan2(-v.z, v.x), 0.0)
    if _ferry:
        # 6 m/s; it starts well along the outbound lane so it is in sight from the harbour.
        var at := _ferry_at(now * 6.0 + 1300.0)
        _ferry.position = (at[0] as Vector3) + Vector3.UP * sin(now * 0.6) * 0.08
        _ferry.rotation = Vector3(0.0, at[1], sin(now * 0.5) * 0.01)
    if _radar_dish:
        _radar_dish.rotation.y = now * 1.1
    for b in _bobbers:
        var node: Node3D = b[0]
        node.position.y = b[1] + sin(Time.get_ticks_msec() / 1000.0 * 1.3 + b[2]) * 0.06
        node.rotation.z = sin(Time.get_ticks_msec() / 1000.0 * 0.9 + b[2]) * 0.03
    if _sommarliv:
        _sommarliv.update(now)


# --- Road network and free riding ("Tryck ej här") -------------------------------------------------
#
# Every rideable road is a path of points 2 m apart: path 0 is the lap (Kustvägen), the others are
# gravel roads. Normal rides follow the lap by distance. In free riding (world/fri_cykling.gd) the
# rider steers anywhere; the paths then give the road assist, the deck height on bridges and the
# name of the road the rider is on. Obstacles (houses, boulders, tree trunks) and the granite slabs
# the bike rides over are kept in 8 m buckets for quick lookups.

const PATH_STEP := 2.0
const BUCKET := 8.0
const FriCykling = preload("res://world/fri_cykling.gd")
const Strid = preload("res://world/strid.gd")

var paths: Array = []          # [{"name", "pts": PackedVector3Array, "closed", "length", "half"}]
var roam := false
var fri: FriCykling            # the free ride once "Tryck ej här" is pressed
var strid: Node3D              # tank, monsters and shells once the base's tank is taken
var _roam_last := 0.0          # the ride's distance last frame
var lap_offset := 0.0          # metres added to the ride's distance to find the place on the lap
                               # (changes when the rider comes back from free riding)
var _path_hash := {}           # bucket → [[path, index], …]
var _obstacles := {}           # bucket → [[x, z, r, tree], …]; tree = [multimesh, index, far multimesh] or []
var _bumps := {}               # bucket → [[x, z, r, top], …]: slabs and stones to ride over
var _falling: Array = []       # trees going over: [tree, start basis, axis, seconds]


## Path 0 is the lap itself.
func _init_network() -> void:
    paths = [{"name": lap_name(), "pts": road_pos, "closed": true, "length": length, "half": ROAD_HALF}]


## A gravel road as a rideable path from the lap point `from_i` along `centre` (the drawn centre
## line), optionally ending on the lap at `to_i`. Returns its index.
func _add_path(name: String, from_i: int, centre: PackedVector3Array, to_i := -1) -> int:
    var raw: Array[Vector3] = [road_pos[from_i]]
    for p in centre:
        raw.append(p)
    if to_i >= 0:
        raw.append(road_pos[to_i])
    var pts := _resample(raw, PATH_STEP)
    var ys := PackedFloat32Array()
    for p in pts:
        ys.append(p.y)
    for k in range(1, pts.size() - 1):
        pts[k].y = (ys[k - 1] + ys[k] * 2.0 + ys[k + 1]) / 4.0
    paths.append({"name": name, "pts": pts, "closed": false, "length": (pts.size() - 1) * PATH_STEP, "half": 1.5})
    return paths.size() - 1


func _resample(raw: Array[Vector3], step: float) -> PackedVector3Array:
    var out := PackedVector3Array([raw[0]])
    var carry := 0.0
    for k in range(1, raw.size()):
        var a: Vector3 = raw[k - 1]
        var b: Vector3 = raw[k]
        var seg := Vector2(b.x - a.x, b.z - a.z).length()
        var pos := step - carry
        while pos <= seg:
            out.append(a.lerp(b, pos / seg))
            pos += step
        carry = seg - (pos - step)
    if out[out.size() - 1].distance_to(raw[raw.size() - 1]) > 0.5:
        out.append(raw[raw.size() - 1])
    return out


func path_index(name: String) -> int:
    for k in paths.size():
        if paths[k]["name"] == name:
            return k
    return -1


static func _bucket(x: float, z: float) -> Vector2i:
    return Vector2i(floori(x / BUCKET), floori(z / BUCKET))


## Put an entry in every bucket its circle touches.
static func _file(table: Dictionary, x: float, z: float, r: float, entry: Array) -> void:
    for i in range(floori((x - r) / BUCKET), floori((x + r) / BUCKET) + 1):
        for j in range(floori((z - r) / BUCKET), floori((z + r) / BUCKET) + 1):
            var key := Vector2i(i, j)
            if not table.has(key):
                table[key] = []
            table[key].append(entry)


func _index_paths() -> void:
    _path_hash.clear()
    for k in paths.size():
        var pts: PackedVector3Array = paths[k]["pts"]
        for i in pts.size():
            var key := _bucket(pts[i].x, pts[i].z)
            if not _path_hash.has(key):
                _path_hash[key] = []
            _path_hash[key].append([k, i])


## Something the bike cannot ride through: a circle on the ground.
func _block(x: float, z: float, r: float, tree: Array = []) -> void:
    _file(_obstacles, x, z, r, [x, z, r, tree])


## A building or other prop: circles along its longer side, from its model's bounding box.
func _block_prop(node: Node3D, name: String) -> void:
    var mesh := _first_mesh(node)
    if mesh == null:
        return
    var box := mesh.get_aabb()
    if box.size.y < 1.2 or name.begins_with("skylt") or name.contains("brygga") or name in ["boj", "eka", "eka_gron", "snipa", "kajak", "roddbat"]:
        return
    if name.contains("trad") or name in ["syren", "flaggstang", "vimpelstang", "midsommarstang", "klockstapel"]:
        var foot := node.global_transform.origin if node.is_inside_tree() else node.position
        _block(foot.x, foot.z, 0.45 * node.scale.x)
        return
    var long_x := box.size.x >= box.size.z
    var lo: float = box.position.x if long_x else box.position.z
    var hi: float = box.end.x if long_x else box.end.z
    var r: float = (box.size.z if long_x else box.size.x) * 0.5 * 0.92
    var mid: float = box.get_center().z if long_x else box.get_center().x
    var n := maxi(1, ceili((hi - lo) / maxf(r * 1.6, 0.5)))
    for k in n:
        var along := lerpf(lo + r, hi - r, (k + 0.5) / n) if hi - lo > 2.0 * r else (lo + hi) * 0.5
        var local := Vector3(along, 0.0, mid) if long_x else Vector3(mid, 0.0, along)
        var p := node.transform * local
        _block(p.x, p.z, r * node.scale.x)


## Bike-level ground height: the deck of a road or bridge where the wheels are on one, otherwise
## the drawn terrain, raised over granite slabs and stones.
func ride_height(x: float, z: float) -> float:
    var r := road_near(x, z)
    if not r.is_empty() and r["d"] < float(r["half"]) + 0.3:
        return r["y"]
    var h := _mesh_height(x, z)
    var cell = _bumps.get(_bucket(x, z))
    if cell != null:
        for b in cell:
            var dx: float = x - b[0]
            var dz: float = z - b[1]
            var f: float = (dx * dx + dz * dz) / (b[2] * b[2])
            if f < 1.0:
                h = maxf(h, lerpf(b[3], h, f))
    return h


## Where free riding may go: the detailed core less a margin. A world can open a little more.
func _in_ride_area(x: float, z: float) -> bool:
    return CORE.grow(-30.0).has_point(Vector2(x, z))


## Can something of `radius` stand at (x, z)? Not in the water (unless on a road or bridge deck),
## not off the edge of the map and not inside a house, boulder or (for the bike) a tree trunk.
func free_at(x: float, z: float, radius: float) -> bool:
    if not _in_ride_area(x, z):
        return false
    var r := road_near(x, z)
    if r.is_empty() or r["d"] > float(r["half"]) + 0.2:
        var probes := [Vector2.ZERO] if radius < 1.0 else [Vector2.ZERO, Vector2(radius, 0), Vector2(-radius, 0), Vector2(0, radius), Vector2(0, -radius)]
        for o in probes:
            if _mesh_height(x + o.x, z + o.y) < 0.15:
                return false
    var tank := radius > 1.0
    for i in range(floori((x - radius) / BUCKET), floori((x + radius) / BUCKET) + 1):
        for j in range(floori((z - radius) / BUCKET), floori((z + radius) / BUCKET) + 1):
            var cell = _obstacles.get(Vector2i(i, j))
            if cell == null:
                continue
            for o in cell:
                if tank and not (o[3] as Array).is_empty():
                    continue    # the tank pushes trees over instead
                var dx: float = x - o[0]
                var dz: float = z - o[1]
                var reach: float = o[2] + radius
                if dx * dx + dz * dz < reach * reach:
                    return false
    return true


## The nearest road point within a bucket or so: {"k" path, "i" index, "d" metres from the centre
## line, "y" deck height, "dir" (Vector2 along increasing index), "half" half-width}, or {}.
func road_near(x: float, z: float) -> Dictionary:
    var key := _bucket(x, z)
    var best := 1e9
    var bk := -1
    var bi := 0
    for dx in range(-1, 2):
        for dz in range(-1, 2):
            var cell = _path_hash.get(Vector2i(key.x + dx, key.y + dz))
            if cell == null:
                continue
            for e in cell:
                var p: Vector3 = paths[e[0]]["pts"][e[1]]
                var d := (p.x - x) * (p.x - x) + (p.z - z) * (p.z - z)
                if d < best:
                    best = d
                    bk = e[0]
                    bi = e[1]
    if bk < 0:
        return {}
    var path: Dictionary = paths[bk]
    var pts: PackedVector3Array = path["pts"]
    var n := pts.size()
    var out := {}
    for seg in [[bi - 1, bi], [bi, bi + 1]]:
        var i0: int = seg[0]
        var i1: int = seg[1]
        if path["closed"]:
            i0 = posmod(i0, n)
            i1 = posmod(i1, n)
        elif i0 < 0 or i1 >= n:
            continue
        var a := pts[i0]
        var b := pts[i1]
        var ab := Vector2(b.x - a.x, b.z - a.z)
        var t := clampf(Vector2(x - a.x, z - a.z).dot(ab) / maxf(ab.length_squared(), 1e-4), 0.0, 1.0)
        var d := Vector2(x, z).distance_to(Vector2(a.x, a.z) + ab * t)
        if out.is_empty() or d < out["d"]:
            out = {"k": bk, "i": i0, "d": d, "y": lerpf(a.y, b.y, t), "dir": ab.normalized(), "half": path["half"]}
    return out


## A point `ahead` metres on along the road in direction `sense` (±1), in the rider's lane.
func road_ahead(road: Dictionary, sense: float, ahead: float) -> Vector3:
    var path: Dictionary = paths[road["k"]]
    var pts: PackedVector3Array = path["pts"]
    var n := pts.size()
    var j: int = road["i"] + int(sense) * roundi(ahead / PATH_STEP)
    j = posmod(j, n) if path["closed"] else clampi(j, 0, n - 1)
    var j2 := j + int(sense)
    j2 = posmod(j2, n) if path["closed"] else clampi(j2, 0, n - 1)
    var dir := Vector2(pts[j2].x - pts[j].x, pts[j2].z - pts[j].z) * (1.0 if j2 != j else 0.0)
    if dir.length() < 0.01:
        return pts[j]
    if j2 < j and not path["closed"]:
        dir = -dir
    dir = dir.normalized()
    var lane := RIDE_OFFSET if road["k"] == 0 else 0.35
    return pts[j] + Vector3(-dir.y, 0.0, dir.x) * lane


## The tank pushes over the trees it drives into (and shells flatten the ones near a burst):
## each falls away from `push` (or outward from the centre when push is zero).
func knock_trees(x: float, z: float, r: float, push: Vector2) -> void:
    var cell = _obstacles.get(_bucket(x, z))
    if cell == null:
        return
    for o in cell:
        var tree: Array = o[3]
        if tree.is_empty() or tree.size() > 3:
            continue
        var d := Vector2(o[0] - x, o[1] - z)
        if d.length() > r + o[2]:
            continue
        var away := push if push != Vector2.ZERO else d.normalized()
        if away == Vector2.ZERO:
            away = Vector2(1, 0)
        away = (away + d.normalized() * 0.4).normalized()
        var mm: MultiMesh = (tree[0] as MultiMeshInstance3D).multimesh
        var axis := Vector3(away.y, 0.0, -away.x).normalized()      # falls towards `away`
        _falling.append([tree, mm.get_instance_transform(tree[1]).basis, axis, 0.0])
        tree.append(true)       # marked: already falling (and never an obstacle again)
        o[2] = 0.0


func _update_falling(delta: float) -> void:
    for k in range(_falling.size() - 1, -1, -1):
        var f: Array = _falling[k]
        f[3] += delta
        var t := clampf(f[3] / 1.4, 0.0, 1.0)
        var angle := 1.45 * t * t            # accelerates as it goes over
        var tree: Array = f[0]
        for m in [tree[0], tree[2]]:
            if m == null:
                continue
            var mm: MultiMesh = (m as MultiMeshInstance3D).multimesh
            var tf := mm.get_instance_transform(tree[1])
            tf.basis = Basis(f[2], angle) * f[1]
            mm.set_instance_transform(tree[1], tf)
        if t >= 1.0:
            _falling.remove_at(k)


## Begin free riding from the rider's place on the lap.
func start_roam(distance: float) -> void:
    roam = true
    _roam_last = distance
    if _path_hash.is_empty():
        _index_paths()
    var here := sample(distance + lap_offset)
    var d: Vector3 = here["dir"]
    var flat := Vector3(d.x, 0, d.z).normalized()
    fri = FriCykling.new(self)
    fri.start((here["pos"] as Vector3) + Vector3(-flat.z, 0.0, flat.x) * (RIDE_OFFSET + lateral), Vector2(flat.x, flat.z))
    lateral = 0.0


## Put the free rider at (x, z) heading `degrees` (0 = +X, 90 = +Z) — for tests and screenshots.
func place_free(x: float, z: float, degrees: float) -> void:
    if not roam:
        start_roam(0.0)
    fri.start(Vector3(x, 0.0, z), Vector2.from_angle(deg_to_rad(degrees)))
    _cam_ready = false


## Grade the trainer should feel now: the lap's at `distance`, or the free ride's.
func current_grade(distance: float) -> float:
    return fri.grade if roam else grade_at(distance + lap_offset)


## Where the ride's distance puts the rider on the lap (for the profile on screen).
func lap_distance(distance: float) -> float:
    return distance + lap_offset


## "Tillbaka till vägen": end free riding (and the tank and the battle, if on) and put the bike
## back on the lap at the point nearest to where it is, going round the usual way.
func end_roam(distance: float) -> void:
    if not roam:
        return
    var s := _nearest_s(Vector2(fri.pos.x, fri.pos.z))
    lap_offset = fposmod(s - distance, length)
    if strid:
        strid.queue_free()
        strid = null
        if base_tank:
            base_tank.visible = true
    rider.visible = true
    roam = false
    fri = null
    lateral = 0.0
    orbit = 0.0
    _cam_ready = false


func current_road() -> String:
    if not roam:
        return lap_name()
    var place := _place_name(fri.pos)
    if place != "":
        return place
    if not fri.road.is_empty() and fri.road["d"] < float(fri.road["half"]) + 1.5:
        return paths[fri.road["k"]]["name"]
    return "Terrängen"


## How far the rider may steer across the road on the lap (metres from the usual line).
func lateral_range() -> Vector2:
    return Vector2(-2.9, 0.9)


## The parked tank: ride up to it and the bike becomes a tank, and the monsters wake.
func take_tank() -> void:
    if strid or base_tank == null:
        return
    strid = Strid.new()
    strid.world = self
    add_child(strid)
    var tf := base_tank.transform
    base_tank.visible = false
    rider.visible = false
    fri.radius = float(battle_theme().get("radius", 1.6))
    fri.start(Vector3(tf.origin.x, 0.0, tf.origin.z), Vector2(tf.basis.x.x, tf.basis.x.z))
    strid.activate(fri)


# --- What a world can change (Egypten overrides these; see world/egypten/egypten.gd) --------------

func _road_ctrl() -> Array:
    return ROAD


## The map's detailed core (see CORE): each world returns its own. Skärgården's spans the three
## islands added for the 12 km lap (Norrholmen in the north, Storön in the east, Långön in the south).
func _core() -> Rect2:
    return Rect2(-820, -900, 2800, 1920)


## 0 where the road should run straight (no sideways weave), 1 elsewhere.
func _weave_calm(p: Vector2) -> float:
    return smoothstep(70.0, 150.0, p.distance_to(HARBOUR))


func lap_name() -> String:
    return "Kustvägen"


## The timed segments on the lap (metres from the start line). Records and the HUD's segment card
## come from these; see core/lap_tracker.gd.
func segments() -> Array:
    return [
        # The 6 km lap's four keep their ids: the same road, only further along the 12 km lap.
        {"id": "klipporna", "name": "Klipporna", "kind": "climb", "from": 486.0, "to": 896.0},
        {"id": "fiskelagesbacken", "name": "Fiskelägesbacken", "kind": "climb", "from": 2840.0, "to": 2960.0},
        {"id": "kyrkbacken", "name": "Kyrkbacken", "kind": "climb", "from": 4102.0, "to": 4592.0},
        {"id": "kyrkbyspurten", "name": "Kyrkbyspurten", "kind": "sprint", "from": 4300.0, "to": 4496.0},
        {"id": "fyrberget", "name": "Fyrberget", "kind": "climb", "from": 5090.0, "to": 5402.0},
        {"id": "storberget", "name": "Storberget", "kind": "climb", "from": 6500.0, "to": 7200.0},
        {"id": "storospurten", "name": "Storöspurten", "kind": "sprint", "from": 7700.0, "to": 7950.0},
        {"id": "langobron", "name": "Långöbron", "kind": "sprint", "from": 10100.0, "to": 10400.0},
        {"id": "strandspurten", "name": "Strandspurten", "kind": "sprint", "from": 10950.0, "to": 11150.0},
    ]


## What the wheels roll on (Ride uses it for the bike's rolling resistance): the lap is asphalt,
## the other roads gravel, the rest terrain.
func surface() -> String:
    if not roam:
        return "asfalt"
    if not fri.road.is_empty() and fri.road["d"] < float(fri.road["half"]) + 1.0:
        return "asfalt" if int(fri.road["k"]) == 0 else "grus"
    return "terrang"


## The ghost: your best lap, ridden beside you as a see-through rider (core/lap_tracker.gd works out
## where it is). Hidden while free riding or when there is no best lap yet.
var ghost: Node3D = null


func show_ghost(s: float, speed: float, delta: float) -> void:
    if ghost == null:
        ghost = Rider.new()
        add_child(ghost)
        ghost.ghostify()
    ghost.visible = true
    var here := sample(s)
    var dir: Vector3 = here["dir"]
    var flat := Vector3(dir.x, 0.0, dir.z).normalized()
    var right := flat.cross(Vector3.UP).normalized()
    ghost.place(here["pos"] + right * (RIDE_OFFSET - 1.15), dir)
    ghost.animate(speed, 88.0 if speed > 0.5 else 0.0, delta)


func hide_ghost() -> void:
    if ghost:
        ghost.visible = false


func _zone_rock(zone: String) -> Array:
    return ZONE_ROCK.get(zone, [0.7, 0.0])


func _ground_shader() -> Shader:
    return GROUND_SHADER


## [[centre, radius], …] off the road that get the fine 3 m terrain grid.
func _fine_areas() -> Array:
    return [[Vector2(BASE.x, BASE.z), BASE_R * 1.6]]


func _kind_scale(kind: String) -> Array:
    return KIND_SCALE.get(kind, [1.0, 1.0])


func _variants(kind: String) -> int:
    return int(VARIANTS.get(kind, 1))


func _is_tree(kind: String) -> bool:
    return kind in TREE_KINDS


func _sways(kind: String) -> bool:
    return kind in SWAY_KINDS


func _is_small(kind: String) -> bool:
    return kind in SMALL_KINDS


func _is_rock(_kind: String) -> bool:
    return false


## Visibility range for scattered kinds this world adds (0 = use the defaults).
func _view_range(_kind: String, _name: String) -> float:
    return 0.0


## The name of where the free rider is when it is a place rather than a road ("" otherwise).
func _place_name(p: Vector3) -> String:
    if Vector2(p.x - BASE.x, p.z - BASE.z).length() < BASE_R + 2.0:
        return "Militärbasen"
    return ""


## The battle's cast and words (world/strid.gd reads this).
func battle_theme() -> Dictionary:
    return {
        "vehicle": "stridsvagn", "turret": "Torn", "gun": "Kanon", "muzzle": 4.15, "weapon": "kanon",
        "radius": 1.6, "camera": [10.5, 4.6], "monsters": [["zombie", 0.5], ["pysare", 0.3], ["alien", 0.2]],
        "boss": "ufo", "title": "STRIDSVAGN", "names": {"zombie": "Zombier", "pysare": "Pysare", "alien": "Aliens", "ufo": "UFO"},
        "found": "Du hittade den hemliga basen! Cykeln är nu en stridsvagn.",
        "alarm": "Larm! Monstren har vaknat. Skjut med %s.",
        "boss_in": "Ett UFO! Det släpper ner aliens. Åtta träffar fäller det.",
        "boss_down": "UFO:t är nere! +500",
        "knocked": "Stridsvagnen är utslagen! Basen skickar en ny …",
        "new": "Basen skickade en ny stridsvagn. Kör vidare!",
    }


## Where a walking boss comes from (not used by the UFO).
func boss_spawn() -> Vector3:
    return Vector3(BASE.x, BASE.y, BASE.z)


# --- Teleport bridges -----------------------------------------------------------------------------
#
# A short bridge (or jetty) with a glowing gate. Riding through the gate while riding free takes
# you to the other world (main.gd swaps the worlds; the ride and the workout go on). On arrival the
# rider stands just past that world's own gate, still riding free.

var teleports: Array = []      # [[gate position, target world id, direction across the gate]]
var teleport_to := ""          # set when the rider has ridden through a gate (main.gd acts on it)
var _tele_armed := true        # false until the rider has left the gate behind after arriving


func _teleport_bridge(a: Vector3, b: Vector3, gate_t: float, target: String, label: String) -> void:
    var d := Vector3(b.x - a.x, 0.0, b.z - a.z)
    var span := d.length()
    var dir := d / span
    var right := Vector3(-dir.z, 0.0, dir.x)
    var pts := PackedVector3Array()
    var n := maxi(int(span / PATH_STEP), 2)
    for k in n + 1:
        var t := float(k) / n
        var p := a.lerp(b, t)
        p.y = lerpf(a.y, b.y, t) + sin(t * PI) * 1.0
        pts.append(p)
    paths.append({"name": "Teleportbron", "pts": pts, "closed": false, "length": span, "half": 1.7})
    # Deck slabs and low parapets, one multimesh each.
    var deck := []
    var walls := []
    for k in n:
        var p0 := pts[k]
        var p1 := pts[k + 1]
        var seg := p1 - p0
        var basis := Basis.looking_at(seg.normalized(), Vector3.UP)
        var mid := (p0 + p1) * 0.5
        deck.append(Transform3D(basis * Basis.from_scale(Vector3(3.6, 0.45, seg.length() + 0.05)), mid - Vector3.UP * 0.25))
        for side: float in [-1.0, 1.0]:
            walls.append(Transform3D(basis * Basis.from_scale(Vector3(0.35, 0.8, seg.length() + 0.05)),
                mid + right * side * 1.95 + Vector3.UP * 0.35))
    add_child(_multimesh(_box_mesh(Vector3.ONE, Color("cdb48c")), deck))
    add_child(_multimesh(_box_mesh(Vector3.ONE, Color("b89c72")), walls))
    var gate_pos := a.lerp(b, gate_t)
    gate_pos.y = lerpf(a.y, b.y, gate_t) + sin(gate_t * PI) * 1.0 - 0.05
    var gate := _scene("teleportport")
    gate.position = gate_pos
    gate.rotation.y = atan2(-dir.z, dir.x)
    add_child(gate)
    # A pillar of light over the gate, so the portal shows from the lap and from afar.
    var beam := MeshInstance3D.new()
    var tube := CylinderMesh.new()
    tube.top_radius = 2.4
    tube.bottom_radius = 3.0
    tube.height = 160.0
    tube.radial_segments = 16
    tube.rings = 1
    tube.cap_top = false
    tube.cap_bottom = false
    beam.mesh = tube
    var beam_mat := ShaderMaterial.new()
    beam_mat.shader = PORTAL_BEAM
    beam.material_override = beam_mat
    beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    beam.position = gate_pos + Vector3.UP * 80.0
    add_child(beam)
    for side: float in [-1.0, 1.0]:
        var q := gate_pos + right * side * 3.6
        _block(q.x, q.z, 0.9)
    var sp := a - dir * 3.0 + right * 3.0
    var sign := _scene("skylt_vag_h")
    sign.position = Vector3(sp.x, height(sp.x, sp.z), sp.z)
    sign.rotation.y = atan2(-dir.x, -dir.z)
    add_child(sign)
    _sign_text(sign, label, Vector3(0.04, 2.175, 0.035), Color("1d1f22"), 30)
    _keep(Vector2(gate_pos.x, gate_pos.z), 8.0)
    teleports.append([gate_pos, target, dir])


func _check_teleport() -> void:
    if teleports.is_empty() or teleport_to != "":
        return
    var p := Vector2(fri.pos.x, fri.pos.z)
    var nearest := INF
    for t in teleports:
        var g: Vector3 = t[0]
        var d := p.distance_to(Vector2(g.x, g.z))
        nearest = minf(nearest, d)
        if d < 2.6 and _tele_armed:
            teleport_to = t[1]
    if nearest > 10.0:
        _tele_armed = true


## Arrived through a gate from the other world: ride free from this world's gate towards the
## land end of its bridge (a jetty's far end is open water), on the nearest dry spot.
func arrive_by_teleport(distance: float) -> void:
    start_roam(distance)
    if teleports.is_empty():
        return
    var g: Vector3 = teleports[0][0]
    var dir: Vector3 = teleports[0][2]
    var at := nearest_free(g - dir * 7.0, fri.radius)
    fri.start(Vector3(at.x, 0.0, at.z), Vector2(-dir.x, -dir.z))
    _tele_armed = false
    _cam_ready = false


## The nearest spot to p where something of `radius` can stand (rings out to 60 m), or p itself.
func nearest_free(p: Vector3, radius: float) -> Vector3:
    if free_at(p.x, p.z, radius):
        return p
    for ring in range(1, 31):
        var r := ring * 2.0
        for k in 16:
            var a := TAU * k / 16.0
            var q := Vector2(p.x + cos(a) * r, p.z + sin(a) * r)
            if free_at(q.x, q.y, radius):
                return Vector3(q.x, p.y, q.y)
    return p


## The teleport jetty to Egypten: out from the shore near the start, the gate at its far end.
func _place_teleport_sk() -> void:
    for s in range(140, 1400, 20):
        var i := int(s / STEP)
        for side: float in [-1.0, 1.0]:
            var r := _right(i) * side
            var p0 := road_pos[i]
            var shore := _shore_from(p0, r)
            var d := Vector2(shore.x - p0.x, shore.z - p0.z).length()
            if d < 10.0 or d > 40.0:
                continue
            var a := shore - r * 4.0
            var b := shore + r * 22.0
            if height(b.x, b.z) > -1.0:
                continue
            var clear := true
            for t: float in [0.0, 0.33, 0.66, 1.0]:
                var q := a.lerp(b, t)
                if not _free_spot(q.x, q.z, 4.0):
                    clear = false
            if not clear:
                continue
            a.y = maxf(height(a.x, a.z), 0.0) + 0.6
            b.y = 1.2
            _teleport_bridge(a, b, 0.85, "egypten", "Till Egypten")
            return


## The secret military base on the plateau east of Fyrberget, 120 m from the lap and hidden in the
## pine forest: a fenced yard cut flat into the rock, a rock-shelter portal, a hangar with the tank
## parked outside, barracks, a radar and a watchtower. A gravel track leads in from the lap behind
## a red and white barrier and a yellow warning sign. Only free riding gets you past the barrier.
func _place_base() -> void:
    var c := BASE
    var at := func(dx: float, dz: float) -> Vector3: return Vector3(c.x + dx, c.y, c.z + dz)
    _keep(Vector2(c.x, c.z), BASE_R + 5.0)
    # The track: from the lap at the top of the climb, past the barrier and in through the gate.
    var s0 := _nearest_s(Vector2(560.0, -150.0))
    var i0 := int(s0 / STEP) % road_pos.size()
    var p0 := road_pos[i0]
    var r := _right(i0)
    if r.dot(c - p0) < 0.0:
        r = -r
    var gate: Vector3 = at.call(-BASE_R, 0.0)
    var ctrl := [p0 + r * 2.9, p0 + r * 16.0 + (gate - p0).normalized() * 6.0, (p0 + gate) * 0.5 + Vector3(0, 0, -4.0),
        gate - Vector3(10.0, 0, 0), gate, at.call(-14.0, 0.0)]
    _add_path("Förbjudna vägen", i0, _gravel(ctrl, 3.0))
    # Barrier and warning sign 14 m in from the lap.
    var bp := p0 + r * 14.0
    var bdir := ((ctrl[2] as Vector3) - bp).normalized()
    var across := Vector3(-bdir.z, 0, bdir.x)
    var bom_pos := bp - across * 3.0
    var bom := _prop("bom", _ground(bom_pos.x, bom_pos.z), atan2(-across.z, across.x) - PI / 2.0)
    for k in 7:
        var q := bom_pos + across * k
        _block(q.x, q.z, 0.45)
    var sp := bp + across * 3.0 - bdir * 1.0
    var sign := _prop("skylt_skydd", _ground(sp.x, sp.z), atan2(bdir.z, -bdir.x))
    _sign_text(sign, "MILITÄRT OMRÅDE\nTillträde förbjudet", Vector3(0.08, 1.78, 0.0), Color("1d1f22"), 40)
    sign.get_child(sign.get_child_count() - 1).rotation.y = PI / 2.0
    _keep(Vector2(bom.position.x, bom.position.z), 4.0)
    # Fence round the yard, with the gate on the west side and the rock to the north.
    var fence := []
    var steps := 80
    for k in steps:
        var a0 := TAU * k / steps
        var a1 := TAU * (k + 1) / steps
        var e0 := Vector3(c.x + cos(a0) * BASE_R, 0, c.z + sin(a0) * BASE_R)
        var e1 := Vector3(c.x + cos(a1) * BASE_R, 0, c.z + sin(a1) * BASE_R)
        var mid := (e0 + e1) * 0.5
        if absf(mid.z - c.z) < 4.5 and mid.x < c.x:
            continue                # the gate
        if absf(mid.x - (c.x + 4.0)) < 18.0 and mid.z < c.z - 20.0:
            continue                # the rock shelter's knoll closes this side
        var d := e1 - e0
        e0.y = height(e0.x, e0.z) - 0.05
        fence.append(Transform3D(Basis(Vector3.UP, atan2(-d.z, d.x)) * Basis.from_scale(Vector3(d.length() / 3.0, 1.0, 1.0)), e0))
        for t in 4:
            var q := e0.lerp(e1, t / 4.0)
            _block(q.x, q.z, 0.3)
    add_child(_multimesh(_merged(_model_mesh("stangsel")), fence))
    for side in [-1.0, 1.0]:
        var gp: Vector3 = at.call(-BASE_R, side * 4.6)
        _prop("vakttorn", _ground(gp.x + 5.0, gp.z + side * 6.0), 0.0, 0.9)
    # The yard.
    var place := [
        ["bergrum", 4.0, -26.0, -PI / 2.0], ["hangar", 14.0, 4.0, PI], ["barack", -14.0, 26.0, PI],
        ["barack", 4.0, 28.0, PI], ["helipad", -14.0, -10.0, 0.0], ["drivmedel", -26.0, 12.0, 0.4],
        ["sandsackar", -31.0, 7.0, 0.0], ["sandsackar", -31.0, -7.0, 0.0], ["lador", 8.0, -7.0, 0.3],
        ["lador", 6.0, 13.0, 1.2], ["kamonat", 24.0, 20.0, 0.5], ["lastbil", 24.0, 20.0, 0.5 + PI],
        ["flaggstang", -8.0, 14.0, 0.0],
    ]
    for e in place:
        var p: Vector3 = at.call(e[1], e[2])
        var node := _prop(e[0], p, e[3])
        if e[0] == "bergrum":
            var plate := node
            _sign_text(plate, "BERGRUM 7", Vector3(1.12, 4.6, 5.3), Color("1d1f22"), 52)
            plate.get_child(plate.get_child_count() - 1).rotation.y = PI / 2.0
    var radar := _scene("radar")
    radar.position = at.call(22.0, -14.0)
    add_child(radar)
    _radar_dish = radar.find_child("Antenn", true, false)
    _block(radar.position.x, radar.position.z, 2.2)
    # The tank, parked in front of the hangar doors and facing the gate.
    base_tank = _scene("stridsvagn")
    base_tank.position = at.call(-3.0, 4.0)
    base_tank.rotation.y = PI
    add_child(base_tank)


## The base is cut flat into the plateau: full height inside the fence, blending out beyond it.
func _base_flatten(x: float, z: float, h: float) -> float:
    var d := Vector2(x - BASE.x, z - BASE.z).length()
    if d > BASE_R * 1.5:
        return h
    return lerpf(BASE.y, h, smoothstep(BASE_R * 1.08, BASE_R * 1.5, d))


## Kyrkvägen: a gravel road from the start by the harbour straight up through the island to the
## church village's loop, with signs at both ends.
func _place_kyrkvagen() -> void:
    var a := int(_nearest_s(Vector2(180.0, 345.0)) / STEP)
    var b := int(_nearest_s(Vector2(212.0, 140.0)) / STEP)
    var pa := road_pos[a]
    var pb := road_pos[b]
    var ctrl := [pa + _right(a) * 2.9, Vector3(184.0, 0, 312.0), Vector3(192.0, 0, 262.0), Vector3(201.0, 0, 205.0),
        pb - (Vector3(pb.x - 201.0, 0, pb.z - 205.0)).normalized() * 2.9]
    var centre := _gravel(ctrl, 3.2)
    _add_path("Kyrkvägen", a, centre, b)
    for end in [[a, "Kyrkbyn"], [b, "Hamnen"]]:
        var i: int = end[0]
        var flat := Vector3(road_dir[i].x, 0, road_dir[i].z).normalized()
        var rr := _right(i)
        var sp: Vector3 = road_pos[i] - flat * 10.0 + rr * 4.3
        var to_road := Vector2(201.0 - sp.x, 230.0 - sp.z)
        var right_turn := Vector2(rr.x, rr.z).dot(to_road) > 0.0
        var sign := _prop("skylt_vag_h" if right_turn else "skylt_vag_v", _ground(sp.x, sp.z), atan2(-flat.x, -flat.z))
        _sign_text(sign, end[1], Vector3(0.04 * (1.0 if right_turn else -1.0), 2.175, 0.035), Color("1d1f22"), 34)
        _keep(Vector2(sp.x, sp.z), 1.2)


## Grade in percent at distance s (what SIM sends to the trainer).
func grade_at(s: float) -> float:
    return sample(s)["grade"]


## Heights along the whole loop, for the elevation profile on screen.
func profile(points := 300) -> PackedFloat32Array:
    var out := PackedFloat32Array()
    for k in points:
        out.append(sample(length * k / points)["pos"].y)
    return out


# --- Terrain height --------------------------------------------------------------------------

func _make_islets() -> void:
    for sk in SKERRIES:
        _islets.append([sk[0], sk[1], sk[2], sk[3], sk[4]])
    # Small islands scattered over the sea for depth; kept clear of the road area.
    for k in 110:
        var c := Vector2(_rng.randf_range(-2600, 2800), _rng.randf_range(-2400, 2400))
        var inside := CORE.grow(60.0).has_point(c)
        if inside and _near_road_points(c, 140.0):
            continue
        var r := _rng.randf_range(14, 70) * (1.0 if inside else 2.2)
        _islets.append([c.x, c.y, r * _rng.randf_range(0.7, 1.3), r, _rng.randf_range(2.0, 9.0) * (1.0 if inside else 1.8)])
    _index_islets()


var _islet_hash := {}     # 100 m cell → the islets reaching into it (natural() looks only there)


func _index_islets() -> void:
    _islet_hash.clear()
    for isl in _islets:
        var rx: float = isl[2] * 1.2
        var rz: float = isl[3] * 1.2
        for cx in range(floori((isl[0] - rx) / 100.0), floori((isl[0] + rx) / 100.0) + 1):
            for cz in range(floori((isl[1] - rz) / 100.0), floori((isl[1] + rz) / 100.0) + 1):
                var key := Vector2i(cx, cz)
                if not _islet_hash.has(key):
                    _islet_hash[key] = []
                _islet_hash[key].append(isl)


func _near_road_points(c: Vector2, margin: float) -> bool:
    for p in ROAD:
        if c.distance_to(p) < margin:
            return true
    return false


func _dome(x: float, z: float, isl: Array) -> float:
    var dx: float = (x - isl[0]) / isl[2]
    var dz: float = (z - isl[1]) / isl[3]
    var f := 1.0 - dx * dx - dz * dz
    if f > 0.0:
        return -2.5 + (isl[4] + 2.5) * pow(f, 0.55)
    return -2.5 + f * 30.0


## Natural ground height before the road is cut in. Sea floor is about -9 m.
func natural(x: float, z: float) -> float:
    var h := -9.0
    # Warp the coordinates so the big islands get bays and points instead of perfect ellipses.
    var wx := x + _noise.get_noise_2d(x * 0.45 + 200.0, z * 0.45) * 60.0
    var wz := z + _noise.get_noise_2d(x * 0.45, z * 0.45 + 300.0) * 60.0
    for isl in ISLANDS:
        # Beyond 1.12 radii a dome is below the -9 m sea floor anyway: skip the pow (it was most
        # of the terrain's build time once the 12 km lap brought 14 islands).
        var dx: float = (wx - isl[0]) / isl[2]
        var dz: float = (wz - isl[1]) / isl[3]
        if dx * dx + dz * dz < 1.25:
            h = maxf(h, _dome(wx, wz, isl))
    var near_islets = _islet_hash.get(Vector2i(floori(x / 100.0), floori(z / 100.0)))
    if near_islets != null:
        for isl in near_islets:
            if absf(x - isl[0]) < isl[2] * 1.2 and absf(z - isl[1]) < isl[3] * 1.2:
                h = maxf(h, _dome(x, z, isl))
    for bay in BAYS:
        var bx: float = (x - bay[0]) / bay[2]
        var bz: float = (z - bay[1]) / bay[3]
        var f := 1.0 - bx * bx - bz * bz
        if f > 0.0:
            h = lerpf(h, minf(h, -3.0 - 5.0 * f), smoothstep(0.0, 0.3, f))
    for lake in LAKES:
        var lx: float = (x - lake[0]) / lake[2]
        var lz: float = (z - lake[1]) / lake[3]
        var g := 1.0 - lx * lx - lz * lz
        if g > -2.2:
            h = lerpf(h, -2.5 - 2.0 * maxf(g, 0.0), smoothstep(-2.2, 0.15, g))
    # The harbour lies low: road, boathouses and jetty only just above the water.
    var harbour_d := Vector2(x, z).distance_to(HARBOUR + Vector2(0.0, 20.0))
    if harbour_d < 170.0:
        h = minf(h, lerpf(1.4, h, smoothstep(70.0, 170.0, harbour_d)))
    var rock := clampf((h + 3.0) / 6.0, 0.0, 1.0)
    rock *= _flatness(x, z)
    # Big rounded slabs plus smaller knolls: the bumpy granite of the outer archipelago.
    h += (_noise.get_noise_2d(x, z) * 5.0 + _noise.get_noise_2d(x * 3.1 + 900.0, z * 3.1) * 1.6) * rock
    return _base_flatten(x, z, h)


## 1 on ordinary ground, falling towards 0.25 in the open village and pasture land (FLATS).
func _flatness(x: float, z: float) -> float:
    var f := 1.0
    for fl in FLATS:
        var d := Vector2(x, z).distance_to(Vector2(fl[0], fl[1]))
        f = minf(f, lerpf(0.25, 1.0, smoothstep(float(fl[2]) * 0.55, float(fl[2]), d)))
    var db := Vector2(x, z).distance_to(Vector2(BASE.x, BASE.z))
    return minf(f, lerpf(0.25, 1.0, smoothstep(BASE_R, BASE_R * 1.5, db)))


## Final ground height: natural ground blended into a flat road bed near the road.
func height(x: float, z: float) -> float:
    return _height_near(x, z, _nearest_road(x, z))


## Height when the nearest road point [distance, index] is already known.
func _height_near(x: float, z: float, near: Array) -> float:
    var h := natural(x, z) * _vy
    if not diorama and h > 0.4:
        # Rounded rock humps on land, lower in the village and the meadow.
        var hump: float = float(_zone_rock(zone_at(near[1] * STEP))[0]) if near[0] < 40.0 else 0.7
        h += _rundhall(x, z) * hump * clampf((h - 0.4) / 1.5, 0.0, 1.0) * (_flatness(x, z) - 0.25) / 0.75
    if near[0] < 30.0:
        var i: int = near[1]
        if road_bridge[i] == 1:
            return minf(h, -2.0) if near[0] < 9.0 else h
        # Only a narrow flat bed: the rock rises right beside the road, as in the concept art.
        var w := 1.0 - smoothstep(3.6, 14.0, near[0])
        h = lerpf(h, road_pos[i].y - 0.12, w)
    return h


func _nearest_road(x: float, z: float) -> Array:
    var key := Vector2i(floori(x / 20.0), floori(z / 20.0))
    var best := 1e9
    var best_i := 0
    for dx in range(-2, 3):
        for dz in range(-2, 3):
            var cell = _road_hash.get(Vector2i(key.x + dx, key.y + dz))
            if cell == null:
                continue
            for i in cell:
                var p := road_pos[i]
                var d := (p.x - x) * (p.x - x) + (p.z - z) * (p.z - z)
                if d < best:
                    best = d
                    best_i = i
    return [sqrt(best), best_i]


# --- Road -------------------------------------------------------------------------------------

func _build_road() -> void:
    # Closed Catmull-Rom through the control points, then resampled every STEP metres.
    var dense: Array[Vector2] = []
    var ctrl := _road_ctrl()
    var n := ctrl.size()
    for i in n:
        var p0: Vector2 = ctrl[(i - 1 + n) % n]
        var p1: Vector2 = ctrl[i]
        var p2: Vector2 = ctrl[(i + 1) % n]
        var p3: Vector2 = ctrl[(i + 2) % n]
        var steps := int(p1.distance_to(p2) / 0.5) + 1
        for k in steps:
            var t := float(k) / steps
            var t2 := t * t
            var t3 := t2 * t
            dense.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
                + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
    # Wind the road: a gentle sideways weave of a few metres (two slow waves), so it bends with the
    # rock and the shore like the concept art. Kept straight through the harbour, where the bay and
    # the boathouses sit right beside it.
    var total := 0.0
    for k in dense.size():
        total += dense[k].distance_to(dense[(k + 1) % dense.size()])
    # Whole waves per lap, so the weave meets itself at the start without a kink.
    var wave1 := total / roundf(total / 170.0)
    var wave2 := total / roundf(total / 110.0)
    var along := 0.0
    var woven: Array[Vector2] = []
    for k in dense.size():
        if k > 0:
            along += dense[k].distance_to(dense[k - 1])
        var d: Vector2 = (dense[(k + 1) % dense.size()] - dense[(k - 1 + dense.size()) % dense.size()]).normalized()
        var normal := Vector2(-d.y, d.x)
        var calm := _weave_calm(dense[k])
        var weave := (7.0 * sin(along * TAU / wave1) + 3.0 * sin(along * TAU / wave2 + 1.3)) * calm
        woven.append(dense[k] + normal * weave * (0.0 if diorama else 1.0))
    dense = woven
    var flat: Array[Vector2] = [dense[0]]
    var carry := 0.0
    for k in range(1, dense.size() + 1):
        var a: Vector2 = dense[k - 1]
        var b: Vector2 = dense[k % dense.size()]
        var seg := a.distance_to(b)
        var pos := 0.0
        while carry + seg - pos >= STEP:
            pos += STEP - carry
            carry = 0.0
            flat.append(a.lerp(b, pos / seg))
        carry += seg - pos
    flat.pop_back()
    var count := flat.size()
    length = count * STEP

    # Heights: smoothed natural ground on land; bridges span the water between their abutments.
    var raw := PackedFloat32Array()
    road_bridge.resize(count)
    for i in count:
        var h := natural(flat[i].x, flat[i].y)
        raw.append(maxf(h, 1.6))
        road_bridge[i] = 1 if h < 0.3 else 0
    _drop_short_runs(count, 12)        # only real water crossings (>= 24 m) become bridges
    var grown := road_bridge.duplicate()
    for i in count:
        if road_bridge[i] == 1:
            for k in range(-5, 6):
                grown[(i + k + count) % count] = 1
    road_bridge = grown
    var y := _smooth(raw, 18)
    var i0 := 0
    while i0 < count:
        if road_bridge[i0] == 1 and road_bridge[(i0 - 1 + count) % count] == 0:
            var i1 := i0
            while road_bridge[i1 % count] == 1:
                i1 += 1
            var a := y[(i0 - 1 + count) % count]
            var b := y[i1 % count]
            for k in range(i0, i1):
                var t := float(k - i0 + 1) / (i1 - i0 + 1)
                y[k % count] = maxf(lerpf(a, b, t) + sin(t * PI) * 1.5, 3.5)
            i0 = i1
        else:
            i0 += 1
    y = _limit_grade(_smooth(y, 6), MAX_GRADE)
    y = _smooth(y, 4)

    road_pos.resize(count)
    road_dir.resize(count)
    road_grade.resize(count)
    for i in count:
        road_pos[i] = Vector3(flat[i].x, y[i], flat[i].y)
    for i in count:
        var a := road_pos[(i - 1 + count) % count]
        var b := road_pos[(i + 1) % count]
        road_dir[i] = (b - a).normalized()
        road_grade[i] = clampf((b.y - a.y) / (2.0 * STEP) * 100.0, -12.0, 12.0)
    for i in range(0, count):
        var key := Vector2i(floori(road_pos[i].x / 20.0), floori(road_pos[i].z / 20.0))
        if not _road_hash.has(key):
            _road_hash[key] = PackedInt32Array()
        _road_hash[key].append(i)


## Clear water runs shorter than `min_len` samples (a dip near the shore becomes an embankment).
func _drop_short_runs(count: int, min_len: int) -> void:
    var i := 0
    while i < count:
        if road_bridge[i] == 1:
            var j := i
            while j < i + count and road_bridge[j % count] == 1:
                j += 1
            if j - i < min_len:
                for k in range(i, j):
                    road_bridge[k % count] = 0
            i = j
        else:
            i += 1


## Keep every step within the max grade by lowering peaks (the road then cuts into the rock)
## and raising dips (embankments). Forward and backward passes around the loop.
func _limit_grade(values: PackedFloat32Array, max_pct: float) -> PackedFloat32Array:
    var n := values.size()
    var out := values.duplicate()
    var rise := max_pct / 100.0 * STEP
    for rounds in 3:
        for i in range(1, n + 1):
            var prev := out[(i - 1) % n]
            out[i % n] = clampf(out[i % n], prev - rise, prev + rise)
        for i in range(n - 2, -2, -1):
            var nxt := out[(i + 1 + n) % n]
            out[(i + n) % n] = clampf(out[(i + n) % n], nxt - rise, nxt + rise)
    return out


func _smooth(values: PackedFloat32Array, half: int) -> PackedFloat32Array:
    var n := values.size()
    var out := PackedFloat32Array()
    out.resize(n)
    var total := 0.0
    for k in range(-half, half + 1):
        total += values[(k + n) % n]
    for i in n:
        out[i] = total / (2 * half + 1)
        total += values[(i + half + 1) % n] - values[(i - half + n) % n]
    return out


func _build_road_mesh() -> void:
    var count := road_pos.size()
    var verts := PackedVector3Array()
    var colors := PackedColorArray()
    var uvs := PackedVector2Array()
    var deck := PackedVector3Array()
    var deck_colors := PackedColorArray()
    var deck_uvs := PackedVector2Array()
    var beams := PackedVector3Array()
    var beam_colors := PackedColorArray()
    # Cross-section offsets (across, down) and colour per strip, left to right.
    var w := _rw
    var land := [[-3.3 * w, -1.6], [-2.55 * w, -0.1], [-ROAD_HALF * w, 0.0], [ROAD_HALF * w, 0.0], [2.55 * w, -0.1], [3.3 * w, -1.6]]
    var land_cols := [COL["kant"], COL["kant"], COL["asfalt"], COL["kant"], COL["kant"]]
    for i in count:
        var j := (i + 1) % count
        var bridge := road_bridge[i] == 1 or road_bridge[j] == 1
        var ra := _right(i)
        var rb := _right(j)
        var v0 := i * STEP
        if bridge:
            # A wooden bridge like the concept art: a plank deck on edge beams, chunky square posts,
            # a broad handrail and a middle rail.
            _strip(deck, deck_colors, road_pos[i], road_pos[j], ra, rb, -2.5 * w, 2.5 * w, 0.02, 0.02, COL["planka"],
                deck_uvs, v0)
            for side in [-1.0, 1.0]:
                var c: float = side * 2.62 * w
                _beam(beams, beam_colors, i, j, c, 1.0, 1.15, 0.24, COL["racke"])
                _beam(beams, beam_colors, i, j, c, 0.5, 0.6, 0.12, COL["racke"])
                _beam(beams, beam_colors, i, j, side * 2.55 * w, -0.4, 0.04, 0.3, COL["balk"])
            continue
        for k in land_cols.size():
            _strip(verts, colors, road_pos[i], road_pos[j], ra, rb, land[k][0], land[k + 1][0], land[k][1], land[k + 1][1],
                land_cols[k], uvs, v0)
        for side in [-1.9 * w, 1.9 * w]:
            _strip(verts, colors, road_pos[i], road_pos[j], ra, rb, side - 0.07 * w, side + 0.07 * w, 0.015, 0.015, COL["linje"],
                uvs, v0)
    add_child(_road_surface(verts, colors, uvs, false))
    add_child(_road_surface(deck, deck_colors, deck_uvs, true))
    add_child(_mesh(beams, beam_colors, 0.85))
    _bridge_posts()


func _right(i: int) -> Vector3:
    var d := road_dir[i]
    return Vector3(d.x, 0, d.z).normalized().cross(Vector3.UP).normalized()


## One quad strip between two road samples, from offset a to b across the road, with UVs of
## (metres across, metres along) for the road shader.
func _strip(verts: PackedVector3Array, colors: PackedColorArray, pa: Vector3, pb: Vector3, ra: Vector3, rb: Vector3,
        a: float, b: float, da: float, db: float, col: Color, uvs: PackedVector2Array, v0: float) -> void:
    var p1 := pa + ra * a + Vector3.UP * da
    var p2 := pa + ra * b + Vector3.UP * db
    var p3 := pb + rb * b + Vector3.UP * db
    var p4 := pb + rb * a + Vector3.UP * da
    verts.append_array([p1, p3, p2, p1, p4, p3])
    for k in 6:
        colors.append(col)
    var v1 := v0 + STEP
    uvs.append_array([Vector2(a, v0), Vector2(b, v1), Vector2(b, v0), Vector2(a, v0), Vector2(a, v1), Vector2(b, v1)])


## A square beam between road samples i and j: centred `c` metres right of the road, from height
## y0 to y1, `width` across. Four faces, each wound to face outwards.
func _beam(verts: PackedVector3Array, colors: PackedColorArray, i: int, j: int, c: float, y0: float, y1: float,
        width: float, col: Color) -> void:
    var ri := _right(i)
    var rj := _right(j)
    var hw := width * 0.5
    var li := road_pos[i] + ri * (c - hw)
    var rri := road_pos[i] + ri * (c + hw)
    var lj := road_pos[j] + rj * (c - hw)
    var rrj := road_pos[j] + rj * (c + hw)
    var lo := Vector3.UP * y0
    var hi := Vector3.UP * y1
    for q in [[li + hi, rri + hi, rrj + hi, lj + hi], [rri + lo, li + lo, lj + lo, rrj + lo],
            [rri + lo, rrj + lo, rrj + hi, rri + hi], [lj + lo, li + lo, li + hi, lj + hi]]:
        # Corners (bottom-left, bottom-right, top-right, top-left) as seen from outside.
        verts.append_array([q[0], q[2], q[1], q[0], q[3], q[2]])
        for k in 6:
            colors.append(col)


func _road_surface(verts: PackedVector3Array, colors: PackedColorArray, uvs: PackedVector2Array, wood: bool) -> MeshInstance3D:
    var mi := _mesh(verts, colors, 0.9)
    var arrays := mi.mesh.surface_get_arrays(0)
    arrays[Mesh.ARRAY_TEX_UV] = uvs
    var mesh := ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    var mat := ShaderMaterial.new()
    mat.shader = ROAD_SHADER
    mat.set_shader_parameter("planks", wood)
    mesh.surface_set_material(0, mat)
    mi.mesh = mesh
    return mi


func _bridge_posts() -> void:
    var posts := []
    var pillars := []
    var cross := []
    var count := road_pos.size()
    for i in count:
        if road_bridge[i] == 0:
            continue
        var r := _right(i)
        var yaw := atan2(-road_dir[i].z, road_dir[i].x)
        for side in [-2.62 * _rw, 2.62 * _rw]:
            posts.append(Transform3D(Basis(Vector3.UP, yaw), road_pos[i] + r * side + Vector3.UP * 0.6))
        if i % 6 == 0:
            for side in [-1.9 * _rw, 1.9 * _rw]:
                var top: Vector3 = road_pos[i] + r * side
                pillars.append(Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(1, (top.y + 6.0) / 2.0, 1)),
                    top + Vector3.DOWN * (top.y + 6.0) / 2.0))
            cross.append(Transform3D(Basis(Vector3.UP, yaw), road_pos[i] + Vector3.DOWN * 0.55))
    var wood := COL["racke"]
    add_child(_multimesh(_box_mesh(Vector3(0.22, 1.2, 0.22), wood.darkened(0.08)), posts))
    add_child(_multimesh(_box_mesh(Vector3(0.4, 2.0, 0.4), COL["balk"]), pillars))
    add_child(_multimesh(_box_mesh(Vector3(0.3, 0.3, 5.6 * _rw), COL["balk"]), cross))


# --- Terrain mesh -----------------------------------------------------------------------------

func _build_terrain() -> void:
    # The core in 60 m tiles: a fine 3 m grid where the road passes (so the rounded rock reads),
    # 6 m within sight of it, 12 m beyond; the 6 and 12 m tiles are merged into one mesh. A coarse
    # 30 m grid covers the far islands outside the core.
    _plan_tiles()
    var nx := ceili(CORE.size.x / TILE)
    var nz := ceili(CORE.size.y / TILE)
    var cverts := PackedVector3Array()
    var ccolors := PackedColorArray()
    for tz in nz:
        for tx in nx:
            var key := Vector2i(tx, tz)
            var rect := Rect2(CORE.position + Vector2(tx, tz) * TILE, Vector2(TILE, TILE))
            var cell: float = _tile_cell.get(key, 12.0)
            if cell < 6.0:
                var verts := PackedVector3Array()
                var colors := PackedColorArray()
                _terrain_tile(rect, cell, verts, colors, key)
                if not verts.is_empty():
                    add_child(_mesh(verts, colors, 0.92, true))
            else:
                _terrain_tile(rect, cell, cverts, ccolors, key)
    add_child(_mesh(cverts, ccolors, 0.92, true))
    add_child(_terrain_grid(Rect2(-2700, -2500, 5600, 5000), 30.0, false, CORE))


## The detailed core of the map: 60 m terrain tiles, scattered plants and free riding (less a
## margin). Set from _core() when the world is built, so each world sizes its own.
var CORE := Rect2(-820, -640, 1920, 1380)
const TILE := 60.0
var _tile_cell := {}     # tile → grid size in metres: 3 by the road, 6 within sight, 12 beyond


## Choose each tile's grid from its distance to the road (marked outwards from the road samples).
func _plan_tiles() -> void:
    # Places off the road that get the fine grid too (the base yard and its knoll).
    for area in _fine_areas():
        var c: Vector2 = area[0]
        var r: float = area[1]
        for tz in range(floori((c.y - r - CORE.position.y) / TILE), floori((c.y + r - CORE.position.y) / TILE) + 1):
            for tx in range(floori((c.x - r - CORE.position.x) / TILE), floori((c.x + r - CORE.position.x) / TILE) + 1):
                _tile_cell[Vector2i(tx, tz)] = 3.0
    for i in range(0, road_pos.size(), 3):
        var p := Vector2(road_pos[i].x, road_pos[i].z)
        for spec in [[200.0, 6.0], [22.0, 3.0]]:
            var reach: float = spec[0]
            var t0 := Vector2i(floori((p.x - reach - CORE.position.x) / TILE), floori((p.y - reach - CORE.position.y) / TILE))
            var t1 := Vector2i(floori((p.x + reach - CORE.position.x) / TILE), floori((p.y + reach - CORE.position.y) / TILE))
            for tz in range(t0.y, t1.y + 1):
                for tx in range(t0.x, t1.x + 1):
                    var key := Vector2i(tx, tz)
                    var rect := Rect2(CORE.position + Vector2(tx, tz) * TILE, Vector2(TILE, TILE))
                    if rect.grow(reach).has_point(p):
                        _tile_cell[key] = minf(_tile_cell.get(key, 12.0), spec[1])


func _cell_at(x: float, z: float) -> float:
    var key := Vector2i(floori((x - CORE.position.x) / TILE), floori((z - CORE.position.y) / TILE))
    return _tile_cell.get(key, 12.0)


## One 60 m tile of ground. Where a tile meets a coarser one, the in-between edge vertices are set
## on the coarser tile's straight edge so the two meet without cracks.
func _terrain_tile(rect: Rect2, cell: float, verts: PackedVector3Array, colors: PackedColorArray, key: Vector2i) -> void:
    var n := int(TILE / cell)
    var h := PackedFloat32Array()
    var near := PackedFloat32Array()
    var gthr := PackedFloat32Array()
    h.resize((n + 1) * (n + 1))
    near.resize((n + 1) * (n + 1))
    gthr.resize((n + 1) * (n + 1))
    for iz in n + 1:
        for ix in n + 1:
            var x := rect.position.x + ix * cell
            var z := rect.position.y + iz * cell
            var k := iz * (n + 1) + ix
            var nr := _nearest_road(x, z)
            h[k] = _height_near(x, z, nr)
            near[k] = nr[0]
            gthr[k] = float(_zone_rock(zone_at(nr[1] * STEP))[1]) if nr[0] < 40.0 else 0.0
    # Stitch each side to a coarser neighbour: [neighbour offset, first vertex index, step along].
    for side in [[Vector2i(0, -1), 0, 1], [Vector2i(0, 1), n * (n + 1), 1], [Vector2i(-1, 0), 0, n + 1], [Vector2i(1, 0), n, n + 1]]:
        var other: float = _tile_cell.get(key + (side[0] as Vector2i), 12.0)
        var ratio := int(roundf(other / cell))
        if ratio <= 1:
            continue
        var first: int = side[1]
        var stride: int = side[2]
        for i in n + 1:
            var r := i % ratio
            if r == 0:
                continue
            var a := first + (i - r) * stride
            var b := first + mini(i - r + ratio, n) * stride
            h[first + i * stride] = lerpf(h[a], h[b], float(r) / ratio)
    for iz in n:
        for ix in n:
            var x0 := rect.position.x + ix * cell
            var z0 := rect.position.y + iz * cell
            var k00 := iz * (n + 1) + ix
            var k10 := k00 + 1
            var k01 := k00 + n + 1
            var k11 := k01 + 1
            if maxf(maxf(h[k00], h[k10]), maxf(h[k01], h[k11])) < -7.5:
                continue
            var p00 := Vector3(x0, h[k00], z0)
            var p10 := Vector3(x0 + cell, h[k10], z0)
            var p01 := Vector3(x0, h[k01], z0 + cell)
            var p11 := Vector3(x0 + cell, h[k11], z0 + cell)
            var road_d := minf(minf(near[k00], near[k10]), minf(near[k01], near[k11]))
            var g := (gthr[k00] + gthr[k10] + gthr[k01] + gthr[k11]) * 0.25
            _tri(verts, colors, p00, p11, p10, road_d, g)
            _tri(verts, colors, p00, p01, p11, road_d, g)


func _terrain_grid(area: Rect2, cell: float, with_road: bool, hole: Rect2) -> MeshInstance3D:
    var nx := int(area.size.x / cell)
    var nz := int(area.size.y / cell)
    var h := PackedFloat32Array()
    var near := PackedFloat32Array()
    h.resize((nx + 1) * (nz + 1))
    near.resize((nx + 1) * (nz + 1))
    for iz in nz + 1:
        for ix in nx + 1:
            var x := area.position.x + ix * cell
            var z := area.position.y + iz * cell
            var k := iz * (nx + 1) + ix
            if with_road:
                h[k] = height(x, z)
                near[k] = _nearest_road(x, z)[0]
            else:
                h[k] = natural(x, z)
                near[k] = 1e9
    var verts := PackedVector3Array()
    var colors := PackedColorArray()
    for iz in nz:
        for ix in nx:
            var x0 := area.position.x + ix * cell
            var z0 := area.position.y + iz * cell
            if hole.size.x > 0 and hole.has_point(Vector2(x0 + cell * 0.5, z0 + cell * 0.5)):
                continue
            var k00 := iz * (nx + 1) + ix
            var k10 := k00 + 1
            var k01 := k00 + nx + 1
            var k11 := k01 + 1
            if maxf(maxf(h[k00], h[k10]), maxf(h[k01], h[k11])) < -7.5:
                continue
            var p00 := Vector3(x0, h[k00], z0)
            var p10 := Vector3(x0 + cell, h[k10], z0)
            var p01 := Vector3(x0, h[k01], z0 + cell)
            var p11 := Vector3(x0 + cell, h[k11], z0 + cell)
            var road_d := minf(minf(near[k00], near[k10]), minf(near[k01], near[k11]))
            _tri(verts, colors, p00, p11, p10, road_d)
            _tri(verts, colors, p00, p01, p11, road_d)
    return _mesh(verts, colors, 0.92, true)


## a→b→c counter-clockwise seen from above; emitted clockwise, which is Godot's front face.
## Granite is the rule: bare rock on the rounded humps, on slopes and by the road; grass and heath
## only in the hollows between, more of it in the meadow and the forest (`gthr` per zone).
func _tri(verts: PackedVector3Array, colors: PackedColorArray, a: Vector3, b: Vector3, c: Vector3, road_d: float, gthr := -0.25) -> void:
    verts.append_array([a, c, b])
    var n := (b - a).cross(c - a).normalized()
    var centre := (a + b + c) / 3.0
    var y := centre.y
    var col: Color
    if y < -1.2:
        col = COL["sand"].lerp(COL["botten"], clampf((-y - 1.2) / 5.0, 0.0, 1.0))
    elif y < 0.5:
        col = COL["strand"]
    else:
        var veg := _noise.get_noise_2d(centre.x * 1.1 + 500.0, centre.z * 1.1)
        var steep := n.y < 0.84
        var hump := 0.0 if diorama else _rundhall(centre.x, centre.z)
        var verge := road_d < 5.5 and veg < gthr + 0.3
        var knoll := not diorama and Vector2(centre.x, centre.z).distance_to(KNOLL) < 62.0
        if steep or veg < gthr or y < 1.4 or hump > 0.45 or verge or knoll:
            col = COL["granit"]
            var v := _noise.get_noise_2d(centre.x * 9.0, centre.z * 9.0)
            if v > 0.25:
                col = COL["granit_ljus"]
            elif v < -0.3:
                col = COL["granit_mork"]
        else:
            col = COL["gras"].lerp(COL["mossa"], clampf(0.5 - veg, 0.0, 1.0))
    var jitter := fposmod(sin(centre.x * 12.9898 + centre.z * 78.233) * 43758.5453, 1.0)
    col = col.lightened(jitter * 0.03) if jitter > 0.5 else col.darkened(jitter * 0.03)
    for k in 3:
        colors.append(col)


## Rounded rock humps (rundhällar) ground smooth by the ice: soft domes up to a couple of metres,
## stretched north-south. Zero in the hollows between, where soil and grass gather.
func _rundhall(x: float, z: float) -> float:
    var nv := _rund.get_noise_2d(x * 1.5, z)
    return pow(maxf(nv, 0.0), 0.8) * 4.2


func _mesh(verts: PackedVector3Array, colors: PackedColorArray, roughness: float, detail := false) -> MeshInstance3D:
    var normals := PackedVector3Array()
    normals.resize(verts.size())
    for t in range(0, verts.size(), 3):
        # Triangles are clockwise towards the viewer (Godot's front face), so this points outwards.
        var n := (verts[t + 2] - verts[t]).cross(verts[t + 1] - verts[t]).normalized()
        normals[t] = n
        normals[t + 1] = n
        normals[t + 2] = n
    var arrays := []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = verts
    arrays[Mesh.ARRAY_NORMAL] = normals
    arrays[Mesh.ARRAY_COLOR] = colors
    var mesh := ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    if detail:
        var ground := ShaderMaterial.new()
        ground.shader = _ground_shader()
        mesh.surface_set_material(0, ground)
    else:
        var mat := StandardMaterial3D.new()
        mat.vertex_color_use_as_albedo = true
        mat.vertex_color_is_srgb = true
        mat.roughness = roughness
        mat.cull_mode = BaseMaterial3D.CULL_DISABLED
        mesh.surface_set_material(0, mat)
    var mi := MeshInstance3D.new()
    mi.mesh = mesh
    return mi


# --- Water, sky, light ------------------------------------------------------------------------

func _build_water() -> void:
    var plane := PlaneMesh.new()
    plane.size = Vector2(7000, 7000)
    plane.subdivide_width = 260
    plane.subdivide_depth = 260
    var mat := ShaderMaterial.new()
    mat.shader = load("res://world/water.gdshader")
    plane.material = mat
    var water := MeshInstance3D.new()
    water.mesh = plane
    water.position = Vector3(100, 0, 0)
    water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(water)


func _build_environment() -> void:
    # Sunset like the concept art: a custom sky (lavender overhead, gold towards the low sun), a
    # strong golden sun with long soft shadows, warm haze that glows towards the sun, and a little
    # extra saturation and contrast.
    var sky_mat := ShaderMaterial.new()
    sky_mat.shader = SKY_SHADER
    var sky := Sky.new()
    sky.sky_material = sky_mat
    sky.radiance_size = Sky.RADIANCE_SIZE_256
    var env := Environment.new()
    env.background_mode = Environment.BG_SKY
    env.sky = sky
    env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
    env.ambient_light_energy = 0.75
    env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
    env.tonemap_mode = Environment.TONE_MAPPER_ACES
    env.tonemap_exposure = 0.95
    env.tonemap_white = 6.0
    env.ssao_enabled = true
    env.ssao_radius = 1.6
    env.ssao_intensity = 1.8
    env.ssao_power = 1.4
    env.glow_enabled = true
    env.glow_intensity = 0.7
    env.glow_bloom = 0.06
    env.glow_hdr_threshold = 1.1
    env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
    env.fog_enabled = true
    env.fog_light_color = Color("e9a98f")
    env.fog_light_energy = 1.0
    env.fog_sun_scatter = 0.18
    env.fog_density = 0.00035
    env.fog_aerial_perspective = 0.55
    env.fog_sky_affect = 0.15
    env.adjustment_enabled = true
    env.adjustment_saturation = 1.14
    env.adjustment_contrast = 1.07
    env.adjustment_brightness = 1.02
    env.ssil_enabled = true
    env.ssil_intensity = 1.0
    env.ssil_radius = 6.0
    environment = env
    var world_env := WorldEnvironment.new()
    world_env.environment = env
    add_child(world_env)
    _build_clouds()
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-10.0, -52.0, 0.0)
    sun.light_color = Color("ffb062")
    sun.light_energy = 2.4
    sun.light_angular_distance = 0.8
    sun.shadow_enabled = true
    sun.shadow_blur = 1.2
    sun.directional_shadow_max_distance = 220.0
    sun.directional_shadow_split_1 = 0.06
    sun.directional_shadow_split_2 = 0.18
    sun.directional_shadow_split_3 = 0.45
    sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
    add_child(sun)


# --- Props and nature ---------------------------------------------------------------------------

## Models painted in TextureCraft (assets/texturer): where <name>_tex.glb exists it is used instead
## of the flat-coloured <name>.glb.
var _painted := {}


## Model folders searched in order (a world puts its own first); the painted model wins in each.
var models_dirs: Array = [MODELS, "res://world/egypten/models/"]


func _scene(name: String) -> Node3D:
    if not _painted.has(name):
        var found := MODELS + name + ".glb"
        for d in models_dirs:
            if ResourceLoader.exists(d + name + "_tex.glb"):
                found = d + name + "_tex.glb"
                break
            if ResourceLoader.exists(d + name + ".glb"):
                found = d + name + ".glb"
                break
        _painted[name] = found
    return load(_painted[name]).instantiate()


func _prop(name: String, pos: Vector3, yaw: float, scale := 1.0) -> Node3D:
    var node := _scene(name)
    node.position = pos
    node.rotation.y = yaw
    node.scale = Vector3.ONE * scale * _ps
    add_child(node)
    if not diorama:
        _block_prop(node, name)
    return node


func _ground(x: float, z: float) -> Vector3:
    return Vector3(x, height(x, z), z)


## The lowest ground under a building's footprint (centre and four corners), so it sits down into
## a rock hump rather than floating over a hollow.
func _ground_low(x: float, z: float, r := 3.0) -> Vector3:
    var y := height(x, z)
    for d in [Vector2(r, r), Vector2(-r, r), Vector2(r, -r), Vector2(-r, -r)]:
        y = minf(y, height(x + d.x, z + d.y))
    return Vector3(x, y, z)


## Walk from a road point along a direction until the ground drops below sea level.
func _shore_from(start: Vector3, dir: Vector3) -> Vector3:
    var p := start
    for k in 200:
        p += dir * 2.0
        if height(p.x, p.z) < 0.0:
            return p
    return p


func _place_props() -> void:
    var q := _ps
    _init_network()
    _place_harbour(q)
    if not diorama:
        _place_kyrkvagen()
        _place_base()
        _place_teleport_sk()
    _place_village(q)

    # Lighthouse at the top of Fyrberget, a little off the road towards the sea.
    var top_i := 0
    for i in road_pos.size():
        if road_pos[i].y > road_pos[top_i].y:
            top_i = i
    var out := _right(top_i)
    if (road_pos[top_i] + out * 10.0 - Vector3(600, 0, -120)).length() < (road_pos[top_i] - Vector3(600, 0, -120)).length():
        out = -out
    var fyr_pos := _ground(road_pos[top_i].x + out.x * 22.0, road_pos[top_i].z + out.z * 22.0)
    _prop("fyr", fyr_pos, 0.0, 1.3)
    _keep(Vector2(fyr_pos.x, fyr_pos.z), (12.0 if diorama else 30.0) * q)   # keep the lighthouse in sight

    # Lillön: a red cottage with a flag on the far side, and a boathouse at the first bridge.
    var lillo := sample(_nearest_s(Vector2(-500, 220)))
    var lr := _right(int(_nearest_s(Vector2(-500, 220)) / STEP))
    var cottage := _ground_low(lillo["pos"].x - lr.x * 16.0 * q, lillo["pos"].z - lr.z * 16.0 * q)
    _prop("rodstuga", cottage, atan2(lr.x, lr.z))
    _prop("flaggstang", _ground(cottage.x + 6.0 * q, cottage.z - 6.0 * q), 0.0)
    _keep(Vector2(cottage.x, cottage.z), 12.0 * q)
    # The harbour lighthouse on the granite knoll ahead of the start (the concept-art view).
    # Stand it on the highest rock near the knoll's centre, a little larger, with a bare top.
    var knoll := _ground(KNOLL.x, KNOLL.y)
    for t in 40:
        var kx := KNOLL.x + _rng.randf_range(-18.0, 18.0)
        var kz := KNOLL.y + _rng.randf_range(-18.0, 18.0)
        if height(kx, kz) > knoll.y:
            knoll = _ground(kx, kz)
    _prop("fyr", knoll - Vector3(0, 0.3, 0), 0.6, 1.0 if diorama else 1.35)
    _keep(Vector2(knoll.x, knoll.z), (10.0 if diorama else 22.0) * q)
    if not diorama:
        _place_skerries()
        _place_kyrkby()
        _place_strandgardar()
        _place_new_islands()
        _place_hage()
        _place_midsommar()
        _place_marina()
        _place_norrskar()
        _place_side_roads()
        _place_road_posts()
        _sommarliv = load("res://world/skargarden/sommarliv.gd").new(self)
        _sommarliv.place()
    if not _fence_tf.is_empty():
        add_child(_multimesh(_merged(_model_mesh("staket")), _fence_tf))
    if not _gravel_verts.is_empty():
        add_child(_mesh(_gravel_verts, _gravel_cols, 1.0))


## The road at the point nearest p: position, flat direction, right-hand side and distance s.
func _road_at(p: Vector2) -> Dictionary:
    var s := _nearest_s(p)
    var i := int(s / STEP) % road_pos.size()
    var flat := Vector3(road_dir[i].x, 0, road_dir[i].z).normalized()
    return {"s": s, "pos": road_pos[i], "dir": flat, "right": _right(i)}


## Distance from p to the nearest road sample anywhere on the lap (slow; only for placing a few things).
func _road_clearance(p: Vector2) -> float:
    var best := 1e9
    for i in range(0, road_pos.size(), 2):
        best = minf(best, p.distance_squared_to(Vector2(road_pos[i].x, road_pos[i].z)))
    return sqrt(best)


## A white church in its whitewashed churchyard with gravestones, a red bell tower, a gravel path
## from the road with a sign, and a few houses round about, one with an old car in the drive.
func _place_kyrkby() -> void:
    var at := _road_at(Vector2(230.0, -95.0))
    var road: Vector3 = at["pos"]
    var r: Vector3 = at["right"]
    var side := 1.0
    for sd in [1.0, -1.0]:
        var c: Vector3 = road + r * sd * 36.0
        if _road_clearance(Vector2(c.x, c.z)) > 30.0:
            side = sd
            break
    var c: Vector3 = road + r * side * 36.0
    var g := _ground_low(c.x, c.z, 6.0)
    _prop("kyrka", g - Vector3(0, 0.2, 0), 0.0)
    # Churchyard wall (4 m bays) round the church, with a gate towards the road.
    var half := Vector2(20.0, 13.0)
    var to_road := Vector2(road.x - c.x, road.z - c.z).normalized()
    var bays := []
    for k in range(-5, 5):
        for zs in [-1.0, 1.0]:
            bays.append([Vector2(c.x + (k + 0.5) * 4.0, c.z + zs * half.y), 0.0])
    for k in range(-3, 3):
        for xs in [-1.0, 1.0]:
            bays.append([Vector2(c.x + xs * half.x, c.z + (k + 0.5) * 4.0 + 1.0), PI / 2])
    var wall := []
    for b in bays:
        var p: Vector2 = b[0]
        if (p - Vector2(c.x, c.z)).normalized().dot(to_road) > 0.92:
            continue    # the gate
        wall.append(Transform3D(Basis(Vector3.UP, b[1]), Vector3(p.x, height(p.x, p.y) - 0.15, p.y)))
    add_child(_multimesh(_merged(_model_mesh("kyrkmur")), wall))
    for k in 6:
        var gx := c.x + _rng.randf_range(-15.0, 15.0)
        var gz := c.z + (_rng.randf_range(7.0, 11.0) * (1.0 if k % 2 else -1.0))
        _prop("gravstenar", _ground(gx, gz), _rng.randf_range(-0.1, 0.1))
    _keep(Vector2(c.x, c.z), 24.0)
    var bell := Vector2(c.x, c.z) - to_road * 28.0 + Vector2(-to_road.y, to_road.x) * 14.0
    _prop("klockstapel", _ground(bell.x, bell.y), 0.3)
    _keep(bell, 4.0)
    var gate := Vector3(c.x + to_road.x * half.y, 0, c.z + to_road.y * half.y)
    _gravel([road + r * side * 2.9, road + r * side * 14.0, gate], 2.6)
    var flat: Vector3 = at["dir"]
    var sp: Vector3 = road - flat * 10.0 + r * side * 4.3
    var sign := _prop("skylt_vag_h" if side > 0 else "skylt_vag_v", _ground(sp.x, sp.z), atan2(-flat.x, -flat.z))
    _sign_text(sign, "Kyrkan", Vector3(0.04 * side, 2.175, 0.035), Color("1d1f22"), 34)
    _keep(Vector2(sp.x, sp.z), 1.2)
    # Houses along the road on the other side, one with an old car in the drive.
    var houses := ["blastuga", "rodstuga", "gulstuga", "storgard", "gronstuga"]
    for k in houses.size():
        var hs: float = at["s"] + (k - 2) * 50.0 + 20.0
        var h_at := sample(hs)
        var hi := int(fposmod(hs, length) / STEP) % road_pos.size()
        var hr := _right(hi) * -side
        var hp: Vector3 = (h_at["pos"] as Vector3) + hr * 22.0
        if _road_clearance(Vector2(hp.x, hp.z)) < 16.0:
            continue
        var face := atan2(-hr.x, -hr.z)
        var hg := _ground_low(hp.x, hp.z)
        _prop(houses[k], hg, face)
        var along := Vector3(hr.z, 0, -hr.x)
        var box_pt: Vector3 = (h_at["pos"] as Vector3) + hr * 3.6 - along * 2.4
        _prop("brevlada", _ground(box_pt.x, box_pt.z), face)
        _gravel([(h_at["pos"] as Vector3) + hr * 2.9, (h_at["pos"] as Vector3) + hr * 10.0, hp - hr * 3.7], 2.4)
        _keep(Vector2(hp.x, hp.z), 13.0)
        _keep(Vector2(box_pt.x, box_pt.z), 0.8)
        var extra: Vector3 = hp + along * 7.0 + hr * 2.0
        if k == 2:
            _prop("gammal_bil", _ground(extra.x, extra.z) + Vector3(0, 0.02, 0), face + PI / 2 + 0.15)
        else:
            _prop("appeltrad_%d" % (1 + k % 2), _ground(extra.x, extra.z), _rng.randf() * TAU)
        _keep(Vector2(extra.x, extra.z), 3.0)
        if k == 0:
            var fp: Vector3 = hp - along * 7.0
            _prop("flaggstang", _ground(fp.x, fp.z), 0.0)


## The islands added for the 12 km lap (2026-11-08): a fishing hamlet on Norrholmen; on Storön the
## lookout tower on Storberget, the manor with its birch avenue and pasture, Storby village with its
## shop, the windmill on Kvarnbacken and a sauna on Storsjön; on Långön the bathing beach with its
## kiosk and huts, the farm and the lighthouse on Sydudden. Storövägen and Långövägen, two gravel
## roads, cross Storön and Långön and make shorter loops.
func _place_new_islands() -> void:
    # Norrholmen: boathouses, jetties and boats along the north shore, a cairn on the top.
    var s0 := _nearest_s(Vector2(250.0, -820.0))
    for k in 4:
        var i := int(fposmod(s0 + 30.0 + k * 42.0, length) / STEP) % road_pos.size()
        var sea := _sea_side(i)
        var p := road_pos[i]
        var shore := _shore_from(p, sea)
        if Vector2(shore.x - p.x, shore.z - p.z).length() > 70.0:
            continue
        var bp := shore - sea * 3.5
        _prop("sjobod", _ground(bp.x, bp.z) + Vector3(0, 0.2, 0), atan2(sea.z, -sea.x))
        _keep(Vector2(bp.x, bp.z), 7.0)
        if k % 2 == 0:
            _prop("brygga", Vector3(shore.x, 0.6, shore.z) + sea * 4.0, atan2(-sea.z, sea.x))
            _boat("eka" if k == 0 else "fiskebat", Vector3(shore.x, 0.15, shore.z) + sea * 9.0 + Vector3(sea.z, 0, -sea.x) * 3.0,
                atan2(-sea.z, sea.x) + 0.3)
    var top := _highest_near(Vector2(300.0, -700.0), 90.0)
    _prop("kummel", top, 0.0, 1.2)
    _keep(Vector2(top.x, top.z), 4.0)
    # Storön: the lookout tower beside the top of Storberget.
    var ti := int(fposmod(_nearest_s(Vector2(1510.0, 120.0)), length) / STEP) % road_pos.size()
    var up_side := -_sea_side(ti)
    var tw: Vector3 = road_pos[ti] + up_side * 24.0
    _prop("utkikstorn", _ground_low(tw.x, tw.z, 2.0), atan2(-up_side.z, up_side.x))
    _keep(Vector2(tw.x, tw.z), 5.0)
    # The manor on its fields, with a birch avenue down to the east road, a barn and red cows.
    var manor := Vector2(1690.0, 270.0)
    var ar := _road_at(Vector2(1880.0, 280.0))
    var ap: Vector3 = ar["pos"]
    var to_manor := Vector3(manor.x - ap.x, 0.0, manor.y - ap.z).normalized()
    var mg := _ground_low(manor.x, manor.y, 6.0)
    _prop("storgard", mg, atan2(to_manor.x, to_manor.z))
    _keep(manor, 16.0)
    var lane := Vector2(manor.x - ap.x, manor.y - ap.z).length()
    var across := Vector3(-to_manor.z, 0.0, to_manor.x)
    var k2 := 18.0
    while k2 < lane - 18.0:
        for side: float in [-1.0, 1.0]:
            var b: Vector3 = ap + to_manor * k2 + across * side * 5.5
            _prop("bjork_%d" % (1 + int(k2 / 18.0) % 2), _ground(b.x, b.z), _rng.randf() * TAU)
            _keep(Vector2(b.x, b.z), 2.0)
        k2 += 18.0
    var barn: Vector3 = mg + across * 34.0 - to_manor * 8.0
    _prop("lada", _ground_low(barn.x, barn.z, 6.0), atan2(across.x, across.z))
    _keep(Vector2(barn.x, barn.z), 12.0)
    var pasture: Vector3 = mg - across * 45.0 + to_manor * 10.0
    for c in 5:
        var cp: Vector3 = pasture + Vector3(_rng.randf_range(-18.0, 18.0), 0.0, _rng.randf_range(-14.0, 14.0))
        _prop(["ko_rod", "ko_svart", "ko_bete"][c % 3], _ground(cp.x, cp.z), _rng.randf() * TAU)
        _keep(Vector2(cp.x, cp.z), 2.5)
    # Storby along the south shore: houses on the land side and the village shop.
    var vs := _nearest_s(Vector2(1620.0, 560.0))
    var types := ["rodstuga", "gulstuga", "vitstuga", "blastuga", "storgard", "gronstuga"]
    for k3 in 6:
        var hs := vs + 40.0 + k3 * 50.0
        var hi := int(fposmod(hs, length) / STEP) % road_pos.size()
        var land := -_sea_side(hi)
        var hp: Vector3 = road_pos[hi] + land * 22.0
        if height(hp.x, hp.z) < 1.0 or _road_clearance(Vector2(hp.x, hp.z)) < 16.0 or not _free_spot(hp.x, hp.z, 6.0):
            continue
        var face := atan2(-land.x, -land.z)
        if k3 == 2:
            var shop := _prop("cafe", _ground_low(hp.x, hp.z), face)
            _sign_text(shop, "Lanthandel", Vector3(-1.0, 3.45, 2.62), Color("1f5aa6"), 46)
        else:
            _prop(types[k3], _ground_low(hp.x, hp.z), face)
        var along := Vector3(land.z, 0, -land.x)
        var bx: Vector3 = road_pos[hi] + land * 3.6 - along * 2.4
        _prop("brevlada", _ground(bx.x, bx.z), face)
        _gravel([road_pos[hi] + land * 2.9, road_pos[hi] + land * 10.0, hp - land * 3.7], 2.4)
        _keep(Vector2(hp.x, hp.z), 13.0)
        _keep(Vector2(bx.x, bx.z), 0.8)
    # The windmill on Kvarnbacken, on the rise above the way back to Kvarnholmen.
    var mill := _highest_near(Vector2(1230.0, 560.0), 60.0)
    _prop("vaderkvarn", mill - Vector3(0, 0.2, 0), 0.6)
    _keep(Vector2(mill.x, mill.z), 7.0)
    # The sauna on Storsjön's south shore, with a bathing jetty out into the lake.
    var lake := Vector2(LAKES[0][0], LAKES[0][1])
    var sauna := lake + Vector2(0.0, float(LAKES[0][3]) + 9.0)
    var to_lake := (lake - sauna).normalized()
    _prop("bastu", _ground_low(sauna.x, sauna.y, 2.0), atan2(to_lake.x, to_lake.y) + PI)
    _keep(sauna, 5.0)
    var jetty := lake + Vector2(6.0, float(LAKES[0][3]) - 3.0)
    _prop("badbrygga", Vector3(jetty.x, 0.5, jetty.y), atan2(-to_lake.y, to_lake.x))
    # Långön: the bathing beach on the south shore with its kiosk, huts and jetties.
    var bs := _nearest_s(Vector2(220.0, 905.0))
    for k4 in 5:
        var bi := int(fposmod(bs + 30.0 + k4 * 38.0, length) / STEP) % road_pos.size()
        var sea2 := _sea_side(bi)
        var bp2 := road_pos[bi]
        var shore2 := _shore_from(bp2, sea2)
        if Vector2(shore2.x - bp2.x, shore2.z - bp2.z).length() > 60.0:
            continue
        var spot: Vector3 = shore2 - sea2 * 6.0
        if k4 == 2:
            var kiosk := _prop("cafe", _ground_low(spot.x, spot.z), atan2(-sea2.x, -sea2.z) + PI)
            _sign_text(kiosk, "Kiosk", Vector3(-1.0, 3.45, 2.62), Color("c8402f"), 56)
            _keep(Vector2(spot.x, spot.z), 8.0)
            for t in 3:
                var tb := _dry(spot + sea2 * 1.0 + Vector3(sea2.z, 0, -sea2.x) * (6.0 + t * 3.2), spot - sea2 * 12.0)
                _prop("cafebord", _ground(tb.x, tb.z), _rng.randf() * TAU)
                _keep(Vector2(tb.x, tb.z), 1.8)
        elif k4 % 2 == 1:
            _prop("badbrygga", Vector3(shore2.x, 0.5, shore2.z) + sea2 * 3.0, atan2(-sea2.z, sea2.x))
        else:
            _prop("uthus", _ground(spot.x, spot.z), atan2(-sea2.x, -sea2.z) + PI)
            _keep(Vector2(spot.x, spot.z), 3.0)
    # The farm on the north shore: house, barn, outhouse and cows.
    var fs := _nearest_s(Vector2(-60.0, 690.0))
    var fi := int(fposmod(fs, length) / STEP) % road_pos.size()
    var inland := -_sea_side(fi)
    var farm: Vector3 = road_pos[fi] + inland * 28.0
    var ff := atan2(-inland.x, -inland.z)
    _prop("rodstuga", _ground_low(farm.x, farm.z), ff)
    _keep(Vector2(farm.x, farm.z), 12.0)
    var side4 := Vector3(inland.z, 0.0, -inland.x)
    var fbarn: Vector3 = farm + side4 * 26.0 + inland * 8.0
    _prop("lada", _ground_low(fbarn.x, fbarn.z, 6.0), ff)
    _keep(Vector2(fbarn.x, fbarn.z), 12.0)
    for c in 4:
        var cp2: Vector3 = farm - side4 * 30.0 + inland * 10.0 + Vector3(_rng.randf_range(-12.0, 12.0), 0.0, _rng.randf_range(-10.0, 10.0))
        _prop(["ko_rod", "ko_bete", "far_1", "far_2"][c], _ground(cp2.x, cp2.z), _rng.randf() * TAU)
        _keep(Vector2(cp2.x, cp2.z), 2.0)
    # The lighthouse on Sydudden, Långön's western tip.
    var light := _highest_near(Vector2(-370.0, 850.0), 60.0)
    if float(_nearest_road(light.x, light.z)[0]) > 18.0:
        _prop("fyr", light - Vector3(0, 0.3, 0), 0.0)
        _keep(Vector2(light.x, light.z), 10.0)
    # The gravel roads across the islands, signposted at both ends.
    _cross_road("Storövägen", Vector2(1210.0, 180.0), Vector2(1880.0, 280.0),
        [Vector2(1380.0, 260.0), Vector2(1540.0, 290.0), Vector2(1700.0, 300.0)], "Herrgården", "Storberget")
    _cross_road("Långövägen", Vector2(450.0, 710.0), Vector2(-260.0, 790.0),
        [Vector2(300.0, 790.0), Vector2(100.0, 805.0), Vector2(-100.0, 800.0)], "Sydudden", "Långöbron")


## A gravel road from the lap near `a` through `via` to the lap near `b`, with a sign at each end
## naming where it leads.
func _cross_road(name: String, a: Vector2, b: Vector2, via: Array, sign_a: String, sign_b: String) -> void:
    var ia := int(_nearest_s(a) / STEP) % road_pos.size()
    var ib := int(_nearest_s(b) / STEP) % road_pos.size()
    var pa := road_pos[ia]
    var pb := road_pos[ib]
    var first: Vector2 = via[0]
    var last: Vector2 = via[via.size() - 1]
    var ctrl: Array = [pa + Vector3(first.x - pa.x, 0, first.y - pa.z).normalized() * 2.9]
    for v in via:
        ctrl.append(Vector3(v.x, 0.0, v.y))
    ctrl.append(pb + Vector3(last.x - pb.x, 0, last.y - pb.z).normalized() * 2.9)
    _add_path(name, ia, _gravel(ctrl, 3.2), ib)
    for end in [[ia, sign_a, first], [ib, sign_b, last]]:
        var i: int = end[0]
        var toward: Vector2 = end[2]
        var flat := Vector3(road_dir[i].x, 0, road_dir[i].z).normalized()
        var rr := _right(i)
        var sp: Vector3 = road_pos[i] - flat * 10.0 + rr * 4.3
        var right_turn := Vector2(rr.x, rr.z).dot(Vector2(toward.x - sp.x, toward.y - sp.z)) > 0.0
        if not right_turn:
            sp = road_pos[i] - flat * 10.0 - rr * 4.3
        var sign := _prop("skylt_vag_h" if right_turn else "skylt_vag_v", _ground(sp.x, sp.z), atan2(-flat.x, -flat.z))
        _sign_text(sign, end[1], Vector3(0.04 * (1.0 if right_turn else -1.0), 2.175, 0.035), Color("1d1f22"), 34)
        _keep(Vector2(sp.x, sp.z), 1.2)


## Which way is the sea from road point i: the side whose ground 30 m out is lower.
func _sea_side(i: int) -> Vector3:
    var r := _right(i)
    var p := road_pos[i]
    return r if height(p.x + r.x * 30.0, p.z + r.z * 30.0) < height(p.x - r.x * 30.0, p.z - r.z * 30.0) else -r


## Walk p towards `toward` in 1 m steps (at most 25) until it stands on dry ground.
func _dry(p: Vector3, toward: Vector3) -> Vector3:
    var q := p
    for k in 25:
        if height(q.x, q.z) > 0.4:
            break
        q = q.move_toward(Vector3(toward.x, q.y, toward.z), 1.0)
    return q


## The highest ground within `radius` of `c` (sampled), for things that crown a rise.
func _highest_near(c: Vector2, radius: float) -> Vector3:
    var best := _ground(c.x, c.y)
    for t in 48:
        var a := t * 2.399963
        var r := radius * sqrt((t + 0.5) / 48.0)
        var p := _ground(c.x + cos(a) * r, c.y + sin(a) * r)
        if p.y > best.y and _free_spot(p.x, p.z, 4.0):
            best = p
    return best


## A row of summer houses along Strandängen, on whichever side of the road is dry land, each with a
## gravel drive, a mailbox and an apple tree.
func _place_strandgardar() -> void:
    var houses := ["gronstuga", "vitstuga", "blastuga"]
    for k in houses.size():
        var hs: float = _nearest_s(Vector2(529.0, 393.0)) + k * 60.0
        var h_at := sample(hs)
        var road: Vector3 = h_at["pos"]
        var hi := int(fposmod(hs, length) / STEP) % road_pos.size()
        for side in [1.0, -1.0]:
            var hr: Vector3 = _right(hi) * side
            var hp: Vector3 = road + hr * 22.0
            if height(hp.x, hp.z) < 1.5 or _road_clearance(Vector2(hp.x, hp.z)) < 16.0:
                continue
            var face := atan2(-hr.x, -hr.z)
            _prop(houses[k], _ground_low(hp.x, hp.z), face)
            var along := Vector3(hr.z, 0, -hr.x)
            var box_pt: Vector3 = road + hr * 3.6 - along * 2.4
            _prop("brevlada", _ground(box_pt.x, box_pt.z), face)
            _gravel([road + hr * 2.9, road + hr * 10.0, hp - hr * 3.7], 2.4)
            _keep(Vector2(hp.x, hp.z), 13.0)
            _keep(Vector2(box_pt.x, box_pt.z), 0.8)
            var tree: Vector3 = hp + along * 7.0 + hr * 2.0
            _prop("appeltrad_%d" % (1 + k % 2), _ground(tree.x, tree.z), _rng.randf() * TAU)
            _keep(Vector2(tree.x, tree.z), 3.0)
            break


## A pasture inside the bend of the inland road: a roundpole fence, red cows and black-and-white
## ones, a flock of sheep, a red barn by the fence and big thickets of hazel and dog rose.
func _place_hage() -> void:
    var centre := Vector2(132.0, 40.0)
    var rad := Vector2(46.0, 36.0)
    var fence := []
    var n := 90
    for k in n:
        var a0 := TAU * k / n
        var a1 := TAU * (k + 1) / n
        var p0 := centre + Vector2(cos(a0) * rad.x, sin(a0) * rad.y)
        var p1 := centre + Vector2(cos(a1) * rad.x, sin(a1) * rad.y)
        var mid := (p0 + p1) * 0.5
        var d := (p1 - p0)
        if _road_clearance(mid) < 8.0:
            continue
        fence.append(Transform3D(Basis(Vector3.UP, atan2(-d.y, d.x)).scaled(Vector3(d.length() / 3.0, 1.15, 1.15)),
            Vector3(mid.x, height(mid.x, mid.y), mid.y)))
        _keep(mid, 1.5)
    add_child(_multimesh(_merged(_model_mesh("gardsgard")), fence))
    _keep(centre, rad.y - 2.0)
    var animals := ["ko_rod", "ko_rod", "ko_bete", "ko_svart", "ko_bete", "ko_svart", "far_1", "far_2", "far_1", "far_2",
        "far_2", "far_1", "far_2", "far_1"]
    for k in animals.size():
        var a := _rng.randf() * TAU
        var rr := sqrt(_rng.randf()) * 0.75
        var p := centre + Vector2(cos(a) * rad.x * rr, sin(a) * rad.y * rr)
        if animals[k].begins_with("far"):
            p = centre + Vector2(18.0, -6.0) + Vector2(_rng.randf_range(-9, 9), _rng.randf_range(-7, 7))
        _prop(animals[k], _ground(p.x, p.y), _rng.randf() * TAU)
    for k in 3:
        var a := _rng.randf() * TAU
        var p := centre + Vector2(cos(a) * rad.x * 0.5, sin(a) * rad.y * 0.5)
        _prop("hassel_%d" % (1 + k % 2), _ground(p.x, p.y), _rng.randf() * TAU)
    var barn := centre + Vector2(rad.x + 12.0, 0.0)
    _prop("lada", _ground_low(barn.x, barn.y, 6.0), PI / 2)
    _keep(barn, 10.0)


## The maypole on the open meadow beside the road, with benches and summer flowers round it.
func _place_midsommar() -> void:
    var at := _road_at(Vector2(290.0, 110.0))
    var road: Vector3 = at["pos"]
    var r: Vector3 = at["right"]
    var to_flat := Vector2(290.0 - road.x, 110.0 - road.z)
    var side := 1.0 if Vector2(r.x, r.z).dot(to_flat) > 0.0 else -1.0
    var p: Vector3 = road + r * side * 24.0
    _prop("midsommarstang", _ground(p.x, p.z), atan2(-(at["dir"] as Vector3).z, (at["dir"] as Vector3).x))
    _keep(Vector2(p.x, p.z), 9.0)
    for k in 3:
        var a := TAU * k / 3.0 + 0.4
        var b: Vector3 = p + Vector3(cos(a), 0, sin(a)) * 8.0
        _prop("utemobler", _ground(b.x, b.z), a + PI / 2)


## Gästholmen's marina: two piers with mooring fingers full of boats (sails furled), a yellow café
## with tables and parasols on the shore, a boathouse with a pennant and a sign from the road.
func _place_marina() -> void:
    var at := _road_at(Vector2(872.0, 445.0))
    var road: Vector3 = at["pos"]
    var north := Vector3(0, 0, -1)
    var shore := _shore_from(road, north)
    var out := north
    var lateral := Vector3(-out.z, 0, out.x)      # along the shore
    var yaw := atan2(-out.z, out.x)               # the pier model runs along its +X
    var boats := ["segelbat_forto", "segelbat_bla", "segelbat_forto", "snipa", "segelbat_forto", "fiskebat",
        "segelbat_bla", "roddbat", "segelbat_forto", "eka", "segelbat_forto", "snipa"]
    var berth := 0
    for pier_off in [-10.0, 12.0]:
        var root: Vector3 = shore + lateral * pier_off - out * 1.5
        _prop("gastbrygga", Vector3(root.x, 0.55, root.z), yaw)
        _keep(Vector2(root.x, root.z) + Vector2(out.x, out.z) * 20.0, 22.0)
        for k in 5:
            for sd in [-1.0, 1.0]:
                berth += 1
                if berth % 5 == 0:
                    continue        # a few empty berths
                var name: String = boats[berth % boats.size()]
                var c: Vector3 = root + out * (9.0 + 6.0 * k) + lateral * sd * 4.9
                var bow: Vector3 = -lateral * float(sd)
                _boat(name, Vector3(c.x, 0.2, c.z), atan2(-bow.z, bow.x))
    var cafe_pt: Vector3 = shore - out * 9.0 + lateral * -26.0
    for k in 20:                        # move it in towards the road until all of it stands on land
        if _ground_low(cafe_pt.x, cafe_pt.z, 4.0).y > 0.3:
            break
        cafe_pt = cafe_pt.move_toward(Vector3(road.x, cafe_pt.y, road.z) + lateral * -26.0, 1.0)
    var cg := _ground_low(cafe_pt.x, cafe_pt.z, 4.0)
    var cafe := _prop("cafe", cg, atan2(out.x, out.z))
    _sign_text(cafe, "Café", Vector3(-1.0, 3.45, 2.62), Color("1f5aa6"), 56)
    _keep(Vector2(cafe_pt.x, cafe_pt.z), 9.0)
    for k in 4:
        var off: Vector3 = lateral * (7.0 + (k % 2) * 3.2) + out * ((k / 2) * 3.2 - 1.0)
        var t := _dry(cafe_pt + off, Vector3(road.x, cafe_pt.y, road.z) + off)
        _prop("cafebord", _ground(t.x, t.z), _rng.randf() * TAU)
        _keep(Vector2(t.x, t.z), 1.8)
    var bod: Vector3 = shore - out * 2.0 + lateral * 30.0
    _prop("sjobod", _ground_low(bod.x, bod.z) + Vector3(0, 0.2, 0), yaw)
    _keep(Vector2(bod.x, bod.z), 7.0)
    var pole: Vector3 = shore - out * 6.0 + lateral * 2.0
    _prop("vimpelstang", _ground(pole.x, pole.z), 0.0)
    _keep(Vector2(pole.x, pole.z), 1.5)
    var flat: Vector3 = at["dir"]
    var rr: Vector3 = at["right"]
    var sp: Vector3 = road - flat * 30.0 + rr * 4.3
    var to_marina := Vector2(shore.x - sp.x, shore.z - sp.z)
    var sign := _prop("skylt_vag_v" if Vector2(rr.x, rr.z).dot(to_marina) < 0.0 else "skylt_vag_h", _ground(sp.x, sp.z),
        atan2(-flat.x, -flat.z))
    _sign_text(sign, "Gästhamn", Vector3(0.0, 2.175, 0.035), Color("1d1f22"), 32)
    _keep(Vector2(sp.x, sp.z), 1.2)


## A fishing camp on Norrskär: boathouses and a jetty on the north shore, a net rack, a rowing
## boat, and a stone cairn and a wooden beacon on the bare rock.
func _place_norrskar() -> void:
    var at := _road_at(Vector2(-410.0, -478.0))
    var road: Vector3 = at["pos"]
    var north := Vector3(0, 0, -1)
    var shore := _shore_from(road, north)
    var lateral := Vector3(1, 0, 0)
    for k in 2:
        var g: Vector3 = shore - north * 3.0 + lateral * (k * 12.0 - 6.0)
        _prop("sjobod", _ground_low(g.x, g.z) + Vector3(0, 0.2, 0), atan2(-north.z, north.x))
        _keep(Vector2(g.x, g.z), 7.0)
    _prop("brygga", Vector3(shore.x + 12.0, 0.6, shore.z) + north * 4.0, atan2(-north.z, north.x))
    _boat("eka", Vector3(shore.x + 14.5, 0.12, shore.z) + north * 7.0, atan2(-north.z, north.x) + 0.2)
    var rack: Vector3 = shore - north * 9.0 + lateral * 4.0
    _prop("natstallning", _ground(rack.x, rack.z), 0.0)
    _keep(Vector2(rack.x, rack.z), 4.0)
    var best := Vector3(-395.0, height(-395.0, -385.0), -385.0)
    for t in 60:
        var x := _rng.randf_range(-540.0, -260.0)
        var z := _rng.randf_range(-470.0, -300.0)
        var y := height(x, z)
        if y > best.y and _road_clearance(Vector2(x, z)) > 18.0:
            best = Vector3(x, y, z)
    _prop("kummel", best, 0.0, 1.3)
    _keep(Vector2(best.x, best.z), 4.0)
    var tip := Vector3(-560.0, 0, -450.0)
    tip = _ground(tip.x, tip.z)
    if tip.y > 1.0:
        _prop("bak", tip - Vector3(0, 0.2, 0), 0.4)
        _keep(Vector2(tip.x, tip.z), 4.0)


## A boat or buoy that rocks on the water.
func _boat(name: String, pos: Vector3, yaw: float) -> Node3D:
    var b := _prop(name, pos, yaw)
    _bobbers.append([b, pos.y, _rng.randf() * TAU])
    return b


## Harbour: a bay right beside the road with a jetty full of boats, boathouses with life rings,
## a net rack, a pennant and a bathing jetty with a ladder a little further along the shore.
func _place_harbour(q: float) -> void:
    var hs := _nearest_s(HARBOUR)
    var start := sample(hs)
    var south := Vector3(0, 0, 1)
    var shore := _shore_from(start["pos"], south)
    var jetty := shore + south * 5.0 * q
    _prop("brygga", Vector3(jetty.x, 0.6 * q, jetty.z), PI / 2)
    _boat("fiskebat", Vector3(jetty.x + 3.4 * q, 0.25, jetty.z + 3.0 * q), PI / 2)
    for k in 2:
        _boat("roddbat", Vector3(jetty.x - 3.0 * q, 0.15, jetty.z + (1.0 + k * 3.5) * q), PI / 2 + 0.2 * k)
    _boat("snipa", Vector3(jetty.x + 3.1 * q, 0.2, jetty.z + 8.6 * q), PI / 2 - 0.08)
    _boat("eka", Vector3(jetty.x - 2.8 * q, 0.12, jetty.z + 8.8 * q), PI / 2 + 0.15)
    _prop("livbojsstall", Vector3(jetty.x + 0.85 * q, 0.64 * q, jetty.z - 3.5 * q), PI)
    for k in 5:
        _boat("boj", Vector3(jetty.x + _rng.randf_range(-30, 30) * q, 0.0, jetty.z + _rng.randf_range(14, 45) * q), 0.0)
    _prop("hamnprylar", _ground(shore.x + 6.0 * q, shore.z - 2.0 * q), 0.0)
    _keep(Vector2(shore.x, shore.z), 16.0 * q)
    for along in [-30.0, -15.0, 18.0]:
        var road_pt := sample(hs + along * q)
        var sh := _shore_from(road_pt["pos"], south)
        var g := _ground(sh.x, sh.z - 1.0 * q)
        _prop("sjobod", Vector3(g.x, maxf(g.y, 0.4), g.z), -PI / 2)
        _keep(Vector2(g.x, g.z), 8.0 * q)
    if diorama:
        return
    # Net rack and pennant between the boathouses, a green rowing boat drawn up on the shore.
    var mid := _shore_from(sample(hs + 3.0)["pos"], south) - south * 3.5
    _prop("natstallning", _ground(mid.x, mid.z), 0.15)
    _keep(Vector2(mid.x, mid.z), 4.0)
    var pole := _shore_from(sample(hs + 30.0)["pos"], south) - south * 5.0
    _prop("vimpelstang", _ground(pole.x, pole.z), 0.0)
    _keep(Vector2(pole.x, pole.z), 2.0)
    var drawn := _shore_from(sample(hs + 26.0)["pos"], south) + south * 1.5
    _boat("eka_gron", Vector3(drawn.x, 0.1, drawn.z + 1.0), PI / 2 + 0.5)
    # Bathing jetty with a steel ladder, east of the boathouses.
    var bath := _shore_from(sample(hs - 55.0)["pos"], south)
    _prop("badbrygga", Vector3(bath.x, 0.5, bath.z + 3.0), -PI / 2)
    _keep(Vector2(bath.x, bath.z), 5.0)


## The village: white, yellow, red, blue and green houses (one a two-storey farmhouse) on the land
## side, each with a gravel drive and a mailbox by the road, a picket fence, lilac, apple trees, a
## washing line and garden furniture, a woodpile or an outhouse, and a flag at the first.
func _place_village(q: float) -> void:
    var hs := _nearest_s(HARBOUR)
    var houses := ["vitstuga", "gulstuga", "storgard", "rodstuga", "blastuga", "gronstuga", "vitstuga"]
    var k2 := 0
    for s_off in [-215.0, -150.0, -85.0, 60.0, 125.0, 190.0, 255.0]:
        var s_at := fposmod(hs + s_off * q, length)
        var at := sample(s_at)
        var road: Vector3 = at["pos"]
        var rr := _right(int(s_at / STEP) % road_pos.size())
        var along := Vector3(rr.z, 0, -rr.x)
        var hp: Vector3 = road + rr * 24.0 * q
        if height(hp.x, hp.z) < 1.0 or _road_clearance(Vector2(hp.x, hp.z)) < 14.0 * q:
            continue
        var g2 := _ground_low(hp.x, hp.z)
        var face := atan2(-rr.x, -rr.z)
        var line := atan2(-along.z, along.x)
        _prop(houses[k2 % houses.size()], g2, face)
        var box_pt: Vector3 = road + rr * 3.6 * q - along * 2.4 * q
        _prop("brevlada", _ground(box_pt.x, box_pt.z), face)
        var side_pt: Vector3 = hp + rr * 8.0 * q + along * 6.0 * q
        _prop("vedtrave" if k2 % 2 == 0 else "uthus", _ground_low(side_pt.x, side_pt.z, 1.4), face)
        if k2 == 0:
            var fp: Vector3 = hp - along * 7.0 * q
            _prop("flaggstang", _ground(fp.x, fp.z), 0.0)
        _keep(Vector2(g2.x, g2.z), 14.0 * q)
        _keep(Vector2(side_pt.x, side_pt.z), 5.0 * q)
        _keep(Vector2(box_pt.x, box_pt.z), 0.8)
        k2 += 1
        if diorama:
            continue
        _gravel([road + rr * 2.9, road + rr * 11.0 + along * 0.4, hp - rr * 3.7], 2.4)
        for k in [-3, -2, -1, 1, 2, 3]:
            var c: Vector3 = road + rr * 7.6 + along * k * 3.0
            _fence_tf.append(Transform3D(Basis(Vector3.UP, line), Vector3(c.x, height(c.x, c.z) - 0.05, c.z)))
            _keep(Vector2(c.x, c.z), 1.6)
        var garden := [["syren", hp + along * 4.9 - rr * 0.6, _rng.randf() * TAU, 2.2],
            ["appeltrad_1", hp - along * 7.5 + rr * 5.0, _rng.randf() * TAU, 2.6],
            ["appeltrad_2", hp - along * 9.0 - rr * 4.0, _rng.randf() * TAU, 2.6],
            ["tvattlina", hp - along * 4.0 + rr * 9.5, line, 2.4],
            ["utemobler", hp - along * 4.0 - rr * 5.2, face, 1.4]]
        for item in garden:
            var p: Vector3 = item[1]
            _prop(item[0], _ground(p.x, p.z), item[2])
            _keep(Vector2(p.x, p.z), item[3])


## Lone buildings and sea marks on the skerries, turned towards the road.
func _place_skerries() -> void:
    var cottages := ["rodstuga", "gronstuga", "blastuga"]
    var n_cottage := 0
    for sk in SKERRIES:
        var what: String = sk[5]
        var c := Vector2(sk[0], sk[1])
        var best := Vector3(c.x, height(c.x, c.y), c.y)
        for t in 30:
            var x: float = c.x + _rng.randf_range(-0.35, 0.35) * sk[2]
            var z: float = c.y + _rng.randf_range(-0.35, 0.35) * sk[3]
            var y := height(x, z)
            if y > best.y:
                best = Vector3(x, y, z)
        var rp: Vector3 = sample(_nearest_s(c))["pos"]
        var to_road := Vector3(rp.x - best.x, 0, rp.z - best.z).normalized()
        var face := atan2(to_road.x, to_road.z)
        var along_yaw := atan2(-to_road.z, to_road.x)
        var sh := _shore_from(best, to_road)
        match what:
            "stuga":
                _prop(cottages[n_cottage % cottages.size()], best - Vector3(0, 0.25, 0), face)
                n_cottage += 1
                var vp: Vector3 = best + Vector3(to_road.z, 0, -to_road.x) * 7.0
                _prop("vimpelstang", _ground(vp.x, vp.z), 0.0)
                _prop("brygga", Vector3(sh.x, 0.6, sh.z) + to_road * 4.0, along_yaw)
                _boat("eka", Vector3(sh.x, 0.12, sh.z) + to_road * 7.0 + Vector3(to_road.z, 0, -to_road.x) * 2.0, along_yaw + 0.2)
                _keep(Vector2(best.x, best.z), 11.0)
                _keep(Vector2(vp.x, vp.z), 2.0)
            "sjobod":
                var bp := sh - to_road * 3.5
                _prop("sjobod", _ground(bp.x, bp.z) + Vector3(0, 0.2, 0), along_yaw)
                _boat("eka_gron", Vector3(sh.x, 0.12, sh.z) + to_road * 3.0, along_yaw + 1.3)
                _keep(Vector2(bp.x, bp.z), 7.0)
            "bak":
                _prop("bak", best - Vector3(0, 0.2, 0), _rng.randf() * TAU)
                _keep(Vector2(best.x, best.z), 4.0)
            "kummel":
                _prop("kummel", best, 0.0, 1.2)
                _keep(Vector2(best.x, best.z), 4.0)


## Gravel side roads off the lap with a local destination sign and a cycle route sign before the
## turn: one down to a bathing jetty on the shore, one up to a farm in the forest.
func _place_side_roads() -> void:
    for sr in SIDE_ROADS:
        var s0 := _nearest_s(sr[0])
        var turn: float = sr[1]
        var i0 := int(s0 / STEP) % road_pos.size()
        var p0 := road_pos[i0]
        var flat := Vector3(road_dir[i0].x, 0, road_dir[i0].z).normalized()
        var r := _right(i0) * turn
        var ctrl: Array = []
        var end: Vector3
        if turn < 0.0:
            # Down to the shore: stop where the water starts and build the jetty from there.
            var shore := _shore_from(p0, r)
            var dist := minf(p0.distance_to(shore), 140.0)
            end = p0 + r * (dist - 5.0) + flat * 3.0
            ctrl = [p0 + r * 2.9, p0 + r * dist * 0.35 + flat * 7.0, p0 + r * dist * 0.7 + flat * 6.0, end]
            var jetty := _shore_from(end, r)
            _prop("badbrygga", Vector3(jetty.x, 0.5, jetty.z) + r * 3.0, atan2(-r.z, r.x))
            _boat("eka_gron", Vector3(jetty.x, 0.12, jetty.z) + r * 5.0 + flat * 2.2, atan2(-r.z, r.x) + 0.3)
            var bod := end - flat * 7.0 + r * 1.0
            _prop("sjobod", _ground(bod.x, bod.z), atan2(-r.z, r.x))
            _keep(Vector2(bod.x, bod.z), 7.0)
            _keep(Vector2(jetty.x, jetty.z), 5.0)
        else:
            # Up to a farm: red house facing the drive, outhouse, woodpile, apple tree, washing line.
            end = p0 + r * 62.0 - flat * 6.0
            ctrl = [p0 + r * 2.9, p0 + r * 22.0 + flat * 6.0, p0 + r * 44.0 - flat * 2.0, end]
            var house := end + r * 10.0
            var face := atan2(-r.x, -r.z)
            var g := _ground_low(house.x, house.z)
            _prop("rodstuga", g, face)
            var side := Vector3(r.z, 0, -r.x)
            var extras := [["uthus", house + side * 9.0 + r * 4.0, face, 4.0], ["vedtrave", house - side * 6.5 + r * 2.0, face, 2.0],
                ["appeltrad_1", house + side * 8.0 - r * 7.0, 0.7, 2.6], ["tvattlina", house - side * 8.0 + r * 9.0, atan2(-side.z, side.x), 2.4],
                ["flaggstang", house - side * 6.0 - r * 6.0, 0.0, 1.0], ["syren", house + side * 4.8 - r * 1.5, 1.1, 2.2]]
            for e in extras:
                var p: Vector3 = e[1]
                _prop(e[0], _ground(p.x, p.z), e[2])
                _keep(Vector2(p.x, p.z), e[3])
            _keep(Vector2(house.x, house.z), 9.0)
        _add_path(sr[2], i0, _gravel(ctrl, 3.0))
        # Signs on the right-hand verge before the turn, facing the rider.
        var rr := _right(i0)
        var yaw := atan2(-flat.x, -flat.z)
        var sp := p0 - flat * 9.0 + rr * 4.3
        var sign := _prop("skylt_vag_v" if turn < 0.0 else "skylt_vag_h", _ground(sp.x, sp.z), yaw)
        _sign_text(sign, sr[2], Vector3(0.04 * turn, 2.175, 0.035), Color("1d1f22"), 34)
        var cp := p0 - flat * 14.0 + rr * 4.3
        var csign := _prop("skylt_cykel", _ground(cp.x, cp.z), yaw)
        _sign_text(csign, sr[3], Vector3(0.12, 1.85, 0.036), Color("c8282b"), 30)
        _keep(Vector2(sp.x, sp.z), 1.2)
        _keep(Vector2(cp.x, cp.z), 1.2)


func _sign_text(sign: Node3D, text: String, at: Vector3, col: Color, size: int) -> void:
    var label := Label3D.new()
    label.text = text
    label.font_size = size
    label.pixel_size = 0.0042
    label.outline_size = 0
    label.modulate = col
    label.double_sided = false
    label.position = at
    label.visibility_range_end = 120.0
    sign.add_child(label)


## Swedish roadside marker posts (kantstolpar) every 50 m on both sides, off the bridges.
func _place_road_posts() -> void:
    var tf := []
    var s := 25.0
    while s < length:
        var i := int(s / STEP) % road_pos.size()
        if road_bridge[i] == 0:
            var flat := Vector3(road_dir[i].x, 0, road_dir[i].z).normalized()
            for side in [-1.0, 1.0]:
                var p: Vector3 = road_pos[i] + _right(i) * float(side) * 3.5
                if _free_spot(p.x, p.z, 0.3):
                    tf.append(Transform3D(Basis(Vector3.UP, atan2(-flat.z, flat.x)), Vector3(p.x, height(p.x, p.z) - 0.1, p.z)))
                    _keep(Vector2(p.x, p.z), 0.6)
        s += 50.0
    var mmi := _multimesh(_merged(_model_mesh("kantstolpe")), tf)
    mmi.visibility_range_end = 400.0
    add_child(mmi)


var _fence_tf := []
var _gravel_verts := PackedVector3Array()
var _gravel_cols := PackedColorArray()


## A gravel road through the control points (open Catmull-Rom), draped on the terrain mesh, with a
## strip of grass down the middle and worn edges, like a Swedish byväg.
func _gravel(ctrl: Array, width: float) -> PackedVector3Array:
    var pts: Array[Vector2] = []
    var n := ctrl.size()
    for i in n - 1:
        var p0: Vector3 = ctrl[maxi(i - 1, 0)]
        var p1: Vector3 = ctrl[i]
        var p2: Vector3 = ctrl[i + 1]
        var p3: Vector3 = ctrl[mini(i + 2, n - 1)]
        var a0 := Vector2(p0.x, p0.z)
        var a1 := Vector2(p1.x, p1.z)
        var a2 := Vector2(p2.x, p2.z)
        var a3 := Vector2(p3.x, p3.z)
        var steps := maxi(int(a1.distance_to(a2) / 1.2), 1)
        for k in steps:
            var t := float(k) / steps
            var t2 := t * t
            var t3 := t2 * t
            pts.append(0.5 * ((2.0 * a1) + (-a0 + a2) * t + (2.0 * a0 - 5.0 * a1 + 4.0 * a2 - a3) * t2
                + (-a0 + 3.0 * a1 - 3.0 * a2 + a3) * t3))
    var last: Vector3 = ctrl[n - 1]
    pts.append(Vector2(last.x, last.z))
    var hw := width / 2.0
    var across := [-hw - 0.35, -hw, -0.22, 0.22, hw, hw + 0.35]
    var gc := _gravel_colours()
    var cols := [gc[0], gc[1], gc[2], gc[1], gc[0]]
    var prev: Array = []
    var centre := PackedVector3Array()
    for k in pts.size():
        var d: Vector2 = (pts[mini(k + 1, pts.size() - 1)] - pts[maxi(k - 1, 0)]).normalized()
        var right := Vector2(-d.y, d.x)
        var row: Array = []
        for a in across:
            var p: Vector2 = pts[k] + right * float(a)
            var lift := 0.05 if absf(a) > hw else 0.09
            row.append(Vector3(p.x, _mesh_height(p.x, p.y) + lift, p.y))
        centre.append(((row[2] as Vector3) + (row[3] as Vector3)) * 0.5)
        if k % 3 == 0:
            _keep(pts[k], hw + 1.2)
        if not prev.is_empty():
            for c in cols.size():
                var p1: Vector3 = prev[c]
                var p2: Vector3 = prev[c + 1]
                var p3: Vector3 = row[c + 1]
                var p4: Vector3 = row[c]
                _gravel_verts.append_array([p1, p3, p2, p1, p4, p3])
                var col: Color = cols[c]
                var j := fposmod(sin(p1.x * 12.9898 + p1.z * 78.233) * 43758.5453, 1.0)
                col = col.lightened(j * 0.05) if j > 0.5 else col.darkened(j * 0.05)
                for m in 6:
                    _gravel_cols.append(col)
        prev = row
    return centre



## A gravel track's colours across it: [verge, gravel, the crown between the wheel ruts].
func _gravel_colours() -> Array:
    return [COL["grus"].lerp(COL["gras"], 0.45), COL["grus"].lightened(0.06), COL["gras"].lerp(COL["grus"], 0.35)]

## Height of the drawn terrain (the 6 m triangle grid around the road), so things laid on the
## ground follow the facets instead of the smooth height function.
func _mesh_height(x: float, z: float) -> float:
    var cell := _cell_at(x, z)
    var gx := (x - CORE.position.x) / cell
    var gz := (z - CORE.position.y) / cell
    var ix := floori(gx)
    var iz := floori(gz)
    var u := gx - ix
    var v := gz - iz
    var x0 := CORE.position.x + ix * cell
    var z0 := CORE.position.y + iz * cell
    var h00 := height(x0, z0)
    var h11 := height(x0 + cell, z0 + cell)
    if u >= v:
        var h10 := height(x0 + cell, z0)
        return h00 + (h10 - h00) * u + (h11 - h10) * v
    var h01 := height(x0, z0 + cell)
    return h00 + (h01 - h00) * v + (h11 - h01) * u


## The same for the coarse 30 m grid of the far islands.
func _far_height(x: float, z: float) -> float:
    var gx := (x + 2700.0) / 30.0
    var gz := (z + 2500.0) / 30.0
    var ix := floori(gx)
    var iz := floori(gz)
    var u := gx - ix
    var v := gz - iz
    var x0 := -2700.0 + ix * 30.0
    var z0 := -2500.0 + iz * 30.0
    var h00 := natural(x0, z0)
    var h11 := natural(x0 + 30.0, z0 + 30.0)
    if u >= v:
        var h10 := natural(x0 + 30.0, z0)
        return h00 + (h10 - h00) * u + (h11 - h10) * v
    var h01 := natural(x0, z0 + 30.0)
    return h00 + (h01 - h00) * v + (h11 - h01) * u


var _keep_out: Array = []       # [Vector2, radius] where trees, stones and verge plants are not placed
var _keep_hash := {}            # the same entries bucketed in 16 m cells for quick lookups
const KEEP_CELL := 16.0


func _keep(c: Vector2, r: float) -> void:
    var e := [c, r]
    _keep_out.append(e)
    for i in range(floori((c.x - r) / KEEP_CELL), floori((c.x + r) / KEEP_CELL) + 1):
        for j in range(floori((c.y - r) / KEEP_CELL), floori((c.y + r) / KEEP_CELL) + 1):
            var key := Vector2i(i, j)
            if not _keep_hash.has(key):
                _keep_hash[key] = []
            _keep_hash[key].append(e)


func _nearest_s(p: Vector2) -> float:
    var best := 1e9
    var best_i := 0
    for i in road_pos.size():
        var d := Vector2(road_pos[i].x, road_pos[i].z).distance_squared_to(p)
        if d < best:
            best = d
            best_i = i
    return best_i * STEP


func _free_spot(x: float, z: float, clearance: float) -> bool:
    var p := Vector2(x, z)
    for i in range(floori((x - clearance) / KEEP_CELL), floori((x + clearance) / KEEP_CELL) + 1):
        for j in range(floori((z - clearance) / KEEP_CELL), floori((z + clearance) / KEEP_CELL) + 1):
            var cell = _keep_hash.get(Vector2i(i, j))
            if cell == null:
                continue
            for k in cell:
                if p.distance_to(k[0]) < k[1] + clearance:
                    return false
    return true


## The zone at distance s along the lap.
func zone_at(s: float) -> String:
    var t := fposmod(s, length)
    var name: String = ZONES[0][1]
    for entry in ZONES:
        if t >= entry[0]:
            name = entry[1]
    return name


func _put(kinds: Dictionary, kind: String, p: Vector3, sink := 0.05) -> void:
    var r: Array = _kind_scale(kind)
    var size := _rng.randf_range(r[0], r[1]) * (_ps * 0.6 if diorama else 1.0)
    var name := "%s_%d" % [kind, 1 + _rng.randi() % _variants(kind)]
    if not kinds.has(name):
        kinds[name] = []
    var y := p.y - (size * 0.3 if kind == "flyttblock" else sink)
    kinds[name].append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * size), Vector3(p.x, y, p.z)))


func _scatter_nature() -> void:
    var kinds := {}
    # 1. The verges, following the zone: granite slabs crowding the road, ground cover between the
    #    asphalt and the rock, small stones, moss and berry sprigs, and trees close to the road.
    if not diorama:
        for i in road_pos.size():
            if road_bridge[i] == 1:
                continue
            var style: Dictionary = ZONE_STYLE[zone_at(i * STEP)]
            var cover: Array = style["cover"]
            var fine: Array = style["fine"]
            var trees: Array = style["trees"]
            var shore: Array = style["shore"]
            var r := _right(i)
            for side in [-1.0, 1.0]:
                var sd: float = side
                # Keep the verge low and open where the water is close, so the view down to the
                # shore (the harbour, boats and jetty) stays clear.
                var far: Vector3 = road_pos[i] + r * sd * 18.0
                var open_water := height(far.x, far.z) < 0.5
                if open_water:
                    if _rng.randf() < 0.7:
                        var g: Vector3 = road_pos[i] + r * sd * _rng.randf_range(3.1, 6.0)
                        _put_free(kinds, "grastuva", g, 0.3)
                    for n in 2:
                        var g2: Vector3 = road_pos[i] + r * sd * _rng.randf_range(3.0, 8.0) + road_dir[i] * _rng.randf_range(-1.0, 1.0)
                        _put_free(kinds, fine[_rng.randi() % fine.size()], g2, 0.3)
                    # Low things only on the water side: heather, stones and flat slabs of rock,
                    # so the land down to the shore is granite and heath, not lawn.
                    for n in 2:
                        var g3: Vector3 = road_pos[i] + r * sd * _rng.randf_range(5.0, 16.0) + road_dir[i] * _rng.randf_range(-1.0, 1.0)
                        var low: Array = ["ljungtuva", "ljungtuva", "stenar", "grastuva", "strandkal", "blabarsris"]
                        if height(g3.x, g3.z) > 0.3:
                            _put_free(kinds, low[_rng.randi() % low.size()], g3, 0.4)
                    if i % 2 == 1 and _rng.randf() < 0.6:
                        var g4: Vector3 = road_pos[i] + r * sd * _rng.randf_range(6.5, 14.0)
                        if height(g4.x, g4.z) > 0.3:
                            _place_slab(kinds, g4, _rng.randf_range(1.2, 2.6), false, 0.55)
                    if i % 3 == 0:
                        # Granite blocks along the water's edge, like the concept art, and the
                        # plants of the shore just above them.
                        var edge := _shore_from(road_pos[i], r * sd)
                        if edge.distance_to(road_pos[i]) < 45.0:
                            _place_slab(kinds, edge + r * sd * _rng.randf_range(-2.0, 3.0), _rng.randf_range(1.5, 3.8), true)
                            var sp: Vector3 = edge - r * sd * _rng.randf_range(1.5, 5.0)
                            if height(sp.x, sp.z) > 0.15:
                                _put_free(kinds, shore[_rng.randi() % shore.size()], sp, 1.0)
                    continue
                if i % 2 == 0 and _rng.randf() < 0.85 * float(style["slab"]):
                    # Rounded slabs lying along the road, right up to the shoulder.
                    var size := _rng.randf_range(1.2, 3.2)
                    var off := 3.0 + 1.25 * size + _rng.randf_range(0.0, 3.0)
                    var along_yaw := atan2(-road_dir[i].z, road_dir[i].x)
                    _place_slab(kinds, road_pos[i] + r * sd * off + road_dir[i] * _rng.randf_range(-1.5, 1.5), size, false, 1.1, along_yaw)
                for n in 2:
                    var p: Vector3 = road_pos[i] + r * sd * _rng.randf_range(3.1, 7.0) + road_dir[i] * _rng.randf_range(-1.0, 1.0)
                    _put_free(kinds, cover[_rng.randi() % cover.size()], p, 0.3)
                for n in 2:
                    var p2: Vector3 = road_pos[i] + r * sd * _rng.randf_range(3.0, 10.0) + road_dir[i] * _rng.randf_range(-1.0, 1.0)
                    _put_free(kinds, fine[_rng.randi() % fine.size()], p2, 0.3)
                if _rng.randf() < 0.6:
                    var p4: Vector3 = road_pos[i] + r * sd * _rng.randf_range(7.0, 16.0) + road_dir[i] * _rng.randf_range(-1.0, 1.0)
                    var pool: Array = cover if _rng.randf() < 0.5 else fine
                    _put_free(kinds, pool[_rng.randi() % pool.size()], p4, 0.5)
                if i % 4 == 0 and _rng.randf() < float(style["tree_p"]):
                    var p3: Vector3 = road_pos[i] + r * sd * _rng.randf_range(6.0, 14.0)
                    var y3 := height(p3.x, p3.z)
                    if y3 > 0.8 and _free_spot(p3.x, p3.z, 3.0):
                        _put(kinds, trees[_rng.randi() % trees.size()], Vector3(p3.x, y3, p3.z), 0.3)
    # 2. Across the islands, following the zone of the nearest stretch of road.
    var area := CORE
    for k in (18000 if diorama else 34000):
        var x := _rng.randf_range(area.position.x, area.end.x)
        var z := _rng.randf_range(area.position.y, area.end.y)
        if diorama and Vector2(x, z).distance_to(DIO_CENTER) > DIO_R - 12.0:
            continue
        var near := _nearest_road(x, z)
        if near[0] < 9.0 * _rw:
            continue
        var y := _height_near(x, z, near)
        if y < -2.5:
            continue
        var zone := zone_at(near[1] * STEP)
        var style: Dictionary = ZONE_STYLE[zone]
        if y < 1.2:
            # The shore: sea buckthorn, sea kale and stones above the water, reeds and bulrushes in
            # the calm shallows, water lilies in the bay, slabs half in the water elsewhere.
            var shore: Array = style["shore"]
            var reeds: Array = style["reeds"]
            if diorama:
                reeds = ["vass"] if zone in ["hamn", "vik", "ang"] else []
                shore = []
            if y > 0.15 and not shore.is_empty() and _rng.randf() < 0.3:
                _put_free(kinds, shore[_rng.randi() % shore.size()], Vector3(x, y, z), 1.5)
            elif y > -1.0 and y < 0.3 and not reeds.is_empty() and _rng.randf() < 0.3:
                _put(kinds, reeds[_rng.randi() % reeds.size()], Vector3(x, minf(y, 0.0), z), 0.0)
            elif y > -2.0 and y < -0.5 and zone == "vik" and _rng.randf() < 0.15:
                _put(kinds, "nackrosor", Vector3(x, 0.03, z), 0.0)
            elif y > -1.5 and _rng.randf() < 0.3 * _dens:
                _place_slab(kinds, Vector3(x, 0.0, z), _rng.randf_range(2.0, 6.5) * (_ps * 0.6 if diorama else 1.0), true)
            continue
        var veg := _noise.get_noise_2d(x * 1.1 + 500.0, z * 1.1)
        var slope := 0.0
        if veg > -0.4:
            slope = absf(height(x + 2.0, z) - y) + absf(height(x, z + 2.0) - y)
        var trees: Array = style["trees"]
        var cover: Array = style["cover"]
        var fine: Array = style["fine"]
        # Pines crowd the rocky hills (as on every skerry in the concept art); elsewhere the zone's mix.
        # Villages and pastures stay open: no hill forest there, and few trees on the flat land.
        var open_land := 1.0 if diorama else _flatness(x, z)
        var hill := y > 6.0 and not diorama and open_land > 0.9 and not zone in ["kyrkby", "hage", "norrskar"]
        if (veg > -0.05 or (hill and veg > -0.4)) and slope < (3.4 if hill else 1.8) and _free_spot(x, z, 3.0 * _ps) \
                and _rng.randf() < (0.3 + float(style["tree_p"]) + (0.25 if hill else 0.0)) * _dens * open_land * open_land:
            var kind: String = "tall" if hill and _rng.randf() < 0.7 else trees[_rng.randi() % trees.size()]
            _put(kinds, kind, Vector3(x, y, z), 0.3)
        elif veg < -0.15 and _rng.randf() < 0.3 * float(style["slab"]) * _dens:
            # Big slabs keep at least their own width from the road, so none hangs over it.
            var size := _rng.randf_range(2.5, 9.0) * (_ps * 0.5 if diorama else 1.0)
            if diorama or near[0] > 4.0 + size * 1.9:
                _place_slab(kinds, Vector3(x, 0.0, z), size, false)
        elif zone == "skog" and _rng.randf() < 0.05 and near[0] > 14.0:
            _put(kinds, "flyttblock", Vector3(x, y, z))
        elif style.has("thicket") and near[0] > 14.0 and _rng.randf() < 0.12 and _free_spot(x, z, 3.0):
            # Big thickets of hazel and dog rose along fields and lanes, back from the road.
            var thicket: Array = style["thicket"]
            _put(kinds, thicket[_rng.randi() % thicket.size()], Vector3(x, y, z), 0.2)
        elif _rng.randf() < 0.14 * _dens:
            _put(kinds, cover[_rng.randi() % cover.size()], Vector3(x, y, z))
        elif not diorama and _rng.randf() < 0.16 and _free_spot(x, z, 0.5):
            _put(kinds, fine[_rng.randi() % fine.size()], Vector3(x, y, z))
    if not diorama:
        _place_fences()
        _far_islet_trees(kinds)
    _add_scattered(kinds)


## Put a plant or stone at p (height from the ground) unless something is standing there.
func _put_free(kinds: Dictionary, kind: String, p: Vector3, clearance: float) -> void:
    if _free_spot(p.x, p.z, clearance):
        if kind in ["grastuva", "buske", "blabarsris"] and _rundhall(p.x, p.z) > 0.5:
            kind = ROCK_COVER[_rng.randi() % ROCK_COVER.size()]   # bare rock: no soil for grass
        _put(kinds, kind, Vector3(p.x, height(p.x, p.z), p.z))


const ROCK_COVER := ["renlav", "mossa", "stenar", "ljungtuva", "ljungtuva", "grastuva"]


## Pine silhouettes on the far islands, so the horizon reads as wooded skerries like the concept.
func _far_islet_trees(kinds: Dictionary) -> void:
    var core := CORE
    for isl in _islets:
        if core.has_point(Vector2(isl[0], isl[1])):
            continue
        var n := clampi(int(isl[2] * isl[3] / 260.0), 2, 60)
        for k in n:
            var a := _rng.randf() * TAU
            var rr := sqrt(_rng.randf()) * 0.8
            var x: float = isl[0] + cos(a) * rr * isl[2]
            var z: float = isl[1] + sin(a) * rr * isl[3]
            if core.has_point(Vector2(x, z)):
                continue
            var y := _far_height(x, z)
            if y > 1.5:
                _put(kinds, "tall_fjarran", Vector3(x, y, z), 0.4)


## Roundpole fences (gärdsgård) along the meadow and the edge of the village, on the land side.
func _place_fences() -> void:
    var transforms := []
    var s := 0.0
    while s < length:
        var zone := zone_at(s)
        var i := int(s / STEP) % road_pos.size()
        if (zone == "ang" or (zone == "hamn" and s > 260.0)) and road_bridge[i] == 0:
            var dir: Vector3 = sample(s)["dir"]
            var flat := Vector3(dir.x, 0, dir.z).normalized()
            var r := flat.cross(Vector3.UP).normalized()
            var p: Vector3 = sample(s)["pos"] + r * 4.6
            if _free_spot(p.x, p.z, 1.0):
                transforms.append(Transform3D(Basis(Vector3.UP, atan2(-flat.z, flat.x)).scaled(Vector3(1.0, 1.15, 1.15)),
                    Vector3(p.x, height(p.x, p.z), p.z)))
        s += 3.0
    if not transforms.is_empty():
        add_child(_multimesh(_merged(_model_mesh("gardsgard")), transforms))


var _gulls: Array = []   # [node, centre, radius, angular speed, phase]


## Life on and over the water: gulls, sailboats at anchor, sea marks by the bridges, cairns.
func _place_life() -> void:
    var harbour: Vector3 = sample(_nearest_s(HARBOUR))["pos"]
    var flocks := [harbour + Vector3(0, 0, 40), sample(length * 0.12)["pos"], sample(length * 0.33)["pos"]]
    for k in 12:
        var gull := _scene("mas")
        add_child(gull)
        var centre: Vector3 = flocks[k % flocks.size()] + Vector3(_rng.randf_range(-50, 50), _rng.randf_range(14, 32), _rng.randf_range(-30, 50))
        _gulls.append([gull, centre, _rng.randf_range(10.0, 28.0), _rng.randf_range(0.25, 0.45) * (1.0 if k % 2 else -1.0), _rng.randf() * TAU])
    var placed := 0
    for i in range(0, road_pos.size(), 7):
        if placed >= 7:
            break
        var zone := zone_at(i * STEP)
        if not zone in ["vik", "hamn", "ang", "marina"]:
            continue
        for side in [-1.0, 1.0]:
            var p: Vector3 = road_pos[i] + _right(i) * float(side) * _rng.randf_range(50.0, 110.0)
            if height(p.x, p.z) < -3.5 and _free_spot(p.x, p.z, 10.0) and _rng.randf() < 0.3:
                var boat := _prop("segelbat", Vector3(p.x, 0.2, p.z), _rng.randf() * TAU)
                _bobbers.append([boat, 0.2, placed * 1.3])
                _keep(Vector2(p.x, p.z), 12.0)
                placed += 1
                break
    var n := road_pos.size()
    for i in n:
        if road_bridge[i] == 1 and road_bridge[(i - 1 + n) % n] == 0:
            var mid := (i + 18) % n
            for side in [-1.0, 1.0]:
                var p: Vector3 = road_pos[mid] + _right(mid) * float(side) * 32.0
                if height(p.x, p.z) < -1.5:
                    var mark := _prop("prick_rod" if side < 0 else "prick_gron", Vector3(p.x, -0.6, p.z), 0.0)
                    _bobbers.append([mark, -0.6, i * 0.1])
    for spot in [Vector2(-470, 150), Vector2(560, -140)]:
        var best := Vector3(spot.x, height(spot.x, spot.y), spot.y)
        for t in 50:
            var cx: float = spot.x + _rng.randf_range(-70, 70)
            var cz: float = spot.y + _rng.randf_range(-70, 70)
            var cy := height(cx, cz)
            if cy > best.y and _nearest_road(cx, cz)[0] > 14.0:
                best = Vector3(cx, cy, cz)
        _prop("kummel", best, 0.0, 1.3)
    if diorama:
        return
    # Eiders resting on the water close to the shore.
    var rafts := 0
    for i in range(0, road_pos.size(), 19):
        if rafts >= 9:
            break
        if zone_at(i * STEP) == "skog":
            continue
        for side in [-1.0, 1.0]:
            var e: Vector3 = road_pos[i] + _right(i) * float(side) * _rng.randf_range(22.0, 60.0)
            if height(e.x, e.z) < -1.2 and _free_spot(e.x, e.z, 6.0) and _rng.randf() < 0.45:
                _boat("ejdrar", Vector3(e.x, 0.0, e.z), _rng.randf() * TAU)
                _keep(Vector2(e.x, e.z), 5.0)
                rafts += 1
                break
    # Kayaks paddling slow circles in the harbour bay and the sheltered bay.
    for c in [Vector2(70.0, 430.0), Vector2(-360.0, -20.0), Vector2(-150.0, 420.0)]:
        var radius := 34.0
        while radius > 12.0 and not _water_circle(c, radius):
            radius -= 6.0
        if radius > 12.0:
            var kayak := _scene("kajak")
            add_child(kayak)
            _paddlers.append([kayak, Vector3(c.x, 0.05, c.y), radius, 1.1 / radius * (1.0 if _paddlers.size() % 2 else -1.0), _rng.randf() * TAU])
    # A white archipelago boat out to the south: it runs a long loop (east on one lane, west on the
    # next, turning at the ends) on the first stretch of open water long enough, clear of islands.
    for lane in range(600, 1400, 20):
        var run := 0.0
        var x0 := -2000.0
        for x in range(-2000, 2200, 20):
            var blocked := false
            for dz in [-14.0, 0.0, 20.0, 40.0, 54.0]:
                if natural(float(x), lane + dz) > -4.0:
                    blocked = true
                    break
            if blocked:
                if run >= 1500.0:
                    break
                run = 0.0
                x0 = x + 20.0
            else:
                run += 20.0
        if run >= 1500.0:
            _ferry = _scene("skargardsbat")
            add_child(_ferry)
            _ferry_route = [x0 + 60.0, x0 + run - 60.0, float(lane)]
            break


var _paddlers: Array = []   # [node, centre, radius, angular speed, phase]
var _ferry: Node3D
var _ferry_route := []      # [west end x, east end x, lane z]; the return lane is 40 m further out


## Position and heading of the archipelago boat after travelling d metres round its loop.
func _ferry_at(d: float) -> Array:
    var xa: float = _ferry_route[0]
    var xb: float = _ferry_route[1]
    var z: float = _ferry_route[2]
    var r := 20.0
    var straight := xb - xa
    var loop := 2.0 * straight + 2.0 * PI * r
    d = fposmod(d, loop)
    if d < straight:
        return [Vector3(xa + d, 0.0, z), 0.0]
    d -= straight
    if d < PI * r:
        var a := d / r
        return [Vector3(xb + sin(a) * r, 0.0, z + r - cos(a) * r), -a]
    d -= PI * r
    if d < straight:
        return [Vector3(xb - d, 0.0, z + 2.0 * r), PI]
    d -= straight
    var b := d / r
    return [Vector3(xa - sin(b) * r, 0.0, z + r + cos(b) * r), PI - b]


func _water_circle(c: Vector2, radius: float) -> bool:
    for k in 12:
        var a := TAU * k / 12.0
        if height(c.x + cos(a) * radius, c.y + sin(a) * radius) > -0.8:
            return false
    return height(c.x, c.y) < -0.8


## A granite slab of the given size at p (on the ground, or half in the water along the shore).
func _place_slab(kinds: Dictionary, p: Vector3, size: float, shore: bool, tall := 1.0, yaw := INF) -> void:
    var y := height(p.x, p.z)
    if not shore and y < -0.5:
        return
    if not _free_spot(p.x, p.z, size * 1.6):
        return
    var base := (maxf(y, -1.5) - size * 0.35) if shore else (y - size * 0.25)
    var name := "hall_%d" % (1 + _rng.randi() % 5)
    if not kinds.has(name):
        kinds[name] = []
    var turn: float = _rng.randf() * TAU if yaw == INF else yaw + _rng.randf_range(-0.25, 0.25)
    kinds[name].append(Transform3D(Basis(Vector3.UP, turn).scaled(
        Vector3(size, size * tall * _rng.randf_range(0.8, 1.25), size)), Vector3(p.x, base, p.z)))


## Small ground cover: finer chunks (so it is culled close by) and no shadows of its own.
const SMALL_KINDS := ["grastuva", "blabarsris", "lingonris", "mossa", "renlav", "stenar", "nackrosor", "strandkal"]


## Multimeshes in chunks, so small things far away are skipped (visibility ranges). Each model is
## merged into one surface with its colours in the vertices: one draw call per chunk instead of one
## per material.
func _add_scattered(kinds: Dictionary) -> void:
    var ranges := {"grastuva": 150.0, "ljungtuva": 210.0, "rallarros": 260.0, "buske": 280.0, "sten": 500.0, "hall": 1800.0,
        "vass": 320.0, "nackrosor": 320.0, "en": 450.0, "flyttblock": 900.0, "blabarsris": 140.0, "lingonris": 120.0,
        "mossa": 110.0, "renlav": 130.0, "stenar": 170.0, "kaveldun": 320.0, "strandkal": 220.0, "havtorn": 450.0}
    for name in kinds:
        var list: Array = kinds[name]
        if list.is_empty():
            continue
        var kind: String = name.substr(0, name.rfind("_"))
        var rock: bool = name.begins_with("hall") or name.begins_with("sten_") or name.begins_with("flyttblock")
        var mat: Material = null
        if _is_tree(kind):
            mat = _wind_material("leaf" if kind in LEAFY_KINDS else "tree")
        elif _sways(kind):
            mat = _wind_material("plant")
        elif kind in STILL_PLANTS:
            mat = _wind_material("still")
        var mesh := _merged(_model_mesh(name), rock, mat)
        var small: bool = _is_small(kind)
        var chunk := 64.0 if small else 160.0
        var far_mesh: Mesh = null
        if kind == "tall" and not diorama:
            # Beyond 170 m a pine is drawn as the cheap silhouette of the far islands.
            far_mesh = _merged(_model_mesh("tall_fjarran_%d" % (1 + int(name.get_slice("_", 1)) % 2)), false, mat)
        var chunks := {}
        for t in list:
            var key := Vector2i(floori(t.origin.x / chunk), floori(t.origin.z / chunk))
            if not chunks.has(key):
                chunks[key] = []
            chunks[key].append(t)
        var aabb := mesh.get_aabb()
        for key in chunks:
            var mmi := _multimesh(mesh, chunks[key])
            if not diorama:
                mmi.visibility_range_end = _view_range(kind, name) if _view_range(kind, name) > 0.0 else ranges.get(kind, ranges.get(name.get_slice("_", 0), 0.0))
            if small or kind == "tall_fjarran":
                mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
            add_child(mmi)
            var far: MultiMeshInstance3D = null
            if far_mesh:
                mmi.visibility_range_end = 170.0
                far = _multimesh(far_mesh, chunks[key])
                far.visibility_range_begin = 170.0
                far.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
                add_child(far)
            if not diorama:
                _register_solid(kind, chunks[key], aabb, mmi, far)


## What free riding bumps into: tree trunks (the tank pushes them over), boulders as walls,
## granite slabs and stones as humps the bike rides over (the tallest ones as walls).
func _register_solid(kind: String, list: Array, aabb: AABB, mmi: MultiMeshInstance3D, far: MultiMeshInstance3D) -> void:
    var tree := _is_tree(kind) and kind != "tall_fjarran"
    var rock := kind == "hall" or kind == "sten" or kind == "flyttblock" or _is_rock(kind)
    if not tree and not rock:
        return
    var half := maxf(maxf(absf(aabb.position.x), aabb.end.x), maxf(absf(aabb.position.z), aabb.end.z))
    for k in list.size():
        var t: Transform3D = list[k]
        var sc := t.basis.get_scale()
        if tree:
            _block(t.origin.x, t.origin.z, 0.32 * sc.x, [mmi, k, far])
            continue
        var r := half * sc.x * 0.8
        var top := t.origin.y + aabb.end.y * sc.y
        var ground := height(t.origin.x, t.origin.z)
        if top < ground + 0.25 or ground < -0.5:
            continue
        if kind == "flyttblock" or top > ground + 2.2:
            _block(t.origin.x, t.origin.z, r * 0.85)
        else:
            _file(_bumps, t.origin.x, t.origin.z, r, [t.origin.x, t.origin.z, r, top])


var _plain_mat: StandardMaterial3D
var _wind_mats := {}
const VAXT_SHADER := preload("res://world/vaxt.gdshader")
const TREE_KINDS := ["tall", "gran", "bjork", "vindtall", "al", "ronn", "salg", "tall_fjarran"]
const SWAY_KINDS := ["grastuva", "ljungtuva", "vass", "kaveldun", "rallarros", "havtorn", "strandkal", "buske", "hassel", "nypon",
    "blabarsris", "lingonris", "en"]


## Shared wind materials: trees sway a little at the crown, grass and flowers most at the tips.
func _wind_material(kind: String) -> ShaderMaterial:
    if not _wind_mats.has(kind):
        var m := ShaderMaterial.new()
        m.shader = VAXT_SHADER
        var tree := kind == "tree" or kind == "leaf"
        m.set_shader_parameter("sway_linear", 0.012 if tree else 0.0)
        m.set_shader_parameter("sway_square", 0.09 if kind == "plant" else 0.0)
        m.set_shader_parameter("leafy", 1.0 if kind == "leaf" else 0.0)
        m.set_shader_parameter("ground_plant", 1.0 if kind == "plant" or kind == "still" else 0.0)
        _wind_mats[kind] = m
    return _wind_mats[kind]


## One surface with the material colours baked into the vertices (rocks keep the granite shader).
## Models with glowing parts, and TextureCraft-painted ones (their colour is in a texture), are left
## as they are.
func _merged(mesh: Mesh, rock := false, material: Material = null) -> Mesh:
    var verts := PackedVector3Array()
    var norms := PackedVector3Array()
    var cols := PackedColorArray()
    var idx := PackedInt32Array()
    for k in mesh.get_surface_count():
        var m := mesh.surface_get_material(k)
        if m is BaseMaterial3D and ((m as BaseMaterial3D).emission_enabled or (m as BaseMaterial3D).albedo_texture):
            return mesh
        var c: Color = (m as BaseMaterial3D).albedo_color if m is BaseMaterial3D else Color.WHITE
        var arr := mesh.surface_get_arrays(k)
        var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
        var base := verts.size()
        verts.append_array(v)
        norms.append_array(arr[Mesh.ARRAY_NORMAL])
        for i in v.size():
            cols.append(c)
        var ix = arr[Mesh.ARRAY_INDEX]
        if ix == null or (ix as PackedInt32Array).is_empty():
            for i in v.size():
                idx.append(base + i)
        else:
            for i in ix:
                idx.append(base + i)
    var arrays := []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = verts
    arrays[Mesh.ARRAY_NORMAL] = norms
    arrays[Mesh.ARRAY_COLOR] = cols
    arrays[Mesh.ARRAY_INDEX] = idx
    var out := ArrayMesh.new()
    out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    if rock:
        var mat := ShaderMaterial.new()
        mat.shader = GROUND_SHADER
        mat.set_shader_parameter("use_vertex_color", true)
        out.surface_set_material(0, mat)
    elif material:
        out.surface_set_material(0, material)
    else:
        if _plain_mat == null:
            _plain_mat = StandardMaterial3D.new()
            _plain_mat.vertex_color_use_as_albedo = true
            _plain_mat.vertex_color_is_srgb = true
            _plain_mat.roughness = 0.85
        out.surface_set_material(0, _plain_mat)
    return out


## Faceted clouds around the horizon, lit warm by the low sun.
func _build_clouds() -> void:
    # Peach clouds with a faint glow, as if lit from below by the setting sun.
    var cloud_mat := StandardMaterial3D.new()
    cloud_mat.albedo_color = Color("ffd0ae")
    cloud_mat.emission_enabled = true
    cloud_mat.emission = Color("ff9a6a")
    cloud_mat.emission_energy_multiplier = 0.35
    cloud_mat.roughness = 1.0
    var sets := [[], [], []]
    for k in 36:
        var a := _rng.randf() * TAU
        var r := _rng.randf_range(1300.0, 3200.0)
        var s := _rng.randf_range(35.0, 95.0)
        sets[k % 3].append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(s, s * 0.7, s)),
            Vector3(100.0 + cos(a) * r, _rng.randf_range(240.0, 640.0), sin(a) * r)))
    for k in 3:
        var mmi := _multimesh(_model_mesh("moln_%d" % (k + 1)), sets[k])
        mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        mmi.material_override = cloud_mat
        add_child(mmi)


## The mesh of model `name`, without keeping the scene instance it came in (which would leak).
func _model_mesh(name: String) -> Mesh:
    var node := _scene(name)
    var mesh := _first_mesh(node)
    node.free()
    return mesh


func _first_mesh(root: Node) -> Mesh:
    for child in root.find_children("*", "MeshInstance3D", true, false):
        return (child as MeshInstance3D).mesh
    return null


func _multimesh(mesh: Mesh, transforms: Array) -> MultiMeshInstance3D:
    var mm := MultiMesh.new()
    mm.transform_format = MultiMesh.TRANSFORM_3D
    mm.mesh = mesh
    mm.instance_count = transforms.size()
    for k in transforms.size():
        mm.set_instance_transform(k, transforms[k])
    var mmi := MultiMeshInstance3D.new()
    mmi.multimesh = mm
    return mmi


func _box_mesh(size: Vector3, col: Color) -> BoxMesh:
    var b := BoxMesh.new()
    b.size = size
    var mat := StandardMaterial3D.new()
    mat.albedo_color = col
    mat.roughness = 0.9
    b.material = mat
    return b


# --- Diorama (world-select card) ---------------------------------------------------------------

func _build_diorama() -> void:
    _diorama_environment()
    add_child(_diorama_terrain())
    _diorama_base()
    _build_road_mesh()
    _diorama_water()
    _place_props()
    _scatter_nature()
    camera = Camera3D.new()
    camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    camera.size = 1900.0
    camera.far = 14000.0
    add_child(camera)
    var centre := Vector3(DIO_CENTER.x, -150.0, DIO_CENTER.y)
    camera.position = centre + Vector3(0.5, 0.75, 0.8).normalized() * 6000.0
    camera.look_at(centre, Vector3.UP)
    camera.make_current()


func _diorama_environment() -> void:
    var env := Environment.new()
    env.background_mode = Environment.BG_CLEAR_COLOR
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color("cfd8ee")
    env.ambient_light_energy = 0.55
    env.tonemap_mode = Environment.TONE_MAPPER_ACES
    env.tonemap_exposure = 1.0
    env.ssao_enabled = true
    env.ssao_radius = 25.0
    env.ssao_intensity = 1.4
    env.adjustment_enabled = true
    env.adjustment_saturation = 1.06
    environment = env
    var world_env := WorldEnvironment.new()
    world_env.environment = env
    add_child(world_env)
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-42.0, -150.0, 0.0)
    sun.light_color = Color("ffe2c4")
    sun.light_energy = 1.6
    sun.shadow_enabled = true
    sun.directional_shadow_max_distance = 9000.0
    sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
    add_child(sun)


## The ground inside the circle; vertices outside are pulled onto the rim.
func _diorama_terrain() -> MeshInstance3D:
    var cell := 9.0
    var x0 := DIO_CENTER.x - DIO_R
    var z0 := DIO_CENTER.y - DIO_R
    var n := int(2.0 * DIO_R / cell) + 1
    var pos := PackedVector3Array()
    var inside := PackedByteArray()
    var near := PackedFloat32Array()
    pos.resize((n + 1) * (n + 1))
    inside.resize((n + 1) * (n + 1))
    near.resize((n + 1) * (n + 1))
    for iz in n + 1:
        for ix in n + 1:
            var p := Vector2(x0 + ix * cell, z0 + iz * cell)
            var d := p.distance_to(DIO_CENTER)
            var k := iz * (n + 1) + ix
            inside[k] = 1 if d <= DIO_R else 0
            if d > DIO_R:
                p = DIO_CENTER + (p - DIO_CENTER) / d * DIO_R
            pos[k] = Vector3(p.x, height(p.x, p.y), p.y)
            near[k] = _nearest_road(p.x, p.y)[0]
    var verts := PackedVector3Array()
    var colors := PackedColorArray()
    for iz in n:
        for ix in n:
            var k00 := iz * (n + 1) + ix
            var k10 := k00 + 1
            var k01 := k00 + n + 1
            var k11 := k01 + 1
            if inside[k00] + inside[k10] + inside[k01] + inside[k11] == 0:
                continue
            var road_d := minf(minf(near[k00], near[k10]), minf(near[k01], near[k11]))
            _tri(verts, colors, pos[k00], pos[k11], pos[k10], road_d)
            _tri(verts, colors, pos[k00], pos[k01], pos[k11], road_d)
    return _mesh(verts, colors, 0.92, true)


## Add a triangle whose front face points along `outward`.
func _face(verts: PackedVector3Array, colors: PackedColorArray, a: Vector3, b: Vector3, c: Vector3, col: Color, outward: Vector3) -> void:
    if (c - a).cross(b - a).dot(outward) < 0.0:
        verts.append_array([a, c, b])
    else:
        verts.append_array([a, b, c])
    for k in 3:
        colors.append(col)


## Rock skirt under the rim narrowing to a point, in darkening strata, plus a few loose rocks.
func _diorama_base() -> void:
    var n := 140
    var rings := []
    var top := []
    for k in n:
        var a := TAU * k / n
        var p := DIO_CENTER + Vector2(cos(a), sin(a)) * DIO_R
        top.append(Vector3(p.x, minf(height(p.x, p.y), 0.0) - 0.3, p.y))
    rings.append(top)
    for spec in [[1.0, -40.0], [0.9, -170.0], [0.64, -330.0], [0.32, -470.0]]:
        var ring := []
        for k in n:
            var a := TAU * k / n
            var r: float = spec[0] * (1.0 + (_noise.get_noise_2d(k * 11.0, spec[1]) * 0.16 if spec[0] < 1.0 else 0.0))
            var p := DIO_CENTER + Vector2(cos(a), sin(a)) * DIO_R * r
            ring.append(Vector3(p.x, spec[1] + _noise.get_noise_2d(k * 7.0, spec[1] * 3.0) * 20.0, p.y))
        rings.append(ring)
    var tip := Vector3(DIO_CENTER.x, -600.0, DIO_CENTER.y)
    var strata := [Color("9c7a70"), Color("86655e"), Color("72544f"), Color("5e4542"), Color("4f3a38")]
    var verts := PackedVector3Array()
    var colors := PackedColorArray()
    var centre := Vector3(DIO_CENTER.x, -200.0, DIO_CENTER.y)
    for ri in rings.size():
        for k in n:
            var a: Vector3 = rings[ri][k]
            var b: Vector3 = rings[ri][(k + 1) % n]
            var col: Color = strata[ri].lightened(fposmod(sin(k * 12.9898 + ri * 4.1) * 43758.5, 1.0) * 0.08)
            if ri + 1 < rings.size():
                var c: Vector3 = rings[ri + 1][(k + 1) % n]
                var d: Vector3 = rings[ri + 1][k]
                var out := ((a + b + c + d) / 4.0 - centre)
                _face(verts, colors, a, b, c, col, out)
                _face(verts, colors, a, c, d, col, out)
            else:
                _face(verts, colors, a, b, tip, col, (a + b) / 2.0 - centre)
    add_child(_mesh(verts, colors, 0.95))
    # A few rocks floating below, like crumbs breaking off the island.
    var rock_mat := StandardMaterial3D.new()
    rock_mat.albedo_color = Color("7d5f58")
    rock_mat.roughness = 0.95
    for k in 9:
        var rock := MeshInstance3D.new()
        var sphere := SphereMesh.new()
        sphere.radial_segments = 6
        sphere.rings = 3
        sphere.material = rock_mat
        rock.mesh = sphere
        var a := _rng.randf() * TAU
        var r := DIO_R * _rng.randf_range(0.55, 1.15)
        rock.position = Vector3(DIO_CENTER.x + cos(a) * r, _rng.randf_range(-640, -220), DIO_CENTER.y + sin(a) * r)
        var s := _rng.randf_range(18.0, 50.0)
        rock.scale = Vector3(s, s * 0.8, s)
        rock.rotation = Vector3(_rng.randf(), _rng.randf() * TAU, _rng.randf())
        add_child(rock)


## Sea cut to the circle, with a see-through blue side where the water meets the rim.
func _diorama_water() -> void:
    var plane := PlaneMesh.new()
    plane.size = Vector2(DIO_R * 2.0, DIO_R * 2.0)
    plane.subdivide_width = 160
    plane.subdivide_depth = 160
    var mat := ShaderMaterial.new()
    mat.shader = load("res://world/water.gdshader")
    mat.set_shader_parameter("clip_radius", DIO_R - 0.5)
    mat.set_shader_parameter("clip_center", DIO_CENTER)
    mat.set_shader_parameter("wave_height", 0.0)
    mat.set_shader_parameter("shallow", Color("5fd3c9"))
    mat.set_shader_parameter("deep", Color("2b78b8"))
    mat.set_shader_parameter("depth_fade", 30.0)
    plane.material = mat
    var water := MeshInstance3D.new()
    water.mesh = plane
    water.position = Vector3(DIO_CENTER.x, 0.0, DIO_CENTER.y)
    water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(water)
    var verts := PackedVector3Array()
    var colors := PackedColorArray()
    var n := 140
    for k in n:
        var a0 := TAU * k / n
        var a1 := TAU * (k + 1) / n
        var p0 := DIO_CENTER + Vector2(cos(a0), sin(a0)) * (DIO_R + 0.3)
        var p1 := DIO_CENTER + Vector2(cos(a1), sin(a1)) * (DIO_R + 0.3)
        var b0 := minf(height(p0.x, p0.y), 0.0)
        var b1 := minf(height(p1.x, p1.y), 0.0)
        if b0 > -0.2 and b1 > -0.2:
            continue
        var out := Vector3(cos((a0 + a1) / 2.0), 0.0, sin((a0 + a1) / 2.0))
        var t0 := Vector3(p0.x, 0.0, p0.y)
        var t1 := Vector3(p1.x, 0.0, p1.y)
        var d0 := Vector3(p0.x, b0, p0.y)
        var d1 := Vector3(p1.x, b1, p1.y)
        _face(verts, colors, t0, t1, d1, Color("2f8fbf"), out)
        _face(verts, colors, t0, d1, d0, Color("2f8fbf"), out)
    var side := _mesh(verts, colors, 0.2)
    var side_mat: StandardMaterial3D = side.mesh.surface_get_material(0)
    side_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    side_mat.albedo_color = Color(1, 1, 1, 0.78)
    add_child(side)
