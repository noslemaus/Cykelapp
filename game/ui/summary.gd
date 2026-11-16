extends Control
## After the ride: key numbers, time in zone, the saved FIT file and the Strava choice.

const Style = preload("res://ui/style.gd")
const Zones = preload("res://core/zones.gd")
const PowerCurve = preload("res://core/power_curve.gd")

var app
var args := {}


func _ready() -> void:
    var s: Dictionary = Ride.summary
    var root := Style.vbox(14)
    add_child(Style.margin(root, 32))
    # Everything but the buttons scrolls, so Strava and "Till menyn" stay in view however much
    # the ride has to show (records, unlocks, pictures) and however small the window is.
    var scroll := ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    var body := Style.vbox(14)
    body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.add_child(body)
    root.add_child(scroll)
    var title := Style.vbox(2)
    title.add_child(Style.label(tr("Bra jobbat!"), 40, Style.TEXT, 900))
    var line: String = tr(s.get("name", ""))
    var stars: Vector2i = s.get("stars", Vector2i.ZERO)
    if stars.y > 0:
        line += tr("  ·  ★ %d av %d nyckelblock klarade") % [stars.x, stars.y]
    if s.get("completed", false):
        line += tr("  ·  hela passet genomfört")
    title.add_child(Style.label(line, 20, Style.TEXT_DIM, 600))
    body.add_child(title)

    var grid := GridContainer.new()
    grid.columns = 6
    grid.add_theme_constant_override("h_separation", 14)
    grid.add_theme_constant_override("v_separation", 12)
    var tiles := [
        [Style.clock(s.get("moving_time", 0.0)), tr("tid")],
        [Style.dec(s.get("distance", 0.0) / 1000.0, 2), "km"],
        ["%d" % roundi(s.get("avg_power", 0.0)), tr("W snitt")],
        ["%d" % s.get("max_power", 0), tr("W max")],
        ["%d" % roundi(s.get("np", 0.0)), tr("W NP")],
        [Style.dec(s.get("if", 0.0), 2), "IF"],
        ["%d" % roundi(s.get("tss", 0.0)), "TSS"],
        ["%d" % roundi(s.get("kj", 0.0)), "kJ"],
        ["%d" % roundi(s.get("avg_hr", 0.0)) if s.get("avg_hr", 0.0) > 0 else "–", tr("bpm snitt")],
        ["%d" % s.get("max_hr", 0) if s.get("max_hr", 0) > 0 else "–", tr("bpm max")],
        ["%d" % roundi(s.get("avg_cadence", 0.0)), tr("rpm snitt")],
        ["%d" % roundi(s.get("elevation_gain", 0.0)), tr("höjdmeter")],
    ]
    for t in tiles:
        var tile := Style.panel(Style.PANEL, 14, 12)
        tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        var box := Style.vbox(-2)
        box.add_child(Style.label(t[0], 30, Style.TEXT, 800))
        box.add_child(Style.label(t[1], 15, Style.TEXT_DIM, 600))
        tile.add_child(box)
        grid.add_child(tile)
    body.add_child(grid)

    body.add_child(Style.label(tr("Tid i zon (faktisk watt)"), 18, Style.TEXT_DIM, 700))
    body.add_child(_zone_bars(s.get("zone_seconds", [0, 0, 0, 0, 0, 0])))
    if not Ride.progress_report.is_empty():
        body.add_child(_progress_row(Ride.progress_report))
    body.add_child(_pictures_row())

    var file_row := Style.hbox(14)
    var path := Ride.fit_path
    var file_text := Style.label(tr("FIT-fil sparad: %s") % path.get_file() if path != "" else tr("Ingen data att spara."), 18, Style.TEXT_DIM, 500)
    file_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    file_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    file_row.add_child(file_text)
    if path != "":
        var show := Style.button(tr("Visa i Utforskaren") if OS.get_name() == "Windows" else tr("Visa i Finder"), "secondary", 18)
        show.pressed.connect(func(): OS.shell_show_in_file_manager(path))
        file_row.add_child(show)
    body.add_child(file_row)

    var actions := Style.hbox(14)
    _strava_button = Style.button("", "primary", 20)
    _strava_button.pressed.connect(_on_strava_pressed)
    actions.add_child(_strava_button)
    _strava_text = Style.label("", 17, Style.TEXT_DIM, 600)
    _strava_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _strava_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    actions.add_child(_strava_text)
    Strava.upload_finished.connect(_on_uploaded)
    _refresh_strava()
    var done := Style.button(tr("Till menyn"), "primary", 22)
    done.pressed.connect(func():
        Ride.back_to_idle()
        app.go("menu"))
    actions.add_child(done)
    root.add_child(actions)


var _strava_button: Button
var _strava_text: Label
var _strava_url := ""


func _refresh_strava() -> void:
    if _strava_url != "":
        _strava_button.text = tr("Öppna i Strava")
        _strava_button.disabled = false
    elif Ride.fit_path == "":
        _strava_button.text = tr("Ladda upp till Strava")
        _strava_button.disabled = true
        _strava_text.text = tr("Turen är för kort för att sparas.")
    elif not Strava.is_linked():
        _strava_button.text = tr("Koppla Strava")
        _strava_button.disabled = false
        _strava_text.text = tr("Koppla Strava i inställningarna, så kan du ladda upp härifrån.")
    else:
        _strava_button.text = tr("Laddar upp…") if Strava.busy else tr("Ladda upp till Strava")
        _strava_button.disabled = Strava.busy
        _strava_text.text = tr("Du väljer själv: passet laddas bara upp om du trycker.") if not Strava.busy else Strava.status


func _on_strava_pressed() -> void:
    if _strava_url != "":
        OS.shell_open(_strava_url)
    elif not Strava.is_linked():
        app.go("settings", {"tab": "strava"})
    else:
        var s: Dictionary = Ride.summary
        var title: String = app.activity_title(s)
        var description := tr("%s · NP %d W · IF %s · TSS %d · körd i Cykelapp") % [
            title, roundi(s.get("np", 0.0)), Style.dec(s.get("if", 0.0), 2), roundi(s.get("tss", 0.0))]
        Strava.upload(Ride.fit_path, title, description)
        _refresh_strava()


func _on_uploaded(ok: bool, message: String, url: String) -> void:
    _strava_url = url if ok else ""
    if ok and url != "":
        Progress.mark_strava(Ride.started_unix, url)
    _strava_text.text = message
    _strava_text.add_theme_color_override("font_color", Style.ACCENT if ok else Color("f07b32"))
    _refresh_strava()
    if not ok:
        _strava_text.text = message


## The three pictures from the ride (core/turbilder.gd): made from photos taken in the world, with
## the ride's numbers drawn on; "Spara bilder" puts them in Downloads/Cykelapp.
var _pics_row: HBoxContainer
var _pics_text: Label


func _pictures_row() -> Control:
    var row := Style.hbox(14)
    _pics_row = row
    var tb = app.turbilder
    if tb == null or tb.shots.is_empty():
        row.visible = false
        return row
    _pics_text = Style.label(tr("Gör bilder från turen …"), 17, Style.TEXT_DIM, 600)
    row.add_child(_pics_text)
    tb.composed.connect(_on_pictures, CONNECT_ONE_SHOT)
    tb.compose(app.activity_title(Ride.summary))
    return row


func _on_pictures() -> void:
    var tb = app.turbilder
    if not is_instance_valid(_pics_row):
        return
    _pics_text.queue_free()
    if tb.images.is_empty():
        _pics_row.visible = false
        return
    for img in tb.images:
        var thumb := TextureRect.new()
        thumb.texture = ImageTexture.create_from_image(img)
        thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
        thumb.custom_minimum_size = Vector2(256, 144)
        _pics_row.add_child(thumb)
    var col := Style.vbox(6)
    col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    var save := Style.button(tr("Spara bilder"), "secondary", 18)
    var info := Style.label(tr("Tre bilder med turens siffror."), 15, Style.TEXT_DIM, 600)
    save.pressed.connect(func():
        var folder: String = tb.save()
        var home := OS.get_environment("USERPROFILE") if OS.get_name() == "Windows" else OS.get_environment("HOME")
        info.text = tr("Sparade i %s") % (folder.replace(home, "~") if home != "" else folder)
        OS.shell_show_in_file_manager(folder))
    col.add_child(save)
    col.add_child(info)
    _pics_row.add_child(col)


func _zone_bars(zone_seconds: Array) -> Control:
    var total := 0
    for v in zone_seconds:
        total += v
    var row := Style.hbox(14)
    for i in 6:
        var share := float(zone_seconds[i]) / maxf(total, 1)
        var box := Style.vbox(2)
        box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        var bar_bg := Style.panel(Style.PANEL, 8, 0)
        bar_bg.custom_minimum_size.y = 44
        var fill := ColorRect.new()
        fill.color = Zones.COLORS[i]
        fill.custom_minimum_size.y = 44.0 * share
        fill.size_flags_vertical = Control.SIZE_SHRINK_END
        bar_bg.add_child(fill)
        box.add_child(bar_bg)
        box.add_child(Style.label("Z%d %s  ·  %d %%  ·  %s" % [i + 1, tr(Zones.NAMES[i]), roundi(share * 100.0), Style.clock(zone_seconds[i])], 15, Style.TEXT, 700))
        row.add_child(box)
    return row


## XP and level on the left, the ride's records on the right.
func _progress_row(r: Dictionary) -> Control:
    var row := Style.hbox(16)
    var xp_card := Style.panel(Style.PANEL, 14, 16)
    xp_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var xbox := Style.vbox(4)
    xp_card.add_child(xbox)
    if not r["counts"]:
        # The pretend trainer makes its watts up: no XP, records or FTP.
        xbox.add_child(Style.label(tr("Ingen XP"), 30, Style.TEXT_DIM, 900))
        var note := Style.label(tr("Låtsastrainer: XP, rekord och FTP räknas bara med en riktig trainer."), 15,
            Color("f0b232"), 700)
        note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        xbox.add_child(note)
    else:
        var head := Style.hbox(14)
        head.add_child(Style.label("+%d XP" % int(r["xp"]), 30, Color("ffd34d"), 900))
        var lv := int(r["level_after"])
        var level_text := tr("Nivå %d") % lv
        if lv > int(r["level_before"]):
            level_text = tr("Ny nivå: %d!") % lv
        var lv_label := Style.label(level_text, 22, Style.TEXT, 800)
        lv_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        head.add_child(lv_label)
        xbox.add_child(head)
        var total := Progress.xp()
        var bar := ProgressBar.new()
        bar.show_percentage = false
        bar.custom_minimum_size = Vector2(0, 10)
        bar.min_value = Progress.xp_for(lv)
        bar.max_value = Progress.xp_for(mini(lv + 1, Progress.MAX_LEVEL))
        bar.value = total
        bar.add_theme_stylebox_override("background", Style.flat(Color(0, 0, 0, 0.35), 5))
        bar.add_theme_stylebox_override("fill", Style.flat(Color("ffd34d"), 5))
        xbox.add_child(bar)
        var parts: Array[String] = []
        for line in r["lines"]:
            parts.append("%s +%d" % [line[0], line[1]])
        var why := Style.label("  ·  ".join(parts.slice(0, 5)), 15, Style.TEXT_DIM, 600)
        why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        xbox.add_child(why)
        if not r["unlocks"].is_empty():
            var names: Array[String] = []
            for key in r["unlocks"]:
                names.append(Progress.unlock_name(key))
            var un := Style.label(tr("Upplåst i garaget: ") + ", ".join(names), 16, Color("7dff9a"), 800)
            un.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
            xbox.add_child(un)
    row.add_child(xp_card)

    var rec := Style.panel(Style.PANEL, 14, 16)
    rec.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var rbox := Style.vbox(2)
    rec.add_child(rbox)
    rbox.add_child(Style.label(tr("REKORD OCH SEGMENT"), 13, Style.TEXT_DIM, 800))
    var lines: Array[String] = []
    if r.has("plan"):
        var plan: Dictionary = app.find_plan(r["plan"][0])
        if not plan.is_empty():
            lines.append(tr("★ %s: pass %d av %d klart") % [tr(plan["name"]), r["plan"][1], plan["sessions"].size()])
    if not r["ftp"].is_empty():
        lines.append(tr("★ FTP höjd: %d → %d W (95 %% av bästa 20 min)") % [r["ftp"][0], r["ftp"][1]])
    for b in r["bests"]:
        var was := "" if float(b["old"]) <= 0.0 else tr(" (förut %d W)") % roundi(b["old"])
        lines.append(tr("★ Personbästa %s: %d W%s") % [PowerCurve.label(b["duration"]), roundi(b["watts"]), was])
    for lap in r["laps"]:
        var name: String = tr(Progress.WORLD_NAMES.get(lap["world"], lap["world"]))
        var lap_line := tr("Varv i %s: %s") % [name, Style.clock(lap["time"])]
        if lap["pr"] and float(lap["old"]) > 0.0:
            lap_line = "★ " + lap_line + tr(" (slog spöket med %s s)") % Style.dec(float(lap["old"]) - float(lap["time"]))
        lines.append(lap_line)
    for seg in r["segments"]:
        var t := _seg_time(seg["time"])
        if seg["pr"] and float(seg["old"]) > 0.0:
            lines.append(tr("★ %s: %s (rekord, %s s snabbare)") % [tr(seg["name"]), t, Style.dec(float(seg["old"]) - float(seg["time"]))])
        elif seg["pr"]:
            lines.append(tr("%s: %s (första tiden)") % [tr(seg["name"]), t])
        elif float(seg["old"]) <= 0.0:
            lines.append("%s: %s" % [tr(seg["name"]), t])
        else:
            lines.append(tr("%s: %s (rekord %s)") % [tr(seg["name"]), t, _seg_time(seg["old"])])
    if lines.is_empty():
        lines.append(tr("Inga segment eller rekord den här gången."))
    var shown := lines.slice(0, 6)
    for line in shown:
        rbox.add_child(Style.label(line, 16, Color("ffd34d") if line.begins_with("★") else Style.TEXT, 700))
    if lines.size() > shown.size():
        rbox.add_child(Style.label(tr("… och %d till i garaget.") % (lines.size() - shown.size()), 14, Style.TEXT_DIM, 600))
    row.add_child(rec)
    return row


static func _seg_time(seconds: float) -> String:
    return "%s s" % Style.dec(seconds) if seconds < 60.0 else Style.clock(seconds)
