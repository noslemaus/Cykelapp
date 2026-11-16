extends Control
## The garage: your level, the bike and jersey you ride with (shown on a turning 3D rider), the battle
## vehicle's upgrades and your records (power curve, FTP, segments, best laps).
## args: {"tab": "cyklar" | "trojor" | "stridsvagn" | "rekord"}

const Style = preload("res://ui/style.gd")
const PowerCurve = preload("res://core/power_curve.gd")
const PowerCurveChart = preload("res://ui/power_curve_chart.gd")
const Rider = preload("res://world/rider.gd")

const TABS := [["cyklar", "Cyklar"], ["trojor", "Tröjor"], ["stridsvagn", "Stridsvagnen"], ["rekord", "Rekord"]]

var app
var args := {}
var _tab := "cyklar"
var _tab_buttons := {}
var _content: Control
var _rider: Node3D
var _look_name: Label


func _ready() -> void:
    _tab = str(args.get("tab", "cyklar"))
    var root := Style.vbox(18)
    add_child(Style.margin(root, 36))
    var head := Style.header(tr("Garaget"), tr("Meny"), func(): app.go("menu"))
    head.add_child(Style.spacer())
    head.add_child(_level_chip())
    root.add_child(head)

    var body := Style.hbox(22)
    body.size_flags_vertical = Control.SIZE_EXPAND_FILL
    root.add_child(body)
    body.add_child(_preview())

    var right := Style.vbox(14)
    right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var tabs := Style.hbox(10)
    for t in TABS:
        var b := Style.button(t[1], "secondary", 19)
        b.custom_minimum_size = Vector2(150, 50)
        var id: String = t[0]
        b.pressed.connect(func(): _show(id))
        tabs.add_child(b)
        _tab_buttons[id] = b
    right.add_child(tabs)
    var scroll := ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    _content = Style.vbox(14)
    _content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.add_child(_content)
    right.add_child(scroll)
    body.add_child(right)
    _show(_tab)


func _level_chip() -> Control:
    var chip := Style.panel(Style.PANEL, 14, 12)
    var box := Style.vbox(4)
    chip.add_child(box)
    var p := Progress.level_progress()
    var row := Style.hbox(12)
    row.add_child(Style.label(tr("Nivå %d") % Progress.level(), 24, Color("ffd34d"), 900))
    var xp_text := tr("%d XP totalt") % Progress.xp()
    if Progress.level() < Progress.MAX_LEVEL:
        xp_text = tr("%d / %d XP till nivå %d") % [p.x, p.y, Progress.level() + 1]
    var xl := Style.label(xp_text, 15, Style.TEXT_DIM, 700)
    xl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    row.add_child(xl)
    box.add_child(row)
    var bar := ProgressBar.new()
    bar.show_percentage = false
    bar.custom_minimum_size = Vector2(320, 8)
    bar.max_value = p.y
    bar.value = p.x
    bar.add_theme_stylebox_override("background", Style.flat(Color(0, 0, 0, 0.35), 4))
    bar.add_theme_stylebox_override("fill", Style.flat(Color("ffd34d"), 4))
    box.add_child(bar)
    return chip


## A slowly turning rider with the chosen jersey and bike, in its own little 3D world.
func _preview() -> Control:
    var card := Style.panel(Style.PANEL, 18, 0)
    card.custom_minimum_size = Vector2(500, 0)
    var box := Style.vbox(0)
    card.add_child(box)
    var holder := SubViewportContainer.new()
    holder.stretch = true
    holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
    holder.custom_minimum_size = Vector2(500, 520)
    var vp := SubViewport.new()
    vp.own_world_3d = true
    vp.transparent_bg = true
    vp.msaa_3d = Viewport.MSAA_4X
    holder.add_child(vp)
    var env := Environment.new()
    env.background_mode = Environment.BG_CLEAR_COLOR
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color("b8c4d8")
    env.ambient_light_energy = 0.9
    env.tonemap_mode = Environment.TONE_MAPPER_ACES
    env.tonemap_exposure = 1.05
    var we := WorldEnvironment.new()
    we.environment = env
    vp.add_child(we)
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-38, 35, 0)
    sun.light_color = Color("fff1dc")
    sun.light_energy = 2.0
    sun.shadow_enabled = true
    vp.add_child(sun)
    var fill := DirectionalLight3D.new()
    fill.rotation_degrees = Vector3(-15, -140, 0)
    fill.light_color = Color("9fc4ff")
    fill.light_energy = 0.7
    vp.add_child(fill)
    var floor_mesh := MeshInstance3D.new()
    var disc := CylinderMesh.new()
    disc.top_radius = 1.5
    disc.bottom_radius = 1.5
    disc.height = 0.04
    disc.radial_segments = 48
    floor_mesh.mesh = disc
    var floor_mat := StandardMaterial3D.new()
    floor_mat.albedo_color = Color("2b3341")
    floor_mat.roughness = 0.9
    floor_mesh.material_override = floor_mat
    floor_mesh.position = Vector3(0, -0.02, 0)
    vp.add_child(floor_mesh)
    _rider = Rider.new()
    vp.add_child(_rider)
    var cam := Camera3D.new()
    cam.keep_aspect = Camera3D.KEEP_WIDTH
    cam.fov = 30.0
    cam.look_at_from_position(Vector3(0.0, 1.3, 3.9), Vector3(0.0, 0.66, 0.0), Vector3.UP)
    vp.add_child(cam)
    box.add_child(holder)
    _look_name = Style.label("", 18, Style.TEXT, 800)
    _look_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    box.add_child(Style.margin(_look_name, 14))
    _refresh_look()
    return card


func _process(delta: float) -> void:
    if _rider:
        _rider.rotation.y += delta * 0.45
        _rider.animate(1.8, 60.0, delta)


func _refresh_look() -> void:
    if _rider and _rider.is_inside_tree():
        _rider.apply_look(Progress.look())
    _look_name.text = "%s  ·  %s" % [tr(Progress.bike()["name"]), tr(Progress.jersey()["name"])]


func _show(tab: String) -> void:
    _tab = tab
    for id in _tab_buttons:
        Style.set_selected(_tab_buttons[id], id == tab)
    for child in _content.get_children():
        child.queue_free()
    match tab:
        "cyklar":
            _bikes()
        "trojor":
            _jerseys()
        "stridsvagn":
            _upgrades()
        "rekord":
            _records()


func _card(selected: bool, open: bool) -> PanelContainer:
    var card := PanelContainer.new()
    var box := Style.flat(Style.PANEL if open else Color(Style.PANEL, 0.55), 14, 16)
    if selected:
        box.border_color = Style.ACCENT
        box.set_border_width_all(3)
    card.add_theme_stylebox_override("panel", box)
    card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    return card


func _grid() -> GridContainer:
    var grid := GridContainer.new()
    grid.columns = 2
    grid.add_theme_constant_override("h_separation", 14)
    grid.add_theme_constant_override("v_separation", 14)
    grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _content.add_child(grid)
    return grid


func _bikes() -> void:
    _content.add_child(_note(tr("Cykeln ändrar farten i världen: vikten i backarna, aerodynamiken på flacken och däcken på grus och i terrängen. Trainern känns likadan.")))
    var grid := _grid()
    for id in Progress.BIKE_ORDER:
        var b: Dictionary = Progress.BIKES[id]
        var open := Progress.unlocked("bike", id)
        var card := _card(id == Progress.bike_id(), open)
        var box := Style.vbox(6)
        card.add_child(box)
        var row := Style.hbox(10)
        var swatch := ColorRect.new()
        swatch.color = Color(b["frame"])
        swatch.custom_minimum_size = Vector2(16, 16)
        swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        row.add_child(swatch)
        row.add_child(Style.label(b["name"], 22, Style.TEXT if open else Style.TEXT_DIM, 900))
        box.add_child(row)
        var text := Style.label(b["text"], 15, Style.TEXT_DIM, 600)
        text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        box.add_child(text)
        box.add_child(_stat(tr("Backar"), clampf((12.5 - float(b["kg"])) / 6.0, 0.05, 1.0), "%s kg" % Style.dec(b["kg"])))
        box.add_child(_stat(tr("Flack"), clampf((0.43 - float(b["cda"])) / 0.18, 0.05, 1.0), "CdA %s" % Style.dec(b["cda"], 3)))
        box.add_child(_stat(tr("Terräng"), clampf((0.02 - float(b["crr"]["terrang"])) / 0.0125, 0.05, 1.0), ""))
        if not open:
            box.add_child(Style.label(tr("LÅST  ·  ") + Progress.requirement("bike", id), 15, Color("f0b232"), 800))
        elif id == Progress.bike_id():
            box.add_child(Style.label(tr("DU CYKLAR MED DEN HÄR"), 14, Style.ACCENT, 900))
        if open:
            Style.clickable(card, func():
                Progress.set_bike(id)
                Ride.apply_bike()
                _refresh_look()
                _show("cyklar"))
        grid.add_child(card)


func _stat(name: String, share: float, value: String) -> Control:
    var row := Style.hbox(10)
    var l := Style.label(name, 14, Style.TEXT_DIM, 700)
    l.custom_minimum_size.x = 70
    row.add_child(l)
    var bar := ProgressBar.new()
    bar.show_percentage = false
    bar.max_value = 1.0
    bar.value = share
    bar.custom_minimum_size = Vector2(0, 8)
    bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    bar.add_theme_stylebox_override("background", Style.flat(Color(0, 0, 0, 0.35), 4))
    bar.add_theme_stylebox_override("fill", Style.flat(Style.ACCENT, 4))
    row.add_child(bar)
    var v := Style.label(value, 13, Style.TEXT_DIM, 600)
    v.custom_minimum_size.x = 72
    row.add_child(v)
    return row


func _jerseys() -> void:
    _content.add_child(_note(tr("Tröjor låses upp med nivåer och med det du gör: klättringar, spurter, ett helt varv i en värld och att slå ditt eget spöke.")))
    var grid := _grid()
    grid.columns = 3
    for id in Progress.JERSEY_ORDER:
        var j: Dictionary = Progress.JERSEYS[id]
        var open := Progress.unlocked("jersey", id)
        var card := _card(id == Progress.jersey_id(), open)
        var row := Style.hbox(14)
        card.add_child(row)
        var swatch := JerseySwatch.new()
        swatch.main = Color(j["main"])
        swatch.accent = Color(j["accent"])
        swatch.dim = not open
        swatch.custom_minimum_size = Vector2(56, 60)
        row.add_child(swatch)
        var box := Style.vbox(2)
        box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        box.add_child(Style.label(j["name"], 19, Style.TEXT if open else Style.TEXT_DIM, 900))
        var req := Style.label(tr("På dig nu") if id == Progress.jersey_id() else (tr("Upplåst") if open else Progress.requirement("jersey", id)),
            13, Style.ACCENT if id == Progress.jersey_id() else (Style.TEXT_DIM if open else Color("f0b232")), 700)
        req.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        box.add_child(req)
        row.add_child(box)
        if open:
            Style.clickable(card, func():
                Progress.set_jersey(id)
                _refresh_look()
                _show("trojor"))
        grid.add_child(card)


func _upgrades() -> void:
    _content.add_child(_note(tr("Poängen från striderna (i alla världar) samlas här: %d stridspoäng hittills. Uppgraderingarna gäller stridsvagnen, pickupen och samurajen.") % Progress.battle_points()))
    var grid := _grid()
    for id in Progress.UPGRADE_ORDER:
        var u: Dictionary = Progress.UPGRADES[id]
        var open := Progress.upgrade_on(id)
        var card := _card(open, open)
        var box := Style.vbox(6)
        card.add_child(box)
        box.add_child(Style.label(u["name"], 22, Style.TEXT if open else Style.TEXT_DIM, 900))
        box.add_child(Style.label(u["text"], 15, Style.TEXT_DIM, 600))
        var bar := ProgressBar.new()
        bar.show_percentage = false
        bar.max_value = float(u["points"])
        bar.value = minf(Progress.battle_points(), float(u["points"]))
        bar.custom_minimum_size = Vector2(0, 8)
        bar.add_theme_stylebox_override("background", Style.flat(Color(0, 0, 0, 0.35), 4))
        bar.add_theme_stylebox_override("fill", Style.flat(Style.ACCENT if open else Color("f0b232"), 4))
        box.add_child(bar)
        box.add_child(Style.label(tr("PÅ") if open else Progress.requirement("upgrade", id), 14, Style.ACCENT if open else Color("f0b232"), 800))
        grid.add_child(card)


func _records() -> void:
    var top := Style.hbox(14)
    var chart := PowerCurveChart.new()
    chart.custom_minimum_size = Vector2(0, 250)
    chart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var all_time := {}
    for d in PowerCurve.DURATIONS:
        var w := Progress.best_power(d)
        if w > 0.0:
            all_time[str(d)] = w
    chart.curves = [[Progress.curve_since(90), Color(Style.ACCENT, 0.9), 2.0], [all_time, Color("ffd34d"), 3.0]]
    top.add_child(chart)
    var side := Style.vbox(8)
    side.custom_minimum_size.x = 250
    side.add_child(Style.label(tr("PERSONBÄSTA"), 13, Style.TEXT_DIM, 800))
    for d in PowerCurve.KEY:
        var w := Progress.best_power(d)
        var row := Style.hbox(8)
        var l := Style.label(PowerCurve.label(d), 17, Style.TEXT_DIM, 700)
        l.custom_minimum_size.x = 70
        row.add_child(l)
        row.add_child(Style.label("%d W" % roundi(w) if w > 0.0 else "–", 22, Color("ffd34d"), 900))
        side.add_child(row)
    var legend := Style.label(tr("Gult: genom tiderna. Turkos: senaste 90 dagarna."), 12, Style.TEXT_DIM, 600)
    legend.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    side.add_child(legend)
    var ftp_row := Style.hbox(8)
    ftp_row.add_child(Style.label("FTP %d W" % Settings.ftp, 20, Style.TEXT, 900))
    side.add_child(ftp_row)
    var auto := CheckButton.new()
    auto.text = tr("Höj FTP av sig själv")
    auto.button_pressed = Settings.auto_ftp
    auto.focus_mode = Control.FOCUS_NONE
    auto.add_theme_font_size_override("font_size", 15)
    auto.toggled.connect(func(on: bool):
        Settings.auto_ftp = on
        Settings.save())
    side.add_child(auto)
    var hint := Style.label(tr("95 % av din bästa 20-minuterswatt. Den sänks aldrig av sig själv."), 12, Style.TEXT_DIM, 600)
    hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    side.add_child(hint)
    top.add_child(side)
    _content.add_child(top)

    for world_id in app.WORLDS:
        var world_name: String = app.WORLDS[world_id]["name"]
        var card := _card(false, true)
        var box := Style.vbox(4)
        card.add_child(box)
        var head := Style.hbox(10)
        head.add_child(Style.label(tr(world_name).to_upper(), 15, Style.TEXT, 900))
        var lap = Progress.data["laps"].get(world_id)
        var laps_done := int(Progress.data["lap_counts"].get(world_id, 0))
        var lap_text := tr("Bästa varv %s  ·  %d varv") % [Style.clock(float(lap["time"])), laps_done] if lap is Dictionary else tr("Inget helt varv än")
        head.add_child(Style.label(lap_text, 15, Color("6fe8ff"), 700))
        box.add_child(head)
        var segs: Array = _world_segments(world_id)
        for seg in segs:
            var rec := Progress.segment_record(world_id, seg["id"])
            var row := Style.hbox(10)
            var n := Style.label("%s  (%s)" % [tr(seg["name"]), tr("klättring") if seg["kind"] == "climb" else tr("spurt")], 15, Style.TEXT_DIM, 600)
            n.custom_minimum_size.x = 300
            row.add_child(n)
            if rec.is_empty():
                row.add_child(Style.label("–", 15, Style.TEXT_DIM, 700))
            else:
                var t := float(rec["time"])
                row.add_child(Style.label("%s s" % Style.dec(t) if t < 60.0 else Style.clock(t), 16, Color("ffd34d"), 800))
                row.add_child(Style.label(tr("%d gånger") % int(rec["count"]), 13, Style.TEXT_DIM, 600))
            box.add_child(row)
        _content.add_child(card)


## The segments of a world without building it: the world scripts list them in segments().
func _world_segments(world_id: String) -> Array:
    var script: GDScript = load(app.WORLDS[world_id]["script"])
    var temp = script.new()
    var list: Array = temp.segments() if temp.has_method("segments") else []
    temp.free()
    return list


func _note(text: String) -> Label:
    var l := Style.label(text, 16, Style.TEXT_DIM, 600)
    l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    return l


## A little jersey: body and sleeves in the main colour with the accent as a cross.
class JerseySwatch extends Control:
    var main := Color.WHITE
    var accent := Color.BLACK
    var dim := false

    func _draw() -> void:
        var m := main if not dim else main.darkened(0.55)
        var a := accent if not dim else accent.darkened(0.55)
        var w := size.x
        var h := size.y
        var body := PackedVector2Array([Vector2(w * 0.28, h * 0.08), Vector2(w * 0.72, h * 0.08),
            Vector2(w, h * 0.3), Vector2(w * 0.86, h * 0.46), Vector2(w * 0.76, h * 0.38),
            Vector2(w * 0.76, h), Vector2(w * 0.24, h), Vector2(w * 0.24, h * 0.38),
            Vector2(w * 0.14, h * 0.46), Vector2(0, h * 0.3)])
        draw_colored_polygon(body, m)
        draw_rect(Rect2(w * 0.24, h * 0.5, w * 0.52, h * 0.11), a)
        draw_rect(Rect2(w * 0.38, h * 0.2, w * 0.11, h * 0.8), a)
        draw_polyline(body + PackedVector2Array([body[0]]), Color(0, 0, 0, 0.35), 1.5, true)
