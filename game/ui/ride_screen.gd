extends Control
## The gym console: what you look at while riding. Reads everything from the Ride engine.
## Workout: current step, countdown, step list, intensity, key efforts and the workout graph.
## Free ride: hold watts (ERG) or a grade (SIM), like the levels on a gym bike.
## Keys: space = pause workout, → = skip step, ↑/↓ = intensity (workout) or watts/grade (free),
##       M = ERG/SIM, W/S = pretend rider harder/easier (pretend trainer only).

const Style = preload("res://ui/style.gd")
const Zones = preload("res://core/zones.gd")
const WorkoutGraph = preload("res://ui/workout_graph.gd")
const PowerTrace = preload("res://ui/power_trace.gd")
const RouteProfile = preload("res://ui/route_profile.gd")
const PowerPanel = preload("res://ui/power_panel.gd")
const ClickMenu = preload("res://ui/click_menu.gd")

var app
var args := {}

var _metric_labels: Array[Label] = []
var _source_label: Label
var _hint_label: Label
var _graph: Control

# Workout widgets.
var _step_title: Label
var _step_target: Label
var _step_detail: Label
var _step_bar: ProgressBar
var _step_next: Label
var _step_delta: Label
var _status_label: Label
var _list_box: VBoxContainer
var _finish_label: Label
var _intensity_label: Label
var _stars_label: Label
var _pause_button: Button
var _mode_button: Button
var _list_key := ""
var _world_mode := false
var _profile: Control = null

# Free-ride widgets.
var _free_value: Label
var _free_caption: Label
var _free_erg: Button
var _free_sim: Button
var _free_minus: Button
var _free_plus: Button


var _menu: ClickMenu
var _power: Control


func _ready() -> void:
    _world_mode = args.get("world", false) and app != null and app.world != null
    _menu = ClickMenu.new(self, func(): return _settings, _toggle_settings)
    var root := Style.vbox(18)
    add_child(Style.margin(root, 24))

    var top := Style.hbox(20)
    _source_label = Style.label("", 16, Style.TEXT_DIM, 500)
    _source_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _source_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    top.add_child(_source_label)
    top.add_child(_metrics_bar())
    _hint_label = Style.label("", 15, Style.TEXT_DIM, 500)
    _hint_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    _hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    top.add_child(_hint_label)
    root.add_child(top)

    var middle := Style.hbox(20)
    middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
    root.add_child(middle)
    var power := _power_panel()
    middle.add_child(power)
    if Ride.player:
        var step := _step_panel()
        middle.add_child(step)
        var list := _list_panel()
        middle.add_child(list)
        if _world_mode:
            # The world shows through the middle: compact panels hugging the top.
            step.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
            step.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
            step.custom_minimum_size.x = 520
            middle.move_child(step, 1)
            var gap := Style.spacer()
            middle.add_child(gap)
            middle.move_child(gap, 1)
            var gap2 := Style.spacer()
            middle.add_child(gap2)
            middle.move_child(gap2, 3)
        var graph := WorkoutGraph.new()
        graph.workout = Ride.workout
        graph.ftp = Settings.ftp
        graph.detailed = true
        _graph = graph
    else:
        var free := _free_panel()
        middle.add_child(free)
        if _world_mode:
            free.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
            free.size_flags_horizontal = Control.SIZE_SHRINK_END
            free.custom_minimum_size.x = 460
        var trace := PowerTrace.new()
        trace.ftp = Settings.ftp
        _graph = trace
    if _world_mode:
        power.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
        var bottom := Style.hbox(16)
        _profile = RouteProfile.new()
        _profile.heights = app.world.profile()
        _profile.length = app.world.length
        _profile.custom_minimum_size = Vector2(460, 150)
        _profile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        if Ride.player:
            _graph.custom_minimum_size.y = 150
            _graph.background = Color(Style.GRAPH_BG, 0.82)
            _graph.size_flags_horizontal = Control.SIZE_EXPAND_FILL
            _graph.size_flags_stretch_ratio = 2.0
            bottom.add_child(_graph)
        else:
            _graph = null
        bottom.add_child(_profile)
        root.add_child(bottom)
    else:
        _graph.custom_minimum_size.y = 230
        root.add_child(_graph)
    root.add_child(_buttons())


## Panels are see-through when a world is behind them.
func _panel(radius := 18, pad := 22.0) -> PanelContainer:
    return Style.panel(Color(Style.PANEL, 0.8) if _world_mode else Style.PANEL, radius, pad)


func _metrics_bar() -> Control:
    var panel := _panel(16, 16)
    var row := Style.hbox(44)
    panel.add_child(row)
    for unit in ["km/h", "km", tr("höjdmeter"), tr("tid")]:
        var box := Style.vbox(0)
        var value := Style.label("0", 42, Style.TEXT, 800)
        value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        box.add_child(value)
        var caption := Style.label(unit, 15, Style.TEXT_DIM, 600)
        caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        box.add_child(caption)
        row.add_child(box)
        _metric_labels.append(value)
    return panel


## The watts and the four fields, drawn like the world HUD's (ui/power_panel.gd) but larger.
func _power_panel() -> Control:
    _power = PowerPanel.new()
    _power.k = 1.4
    _power.alpha = 0.8 if _world_mode else 1.0
    _power.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
    return _power


func _step_panel() -> Control:
    var panel := _panel(18, 26)
    panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var box := Style.vbox(10)
    panel.add_child(box)
    _step_title = Style.label("", 26, Style.TEXT_DIM, 800)
    box.add_child(_step_title)
    var target_row := Style.hbox(18)
    _step_target = Style.label("", 76, Style.TEXT, 900)
    target_row.add_child(_step_target)
    _step_delta = Style.label("", 30, Style.TEXT_DIM, 800)
    _step_delta.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    target_row.add_child(_step_delta)
    box.add_child(target_row)
    _step_detail = Style.label("", 26, Style.TEXT, 700)
    box.add_child(_step_detail)
    _step_bar = ProgressBar.new()
    _step_bar.show_percentage = false
    _step_bar.custom_minimum_size.y = 16
    _step_bar.add_theme_stylebox_override("background", Style.flat(Style.PANEL_LIGHT, 8))
    _step_bar.add_theme_stylebox_override("fill", Style.flat(Style.ACCENT, 8))
    box.add_child(_step_bar)
    _step_next = Style.label("", 20, Style.TEXT_DIM, 600)
    box.add_child(_step_next)
    box.add_child(Style.spacer())
    _status_label = Style.label("", 19, Style.ACCENT, 700)
    _status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    box.add_child(_status_label)
    return panel


func _list_panel() -> Control:
    var panel := _panel(18, 18)
    panel.custom_minimum_size.x = 380
    var box := Style.vbox(10)
    panel.add_child(box)
    box.add_child(Style.label(Ride.workout.name, 24, Style.TEXT, 800))
    _finish_label = Style.label("", 18, Style.TEXT_DIM, 600)
    box.add_child(_finish_label)
    var scroll := ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    _list_box = Style.vbox(4)
    _list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.add_child(_list_box)
    box.add_child(scroll)
    var row := Style.hbox(10)
    var minus := Style.button("−", "secondary", 22)
    minus.pressed.connect(func(): Ride.change_intensity(-0.05))
    var plus := Style.button("+", "secondary", 22)
    plus.pressed.connect(func(): Ride.change_intensity(0.05))
    _intensity_label = Style.label("100 %", 22, Style.TEXT, 800)
    row.add_child(minus)
    row.add_child(_intensity_label)
    row.add_child(plus)
    row.add_child(Style.spacer())
    _stars_label = Style.label("", 22, Color("f2c23a"), 800)
    row.add_child(_stars_label)
    box.add_child(row)
    return panel


func _free_panel() -> Control:
    var panel := _panel(18, 26)
    panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var box := Style.vbox(16)
    panel.add_child(box)
    var modes := Style.hbox(12)
    _free_erg = Style.button(tr("Håll watt (ERG)"), "secondary", 22)
    _free_sim = Style.button(tr("Lutning (SIM)"), "secondary", 22)
    _free_erg.pressed.connect(_set_free_mode.bind(true))
    _free_sim.pressed.connect(_set_free_mode.bind(false))
    modes.add_child(_free_erg)
    modes.add_child(_free_sim)
    box.add_child(modes)
    var row := Style.hbox(24)
    row.alignment = BoxContainer.ALIGNMENT_CENTER
    var minus := Style.button("−", "secondary", 40)
    minus.custom_minimum_size = Vector2(90, 90)
    minus.pressed.connect(func(): _adjust_free(-1))
    _free_minus = minus
    var plus := Style.button("+", "secondary", 40)
    plus.custom_minimum_size = Vector2(90, 90)
    plus.pressed.connect(func(): _adjust_free(1))
    _free_plus = plus
    _free_value = Style.label("", 88, Style.TEXT, 900)
    _free_value.custom_minimum_size.x = 320
    _free_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    row.add_child(minus)
    row.add_child(_free_value)
    row.add_child(plus)
    box.add_child(row)
    _free_caption = Style.label("", 20, Style.TEXT_DIM, 600)
    _free_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _free_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    box.add_child(_free_caption)
    box.add_child(Style.spacer())
    _status_label = Style.label("", 19, Style.ACCENT, 700)
    box.add_child(_status_label)
    return panel


func _buttons() -> Control:
    var row := Style.hbox(14)
    row.alignment = BoxContainer.ALIGNMENT_CENTER
    if Ride.player:
        _pause_button = Style.button(tr("Pausa passet"), "secondary", 20)
        _pause_button.pressed.connect(Ride.toggle_pause)
        row.add_child(_pause_button)
        var skip := Style.button(tr("Hoppa över steg"), "secondary", 20)
        skip.pressed.connect(Ride.skip_segment)
        row.add_child(skip)
        _mode_button = Style.button("", "secondary", 20)
        _mode_button.pressed.connect(Ride.toggle_mode)
        row.add_child(_mode_button)
    var gear := Style.button(tr("⚙ Inställningar"), "secondary", 20)
    gear.pressed.connect(_toggle_settings)
    row.add_child(gear)
    var end := Style.button(tr("Avsluta"), "primary", 20)
    end.pressed.connect(func(): app.finish_ride())
    row.add_child(end)
    for b in row.get_children():
        _menu.buttons.append(b)
    _menu.first = gear
    return row


var _settings: Control = null     # the settings, open over the ride


## The settings over the ride (the gear button or Esc); the ride goes on underneath.
func _toggle_settings() -> void:
    if _settings:
        _settings.queue_free()
        _settings = null
        return
    _settings = preload("res://ui/settings_screen.gd").new()
    _settings.app = app
    _settings.args = {"overlay": true, "on_close": _toggle_settings}
    _settings.set_anchors_preset(Control.PRESET_FULL_RECT)
    add_child(_settings)
    if _menu.open:
        _menu.focus_settings.call_deferred(_settings)


## Y on the Click (or Tab), before the buttons see it; B goes back while the menu is open.
func _input(event: InputEvent) -> void:
    if event.is_action_pressed("meny"):
        _menu.toggle()
        get_viewport().set_input_as_handled()
    elif _menu.open and event.is_action_pressed("ui_cancel"):
        _menu.back()
        get_viewport().set_input_as_handled()


func _exit_tree() -> void:
    Controls.menu_open = false


func _nudge(direction: int) -> void:
    if Ride.player:
        Ride.change_intensity(0.05 * direction)
    else:
        _adjust_free(direction)


func _set_free_mode(use_erg: bool) -> void:
    if Ride.erg != use_erg:
        Ride.toggle_mode()


func _adjust_free(direction: int) -> void:
    if Ride.erg:
        Ride.change_free_watts(10 * direction)
    elif not _world_mode:          # in a world the road sets the grade
        Ride.change_grade(0.5 * direction)
    else:
        Ride.change_gear(direction)


## Actions come from the keys and from the Zwift Click buttons alike (see core/controls.gd).
## → also skips a step here, as before.
func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("installningar"):
        _toggle_settings()
        get_viewport().set_input_as_handled()
        return
    if _settings:
        return
    if event.is_action_pressed("paus"):
        Ride.toggle_pause()
    elif event.is_action_pressed("nasta_steg") or event.is_action_pressed("titta_hoger"):
        Ride.skip_segment()
    elif event.is_action_pressed("tyngre"):
        _nudge(1)
    elif event.is_action_pressed("lattare"):
        _nudge(-1)
    elif event.is_action_pressed("byt_lage"):
        Ride.toggle_mode()
    elif event is InputEventKey and event.pressed and Ride.sim:
        if event.keycode == KEY_W:
            Ride.sim.bias += 10.0
        elif event.keycode == KEY_S:
            Ride.sim.bias -= 10.0


# --- Per-frame update ---------------------------------------------------------------------------

func _process(delta: float) -> void:
    if _world_mode and app.world:
        # The road decides the grade (sent to the trainer in SIM) and where the rider is drawn.
        Ride.grade = app.world.grade_at(Ride.distance)
        Ride.grade_ahead = app.world.grade_at(Ride.distance + Ride.speed * Ride.GRADE_LOOKAHEAD)
        app.world.update_view(Ride.distance, Ride.speed, Ride.cadence, delta)
        _profile.distance = Ride.distance
        _profile.grade = Ride.grade
        _profile.queue_redraw()
    _metric_labels[0].text = Style.dec(Ride.speed * 3.6)
    _metric_labels[1].text = Style.dec(Ride.distance / 1000.0, 2)
    _metric_labels[2].text = "%d" % roundi(Ride.elevation_gain)
    _metric_labels[3].text = Style.clock(Ride.moving_time)
    var shown := Ride.display_power()
    var slots: Array = []
    for i in 4:
        var key: String = Settings.hud_slots[i]
        slots.append(_slot(key) + [key])
    _power.show_values(roundi(shown), shown / float(maxi(Settings.ftp, 1)), slots)
    _source_label.text = Ride.source_description()
    var hint := tr("Mellanslag paus · → hoppa · ↑↓ intensitet · M läge") if Ride.player else tr("↑↓ ändrar watt eller lutning · M byter läge")
    if Ride.sim:
        hint += tr("\nLåtsastrainer: W/S gör låtsascyklisten starkare/svagare (%+d W)") % roundi(Ride.sim.bias)
    _hint_label.text = hint
    if Ride.player:
        _update_workout(shown)
    else:
        _update_free()
    if _graph:
        _graph.queue_redraw()


func _slot(key: String) -> Array:
    match key:
        "cadence":
            return ["%d" % roundi(Ride.cadence), tr("rpm kadens")]
        "avg_power":
            return ["%d" % roundi(Ride.avg_power()), tr("W snitt")]
        "hr":
            return ["%d" % roundi(Ride.hr) if Ride.hr > 0.0 else "–", tr("bpm puls")]
        "kj":
            return ["%d" % roundi(Ride.kj), "kJ"]
        "max_power":
            return ["%d" % Ride.max_power, tr("W max")]
        "np":
            return ["%d" % roundi(Ride.np_live), tr("W NP")]
        "wkg":
            return [Style.dec(Ride.display_power() / Settings.weight_kg), "W/kg"]
        "speed":
            return [Style.dec(Ride.speed * 3.6), "km/h"]
    return ["–", key]


func _update_workout(shown: float) -> void:
    var player = Ride.player
    var segment: Dictionary = player.segment()
    var target: int = player.target_watts()
    if player.finished or segment.is_empty():
        _step_title.text = tr("PASSET ÄR KLART")
        _step_target.text = tr("Bra jobbat!")
        _step_detail.text = tr("Rulla vidare så länge du vill och tryck Avsluta.")
        _step_delta.text = ""
        _step_next.text = ""
        _step_bar.value = 100
    else:
        _step_title.text = tr(str(segment["label"])).to_upper()
        _step_target.text = "%d W" % target if target > 0 else tr("Fritt")
        var detail := tr("i %s") % Style.clock(player.time_left_in_segment())
        if segment["cadence"] > 0:
            detail += "  ·  %d rpm" % segment["cadence"]
        _step_detail.text = detail
        _step_bar.value = 100.0 * (1.0 - player.time_left_in_segment() / segment["duration"])
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
            _step_next.text = tr("Sedan: %s %s i %s") % [tr(n["label"]), _watts_text(n), Style.clock(n["duration"])]
        else:
            _step_next.text = tr("Sedan: klart!")
    var status: Array[String] = []
    status.append(tr("ERG – trainern håller watten") if Ride.erg else tr("SIM – du håller watten med växel och kadens"))
    if Ride.paused:
        status.append(tr("passet är pausat (mellanslag fortsätter)"))
    if Ride.guard_active:
        status.append(tr("kadensskydd: målet är sänkt tills du trampar runt 70 rpm igen"))
    _status_label.text = "  ·  ".join(status)
    _pause_button.text = tr("Fortsätt passet") if Ride.paused else tr("Pausa passet")
    _mode_button.text = tr("Byt till SIM") if Ride.erg else tr("Byt till ERG")
    _finish_label.text = tr("Klar om %s") % Style.clock(player.time_left())
    _intensity_label.text = "%d %%" % roundi(player.intensity * 100.0)
    var stars: Vector2i = player.stars()
    _stars_label.text = "★ %d/%d" % [stars.x, stars.y]
    _update_list()
    _graph.progress = player.elapsed
    _graph.intensity = player.intensity
    _graph.actual = Ride.power_history


func _watts_text(s: Dictionary) -> String:
    if s["free"]:
        return "fritt"
    var player = Ride.player
    var a: int = player.watts_at(s["from"])
    var b: int = player.watts_at(s["to"])
    return "%d W" % a if a == b else "%d→%d W" % [a, b]


## Rebuild the step list only when the current step or the intensity changes.
func _update_list() -> void:
    var player = Ride.player
    var key := "%d|%.2f" % [player.index(), player.intensity]
    if key == _list_key:
        return
    _list_key = key
    for child in _list_box.get_children():
        child.queue_free()
    var current: int = player.index()
    for i in Ride.workout.segments.size():
        var s: Dictionary = Ride.workout.segments[i]
        var row := Style.panel(Style.PANEL_LIGHT if i == current else Color(0, 0, 0, 0), 8, 6)
        var line := Style.hbox(10)
        var strip := ColorRect.new()
        strip.custom_minimum_size = Vector2(8, 24)
        strip.color = Color("6c7280") if s["free"] else Zones.color((s["from"] + s["to"]) * 0.5 * player.intensity)
        line.add_child(strip)
        var done: bool = i < current or player.finished
        var text := Style.label("%s  %s" % [Style.clock(s["duration"]), _watts_text(s)], 18,
            Style.TEXT_DIM if done else Style.TEXT, 700 if i == current else 500)
        line.add_child(text)
        row.add_child(line)
        _list_box.add_child(row)


func _update_free() -> void:
    Style.set_selected(_free_erg, Ride.erg)
    Style.set_selected(_free_sim, not Ride.erg)
    _free_minus.visible = true
    _free_plus.visible = true
    if Ride.erg:
        _free_value.text = "%d W" % Ride.free_watts
        _free_caption.text = tr("Trainern håller %d W oavsett växel och kadens. ↑↓ ändrar 10 W.") % Ride.free_watts
    elif _world_mode:
        _free_minus.visible = false
        _free_plus.visible = false
        _free_value.text = "%s %%" % Style.dec(Ride.grade)
        _free_caption.text = tr("Trainern känns som vägen. Välj watt själv med växlarna.")
    else:
        _free_value.text = "%s %%" % Style.dec(Ride.grade)
        _free_caption.text = tr("Trainern känns som en väg med %s %% lutning. Välj watt själv med växlarna.") % Style.dec(Ride.grade)
    _status_label.text = tr("Rulla på!") if Ride.power > 0.0 else tr("Börja trampa så startar klockan.")
    if _graph:
        _graph.values = Ride.power_history
