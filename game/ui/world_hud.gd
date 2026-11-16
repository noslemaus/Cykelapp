extends Control
## Compact HUD over a 3D world, laid out so the world stays visible:
##   top centre  the workout step, the workout's graph, and the watts with four small fields
##   top left    speed · distance · climbed · time; the current workout step and the list below it
##   top right   the loop's elevation profile with lap and grade, the map, the pacers near you
##   bottom      small buttons left; free-ride mode and target right
## In free ride the red "Tryck ej här" button lets the rider leave the lap and ride anywhere: the
## profile then gives way to where you are (road or terrain). Find the secret base and its tank, and
## the panel turns into the tank's: armour, score, monsters shot and a radar.
## Keys as on the gym screen: space pause, → skip, ↑↓ intensity/watts, M ERG/SIM, W/S pretend rider.

const Style = preload("res://ui/style.gd")
const Zones = preload("res://core/zones.gd")
const WorkoutGraph = preload("res://ui/workout_graph.gd")
const RouteProfile = preload("res://ui/route_profile.gd")
const Radar = preload("res://ui/radar.gd")
const SettingsScreen = preload("res://ui/settings_screen.gd")
const LapTracker = preload("res://core/lap_tracker.gd")
const Minikarta = preload("res://ui/minikarta.gd")
const Pacers = preload("res://world/pacers.gd")
const PowerPanel = preload("res://ui/power_panel.gd")
const ClickMenu = preload("res://ui/click_menu.gd")

const ALPHA := 0.72

var app
var args := {}

var _metrics: Array[Label] = []
var _power: Control           # the watts and the four fields (ui/power_panel.gd)
var _profile: Control
var _graph: Control = null
var _status: Label
var _source: Label

var _step_title: Label
var _step_delta: Label
var _step_detail: Label
var _step_next: Label
var _intensity: Label
var _stars: Label
var _pause: Button

var _free_value: Label
var _free_note: Label
var _free_erg: Button
var _free_sim: Button
var _free_own: Button
var _free_minus: Button
var _free_plus: Button
var _roam_button: Button
var _roam_box: Control
var _roam_title: Label
var _roam_road: Label
var _roam_hint: Label
var _battle: Control
var _armor: ProgressBar
var _score: Label
var _kills: Label
var _radar: Control
var _toast: Label
var _toast_left := 0.0
var _toast_queue: Array[String] = []
var _teleporting := false
var _settings: Control = null     # the settings, open over the ride
var _menu: ClickMenu                # Y on the Click: choose the ride's buttons (ui/click_menu.gd)
var _settings_button: Button

# Segments and the ghost (core/lap_tracker.gd times them, Progress keeps the records).
var _seg_box: Control
var _seg_title: Label
var _seg_line: Label
var _ghost_line: Label
var _seg_pr := {}             # segment id → its best when it started (to compare at the line)
var _ghost := {}              # the lap the ghost rides this lap: {"time", "splits"} or {}
var _ghost_lap_start := -1.0


func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    _menu = ClickMenu.new(self, func(): return _settings, _toggle_settings)
    if Progress.tracker == null:
        Progress.begin_ride()
    Progress.tracker.set_world(app.world_id, app.world.length,
        app.world.segments() if app.world.has_method("segments") else [])
    if Settings.pacers and "RIDE_OFFSET" in app.world:
        _pacers = Pacers.new()
        app.world.add_child(_pacers)
        _pacers.setup(app.world, _lap_s())
    _build_top_centre()
    _build_top_left()
    _build_top_right()
    _build_bottom()
    if "roam" in app.world and app.world.roam:
        _show_roam_ui()      # arrived through a teleport gate, already riding free


func _panel(pad := 12.0) -> PanelContainer:
    return Style.panel(Color(Style.PANEL, ALPHA), 12, pad)


func _place(node: Control, preset: int, grow_h: int, grow_v: int) -> void:
    add_child(node)
    node.set_anchors_and_offsets_preset(preset, Control.PRESET_MODE_MINSIZE, 16)
    node.grow_horizontal = grow_h
    node.grow_vertical = grow_v


## Top centre, where the eye is: the watts and the four chosen fields (ui/power_panel.gd), with the
## workout step on top.
func _build_top_centre() -> void:
    var box := Style.vbox(6)
    _power = PowerPanel.new()
    _power.k = 1.15
    _power.alpha = ALPHA
    _power.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    if Ride.player:
        _graph = _power.set_workout(Ride.workout, Settings.ftp)     # what lies ahead, inside the panel
    box.add_child(_power)
    _place(box, Control.PRESET_CENTER_TOP, Control.GROW_DIRECTION_BOTH, Control.GROW_DIRECTION_END)


## Top left: speed, distance, climbing and time in a compact row, then the workout step and the
## list of the steps after it.
func _build_top_left() -> void:
    var column := Style.vbox(10)
    column.custom_minimum_size.x = 280
    var bar := _panel(10)
    var row := Style.hbox(6)
    bar.add_child(row)
    for unit in ["km/h", "km", "hm", tr("tid")]:
        if row.get_child_count() > 0:
            var line := ColorRect.new()
            line.color = Color(1, 1, 1, 0.12)
            line.custom_minimum_size = Vector2(1, 28)
            line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
            row.add_child(line)
        var cell := Style.vbox(-4)
        cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        var value := Style.label("0", 21, Style.TEXT, 900)
        value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        cell.add_child(value)
        var caption := Style.label(unit.to_upper(), 10, Style.TEXT_DIM, 800)
        caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        cell.add_child(caption)
        row.add_child(cell)
        _metrics.append(value)
    column.add_child(bar)
    if Ride.player:
        column.add_child(_step_card())
    column.add_child(_segment_card())
    if Ride.player:
        column.add_child(_step_list_card())
    _place(column, Control.PRESET_TOP_LEFT, Control.GROW_DIRECTION_END, Control.GROW_DIRECTION_END)


## The segment being ridden (its time, metres left and record) and the gap to the ghost.
func _segment_card() -> Control:
    var seg := _panel(10)
    var sbox := Style.vbox(0)
    seg.add_child(sbox)
    _seg_title = Style.label("", 12, Color("ffd34d"), 900)
    sbox.add_child(_seg_title)
    _seg_line = Style.label("", 16, Style.TEXT, 800)
    _seg_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    sbox.add_child(_seg_line)
    _ghost_line = Style.label("", 16, Color("6fe8ff"), 900)
    sbox.add_child(_ghost_line)
    seg.visible = false
    _seg_box = seg
    return seg


func _step_card() -> Control:
    var card := _panel(14)
    var box := Style.vbox(6)
    card.add_child(box)
    # The step's name with a dot in its zone colour, and the key blocks done so far.
    var head := Style.hbox(8)
    _step_dot = Panel.new()
    _step_dot.custom_minimum_size = Vector2(10, 10)
    _step_dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    head.add_child(_step_dot)
    _step_title = Style.label("", 13, Style.TEXT, 900)
    _step_title.clip_text = true
    _step_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    head.add_child(_step_title)
    # How far from the target you are (the target and the time left are in the centre panel).
    _step_delta = Style.label("", 13, Style.TEXT_DIM, 900)
    head.add_child(_step_delta)
    _stars = Style.label("", 14, Color("f2c23a"), 900)
    head.add_child(_stars)
    box.add_child(head)
    _step_detail = Style.label("", 12, Style.TEXT, 700)
    box.add_child(_step_detail)
    _step_next = Style.label("", 12, Style.TEXT_DIM, 600)
    _step_next.clip_text = true
    box.add_child(_step_next)
    var row2 := Style.hbox(6)
    var minus := _small("−", func(): Ride.change_intensity(-0.05))
    var plus := _small("+", func(): Ride.change_intensity(0.05))
    _intensity = Style.label("100 %", 14, Style.TEXT, 800)
    _intensity.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    row2.add_child(minus)
    row2.add_child(_intensity)
    row2.add_child(plus)
    row2.add_child(Style.spacer())
    row2.add_child(Style.label(tr("INTENSITET"), 10, Style.TEXT_DIM, 800))
    box.add_child(row2)
    return card


var _step_dot: Panel
var _step_colour := Color(0, 0, 0, 0)


## The step's zone colour on its dot (set only when it changes).
func _colour_step(colour: Color) -> void:
    if colour.is_equal_approx(_step_colour):
        return
    _step_colour = colour
    _step_dot.add_theme_stylebox_override("panel", Style.flat(colour, 5))


## The map: small top right, and the whole world over the ride with K (or a click on the small one).
var _map: Control
var _big_map: Control = null


func _toggle_big_map() -> void:
    if _big_map:
        _big_map.queue_free()
        _big_map = null
        return
    var shade := ColorRect.new()
    shade.color = Color(0, 0, 0, 0.55)
    shade.set_anchors_preset(Control.PRESET_FULL_RECT)
    shade.mouse_filter = Control.MOUSE_FILTER_STOP
    shade.gui_input.connect(func(e):
        if e is InputEventMouseButton and e.pressed:
            _toggle_big_map())
    var center := CenterContainer.new()
    center.set_anchors_preset(Control.PRESET_FULL_RECT)
    center.mouse_filter = Control.MOUSE_FILTER_IGNORE
    shade.add_child(center)
    var big := Minikarta.new()
    big.setup(app.world, app.world_id)
    big.whole = true
    big.custom_minimum_size = Vector2(1180, 720)
    big.mouse_filter = Control.MOUSE_FILTER_IGNORE
    center.add_child(big)
    add_child(shade)
    _big_map = shade
    _big_map.set_meta("map", big)


## Where the ghost and the pacers are, for the maps.
func _feed_maps() -> void:
    var dots: Array = _pacers.dots() if _pacers else []
    var ghost = app.world.ghost.global_position if app.world.get("ghost") and app.world.ghost.visible else null
    for m in [_map, _big_map.get_meta("map") if _big_map else null]:
        if m:
            m.pacers = dots
            m.ghost_pos = ghost


# --- Pacers and the route --------------------------------------------------------------------------

var _pacers: Node3D = null
var _near_rows: VBoxContainer
var _draft_label: Label


## Your place on the lap (not wrapped), as the lap tracker and the pacers count it.
func _lap_s() -> float:
    return app.world.lap_distance(Ride.distance) if app.world.has_method("lap_distance") else Ride.distance


func _update_pacers(delta: float) -> void:
    if _pacers == null:
        Ride.draft = 0.0
        return
    var roaming: bool = "roam" in app.world and app.world.roam
    var me := _lap_s()
    Ride.draft = _pacers.update(delta, me, not roaming and not _teleporting)
    _draft_label.text = tr("I DRAFTEN  −%d %% LUFT") % roundi(Ride.draft * 100.0) if Ride.draft > 0.02 else ""
    var list: Array = _pacers.nearby(me)
    while _near_rows.get_child_count() < list.size():
        var row := Style.hbox(6)
        var dot := ColorRect.new()
        dot.custom_minimum_size = Vector2(8, 14)
        row.add_child(dot)
        var who := Style.label("", 13, Style.TEXT, 800)
        who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        row.add_child(who)
        row.add_child(Style.label("", 12, Style.TEXT_DIM, 700))
        var gap := Style.label("", 13, Style.TEXT, 900)
        gap.custom_minimum_size.x = 92
        gap.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
        row.add_child(gap)
        _near_rows.add_child(row)
    for i in list.size():
        var r: Dictionary = list[i]
        var row := _near_rows.get_child(i)
        (row.get_child(0) as ColorRect).color = r["colour"]
        (row.get_child(1) as Label).text = r["name"]
        (row.get_child(2) as Label).text = "%s W/kg" % Style.dec(r["wkg"])
        var gap: float = r["gap"]
        var secs := absf(gap) / maxf(Ride.speed, 4.0)
        var text := tr("%d s före") % roundi(secs) if gap > 0.0 else tr("%d s efter") % roundi(secs)
        if absf(gap) < 2.0:
            text = tr("bredvid")
        (row.get_child(3) as Label).text = text
        (row.get_child(3) as Label).add_theme_color_override("font_color", Color("ff9b7a") if gap > 0.0 else Color("7dff9a"))


## The route (core/routes.gd): how far is left, done at its length, broken when you leave the lap.
func _update_route() -> void:
    var r: Dictionary = Ride.route
    if r.is_empty():
        return
    var left: float = float(r["length_m"]) - Ride.distance
    if Ride.route_state == "":
        if ("roam" in app.world and app.world.roam) or _teleporting:
            Ride.route_state = "avbruten"
            _show_toast(tr("Rutten %s är avbruten: du lämnade vägen.") % tr(r["name"]))
        elif left <= 0.0:
            Ride.route_state = "klar"
            Ride.route_time = Ride.moving_time
            _show_toast(tr("Rutten %s är klar på %s!") % [tr(r["name"]), Style.clock(Ride.moving_time)])
    _profile.route_text = ""
    if Ride.route_state == "":
        _profile.route_text = tr("%s  ·  %s km kvar") % [tr(r["name"]), Style.dec(maxf(left, 0.0) / 1000.0, 1)]


## The whole workout as a list: the step you are in (with the time left) and the ones
## after it, each with its time and watts and a bar in its zone colour, under "klart om".
const STEP_ROWS := 8
var _list_head: Label
var _list_rows: VBoxContainer
var _list_key := ""


func _step_list_card() -> Control:
    var card := _panel(10)
    var box := Style.vbox(3)
    card.add_child(box)
    _list_head = Style.label("", 11, Style.TEXT_DIM, 800)
    box.add_child(_list_head)
    _list_rows = Style.vbox(2)
    box.add_child(_list_rows)
    return card


func _update_step_list(player) -> void:
    _list_head.text = tr("PASSET  ·  KLART OM %s") % Style.clock(player.time_left())
    var first: int = player.index()
    var segments: Array = Ride.workout.segments
    # Rebuild the rows only when the step or the intensity changes; the first row's clock ticks.
    var key := "%d/%d" % [first, roundi(player.intensity * 100.0)]
    if key != _list_key:
        _list_key = key
        for c in _list_rows.get_children():
            c.queue_free()
        if first < 0:
            return
        for i in range(first, mini(first + STEP_ROWS, segments.size())):
            _list_rows.add_child(_step_row(segments[i], player, i == first))
        var rest := segments.size() - first - STEP_ROWS
        if rest > 0:
            _list_rows.add_child(Style.label(tr("… och %d steg till") % rest, 11, Style.TEXT_DIM, 700))
    if first >= 0 and _list_rows.get_child_count() > 0:
        var row := _list_rows.get_child(0)
        var clock: Label = row.get_meta("clock", null)
        if clock:
            clock.text = Style.clock(player.time_left_in_segment())


func _step_row(seg: Dictionary, player, current: bool) -> Control:
    var row := Style.hbox(6)
    var share: float = maxf(seg["from"], seg["to"])
    var chip := ColorRect.new()
    chip.color = Color(0.55, 0.58, 0.64) if seg["free"] else Zones.color(share)
    chip.custom_minimum_size = Vector2(5, 15)
    row.add_child(chip)
    var size := 13 if current else 12
    var colour := Style.TEXT if current else Color(Style.TEXT, 0.78)
    var clock := Style.label(Style.clock(seg["duration"]), size, colour, 900 if current else 700)
    clock.custom_minimum_size.x = 40
    row.add_child(clock)
    row.set_meta("clock", clock if current else null)
    var a: int = player.watts_at(seg["from"])
    var b: int = player.watts_at(seg["to"])
    var watts: String = tr("fritt") if seg["free"] else ("%d W" % a if a == b else "%d→%d W" % [a, b])
    var w := Style.label(watts, size, colour, 900 if current else 700)
    w.custom_minimum_size.x = 76
    row.add_child(w)
    var name := Style.label(tr(str(seg["label"])), 11, Style.TEXT_DIM, 600)
    name.clip_text = true
    name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(name)
    return row


func _build_top_right() -> void:
    var box := Style.vbox(4)
    _profile = RouteProfile.new()
    _profile.heights = app.world.profile()
    _profile.length = app.world.length
    _profile.compact = true
    _profile.custom_minimum_size = Vector2(340, 96)
    box.add_child(_profile)
    _map = Minikarta.new()
    _map.setup(app.world, app.world_id)
    _map.custom_minimum_size = Vector2(340, 190)
    _map.mouse_filter = Control.MOUSE_FILTER_STOP
    _map.gui_input.connect(func(e):
        if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
            _toggle_big_map())
    _map.tooltip_text = tr("Klicka (eller K) för hela kartan")
    box.add_child(_map)
    # The pacers near you, nearest first, and the draft when you sit on a wheel.
    var near := _panel(10)
    var nbox := Style.vbox(3)
    near.add_child(nbox)
    var nhead := Style.hbox(8)
    nhead.add_child(Style.label(tr("I NÄRHETEN"), 11, Style.TEXT_DIM, 800))
    nhead.add_child(Style.spacer())
    _draft_label = Style.label("", 11, Color("7dff9a"), 900)
    nhead.add_child(_draft_label)
    nbox.add_child(nhead)
    _near_rows = Style.vbox(2)
    nbox.add_child(_near_rows)
    near.custom_minimum_size.x = 340
    near.visible = _pacers != null
    box.add_child(near)
    _source = Style.label("", 11, Color(Style.TEXT, 0.9), 600)
    _readable(_source)
    _source.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    _source.custom_minimum_size.x = 340
    _source.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    # Free riding: where you are; once the tank is taken, its armour, score and radar.
    var roam := _panel(12)
    roam.custom_minimum_size = Vector2(340, 96)
    var rbox := Style.vbox(4)
    roam.add_child(rbox)
    _roam_title = Style.label(tr("FRI CYKLING"), 11, Style.TEXT_DIM, 800)
    rbox.add_child(_roam_title)
    _roam_road = Style.label("", 24, Style.TEXT, 900)
    rbox.add_child(_roam_road)
    _roam_hint = Style.label("", 14, Style.TEXT_DIM, 700)
    _roam_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    rbox.add_child(_roam_hint)
    var battle := Style.hbox(12)
    var stats := Style.vbox(4)
    stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    stats.add_child(Style.label(tr("PANSAR"), 11, Style.TEXT_DIM, 800))
    _armor = ProgressBar.new()
    _armor.max_value = 100.0
    _armor.show_percentage = false
    _armor.custom_minimum_size = Vector2(150, 12)
    _armor.add_theme_stylebox_override("background", Style.flat(Color(0, 0, 0, 0.35), 6))
    _armor.add_theme_stylebox_override("fill", Style.flat(Color("45bf5c"), 6))
    stats.add_child(_armor)
    _score = Style.label(tr("0 poäng"), 26, Style.TEXT, 900)
    stats.add_child(_score)
    _kills = Style.label("", 13, Style.TEXT_DIM, 700)
    _kills.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    stats.add_child(_kills)
    battle.add_child(stats)
    _radar = Radar.new()
    _radar.custom_minimum_size = Vector2(130, 130)
    battle.add_child(_radar)
    battle.visible = false
    _battle = battle
    rbox.add_child(battle)
    roam.visible = false
    _roam_box = roam
    box.add_child(roam)
    box.move_child(roam, 0)
    box.add_child(_source)
    _place(box, Control.PRESET_TOP_RIGHT, Control.GROW_DIRECTION_BEGIN, Control.GROW_DIRECTION_END)
    _toast = Style.label("", 26, Style.TEXT, 800)
    _toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _toast.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
    _toast.add_theme_constant_override("outline_size", 8)
    _toast.visible = false
    _place(_toast, Control.PRESET_CENTER_TOP, Control.GROW_DIRECTION_BOTH, Control.GROW_DIRECTION_END)
    var drop := 236.0 if Ride.player else 130.0     # under the power panel (and its workout step)
    _toast.offset_top += drop
    _toast.offset_bottom += drop


func _small(text: String, on_press: Callable, kind := "secondary") -> Button:
    var b := Style.button(text, kind, 14)
    for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
        var box: StyleBoxFlat = b.get_theme_stylebox(state).duplicate()
        box.set_content_margin_all(7)
        box.content_margin_left = 12
        box.content_margin_right = 12
        if kind == "secondary":
            box.bg_color = Color(box.bg_color, 0.85)
        b.add_theme_stylebox_override(state, box)
    b.pressed.connect(on_press)
    _menu.buttons.append(b)
    return b


func _build_bottom() -> void:
    var left := Style.hbox(8)
    left.add_child(_small(tr("Avsluta"), func(): app.finish_ride(), "primary"))
    _settings_button = _small(tr("⚙ Inställningar"), _toggle_settings)
    left.add_child(_settings_button)
    if Ride.player:
        _pause = _small(tr("Pausa"), Ride.toggle_pause)
        left.add_child(_pause)
        left.add_child(_small(tr("Hoppa över"), Ride.skip_segment))
    if "roam" in app.world:
        # Free and in workouts alike: the workout carries on, only the map is free.
        _roam_button = _small(tr("Tryck ej här"), _toggle_roam, "primary")
        _style_roam_button(true)
        left.add_child(_roam_button)
    _place(left, Control.PRESET_BOTTOM_LEFT, Control.GROW_DIRECTION_END, Control.GROW_DIRECTION_BEGIN)
    # How the trainer is driven: ERG (the workout's or your chosen watts), the road (SIM) or your
    # own steady resistance.
    var card := _panel(12)
    var box := Style.vbox(6)
    card.add_child(box)
    # What drives the trainer now (and paused, the cadence guard), above the choice.
    _status = Style.label("", 12, Style.ACCENT, 800)
    _status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _status.custom_minimum_size.x = 300
    box.add_child(_status)
    var modes := Style.hbox(6)
    _free_erg = _small(tr("Passet (ERG)") if Ride.player else tr("Håll watt"), func(): Ride.set_mode("erg"))
    _free_sim = _small(tr("Känn vägen"), func(): Ride.set_mode("sim"))
    _free_own = _small(tr("Eget motstånd"), func(): Ride.set_mode("eget"))
    modes.add_child(_free_erg)
    modes.add_child(_free_sim)
    modes.add_child(_free_own)
    box.add_child(modes)
    var row := Style.hbox(8)
    _free_minus = _small("−", func(): _adjust(-1))
    _free_plus = _small("+", func(): _adjust(1))
    _free_value = Style.label("", 26, Style.TEXT, 900)
    _free_value.custom_minimum_size.x = 150
    _free_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    row.add_child(_free_minus)
    row.add_child(_free_value)
    row.add_child(_free_plus)
    box.add_child(row)
    _free_note = Style.label("", 12, Style.TEXT_DIM, 600)
    _free_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _free_note.custom_minimum_size.x = 300
    box.add_child(_free_note)
    _place(card, Control.PRESET_BOTTOM_RIGHT, Control.GROW_DIRECTION_BEGIN, Control.GROW_DIRECTION_BEGIN)


## − and + on the card: your watts in free ride ERG, your resistance level in "Eget motstånd".
func _adjust(direction: int) -> void:
    if Ride.manual:
        Ride.change_level(direction)
    elif Ride.erg and not Ride.player:
        Ride.change_free_watts(10 * direction)


## Red "Tryck ej här" on the lap; a calm "Tillbaka till vägen" while riding free (or in the tank).
func _style_roam_button(red: bool) -> void:
    for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
        var sb: StyleBoxFlat = Style.flat(Color("d64545") if red else Color("3a6f8f"), 18)
        sb.content_margin_left = 12
        sb.content_margin_right = 12
        sb.content_margin_top = 6
        sb.content_margin_bottom = 6
        if state in ["hover", "hover_pressed"]:
            sb.bg_color = sb.bg_color.lightened(0.1)
        _roam_button.add_theme_stylebox_override(state, sb)


## ↑/↓: intensity in a workout; in free ride the pretend rider pedals harder/easier
## (with the real trainer: the ERG watts).
func _push(direction: int) -> void:
    if Ride.sim and not Ride.player and Ride.mode() == "sim":
        # Pretend trainer, free ride: make the pretend rider pedal harder or easier.
        Ride.sim.bias = clampf(Ride.sim.bias + 25.0 * direction, -150.0, 400.0)
    else:
        Ride.push(direction)


## "Tryck ej här" leaves the lap and rides anywhere; pressed again ("Tillbaka till vägen") it puts
## the bike back on the lap at the nearest point, and ends the tank and the battle if they are on.
func _toggle_roam() -> void:
    if app.world.roam:
        _end_roam()
    else:
        _start_roam()


func _start_roam() -> void:
    if app.world.roam:
        return
    app.world.start_roam(Ride.distance)
    _show_roam_ui()
    _show_toast(tr("Nu får du åka vart du vill!\nSväng med A/D eller Clickens pilar. På vägarna följer cykeln vägen själv."))


func _show_roam_ui() -> void:
    _roam_button.text = tr("Tillbaka till vägen")
    _style_roam_button(false)
    _profile.visible = false
    _roam_box.visible = true
    _battle.visible = false
    _roam_title.text = tr("FRI CYKLING")


## Show a message for five seconds; one that comes while another shows waits its turn (and the
## one showing is cut short).
func _show_toast(text: String) -> void:
    if _toast.visible and _toast_left > 0.0:
        _toast_queue.append(text)
        _toast_left = minf(_toast_left, 1.8)
        return
    _toast.text = text
    _toast.visible = true
    _toast_left = 5.0


func _exit_tree() -> void:
    if _menu.open:
        _menu.open = false
    Engine.time_scale = 1.0
    Controls.menu_open = false


## The settings over the ride (the gear button, Esc or a Click button bound to it): rebind the
## buttons, change the sound or the screen fields while the ride goes on underneath.
func _toggle_settings() -> void:
    if _settings:
        _settings.queue_free()
        _settings = null
        return
    _settings = SettingsScreen.new()
    _settings.app = app
    _settings.args = {"overlay": true, "on_close": _toggle_settings}
    _settings.set_anchors_preset(Control.PRESET_FULL_RECT)
    add_child(_settings)
    if _menu.open and _settings:
        _menu.focus_settings.call_deferred(_settings)


# --- The menu with the Click: Y shows a marker on the ride's buttons, the left arrows move it, A
# presses, B goes back (out of the settings, then out of the menu), Y again hides it ---------------

func _toggle_menu() -> void:
    _menu.first = _settings_button
    _menu.toggle()


func _end_roam() -> void:
    if not app.world.roam:
        return
    var was_tank: bool = app.world.strid != null
    app.bank_battle()
    app.world.end_roam(Ride.distance)
    _roam_button.text = tr("Tryck ej här")
    _style_roam_button(true)
    _profile.visible = true
    _roam_box.visible = false
    _battle.visible = false
    _toast_queue.clear()
    _toast_left = 0.0
    var road: String = tr(app.world.lap_name())
    _show_toast((tr("Fordonet är tillbaka. Du cyklar på %s igen.") if was_tank else tr("Tillbaka på %s.")) % road)


## M (or a Click button): ERG → feel the road → own resistance → ERG.
func _cycle_mode() -> void:
    Ride.set_mode({"erg": "sim", "sim": "eget", "eget": "erg"}[Ride.mode()])


## Actions come from the keys and from the Zwift Click buttons alike (see core/controls.gd).
func _input(event: InputEvent) -> void:
    # Before the buttons see it: with a button marked, Tab would otherwise only move the marker on.
    if event.is_action_pressed("meny"):
        _toggle_menu()
        get_viewport().set_input_as_handled()
    elif _menu.open and event.is_action_pressed("ui_cancel"):
        _menu.back()
        get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("karta"):
        _toggle_big_map()
        get_viewport().set_input_as_handled()
        return
    if event.is_action_pressed("installningar"):
        _toggle_settings()
        get_viewport().set_input_as_handled()
        return
    if _settings:
        return          # the keys belong to the settings while they are open
    if event.is_action_pressed("paus"):
        Ride.toggle_pause()
    elif event.is_action_pressed("nasta_steg"):
        Ride.skip_segment()
    elif event.is_action_pressed("tyngre"):
        _push(1)
    elif event.is_action_pressed("lattare"):
        _push(-1)
    elif event.is_action_pressed("byt_lage"):
        _cycle_mode()
    elif event is InputEventKey and event.pressed and not event.echo and _atmosphere_key(event):
        get_viewport().set_input_as_handled()
    elif event is InputEventKey and event.pressed and Ride.sim:
        if event.keycode == KEY_W:
            Ride.sim.bias += 10.0
        elif event.keycode == KEY_S:
            Ride.sim.bias -= 10.0


## Small text straight on the world (not on a panel): a dark outline keeps it readable on a bright
## scene such as the bazaar or snow.
static func _readable(label: Label) -> void:
    label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
    label.add_theme_constant_override("outline_size", 5)


# --- Per-frame update ---------------------------------------------------------------------------

func _process(delta: float) -> void:
    if app.world == null:
        return
    # Look around (←/→ or a Click button) swings the camera round the rider; steering moves the
    # rider across the road. Shift fast-forwards the pretend ride.
    var swing := Input.get_axis("titta_vanster", "titta_hoger")
    if swing != 0.0:
        app.world.orbit = clampf(app.world.orbit + swing * 1.6 * delta, -PI, PI)
    else:
        app.world.orbit = move_toward(app.world.orbit, 0.0, delta * 0.7)
    var steer := Input.get_axis("styr_vanster", "styr_hoger") if _settings == null else 0.0
    if "roam" in app.world and app.world.roam:
        app.world.fri.steer = steer      # free riding: steering turns the bike (or the tank)
    elif steer != 0.0 and "lateral" in app.world:
        var limits: Vector2 = app.world.lateral_range() if app.world.has_method("lateral_range") else Vector2(-2.9, 0.9)
        app.world.lateral = clampf(app.world.lateral + steer * 1.4 * delta, limits.x, limits.y)
    if _toast_left > 0.0:
        _toast_left -= delta
        _toast.visible = _toast_left > 0.0
    elif not _toast_queue.is_empty():
        _show_toast(_toast_queue.pop_front())
    if _roam_box and _roam_box.visible:
        _update_roam()
    # Ridden through a teleport gate: the app swaps the worlds (this screen is rebuilt).
    if "teleport_to" in app.world and app.world.teleport_to != "" and not _teleporting:
        _teleporting = true
        app.teleport(app.world.teleport_to)
    Engine.time_scale = 6.0 if Ride.sim and Input.is_key_pressed(KEY_SHIFT) else app.dev_time_scale
    Ride.grade = app.world.current_grade(Ride.distance) if app.world.has_method("current_grade") else app.world.grade_at(Ride.distance)
    var ahead := Ride.distance + Ride.speed * Ride.GRADE_LOOKAHEAD
    Ride.grade_ahead = app.world.current_grade(ahead) if app.world.has_method("current_grade") else app.world.grade_at(ahead)
    app.world.update_view(Ride.distance, Ride.speed, Ride.cadence, delta)
    if app.world.has_method("surface"):
        Ride.surface = app.world.surface()
    _update_segments(delta)
    _update_pacers(delta)
    _update_route()
    _feed_maps()
    _profile.distance = app.world.lap_distance(Ride.distance) if app.world.has_method("lap_distance") else Ride.distance
    _profile.grade = Ride.grade
    _profile.queue_redraw()
    _metrics[0].text = Style.dec(Ride.speed * 3.6)
    _metrics[1].text = Style.dec(Ride.distance / 1000.0, 2)
    _metrics[2].text = "%d" % roundi(Ride.elevation_gain)
    _metrics[3].text = Style.clock(Ride.moving_time)
    var shown := Ride.display_power()
    var slots: Array = []
    for i in 4:
        var key: String = Settings.hud_slots[i]
        slots.append(_slot(key) + [key])
    _power.show_values(roundi(shown), shown / float(maxi(Settings.ftp, 1)), slots)
    var source := Ride.source_description()
    if Ride.sim:
        source += tr("  ·  W/S trampa (%+d W)  ·  ←→ titta  ·  Skift snabbspola") % roundi(Ride.sim.bias)
    _source.text = source
    if Ride.player:
        _update_workout(shown)
    else:
        _update_free()


func _update_roam() -> void:
    var world = app.world
    _roam_road.text = world.current_road()
    var strid = world.strid
    if strid == null:
        if world.fri.blocked:
            _roam_hint.text = tr("Stopp! Sväng runt hindret.")
        elif world.current_road() == "Terrängen":
            _roam_hint.text = tr("Ute i terrängen. Lutning %s %%.") % Style.dec(world.fri.grade)
        else:
            _roam_hint.text = tr("Sväng med A/D eller Clickens pilar.")
        return
    if not _battle.visible:
        _battle.visible = true
        _roam_title.text = strid.title()
        (_radar as Radar).strid = strid
    while not strid.news.is_empty():
        _show_toast(strid.news.pop_front())
    _roam_hint.text = tr("Stridsvagnen är utslagen …") if strid.knocked_out() else (tr("Skjut: ") + strid.fire_keys())
    _armor.max_value = strid.armor_max
    _armor.value = strid.armor
    var fill: StyleBoxFlat = _armor.get_theme_stylebox("fill")
    var share: float = strid.armor / strid.armor_max
    fill.bg_color = Color("45bf5c") if share > 0.5 else (Color("f0b232") if share > 0.25 else Color("e0483d"))
    _score.text = tr("%d poäng") % strid.score
    _kills.text = strid.kill_line()


func _slot(key: String) -> Array:
    match key:
        "cadence":
            return ["%d" % roundi(Ride.cadence), "RPM"]
        "avg_power":
            return ["%d" % roundi(Ride.avg_power()), "W SNITT"]
        "hr":
            return ["%d" % roundi(Ride.hr) if Ride.hr > 0.0 else "–", "BPM"]
        "kj":
            return ["%d" % roundi(Ride.kj), "KJ"]
        "max_power":
            return ["%d" % Ride.max_power, "W MAX"]
        "np":
            return ["%d" % roundi(Ride.np_live), tr("W NP")]
        "wkg":
            return [Style.dec(Ride.display_power() / Settings.weight_kg), "W/KG"]
        "speed":
            return [Style.dec(Ride.speed * 3.6), tr("KM/H")]
    return ["–", key]


func _update_workout(shown: float) -> void:
    var player = Ride.player
    var segment: Dictionary = player.segment()
    var target: int = player.target_watts()
    if player.finished or segment.is_empty():
        _step_title.text = tr("PASSET ÄR KLART")
        _step_delta.text = ""
        _step_detail.text = tr("Rulla vidare och tryck Avsluta.")
        _step_detail.visible = true
        _step_next.text = ""
        _colour_step(Style.ACCENT)
        _power.show_step({})
    else:
        _step_title.text = tr(str(segment["label"])).to_upper()
        _step_detail.text = tr("Kadens %d rpm") % segment["cadence"] if segment["cadence"] > 0 else ""
        _step_detail.visible = segment["cadence"] > 0
        var colour := Color(0.55, 0.58, 0.64) if target <= 0 else Zones.color(target / float(Settings.ftp))
        _colour_step(colour)
        # The step on top of the centre panel: target, how long, and the time left counting down.
        var from_w: int = player.watts_at(segment["from"])
        var to_w: int = player.watts_at(segment["to"])
        var aim: String = tr("Fritt") if segment["free"] else ("%d W" % from_w if from_w == to_w else "%d→%d W" % [from_w, to_w])
        var length: float = segment["duration"]
        var how_long: String = tr("i %d min") % roundi(length / 60.0) if fmod(length, 60.0) < 0.5 else tr("i %s") % Style.clock(length)
        var left: float = player.time_left_in_segment()
        _power.show_step({"target": aim, "length": how_long, "label": tr(str(segment["label"])).to_upper(),
            "left": ceilf(left), "fraction": snappedf(1.0 - left / length, 0.002), "colour": colour})
        if target > 0:
            var diff := roundi(shown) - target
            _step_delta.text = "%+d W" % diff
            var close := absf(diff) <= maxf(8.0, target * 0.05)
            _step_delta.add_theme_color_override("font_color", Color("45bf5c") if close else Color("f07b32"))
        else:
            _step_delta.text = ""
        var next_index: int = player.index() + 1
        if next_index < Ride.workout.segments.size():
            var n: Dictionary = Ride.workout.segments[next_index]
            var a: int = player.watts_at(n["from"])
            var b: int = player.watts_at(n["to"])
            var watts := "fritt" if n["free"] else ("%d W" % a if a == b else "%d→%d W" % [a, b])
            _step_next.text = tr("Sedan: %s %s · %s") % [tr(n["label"]), watts, Style.clock(n["duration"])]
        else:
            _step_next.text = tr("Sedan: klart!")
    _update_step_list(player)
    _intensity.text = "%d %%" % roundi(player.intensity * 100.0)
    var stars: Vector2i = player.stars()
    _stars.text = "★ %d/%d" % [stars.x, stars.y]
    _pause.text = tr("Fortsätt") if Ride.paused else tr("Pausa")
    var status: Array[String] = []
    match Ride.mode():
        "erg":
            status.append(tr("ERG – passet styr motståndet"))
        "sim":
            status.append(tr("SIM – backarna känns, håll watten med växlarna"))
        "eget":
            status.append(tr("Eget motstånd %d – passet visar bara watten") % Ride.manual_level)
    if Ride.paused:
        status.append("pausat")
    if Ride.guard_active:
        status.append("kadensskydd")
    _status.text = "  ·  ".join(status)
    _status.visible = _status.text != ""
    _graph.progress = player.elapsed
    _graph.intensity = player.intensity
    _graph.queue_redraw()
    _update_mode_card()


func _update_free() -> void:
    _update_mode_card()
    _status.text = "" if Ride.power > 0.0 else tr("Börja trampa så startar klockan.")
    _status.visible = _status.text != ""


## The trainer card (bottom right), in free rides and workouts.
func _update_mode_card() -> void:
    var m := Ride.mode()
    Style.set_selected(_free_erg, m == "erg")
    Style.set_selected(_free_sim, m == "sim")
    Style.set_selected(_free_own, m == "eget")
    var adjustable := m == "eget" or (m == "erg" and not Ride.player)
    _free_minus.visible = adjustable
    _free_plus.visible = adjustable
    match m:
        "erg":
            if Ride.player:
                var target := Ride.target_watts()
                _free_value.text = "%d W" % target if target > 0 else "–"
                _free_note.text = tr("Passet styr trainern, var du än cyklar.")
            else:
                _free_value.text = "%d W" % Ride.free_watts
                _free_note.text = tr("Trainern håller watten i backarna.")
        "sim":
            _free_value.text = "%s %%" % Style.dec(Ride.grade)
            var gear_text := tr(", växel %d av %d") % [Ride.gear, Ride.GEAR_COUNT]
            _free_note.text = tr("Känns som %s %% (backkänsla %d %%%s)") % [
                Style.dec(Ride.felt_grade()), roundi(Settings.trainer_difficulty * 100.0), gear_text]
        "eget":
            _free_value.text = tr("Motstånd %d") % Ride.manual_level
            _free_note.text = tr("Samma motstånd i backarna. Välj med − och + (eller Tyngre/Lättare).")


# --- Segments and the ghost -------------------------------------------------------------------

## Time the segments and the lap, say how each went, and move the ghost.
func _update_segments(delta: float) -> void:
    var tracker = Progress.tracker
    var world = app.world
    var roaming: bool = "roam" in world and world.roam
    var lap_s: float = world.lap_distance(Ride.distance) if world.has_method("lap_distance") else Ride.distance
    var now := Ride.moving_time
    tracker.update(lap_s, now, not roaming and not _teleporting)
    while not tracker.events.is_empty():
        _segment_event(tracker.events.pop_front())
    if tracker.lap_valid and tracker.lap_start != _ghost_lap_start:
        _ghost_lap_start = tracker.lap_start
        _ghost = Progress.ghost_lap(app.world_id, app.world.length)

    var lines := false
    var cur: Dictionary = tracker.current_segment(lap_s)
    if cur.is_empty():
        _seg_title.visible = false
        _seg_line.visible = false
    else:
        var seg: Dictionary = cur["segment"]
        var pr: float = _seg_pr.get(seg["id"], 0.0)
        _seg_title.text = "%s  ·  %s" % [tr(seg["name"]).to_upper(), tr("KLÄTTRING") if seg["kind"] == "climb" else tr("SPURT")]
        var text := tr("%s   ·   %d m kvar") % [_time(now - float(cur["started"])), maxi(0, roundi(cur["left"]))]
        text += (tr("   ·   rekord %s") % _time(pr)) if pr > 0.0 else tr("   ·   första gången")
        _seg_line.text = text
        _seg_title.visible = true
        _seg_line.visible = true
        lines = true

    var ghost_on := false
    if not _ghost.is_empty() and tracker.lap_valid and not roaming and world.has_method("show_ghost"):
        var splits: PackedFloat32Array = _ghost["splits"]
        var lap_time: float = _ghost["time"]
        var elapsed: float = tracker.lap_elapsed(now)
        var at := LapTracker.ghost_distance(splits, lap_time, world.length, elapsed)
        if at >= 0.0:
            var k := clampi(int(at / LapTracker.SPLIT), 0, splits.size() - 2)
            var ghost_speed := LapTracker.SPLIT / maxf(splits[k + 1] - splits[k], 0.2)
            world.show_ghost(at, ghost_speed, delta)
            ghost_on = true
        var mine := fposmod(lap_s, world.length)
        var gap := elapsed - LapTracker.ghost_time_at(splits, lap_time, world.length, mine)
        if absf(gap) < 0.05:
            _ghost_line.text = tr("SPÖKET  ±0,0 s")
        elif gap > 0.0:
            _ghost_line.text = tr("SPÖKET  +%s s  efter") % Style.dec(gap)
        else:
            _ghost_line.text = tr("SPÖKET  %s s  före") % Style.dec(-gap)
        _ghost_line.add_theme_color_override("font_color", Color("ff7a6b") if gap > 0.0 else Color("7dff9a"))
        _ghost_line.visible = true
        lines = true
    else:
        _ghost_line.visible = false
    if not ghost_on and world.has_method("hide_ghost"):
        world.hide_ghost()
    _seg_box.visible = lines


func _segment_event(e: Dictionary) -> void:
    match e["type"]:
        "segment_start":
            var seg: Dictionary = e["segment"]
            _seg_pr[seg["id"]] = Progress.segment_best(app.world_id, seg["id"])
        "segment_end":
            var seg: Dictionary = e["segment"]
            var took: float = e["time"]
            var pr: float = _seg_pr.get(seg["id"], 0.0)
            if pr <= 0.0:
                _show_toast(tr("%s: %s\nFörsta tiden. Nu har du ett rekord att slå.") % [tr(seg["name"]), _time(took)])
            elif took < pr:
                _show_toast(tr("%s: %s\nNytt rekord! %s s snabbare.") % [tr(seg["name"]), _time(took), Style.dec(pr - took)])
            else:
                _show_toast(tr("%s: %s\n%s s efter rekordet (%s).") % [tr(seg["name"]), _time(took), Style.dec(took - pr), _time(pr)])
        "lap":
            var took: float = e["time"]
            if _ghost.is_empty():
                _show_toast(tr("Varvet klart: %s\nNästa varv cyklar ditt spöke med dig.") % _time(took))
            else:
                var best: float = _ghost["time"]
                if took < best:
                    _show_toast(tr("Varvet klart: %s\nDu slog spöket med %s s!") % [_time(took), Style.dec(best - took)])
                else:
                    _show_toast(tr("Varvet klart: %s\n%s s efter spöket.") % [_time(took), Style.dec(took - best)])


## Segment and lap times: tenths under a minute (sprints are close), m:ss above.
static func _time(seconds: float) -> String:
    if seconds < 60.0:
        return "%s s" % Style.dec(seconds)
    return Style.clock(seconds)


# --- Weather, time of day and season (world/atmosphere.gd) ------------------------------------

## T: time of day, V: weather, Å: season. Each press goes to the next and is remembered.
func _atmosphere_key(event: InputEventKey) -> bool:
    var atm = app.world.get("atmosphere")
    if atm == null:
        return false
    if event.keycode == KEY_T:
        Settings.time_of_day = _next(atm.TIMES, Settings.time_of_day)
    elif event.keycode == KEY_V:
        Settings.weather = _next(atm.WEATHERS, Settings.weather)
    elif event.unicode == 229 or event.unicode == 197:      # å / Å
        if atm.climate() == "desert":
            _show_toast(tr("Öknen har inga årstider."))
            return true
        Settings.season = _next(atm.SEASONS, Settings.season)
    else:
        return false
    Settings.save()
    atm.apply_settings()
    _show_toast("%s  ·  %s  ·  %s" % [tr(atm.TIME_NAMES[Settings.time_of_day]),
        tr(atm.weather_label(atm.weather, atm.climate(), atm.season)), tr(atm.SEASON_NAMES[atm.season])])
    return true


static func _next(list: Array, current: String) -> String:
    var i := list.find(current)
    return list[(i + 1) % list.size()]
