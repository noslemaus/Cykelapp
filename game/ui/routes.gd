extends Control
## Choose a route in the chosen world: each with its length,
## climbing, the segments on it and how it has gone for you. The choice is remembered per world and
## both free rides and workouts start where the route starts.

const Style = preload("res://ui/style.gd")
const Routes = preload("res://core/routes.gd")

var app
var args := {}


func _ready() -> void:
    var world_id := Settings.world
    var root := Style.vbox(20)
    add_child(Style.margin(root, 36))
    var world_name: String = tr(app.WORLDS[world_id]["name"]) if app.WORLDS.has(world_id) else ""
    root.add_child(Style.header(tr("Välj rutt i %s") % world_name, tr("Meny"), func(): app.go("menu")))
    var intro := Style.label(tr("Rutterna går på världens väg med olika start, längd och backar. ")
        + tr("Både fri cykling och träningspass börjar där rutten börjar. Kör den till slut för XP och en tid att slå."),
        18, Style.TEXT_DIM, 600)
    intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    root.add_child(intro)
    var scroll := ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    var list := Style.vbox(12)
    list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.add_child(list)
    root.add_child(scroll)
    var current := Routes.chosen(world_id, Settings.routes)
    for route in Routes.for_world(world_id):
        list.add_child(_card(world_id, route, route["id"] == current.get("id", "")))


func _card(world_id: String, route: Dictionary, chosen: bool) -> Control:
    var card := PanelContainer.new()
    var style := Style.flat(Style.PANEL, 16, 18)
    if chosen:
        style.set_border_width_all(3)
        style.border_color = Style.ACCENT
    card.add_theme_stylebox_override("panel", style)
    var row := Style.hbox(24)
    card.add_child(row)
    var text := Style.vbox(4)
    text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var head := Style.hbox(10)
    head.add_child(Style.label(tr(route["name"]), 26, Style.TEXT, 900))
    if chosen:
        head.add_child(Style.label(tr("✓ vald"), 16, Style.ACCENT, 800))
    var record := Progress.route_record(world_id, route["id"])
    if not record.is_empty():
        head.add_child(Style.label(tr("klarad %d×, bästa %s") % [int(record["count"]), Style.clock(float(record["best"]))],
            15, Color("ffd34d"), 800))
    text.add_child(head)
    var about := Style.label(tr(route["text"]), 16, Style.TEXT_DIM, 600)
    about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    text.add_child(about)
    var facts := Routes.facts(world_id, route["id"])
    if not facts.is_empty() and not facts["segments"].is_empty():
        var segs := Style.label(tr("Segment: %s") % ", ".join(facts["segments"].map(func(n): return tr(n))), 14, Style.TEXT_DIM, 700)
        segs.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        text.add_child(segs)
    row.add_child(text)
    for f in [[Style.dec(float(facts.get("km", 0.0)), 1) if not facts.is_empty() else "–", "km"],
            ["%d" % int(facts.get("hm", 0)) if not facts.is_empty() else "–", tr("höjdmeter")],
            ["%d" % Routes.xp_for(float(facts.get("km", 0.0)) * 1000.0), "XP"]]:
        var v := Style.vbox(-2)
        v.custom_minimum_size.x = 110
        v.add_child(Style.label(f[0], 30, Style.TEXT, 900))
        v.add_child(Style.label(f[1], 14, Style.TEXT_DIM, 700))
        row.add_child(v)
    Style.clickable(card, func():
        Settings.routes[world_id] = route["id"]
        Settings.save()
        app.go("menu"))
    return card
