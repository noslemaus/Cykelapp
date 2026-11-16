extends Node
## Your progress, autoloaded as `Progress`: XP and level, personal records on the power curve and an
## FTP that follows them, segment records, the best lap in each world (it rides along as the ghost),
## what is unlocked (bikes, jerseys, the tank's upgrades) and what you ride with. Stored in
## user://progress.json.
## Rides on the pretend trainer show everything live (segment times, the ghost, the summary) but are
## never saved: a pretend record is no record. Developer runs never read or write the file.

const LapTracker = preload("res://core/lap_tracker.gd")
const PowerCurve = preload("res://core/power_curve.gd")

const PATH := "user://progress.json"
const Catalog = preload("res://core/catalog.gd")
const SafeFile = preload("res://core/safe_file.gd")
const Routes = preload("res://core/routes.gd")
const MAX_LEVEL := Catalog.MAX_LEVEL
const MAX_RIDES := 500
const BIKES := Catalog.BIKES
const BIKE_ORDER := Catalog.BIKE_ORDER
const JERSEYS := Catalog.JERSEYS
const JERSEY_ORDER := Catalog.JERSEY_ORDER
const UPGRADES := Catalog.UPGRADES
const UPGRADE_ORDER := Catalog.UPGRADE_ORDER
const WORLD_NAMES := Catalog.WORLD_NAMES
const XP_WORKOUT := Catalog.XP_WORKOUT
const XP_SEGMENT := Catalog.XP_SEGMENT
const XP_SEGMENT_PR := Catalog.XP_SEGMENT_PR
const XP_LAP := Catalog.XP_LAP
const XP_LAP_PR := Catalog.XP_LAP_PR
const XP_POWER_PB := Catalog.XP_POWER_PB
const XP_FTP := Catalog.XP_FTP

var data := {}
var tracker: LapTracker = null
var _battle := 0          # battle points this ride, banked when a battle ends


func _ready() -> void:
    data = _blank()
    if not Settings.dev_run:
        _load()


func _blank() -> Dictionary:
    return {"xp": 0, "rides": [], "bests": {}, "segments": {}, "laps": {}, "lap_counts": {},
        "kinds": {"climb": 0, "sprint": 0}, "ghosts": 0, "battle_points": 0,
        "bike": "landsvag", "jersey": "sverige", "routes": {}}


## Read progress.json, or its backup when the file is missing or broken (see core/safe_file.gd).
func _load() -> void:
    var text := SafeFile.read_text(PATH, SafeFile.is_json_object)
    if text == "":
        if FileAccess.file_exists(PATH):
            # Neither the file nor its backup reads: move the broken file aside (it can be mended by
            # hand) instead of saving an empty history over it, and start afresh.
            var aside := "user://progress-trasig-%d.json" % int(Time.get_unix_time_from_system())
            DirAccess.rename_absolute(ProjectSettings.globalize_path(PATH), ProjectSettings.globalize_path(aside))
            push_error("progress.json gick inte att läsa och ligger nu som %s" % aside.get_file())
        return
    var parsed = JSON.parse_string(text)
    for key in parsed:
        data[key] = parsed[key]


func save() -> void:
    if Settings.dev_run or not Settings.persist:
        return
    SafeFile.write_text(PATH, JSON.stringify(data))


# --- Level ------------------------------------------------------------------------------------

static func xp_for(level: int) -> int:
    return Catalog.xp_for(level)


static func level_for(total: int) -> int:
    return Catalog.level_for(total)


func xp() -> int:
    return int(data["xp"])


func level() -> int:
    return level_for(xp())


## XP into the current level and the XP the level spans.
func level_progress() -> Vector2i:
    var lv := level()
    if lv >= MAX_LEVEL:
        return Vector2i(1, 1)
    return Vector2i(xp() - xp_for(lv), xp_for(lv + 1) - xp_for(lv))


# --- Equipment and unlocks ----------------------------------------------------------------------

func bike_id() -> String:
    var id := str(data.get("bike", "landsvag"))
    return id if BIKES.has(id) and unlocked("bike", id) else "landsvag"


func jersey_id() -> String:
    var id := str(data.get("jersey", "sverige"))
    return id if JERSEYS.has(id) and unlocked("jersey", id) else "sverige"


func bike() -> Dictionary:
    return BIKES[bike_id()]


func jersey() -> Dictionary:
    return JERSEYS[jersey_id()]


func set_bike(id: String) -> void:
    if BIKES.has(id) and unlocked("bike", id):
        data["bike"] = id
        save()


func set_jersey(id: String) -> void:
    if JERSEYS.has(id) and unlocked("jersey", id):
        data["jersey"] = id
        save()


## The colours the rider wears and rides: jersey main, accent and frame.
func look() -> Dictionary:
    return {"jersey": jersey_id(), "main": Color(jersey()["main"]), "accent": Color(jersey()["accent"]),
        "bike": bike_id(), "frame": Color(bike()["frame"])}


func unlocked(kind: String, id: String) -> bool:
    match kind:
        "bike":
            return level() >= int(BIKES[id]["level"])
        "upgrade":
            return battle_points() >= int(UPGRADES[id]["points"])
        "jersey":
            var need: Dictionary = JERSEYS[id]["unlock"]
            if need.has("level"):
                return level() >= int(need["level"])
            if need.has("climb"):
                return int(data["kinds"].get("climb", 0)) >= int(need["climb"])
            if need.has("sprint"):
                return int(data["kinds"].get("sprint", 0)) >= int(need["sprint"])
            if need.has("lap"):
                return int(data["lap_counts"].get(need["lap"], 0)) > 0
            if need.has("ghost"):
                return int(data.get("ghosts", 0)) >= int(need["ghost"])
    return false


## What it takes, for a locked card: "Nivå 6", "10 klättersegment (3 av 10)" …
func requirement(kind: String, id: String) -> String:
    match kind:
        "bike":
            return tr("Nivå %d") % int(BIKES[id]["level"])
        "upgrade":
            return tr("%d stridspoäng (du har %d)") % [int(UPGRADES[id]["points"]), battle_points()]
        "jersey":
            var need: Dictionary = JERSEYS[id]["unlock"]
            if need.has("level"):
                return tr("Nivå %d") % int(need["level"])
            if need.has("climb"):
                return tr("Kör %d klättersegment (%d av %d)") % [need["climb"], int(data["kinds"].get("climb", 0)), need["climb"]]
            if need.has("sprint"):
                return tr("Kör %d spurter (%d av %d)") % [need["sprint"], int(data["kinds"].get("sprint", 0)), need["sprint"]]
            if need.has("lap"):
                return tr("Ett helt varv i %s") % tr(WORLD_NAMES.get(need["lap"], need["lap"]))
            if need.has("ghost"):
                return tr("Slå ditt eget spöke")
    return ""


func upgrade_on(id: String) -> bool:
    return unlocked("upgrade", id)


func battle_points() -> int:
    return int(data.get("battle_points", 0))


func _unlocked_list() -> Array:
    var list := []
    for id in BIKE_ORDER:
        if unlocked("bike", id):
            list.append("bike:" + id)
    for id in JERSEY_ORDER:
        if unlocked("jersey", id):
            list.append("jersey:" + id)
    for id in UPGRADE_ORDER:
        if unlocked("upgrade", id):
            list.append("upgrade:" + id)
    return list


static func unlock_name(key: String) -> String:
    var kind := key.get_slice(":", 0)
    var id := key.get_slice(":", 1)
    match kind:
        "bike":
            return str(TranslationServer.translate("Cykel: ")) + str(TranslationServer.translate(BIKES[id]["name"]))
        "jersey":
            return str(TranslationServer.translate("Tröja: ")) + str(TranslationServer.translate(JERSEYS[id]["name"]))
        "upgrade":
            return str(TranslationServer.translate("Stridsvagnen: ")) + str(TranslationServer.translate(UPGRADES[id]["name"]))
    return key


# --- Records ----------------------------------------------------------------------------------

func best_power(duration: int) -> float:
    var entry = data["bests"].get(str(duration))
    return float(entry["w"]) if entry is Dictionary else 0.0


## The best for each duration over the last `days` days (0 = all time), from the ride history.
func curve_since(days: int) -> Dictionary:
    var since := Time.get_unix_time_from_system() - days * 86400.0 if days > 0 else 0.0
    var result := {}
    for ride in data["rides"]:
        if float(ride.get("date", 0.0)) < since or ride.get("pretend", false):
            continue
        var curve: Dictionary = ride.get("curve", {})
        for key in curve:
            result[key] = maxf(float(result.get(key, 0.0)), float(curve[key]))
    return result


## The segment's best time: saved, or ridden earlier in this ride (0 = never ridden).
func segment_best(world: String, id: String) -> float:
    var best := 0.0
    var entry = data["segments"].get(world + "/" + id)
    if entry is Dictionary:
        best = float(entry["time"])
    if tracker:
        for r in tracker.results:
            if r["world"] == world and r["id"] == id and (best <= 0.0 or float(r["time"]) < best):
                best = float(r["time"])
    return best


## How a route has gone: {"count", "best" (seconds)} or {} when never ridden to the end.
func route_record(world: String, id: String) -> Dictionary:
    var entry = data.get("routes", {}).get(world + "/" + id)
    return entry if entry is Dictionary else {}


func segment_record(world: String, id: String) -> Dictionary:
    var entry = data["segments"].get(world + "/" + id)
    return entry if entry is Dictionary else {}


## The lap the ghost rides: the best saved, or a faster one from earlier in this ride.
## {"time", "splits": PackedFloat32Array} or {} when there is none yet.
## A saved lap only counts while the lap is the same length: when a world's route is rebuilt, the old
## ghost would ride somewhere else, so it is left out (`lap_length` 0 = do not check).
func ghost_lap(world: String, lap_length := 0.0) -> Dictionary:
    var best := {}
    var entry = data["laps"].get(world)
    if entry is Dictionary and entry.has("splits"):
        var splits := PackedFloat32Array(entry["splits"])
        if lap_length <= 0.0 or absf((splits.size() - 1) * LapTracker.SPLIT - lap_length) < 20.0:
            best = {"time": float(entry["time"]), "splits": splits}
    if tracker:
        for lap in tracker.laps:
            if lap["world"] == world and (best.is_empty() or float(lap["time"]) < float(best["time"])):
                best = {"time": float(lap["time"]), "splits": lap["splits"]}
    return best


# --- A ride -----------------------------------------------------------------------------------

func begin_ride() -> void:
    tracker = LapTracker.new()
    _battle = 0


## Points from a battle that just ended (the vehicle left, the ride over, a teleport).
func bank_battle(points: int) -> void:
    _battle += maxi(points, 0)


## The ride is over: work out records, XP and unlocks, and save them when the ride counts.
## On the pretend trainer both `counts` and `real` are false: nothing is saved, and its made-up
## watts are not reported as records (power bests, segment and lap times, the ghost) or a new FTP.
## Returns the report the summary screen shows.
func finish_ride(summary: Dictionary, seconds: PackedFloat32Array, counts: bool, real := true) -> Dictionary:
    var report := {"counts": counts, "real": real, "xp": 0, "lines": [], "level_before": level(), "unlocks": [],
        "bests": [], "segments": [], "laps": [], "ftp": [], "battle": _battle, "curve": {}}
    var before := _unlocked_list()
    var had_rides: bool = data["rides"].any(func(r): return not r.get("pretend", false))
    var gained := 0
    var lines: Array = []

    var kj := roundi(float(summary.get("kj", 0.0)))
    if kj > 0:
        gained += kj
        lines.append([tr("%d kJ arbete") % kj, kj])
    if summary.get("completed", false):
        gained += XP_WORKOUT
        lines.append([tr("Hela passet genomfört"), XP_WORKOUT])

    # Power curve and personal records.
    var curve := PowerCurve.of(seconds)
    report["curve"] = curve
    for d in PowerCurve.DURATIONS:
        var key := str(d)
        if not curve.has(key):
            continue
        var old := best_power(d)
        var now := float(curve[key])
        if real and now > old + 0.5:
            if d in PowerCurve.KEY:
                report["bests"].append({"duration": d, "watts": now, "old": old})
                if had_rides and old > 0.0:
                    gained += XP_POWER_PB
                    lines.append([tr("Personbästa %s: %d W") % [PowerCurve.label(d), roundi(now)], XP_POWER_PB])
            if counts:
                data["bests"][key] = {"w": now, "date": summary.get("started", 0.0)}

    # Segments.
    var seen := {}
    if tracker:
        for r in tracker.results:
            var key: String = r["world"] + "/" + r["id"]
            var entry = data["segments"].get(key)
            var stored: float = float(entry["time"]) if entry is Dictionary else 0.0
            var old := stored
            if seen.has(key) and (old <= 0.0 or float(seen[key]) < old):
                old = float(seen[key])
            var time: float = r["time"]
            var pr := real and (old <= 0.0 or time < old)
            gained += XP_SEGMENT
            if pr and old > 0.0:
                gained += XP_SEGMENT_PR
            report["segments"].append({"name": r["name"], "kind": r["kind"], "time": time, "old": old, "pr": pr})
            seen[key] = time if not seen.has(key) else minf(float(seen[key]), time)
            if counts:
                var count := (int(entry["count"]) if entry is Dictionary else 0) + 1
                var faster := real and (stored <= 0.0 or time < stored)
                data["segments"][key] = {"time": time if faster else stored, "count": count,
                    "date": summary.get("started", 0.0) if faster else entry["date"]}
                data["kinds"][r["kind"]] = int(data["kinds"].get(r["kind"], 0)) + 1
        if not tracker.results.is_empty():
            lines.append([tr("%d segment") % tracker.results.size(), XP_SEGMENT * tracker.results.size()])
        var seg_prs := 0
        for s in report["segments"]:
            if s["pr"] and float(s["old"]) > 0.0:
                seg_prs += 1
        if seg_prs > 0:
            lines.append([tr("%d segmentrekord") % seg_prs, XP_SEGMENT_PR * seg_prs])

        # Laps and the ghost.
        for lap in tracker.laps:
            var world: String = lap["world"]
            var entry = data["laps"].get(world)
            var old: float = float(entry["time"]) if entry is Dictionary else 0.0
            for earlier in report["laps"]:
                if earlier["world"] == world and (old <= 0.0 or float(earlier["time"]) < old):
                    old = float(earlier["time"])
            var time: float = lap["time"]
            var pr := real and (old <= 0.0 or time < old)
            gained += XP_LAP
            lines.append([tr("Varv i %s") % tr(WORLD_NAMES.get(world, world)), XP_LAP])
            if pr and old > 0.0:
                gained += XP_LAP_PR
                lines.append([tr("Du slog ditt spöke"), XP_LAP_PR])
            report["laps"].append({"world": world, "time": time, "old": old, "pr": pr})
            if counts:
                data["lap_counts"][world] = int(data["lap_counts"].get(world, 0)) + 1
                if pr:
                    data["laps"][world] = {"time": time, "date": summary.get("started", 0.0), "splits": Array(lap["splits"])}
                    if old > 0.0:
                        data["ghosts"] = int(data.get("ghosts", 0)) + 1

    # FTP follows the best 20 minutes (it only goes up by itself).
    var estimate := PowerCurve.ftp_from(curve)
    if real and Settings.auto_ftp and estimate > Settings.ftp:
        report["ftp"] = [Settings.ftp, estimate]
        gained += XP_FTP
        lines.append([tr("Ny FTP: %d W") % estimate, XP_FTP])
        if counts:
            Settings.ftp = estimate
            Settings.save()

    # A route ridden to the end (core/routes.gd): XP by its length, and its best time.
    var route: Dictionary = Ride.route
    if Ride.route_state == "klar" and not route.is_empty():
        var key: String = str(route["world"]) + "/" + str(route["id"])
        if not data.has("routes"):
            data["routes"] = {}
        var entry = data["routes"].get(key)
        var old: float = float(entry["best"]) if entry is Dictionary else 0.0
        var pr := real and (old <= 0.0 or Ride.route_time < old)
        var route_xp := Routes.xp_for(float(route["length_m"]))
        gained += route_xp
        lines.append([tr("Rutten %s") % tr(route["name"]), route_xp])
        report["route"] = {"name": route["name"], "time": Ride.route_time, "old": old, "pr": pr}
        if counts:
            data["routes"][key] = {"count": (int(entry["count"]) if entry is Dictionary else 0) + 1,
                "best": Ride.route_time if pr else old}

    if _battle > 0:
        var battle_xp := _battle / 10
        gained += battle_xp
        lines.append([tr("%d stridspoäng") % _battle, battle_xp])
        if counts:
            data["battle_points"] = battle_points() + _battle

    report["xp"] = gained
    report["lines"] = lines
    if counts:
        data["xp"] = xp() + gained
    # Every ride goes into the history, also on the pretend trainer (marked, and left out of records,
    # form and XP), so you can always see what you have ridden and how it went.
    if float(summary.get("moving_time", 0.0)) >= 60.0:
        data["rides"].append(_history_entry(summary, seconds, curve, report, gained if counts else 0, not real))
        while data["rides"].size() > MAX_RIDES:
            data["rides"].pop_front()
    if counts:
        for key in _unlocked_list():
            if not key in before:
                report["unlocks"].append(key)
        save()
    # A session in a training plan counts as done when it was ridden (almost) to the end.
    var w = Ride.workout
    if w != null and str(w.get("plan_id")) != "" and (summary.get("completed", false)
            or float(summary.get("moving_time", 0.0)) >= 0.75 * float(w.duration)):
        var done := plan_done(w.plan_id)
        if not w.plan_index in done and counts:
            done.append(w.plan_index)
            data["plans"][w.plan_id] = {"done": done}
            save()
        report["plan"] = [w.plan_id, w.plan_index + 1, done.size()]
    report["level_after"] = level() if counts else level_for(xp() + gained)
    if not counts:
        save()          # the history entry of a pretend ride
    return report


## One ride in the history: what was ridden, the numbers, the power every 10 s for a graph, the
## segments and laps, the XP it gave, the FIT file and (later) its Strava link.
func _history_entry(summary: Dictionary, seconds: PackedFloat32Array, curve: Dictionary, report: Dictionary,
        xp_gained: int, pretend: bool) -> Dictionary:
    var watts := []
    var k := 0
    while k < seconds.size():
        var sum := 0.0
        var n := 0
        for j in range(k, mini(k + 10, seconds.size())):
            sum += seconds[j]
            n += 1
        watts.append(roundi(sum / maxi(n, 1)))
        k += 10
    var w = Ride.workout
    var segs := []
    for s in report.get("segments", []):
        segs.append({"name": s["name"], "time": s["time"], "pr": s["pr"]})
    var stars: Vector2i = summary.get("stars", Vector2i.ZERO)
    return {
        "id": int(summary.get("started", 0.0)), "date": summary.get("started", 0.0),
        "world": summary.get("world", ""), "name": summary.get("name", ""),
        "workout": w.id if w != null else "", "category": w.category if w != null else "",
        "plan": [w.plan_id, w.plan_index] if w != null and str(w.get("plan_id")) != "" else null,
        "seconds": summary.get("moving_time", 0.0), "km": float(summary.get("distance", 0.0)) / 1000.0,
        "elev": summary.get("elevation_gain", 0.0), "kj": roundi(float(summary.get("kj", 0.0))),
        "tss": summary.get("tss", 0.0), "np": summary.get("np", 0.0), "if": summary.get("if", 0.0),
        "avg_w": summary.get("avg_power", 0.0), "max_w": summary.get("max_power", 0),
        "avg_hr": summary.get("avg_hr", 0.0), "max_hr": summary.get("max_hr", 0),
        "avg_cad": summary.get("avg_cadence", 0.0), "completed": summary.get("completed", false),
        "stars": [stars.x, stars.y], "xp": xp_gained, "pretend": pretend,
        "fit": Ride.fit_path.get_file() if Ride.fit_path != "" else "", "strava": "",
        "curve": curve, "watts": watts, "segments": segs,
        "laps": report.get("laps", []).map(func(l): return {"world": l["world"], "time": l["time"], "pr": l["pr"]}),
        "bests": report.get("bests", []).map(func(b): return [b["duration"], roundi(b["watts"])]),
    }


## Uploaded to Strava: keep the link with the ride.
func mark_strava(started: float, url: String) -> void:
    for r in data["rides"]:
        if int(r.get("id", 0)) == int(started):
            r["strava"] = url
            save()
            return


## How a workout has gone: times ridden, the last date, and whether it was ever ridden to the end.
func workout_record(workout_id: String) -> Dictionary:
    var out := {"count": 0, "last": 0.0, "completed": false}
    if workout_id == "":
        return out
    for r in data["rides"]:
        if r.get("workout", "") == workout_id:
            out["count"] += 1
            out["last"] = maxf(out["last"], float(r.get("date", 0.0)))
            out["completed"] = out["completed"] or bool(r.get("completed", false))
    return out


## Totals for a week (0 = this week, 1 = last week …), weeks starting on Monday, local time.
func week_totals(weeks_ago := 0) -> Dictionary:
    var start := week_start(Time.get_unix_time_from_system()) - weeks_ago * 7 * 86400.0
    var out := {"rides": 0, "seconds": 0.0, "km": 0.0, "tss": 0.0, "kj": 0, "elev": 0.0}
    for r in data["rides"]:
        var t := float(r.get("date", 0.0))
        if t >= start and t < start + 7 * 86400.0:
            out["rides"] += 1
            out["seconds"] += float(r.get("seconds", 0.0))
            out["km"] += float(r.get("km", 0.0))
            out["tss"] += float(r.get("tss", 0.0))
            out["kj"] += int(r.get("kj", 0))
            out["elev"] += float(r.get("elev", 0.0))
    return out


## Midnight on the Monday of the week that `t` falls in (local time).
static func week_start(t: float) -> float:
    var bias := float(Time.get_time_zone_from_system().get("bias", 0)) * 60.0
    var local := t + bias
    var day := floorf(local / 86400.0)
    var weekday := int(day + 3) % 7          # 1970-01-01 was a Thursday; 0 = Monday
    return (day - weekday) * 86400.0 - bias


## Weeks in a row with at least one ride, counting back from this week (or last, if this week is empty).
func streak_weeks() -> int:
    var n := 0
    var k := 0 if week_totals(0)["rides"] > 0 else 1
    while week_totals(k)["rides"] > 0:
        n += 1
        k += 1
    return n


func lifetime() -> Dictionary:
    var out := {"rides": 0, "seconds": 0.0, "km": 0.0, "elev": 0.0, "kj": 0}
    for r in data["rides"]:
        out["rides"] += 1
        out["seconds"] += float(r.get("seconds", 0.0))
        out["km"] += float(r.get("km", 0.0))
        out["elev"] += float(r.get("elev", 0.0))
        out["kj"] += int(r.get("kj", 0))
    return out


## Fitness (CTL, 42-day average of daily TSS), fatigue (ATL, 7 days) and form (TSB = CTL − ATL), one
## value per day for the last `days` days, the way Strava and TrainingPeaks show them. Pretend rides
## are left out.
func fitness(days := 90) -> Dictionary:
    var today := floorf(Time.get_unix_time_from_system() / 86400.0)
    var first := today - days - 120          # warm the averages up first
    var daily := {}
    for r in data["rides"]:
        if r.get("pretend", false):
            continue
        var d := floorf(float(r.get("date", 0.0)) / 86400.0)
        daily[d] = float(daily.get(d, 0.0)) + float(r.get("tss", 0.0))
    var ctl := 0.0
    var atl := 0.0
    var out := {"ctl": PackedFloat32Array(), "atl": PackedFloat32Array(), "tsb": PackedFloat32Array()}
    var d := first
    while d <= today:
        var tss: float = daily.get(d, 0.0)
        ctl += (tss - ctl) / 42.0
        atl += (tss - atl) / 7.0
        if d > today - days:
            out["ctl"].append(ctl)
            out["atl"].append(atl)
            out["tsb"].append(ctl - atl)
        d += 1.0
    return out


## The plan you are in the middle of: the latest ridden plan session's plan, if it has sessions left.
func active_plan_id(plans: Array) -> String:
    for i in range(data["rides"].size() - 1, -1, -1):
        var p = data["rides"][i].get("plan")
        if p is Array and p.size() == 2:
            for plan in plans:
                if plan["id"] == p[0] and plan_done(p[0]).size() < plan["sessions"].size():
                    return p[0]
            return ""
    return ""


## The sessions of a plan that are done (indices from 0).
func plan_done(plan_id: String) -> Array:
    if not data.has("plans"):
        data["plans"] = {}
    var entry = data["plans"].get(plan_id)
    return Array(entry["done"]) if entry is Dictionary and entry.has("done") else []


## Developer screenshots of the garage and the summary: a rider some weeks in.
func load_demo() -> void:
    data = _blank()
    data["xp"] = 9200
    data["kinds"] = {"climb": 7, "sprint": 11}
    data["lap_counts"] = {"skargarden": 6, "egypten": 2}
    data["ghosts"] = 2
    data["battle_points"] = 1450
    data["bike"] = "grus"
    data["jersey"] = "gron"
    var now := Time.get_unix_time_from_system()
    var base := {"5": 812.0, "15": 690.0, "30": 560.0, "60": 405.0, "120": 318.0, "300": 262.0,
        "600": 236.0, "1200": 221.0, "1800": 209.0, "3600": 192.0}
    for k in base:
        data["bests"][k] = {"w": base[k], "date": now - 86400.0 * 12.0}
    var names := ["Fri cykling", "Kanelbullen", "Fyren på Vinga", "Runt Siljan", "Tor", "Upp på Kinnekulle", "Söndagsrullen"]
    var worlds := ["Skärgården", "Egypten", "Japan"]
    for i in 16:
        var c := {}
        for k in base:
            c[k] = float(base[k]) * (0.82 + 0.012 * i)
        var secs := 2400.0 + 600.0 * (i % 4)
        var avg := 150.0 + 4.0 * i
        var watts := []
        for t in int(secs / 10.0):
            watts.append(roundi(avg * (0.75 + 0.5 * absf(sin(t * 0.07))) + (120.0 if t % 37 < 2 else 0.0)))
        data["rides"].append({"id": int(now - 86400.0 * (44 - i * 3)), "date": now - 86400.0 * (44 - i * 3) + 3600.0 * 18,
            "world": worlds[i % 3], "name": names[i % names.size()], "workout": "",
            "plan": ["ur-idet", i - 10] if i >= 10 and i < 14 else null,
            "seconds": secs, "km": secs / 3600.0 * 31.0, "elev": 80.0 + 10.0 * (i % 5), "kj": roundi(avg * secs / 1000.0),
            "tss": secs / 3600.0 * 70.0, "np": avg + 12.0, "if": (avg + 12.0) / 200.0, "avg_w": avg, "max_w": 480 + i * 5,
            "avg_hr": 128.0 + i, "max_hr": 165, "avg_cad": 88.0, "completed": i % 3 != 0, "stars": [2, 3] if i % 3 == 1 else [0, 0],
            "xp": roundi(avg * secs / 1000.0) + 60, "pretend": i == 15, "fit": "", "strava": "https://www.strava.com/activities/1" if i % 4 == 0 else "",
            "curve": c, "watts": watts, "segments": [{"name": "Fyrberget", "time": 74.0 + i, "pr": i == 12}],
            "laps": [], "bests": [[300, 262]] if i == 12 else []})
    data["plans"] = {"ur-idet": {"done": [0, 1, 2, 3]}}
    var splits := []
    for k in 601:
        splits.append(k * 10.0 / 6.6)
    data["laps"] = {"skargarden": {"time": 6004.0 / 6.6, "date": now - 86400.0 * 5.0, "splits": splits}}
    data["segments"] = {
        "skargarden/fyrberget": {"time": 74.2, "date": now - 86400.0 * 3.0, "count": 6},
        "skargarden/kyrkbacken": {"time": 61.8, "date": now - 86400.0 * 9.0, "count": 5},
        "skargarden/kyrkbyspurten": {"time": 15.6, "date": now - 86400.0 * 3.0, "count": 6},
        "egypten/giza": {"time": 118.0, "date": now - 86400.0 * 20.0, "count": 2},
    }
