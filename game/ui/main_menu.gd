extends Control
## Start screen: every world as a miniature to pick from (the chosen one outlined), then free ride,
## workouts, the garage and settings. The window scales the whole screen (stretch mode canvas_items
## from 1600 × 900), so a small window shows the same layout, smaller.

const Style = preload("res://ui/style.gd")
const Routes = preload("res://core/routes.gd")
const History = preload("res://ui/history.gd")

var app
var args := {}
var _status: Label


func _ready() -> void:
    var root := Style.vbox(24)
    add_child(Style.margin(root, 40))

    var head := Style.hbox(20)
    var title := Style.vbox(2)
    title.add_child(Style.label(tr("Cykelapp"), 48, Style.TEXT, 900))
    title.add_child(Style.label(tr("Arbetsnamn"), 17, Style.TEXT_DIM, 600))
    head.add_child(title)
    head.add_child(Style.spacer())
    head.add_child(_progress_strip())
    root.add_child(head)

    var body := Style.hbox(24)
    body.size_flags_vertical = Control.SIZE_EXPAND_FILL
    root.add_child(body)
    body.add_child(_worlds_panel())
    var choices := Style.vbox(18)
    choices.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    choices.add_child(_choice(tr("Fri cykling"), tr("Cykla fritt i din värld. Håll en watt eller känn backarna."),
        Color("3d8fd6"), func(): app.start_free_ride()))
    choices.add_child(_choice(tr("Träningspass"), tr("Välj ett pass. Det körs i din värld, i ERG eller SIM."),
        Color("14b8a6"), func(): app.go("library")))
    choices.add_child(_choice(tr("Garaget"), tr("Nivå %d. Cyklar, tröjor, stridsvagnen och dina rekord.") % Progress.level(),
        Color("c27c1a"), func(): app.go("garage")))
    choices.add_child(_choice(tr("Inställningar"), tr("FTP, vikt, trainer, backkänsla, skärmen och Strava."),
        Color("5c6475"), func(): app.go("settings")))
    body.add_child(choices)

    var footer := Style.panel(Style.PANEL, 14, 14)
    _status = Style.label("", 17, Style.TEXT_DIM, 600)
    _status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    footer.add_child(_status)
    root.add_child(footer)


## Every world side by side as a miniature, plus the gym screen; click one to ride there.
func _worlds_panel() -> Control:
    var panel := Style.vbox(12)
    panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    panel.size_flags_stretch_ratio = 1.6
    panel.add_child(Style.label(tr("VÄRLDAR"), 15, Style.TEXT_DIM, 800))
    var grid := GridContainer.new()
    var count: int = app.WORLDS.size() + 1
    grid.columns = 2 if count <= 4 else 3
    grid.add_theme_constant_override("h_separation", 18)
    grid.add_theme_constant_override("v_separation", 18)
    grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
    panel.add_child(grid)
    for id in app.WORLDS:
        grid.add_child(_mini_card(id, app.WORLDS[id]))
    grid.add_child(_mini_card("", {}))
    if app.WORLDS.has(Settings.world):
        panel.add_child(_route_strip())
    return panel


## The route you ride in the chosen world (core/routes.gd), with its length and climbing.
func _route_strip() -> Control:
    var route := Routes.chosen(Settings.world, Settings.routes)
    var facts := Routes.facts(Settings.world, route.get("id", ""))
    var strip := Style.panel(Style.PANEL, 14, 12)
    var row := Style.hbox(14)
    strip.add_child(row)
    row.add_child(Style.label(tr("RUTT"), 13, Style.TEXT_DIM, 800))
    var line := tr(route.get("name", ""))
    if not facts.is_empty():
        line += "  ·  %s km  ·  %d hm" % [Style.dec(float(facts["km"]), 1), int(facts["hm"])]
    var name := Style.label(line, 18, Style.TEXT, 800)
    name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(name)
    var change := Style.button(tr("Byt rutt"), "secondary", 16)
    change.pressed.connect(func(): app.go("routes"))
    row.add_child(change)
    return strip


## One world's miniature: its picture, name and length; the chosen world gets an accent outline
## and "✓ vald". An empty `info` is the gym screen (no world).
func _mini_card(id: String, info: Dictionary) -> Control:
    var chosen: bool = Settings.world == id
    var gym := info.is_empty()
    var card := PanelContainer.new()
    var style := Style.flat(Style.PANEL_LIGHT if gym else Style.CARD, 16, 4)     # the inset keeps the
    if chosen:                                                                     # outline clear of the picture
        style.set_border_width_all(4)
        style.border_color = Style.ACCENT
    card.add_theme_stylebox_override("panel", style)
    card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    card.size_flags_vertical = Control.SIZE_EXPAND_FILL
    var box := Style.vbox(0)
    card.add_child(box)
    if gym:
        var empty := Control.new()
        empty.custom_minimum_size.y = 110.0
        empty.size_flags_vertical = Control.SIZE_EXPAND_FILL
        var center := CenterContainer.new()
        center.set_anchors_preset(Control.PRESET_FULL_RECT)
        center.add_child(Style.label("▮▮▮", 40, Style.TEXT_DIM, 900))
        empty.add_child(center)
        box.add_child(empty)
    else:
        box.add_child(Style.world_picture(info["thumb"], 110.0))
    var text := Style.vbox(0)
    var head := Style.hbox(8)
    var name_colour := Style.TEXT if gym else Style.TEXT_DARK
    head.add_child(Style.label(info.get("name", tr("Gymskärm")), 22, name_colour, 900))
    if chosen:
        head.add_child(Style.label(tr("✓ vald"), 15, Style.ACCENT, 800))
    text.add_child(head)
    var facts := tr("Ingen värld, bara siffror och grafer") if gym else "  ·  ".join(tr(info.get("facts", "")).split("  ·  ").slice(0, 2))
    var line := Style.label(facts, 14, Style.TEXT_DIM if gym else Style.TEXT_DARK_DIM, 700)
    line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    text.add_child(line)
    box.add_child(Style.margin(text, 14))
    Style.clickable(card, _choose_world.bind(id))
    return card


func _choose_world(id: String) -> void:
    Settings.world = id
    Settings.save()
    app.go("menu")


func _choice(heading: String, text: String, color: Color, on_click: Callable) -> Control:
    var card := Style.panel(color, 20, 26)
    card.size_flags_vertical = Control.SIZE_EXPAND_FILL
    var box := Style.vbox(6)
    box.add_child(Style.spacer())
    box.add_child(Style.label(heading, 34, Style.TEXT, 900))
    var t := Style.label(text, 18, Color(1, 1, 1, 0.88), 600)
    t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    box.add_child(t)
    card.add_child(box)
    Style.clickable(card, on_click)
    return card


func _process(_delta: float) -> void:
    _status.text = tr("Trainer: %s     FTP %d W     Vikt %s kg") % [
        Ride.source_description(), Settings.ftp, Style.dec(Settings.weight_kg)]
    if Ride.sim:
        # Rides on the pretend trainer are kept in the history but give no XP, records or plan progress.
        _status.text += "\n" + tr("Låtsastrainern är på: turerna syns i historiken men ger ingen XP. Välj din trainer i Inställningar → Hårdvara.")


## Where you are: level and XP, this week, the plan you are in the middle of, and the history.
func _progress_strip() -> Control:
    var strip := Style.hbox(12)
    var level := Style.panel(Style.PANEL, 14, 12)
    var lbox := Style.vbox(4)
    level.add_child(lbox)
    var p := Progress.level_progress()
    lbox.add_child(Style.label(tr("Nivå %d") % Progress.level() + "   " + tr("%d XP totalt") % Progress.xp(), 18, Color("ffd34d"), 900))
    var bar := ProgressBar.new()
    bar.show_percentage = false
    bar.max_value = p.y
    bar.value = p.x
    bar.custom_minimum_size = Vector2(230, 8)
    bar.add_theme_stylebox_override("background", Style.flat(Color(0, 0, 0, 0.35), 4))
    bar.add_theme_stylebox_override("fill", Style.flat(Color("ffd34d"), 4))
    lbox.add_child(bar)
    var week := Progress.week_totals(0)
    lbox.add_child(Style.label(tr("Den här veckan: %s  ·  %s") % [Style.minutes(week["seconds"]) if week["seconds"] > 0 else "0 min", History.rides_text(week["rides"])],
        14, Style.TEXT_DIM, 700))
    strip.add_child(level)
    var plan_id := Progress.active_plan_id(app.plans)
    if plan_id != "":
        var plan: Dictionary = app.find_plan(plan_id)
        var done: int = Progress.plan_done(plan_id).size()
        var b := Style.button(tr("Fortsätt %s (%d/%d)") % [tr(plan["name"]), done, plan["sessions"].size()], "primary", 17)
        b.custom_minimum_size.y = 64
        b.pressed.connect(func(): app.go("plan", {"plan": plan}))
        strip.add_child(b)
    var hist := Style.button(tr("Historik"), "secondary", 17)
    hist.custom_minimum_size = Vector2(130, 64)
    hist.pressed.connect(func(): app.go("history"))
    strip.add_child(hist)
    return strip
