extends Node
## The ride engine ("motorn"), autoloaded as `Ride`. Owns the data source (pretend trainer or the
## Bluetooth bridge), the bike physics, the running workout, trainer commands and the recording.
## Screens only read from here and call the small public API below; the 3D world will later
## set `grade` from the road and read `distance`/`speed` the same way.

signal source_changed

const TrainerSim = preload("res://core/trainer_sim.gd")
const BridgeClient = preload("res://core/bridge_client.gd")
const BikePhysics = preload("res://core/physics.gd")
const WorkoutPlayer = preload("res://core/workout_player.gd")
const Metrics = preload("res://core/metrics.gd")
const Zones = preload("res://core/zones.gd")
# The most ERG may ask of the trainer. Some workouts ramp to 300–500 % of FTP for
# a few seconds (2 000 W and more); the KICKR CORE tops out near 1 800 W and an ERG target far above
# what the legs give at low cadence locks the flywheel. The screen still shows the workout's target.
const ERG_MAX_WATTS := 1500
const ERG_MAX_FTP := 3.0
const FitWriter = preload("res://core/fit_writer.gd")
const SafeFile = preload("res://core/safe_file.gd")

enum State { IDLE, RIDING, FINISHED }

## The trainer needs a second or so to change its resistance (and gets at most one command a
## second), so in a world it is sent the grade this far ahead.
const GRADE_LOOKAHEAD := 1.5
## Virtual gears: 24 ratios from a climbing gear (0.75) to a sprint gear (5.49), on top
## of the real gear on the trainer. In the neutral gear the trainer feels exactly like the road. A
## gear k times heavier makes the trainer resist as if the bike went k times faster for the same
## flywheel speed: FTMS SIM then gets k × the grade, k × the rolling resistance and k³ × the air
## drag (the power for k times the speed, felt at the flywheel's speed).
const GEAR_COUNT := 24
const GEAR_NEUTRAL := 15
const TRAINER_CRR := 0.004      # what SIM tells the trainer about the road (FTMS defaults)
const TRAINER_CW := 0.51        # kg/m
const GUARD_LOW_RPM := 55.0
const GUARD_OK_RPM := 70.0

var state := State.IDLE
var sim: TrainerSim = null
## Cykelbrygga: the real trainer (Settings.source "trainer") and/or the Zwift Click buttons.
var bridge: BridgeClient = null
var physics := BikePhysics.new()
var player: WorkoutPlayer = null
var workout = null

## Workout: ERG on/off. Free ride: true = hold `free_watts` (ERG), false = ride `grade` (SIM).
var erg := true
var free_watts := 150
var grade := 0.0
## The road's grade a moment ahead (GRADE_LOOKAHEAD seconds at the current speed), set by the world
## HUD: what the trainer is sent in SIM, so its resistance has changed by the time the bike gets there.
var grade_ahead := 0.0
var gear := GEAR_NEUTRAL   # virtual gear in SIM, 1–24 (see gear_factor)
## Drafting behind a pacer (world/pacers.gd): the share of the air drag taken away, 0–0.35.
var draft := 0.0
## The route ridden (core/routes.gd, with "length_m" and "world"), {} on the gym screen. Its state:
## "" while riding it, "klar" once its length is ridden (route_time = the moving time then), or
## "avbruten" when you left the lap.
var route := {}
var route_state := ""
var route_time := -1.0
var manual := false    # "eget motstånd": the rider's own resistance level instead of ERG or the road
var manual_level := 3  # 0–10: the trainer feels like a steady climb of that many percent
var paused := false
var guard_active := false

# Live values.
var power := 0.0
var cadence := 0.0
var hr := 0.0
var speed := 0.0          # m/s
var distance := 0.0       # m
var altitude := 0.0       # m
var elevation_gain := 0.0
var moving_time := 0.0
var kj := 0.0
var max_power := 0
var max_hr := 0
var np_live := 0.0
var power_history := PackedFloat32Array()   # one value per recorded second

# Recording.
var samples: Array[Dictionary] = []
var lap_starts: Array[int] = [0]
var started_unix := 0.0
var summary := {}
var fit_path := ""
var fit_folder := "user://pass"
## A ride in progress is saved every minute, so a crash or a power cut does not lose it: the next
## start offers to save it (main.gd). Developer runs use user://dev-pagaende-tur.json.
const AUTOSAVE_EVERY := 60
var autosave_path := "user://pagaende-tur.json"
var _restored_real = null       # a restored ride keeps whether it was on the real trainer
var world_name := ""             # set by main.gd when riding in a 3D world   # developer runs switch this to user://dev-pass
## Under the wheels, set by the world HUD: asfalt, grus or terrang (rolling resistance per bike).
var surface := "asfalt"
## What the ride gave in progress (records, XP, unlocks), from Progress.finish_ride.
var progress_report := {}
var _bike := {}

var _clock := 0.0
var _second_accum := 0.0
var _window: Array = []        # [[clock, power], ...] for the 3 s average
var _power_seconds := 0.0
var _power_sum := 0.0
var _guard_low := 0.0
var _guard_ok := 0.0
var _command_timer := 0.0
var _last_command := ""
var _last_segment := -1


func _ready() -> void:
    Settings.changed.connect(apply_settings)
    apply_settings()


## Tell the bridge to release the trainer and quit. Called by main.gd right before the app quits.
func shutdown() -> void:
    if bridge:
        bridge.stop()
        bridge = null


func _notification(what: int) -> void:
    if what == NOTIFICATION_PREDELETE:
        shutdown()


## Switch between the pretend trainer and the real one when the setting changes, and run
## Cykelbrygga when it is needed: for the trainer, or for the Zwift Clicks alone.
func apply_settings() -> void:
    physics.rider_kg = Settings.weight_kg
    apply_bike()
    var want_trainer := Settings.source == "trainer" and not Settings.dev_run
    var want_bridge := want_trainer or (Settings.click_enabled and Settings.hardware_ok())
    var changed := false
    if want_bridge and bridge == null:
        bridge = BridgeClient.new()
        bridge.start()
        changed = true
    elif not want_bridge and bridge:
        bridge.stop()
        bridge = null
        changed = true
    if bridge:
        bridge.controllers_only = not want_trainer
        bridge.wanted_trainer = Settings.trainer_id
        bridge.wanted_name = Settings.trainer_name
    if want_trainer and sim:
        sim = null
        changed = true
    elif not want_trainer and sim == null:
        sim = TrainerSim.new()
        changed = true
    if changed:
        source_changed.emit()


## The bridge when it drives the real trainer (not when it only carries the Click buttons).
func trainer_link() -> BridgeClient:
    return bridge if bridge and not bridge.controllers_only and sim == null else null


func source_description() -> String:
    if trainer_link():
        return bridge.describe()
    if sim == null and bridge:
        return bridge.describe()        # the bridge check (main.gd --bridgecheck)
    return tr("Låtsastrainer (byt under Inställningar → Hårdvara)")


func _process(delta: float) -> void:
    if bridge:
        bridge.poll(delta)
        for b in bridge.take_buttons():
            Controls.press(b[0], b[1])
    if state == State.RIDING:
        step(minf(delta, 0.5))     # a long stall (a world being built) is not one huge step


# --- Public API -------------------------------------------------------------------------------

func start_free_ride() -> void:
    _reset()
    Progress.begin_ride()
    workout = null
    player = null
    erg = false
    state = State.RIDING


func start_workout(w, use_erg: bool) -> void:
    _reset()
    Progress.begin_ride()
    workout = w
    player = WorkoutPlayer.new(w, Settings.ftp)
    erg = use_erg
    state = State.RIDING


func toggle_pause() -> void:
    paused = not paused


func skip_segment() -> void:
    if player:
        player.skip()


func change_intensity(delta: float) -> void:
    if player:
        player.change_intensity(delta)


func toggle_mode() -> void:
    erg = not erg
    manual = false
    _last_command = ""


## "erg" (the workout or the chosen watts), "sim" (feel the road) or "eget" (own resistance).
func mode() -> String:
    return "erg" if erg else ("eget" if manual else "sim")


func set_mode(m: String) -> void:
    erg = m == "erg"
    manual = m == "eget"
    _last_command = ""


func change_level(delta: int) -> void:
    manual_level = clampi(manual_level + delta, 0, 10)


func change_free_watts(delta: int) -> void:
    free_watts = clampi(free_watts + delta, 50, 1000)


func change_grade(delta: float) -> void:
    grade = clampf(snappedf(grade + delta, 0.5), -10.0, 20.0)


## A heavier or lighter virtual gear for riding SIM (only changes what the trainer feels).
func change_gear(delta: int) -> void:
    gear = clampi(gear + delta, 1, GEAR_COUNT)


static func gear_ratio(g: int) -> float:
    return 0.75 * pow(5.49 / 0.75, float(g - 1) / (GEAR_COUNT - 1))


## How much heavier the chosen gear is than the neutral one: 1.0 in gear 15, 0.3 in gear 1, 2.2 in 24.
func gear_factor() -> float:
    return gear_ratio(gear) / gear_ratio(GEAR_NEUTRAL)


## Rolling resistance and air drag sent with SIM: the gear's, and less air behind a pacer.
func trainer_crr() -> float:
    return TRAINER_CRR * (1.0 if manual else gear_factor())


func trainer_cw() -> float:
    return TRAINER_CW * (1.0 if manual else pow(gear_factor(), 3.0)) * (1.0 - draft)


## "Tyngre"/"Lättare" from the keys or a Click: the workout's intensity, the watts to hold in free
## ride ERG, or the virtual gear when the trainer simulates the road.
func push(direction: int) -> void:
    if player and erg:
        change_intensity(0.05 * direction)
    elif not player and erg:
        change_free_watts(10 * direction)
    elif manual:
        change_level(direction)
    else:
        change_gear(direction)


## The grade the trainer is sent in SIM. In a world it is the road a moment ahead, softened by the
## "backkänsla" setting, a trainer difficulty (the speed on screen still uses the real
## grade where the bike is), times the virtual gear (gear_factor). Own resistance ignores the hills.
func felt_grade() -> float:
    if manual:
        return float(manual_level)
    var road := grade_ahead * Settings.trainer_difficulty if world_name != "" else grade
    return road * gear_factor()


## Watts the trainer should hold right now, or -1 when it should simulate the road (SIM).
func target_watts() -> int:
    if paused:
        return -1
    if player:
        if player.finished or not erg:
            return -1
        return _erg_cap(player.target_watts())
    return _erg_cap(free_watts) if erg else -1


func _erg_cap(w: int) -> int:
    return mini(w, mini(ERG_MAX_WATTS, roundi(Settings.ftp * ERG_MAX_FTP)))


## The workout target to show on screen even in SIM (the rider then holds it with the gears).
func shown_target() -> int:
    if player and not player.finished:
        return player.target_watts()
    return free_watts if erg else -1


func display_power() -> float:
    if Settings.power_display == "instant" or _window.is_empty():
        return power
    var total := 0.0
    for item in _window:
        total += item[1]
    return total / _window.size()


func avg_power() -> float:
    return _power_sum / _power_seconds if _power_seconds > 0.0 else 0.0


func finish() -> Dictionary:
    state = State.FINISHED
    if trainer_link():
        bridge.release()
    if sim:
        sim.erg_target = -1
    summary = _build_summary()
    fit_path = _save_fit()
    # The pretend trainer makes its watts up, so its rides give no XP, records or FTP (developer
    # runs count, but keep everything in memory, see Progress.save).
    var real: bool = (sim == null or Settings.dev_run) if _restored_real == null else bool(_restored_real)
    _restored_real = null
    forget_autosave()
    progress_report = Progress.finish_ride(summary, power_history, real, real)
    return summary


## The bike from the garage: its weight, drag and rolling resistance.
func apply_bike() -> void:
    _bike = Progress.bike()
    physics.bike_kg = float(_bike["kg"])
    physics.cda = float(_bike["cda"])
    physics.crr = float(_bike["crr"].get(surface, _bike["crr"]["asfalt"]))


## Save the ride so far (see AUTOSAVE_EVERY): everything finish() needs to make the summary, the FIT
## file and the progress, in a compact form (a sample is [t, W, rpm, bpm, m/s, m, m ö.h.]).
func autosave() -> void:
    if state != State.RIDING or samples.is_empty():
        return
    var rows := []
    for x in samples:
        rows.append([x["t"], x["power"], x["cadence"], x["hr"], snappedf(x["speed"], 0.01),
            snappedf(x["distance"], 0.1), snappedf(x["altitude"], 0.1)])
    var tracker = Progress.tracker
    var data := {
        "version": 1, "saved": Time.get_unix_time_from_system(), "started": started_unix,
        "real": sim == null or Settings.dev_run, "world": world_name, "erg": erg,
        "workout": workout.id if workout else "",
        "plan": [workout.plan_id, workout.plan_index] if workout and str(workout.plan_id) != "" else null,
        "clock": _clock, "moving_time": moving_time, "distance": distance, "altitude": altitude,
        "elevation_gain": elevation_gain, "kj": kj, "max_power": max_power, "max_hr": max_hr,
        "power_sum": _power_sum, "power_seconds": _power_seconds, "power_history": Array(power_history),
        "samples": rows, "lap_starts": lap_starts,
        "player": {"elapsed": player.elapsed, "intensity": player.intensity, "results": player.results} if player else null,
        "route": route, "route_state": route_state, "route_time": route_time,
        "segments": tracker.results if tracker else [],
        "laps": tracker.laps.map(func(l): return {"world": l["world"], "time": l["time"], "splits": Array(l["splits"])}) if tracker else [],
    }
    SafeFile.write_text(autosave_path, JSON.stringify(data))


func forget_autosave() -> void:
    for p in [autosave_path, autosave_path + ".bak", autosave_path + ".tmp"]:
        if FileAccess.file_exists(p):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


## The ride a crash left behind, or {} (none, unreadable, or under a minute).
func pending_autosave() -> Dictionary:
    var text := SafeFile.read_text(autosave_path, SafeFile.is_json_object)
    if text == "":
        return {}
    var data: Dictionary = JSON.parse_string(text)
    if (data.get("samples", []) as Array).size() < AUTOSAVE_EVERY:
        forget_autosave()
        return {}
    return data


## Put a ride saved by autosave() back, as if it had just been ridden up to then; finish() then saves
## it like any other. `w` is its workout (or null for a free ride).
func restore(data: Dictionary, w) -> void:
    _reset()
    Progress.begin_ride()
    workout = w
    player = WorkoutPlayer.new(w, Settings.ftp) if w != null else null
    var saved_player = data.get("player")
    if player and saved_player is Dictionary:
        player.elapsed = float(saved_player["elapsed"])
        player.intensity = float(saved_player["intensity"])
        var res: Array = saved_player.get("results", [])
        for i in mini(res.size(), player.results.size()):
            player.results[i] = {"seconds": float(res[i]["seconds"]), "power_sum": float(res[i]["power_sum"]),
                "target_sum": float(res[i]["target_sum"])}
        player.finished = player.elapsed >= float(w.duration) - 0.5
    erg = bool(data.get("erg", true))
    started_unix = float(data["started"])
    world_name = str(data.get("world", ""))
    _clock = float(data["clock"])
    moving_time = float(data["moving_time"])
    distance = float(data["distance"])
    altitude = float(data["altitude"])
    elevation_gain = float(data["elevation_gain"])
    kj = float(data["kj"])
    max_power = int(data["max_power"])
    max_hr = int(data["max_hr"])
    _power_sum = float(data["power_sum"])
    _power_seconds = float(data["power_seconds"])
    power_history = PackedFloat32Array(data["power_history"])
    for r in data["samples"]:
        samples.append({"t": float(r[0]), "power": int(r[1]), "cadence": int(r[2]), "hr": int(r[3]),
            "speed": float(r[4]), "distance": float(r[5]), "altitude": float(r[6])})
    lap_starts.clear()
    for i in data.get("lap_starts", [0]):
        lap_starts.append(int(i))
    var saved_route = data.get("route", {})
    route = saved_route if saved_route is Dictionary else {}
    route_state = str(data.get("route_state", ""))
    route_time = float(data.get("route_time", -1.0))
    var tracker = Progress.tracker
    for r in data.get("segments", []):
        tracker.results.append(r)
    for l in data.get("laps", []):
        tracker.laps.append({"world": l["world"], "time": float(l["time"]), "splits": PackedFloat32Array(l["splits"])})
    np_live = Metrics.normalized(power_history)
    _restored_real = bool(data.get("real", false))
    state = State.RIDING


func back_to_idle() -> void:
    forget_autosave()          # a ride thrown away (or done) is not offered again
    state = State.IDLE
    paused = false


# --- Engine -----------------------------------------------------------------------------------

func _reset() -> void:
    physics = BikePhysics.new()
    physics.rider_kg = Settings.weight_kg
    surface = "asfalt"
    progress_report = {}
    apply_bike()
    paused = false
    guard_active = false
    grade = 0.0
    grade_ahead = 0.0
    gear = GEAR_NEUTRAL
    draft = 0.0
    route = {}
    route_state = ""
    route_time = -1.0
    manual = false
    power = 0.0
    cadence = 0.0
    hr = 0.0
    speed = 0.0
    distance = 0.0
    altitude = 0.0
    elevation_gain = 0.0
    moving_time = 0.0
    kj = 0.0
    max_power = 0
    max_hr = 0
    np_live = 0.0
    power_history = PackedFloat32Array()
    samples.clear()
    lap_starts = [0]
    summary = {}
    fit_path = ""
    started_unix = Time.get_unix_time_from_system()
    _clock = 0.0
    _second_accum = 0.0
    _window.clear()
    _power_seconds = 0.0
    _power_sum = 0.0
    _guard_low = 0.0
    _guard_ok = 0.0
    _command_timer = 0.0
    _last_command = ""
    _last_segment = -1
    if sim:
        sim.bias = 0.0


## Advance the whole engine by dt seconds. Called every frame while riding, and in big steps
## by the self-test to fast-forward a ride.
func step(dt: float) -> void:
    _clock += dt
    if sim:
        sim.update(dt)
        power = sim.power
        cadence = sim.cadence
        hr = sim.hr
    elif trainer_link():
        power = bridge.power
        cadence = bridge.cadence
        hr = bridge.hr
    var pedalling := power > 0.0 or cadence > 0.0

    physics.crr = float(_bike["crr"].get(surface, _bike["crr"]["asfalt"]))
    physics.cda = float(_bike["cda"]) * (1.0 - draft)
    speed = physics.step(dt, power, grade)
    var moved := speed * dt
    distance += moved
    var climb := moved * sin(atan(grade / 100.0))
    altitude += climb
    if climb > 0.0:
        elevation_gain += climb
    if pedalling or speed > 0.3:
        moving_time += dt
    kj += power * dt / 1000.0

    _window.append([_clock, power])
    while not _window.is_empty() and _window[0][0] < _clock - 3.0:
        _window.pop_front()

    if player and not paused and pedalling:
        player.advance(dt, power)
    if player:
        var index := player.index()
        if index != _last_segment and index >= 0:
            if _last_segment >= 0:
                lap_starts.append(samples.size())
            _last_segment = index

    _update_commands(dt)

    _second_accum += dt
    while _second_accum >= 1.0:
        _second_accum -= 1.0
        _record_second()
        if samples.size() % AUTOSAVE_EVERY == 0:
            autosave()


## Decide what the trainer should do and send it when it changes (and every 2 s as a refresh).
func _update_commands(dt: float) -> void:
    var target := target_watts()
    if target > 0 and Settings.cadence_guard:
        if cadence < GUARD_LOW_RPM:
            _guard_low += dt
        else:
            _guard_low = 0.0
        _guard_ok = _guard_ok + dt if cadence >= GUARD_OK_RPM else 0.0
        if not guard_active and _guard_low >= 3.0:
            guard_active = true
        elif guard_active and _guard_ok >= 2.0:
            guard_active = false
    else:
        guard_active = false

    var command := ""
    if target > 0:
        var watts := maxi(50, roundi(target * 0.5)) if guard_active else target
        command = "erg:%d" % watts
    else:
        command = "sim:%.1f:%.4f:%.2f" % [felt_grade(), trainer_crr(), trainer_cw()]

    if sim:
        # The pretend rider aims for the shown target in SIM, a bit harder uphill in free ride.
        var aim := shown_target()
        sim.rider_target = float(aim) if aim > 0 else 150.0 + maxf(grade, 0.0) * 12.0
        if paused:
            sim.rider_target = 110.0

    _command_timer += dt
    if command == _last_command and _command_timer < 2.0:
        return
    # At most one trainer write per second (a world changes the grade constantly); switching
    # between ERG and SIM still goes out at once.
    var same_kind := command.get_slice(":", 0) == _last_command.get_slice(":", 0)
    if same_kind and _command_timer < 1.0:
        return
    _command_timer = 0.0
    _last_command = command
    var parts := command.split(":")
    if parts[0] == "erg":
        if sim:
            sim.erg_target = int(parts[1])
        if trainer_link():
            bridge.set_erg(int(parts[1]))
    else:
        if sim:
            sim.erg_target = -1
            sim.grade = float(parts[1])
        if trainer_link():
            bridge.set_sim(float(parts[1]), float(parts[2]), float(parts[3]))


func _record_second() -> void:
    var p := roundi(power)
    # One record per whole second from the start: the clock's frame-time jitter would otherwise
    # now and then give two records the same FIT time stamp (or skip one).
    samples.append({
        "t": floorf(started_unix) + samples.size() + 1,
        "power": p,
        "cadence": roundi(cadence),
        "hr": roundi(hr),
        "speed": speed,
        "distance": distance,
        "altitude": altitude,
    })
    power_history.append(power)
    max_power = maxi(max_power, p)
    max_hr = maxi(max_hr, roundi(hr))
    # The average counts every second you are moving, the rolling ones at 0 W too, like Strava and
    # Garmin: an average of only the pedalling seconds came out higher than Strava showed.
    if power > 0.0 or cadence > 0.0 or speed > 0.3:
        _power_sum += power
        _power_seconds += 1.0
    np_live = Metrics.normalized(power_history)


func _build_summary() -> Dictionary:
    var zone_seconds := [0, 0, 0, 0, 0, 0]
    var hr_sum := 0.0
    var hr_n := 0
    var cad_sum := 0.0
    var cad_n := 0
    for s in samples:
        if s["power"] > 0:
            zone_seconds[Zones.zone(s["power"] / float(Settings.ftp))] += 1
        if s["hr"] > 0:
            hr_sum += s["hr"]
            hr_n += 1
        if s["cadence"] > 0:
            cad_sum += s["cadence"]
            cad_n += 1
    var np := Metrics.normalized(power_history)
    var result := {
        "name": workout.name if workout else tr("Fri cykling"),
        "world": world_name,
        "started": started_unix,
        "moving_time": moving_time,
        "distance": distance,
        "elevation_gain": elevation_gain,
        "avg_power": avg_power(),
        "max_power": max_power,
        "np": np,
        "if": np / Settings.ftp,
        "tss": Metrics.tss(moving_time, np, Settings.ftp),
        "kj": kj,
        "avg_hr": hr_sum / hr_n if hr_n > 0 else 0.0,
        "max_hr": max_hr,
        "avg_cadence": cad_sum / cad_n if cad_n > 0 else 0.0,
        "zone_seconds": zone_seconds,
        "ftp": Settings.ftp,
        "route": route.get("name", "") if route_state == "klar" or route.get("id", "varvet") != "varvet" else "",
        "stars": player.stars() if player else Vector2i.ZERO,
        "completed": player.finished if player else false,
    }
    return result


func laps() -> Array:
    var result := []
    for i in lap_starts.size():
        var first := lap_starts[i]
        var last := (lap_starts[i + 1] - 1) if i + 1 < lap_starts.size() else samples.size() - 1
        if last >= first:
            result.append({"first": first, "last": last})
    return result


func _save_fit() -> String:
    if samples.is_empty():
        return ""
    var bytes := FitWriter.new().encode(samples, laps(), summary)
    DirAccess.make_dir_recursive_absolute(fit_folder)
    var stamp := Time.get_datetime_string_from_unix_time(int(started_unix + Time.get_time_zone_from_system().get("bias", 0) * 60), true)
    var slug := SafeFile.slug(str(summary["name"]), true)
    var path := "%s/%s_%s.fit" % [fit_folder, stamp.replace(":", "").replace(" ", "_"), slug]
    var file := FileAccess.open(path, FileAccess.WRITE)
    if file == null:
        push_error("Kunde inte spara %s" % path)
        return ""
    file.store_buffer(bytes)
    file.close()
    return ProjectSettings.globalize_path(path)
