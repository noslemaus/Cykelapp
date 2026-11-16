extends Control
## Pick the world you ride in. It is remembered, and both free rides and workouts happen there.
## The pictures are the real worlds rendered as floating dioramas (`--worldthumb`).

const Style = preload("res://ui/style.gd")
const Atmosphere = preload("res://world/atmosphere.gd")

var app
var args := {}


func _ready() -> void:
    var root := Style.vbox(22)
    add_child(Style.margin(root, 36))
    root.add_child(Style.header(tr("Välj värld"), tr("Meny"), func(): app.go("menu")))
    var intro := Style.label(tr("Du cyklar i den värld du väljer, både fri cykling och träningspass. ")
        + tr("I ERG styr passet motståndet; i SIM känns backarna."), 18, Style.TEXT_DIM, 600)
    intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    root.add_child(intro)
    root.add_child(_atmosphere_bar())
    var row := Style.hbox(26)
    row.size_flags_vertical = Control.SIZE_EXPAND_FILL
    root.add_child(row)
    for id in app.WORLDS:
        row.add_child(_world_card(id, app.WORLDS[id]))
    row.add_child(_gym_card())


func _choose(id: String) -> void:
    Settings.world = id
    Settings.save()
    app.go("menu")


func _world_card(id: String, info: Dictionary) -> Control:
    var card := Style.panel(Style.CARD, 22, 0)
    card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    card.size_flags_vertical = Control.SIZE_EXPAND_FILL
    card.size_flags_stretch_ratio = 2.0
    var box := Style.vbox(0)
    card.add_child(box)
    box.add_child(Style.world_picture(info["thumb"], 380.0))
    var text := Style.vbox(6)
    var head := Style.hbox(12)
    head.add_child(Style.label(info["name"], 30, Style.TEXT_DARK, 900))
    if Settings.world == id:
        head.add_child(Style.label(tr("✓ vald"), 18, Style.ACCENT, 800))
    text.add_child(head)
    var facts := Style.label(info.get("facts", ""), 16, Style.TEXT_DARK_DIM, 700)
    facts.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART     # so three worlds and the gym fit in a row
    text.add_child(facts)
    var desc := Style.label(info["text"], 16, Style.TEXT_DARK_DIM, 500)
    desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    text.add_child(desc)
    var wrap := Style.margin(text, 22)
    wrap.set_anchors_preset(Control.PRESET_TOP_LEFT)
    box.add_child(wrap)
    Style.clickable(card, _choose.bind(id))
    return card


func _gym_card() -> Control:
    var card := Style.panel(Style.PANEL, 22, 30)
    card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    card.size_flags_vertical = Control.SIZE_EXPAND_FILL
    var box := Style.vbox(12)
    card.add_child(box)
    box.add_child(Style.spacer())
    var head := Style.hbox(12)
    head.add_child(Style.label(tr("Gymskärm"), 32, Style.TEXT, 900))
    if Settings.world == "":
        head.add_child(Style.label(tr("✓ vald"), 18, Style.ACCENT, 800))
    box.add_child(head)
    var desc := Style.label(tr("Ingen värld, bara siffror och grafer. Lättast för datorn."), 18, Style.TEXT_DIM, 500)
    desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    box.add_child(desc)
    Style.clickable(card, _choose.bind(""))
    return card


## Time of day, weather and season for every world (T, V and Å change them while riding).
func _atmosphere_bar() -> Control:
    var bar := Style.panel(Style.PANEL, 16, 14)
    var row := Style.hbox(36)
    bar.add_child(row)
    row.add_child(_choice_group(tr("TID PÅ DYGNET"), Atmosphere.TIMES, Atmosphere.TIME_NAMES, "time_of_day"))
    var weather_names := Atmosphere.WEATHER_NAMES.duplicate()
    weather_names["regn"] = tr("Regn/snö")
    row.add_child(_choice_group(tr("VÄDER"), Atmosphere.WEATHERS, weather_names, "weather"))
    row.add_child(_choice_group(tr("ÅRSTID"), Atmosphere.SEASONS, Atmosphere.SEASON_NAMES, "season"))
    return bar


func _choice_group(title: String, ids: Array, names: Dictionary, setting: String) -> Control:
    var box := Style.vbox(6)
    box.add_child(Style.label(title, 12, Style.TEXT_DIM, 800))
    var buttons := Style.hbox(6)
    var all: Array[Button] = []
    for id in ids:
        var b := Style.button(names[id], "secondary", 16)
        b.custom_minimum_size = Vector2(0, 40)
        all.append(b)
        buttons.add_child(b)
    for i in ids.size():
        var id: String = ids[i]
        all[i].pressed.connect(func():
            Settings.set(setting, id)
            Settings.save()
            for k in ids.size():
                Style.set_selected(all[k], ids[k] == id))
        Style.set_selected(all[i], Settings.get(setting) == id)
    box.add_child(buttons)
    return box
