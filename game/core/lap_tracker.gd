extends RefCounted
## Times the world's segments and whole laps during a ride, and records each lap's split times so
## the best lap can ride along as a ghost. The world HUD feeds it every frame with the continuous lap
## distance (the ride's distance + the world's lap offset, not wrapped) and the ride's moving time.
## A lap only counts when it was ridden from the start line all the way round on the road: leaving the
## lap ("Tryck ej här"), going back to it, or a teleport throws the running lap and segments away.

const SPLIT := 10.0          # metres between recorded lap splits
const JUMP := 60.0           # a bigger move in one frame is a jump, not riding

var world_id := ""
var length := 0.0
var segments: Array = []     # the world's segments: [{"id", "name", "kind", "from", "to"}]
var results: Array = []      # finished segments: [{"world", "id", "name", "kind", "time"}]
var laps: Array = []         # finished laps: [{"world", "time", "splits": PackedFloat32Array}]
var events: Array = []       # for the HUD, oldest first (see _event)
var active := {}             # segment id → the moving time it started at
var lap_valid := false
var lap_start := 0.0
var splits := PackedFloat32Array()   # seconds into the lap at 0, 10, 20 … metres

var _last_s := 0.0
var _last_t := 0.0
var _have := false


## A world is under the ride (at the start, or after a teleport). The lap starts at once only when
## the rider stands on the start line.
func set_world(id: String, lap_length: float, world_segments: Array) -> void:
    world_id = id
    length = lap_length
    segments = world_segments
    _invalidate()
    _have = false


func update(s: float, t: float, valid: bool) -> void:
    if not valid or length <= 0.0:
        _invalidate()
        _have = false
        return
    if not _have:
        _have = true
        _last_s = s
        _last_t = t
        if fposmod(s, length) < 5.0:
            _start_lap(t)
        return
    var ds := s - _last_s
    if absf(ds) > JUMP or ds < -0.5:
        _invalidate()
        _last_s = s
        _last_t = t
        return
    if ds <= 0.0:
        _last_t = t
        return
    var a := _last_s
    var a_t := _last_t
    var lap_a := floorf(a / length)
    var lap_b := floorf(s / length)
    var pb := s - lap_b * length
    var pa := a - lap_a * length
    if lap_b > lap_a:
        # Over the start line: the lap is done (if it counted) and the next one begins here.
        var cross_t := lerpf(a_t, t, (lap_b * length - a) / ds)
        if lap_valid:
            _fill_splits(length, cross_t, pa, a_t, length)
            var lap_time := cross_t - lap_start
            laps.append({"world": world_id, "time": lap_time, "splits": splits.duplicate()})
            _event({"type": "lap", "time": lap_time})
        active.clear()
        _start_lap(cross_t)
        pa = 0.0
        a_t = cross_t
    if lap_valid:
        _fill_splits(pb, t, pa, a_t, pb)
    for seg in segments:
        var from: float = seg["from"]
        var to: float = seg["to"]
        var id: String = seg["id"]
        if pa < from and pb >= from:
            active[id] = _time_at(from, pa, a_t, pb, t)
            _event({"type": "segment_start", "segment": seg})
        if active.has(id) and pa < to and pb >= to:
            var took: float = _time_at(to, pa, a_t, pb, t) - float(active[id])
            active.erase(id)
            var result := {"world": world_id, "id": id, "name": seg["name"], "kind": seg["kind"], "time": took}
            results.append(result)
            _event({"type": "segment_end", "segment": seg, "time": took})
    _last_s = s
    _last_t = t


## The segment being ridden now ({} when none), with how far it has to go.
func current_segment(s: float) -> Dictionary:
    var p := fposmod(s, length) if length > 0.0 else 0.0
    for seg in segments:
        if active.has(seg["id"]):
            return {"segment": seg, "started": active[seg["id"]], "left": float(seg["to"]) - p}
    return {}


## Seconds into the running lap, or -1 when no lap counts right now.
func lap_elapsed(t: float) -> float:
    return t - lap_start if lap_valid else -1.0


func _start_lap(t: float) -> void:
    lap_valid = true
    lap_start = t
    splits = PackedFloat32Array([0.0])


func _invalidate() -> void:
    lap_valid = false
    active.clear()
    splits = PackedFloat32Array()


## Record the splits passed between lap distance pa (at a_t) and pb (at t), up to `limit` metres.
func _fill_splits(pb: float, t: float, pa: float, a_t: float, limit: float) -> void:
    while splits.size() * SPLIT <= minf(pb, limit) and splits.size() * SPLIT <= length:
        var d := splits.size() * SPLIT
        splits.append(_time_at(d, pa, a_t, pb, t) - lap_start)


func _time_at(d: float, pa: float, a_t: float, pb: float, t: float) -> float:
    if pb - pa <= 0.0001:
        return t
    return lerpf(a_t, t, clampf((d - pa) / (pb - pa), 0.0, 1.0))


func _event(e: Dictionary) -> void:
    events.append(e)
    if events.size() > 20:
        events.pop_front()


# --- The ghost --------------------------------------------------------------------------------

## Where the best lap was `elapsed` seconds in (metres into the lap), or -1 once it has finished.
static func ghost_distance(ghost_splits: PackedFloat32Array, lap_time: float, lap_length: float, elapsed: float) -> float:
    var n := ghost_splits.size()
    if n < 2 or elapsed < 0.0 or elapsed >= lap_time:
        return -1.0
    var lo := 0
    var hi := n - 1
    if elapsed >= ghost_splits[hi]:
        var end_t := maxf(lap_time - ghost_splits[hi], 0.001)
        return lerpf(hi * SPLIT, lap_length, (elapsed - ghost_splits[hi]) / end_t)
    while hi - lo > 1:
        var mid := (lo + hi) / 2
        if ghost_splits[mid] <= elapsed:
            lo = mid
        else:
            hi = mid
    var span := maxf(ghost_splits[hi] - ghost_splits[lo], 0.001)
    return (lo + (elapsed - ghost_splits[lo]) / span) * SPLIT


## When the best lap passed `d` metres into the lap (seconds).
static func ghost_time_at(ghost_splits: PackedFloat32Array, lap_time: float, lap_length: float, d: float) -> float:
    var n := ghost_splits.size()
    if n < 2:
        return -1.0
    var k := int(d / SPLIT)
    if k >= n - 1:
        var last_d := (n - 1) * SPLIT
        return lerpf(ghost_splits[n - 1], lap_time, clampf((d - last_d) / maxf(lap_length - last_d, 0.001), 0.0, 1.0))
    return lerpf(ghost_splits[k], ghost_splits[k + 1], (d - k * SPLIT) / SPLIT)
