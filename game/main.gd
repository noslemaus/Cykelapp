extends Control
## App shell: loads the workouts, swaps screens and handles developer options.
## Developer options (after `--` on the command line):
##   --screen=menu|library|detail|ride|summary|settings|garage   open a screen directly
##   --demo-progress         a rider some weeks in (level, records, a ghost lap in Skärgården)
##   --fart=<x>              the world HUD runs the pretend ride x times faster (screenshots)
##   --workout=<id>          workout for detail/ride/summary (default sotpunkten)
##   --free                  ride screen in free-ride mode
##   --simulate=<s>          fast-forward the pretend ride this many seconds first
##   --screenshot=<path.png> save a screenshot after a moment and quit
##   --selftest              ride a whole workout on the pretend trainer, save FIT, print a summary, quit
## Developer options always use the pretend trainer, never the real KICKR.

const Style = preload("res://ui/style.gd")
const WorkoutLibrary = preload("res://core/workout_library.gd")
const PlanLibrary = preload("res://core/plan_library.gd")
const Routes = preload("res://core/routes.gd")
const CustomWorkouts = preload("res://core/custom_workouts.gd")

const SCREENS := {
    "menu": preload("res://ui/main_menu.gd"),
    "library": preload("res://ui/library.gd"),
    "detail": preload("res://ui/detail.gd"),
    "ride": preload("res://ui/ride_screen.gd"),
    "summary": preload("res://ui/summary.gd"),
    "settings": preload("res://ui/settings_screen.gd"),
    "world_select": preload("res://ui/world_select.gd"),
    "world_hud": preload("res://ui/world_hud.gd"),
    "garage": preload("res://ui/garage.gd"),
    "plan": preload("res://ui/plan.gd"),
    "history": preload("res://ui/history.gd"),
    "ride_detail": preload("res://ui/ride_detail.gd"),
    "routes": preload("res://ui/routes.gd"),
    "workout_editor": preload("res://ui/workout_editor.gd"),
}

const WORLDS := {
    "skargarden": {"name": "Skärgården", "script": "res://world/skargarden/skargarden.gd",
        "thumb": "res://world/skargarden/kort_koncept.png",   # the concept the world is built towards
        "diorama": "res://world/skargarden/kort.png",          # rendered from the real world (--worldthumb)
        "facts": "12,2 km per varv  ·  178 höjdmeter  ·  backar upp till fyren och Storberget (max 7 %)",
        "text": "Granithällar, tallar och röda sjöbodar. Upp till fyren och Storberget, över broarna till Lillön, Norrholmen, Storön och Långön."},
    "egypten": {"name": "Egypten", "script": "res://world/egypten/egypten.gd",
        "thumb": "res://world/egypten/kort_koncept.png",
        "diorama": "res://world/egypten/kort.png",
        "facts": "12,3 km per varv  ·  154 höjdmeter  ·  över Nilen två gånger",
        "text": "Pyramiderna och Sfinxen, basaren i Kairo, fyren på Faros i Alexandria, Vita öknen, Kungadalen, katarakten vid Aswan med Philae och en nubisk by, och palmdjungel längs Nilen."},
    "japan": {"name": "Japan", "script": "res://world/japan/japan.gd",
        "thumb": "res://world/japan/kort_koncept.png",
        "diorama": "res://world/japan/kort.png",
        "facts": "12,3 km per varv  ·  103 höjdmeter  ·  kväll med neon och Fuji, Irohabackarna (max 7 %)",
        "text": "Neon och pariserhjulet i Tokyo, gamla stan med geishor, sjön med toriin i vattnet under Fuji, Irohabackarna, teodlingar, gasshobyn och fiskehamnen."},
}

var workouts: Array = []
var plans: Array = []          # training plans (core/plan_library.gd)
var turbilder: Node = null     # photos during the ride and the three pictures after (core/turbilder.gd)
var current: Control
var world: Node3D = null
var world_id := ""           # the WORLDS key of the world under the ride ("" = none)
var dev_time_scale := 1.0    # developer screenshots (--fart): how fast the world HUD runs the ride
var _bg: ColorRect


func _ready() -> void:
    get_tree().set_auto_accept_quit(false)   # closing mid-ride asks first, see _notification
    theme = Style.make_theme()
    _bg = ColorRect.new()
    _bg.color = Style.BG
    _bg.set_anchors_preset(Control.PRESET_FULL_RECT)
    add_child(_bg)
    if not OS.get_cmdline_user_args().is_empty():
        custom_dir = "user://dev-egna-pass"      # developer runs never touch your own workouts
    reload_workouts()
    plans = PlanLibrary.load_all("res://plans")
    get_window().files_dropped.connect(_on_files_dropped)
    turbilder = preload("res://core/turbilder.gd").new()
    turbilder.app = self
    add_child(turbilder)
    _apply_ftp()
    Settings.changed.connect(_apply_ftp)     # a new FTP (by hand, or raised by a ride) redraws them
    var dev := _dev_options()
    if dev.is_empty():
        go("menu")
        var pending := Ride.pending_autosave()
        if not pending.is_empty():
            _offer_recovery(pending)
        if Settings.intro:
            _play_intro()
    else:
        _run_dev(dev)


## The game's workouts and your own (Egna pass, core/custom_workouts.gd), shortest first.
var custom_dir := CustomWorkouts.DIR


func reload_workouts() -> void:
    workouts = WorkoutLibrary.load_all("res://workouts") + CustomWorkouts.load_all(custom_dir)
    workouts.sort_custom(func(a, b): return a.duration < b.duration or (a.duration == b.duration and a.name < b.name))
    for w in workouts:
        w.set_ftp(Settings.ftp)


## .zwo files dropped on the window become your own workouts (not in the middle of a ride).
func _on_files_dropped(files: PackedStringArray) -> void:
    if Ride.state == Ride.State.RIDING:
        return
    var names: Array = []
    var errors: Array = []
    for f in files:
        if f.get_extension().to_lower() != "zwo":
            continue
        var result := CustomWorkouts.import_zwo(f, custom_dir)
        if result.has("error"):
            errors.append(tr(result["error"]))
        else:
            names.append(result["name"])
    if names.is_empty() and errors.is_empty():
        return
    reload_workouts()
    var message := tr("Importerade: %s") % ", ".join(names) if not names.is_empty() else ""
    if not errors.is_empty():
        message += ("  " if message != "" else "") + " ".join(errors)
    go("library", {"view": "custom", "message": message})


## Fixed-watt steps (the ramp tests) are drawn and counted against your FTP.
func _apply_ftp() -> void:
    for w in workouts:
        w.set_ftp(Settings.ftp)
    for plan in plans:
        for w in plan["sessions"]:
            w.set_ftp(Settings.ftp)


func go(screen: String, args := {}) -> void:
    if current:
        current.queue_free()
    current = SCREENS[screen].new()
    current.set("app", self)
    current.set("args", args)
    current.set_anchors_preset(Control.PRESET_FULL_RECT)
    add_child(current)


## Rides always happen in the world chosen on the start screen (Settings.world, "" = gym screen).
func start_free_ride() -> void:
    begin_ride({"mode": "free", "world": Settings.world})


func start_workout(w, use_erg: bool) -> void:
    begin_ride({"mode": "workout", "workout": w, "erg": use_erg, "world": Settings.world})


## Start the ride chosen on the world screen: {"mode", "workout"?, "erg"?, "world": id or ""}.
## The world is a 3D node under the UI; the ride screen draws its panels on top of it.
func begin_ride(opts: Dictionary) -> void:
    if _loading:
        return
    _loading = true
    var id: String = opts.get("world", "")
    var cover: Control = null
    if WORLDS.has(id):
        # Building a world takes a few seconds: say so first, instead of a menu that stands still.
        cover = _cover(tr("Bygger %s …") % tr(WORLDS[id]["name"]))
        await get_tree().process_frame
        await get_tree().process_frame
    _set_world(id)
    if opts.get("mode") == "workout":
        Ride.start_workout(opts["workout"], opts.get("erg", true))
    else:
        Ride.start_free_ride()
    _start_route()
    go("world_hud" if world else "ride")
    if cover:
        # A new world's first frames compile its materials and stutter: the cover stays until eight
        # frames in a row run smoothly (at most 2.5 s).
        move_child(cover, -1)
        var smooth := 0
        var since := Time.get_ticks_msec()
        while smooth < 8 and Time.get_ticks_msec() - since < 2500:
            await get_tree().process_frame
            smooth = smooth + 1 if get_process_delta_time() < 0.025 else 0
        cover.queue_free()
    _loading = false


var _loading := false


## A full-screen cover with one line, over everything (loading a world, teleporting), with the
## cyclist from AniCraft pedalling above it (ui/animering/laddning.ogv, assets/animering).
func _cover(text: String) -> Control:
    var cover := ColorRect.new()
    cover.color = Color("0a1f29")
    cover.set_anchors_preset(Control.PRESET_FULL_RECT)
    var center := CenterContainer.new()
    center.set_anchors_preset(Control.PRESET_FULL_RECT)
    var box := Style.vbox(10)
    var loop := _video("res://ui/animering/laddning.ogv", true)
    if loop:
        loop.custom_minimum_size = Vector2(540, 225)
        box.add_child(loop)
    var label := Style.label(text, 40, Color("6fe8ff"), 900)
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    box.add_child(label)
    center.add_child(box)
    cover.add_child(center)
    add_child(cover)
    return cover


## A player for one of the AniCraft videos, playing; null when the file is missing.
func _video(path: String, loop: bool) -> VideoStreamPlayer:
    if not ResourceLoader.exists(path):
        return null
    var v := VideoStreamPlayer.new()
    v.stream = load(path)
    v.expand = true
    v.loop = loop
    v.autoplay = true
    v.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return v


## The intro at start-up (made in AniCraft, assets/animering): 3 s, then it fades away. Any key,
## click or Click button skips it. Settings → Skärmen turns it off.
var _intro: Control = null


func _play_intro() -> void:
    var v := _video("res://ui/animering/intro.ogv", false)
    if v == null:
        return
    var shade := ColorRect.new()
    shade.color = Style.BG
    shade.set_anchors_preset(Control.PRESET_FULL_RECT)
    v.set_anchors_preset(Control.PRESET_FULL_RECT)
    shade.add_child(v)
    add_child(shade)
    _intro = shade
    v.finished.connect(_end_intro)


func _end_intro() -> void:
    if _intro == null:
        return
    var going := _intro
    _intro = null
    var fade := create_tween()
    fade.tween_property(going, "modulate:a", 0.0, 0.35)
    fade.tween_callback(going.queue_free)


## The world's chosen route (core/routes.gd): the ride starts at its start on the lap.
func _start_route() -> void:
    if world == null:
        return
    var route := Routes.chosen(world_id, Settings.routes)
    if route.is_empty():
        return
    world.lap_offset = float(route["start"])
    Ride.route = route.duplicate()
    Ride.route["length_m"] = Routes.length_of(route, world.length)
    Ride.route["world"] = world_id


func _set_world(id: String) -> void:
    if world:
        world.queue_free()
        world = null
    Ride.world_name = ""
    world_id = ""
    if id != "" and WORLDS.has(id):
        world = load(WORLDS[id]["script"]).new()
        add_child(world)
        move_child(world, 1)      # above the background colour, below every screen
        Ride.world_name = WORLDS[id]["name"]
        world_id = id
    _bg.visible = world == null
    # The world's music in a ride; in the menus the chosen world's.
    Musik.set_world(id if world != null else Settings.world)


## Points from the battle in the world so far go to Progress (once): when the vehicle is left, the
## ride ends or a teleport takes the world away.
func bank_battle() -> void:
    if world == null or not "strid" in world or world.strid == null:
        return
    Progress.bank_battle(world.strid.score - world.strid.banked)
    world.strid.banked = world.strid.score


## Ridden through a teleport gate: swap the world under the ride. The ride, the workout and the
## trainer carry on; the screen says "Teleporterar …" while the new world is built (a few seconds).
func teleport(target: String) -> void:
    if not WORLDS.has(target) or world == null or _teleporting:
        return
    _teleporting = true
    var cover := _cover(tr("Teleporterar till %s …") % tr(WORLDS[target]["name"]))
    await get_tree().process_frame      # two frames, so the cover is on screen before the build
    await get_tree().process_frame
    bank_battle()
    _set_world(target)
    world.arrive_by_teleport(Ride.distance)
    go("world_hud")
    move_child(cover, -1)
    await get_tree().process_frame
    cover.queue_free()
    _teleporting = false


var _teleporting := false


## The ride's name for Strava and the pictures: the world, the plan and its session number, and the
## workout, e.g. "Japan · Ur idet 3/10 · Tempo och sweet spot" or "Egypten · Fri cykling".
func activity_title(s: Dictionary) -> String:
    var parts: Array[String] = []
    if str(s.get("world", "")) != "":
        parts.append(tr(str(s["world"])))
    var w = Ride.workout
    if w != null and str(w.get("plan_id")) != "":
        var p := find_plan(w.plan_id)
        if not p.is_empty():
            parts.append("%s %d/%d" % [tr(p["name"]), int(w.plan_index) + 1, p["sessions"].size()])
    if w == null and str(s.get("route", "")) != "":
        parts.append(tr(str(s["route"])))          # a free ride on a route: "Skärgården · Tre berg"
    else:
        parts.append(tr(str(s.get("name", tr("Cykelpass")))))
    return " · ".join(parts)


func finish_ride() -> void:
    bank_battle()
    Ride.finish()
    _set_world("")
    go("summary")


## F11 switches between full screen and a window, wherever you are in the game; while the intro
## plays, any key, click or Click button skips it.
func _input(event: InputEvent) -> void:
    if _intro and event.is_pressed() and not event.is_echo() and (event is InputEventKey or event is InputEventMouseButton
            or event is InputEventAction or event is InputEventJoypadButton):
        _end_intro()
        get_viewport().set_input_as_handled()
        return
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11:
        Settings.fullscreen = not Settings.fullscreen
        Settings.save()
        get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
    if what != NOTIFICATION_WM_CLOSE_REQUEST:
        return
    if Ride.state == Ride.State.RIDING:
        _ask_before_closing()
    else:
        quit_app()


func quit_app() -> void:
    Ride.shutdown()
    get_tree().quit()


var _close_dialog: Control = null


## Closing the window mid-ride: save the ride (then choose Strava on the summary), throw it away,
## or keep riding.
func _ask_before_closing() -> void:
    if _close_dialog:
        return
    var shade := ColorRect.new()
    shade.color = Color(0, 0, 0, 0.6)
    shade.set_anchors_preset(Control.PRESET_FULL_RECT)
    var center := CenterContainer.new()
    center.set_anchors_preset(Control.PRESET_FULL_RECT)
    shade.add_child(center)
    var panel := Style.panel(Style.PANEL, 20, 32)
    center.add_child(panel)
    var box := Style.vbox(18)
    panel.add_child(box)
    box.add_child(Style.label(tr("Avsluta turen?"), 34, Style.TEXT, 800))
    box.add_child(Style.label(tr("Du är mitt i en tur. Spara den, så kan du välja att ladda upp den till Strava."), 20, Style.TEXT_DIM, 500))
    var row := Style.hbox(12)
    var save := Style.button(tr("Spara turen"), "primary", 21)
    save.pressed.connect(func():
        _close_dialog.queue_free()
        _close_dialog = null
        finish_ride())
    var discard := Style.button(tr("Släng turen och stäng"), "secondary", 21)
    discard.pressed.connect(func():
        Ride.back_to_idle()
        quit_app())
    var keep := Style.button(tr("Fortsätt cykla"), "ghost", 21)
    keep.pressed.connect(func():
        _close_dialog.queue_free()
        _close_dialog = null)
    row.add_child(save)
    row.add_child(discard)
    row.add_child(keep)
    box.add_child(row)
    _close_dialog = shade
    add_child(shade)


## A ride a crash left behind (Ride.autosave): save it as it was at the last minute, or throw it away.
func _offer_recovery(data: Dictionary) -> void:
    var shade := ColorRect.new()
    shade.color = Color(0, 0, 0, 0.6)
    shade.set_anchors_preset(Control.PRESET_FULL_RECT)
    var center := CenterContainer.new()
    center.set_anchors_preset(Control.PRESET_FULL_RECT)
    shade.add_child(center)
    var panel := Style.panel(Style.PANEL, 20, 32)
    center.add_child(panel)
    var box := Style.vbox(16)
    panel.add_child(box)
    box.add_child(Style.label(tr("En tur blev avbruten"), 34, Style.TEXT, 800))
    var w = _saved_workout(data)
    var what: Array[String] = []
    if str(data.get("world", "")) != "":
        what.append(tr(str(data["world"])))
    what.append(tr(w.name) if w != null else tr("Fri cykling"))
    what.append(Style.clock(float(data["moving_time"])))
    what.append("%s km" % Style.dec(float(data["distance"]) / 1000.0, 1))
    var when := Time.get_datetime_string_from_unix_time(int(float(data["started"]) + Time.get_time_zone_from_system().get("bias", 0) * 60), true)
    box.add_child(Style.label("  ·  ".join(what), 22, Style.ACCENT, 800))
    var text := Style.label(tr("Startad %s. Appen stängdes mitt i turen, men den sparades varje minut. Spara den som den var, så kan du ladda upp den till Strava.") % when.left(16),
        18, Style.TEXT_DIM, 500)
    text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    text.custom_minimum_size.x = 640
    box.add_child(text)
    var row := Style.hbox(12)
    var save := Style.button(tr("Spara turen"), "primary", 21)
    save.pressed.connect(func():
        shade.queue_free()
        Ride.restore(data, _saved_workout(data))
        finish_ride())
    var discard := Style.button(tr("Släng den"), "secondary", 21)
    discard.pressed.connect(func():
        Ride.forget_autosave()
        shade.queue_free())
    row.add_child(save)
    row.add_child(discard)
    box.add_child(row)
    add_child(shade)


## The workout of a saved ride: a plan's session or one from the library (null for a free ride).
func _saved_workout(data: Dictionary):
    var plan = data.get("plan")
    if plan is Array and plan.size() == 2:
        var p := find_plan(str(plan[0]))
        if not p.is_empty() and int(plan[1]) < p["sessions"].size():
            return p["sessions"][int(plan[1])]
    var id := str(data.get("workout", ""))
    for w in workouts:
        if w.id == id:
            return w
    return null


## --kraschtest: ride 150 s, "crash" (the app is gone, the saved ride is left), and save the ride
## again from what was saved at 120 s, as the next start would.
func _crashtest() -> void:
    var failures := 0
    var w = find_workout("sotpunkten")
    Ride.start_workout(w, true)
    for i in 150:
        Ride.step(1.0)
    var at_save := Ride.samples.size() - Ride.samples.size() % Ride.AUTOSAVE_EVERY
    var dist_then: float = Ride.samples[at_save - 1]["distance"]
    Ride.state = Ride.State.IDLE                # the crash: nothing finished, the file stays
    var data := Ride.pending_autosave()
    var checks := []
    checks.append([not data.is_empty() and data["samples"].size() == at_save, "turen sparades efter %d s" % at_save])
    Ride.restore(data, _saved_workout(data))
    checks.append([Ride.samples.size() == at_save and is_equal_approx(Ride.distance, float(data["distance"])), "turen återställs"])
    checks.append([Ride.player != null and Ride.player.elapsed > 100.0 and Ride.workout == w, "passet och var i det"])
    var s := Ride.finish()
    checks.append([Ride.fit_path != "" and FileAccess.file_exists(Ride.fit_path), "FIT-filen sparas"])
    checks.append([absf(float(s["distance"]) - dist_then) < 10.0 and s["moving_time"] >= at_save - 2, "sammanfattningen stämmer (%.0f m)" % s["distance"]])
    checks.append([Ride.pending_autosave().is_empty(), "den sparade turen är borta efteråt"])
    Ride.start_free_ride()
    for i in 70:
        Ride.step(1.0)
    Ride.back_to_idle()
    checks.append([Ride.pending_autosave().is_empty(), "en slängd tur erbjuds inte igen"])
    for c in checks:
        print("  %s  %s" % ["ok " if c[0] else "FEL", c[1]])
        if not c[0]:
            failures += 1
    print("KRASCHTEST: %d fel" % failures)
    get_tree().quit(1 if failures > 0 else 0)


func find_plan(id: String) -> Dictionary:
    for plan in plans:
        if plan["id"] == id:
            return plan
    return {}


func find_workout(id: String):
    for w in workouts:
        if w.id == id:
            return w
    return workouts[0] if not workouts.is_empty() else null


# --- Developer options -------------------------------------------------------------------------

func _dev_options() -> Dictionary:
    var options := {}
    for arg in OS.get_cmdline_user_args():
        var parts := arg.trim_prefix("--").split("=", true, 1)
        options[parts[0]] = parts[1] if parts.size() > 1 else "1"
    return options


func _run_dev(dev: Dictionary) -> void:
    Ride.fit_folder = "user://dev-pass"   # keep pretend rides out of the real ride folder
    Ride.autosave_path = "user://dev-pagaende-tur.json"
    _prune_dev_rides(50)
    Settings.persist = false              # developer runs never change the saved settings
    # Tests click buttons by their Swedish text: developer runs are in Swedish unless --sprak=en.
    Settings.language = dev.get("sprak", "sv")
    Settings.apply_language()
    Strava.use_config("user://strava-dev.cfg")   # never touch the real Strava keys
    Strava.open_browser = false
    # --tid=natt --vader=regn --arstid=vinter: the world's time of day, weather and season.
    for pair in [["tid", "time_of_day"], ["vader", "weather"], ["arstid", "season"]]:
        if dev.has(pair[0]):
            Settings.set(pair[1], dev[pair[0]])
    if dev.has("stravatest"):
        _stravatest(dev["stravatest"])
        return
    if dev.has("worldshot"):
        _worldshot(dev)
        return
    if dev.has("worldmap"):
        _worldmap(dev)
        return
    if dev.has("film"):
        _film(str(dev["film"]))
        return
    if dev.has("kartor"):
        _bake_maps()
        return
    if dev.has("worldthumb"):
        _worldthumb(dev)
        return
    if dev.has("kraschtest"):
        _crashtest()
        return
    if dev.has("closetest"):
        _closetest()
        return
    if dev.has("bridgecheck"):
        _bridgecheck(not dev.has("nolaunch"), dev.has("byttrainer"))
        return
    # Never touch the real trainer from developer runs.
    Settings.source = "sim"
    if dev.has("demo-progress"):
        Progress.load_demo()          # --demo-progress: a rider some weeks in (garage, ghost)
    dev_time_scale = float(dev.get("fart", "1"))   # --fart=8: the world HUD runs the ride faster
    Ride.apply_settings()
    var w = find_workout(dev.get("workout", "sotpunkten"))
    if dev.has("planpass"):
        # --planpass=<plan id>,<session number from 1>: ride a session of a plan.
        var pp: PackedStringArray = str(dev["planpass"]).split(",")
        var plan := find_plan(pp[0])
        if not plan.is_empty():
            w = plan["sessions"][clampi(int(pp[1]) - 1 if pp.size() > 1 else 0, 0, plan["sessions"].size() - 1)]
    if dev.has("selftest"):
        _selftest(w)
        return
    if dev.has("passtest"):
        _passtest()
        return
    if dev.has("flowtest"):
        _flowtest()
        return
    var screen: String = dev.get("screen", "menu")
    var args := {}
    if screen in ["ride", "summary"]:
        _set_world(dev.get("world", ""))
        if dev.has("free"):
            Ride.start_free_ride()
            Ride.grade = 2.0
        else:
            Ride.start_workout(w, true)
        if dev.has("rutt"):
            Settings.routes[dev.get("world", "")] = dev["rutt"]     # --rutt=tre_berg
        _start_route()
        for i in int(dev.get("simulate", "0")):
            if world:
                Ride.grade = world.grade_at(Ride.distance)
                Ride.grade_ahead = world.grade_at(Ride.distance + Ride.speed * Ride.GRADE_LOOKAHEAD)
            Ride.step(1.0)
        if dev.has("lage"):
            Ride.set_mode(dev["lage"])      # --lage=erg|sim|eget
        if screen == "summary":
            bank_battle()
            Ride.finish()
            _set_world("")
        if world and screen == "ride":
            screen = "world_hud"
    if screen == "detail" or screen == "world_select":
        args = {"workout": w, "mode": "workout", "erg": true}
    elif screen == "library":
        args = {"view": dev.get("view", "collections")}
    elif screen == "settings":
        args = {"tab": dev.get("tab", "profil")}
    elif screen == "garage":
        args = {"tab": dev.get("tab", "cyklar")}
    elif screen == "ride_detail":
        args = {"ride": Progress.data["rides"][-2] if Progress.data["rides"].size() > 1 else {}}
    elif screen == "plan":
        args = {"plan": find_plan(dev.get("plan", "ur-idet"))}     # --plan=<id>
    if dev.has("provtrainers"):
        _fake_trainers(str(dev["provtrainers"]))
    go(screen, args)
    if (dev.has("roam") or dev.has("fri")) and world and current.has_method("_start_roam"):
        # --roam: press "Tryck ej här". --fri=x,z,degrees: stand there; --strid: take the tank.
        current._start_roam()
        _dev_free(world, dev)
    if dev.has("intro"):
        _play_intro()                       # --intro: the start-up animation (screenshots)
    if dev.has("laddning"):
        _cover(tr("Bygger %s …") % tr("Japan"))   # --laddning: the loading cover with its loop
    if dev.has("aterstall"):
        # --aterstall: the question a crashed ride leaves for the next start (from a developer ride).
        var pending := Ride.pending_autosave()
        if not pending.is_empty():
            _offer_recovery(pending)
    if dev.has("storkarta") and current.has_method("_toggle_big_map"):
        current._toggle_big_map()           # --storkarta: the whole map (K) over the ride
    if dev.has("installningar") and current.has_method("_toggle_settings"):
        # --installningar[=<flik>]: the settings open over the ride, e.g. --installningar=ljud
        current._toggle_settings()
        if str(dev["installningar"]) != "1":
            current._settings._show(dev["installningar"])
    if dev.has("klick"):
        # --klick=h_y,v_hoger,h_a,…: press these Click buttons one after another (after the world has
        # had a second), as if from the bridge; "-" waits a second. Then the screenshot, if asked.
        await get_tree().create_timer(1.0, true, false, true).timeout
        for id in str(dev["klick"]).split(","):
            if id == "-":
                await get_tree().create_timer(1.0, true, false, true).timeout
                continue
            Controls.press(id, true)
            await get_tree().create_timer(0.12, true, false, true).timeout
            Controls.press(id, false)
            await get_tree().create_timer(0.3, true, false, true).timeout
            var f := get_viewport().gui_get_focus_owner()
            print("Klick %s → fokus: %s" % [id, (f as Button).text if f is Button else (f.get_class() if f else "ingen")])
    if dev.has("matning"):
        await _measure_ride(float(dev["matning"]))
        get_tree().quit()
        return
    if dev.has("turbilder"):
        # --turbilder=<dir>: ride on for --vanta seconds (with --fart, in a world), finish, and save the
        # three pictures there.
        await get_tree().create_timer(float(dev.get("vanta", "60")), true, false, true).timeout
        finish_ride()
        await turbilder.composed
        for i in 4:
            await get_tree().process_frame
        await RenderingServer.frame_post_draw
        get_viewport().get_texture().get_image().save_png(str(dev["turbilder"]).path_join("sammanfattning.png"))
        print("Turbilder: %d foton, %d bilder, titel \"%s\", sparade i %s" % [turbilder.shots.size(),
            turbilder.images.size(), turbilder.title, turbilder.save(str(dev["turbilder"]))])
        get_tree().quit()
        return
    if dev.has("screenshot"):
        # --vanta=<s> waits longer (in real seconds, also when --fart runs the ride faster). The first
        # frames compile the shaders and can take seconds, so the wait starts after them.
        for i in 3:
            await get_tree().process_frame
        await get_tree().create_timer(float(dev.get("vanta", "1.0")), true, false, true).timeout
        await RenderingServer.frame_post_draw
        print("Tid i turen %.1f s, %.0f m, tidsskala %.1f" % [Ride.moving_time, Ride.distance, Engine.time_scale])
        for bus in ["Musik"]:
            var b := AudioServer.get_bus_index(bus)
            if b >= 0:
                print("  ljud %s: %.0f dB" % [bus, AudioServer.get_bus_peak_volume_left_db(b, 0)])
        print("  musiknivå %d (zon av %d W snitt), låt %s" % [Musik.level, roundi(Ride.avg_power()), Musik.song])
        var path: String = dev["screenshot"]
        get_viewport().get_texture().get_image().save_png(path)
        print("Skärmdump: ", path)
        get_tree().quit()


## Developer runs save a FIT file per test ride in user://dev-pass; keep only the newest `keep`
## (the names start with the date and time, so they sort by age). Real rides are never touched.
func _prune_dev_rides(keep: int) -> void:
    if not DirAccess.dir_exists_absolute("user://dev-pass"):
        return
    var files := Array(DirAccess.get_files_at("user://dev-pass")).filter(func(f): return f.ends_with(".fit"))
    files.sort()
    for i in maxi(files.size() - keep, 0):
        DirAccess.remove_absolute(ProjectSettings.globalize_path("user://dev-pass".path_join(files[i])))


## --matning=<s> (with --screen=ride --world=…): the frame times of a whole ride for s seconds, once
## the shaders have warmed up: the HUD, the engine, the music and the ride photos together. Frames
## around a ride photo (core/turbilder.gd) are counted apart, since a photo renders the world twice.
func _measure_ride(seconds: float) -> void:
    await get_tree().create_timer(3.0, true, false, true).timeout
    var times := PackedFloat32Array()
    var photo := PackedFloat32Array()
    var shots: int = turbilder.shots.size()
    var end := Time.get_ticks_msec() + int(seconds * 1000.0)
    var last := Time.get_ticks_usec()
    while Time.get_ticks_msec() < end:
        await get_tree().process_frame
        var now := Time.get_ticks_usec()
        var ms := (now - last) / 1000.0
        last = now
        times.append(ms)
        var during_photo: bool = turbilder._busy or turbilder.shots.size() != shots
        if during_photo:
            photo.append(ms)
            shots = turbilder.shots.size()
        if ms > 40.0:
            print("  lång bild: %.0f ms vid %.1f s in i turen%s" % [ms, Ride.moving_time, " (foto)" if during_photo else ""])
    var sorted := times.duplicate()
    sorted.sort()
    var n := sorted.size()
    var over := func(limit: float) -> int: return Array(times).filter(func(t): return t > limit).size()
    print("Mätning %s: %d bilder på %.0f s = %.1f bilder/s" % [world_id, n, seconds, n / seconds])
    print("  bildtid: median %.1f ms, 95 %% %.1f ms, 99 %% %.1f ms, längsta %.0f ms; över 25 ms: %d, över 50 ms: %d" % [
        sorted[n / 2], sorted[int(n * 0.95)], sorted[int(n * 0.99)], sorted[-1], over.call(25.0), over.call(50.0)])
    var photo_max := 0.0
    for t in photo:
        photo_max = maxf(photo_max, t)
    print("  turbilder: %d foton, längsta bild runt ett foto %.0f ms" % [turbilder.shots.size(), photo_max])


## Build a world, stand the rider at --at metres (several comma-separated), print road facts and
## save one screenshot per position: --worldshot=<dir> [--world=skargarden] [--at=0,800,1500] [--orbit=deg]
## [--fri=x,z,degrees] (free riding from there; --at is then only the frame count) [--strid] (in the tank)
func _worldshot(dev: Dictionary) -> void:
    var started := Time.get_ticks_msec()
    var id: String = dev.get("world", "skargarden")
    var w: Node3D = load(WORLDS[id]["script"]).new()
    add_child(w)
    _bg.visible = false
    w.orbit = deg_to_rad(float(dev.get("orbit", "0")))   # swing the camera to look around (degrees)
    if dev.has("fri"):
        _dev_free(w, dev)
    print("Världen byggd på %d ms" % (Time.get_ticks_msec() - started))
    var climb := 0.0
    var max_grade := -99.0
    var min_grade := 99.0
    var bridge_m := 0.0
    var top := -99.0
    for i in w.road_pos.size():
        var a: Vector3 = w.road_pos[i]
        var b: Vector3 = w.road_pos[(i + 1) % w.road_pos.size()]
        climb += maxf(b.y - a.y, 0.0)
        max_grade = maxf(max_grade, w.road_grade[i])
        min_grade = minf(min_grade, w.road_grade[i])
        top = maxf(top, a.y)
        if w.road_bridge[i] == 1:
            bridge_m += w.STEP
    print("Väg %.0f m, %d höjdmeter per varv, högsta punkt %.0f m, lutning %.1f till %.1f %%, bro %.0f m" % [
        w.length, roundi(climb), top, min_grade, max_grade, bridge_m])
    var spans := []
    for i in w.road_pos.size():
        if w.road_bridge[i] == 1 and w.road_bridge[(i - 1 + w.road_pos.size()) % w.road_pos.size()] == 0:
            spans.append("%d m" % roundi(i * w.STEP))
    print("Broar börjar vid: %s" % ", ".join(spans))
    var points: Array = []
    for p in str(dev.get("at", "0")).split(","):
        points.append(float(p))
    for at in points:
        for i in 40:
            w.update_view(at - 40.0 * 0.15 + i * 0.15, 9.0, 88.0, 1.0 / 60.0)
            await get_tree().process_frame
        await RenderingServer.frame_post_draw
        var path := "%s/varld_%04d.png" % [dev["worldshot"], int(at)]
        get_viewport().get_texture().get_image().save_png(path)
        print("Skärmdump %s (lutning %.1f %%)" % [path, w.grade_at(at)])
    # Ride on for five seconds at 30 km/h and measure the frame rate. Vsync caps it at the screen's
    # rate, so triangles and draw calls per frame show how much the scene asks of the GPU.
    var t0 := Time.get_ticks_msec()
    var frames := 0
    var gpu := 0.0
    var gpu_max := 0.0
    var at0: float = points[-1]
    var times := PackedFloat32Array()
    var cpu := 0.0
    while Time.get_ticks_msec() - t0 < 5000:
        var dt := get_process_delta_time()
        times.append(dt)
        at0 += 8.3 * dt
        var c0 := Time.get_ticks_usec()
        w.update_view(at0, 8.3, 88.0, dt)
        cpu += Time.get_ticks_usec() - c0
        frames += 1
        await get_tree().process_frame
        gpu += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
        gpu_max = maxf(gpu_max, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
    print("Bildfrekvens: %.0f bilder/s (%d bilder på 5 s), %.1f milj. trianglar och högst %d ritanrop per bild" % [
        frames / 5.0, frames, gpu / maxf(frames, 1) / 1e6, int(gpu_max)])
    times.sort()
    print("  bildtid: median %.1f ms, 95 %% %.1f ms, längsta %.0f ms; update_view %.1f ms i snitt" % [
        times[times.size() / 2] * 1000.0, times[int(times.size() * 0.95)] * 1000.0, times[-1] * 1000.0, cpu / maxf(frames, 1) / 1000.0])
    get_tree().quit()


## A map from above of a world's ground and roads (2 m per pixel), for planning:
## --worldmap=<png> [--world=egypten]. The lap is black (bridges red, a white dot every 500 m),
## other paths blue, teleport gates cyan.
func _worldmap(dev: Dictionary) -> void:
    var w: Node3D = load(WORLDS[dev.get("world", "skargarden")]["script"]).new()
    add_child(w)
    await get_tree().process_frame
    # The world's detailed core with a margin, at 2 m per pixel (3 m for the bigger maps).
    var area: Rect2 = w.CORE.grow(180.0)
    var sc := 2.0 if area.size.x <= 2400.0 else 3.0
    var x0 := area.position.x
    var z0 := area.position.y
    var width := int(area.size.x / sc)
    var height := int(area.size.y / sc)
    var img := Image.create(width, height, false, Image.FORMAT_RGB8)
    for py in height:
        for px in width:
            var x := x0 + px * sc
            var z := z0 + py * sc
            var h: float = w.natural(x, z)
            var c: Color
            if h < 0.0:
                c = Color(0.15, 0.3, 0.55).lerp(Color(0.35, 0.6, 0.75), clampf((h + 9.0) / 9.0, 0, 1))
            else:
                c = Color(0.55, 0.65, 0.35).lerp(Color(0.95, 0.88, 0.75), clampf(h / 30.0, 0, 1))
            if int(x) % 100 == 0 or int(z) % 100 == 0:
                c = c.darkened(0.25)
            img.set_pixel(px, py, c)
    var dot := func(p: Vector3, col: Color, r: int) -> void:
        var cx := int((p.x - x0) / sc)
        var cy := int((p.z - z0) / sc)
        for dx in range(-r, r + 1):
            for dy in range(-r, r + 1):
                if cx + dx >= 0 and cx + dx < width and cy + dy >= 0 and cy + dy < height:
                    img.set_pixel(cx + dx, cy + dy, col)
    for k in range(1, w.paths.size()):
        for p in w.paths[k]["pts"]:
            dot.call(p, Color(0.2, 0.4, 1.0), 1)
    for i in w.road_pos.size():
        dot.call(w.road_pos[i], Color.RED if w.road_bridge[i] == 1 else Color.BLACK, 1)
    for i in range(0, w.road_pos.size(), 250):
        dot.call(w.road_pos[i], Color.WHITE, 3)
    for t in w.teleports:
        dot.call(t[0], Color(0.4, 0.95, 1.0), 4)
    img.save_png(dev["worldmap"])
    print("Karta: %s, varv %.0f m" % [dev["worldmap"], w.length])
    get_tree().quit()


## --film=<name> (with --write-movie <file.ogv> --fixed-fps 30): show the PNG frames of an AniCraft
## animation (assets/animering/render/<name>/), one per rendered frame, so Godot's movie writer
## makes a video of them (assets/animering/animering.py).
func _film(name: String) -> void:
    _bg.visible = false
    var dir := ProjectSettings.globalize_path("res://").path_join("../assets/animering/render/" + name).simplify_path()
    var files := Array(DirAccess.get_files_at(dir)).filter(func(f): return f.ends_with(".png"))
    files.sort()
    var rect := TextureRect.new()
    rect.set_anchors_preset(Control.PRESET_FULL_RECT)
    rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    rect.stretch_mode = TextureRect.STRETCH_SCALE
    add_child(rect)
    for f in files:
        rect.texture = ImageTexture.create_from_image(Image.load_from_file(dir.path_join(f)))
        await get_tree().process_frame
    get_tree().quit()


## --kartor: build every world once and save what the menus and the HUD need without building one:
## the map (res://world/<id>/karta.png, 3 m per pixel over the world's core: sea, land shaded by
## height, the roads and the lap in white) and each route's length, climbing and segments
## (res://world/rutter.json, core/routes.gd). Run `godot --headless --import` afterwards.
const MAP_SCALE := 3.0
const MAP_LAND := {"skargarden": [Color("5d8a4e"), Color("b9907c")], "egypten": [Color("d8b878"), Color("b07a48")],
    "japan": [Color("5f9450"), Color("a7b089")]}


func _bake_maps() -> void:
    var facts := {}
    for id in WORLDS:
        var started := Time.get_ticks_msec()
        var w: Node3D = load(WORLDS[id]["script"]).new()
        add_child(w)
        await get_tree().process_frame
        var area: Rect2 = w.CORE.grow(180.0)
        var width := int(area.size.x / MAP_SCALE)
        var height := int(area.size.y / MAP_SCALE)
        var heights := PackedFloat32Array()
        heights.resize(width * height)
        for py in height:
            for px in width:
                heights[py * width + px] = w.natural(area.position.x + px * MAP_SCALE, area.position.y + py * MAP_SCALE)
        var img := Image.create(width, height, false, Image.FORMAT_RGB8)
        var land: Array = MAP_LAND.get(id, MAP_LAND["skargarden"])
        for py in height:
            for px in width:
                var h := heights[py * width + px]
                var c: Color
                if h < 0.0:
                    c = Color("17435f").lerp(Color("2f7f9c"), clampf((h + 8.0) / 8.0, 0.0, 1.0))
                else:
                    c = (land[0] as Color).lerp(land[1], clampf(h / 40.0, 0.0, 1.0))
                    # Light from the north-west: slopes facing it lighter, the others darker.
                    var hx := heights[py * width + mini(px + 1, width - 1)] - heights[py * width + maxi(px - 1, 0)]
                    var hz := heights[mini(py + 1, height - 1) * width + px] - heights[maxi(py - 1, 0) * width + px]
                    var shade := clampf(-(hx + hz) * 0.08, -0.25, 0.25)
                    c = c.lightened(shade) if shade > 0.0 else c.darkened(-shade)
                img.set_pixel(px, py, c)
        var stamp := func(p: Vector3, col: Color, r: int) -> void:
            var cx := int((p.x - area.position.x) / MAP_SCALE)
            var cy := int((p.z - area.position.y) / MAP_SCALE)
            for dx in range(-r, r + 1):
                for dy in range(-r, r + 1):
                    if dx * dx + dy * dy <= r * r + 1 and cx + dx >= 0 and cx + dx < width and cy + dy >= 0 and cy + dy < height:
                        img.set_pixel(cx + dx, cy + dy, col)
        for k in range(1, w.paths.size()):
            for p in w.paths[k]["pts"]:
                stamp.call(p, Color("e6dfd2"), 1)
        for p in w.road_pos:
            stamp.call(p, Color("2a2d33"), 2)
        for p in w.road_pos:
            stamp.call(p, Color.WHITE, 1)
        var path := "res://world/%s/karta.png" % id
        img.save_png(ProjectSettings.globalize_path(path))
        facts[id] = {}
        for route in Routes.for_world(id):
            facts[id][route["id"]] = Routes.measure(w, route)
        print("Karta %s: %dx%d, %d rutter, %d ms" % [id, width, height, facts[id].size(), Time.get_ticks_msec() - started])
        w.queue_free()
        await get_tree().process_frame
    var file := FileAccess.open(Routes.FACTS_PATH, FileAccess.WRITE)
    file.store_string(JSON.stringify(facts, "  "))
    file.close()
    print("Ruttfakta: ", ProjectSettings.globalize_path(Routes.FACTS_PATH))
    get_tree().quit()


## Render the world-select picture: the real world cut out as a floating diorama, on a
## transparent background (the card paints the sky gradient behind it).
## --worldthumb [--world=skargarden]  writes the world's "thumb" path (res://…/kort.png).
func _worldthumb(dev: Dictionary) -> void:
    var id: String = dev.get("world", "skargarden")
    get_viewport().transparent_bg = true
    _bg.visible = false
    var w: Node3D = load(WORLDS[id]["script"]).new()
    w.set("diorama", true)
    add_child(w)
    for i in 30:
        await get_tree().process_frame
    await RenderingServer.frame_post_draw
    var image := get_viewport().get_texture().get_image()
    var used := image.get_used_rect()          # crop to the island and its rocks
    image = image.get_region(used.grow(24).intersection(Rect2i(Vector2i.ZERO, image.get_size())))
    image.resize(1400, roundi(1400.0 * image.get_height() / image.get_width()), Image.INTERPOLATE_LANCZOS)
    var path := ProjectSettings.globalize_path(WORLDS[id]["diorama"])
    image.save_png(path)
    print("Kort sparat: %s (%dx%d)" % [path, image.get_width(), image.get_height()])
    get_tree().quit()


## Strava against a local mock (tests/strava_mock.py): login, token refresh, upload, duplicate,
## and a login answer with the wrong state. The real strava.com is never contacted.
func _stravatest(base: String) -> void:
    get_tree().create_timer(90.0).timeout.connect(func():
        print("STRAVATEST: avbrutet efter 90 s")
        get_tree().quit(2))
    var failures := 0
    var check := func(ok: bool, what: String) -> int:
        print("  %s  %s" % ["ok " if ok else "FEL", what])
        return 0 if ok else 1
    Strava.unlink()
    Strava.api_base = base
    Strava.set_app("12345", "test-secret")
    var url := Strava.begin_login()
    failures += check.call(url.contains("client_id=12345") and url.contains("redirect_uri=http%3A%2F%2Flocalhost%3A47012%2Fstrava")
        and url.contains("activity%3Awrite"), "inloggningsadressen har client_id, redirect och scope")
    var page := await _fake_browser("/strava?state=%s&code=testcode&scope=read,activity:write" % Strava.pending_state())
    failures += check.call(page.contains("Klart!"), "webbläsaren får svaret Klart")
    for i in 300:
        if Strava.is_linked():
            break
        await get_tree().process_frame
    failures += check.call(Strava.is_linked() and Strava.athlete_name == "Test Testsson", "kopplad som Test Testsson")

    Ride.start_workout(find_workout("sotpunkten"), true)
    for i in 120:
        Ride.step(1.0)
    Ride.finish()
    Strava.expires_at = 0   # force a token refresh before the upload
    Strava.upload(Ride.fit_path, "Sötpunkten", "test")
    var first: Array = await Strava.upload_finished
    failures += check.call(first[0] and first[2] == "https://www.strava.com/activities/777", "uppladdning blir aktivitet 777 (%s)" % first[1])
    failures += check.call(Strava.access_token == "acc2", "nyckeln förnyades före uppladdningen")
    Strava.upload(Ride.fit_path, "Sötpunkten", "test")
    var second: Array = await Strava.upload_finished
    failures += check.call(not second[0] and second[1].contains("dubblett"), "dubblett känns igen (%s)" % second[1])

    Strava.begin_login()
    page = await _fake_browser("/strava?state=fel&code=x&scope=read,activity:write")
    failures += check.call(page.contains("hörde inte"), "svar med fel state avvisas")
    Strava.begin_login()
    page = await _fake_browser("/strava?state=%s&code=testcode&scope=read" % Strava.pending_state())
    failures += check.call(page.contains("kryssa i"), "inloggning utan uppladdningsrätt avvisas")
    print("STRAVATEST: %d fel" % failures)
    get_tree().quit(1 if failures > 0 else 0)


## Act as the browser returning from Strava: send one GET to the local callback port.
func _fake_browser(path: String) -> String:
    var peer := StreamPeerTCP.new()
    peer.connect_to_host("127.0.0.1", Strava.CALLBACK_PORT)
    for i in 300:
        peer.poll()
        if peer.get_status() == StreamPeerTCP.STATUS_CONNECTED:
            break
        await get_tree().process_frame
    peer.put_data(("GET %s HTTP/1.1\r\nHost: localhost\r\n\r\n" % path).to_utf8_buffer())
    var text := ""
    for i in 300:
        await get_tree().process_frame
        peer.poll()
        var available := peer.get_available_bytes()
        if available > 0:
            text += peer.get_utf8_string(available)
        if text.contains("</body>"):
            break
    return text


## Closing the window mid-ride shows the question; "Spara turen" ends on the summary.
func _closetest() -> void:
    var failures := 0
    begin_ride({"mode": "workout", "workout": find_workout("sotpunkten"), "erg": true, "world": ""})
    for i in 60:
        Ride.step(1.0)
    _notification(NOTIFICATION_WM_CLOSE_REQUEST)
    await get_tree().process_frame
    failures += 0 if _close_dialog != null else 1
    print("  %s  frågan visas när man stänger mitt i turen" % ["ok " if _close_dialog else "FEL"])
    _press(_close_dialog, "Fortsätt cykla")
    await get_tree().process_frame
    print("  %s  Fortsätt cykla stänger frågan och turen fortsätter" % ["ok " if _close_dialog == null and Ride.state == Ride.State.RIDING else "FEL"])
    failures += 0 if _close_dialog == null and Ride.state == Ride.State.RIDING else 1
    _notification(NOTIFICATION_WM_CLOSE_REQUEST)
    await get_tree().process_frame
    _press(_close_dialog, "Spara turen")
    await get_tree().process_frame
    var saved: bool = current.get_script() == SCREENS["summary"] and Ride.fit_path != ""
    print("  %s  Spara turen visar sammanfattningen med sparad FIT" % ["ok " if saved else "FEL"])
    failures += 0 if saved else 1
    print("STÄNGTEST: %d fel" % failures)
    get_tree().quit(1 if failures > 0 else 0)


## Connect to Cykelbrygga and print what arrives for 15 s. No ride is started, so no trainer
## command is ever sent (only pings). Start the bridge with --read-only first to be doubly safe.
## --byttrainer: then pick a trainer that does not exist (the bridge must let go of the one it has)
## and the first one again (it must come back), the way the list in the settings does it.
func _bridgecheck(launch: bool, switch := false) -> void:
    Settings.source = "sim"
    Ride.apply_settings()
    Ride.sim = null
    Ride.bridge = preload("res://core/bridge_client.gd").new()
    var path: String = Ride.bridge.bridge_path()
    print("  brygga: %s (%s)" % [path, "finns" if Ride.bridge.bridge_exists() else "saknas"])
    Ride.bridge.start(launch)
    for i in 5:
        await get_tree().create_timer(3.0).timeout
        print("  %2d s: %s | %d W, %d rpm, puls %d" % [(i + 1) * 3, Ride.source_description(),
            roundi(Ride.bridge.power), roundi(Ride.bridge.cadence), roundi(Ride.bridge.hr)])
    var ok: bool = Ride.bridge.ready_to_ride()
    if switch and ok:
        var first: String = Ride.bridge.connected_trainer()
        print("  hittade: %s" % ", ".join(Ride.bridge.trainers().map(func(t): return str(t.get("name")))))
        for step in [["00000000-0000-0000-0000-000000000001", "Testtrainer", 3], [first, "", 5]]:
            Ride.bridge.wanted_trainer = step[0]
            Ride.bridge.wanted_name = step[1]
            for i in step[2]:
                await get_tree().create_timer(3.0).timeout
                print("  vald %s, %2d s: %s" % [step[1] if step[1] != "" else "den första igen", (i + 1) * 3, Ride.source_description()])
            if step[1] != "" and Ride.bridge.connected_trainer() != "":
                ok = false
                print("  FEL: bryggan släppte inte trainern")
        ok = ok and Ride.bridge.connected_trainer() == first and Ride.bridge.ready_to_ride()
    print("BRYGGTEST: %s" % ("ok" if ok else "trainern inte redo"))
    Ride.bridge.stop()
    Ride.bridge = null
    get_tree().quit()


## --provtrainers[=oppen|nederst] (with --screen=settings --tab=hardvara): the trainer list as it looks
## with two smart trainers and a power meter found (oppen: the list open, nederst: scrolled down). A pretend bridge: nothing goes to Bluetooth, and its
## pings go to the discard port, so a running Cykelbrygga never hears them.
func _fake_trainers(how: String) -> void:
    Ride.sim = null
    var fake = preload("res://core/bridge_client.gd").new()
    fake._udp.set_dest_address("127.0.0.1", 9)
    fake.status = {"t": "status", "trainer": "KICKR CORE 1A2B", "trainerId": "A", "trainerState": "klar",
        "hr": null, "control": "ingen", "clicks": 0, "spindown": false, "trainers": [
            {"id": "A", "name": "KICKR CORE 1A2B", "smart": true},
            {"id": "B", "name": "Tacx Neo 2T", "smart": true},
            {"id": "C", "name": "Assioma Duo", "smart": false}]}
    Ride.bridge = fake
    get_tree().process_frame.connect(func(): fake._last_status_ms = Time.get_ticks_msec())
    await get_tree().create_timer(1.0).timeout
    if how == "nederst":
        for sc in find_children("*", "ScrollContainer", true, false):
            sc.scroll_vertical = 100000
    if how == "oppen":
        for o in find_children("*", "OptionButton", true, false):
            if o.item_count > 1 and o.get_item_text(0) == tr("Första smarta trainern"):
                o.show_popup()


## Click through the app like a user (buttons and cards found by their text) and check each step.
func _flowtest() -> void:
    Settings.world = ""
    for f in DirAccess.get_files_at(custom_dir):        # the developer copy of your own workouts
        DirAccess.remove_absolute(ProjectSettings.globalize_path(custom_dir.path_join(f)))
    reload_workouts()
    get_tree().create_timer(180.0).timeout.connect(func():
        print("FLÖDESTEST: avbrutet efter 180 s")
        get_tree().quit(2))
    go("menu")
    var failures := 0
    # A Click button message over UDP reaches the game (the bridge itself is not started here).
    var client = preload("res://core/bridge_client.gd").new()
    client.start(false)
    var peer := PacketPeerUDP.new()
    peer.set_dest_address("127.0.0.1", client.IN_PORT)
    peer.put_packet(JSON.stringify({"t": "button", "id": "v_upp", "down": true}).to_utf8_buffer())
    await get_tree().create_timer(0.2).timeout
    client.poll(0.0)
    var got: Array = client.take_buttons()
    var udp_ok: bool = got.size() == 1 and got[0][0] == "v_upp" and got[0][1] == true
    if client.error != "":
        print("  ok   udp knapp hoppas över: en annan Cykelapp använder porten just nu")
    else:
        print("  %s  udp knapp" % ["ok " if udp_ok else "FEL"])
        if not udp_ok:
            failures += 1
    # The calibration: the bridge's spin down messages become the right words on the settings page.
    var spin_ok := true
    for m in [[{"t": "spindown", "state": "trampa", "low": 30.0, "high": 35.0}, "35 km/h"],
            [{"t": "spindown", "state": "sluta"}, "Sluta trampa"], [{"t": "spindown", "state": "klar"}, "✓"],
            [{"t": "spindown", "state": "fel", "reason": "stöds inte"}, "Wahoo"]]:
        peer.put_packet(JSON.stringify(m[0]).to_utf8_buffer())
        await get_tree().create_timer(0.1).timeout
        client.poll(0.0)
        spin_ok = spin_ok and client.describe_spindown().contains(m[1])
    if client.error == "":
        print("  %s  kalibreringens texter" % ["ok " if spin_ok else "FEL"])
        if not spin_ok:
            failures += 1
    client.stop()
    peer.close()
    var steps := [
        ["card", "Träningspass", "library"],
        ["button", "Egna pass", "library"],
        ["button", "+ Nytt pass", "workout_editor"],
        ["button", "+ Intervaller", "workout_editor"],
        ["button", "Spara passet", "detail"],
        ["check", "own-saved", ""],
        ["button", "Ändra passet", "workout_editor"],
        ["button", "Ta bort passet", "workout_editor"],
        ["button", "Säker? Tryck igen", "library"],
        ["check", "own-deleted", ""],
        ["card", "Sötpunkten", "detail"],
        ["button", "SIM", "detail"],
        ["button", "Starta passet", "ride"],
        ["check", "sim-mode", ""],
        ["ride", "30", ""],
        ["button", "Byt till ERG", "ride"],
        ["check", "erg-mode", ""],
        ["button", "Pausa passet", "ride"],
        ["check", "paused", ""],
        ["button", "Fortsätt passet", "ride"],
        ["button", "Hoppa över steg", "ride"],
        ["check", "segment-1", ""],
        ["button", "Avsluta", "summary"],
        ["check", "fit-saved", ""],
        ["button", "Till menyn", "menu"],
        ["card", "Inställningar", "settings"],
        ["button", "Hårdvara", "settings"],
        ["button", "Skärmen", "settings"],
        ["button", "Knappar", "settings"],
        ["check", "button-page", ""],
        ["button", "‹  Meny", "menu"],
        ["card", "Garaget", "garage"],
        ["button", "Tröjor", "garage"],
        ["button", "Stridsvagnen", "garage"],
        ["button", "Rekord", "garage"],
        ["check", "garage", ""],
        ["button", "‹  Meny", "menu"],
        ["card", "Fri cykling", "ride"],
        ["button", "Håll watt (ERG)", "ride"],
        ["check", "erg-mode", ""],
        ["button", "+", "ride"],
        ["check", "free-160", ""],
        ["ride", "20", ""],
        ["button", "Avsluta", "summary"],
        ["button", "Till menyn", "menu"],
        ["card", "Skärgården", "menu"],        # the world's miniature on the start screen
        ["check", "world-chosen", ""],
        ["card", "Fri cykling", "world_hud"],
        ["check", "world-built", ""],
        ["ride", "60", ""],
        ["check", "world-grade", ""],
        ["check", "route-on", ""],
        ["check", "pacers", ""],
        ["check", "maps", ""],
        ["check", "gears", ""],
        ["button", "⚙ Inställningar", "world_hud"],
        ["check", "settings-open", ""],
        ["button", "Ljud", "world_hud"],
        ["check", "settings-sound", ""],
        ["ride", "5", ""],
        ["button", "‹  Tillbaka till turen", "world_hud"],
        ["check", "settings-closed", ""],
        ["click", "v_hoger", ""],
        ["check", "steered", ""],
        ["button", "Tryck ej här", "world_hud"],
        ["check", "roam-on", ""],
        ["check", "route-broken", ""],
        ["ride", "20", ""],
        ["check", "roam-moving", ""],
        ["check", "fri-vag", ""],
        ["check", "fri-styr", ""],
        ["check", "fri-vatten", ""],
        ["check", "fri-loss", ""],
        ["check", "bas-stridsvagn", ""],
        ["check", "skott", ""],
        ["check", "monster", ""],
        ["teleport", "egypten", ""],
        ["check", "in-egypt", ""],
        ["check", "egypt-battle", ""],
        ["teleport", "japan", ""],
        ["check", "in-japan", ""],
        ["check", "japan-battle", ""],
        ["teleport", "skargarden", ""],
        ["check", "arrived-dry", ""],
        ["button", "Tillbaka till vägen", "world_hud"],
        ["check", "roam-off", ""],
        ["ride", "10", ""],
        ["check", "world-grade", ""],
        ["button", "Avsluta", "summary"],
        ["check", "world-gone", ""],
        ["check", "fit-virtual", ""],
        ["check", "progress", ""],
        ["check", "pretend-xp", ""],
        ["button", "Till menyn", "menu"],
        ["button", "Historik", "history"],
        ["check", "history", ""],
        ["button", "‹  Meny", "menu"],
        ["card", "Träningspass", "library"],
        ["button", "Egna pass", "library"],
        ["card", "Sötpunkten", "detail"],
        ["button", "Starta passet", "world_hud"],
        ["ride", "30", ""],
        ["click", "h_vaxla", ""],
        ["check", "pushed", ""],
        ["button", "Tryck ej här", "world_hud"],
        ["ride", "10", ""],
        ["check", "pass-fri", ""],
        ["button", "Eget motstånd", "world_hud"],
        ["ride", "3", ""],
        ["check", "eget", ""],
        ["click", "h_vaxla", ""],
        ["check", "eget-tyngre", ""],
        ["button", "Passet (ERG)", "world_hud"],
        ["ride", "3", ""],
        ["check", "pass-fri", ""],
        ["button", "Tillbaka till vägen", "world_hud"],
        ["check", "roam-off", ""],
        ["button", "Hoppa över", "world_hud"],
        ["check", "segment-1", ""],
        ["button", "Avsluta", "summary"],
        ["button", "Till menyn", "menu"],
    ]
    for s in steps:
        var ok := true
        match s[0]:
            "card":
                ok = _click_card(current, s[1])
            "button":
                ok = _press(current, s[1])
            "ride":
                for i in int(s[1]):
                    Ride.step(1.0)
                await get_tree().process_frame    # let the ride screen update the world
            "teleport":
                # Ride through this world's teleport gate; the app swaps the world under the ride.
                ok = await _teleport_check(s[1])
            "click":
                # A Zwift Click button held for a few frames, as the bridge would report it.
                Controls.press(s[1], true)
                for i in 12:
                    await get_tree().process_frame
                Controls.press(s[1], false)
            "check":
                match s[1]:
                    "sim-mode":
                        ok = not Ride.erg
                    "erg-mode":
                        ok = Ride.erg
                    "paused":
                        ok = Ride.paused
                    "segment-1":
                        ok = Ride.player != null and Ride.player.index() == 1
                    "free-160":
                        ok = Ride.free_watts == 160
                    "world-chosen":
                        ok = Settings.world == "skargarden"
                    "own-saved":
                        # A new workout of your own, with the intervals added, saved and shown.
                        var w = current.get("args").get("workout") if current.get("args") else null
                        ok = w != null and str(w.id).begins_with("egen-") and w.custom and w.segments.size() > 3
                        ok = ok and FileAccess.file_exists(custom_dir.path_join(w.id + ".json"))
                    "own-deleted":
                        ok = workouts.all(func(x): return not str(x.id).begins_with("egen-mitt-pass"))
                    "route-on":
                        ok = str(Ride.route.get("id", "")) == "varvet" and Ride.route_state == "" \
                            and is_equal_approx(float(Ride.route["length_m"]), world.length)
                    "route-broken":
                        await get_tree().process_frame
                        ok = Ride.route_state == "avbruten"
                    "pacers":
                        # Three pacers; right behind one you are in its draft, far off you are not.
                        var p = current.get("_pacers")
                        ok = p != null and p.riders.size() == 3 and p.nearby(0.0).size() == 3
                        if ok:
                            var me: float = current._lap_s()
                            p.riders[0]["s"] = me + 3.0
                            var near: float = p.update(0.0, me, true)
                            for r in p.riders:
                                r["s"] = me + 500.0
                            var far: float = p.update(0.0, me, true)
                            p.riders[1]["s"] = me + 3.0
                            var free: float = p.update(0.0, me, false)
                            print("       draft 3 m bakom: %.2f, långt ifrån: %.2f, fri cykling: %.2f" % [near, far, free])
                            ok = near > 0.15 and near <= 0.33 and far == 0.0 and free == 0.0
                    "maps":
                        var m = current.get("_map")
                        ok = m != null and m._texture != null
                        current._toggle_big_map()
                        ok = ok and current._big_map != null
                        await get_tree().process_frame
                        current._toggle_big_map()
                        ok = ok and current._big_map == null
                    "gears":
                        # Gear 24 in SIM: k times the grade and rolling resistance, k³ times the air.
                        Ride.set_mode("sim")
                        Ride.gear = Ride.GEAR_COUNT
                        var k: float = Ride.gear_ratio(Ride.GEAR_COUNT) / Ride.gear_ratio(Ride.GEAR_NEUTRAL)
                        ok = is_equal_approx(Ride.gear_factor(), k) and k > 2.0 \
                            and is_equal_approx(Ride.trainer_crr(), Ride.TRAINER_CRR * k) \
                            and is_equal_approx(Ride.trainer_cw(), Ride.TRAINER_CW * k * k * k * (1.0 - Ride.draft)) \
                            and is_equal_approx(Ride.felt_grade(), Ride.grade_ahead * Settings.trainer_difficulty * k)
                        Ride.gear = Ride.GEAR_NEUTRAL
                        ok = ok and is_equal_approx(Ride.gear_factor(), 1.0)
                    "world-built":
                        ok = world != null and world.length > 2000.0
                    "world-grade":
                        # The ride screen has been feeding the road's grade to the engine.
                        ok = world != null and is_equal_approx(Ride.grade, world.grade_at(world.lap_distance(Ride.distance)))
                        # …and the trainer is sent the road 1.5 s ahead, softened by the trainer difficulty.
                        ok = ok and is_equal_approx(Ride.grade_ahead, world.current_grade(Ride.distance + Ride.speed * Ride.GRADE_LOOKAHEAD))
                        ok = ok and (Ride.mode() != "sim" or is_equal_approx(Ride.felt_grade(), Ride.grade_ahead * Settings.trainer_difficulty * Ride.gear_factor()))
                    "roam-off":
                        # Back on the lap where the free ride ended: no tank, the bike on the road.
                        if world != null:
                            var on_lap: Vector3 = world.sample(world.lap_distance(Ride.distance))["pos"]
                            var gap: float = Vector2(world.rider.position.x - on_lap.x, world.rider.position.z - on_lap.z).length()
                            print("       tillbaka på varvet: %.1f m från vägen, stridsvagn kvar: %s" % [gap, world.strid != null])
                            ok = not world.roam and world.strid == null and world.rider.visible and gap < 4.0 \
                                and (world.base_tank == null or world.base_tank.visible)
                        else:
                            ok = false
                    "pass-fri":
                        # Free riding in a workout: the workout still runs and drives the trainer.
                        ok = world != null and world.roam and Ride.player != null and Ride.erg and Ride.target_watts() > 0 \
                            and Ride.sim.erg_target > 0
                    "eget":
                        # Own resistance: the trainer gets the chosen level as a steady grade.
                        _level_from = Ride.manual_level
                        ok = Ride.manual and Ride.target_watts() == -1 and is_equal_approx(Ride.sim.grade, float(Ride.manual_level)) \
                            and Ride.sim.erg_target == -1
                    "eget-tyngre":
                        ok = Ride.manual and Ride.manual_level == mini(_level_from + 1, 10)
                    "world-gone":
                        ok = world == null and _bg.visible
                    "fit-virtual":
                        ok = Ride.summary.get("world", "") in ["Skärgården", "Egypten"]
                    "arrived-dry":
                        ok = world != null and world.lap_name() == "Kustvägen" and world.roam and _arrival_ok(world)
                    "egypt-battle":
                        ok = world != null and _egypt_battle(world)
                    "in-japan":
                        ok = world != null and world.lap_name() == "Sakuravägen" and world.roam and _arrival_ok(world)
                    "japan-battle":
                        ok = world != null and _japan_battle(world)
                    "in-egypt":
                        ok = world != null and world.lap_name() == "Nilvägen" and world.roam and current.get_script() == SCREENS["world_hud"]
                    "fit-saved":
                        ok = Ride.fit_path != "" and FileAccess.file_exists(Ride.fit_path)
                    "history":
                        # Every finished ride is in the history, newest first, with its numbers.
                        var rides: Array = Progress.data["rides"]
                        print("       historik: %d turer, senaste %s" % [rides.size(), rides[-1].get("name", "") if not rides.is_empty() else "-"])
                        ok = current.get_script() == SCREENS["history"] and rides.size() >= 2 \
                            and rides[-1].has("curve")
                    "garage":
                        # The records tab with the power curve and a card per world.
                        ok = current.get_script() == SCREENS["garage"] and current._tab == "rekord" \
                            and current._content.get_child_count() >= 1 + WORLDS.size()
                    "progress":
                        # The ride gave XP (its kilojoules at least) and the summary shows it.
                        var r: Dictionary = Ride.progress_report
                        print("       XP %d, nivå %d → %d" % [r.get("xp", 0), r.get("level_before", 0), r.get("level_after", 0)])
                        ok = int(r.get("xp", 0)) > 0 and current.get_script() == SCREENS["summary"]
                    "pretend-xp":
                        ok = _pretend_xp()
                    "settings-open":
                        # Over the ride: the HUD is still the screen and the ride goes on.
                        ok = current.get("_settings") != null and Ride.state == Ride.State.RIDING \
                            and current.find_children("*", "OptionButton", true, false).size() >= Controls.BUTTONS.size()
                    "settings-sound":
                        ok = current.get("_settings") != null and current.find_children("*", "HSlider", true, false).size() > 0
                    "settings-closed":
                        ok = current.get("_settings") == null and Ride.state == Ride.State.RIDING
                    "button-page":
                        ok = current.find_children("*", "OptionButton", true, false).size() >= Controls.BUTTONS.size()
                    "steered":
                        ok = world != null and world.lateral > 0.0
                    "roam-on":
                        ok = world != null and world.roam
                        _free_from = world.fri.distance if ok else 0.0
                    "roam-moving", "fri-vag", "fri-styr", "fri-vatten", "fri-loss", "bas-stridsvagn", "skott", "monster":
                        ok = world != null and world.roam and _free_check(world, s[1])
                    "pushed":
                        ok = (Ride.player != null and Ride.player.intensity > 1.0) or Ride.gear > Ride.GEAR_NEUTRAL
        await get_tree().process_frame
        if ok and s[2] != "":
            for i in 300:          # a ride into a world builds it behind a cover first (begin_ride)
                if current.get_script() == SCREENS[s[2]] and not _loading:
                    break
                await get_tree().process_frame
            ok = current.get_script() == SCREENS[s[2]]
        print("  %s  %s %s" % ["ok " if ok else "FEL", s[0], s[1]])
        if not ok:
            failures += 1
    print("FLÖDESTEST: %d fel" % failures)
    get_tree().quit(1 if failures > 0 else 0)


var _free_from := 0.0
var _level_from := 0


## Free riding and the battle, driven directly (no real time): the road assist keeps the bike on
## the road, a firm turn takes it off, the shore stops it, the base's tank is taken, a shell kills
## a zombie, and monsters and the UFO arrive.
func _free_check(w, what: String) -> bool:
    var dt := 1.0 / 8.0          # 8 m/s at 1 m per frame
    match what:
        "roam-moving":
            return w.roam and w.fri.distance > _free_from + 5.0
        "fri-vag":
            var s := 1000.0
            var here: Dictionary = w.sample(s)
            var d: Vector3 = here["dir"]
            var flat := Vector2(d.x, d.z).normalized()
            var start: Vector3 = here["pos"] + Vector3(-flat.y, 0, flat.x) * w.RIDE_OFFSET
            w.fri.start(start, flat.rotated(0.12))
            w.fri.steer = 0.0
            var worst := 0.0
            for i in 150:
                w.fri.advance(1.0, dt)
                worst = maxf(worst, w.fri.road.get("d", 99.0) if not w.fri.road.is_empty() else 99.0)
            print("       vägassistans: längst %.1f m från mittlinjen på 150 m" % worst)
            return worst < 2.6
        "fri-styr":
            var s: float = w._nearest_s(Vector2(560.0, -150.0))
            var here: Dictionary = w.sample(s)
            var d: Vector3 = here["dir"]
            var flat := Vector2(d.x, d.z).normalized()
            w.fri.start(here["pos"], flat)
            var hp: Vector3 = here["pos"]
            var to_base := Vector2(w.BASE.x - hp.x, w.BASE.z - hp.z)
            w.fri.steer = signf(Vector2(-flat.y, flat.x).dot(to_base))
            for i in 12:
                w.fri.advance(1.0, dt)
            w.fri.steer = 0.0
            for i in 30:
                w.fri.advance(1.0, dt)
            var off: float = 99.0 if w.fri.road.is_empty() or w.fri.road["k"] == 0 else w.fri.road["d"]
            var lap_pt: Vector3 = w.sample(w._nearest_s(Vector2(w.fri.pos.x, w.fri.pos.z)))["pos"]
            var lap: float = Vector2(w.fri.pos.x, w.fri.pos.z).distance_to(Vector2(lap_pt.x, lap_pt.z))
            var turned := absf(rad_to_deg(flat.angle_to(w.fri.heading)))
            print("       styrning: %.0f m från varvet, svängt %.0f°" % [lap, turned])
            return lap > 6.0 and turned > 30.0 and off > 0.0
        "fri-vatten":
            # Find the shore east of the base, start 30 m short of it and ride 80 m straight at it.
            var shore := 700.0
            while shore < 1000.0 and w._mesh_height(shore, -165.0) > 0.0:
                shore += 1.0
            w.fri.start(Vector3(shore - 30.0, 0, -165.0), Vector2(1, 0))
            w.fri.steer = 0.0
            var dry := true
            for i in 80:
                w.fri.advance(1.0, dt)
                dry = dry and w._mesh_height(w.fri.pos.x, w.fri.pos.z) > 0.0
            print("       strandkanten vid x %.0f: cykeln står vid x %.0f, z %.0f, höjd %.1f m" % [shore, w.fri.pos.x, w.fri.pos.z, w.fri.pos.y])
            return dry
        "fri-loss":
            # Standing in the water (as a bad landing could leave you): ride towards the shore and
            # get out instead of being stuck.
            var shore := 700.0
            while shore < 1000.0 and w._mesh_height(shore, -165.0) > 0.0:
                shore += 1.0
            w.fri.start(Vector3(shore + 6.0, 0, -165.0), Vector2(-1, 0))
            w.fri.steer = 0.0
            for i in 30:
                w.fri.advance(1.0, dt)
            var out: bool = w._mesh_height(w.fri.pos.x, w.fri.pos.z) > 0.15
            print("       ur vattnet: startade vid x %.0f, står nu vid x %.0f på land: %s" % [shore + 6.0, w.fri.pos.x, out])
            return out
        "bas-stridsvagn":
            w.place_free(w.BASE.x - 30.0, w.BASE.z + 1.0, 0.0)
            var at: float = w._roam_last
            for i in 40:
                at += 1.0
                w.update_view(at, 8.0, 85.0, dt)
                if w.strid:
                    break
            return w.strid != null and w.fri.radius > 1.0
        "skott":
            var st = w.strid
            var h: Vector2 = w.fri.heading
            var p := Vector2(w.fri.pos.x, w.fri.pos.z) + h * 40.0
            var zy: float = w.ride_height(p.x, p.y)
            var z = st.spawn("zombie", Vector3(p.x, zy, p.y))
            z._enter("chase")
            w.orbit = 0.0
            st._choose_target()
            st.place_tank(w.fri, 1.0)
            st._choose_target()
            st.place_tank(w.fri, 1.0)
            var fired: bool = st.fire()
            for i in 120:
                st._update_shells(0.05)
                st._update_pending(0.05)
                if z.dead:
                    break
            print("       skott: låst mål %s, avfyrat %s, zombien träffad %s, %d poäng" % [st.target == z, fired, z.dead, st.score])
            return fired and z.dead and st.score >= 10
        "monster":
            var st = w.strid
            for i in 10:
                st._spawn(5.0)
            st._ufo_t = 0.0
            st._update_ufo(0.1)
            print("       monster: %d på ön, UFO %s" % [st.alive_count(), st.ufo != null])
            return st.alive_count() > 0 and st.ufo != null
    return false


## After a teleport: standing on dry ground (or a bridge deck) and able to ride on from there.
func _arrival_ok(w) -> bool:
    var p: Vector3 = w.fri.pos
    var dry: bool = w.free_at(p.x, p.z, w.fri.radius)
    var start := Vector2(p.x, p.z)
    w.fri.steer = 0.0
    for i in 16:
        w.fri.advance(1.0, 0.125)
    var moved := start.distance_to(Vector2(w.fri.pos.x, w.fri.pos.z))
    print("       framme i %s: torrt %s, cyklade %.0f m av 16" % [w.lap_name(), dry, moved])
    return dry and moved > 8.0


## Japan's battle: ride through the waterfall gorge to the samurai, throw stars at an oni until it
## falls (three hits), and the dragon arrives.
func _japan_battle(w) -> bool:
    var tank: Vector3 = w.base_tank.position
    w.place_free(tank.x, tank.z - 12.0, 90.0)
    var at: float = w._roam_last
    for i in 30:
        at += 1.0
        w.update_view(at, 6.0, 85.0, 0.125)
        if w.strid:
            break
    if w.strid == null:
        print("       kom aldrig fram till samurajen")
        return false
    var st = w.strid
    var h: Vector2 = w.fri.heading
    var p := Vector2(w.fri.pos.x, w.fri.pos.z) + h * 20.0
    var oy: float = w.ride_height(p.x, p.y)
    var oni = st.spawn("oni", Vector3(p.x, oy, p.y))
    oni._enter("chase")
    w.orbit = 0.0
    var throws := 0
    for i in 300:
        st._choose_target()
        st.place_tank(w.fri, 0.05)
        st._reload -= 0.05
        if st.fire():
            throws += 1
        st._update_shells(0.05)
        if oni.dead:
            break
    st._ufo_t = 0.0
    st._update_ufo(0.1)
    print("       Japan: %s, %d kast, oni fälld %s, %d poäng, drake %s" % [st.theme["vehicle"], throws, oni.dead, st.score,
        st.ufo != null])
    return st.theme["vehicle"] == "samurai" and oni.dead and st.score >= 15 and st.ufo != null


## Egypten's battle: ride to the pickup at the dig camp, fire the machine gun at a mummy until it
## falls (four hits), and the pharaoh rises.
func _egypt_battle(w) -> bool:
    var tank: Vector3 = w.base_tank.position
    w.place_free(tank.x - 12.0, tank.z, 0.0)
    var at: float = w._roam_last
    for i in 30:
        at += 1.0
        w.update_view(at, 8.0, 85.0, 0.125)
        if w.strid:
            break
    if w.strid == null:
        print("       kom aldrig fram till flakbilen")
        return false
    var st = w.strid
    var h: Vector2 = w.fri.heading
    var p := Vector2(w.fri.pos.x, w.fri.pos.z) + h * 35.0
    var my: float = w.ride_height(p.x, p.y)
    var mummy = st.spawn("mumie", Vector3(p.x, my, p.y))
    mummy._enter("chase")
    w.orbit = 0.0
    var shots := 0
    for i in 300:
        st._choose_target()
        st.place_tank(w.fri, 0.05)
        st._reload -= 0.05
        if st.fire():
            shots += 1
        st._update_shells(0.05)
        if mummy.dead:
            break
    st._boss_t = 0.0
    st._update_walking_boss(0.1)
    print("       Egypten: %s, %d skott, mumien fälld %s, %d poäng, farao %s" % [st.theme["vehicle"], shots, mummy.dead, st.score,
        st.boss != null])
    return st.theme["vehicle"] == "flakbil" and mummy.dead and shots >= 4 and st.score >= 10 and st.boss != null


## Free riding through the gate: the world says where to go, main.gd builds the other world, the
## rider arrives just past its gate, still riding free, and the ride carries on.
func _teleport_check(target: String) -> bool:
    if world == null or world.teleports.is_empty():
        print("       ingen teleportbro i världen")
        return false
    if world.strid:
        world.end_roam(Ride.distance)
        world.start_roam(Ride.distance)
    var gate: Vector3 = world.teleports[0][0]
    var dir: Vector3 = world.teleports[0][2]
    var from := gate - dir * 12.0
    world.place_free(from.x, from.z, rad_to_deg(atan2(dir.z, dir.x)))
    var at: float = world._roam_last
    for i in 40:
        at += 1.0
        world.update_view(at, 8.0, 85.0, 0.125)
        if world.teleport_to != "":
            break
    var asked: String = world.teleport_to
    var before := Ride.distance
    if asked == "":
        print("       kom aldrig igenom porten")
        return false
    await teleport(asked)
    print("       teleport till %s: %s, ny värld %s, turen fortsätter: %s" % [target, asked, Ride.world_name, Ride.distance >= before])
    return asked == target and Ride.world_name == WORLDS[target]["name"] and world.roam


## --fri=x,z,degrees puts the free rider there; --strid also hands over the base's tank.
func _dev_free(w, dev: Dictionary) -> void:
    if not w.roam:
        w.start_roam(0.0)
    if dev.has("fri"):
        var v: PackedStringArray = str(dev["fri"]).split(",")
        w.place_free(float(v[0]), float(v[1]), float(v[2]) if v.size() > 2 else 0.0)
    if dev.has("profil"):
        # --profil: the ground under the free ride's heading, every 5 m for 60 m.
        var h: Vector2 = w.fri.heading
        var line := ""
        for k in 13:
            var p := Vector2(w.fri.pos.x, w.fri.pos.z) + h * (k * 5.0)
            var r: Dictionary = w.road_near(p.x, p.y)
            line += "%.1f%s " % [w.ride_height(p.x, p.y), "v" if not r.is_empty() and r["d"] < 1.8 else ""]
        print("Marken framåt (var 5:e m): ", line)
    if dev.has("strid"):
        w.take_tank()
        w.fri.start(Vector3(w.fri.pos.x, 0, w.fri.pos.z), w.fri.heading)
        if dev.has("fri"):
            var v: PackedStringArray = str(dev["fri"]).split(",")
            w.place_free(float(v[0]), float(v[1]), float(v[2]) if v.size() > 2 else 0.0)
        w.strid.place_tank(w.fri, 0.0)
        # --monster=N: N monsters already on their way, 25–70 m ahead; --ufo: the UFO overhead.
        if dev.has("autoskott"):
            w.strid.auto_fire = true
        for i in int(dev.get("monster", "0")):
            var at: Vector3 = w.strid._spawn_point(25.0, 70.0)
            if at != Vector3.INF:
                var cast: Array = w.strid.theme["monsters"]
                var m = w.strid.spawn(cast[i % cast.size()][0], at)
                m._enter("chase")
        if dev.has("boss"):
            w.strid._boss_t = 0.0      # --boss: the walking boss (the pharaoh) right away
        if dev.has("ufo"):
            w.strid._ufo_t = 0.0
            w.strid._update_ufo(0.0)
            var h: Vector2 = w.fri.heading
            w.strid.ufo.position = w.fri.pos + Vector3(h.x, 0, h.y) * 70.0 + Vector3.UP * 30.0


func _press(root: Node, text: String) -> bool:
    for node in root.find_children("*", "Button", true, false):
        if node.text == text and not node.disabled:
            node.pressed.emit()
            return true
    return false


func _click_card(root: Node, text: String) -> bool:
    for node in root.find_children("*", "Label", true, false):
        if node.text != text:
            continue
        var card: Node = node.get_parent()
        while card and not (card is Control and card.mouse_filter == Control.MOUSE_FILTER_STOP):
            card = card.get_parent()
        if card:
            var click := InputEventMouseButton.new()
            click.button_index = MOUSE_BUTTON_LEFT
            click.pressed = true
            card.gui_input.emit(click)
            return true
    return false


## A ride on the pretend trainer (here a made-up steady 900 W) gives no XP, is not kept and sets no
## records or FTP, and the summary says so. Only in memory: a developer run.
func _pretend_xp() -> bool:
    var xp_before := Progress.xp()
    var rides_before: int = Progress.data["rides"].size()
    var bests_before := JSON.stringify(Progress.data["bests"])
    var ftp_before := Settings.ftp
    var auto_before := Settings.auto_ftp
    Settings.auto_ftp = true
    var watts := PackedFloat32Array()
    watts.resize(25 * 60)
    watts.fill(900.0)
    Progress.begin_ride()
    var r := Progress.finish_ride({"kj": 1350.0, "completed": true, "moving_time": 1500.0}, watts, false, false)
    Settings.auto_ftp = auto_before
    var shown := false
    if current.has_method("_progress_row"):
        var card: Control = current._progress_row(r)
        for label in card.find_children("*", "Label", true, false):
            shown = shown or label.text == tr("Ingen XP")
        card.free()
    print("       låtsastrainer: XP %d → %d, FTP %d → %d, nya rekord %d, \"Ingen XP\" visas: %s" % [xp_before,
        Progress.xp(), ftp_before, Settings.ftp, r["bests"].size(), shown])
    # The ride is kept in the history (marked as pretend), but gives no XP, records or FTP.
    var rides: Array = Progress.data["rides"]
    return Progress.xp() == xp_before and rides.size() == rides_before + 1 and rides[-1].get("pretend", false) \
        and JSON.stringify(Progress.data["bests"]) == bests_before and r["bests"].is_empty() \
        and r["ftp"].is_empty() and Settings.ftp == ftp_before and shown


## --passtest: ride every workout in the library to the end on the pretend trainer, in ERG (and one
## per category also in SIM), and check that it finishes, that every ERG target is sane, and that the
## summary and the FIT file come out. The FIT files are removed again.
func _passtest() -> void:
    var bad := 0
    var seen_sim := {}
    var t0 := Time.get_ticks_msec()
    for w in workouts:
        for erg in [true, false]:
            if not erg:
                if seen_sim.has(w.category):
                    continue
                seen_sim[w.category] = true
            Ride.start_workout(w, erg)
            var total := int(w.total_seconds()) if w.has_method("total_seconds") else 4 * 3600
            var seconds := 0
            var problems: Array[String] = []
            while not Ride.player.finished and seconds < total + 600:
                var t := Ride.target_watts()
                if erg and t != -1 and (t < 0 or t > 2000):
                    problems.append("mål %d W vid %d s" % [t, seconds])
                    break
                if not erg and t != -1:
                    problems.append("SIM gav ERG-mål %d W" % t)
                    break
                Ride.step(1.0)
                seconds += 1
            if not Ride.player.finished:
                problems.append("inte klart efter %d s (längd %d s)" % [seconds, total])
            var s := Ride.finish()
            for key in ["avg_power", "np", "tss", "kj", "distance"]:
                if not s.has(key) or is_nan(float(s[key])) or is_inf(float(s[key])):
                    problems.append("sammanfattningen saknar %s" % key)
            if s.get("avg_power", 0.0) <= 0.0:
                problems.append("snittwatt %s" % str(s.get("avg_power")))
            if Ride.fit_path == "" or not FileAccess.file_exists(Ride.fit_path):
                problems.append("ingen FIT-fil")
            else:
                DirAccess.remove_absolute(ProjectSettings.globalize_path(Ride.fit_path))
            if not problems.is_empty():
                bad += 1
                print("FEL %s (%s, %s): %s" % [w.name, w.category, "ERG" if erg else "SIM", ", ".join(problems)])
    print("PASSTEST: %d pass, %d fel, %.0f s" % [workouts.size(), bad, (Time.get_ticks_msec() - t0) / 1000.0])
    get_tree().quit()


func _selftest(w) -> void:
    # Frames of uneven length still give one FIT record per whole second, in order.
    Ride.start_free_ride()
    var rng := RandomNumberGenerator.new()
    rng.seed = 3
    for i in 1500:
        Ride.step(rng.randf_range(0.008, 0.034))
    var steady := Ride.samples.size() > 20
    for i in range(1, Ride.samples.size()):
        steady = steady and is_equal_approx(Ride.samples[i]["t"] - Ride.samples[i - 1]["t"], 1.0)
    print("  %s en FIT-post per sekund med ojämna bildtider (%d poster)" % ["ok " if steady else "FEL", Ride.samples.size()])
    Ride.back_to_idle()
    Ride.start_workout(w, true)
    var seconds := 0
    while not Ride.player.finished and seconds < 4 * 3600:
        Ride.step(1.0)
        seconds += 1
    for i in 30:
        Ride.step(1.0)   # roll on a little after the end, like a real rider
    var s := Ride.finish()
    print("SJÄLVTEST ", w.name)
    print("  pass klart: %s efter %d s, laps: %d, sekunder i filen: %d" % [Ride.player.finished, seconds, Ride.laps().size(), Ride.samples.size()])
    print("  snitt %d W, NP %d W, IF %.2f, TSS %d, max %d W, snittpuls %d, kJ %d, distans %.2f km" % [
        roundi(s["avg_power"]), roundi(s["np"]), s["if"], roundi(s["tss"]), s["max_power"], roundi(s["avg_hr"]),
        roundi(s["kj"]), s["distance"] / 1000.0])
    print("  nyckelblock: %s" % str(s["stars"]))
    print("  FIT: ", Ride.fit_path)
    get_tree().quit()
