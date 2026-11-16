extends Control
## One workout: facts, description, ERG/SIM choice, a large graph in watts and time in zone.
## args: {"workout": Workout}

const Style = preload("res://ui/style.gd")
const Zones = preload("res://core/zones.gd")
const WorkoutGraph = preload("res://ui/workout_graph.gd")
const CustomWorkouts = preload("res://core/custom_workouts.gd")

var app
var args := {}
var _use_erg := true
var _erg_button: Button
var _sim_button: Button
var _mode_text: Label


func _ready() -> void:
    var w = args["workout"]
    var stats: Dictionary = w.stats()
    var root := Style.vbox(22)
    add_child(Style.margin(root, 36))
    var plan: Dictionary = app.find_plan(w.plan_id) if w.plan_id != "" else {}
    if plan.is_empty():
        root.add_child(Style.header(tr(w.name), tr("Pass"), func(): app.go("library")))
    else:
        root.add_child(Style.header(tr(w.name), tr(plan["name"]), func(): app.go("plan", {"plan": plan})))
        root.add_child(Style.label(tr("Pass %d av %d i planen %s.") % [w.plan_index + 1, plan["sessions"].size(), tr(plan["name"])],
            18, Style.ACCENT, 800))

    var facts := Style.hbox(36)
    facts.add_child(_fact(Style.minutes(w.duration), tr("längd")))
    facts.add_child(_fact("%s/5" % Style.dec(stats["effort"]).replace(",0", ""), tr("ansträngning")))
    facts.add_child(_fact("%d" % roundi(stats["tss"]), "TSS"))
    facts.add_child(_fact(Style.dec(stats["intensity_factor"], 2), "IF"))
    root.add_child(facts)
    var desc := Style.label(w.description, 21, Style.TEXT_DIM, 500)
    desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    root.add_child(desc)

    var actions := Style.hbox(14)
    var start := Style.button(tr("Starta passet"), "primary", 26)
    start.custom_minimum_size = Vector2(260, 64)
    start.pressed.connect(func(): app.start_workout(w, _use_erg))
    actions.add_child(start)
    _erg_button = Style.button("ERG", "secondary", 20)
    _sim_button = Style.button("SIM", "secondary", 20)
    _erg_button.custom_minimum_size = Vector2(110, 64)
    _sim_button.custom_minimum_size = Vector2(110, 64)
    _erg_button.pressed.connect(func(): _set_mode(true))
    _sim_button.pressed.connect(func(): _set_mode(false))
    actions.add_child(_erg_button)
    actions.add_child(_sim_button)
    _mode_text = Style.label("", 18, Style.TEXT_DIM, 500)
    _mode_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _mode_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    actions.add_child(_mode_text)
    root.add_child(actions)
    var where: String = tr(app.WORLDS[Settings.world]["name"]) if app.WORLDS.has(Settings.world) else tr("gymskärmen")
    var info := Style.hbox(14)
    var where_label := Style.label(tr("Passet körs i %s. Byt värld på startsidan.") % where, 17, Style.TEXT_DIM, 600)
    where_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    info.add_child(where_label)
    # Your own copy to change, or change one of your own.
    var own := CustomWorkouts.is_own(w.id)
    var edit := Style.button(tr("Ändra passet") if own else tr("Kopiera och ändra"), "secondary", 17)
    edit.pressed.connect(func():
        var data: Dictionary = w.raw.duplicate(true)
        if not own:
            data["name"] = tr("%s (kopia)") % tr(w.name)
            data["description"] = tr(w.description)
        app.go("workout_editor", {"data": data, "id": w.id if own else ""}))
    info.add_child(edit)
    root.add_child(info)
    _set_mode(true)

    var graph_panel := Style.panel(Style.CARD, 18, 22)
    graph_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
    var graph_box := Style.vbox(16)
    graph_panel.add_child(graph_box)
    var graph := WorkoutGraph.new()
    graph.workout = w
    graph.ftp = Settings.ftp
    graph.detailed = true
    graph.background = Color("e6e8ec")
    graph.label_color = Style.TEXT_DARK
    graph.size_flags_vertical = Control.SIZE_EXPAND_FILL
    graph_box.add_child(graph)
    graph_box.add_child(_zone_row(stats["zone_seconds"], w.duration))
    root.add_child(graph_panel)


func _set_mode(erg: bool) -> void:
    _use_erg = erg
    Style.set_selected(_erg_button, erg)
    Style.set_selected(_sim_button, not erg)
    _mode_text.text = (tr("ERG: trainern håller målwatten åt dig, oavsett växel och kadens.") if erg
        else tr("SIM: du håller målwatten själv med växel och kadens. Trainern känns som vägen."))


func _fact(value: String, caption: String) -> Control:
    var v := Style.vbox(0)
    v.add_child(Style.label(value, 30, Style.TEXT, 800))
    v.add_child(Style.label(caption, 17, Style.TEXT_DIM, 600))
    return v


func _zone_row(zone_seconds: Array, duration: float) -> Control:
    var row := Style.hbox(26)
    row.alignment = BoxContainer.ALIGNMENT_CENTER
    for i in 6:
        var chip := Style.hbox(8)
        var dot := Style.panel(Zones.COLORS[i], 20, 0)
        dot.custom_minimum_size = Vector2(46, 40)
        var z := Style.label("Z%d" % (i + 1), 17, Style.TEXT, 800)
        z.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        z.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        dot.add_child(z)
        chip.add_child(dot)
        chip.add_child(Style.label("%d %%" % roundi(100.0 * zone_seconds[i] / maxf(duration, 1.0)), 20, Style.TEXT_DARK, 700))
        row.add_child(chip)
    return row
