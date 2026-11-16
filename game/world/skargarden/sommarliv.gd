extends RefCounted
## Skärgården's summer life: people at the water and at the café tables, midsommar dancers round the
## maypole, seals on the skerries, swans, a horse in the paddock and roe deer at the forest edge, a
## camp with a fire, a tent and a hammock, dinghies and a motorboat out on the water, a walker with
## a dog and a tractor on the gravel roads.
##
## It finds what the world has already put out (jetties, bathing jetties, café tables, the maypole,
## the cows in the paddock, the gravel roads), so how those are placed stays untouched. Only
## Skärgården makes one (from its _place_props); update() runs every frame from update_view.

var w                          # the world (skargarden.gd)
var _ring: Array = []          # [dancer, angle]
var _maypole := Vector3.ZERO
var _sailors: Array = []       # [node, centre, radius, angular speed, phase, heel]
var _swimmers: Array = []      # [node, centre, radius, angular speed, phase, water height]
var _trackers: Array = []      # [node, points, length, speed, phase, side offset, trot]
var _grazers: Array = []       # [node, base yaw, phase]
var _fire: Node3D
var _rng := RandomNumberGenerator.new()


func _init(world) -> void:
    w = world
    _rng.seed = 1919


## The props of one model the world has placed (direct children, painted or not).
func _props(name: String) -> Array:
    var out := []
    for c in w.get_children():
        if c is Node3D and String(c.scene_file_path).get_file().get_basename().trim_suffix("_tex") == name:
            out.append(c)
    return out


static func _yaw_to(d: Vector2) -> float:
    return atan2(-d.y, d.x)


func _put(name: String, pos: Vector3, yaw: float, room := 0.0) -> Node3D:
    var node: Node3D = w._prop(name, pos, yaw)
    if room > 0.0:
        w._keep(Vector2(pos.x, pos.z), room)
    return node


func _mover(name: String) -> Node3D:
    var node: Node3D = w._scene(name)
    w.add_child(node)
    return node


func place() -> void:
    _place_jetties()
    _place_cafes()
    _place_dancers()
    _place_animals()
    _place_camp()
    _place_boats()
    _place_tracks()


## A man fishing from the end of each jetty, sunbathers and swimmers at the bathing jetties, and a
## bike left at the shore end.
func _place_jetties() -> void:
    for jetty: Node3D in _props("brygga").slice(0, 4):
        var box: AABB = w._first_mesh(jetty).get_aabb()
        var tip: Vector3 = jetty.transform * Vector3(box.end.x - 0.25, 0.0, box.position.z * 0.4)
        _put("fiskare_brygga", Vector3(tip.x, jetty.position.y + 0.12, tip.z), jetty.rotation.y)
    var n := 0
    for bath: Node3D in _props("badbrygga"):
        var box: AABB = w._first_mesh(bath).get_aabb()
        var along: Vector3 = bath.transform.basis.x.normalized()
        var mid: Vector3 = bath.transform * Vector3(box.get_center().x, 0.0, box.get_center().z)
        _put("solbadare", Vector3(mid.x, bath.position.y + 0.1, mid.z), bath.rotation.y + PI * 0.5)
        var out: Vector3 = bath.transform * Vector3(box.end.x + 7.0, 0.0, 0.0)
        for k in 2:
            var swimmer := _mover("badare")
            _swimmers.append([swimmer, Vector3(out.x, 0.0, out.z), 3.5 + k * 2.5, 0.25 * (1.0 if k == 0 else -1.0), _rng.randf() * TAU])
        var shore: Vector3 = bath.transform * Vector3(box.position.x - 2.5, 0.0, 1.2)
        if w.height(shore.x, shore.z) > 0.2 and w._free_spot(shore.x, shore.z, 0.5):
            _put("cykel_parkerad", w._ground(shore.x, shore.z), _yaw_to(Vector2(along.z, -along.x)), 1.0)
        n += 1


## Guests at the café and kiosk tables, a child with an ice cream, bikes by the café.
func _place_cafes() -> void:
    var k := 0
    for table: Node3D in _props("cafebord"):
        k += 1
        if k % 4 == 3:
            continue
        var seats := 2 if k % 2 == 0 else 1
        for j in seats:
            var a: float = table.rotation.y + j * PI + 0.3
            var p: Vector3 = table.position + Vector3(cos(a), 0.0, -sin(a)) * 0.85
            _put("fikagast_%d" % (1 + (k + j) % 2), w._ground(p.x, p.z), _yaw_to(Vector2(table.position.x - p.x, table.position.z - p.z)))
    # A child with an ice cream and a parked bike beside the first tables at each café.
    var done := {}
    for table: Node3D in _props("cafebord"):
        var key := Vector2i(floori(table.position.x / 60.0), floori(table.position.z / 60.0))
        if done.has(key):
            continue
        done[key] = true
        for e in [["barn_glass", Vector3(1.6, 0.0, 0.4)], ["cykel_parkerad", Vector3(-1.4, 0.0, 2.2)]]:
            var p: Vector3 = table.position + (e[1] as Vector3)
            if w.height(p.x, p.z) > 0.2:
                _put(e[0], w._ground(p.x, p.z), _yaw_to(Vector2(table.position.x - p.x, table.position.z - p.z)) + (0.0 if e[0] == "barn_glass" else 1.2))


## Ten dancers in a ring round the maypole, women in white with flower wreaths and men in folk
## costume, turning slowly.
func _place_dancers() -> void:
    var poles: Array = _props("midsommarstang")
    if poles.is_empty():
        return
    _maypole = (poles[0] as Node3D).position
    for k in 10:
        var d := _mover("dansare_1" if k % 2 == 0 else "dansare_2")
        _ring.append([d, k * TAU / 10.0])


## A horse with the cows, roe deer at the forest edge, seals hauled out on the rocks along the
## shore and swans gliding in the sheltered water.
func _place_animals() -> void:
    var cows: Array = _props("ko_rod") + _props("ko_svart")
    if not cows.is_empty():
        var c: Vector3 = (cows[0] as Node3D).position
        for k in 2:
            var p := c + Vector3(6.0 + k * 4.0, 0.0, -3.0 + k * 7.0)
            if w._free_spot(p.x, p.z, 1.5):
                var horse: Node3D = _put("hast", w._ground(p.x, p.z), _rng.randf() * TAU, 1.5)
                _grazers.append([horse, horse.rotation.y, _rng.randf() * TAU])
    var count: int = w.road_pos.size()
    var deer := 0
    var seals := 0
    var swans := 0
    var i := 40
    while i < count and (deer < 4 or seals < 7 or swans < 5):
        var s: float = i * w.STEP
        var zone: String = w.zone_at(s)
        var rp: Vector3 = w.road_pos[i]
        var r: Vector3 = w._right(i)
        for side: float in [-1.0, 1.0]:
            if deer < 4 and zone == "skog":
                var p: Vector3 = rp + r * side * 22.0
                if w.height(p.x, p.z) > 1.0 and w._free_spot(p.x, p.z, 2.0):
                    var d: Node3D = _put("radjur", w._ground(p.x, p.z), _yaw_to(Vector2(-r.x * side, -r.z * side)), 2.0)
                    _grazers.append([d, d.rotation.y, _rng.randf() * TAU])
                    deer += 1
                    i += 120
                    break
            # A seal on a rock at the water's edge with deep water just beyond.
            for off: float in [28.0, 40.0, 55.0]:
                if seals >= 7 or zone == "skog":
                    break
                var p: Vector3 = rp + r * side * off
                var h: float = w.height(p.x, p.z)
                var beyond: Vector3 = p + r * side * 5.0
                if h > 0.15 and h < 1.4 and w.height(beyond.x, beyond.z) < -0.8 and w._free_spot(p.x, p.z, 1.5):
                    var group := 2 if seals < 5 else 1
                    for g in group:
                        var q := p + Vector3(r.z, 0.0, -r.x) * (g * 1.8)
                        _put("sal", Vector3(q.x, w.height(q.x, q.z), q.z), _yaw_to(Vector2(r.x * side, r.z * side)) + g * 0.6, 1.4)
                        seals += 1
                    i += 90
                    break
            if swans < 5 and zone in ["vik", "ang", "hage"]:
                var c := Vector2(rp.x + r.x * side * 45.0, rp.z + r.z * side * 45.0)
                if w._water_circle(c, 12.0):
                    for k in 2:
                        var swan := _mover("svan")
                        _swimmers.append([swan, Vector3(c.x, 0.0, c.y), 9.0 + k * 1.2, 0.05, swans * 1.3 + k * 0.25])
                        swans += 1
                    i += 150
                    break
        i += 6


## A camp on Långön's shore: a tent, the fire with logs to sit on, and a hammock.
func _place_camp() -> void:
    var bs: float = w._nearest_s(Vector2(80.0, 925.0))
    for k in 12:
        var bi: int = int(fposmod(bs - 40.0 - k * 12.0, w.length) / w.STEP) % w.road_pos.size()
        var land: Vector3 = -w._sea_side(bi)
        var base: Vector3 = w.road_pos[bi] + land * 16.0
        var along := Vector3(land.z, 0.0, -land.x)
        var tent: Vector3 = base
        var fire: Vector3 = base + along * 5.0 - land * 1.0
        var hammock: Vector3 = base + along * 11.0 + land * 3.0
        var ok := true
        for p: Vector3 in [tent, fire, hammock]:
            if w.height(p.x, p.z) < 0.5 or not w._free_spot(p.x, p.z, 2.5):
                ok = false
        if not ok:
            continue
        _put("talt", w._ground_low(tent.x, tent.z, 1.0), _yaw_to(Vector2(-land.x, -land.z)) + 0.4, 2.5)
        _fire = _put("lagereld", w._ground(fire.x, fire.z), 0.3, 2.0)
        _put("hangmatta", w._ground_low(hammock.x, hammock.z, 1.0), _yaw_to(Vector2(land.x, land.z)), 2.5)
        return


## Three Optimist dinghies (a sailing school) and a motorboat out on the water.
func _place_boats() -> void:
    var spots := [Vector2(872.0, 330.0), Vector2(840.0, 300.0), Vector2(70.0, 470.0), Vector2(-360.0, 30.0), Vector2(600.0, 360.0)]
    var dinghies := 0
    for c: Vector2 in spots:
        if dinghies >= 3:
            break
        for r: float in [30.0, 22.0]:
            if w._water_circle(c, r + 4.0):
                var node := _mover("jolle")
                _sailors.append([node, Vector3(c.x, 0.05, c.y), r, 1.8 / r * (1.0 if dinghies % 2 else -1.0), _rng.randf() * TAU, 0.18])
                dinghies += 1
                break
    var count: int = w.road_pos.size()
    for i in range(200, count, 37):
        var zone: String = w.zone_at(i * w.STEP)
        if not zone in ["hamn", "marina", "vik", "ytterskar"]:
            continue
        var sea: Vector3 = w._sea_side(i)
        var c3: Vector3 = w.road_pos[i] + sea * 110.0
        var c := Vector2(c3.x, c3.z)
        if w._water_circle(c, 80.0):
            var boat := _mover("motorbat")
            _sailors.append([boat, Vector3(c.x, 0.1, c.y), 75.0, 6.5 / 75.0, 0.0, 0.05])
            return


## A walker with a dog on Långövägen and the tractor on Storövägen, going to the end and back.
func _place_tracks() -> void:
    for e in [["Långövägen", "promenerare", 1.15, 0.0], ["Långövägen", "hund", 1.15, 1.1], ["Storövägen", "traktor", 3.2, 0.0],
            ["Storövägen", "promenerare", 1.0, 0.0]]:
        var k: int = w.path_index(e[0])
        if k < 0:
            continue
        var pts: PackedVector3Array = w.paths[k]["pts"]
        var phase := 0.3 if e[3] == 0.0 else 0.3
        if e[0] == "Storövägen" and e[1] == "promenerare":
            phase = 0.75
        var node := _mover(e[1])
        var total := 0.0
        for j in pts.size() - 1:
            total += Vector2(pts[j].x - pts[j + 1].x, pts[j].z - pts[j + 1].z).length()
        _trackers.append([node, pts, total, e[2], phase * total * 2.0, e[3], e[1] == "hund"])


func update(now: float) -> void:
    for d in _ring:
        var a: float = d[1] + now * 0.3
        var node: Node3D = d[0]
        var p := _maypole + Vector3(cos(a), 0.0, sin(a)) * 4.2
        node.position = Vector3(p.x, w.height(p.x, p.z) + absf(sin(now * 4.0 + a * 3.0)) * 0.08, p.z)
        node.rotation.y = _yaw_to(Vector2(_maypole.x - p.x, _maypole.z - p.z))
    for b in _sailors:
        var a: float = b[4] + now * b[3]
        var v := Vector3(-sin(a), 0.0, cos(a)) * signf(b[3])
        var node: Node3D = b[0]
        node.position = (b[1] as Vector3) + Vector3(cos(a), 0.0, sin(a)) * b[2] + Vector3.UP * sin(now * 1.7 + a) * 0.05
        node.rotation = Vector3(float(b[5]) * signf(b[3]) + sin(now * 1.1) * 0.03, atan2(-v.z, v.x), sin(now * 1.4 + a) * 0.02)
    for s in _swimmers:
        var a: float = s[4] + now * s[3]
        var v := Vector3(-sin(a), 0.0, cos(a)) * signf(s[3])
        var node: Node3D = s[0]
        node.position = (s[1] as Vector3) + Vector3(cos(a), 0.0, sin(a)) * s[2] + Vector3.UP * sin(now * 2.2 + a) * 0.03
        node.rotation.y = atan2(-v.z, v.x)
    for t in _trackers:
        var pts: PackedVector3Array = t[1]
        var total: float = t[2]
        var u := fposmod(float(t[4]) + now * float(t[3]), total * 2.0)
        var back := u > total
        var dist := total * 2.0 - u if back else u
        var j := 0
        var seg := Vector2(pts[0].x - pts[1].x, pts[0].z - pts[1].z).length()
        while dist > seg and j < pts.size() - 2:
            dist -= seg
            j += 1
            seg = Vector2(pts[j].x - pts[j + 1].x, pts[j].z - pts[j + 1].z).length()
        var p: Vector3 = pts[j].lerp(pts[j + 1], clampf(dist / maxf(seg, 0.01), 0.0, 1.0))
        var dir := Vector2(pts[j + 1].x - pts[j].x, pts[j + 1].z - pts[j].z) * (-1.0 if back else 1.0)
        var side := Vector2(-dir.y, dir.x).normalized() * float(t[5])
        var node: Node3D = t[0]
        var trot := 9.0 if t[6] else 5.0
        node.position = Vector3(p.x + side.x, w.height(p.x + side.x, p.z + side.y) + absf(sin(now * trot)) * 0.04, p.z + side.y)
        node.rotation.y = _yaw_to(dir)
    for g in _grazers:
        var node: Node3D = g[0]
        var ph: float = g[2]
        node.rotation.y = float(g[1]) + sin(now * 0.1 + ph) * 0.4
        node.rotation.z = -0.25 * pow(maxf(sin(now * 0.6 + ph), 0.0), 6.0)
    if _fire:
        _fire.scale = Vector3(1.0, 1.0 + sin(now * 13.0) * 0.04 + sin(now * 21.0) * 0.03, 1.0)
