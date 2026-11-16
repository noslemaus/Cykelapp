extends Control
## One ride from the history: the numbers, the power over the ride, the segments, laps and records,
## and the FIT file and Strava. args: {"ride": Dictionary from Progress.data["rides"]}

const Style = preload("res://ui/style.gd")
const Zones = preload("res://core/zones.gd")
const PowerCurve = preload("res://core/power_curve.gd")
const History = preload("res://ui/history.gd")

var app
var args := {}
var _strava_button: Button
var _strava_text: Label


func _ready() -> void:
    var r: Dictionary = args["ride"]
    var root := Style.vbox(16)
    add_child(Style.margin(root, 32))
    root.add_child(Style.header(tr(str(r.get("name", ""))), tr("Historik"), func(): app.go("history")))
    var sub := History.when(float(r.get("date", 0.0)))
    if str(r.get("world", "")) != "":
        sub += "  ·  " + tr(str(r["world"]))
    if r.get("pretend", false):
        sub += "  ·  " + tr("Låtsastrainer")
    root.add_child(Style.label(sub, 18, Style.TEXT_DIM, 700))

    var grid := GridContainer.new()
    grid.columns = 6
    grid.add_theme_constant_override("h_separation", 12)
    grid.add_theme_constant_override("v_separation", 12)
    var hr := float(r.get("avg_hr", 0.0))
    for t in [[Style.clock(float(r.get("seconds", 0.0))), tr("tid")], [Style.dec(float(r.get("km", 0.0)), 2), "km"],
            ["%d" % roundi(float(r.get("avg_w", 0.0))), tr("W snitt")], ["%d" % int(r.get("max_w", 0)), tr("W max")],
            ["%d" % roundi(float(r.get("np", 0.0))), tr("W NP")], [Style.dec(float(r.get("if", 0.0)), 2), "IF"],
            ["%d" % roundi(float(r.get("tss", 0.0))), "TSS"], ["%d" % int(r.get("kj", 0)), "kJ"],
            ["%d" % roundi(hr) if hr > 0 else "–", tr("bpm snitt")], ["%d" % roundi(float(r.get("elev", 0.0))), tr("höjdmeter")],
            ["%d" % roundi(float(r.get("avg_cad", 0.0))), tr("rpm snitt")], ["+%d" % int(r.get("xp", 0)), "XP"]]:
        var tile := Style.panel(Style.PANEL, 12, 10)
        tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        var box := Style.vbox(-2)
        box.add_child(Style.label(t[0], 26, Style.TEXT, 800))
        box.add_child(Style.label(t[1], 13, Style.TEXT_DIM, 600))
        tile.add_child(box)
        grid.add_child(tile)
    root.add_child(grid)

    var graph := PowerGraph.new()
    graph.watts = r.get("watts", [])
    graph.custom_minimum_size = Vector2(0, 190)
    root.add_child(graph)

    var lines: Array[String] = []
    if r.get("completed", false):
        var st: Array = r.get("stars", [0, 0])
        lines.append(tr("✓ Hela passet genomfört") + (("  ·  ★ %d/%d" % [st[0], st[1]]) if int(st[1]) > 0 else ""))
    for b in r.get("bests", []):
        lines.append(tr("★ Personbästa %s: %d W") % [PowerCurve.label(int(b[0])), int(b[1])])
    for lap in r.get("laps", []):
        lines.append((("★ " if lap.get("pr", false) else "") + tr("Varv i %s: %s") % [tr(Progress.WORLD_NAMES.get(lap["world"], lap["world"])),
            Style.clock(float(lap["time"]))]))
    for s in r.get("segments", []):
        var t := float(s["time"])
        lines.append(("★ " if s.get("pr", false) else "") + "%s: %s" % [tr(s["name"]), "%s s" % Style.dec(t) if t < 60.0 else Style.clock(t)])
    if lines.is_empty():
        lines.append(tr("Inga segment eller rekord den här gången."))
    var rec := Style.panel(Style.PANEL, 12, 14)
    var rbox := Style.vbox(2)
    rec.add_child(rbox)
    for line in lines.slice(0, 8):
        rbox.add_child(Style.label(line, 16, Color("ffd34d") if line.begins_with("★") else Style.TEXT, 700))
    root.add_child(rec)
    root.add_child(Style.spacer())

    var actions := Style.hbox(14)
    var fit := str(r.get("fit", ""))
    var fit_path := ProjectSettings.globalize_path(Ride.fit_folder.path_join(fit)) if fit != "" else ""
    if fit_path != "" and FileAccess.file_exists(fit_path):
        var show := Style.button(tr("Visa i Utforskaren") if OS.get_name() == "Windows" else tr("Visa i Finder"), "secondary", 18)
        show.pressed.connect(func(): OS.shell_show_in_file_manager(fit_path))
        actions.add_child(show)
    _strava_button = Style.button("", "primary", 18)
    _strava_text = Style.label("", 16, Style.TEXT_DIM, 600)
    _strava_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var url := str(r.get("strava", ""))
    if url != "":
        _strava_button.text = tr("Öppna i Strava")
        _strava_button.pressed.connect(func(): OS.shell_open(url))
    elif fit_path != "" and FileAccess.file_exists(fit_path) and Strava.is_linked() and not r.get("pretend", false):
        _strava_button.text = tr("Ladda upp till Strava")
        _strava_button.pressed.connect(func():
            _strava_button.disabled = true
            Strava.upload_finished.connect(_on_uploaded, CONNECT_ONE_SHOT)
            Strava.upload(fit_path, tr(str(r.get("name", ""))), tr("körd i Cykelapp")))
    else:
        _strava_button.visible = false
    actions.add_child(_strava_button)
    actions.add_child(_strava_text)
    root.add_child(actions)


func _on_uploaded(ok: bool, message: String, link: String) -> void:
    _strava_text.text = message
    if ok and link != "":
        var r: Dictionary = args["ride"]
        Progress.mark_strava(float(r["id"]), link)
        _strava_button.text = tr("Öppna i Strava")


## The ride's power every 10 seconds, coloured by zone.
class PowerGraph extends Control:
    var watts: Array = []

    func _draw() -> void:
        draw_style_box(Style.flat(Style.GRAPH_BG, 12), Rect2(Vector2.ZERO, size))
        var n := watts.size()
        if n < 2:
            return
        var top := 0.0
        for w in watts:
            top = maxf(top, float(w))
        top = maxf(top * 1.1, float(Settings.ftp) * 1.2)
        var left := 12.0
        var right := size.x - 12.0
        var h := size.y - 24.0
        var step := (right - left) / n
        for i in n:
            var w := float(watts[i])
            var y := 12.0 + h - h * w / top
            draw_rect(Rect2(left + i * step, y, maxf(step, 1.0), 12.0 + h - y), Zones.COLORS[Zones.zone(w / float(maxi(Settings.ftp, 1)))])
        var fy := 12.0 + h - h * float(Settings.ftp) / top
        draw_line(Vector2(left, fy), Vector2(right, fy), Color(1, 1, 1, 0.4), 1.0)
        draw_string(Style.font(700), Vector2(left + 4, fy - 4), "FTP %d W" % Settings.ftp, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Style.TEXT_DIM)
