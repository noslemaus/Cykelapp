extends RefCounted
## A structured workout: an ordered list of segments with targets as fractions of FTP.
##
## File format (JSON in res://workouts):
##   {"name", "description", "category", "steps": [...]}
##   steady    {"duration": s, "power": 0.88, "cadence"?: 90, "label"?: "..."}
##   ramp      {"duration": s, "from": 0.45, "to": 0.70, ...}
##   intervals {"repeat": 3, "on": {steady fields}, "off": {steady fields}}
##   free      {"duration": s}   no target; always ridden in SIM
## Fixed watts instead of a share of FTP (ramp tests): "watts": 100 on a steady step,
## "from_watts"/"to_watts" on a ramp. They follow set_ftp(), so the trainer gets exactly those watts.
## "custom": true marks our own workouts (shown under Egna pass, outside the type collections).
## Steps are expanded into flat segments:
##   {"start", "duration", "from", "to", "free", "cadence", "label", "interval"}
## where "interval" is the 1-based number of an interval's work part (0 otherwise).

const Zones = preload("res://core/zones.gd")
const Metrics = preload("res://core/metrics.gd")

const CATEGORY_NAMES := {
    "recovery": "Återhämtning",
    "endurance": "Distans",
    "sweetspot": "Tempo och sweet spot",
    "threshold": "Tröskel",
    "vo2max": "VO2max",
    "ftptest": "FTP-test",
    "climbing": "Klättring",
    "sprint": "Sprint",
}

var id := ""
var name := ""
var description := ""
var category := ""
var custom := false
var plan_id := ""             # set for a session in a training plan (core/plan_library.gd)
var plan_index := -1
var segments: Array[Dictionary] = []
var _ftp := 200.0             # what fixed-watt steps are measured against (set_ftp)
var duration := 0.0
var _stats_cache := {}
var raw := {}                 # the JSON it was made from (the workout editor copies it)


func parse(data: Dictionary, workout_id := "") -> bool:
    id = workout_id
    raw = data.duplicate(true)
    name = str(data.get("name", "Namnlöst pass"))
    description = str(data.get("description", ""))
    category = str(data.get("category", ""))
    custom = bool(data.get("custom", false))
    segments.clear()
    _stats_cache.clear()
    var t := 0.0
    var interval_no := 0
    for step in data.get("steps", []):
        match str(step.get("type", "")):
            "steady":
                t = _add(t, step, float(step.get("power", 0.0)), float(step.get("power", 0.0)), false, 0)
            "ramp":
                t = _add(t, step, float(step.get("from", 0.0)), float(step.get("to", 0.0)), false, 0)
            "free":
                t = _add(t, step, 0.0, 0.0, true, 0)
            "intervals":
                for i in int(step.get("repeat", 1)):
                    interval_no += 1
                    var on: Dictionary = step["on"]
                    t = _add(t, on, float(on.get("power", 0.0)), float(on.get("power", 0.0)), false, interval_no)
                    if step.has("off"):
                        var off: Dictionary = step["off"]
                        t = _add(t, off, float(off.get("power", 0.0)), float(off.get("power", 0.0)), false, 0)
            var other:
                push_warning("Okänd stegtyp '%s' i passet %s" % [other, name])
    duration = t
    _default_labels()
    return not segments.is_empty()


func _add(t: float, step: Dictionary, from: float, to: float, is_free: bool, interval: int) -> float:
    var length := float(step.get("duration", 0))
    if length <= 0.0:
        return t
    segments.append({
        "start": t,
        "duration": length,
        "from": from,
        "to": to,
        "free": is_free,
        "cadence": int(step.get("cadence", 0)),
        "label": str(step.get("label", "")),
        "interval": interval,
    })
    if step.has("watts") or step.has("from_watts"):
        var seg := segments[-1]
        seg["from_w"] = float(step.get("from_watts", step.get("watts", 0.0)))
        seg["to_w"] = float(step.get("to_watts", step.get("watts", 0.0)))
        seg["from"] = seg["from_w"] / _ftp
        seg["to"] = seg["to_w"] / _ftp
    return t + length


## Measure fixed-watt steps against this FTP (the player sets the rider's FTP before a ride).
func set_ftp(ftp_watts: float) -> void:
    if ftp_watts <= 0.0 or is_equal_approx(ftp_watts, _ftp):
        return
    _ftp = ftp_watts
    for seg in segments:
        if seg.has("from_w"):
            seg["from"] = seg["from_w"] / _ftp
            seg["to"] = seg["to_w"] / _ftp
    _stats_cache.clear()


func _default_labels() -> void:
    for i in segments.size():
        var s := segments[i]
        if s["label"] != "":
            continue
        if s["free"]:
            s["label"] = "Fritt"
        elif s["to"] > s["from"] + 0.01:
            s["label"] = "Uppvärmning" if i == 0 else "Stegring"
        elif s["to"] < s["from"] - 0.01:
            s["label"] = "Nedvarvning" if i == segments.size() - 1 else "Avtrappning"
        else:
            s["label"] = Zones.NAMES[Zones.zone(s["from"])]


## Index of the segment running at time t (start <= t < end), or -1 outside the workout.
func segment_index_at(t: float) -> int:
    if t < 0.0 or t >= duration:
        return -1
    for i in segments.size():
        var s := segments[i]
        if t < s["start"] + s["duration"]:
            return i
    return -1


## Target as a fraction of FTP at time t; -1 for free segments or outside the workout.
func target_at(t: float) -> float:
    var i := segment_index_at(t)
    if i < 0:
        return -1.0
    var s := segments[i]
    if s["free"]:
        return -1.0
    var f := clampf((t - s["start"]) / s["duration"], 0.0, 1.0)
    return lerpf(s["from"], s["to"], f)


## Highest target fraction in the workout.
func peak() -> float:
    var p := 0.0
    for s in segments:
        p = maxf(p, maxf(s["from"], s["to"]))
    return p


## Planned load: seconds per zone, normalized intensity, TSS and effort 1–5.
## Free segments count as 55 % of FTP.
func stats() -> Dictionary:
    if not _stats_cache.is_empty():
        return _stats_cache
    var series := PackedFloat32Array()
    var zone_seconds := [0, 0, 0, 0, 0, 0]
    for sec in int(ceil(duration)):
        var p := target_at(sec + 0.5)
        if p < 0.0:
            p = 0.55
        series.append(p)
        zone_seconds[Zones.zone(p)] += 1
    var intensity := Metrics.normalized(series)
    _stats_cache = {
        "zone_seconds": zone_seconds,
        "intensity_factor": intensity,
        "tss": Metrics.tss(duration, intensity, 1.0),
        "effort": Metrics.effort(intensity),
    }
    return _stats_cache


## Collection by length: "30", "30-60", "60-90" or "90+".
func length_group() -> String:
    var minutes := duration / 60.0
    if minutes <= 30.5:
        return "30"
    if minutes <= 60.5:
        return "30-60"
    if minutes <= 90.5:
        return "60-90"
    return "90+"
