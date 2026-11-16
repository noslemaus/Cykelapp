extends SceneTree
## Engine tests without graphics:
##   godot --headless --path game -s res://tests/run_tests.gd
## The full ride (autoloads, recording, FIT file) is tested by main.gd with `-- --selftest`.

const Workout = preload("res://core/workout.gd")
const WorkoutLibrary = preload("res://core/workout_library.gd")
const WorkoutPlayer = preload("res://core/workout_player.gd")
const BikePhysics = preload("res://core/physics.gd")
const Metrics = preload("res://core/metrics.gd")
const Zones = preload("res://core/zones.gd")
const FitWriter = preload("res://core/fit_writer.gd")
const TrainerSim = preload("res://core/trainer_sim.gd")
const PowerCurve = preload("res://core/power_curve.gd")
const LapTracker = preload("res://core/lap_tracker.gd")
const PlanLibrary = preload("res://core/plan_library.gd")
const ProgressScript = preload("res://core/catalog.gd")
const SafeFile = preload("res://core/safe_file.gd")
const Zwo = preload("res://core/zwo.gd")
const CustomWorkouts = preload("res://core/custom_workouts.gd")
const Routes = preload("res://core/routes.gd")

var failures := 0


func _init() -> void:
    _test_library()
    _test_workout()
    _test_player()
    _test_physics()
    _test_metrics()
    _test_sim()
    _test_fit()
    _test_power_curve()
    _test_lap_tracker()
    _test_levels()
    _test_fixed_watts()
    _test_plans()
    _test_safe_file()
    _test_zwo()
    _test_custom_workouts()
    _test_routes()
    print("KLART: %d fel" % failures)
    quit(1 if failures > 0 else 0)


func check(ok: bool, what: String) -> void:
    if ok:
        print("  ok   ", what)
    else:
        failures += 1
        print("  FEL  ", what)


func near(a: float, b: float, tolerance: float) -> bool:
    return absf(a - b) <= tolerance


func _sweet_spot():
    for w in WorkoutLibrary.load_all("res://workouts"):
        if w.id == "sotpunkten":
            return w
    return null


func _test_library() -> void:
    print("Passbibliotek")
    var all := WorkoutLibrary.load_all("res://workouts")
    # The whole library, the hand-made five included.
    check(all.size() == 387, "387 pass laddas: 382 i samlingarna och fem egna (fick %d)" % all.size())
    var per := {}
    var own := 0
    for w in all:
        if w.custom:
            own += 1
            continue
        per[w.category] = int(per.get(w.category, 0)) + 1
    check(own == 5, "fem egna pass (fick %d)" % own)
    # A floor per type, with at least ten more than it each.
    var floor_per_type := {"recovery": 21, "endurance": 51, "sweetspot": 25, "threshold": 44, "vo2max": 41, "ftptest": 4,
        "climbing": 52, "sprint": 32}
    var enough := true
    for cat in floor_per_type:
        enough = enough and int(per.get(cat, 0)) >= int(floor_per_type[cat]) + 10
    check(enough, "minst golvet + 10 per typ: %s" % per)
    var short := 0
    for w in all:
        if w.duration >= 18 * 60 and w.duration <= 32 * 60:
            short += 1
    check(short >= 50, "många pass på 20–30 min (%d)" % short)
    for w in all:
        if w.custom:
            print("       %s: %d min, ansträngning %.1f, TSS %d, IF %.2f" % [w.name, roundi(w.duration / 60.0),
            w.stats()["effort"], roundi(w.stats()["tss"]), w.stats()["intensity_factor"]])


func _test_workout() -> void:
    print("Sötpunkten")
    var w = _sweet_spot()
    check(w != null, "passet finns")
    check(near(w.duration, 1800.0, 0.01), "30 minuter långt")
    check(w.segments.size() == 8, "åtta segment (fick %d)" % w.segments.size())
    check(near(w.target_at(0.0), 0.45, 0.001), "uppvärmningen börjar på 45 %")
    check(near(w.target_at(150.0), 0.575, 0.001), "mitt i uppvärmningen 57,5 %")
    check(near(w.target_at(300.0), 0.88, 0.001), "första blocket 88 %")
    check(w.segments[1]["label"] == "Sweet spot" and w.segments[0]["label"] == "Uppvärmning", "etiketter")
    check(w.target_at(1800.0) < 0.0, "inget mål efter slutet")
    check(w.length_group() == "30", "hamnar i samlingen 30 min")
    var stats: Dictionary = w.stats()
    check(near(stats["intensity_factor"], 0.77, 0.03), "IF ungefär 0,77 (fick %.3f)" % stats["intensity_factor"])
    check(stats["effort"] == 2.5, "ansträngning 2,5/5 (fick %.1f)" % stats["effort"])
    var free_test := Workout.new()
    free_test.parse({"name": "x", "steps": [{"type": "free", "duration": 60}, {"type": "steady", "duration": 60, "power": 1.0}]})
    check(free_test.target_at(30.0) < 0.0 and near(free_test.target_at(90.0), 1.0, 0.001), "fria block saknar mål")


func _test_player() -> void:
    print("Passmotorn")
    var player := WorkoutPlayer.new(_sweet_spot(), 200.0)
    check(player.target_watts() == 90, "start 90 W vid FTP 200 (fick %d)" % player.target_watts())
    for i in 300:
        player.advance(1.0, 180.0)
    check(player.index() == 1 and player.target_watts() == 176, "efter 5 min: block 1 på 176 W")
    player.change_intensity(0.1)
    check(player.target_watts() == 194, "intensitet 110 %% ger 194 W (fick %d)" % player.target_watts())
    player.change_intensity(-0.1)
    for i in 300:
        player.advance(1.0, 176.0)
    check(player.segment_done(1), "blocket räknas som klarat")
    player.skip()
    check(player.index() == 3, "hoppa över går till nästa block")
    var stars := player.stars()
    check(stars == Vector2i(1, 3), "1 av 3 block klarade (fick %s)" % str(stars))
    while not player.finished:
        player.advance(1.0, 150.0)
    check(player.finished and player.target_watts() == -1, "passet tar slut")


func _test_physics() -> void:
    print("Fysik (80 kg + 9 kg cykel)")
    var bike := BikePhysics.new()
    bike.rider_kg = 80.0
    for i in 600:
        bike.step(0.1, 200.0, 0.0)
    for i in 3000:
        bike.step(0.1, 200.0, 0.0)
    check(near(bike.speed * 3.6, 33.8, 0.6), "200 W på platten ≈ 33,8 km/h (fick %.1f)" % (bike.speed * 3.6))
    var climb := BikePhysics.new()
    climb.rider_kg = 80.0
    for i in 3000:
        climb.step(0.1, 250.0, 8.0)
    check(near(climb.speed * 3.6, 11.7, 0.6), "250 W i 8 %% ≈ 11,7 km/h (fick %.1f)" % (climb.speed * 3.6))
    var rolling := BikePhysics.new()
    rolling.speed = 10.0
    for i in 100:
        rolling.step(0.1, 0.0, 0.0)
    check(rolling.speed < 9.0 and rolling.speed > 5.0, "utan watt rullar cykeln ut (%.1f m/s efter 10 s)" % rolling.speed)


func _test_metrics() -> void:
    print("Mått")
    var flat := PackedFloat32Array()
    for i in 600:
        flat.append(200.0)
    check(near(Metrics.normalized(flat), 200.0, 0.01), "NP av jämna 200 W är 200 W")
    check(near(Metrics.tss(3600.0, 200.0, 200.0), 100.0, 0.01), "en timme på FTP ger 100 TSS")
    check(Zones.zone(0.65) == 1 and Zones.zone(1.0) == 3 and Zones.zone(1.3) == 5, "zongränser")


func _test_sim() -> void:
    print("Låtsastrainer")
    var sim := TrainerSim.new()
    sim.erg_target = 220
    for i in 300:
        sim.update(0.1)
    check(near(sim.power, 220.0, 15.0), "följer ERG-målet (%.0f W)" % sim.power)
    check(sim.cadence > 80.0 and sim.hr > 100.0, "kadens och puls stiger")


func _test_fit() -> void:
    print("FIT")
    check(FitWriter.crc16(PackedByteArray()) == 0, "CRC av tom data är 0")
    var samples := []
    for i in 120:
        samples.append({"t": 1794120000.0 + i, "power": 200, "cadence": 90, "hr": 140, "speed": 9.0,
            "distance": 9.0 * (i + 1), "altitude": 0.0})
    var bytes := FitWriter.new().encode(samples, [{"first": 0, "last": 59}, {"first": 60, "last": 119}],
        {"moving_time": 120.0, "kj": 24.0, "np": 200.0, "tss": 3.3, "if": 1.0, "ftp": 200})
    check(bytes.size() > 1000, "filen har innehåll (%d byte)" % bytes.size())
    check(bytes.slice(8, 12).get_string_from_ascii() == ".FIT", "huvudet säger .FIT")
    check(FitWriter.crc16(bytes) == 0, "CRC över hela filen inklusive kontrollsumman blir 0")
    DirAccess.make_dir_recursive_absolute("user://dev-pass")
    var file := FileAccess.open("user://dev-pass/test.fit", FileAccess.WRITE)
    file.store_buffer(bytes)
    file.close()
    print("       sparad: ", ProjectSettings.globalize_path("user://dev-pass/test.fit"))


func _test_power_curve() -> void:
    print("Wattkurva")
    var secs := PackedFloat32Array()
    for i in 1500:
        secs.append(200.0)
    for i in 5:
        secs[100 + i] = 700.0          # a 5 s sprint
    var curve := PowerCurve.of(secs)
    check(near(curve["5"], 700.0, 0.01), "bästa 5 s är sprinten: %.0f W" % curve["5"])
    check(near(curve["1200"], 200.0 + 2500.0 / 1200.0, 0.01), "bästa 20 min räknas med sprinten")
    check(not curve.has("1800"), "ingen 30-minuterswatt i en tur på 25 min")
    check(PowerCurve.ftp_from(curve) == roundi(curve["1200"] * 0.95), "FTP = 95 % av 20 min")


func _test_lap_tracker() -> void:
    print("Segment, varv och spöke")
    var t := LapTracker.new()
    t.set_world("test", 1000.0, [{"id": "backe", "name": "Backen", "kind": "climb", "from": 200.0, "to": 400.0}])
    # Ride 2.5 laps at 10 m/s, one update per 0.5 s.
    var time := 0.0
    var s := 0.0
    while s < 2500.0:
        t.update(s, time, true)
        s += 5.0
        time += 0.5
    check(t.results.size() == 3, "backen kördes tre gånger (%d)" % t.results.size())
    check(near(t.results[0]["time"], 20.0, 0.01), "segmenttid 20 s vid 10 m/s (%.2f)" % t.results[0]["time"])
    check(t.laps.size() == 2, "två hela varv (%d)" % t.laps.size())
    check(near(t.laps[0]["time"], 100.0, 0.01), "varvtid 100 s (%.2f)" % t.laps[0]["time"])
    var splits: PackedFloat32Array = t.laps[0]["splits"]
    check(splits.size() == 101 and near(splits[50], 50.0, 0.01), "mellantider var 10:e meter")
    check(near(LapTracker.ghost_distance(splits, 100.0, 1000.0, 25.0), 250.0, 0.01), "spöket är 250 m in efter 25 s")
    check(near(LapTracker.ghost_time_at(splits, 100.0, 1000.0, 735.0), 73.5, 0.01), "spöket passerade 735 m efter 73,5 s")
    check(LapTracker.ghost_distance(splits, 100.0, 1000.0, 101.0) < 0.0, "spöket är i mål efter varvet")
    # A jump (back to the road, a teleport) throws the running lap and segment away.
    var u := LapTracker.new()
    u.set_world("test", 1000.0, [{"id": "backe", "name": "Backen", "kind": "climb", "from": 200.0, "to": 400.0}])
    u.update(0.0, 0.0, true)
    u.update(250.0, 25.0, true)
    u.update(255.0, 25.5, true)
    u.update(600.0, 26.0, true)
    check(not u.lap_valid and u.active.is_empty(), "ett hopp stryker varvet och segmentet")
    u.update(605.0, 26.5, false)
    check(not u.lap_valid, "fri cykling räknas inte")
    # Starting mid-lap (after a teleport): no lap until the start line.
    var v := LapTracker.new()
    v.set_world("test", 1000.0, [])
    for i in 120:
        v.update(500.0 + i * 5.0, i * 0.5, true)
    check(v.laps.is_empty() and v.lap_valid, "varvet börjar först vid startlinjen")


func _test_levels() -> void:
    print("Nivåer")
    check(ProgressScript.level_for(0) == 1, "nivå 1 från början")
    check(ProgressScript.level_for(499) == 1 and ProgressScript.level_for(500) == 2, "nivå 2 vid 500 XP")
    check(ProgressScript.level_for(ProgressScript.xp_for(10)) == 10, "nivå 10 vid %d XP" % ProgressScript.xp_for(10))
    check(ProgressScript.level_for(100000000) == ProgressScript.MAX_LEVEL, "högsta nivån är %d" % ProgressScript.MAX_LEVEL)
    for id in ProgressScript.BIKE_ORDER:
        var b: Dictionary = ProgressScript.BIKES[id]
        check(b["crr"].has("asfalt") and b["crr"].has("grus") and b["crr"].has("terrang"), "cykeln %s har alla underlag" % id)


func _test_fixed_watts() -> void:
    print("Fasta watt (ramptest)")
    var w := Workout.new()
    w.parse({"name": "t", "steps": [{"type": "free", "duration": 60},
        {"type": "steady", "duration": 60, "watts": 100}, {"type": "ramp", "duration": 60, "from_watts": 75, "to_watts": 70}]})
    var player := WorkoutPlayer.new(w, 250.0)
    player.elapsed = 90.0
    check(player.target_watts() == 100, "100 W är 100 W även med FTP 250 (fick %d)" % player.target_watts())
    var other := WorkoutPlayer.new(w, 180.0)
    other.elapsed = 90.0
    check(other.target_watts() == 100, "och med FTP 180 (fick %d)" % other.target_watts())


func _test_plans() -> void:
    print("Planer")
    var plans := PlanLibrary.load_all("res://plans")
    check(plans.size() == 18, "18 planer (fick %d)" % plans.size())
    var sizes_ok := true
    var linked := true
    for plan in plans:
        sizes_ok = sizes_ok and plan["sessions"].size() in [5, 10, 15, 20]
        for i in plan["sessions"].size():
            var w = plan["sessions"][i]
            linked = linked and w.plan_id == plan["id"] and w.plan_index == i and w.duration > 0.0
    check(sizes_ok, "varje plan har 5, 10, 15 eller 20 pass")
    check(linked, "varje pass vet sin plan och sin plats")


func _test_safe_file() -> void:
    print("Säker sparning och filnamn")
    var dir := "user://dev-pass/sakert"
    DirAccess.make_dir_recursive_absolute(dir)
    for f in DirAccess.get_files_at(dir):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(dir.path_join(f)))
    var path := dir.path_join("progress.json")
    var valid := SafeFile.is_json_object
    check(SafeFile.write_text(path, JSON.stringify({"xp": 1})), "första sparningen")
    check(SafeFile.write_text(path, JSON.stringify({"xp": 2})), "andra sparningen")
    check(not FileAccess.file_exists(path + ".tmp"), "ingen .tmp blir kvar")
    check(JSON.parse_string(FileAccess.get_file_as_string(path + ".bak"))["xp"] == 1, "förra versionen ligger i .bak")
    var half := FileAccess.open(path, FileAccess.WRITE)
    half.store_string("{\"xp\": 2, \"rides\": [")       # as if the app died mid-write
    half.close()
    check(JSON.parse_string(SafeFile.read_text(path, valid))["xp"] == 1, "en trasig fil läses från säkerhetskopian")
    DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
    check(JSON.parse_string(SafeFile.read_text(path, valid))["xp"] == 1, "en saknad fil läses från säkerhetskopian")
    var keys := dir.path_join("strava.cfg")
    var cfg := ConfigFile.new()
    cfg.set_value("token", "refresh", "hemligt")
    SafeFile.save_config(cfg, keys, true)
    SafeFile.save_config(cfg, keys, true)
    var perms := FileAccess.get_unix_permissions(ProjectSettings.globalize_path(keys))
    check(perms & 0x3F == 0, "nyckelfilen kan bara läsas av dig (%o)" % perms)
    check(not FileAccess.file_exists(keys + ".bak"), "nyckelfilen får ingen säkerhetskopia")
    var back := ConfigFile.new()
    check(SafeFile.load_config(back, keys) == OK and back.get_value("token", "refresh") == "hemligt", "nyckelfilen läses tillbaka")
    check(SafeFile.slug("Japan · Ur idet 3/10 · Tempo") == "japan-ur-idet-3-10-tempo", "filnamn av turens titel")
    check(SafeFile.slug("Sötpunkten", true) == "sotpunkten", "FIT-namn utan å, ä och ö")
    check(not SafeFile.slug("../../hemlig/fil.txt").contains("/") and not SafeFile.slug("../x").contains("."), "filnamnet kan aldrig peka ut ur mappen")
    check(SafeFile.slug("///") == "tur" and SafeFile.slug("x".repeat(90)).length() == 60, "tomt och för långt namn")


const ZWO_SAMPLE := """<workout_file>
    <author>Någon</author>
    <name>Prov 2x2</name>
    <description>Ett provpass.</description>
    <sportType>bike</sportType>
    <category>Threshold</category>
    <workout>
        <Warmup Duration="600" PowerLow="0.40" PowerHigh="0.75"/>
        <SteadyState Duration="300" Power="0.88" Cadence="90">
            <textevent timeoffset="10" message="Håll det jämnt"/>
        </SteadyState>
        <IntervalsT Repeat="2" OnDuration="120" OffDuration="60" OnPower="1.05" OffPower="0.55" Cadence="95" CadenceResting="85"/>
        <FreeRide Duration="180" FlatRoad="1"/>
        <MaxEffort Duration="20"/>
        <Cooldown Duration="300" PowerLow="0.65" PowerHigh="0.40"/>
    </workout>
</workout_file>"""


func _test_zwo() -> void:
    print("Zwift-pass (.zwo)")
    var data := Zwo.parse(ZWO_SAMPLE)
    check(not data.has("error"), "provpasset läses")
    check(data.get("name") == "Prov 2x2" and data.get("category") == "threshold", "namn och kategori")
    var steps: Array = data.get("steps", [])
    check(steps.size() == 6, "sex block (textevent räknas inte) (%d)" % steps.size())
    var w := Workout.new()
    check(w.parse(data), "blir ett vanligt pass")
    check(near(w.duration, 600 + 300 + 2 * 180 + 180 + 20 + 300, 0.1), "längden stämmer (%.0f s)" % w.duration)
    check(near(w.segments[0]["from"], 0.40, 0.001) and near(w.segments[0]["to"], 0.75, 0.001), "uppvärmningen är en ramp")
    check(w.segments[1]["cadence"] == 90 and near(w.segments[1]["from"], 0.88, 0.001), "jämnt block med kadens")
    check(w.segments[2]["interval"] == 1 and near(w.segments[2]["from"], 1.05, 0.001) and w.segments[2]["cadence"] == 95,
        "intervallerna med kadens")
    check(w.segments[6]["free"] and w.segments[7]["free"], "fritt och allt du har blir fria block")
    check(near(w.segments[-1]["from"], 0.65, 0.001) and near(w.segments[-1]["to"], 0.40, 0.001), "nedvarvningen går nedåt")
    check(Zwo.parse("<workout_file><workout></workout></workout_file>").has("error"), "ett tomt pass ger ett fel")
    check(Zwo.parse("inte xml alls").has("error"), "något annat än XML ger ett fel")


func _test_custom_workouts() -> void:
    print("Egna pass")
    var dir := "user://dev-pass/egna-test"
    DirAccess.make_dir_recursive_absolute(dir)
    for f in DirAccess.get_files_at(dir):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(dir.path_join(f)))
    var data := {"name": "Mitt test", "steps": [{"type": "steady", "duration": 600.0, "power": 0.7}]}
    var id := CustomWorkouts.save(data, "", dir)
    var id2 := CustomWorkouts.save(data, "", dir)
    check(id == "egen-mitt-test" and id2 == "egen-mitt-test-2", "nya pass får egna id (%s, %s)" % [id, id2])
    var all := CustomWorkouts.load_all(dir)
    check(all.size() == 2 and all[0].custom and near(all[0].duration, 600.0, 0.1), "de läses tillbaka som egna pass")
    CustomWorkouts.delete(id2, dir)
    check(CustomWorkouts.load_all(dir).size() == 1, "ett pass tas bort")
    var file := FileAccess.open(dir.path_join("prov.zwo"), FileAccess.WRITE)
    file.store_string(ZWO_SAMPLE)
    file.close()
    var result := CustomWorkouts.import_zwo(ProjectSettings.globalize_path(dir.path_join("prov.zwo")), dir)
    check(result.get("id", "") == "egen-prov-2x2", "en .zwo-fil importeras (%s)" % str(result))
    check(CustomWorkouts.load_all(dir).size() == 2, "och syns bland de egna passen")


func _test_routes() -> void:
    print("Rutter")
    for world in ["skargarden", "egypten", "japan"]:
        var list := Routes.for_world(world)
        check(list.size() >= 4 and list[0]["id"] == "varvet", "%s har %d rutter, först hela varvet" % [world, list.size()])
        var facts := Routes.facts(world, "varvet")
        check(not facts.is_empty() and facts["km"] > 12.0 and facts["hm"] > 50, "%s: hela varvet %.1f km, %d hm" % [world, facts.get("km", 0.0), facts.get("hm", 0)])
        for r in list:
            check(not Routes.facts(world, r["id"]).is_empty(), "  %s: fakta finns" % r["name"])
    check(Routes.chosen("japan", {"japan": "neonstaden"})["id"] == "neonstaden", "den valda rutten")
    check(Routes.chosen("japan", {"japan": "finns-inte"})["id"] == "varvet", "en okänd rutt ger hela varvet")
    check(Routes.chosen("", {}).is_empty(), "gymskärmen har ingen rutt")
    check(near(Routes.length_of({"laps": 2.0}, 12000.0), 24000.0, 0.1) and near(Routes.length_of({"length": 3400.0}, 12000.0), 3400.0, 0.1),
        "längd av varv och av meter")
    check(Routes.xp_for(12200.0) == 50 + 5 * 12, "XP efter längd")
