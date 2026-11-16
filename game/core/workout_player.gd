extends RefCounted
## Runs a Workout against the clock: current segment, target watts, intensity, skipping
## and per-segment results (used for the "klarade intervaller" count and laps).

var workout
var ftp := 200.0
var intensity := 1.0
var elapsed := 0.0
var finished := false
## Per segment: {"seconds", "power_sum", "target_sum"}.
var results: Array[Dictionary] = []


func _init(w, ftp_watts: float) -> void:
    workout = w
    ftp = ftp_watts
    if workout.has_method("set_ftp"):
        workout.set_ftp(ftp_watts)
    for s in workout.segments:
        results.append({"seconds": 0.0, "power_sum": 0.0, "target_sum": 0.0})


func index() -> int:
    return workout.segment_index_at(elapsed)


func segment() -> Dictionary:
    var i := index()
    return workout.segments[i] if i >= 0 else {}


## Target in watts right now, -1 in free segments or after the end.
func target_watts() -> int:
    var p: float = workout.target_at(elapsed)
    return -1 if p < 0.0 else roundi(p * ftp * intensity)


## Target in watts at an arbitrary time (for step lists and graphs).
func watts_at(fraction: float) -> int:
    return roundi(fraction * ftp * intensity)


func time_left_in_segment() -> float:
    var s := segment()
    return 0.0 if s.is_empty() else s["start"] + s["duration"] - elapsed


func time_left() -> float:
    return maxf(0.0, workout.duration - elapsed)


func advance(dt: float, power: float) -> void:
    if finished:
        return
    var i := index()
    if i >= 0:
        var r := results[i]
        r["seconds"] += dt
        r["power_sum"] += power * dt
        var target := target_watts()
        if target > 0:
            r["target_sum"] += target * dt
    elapsed += dt
    if elapsed >= workout.duration:
        elapsed = workout.duration
        finished = true


## Jump to the start of the next segment.
func skip() -> void:
    var s := segment()
    if s.is_empty():
        return
    elapsed = s["start"] + s["duration"]
    if elapsed >= workout.duration:
        elapsed = workout.duration
        finished = true


func change_intensity(delta: float) -> void:
    intensity = clampf(snappedf(intensity + delta, 0.05), 0.5, 1.5)


## Key efforts: interval work parts, plus steady blocks of at least a minute at 85 % FTP or more.
func key_segments() -> Array[int]:
    var keys: Array[int] = []
    for i in workout.segments.size():
        var s: Dictionary = workout.segments[i]
        if s["free"]:
            continue
        if s["interval"] > 0 or (is_equal_approx(s["from"], s["to"]) and s["from"] >= 0.85 and s["duration"] >= 60):
            keys.append(i)
    return keys


## A key effort counts as done when it was ridden to the end at >= 90 % of its target on average.
func segment_done(i: int) -> bool:
    var r := results[i]
    var s: Dictionary = workout.segments[i]
    if r["seconds"] < s["duration"] - 1.0 or r["target_sum"] <= 0.0:
        return false
    return r["power_sum"] >= 0.9 * r["target_sum"]


func stars() -> Vector2i:
    var keys := key_segments()
    var done := 0
    for i in keys:
        if segment_done(i):
            done += 1
    return Vector2i(done, keys.size())
