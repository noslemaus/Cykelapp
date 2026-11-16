extends Control
## Make or change your own workout (Egna pass): a name, a description
## and the blocks in order: steady, ramp, intervals or free. Each block's time is set in minutes and
## its watts in percent of FTP; the graph and the numbers above follow every change. Saved in
## user://egna-pass (core/custom_workouts.gd).
## args: {"data": the workout JSON to start from, "id": its id when it is already your own ("" = new)}

const Style = preload("res://ui/style.gd")
const Workout = preload("res://core/workout.gd")
const WorkoutGraph = preload("res://ui/workout_graph.gd")
const CustomWorkouts = preload("res://core/custom_workouts.gd")

const KINDS := ["steady", "ramp", "intervals", "free"]
const KIND_NAMES := ["Jämnt", "Ramp", "Intervaller", "Fritt"]

var app
var args := {}
var _data := {}
var _id := ""
var _rows: VBoxContainer
var _graph: Control
var _facts: Label
var _error: Label
var _name: LineEdit
var _desc: LineEdit
var _delete_armed := false


func _ready() -> void:
    _data = (args.get("data", {}) as Dictionary).duplicate(true)
    _id = str(args.get("id", ""))
    if not _data.has("steps"):
        _data["steps"] = [{"type": "ramp", "duration": 600.0, "from": 0.45, "to": 0.7},
            {"type": "steady", "duration": 1200.0, "power": 0.75},
            {"type": "ramp", "duration": 300.0, "from": 0.6, "to": 0.4}]
    var root := Style.vbox(16)
    add_child(Style.margin(root, 32))
    root.add_child(Style.header(tr("Ändra eget pass") if _id != "" else tr("Nytt eget pass"), tr("Egna pass"),
        func(): app.go("library", {"view": "custom"})))

    var names := Style.hbox(14)
    _name = _line(str(_data.get("name", tr("Mitt pass"))), tr("Namn"))
    _name.custom_minimum_size.x = 380
    _name.text_changed.connect(func(t): _data["name"] = t)
    names.add_child(_name)
    _desc = _line(str(_data.get("description", "")), tr("Beskrivning (valfri)"))
    _desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _desc.text_changed.connect(func(t): _data["description"] = t)
    names.add_child(_desc)
    root.add_child(names)

    var top := Style.panel(Style.CARD, 16, 14)
    var tbox := Style.vbox(8)
    top.add_child(tbox)
    _graph = WorkoutGraph.new()
    _graph.ftp = Settings.ftp
    _graph.detailed = true
    _graph.background = Color("e6e8ec")
    _graph.label_color = Style.TEXT_DARK
    _graph.custom_minimum_size.y = 170
    tbox.add_child(_graph)
    _facts = Style.label("", 18, Style.TEXT_DARK, 800)
    tbox.add_child(_facts)
    root.add_child(top)

    var add := Style.hbox(10)
    add.add_child(Style.label(tr("Lägg till:"), 18, Style.TEXT_DIM, 700))
    for i in KINDS.size():
        var kind: String = KINDS[i]
        var b := Style.button("+ " + tr(KIND_NAMES[i]), "secondary", 17)
        b.pressed.connect(func(): _add(kind))
        add.add_child(b)
    root.add_child(add)

    var scroll := ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    _rows = Style.vbox(8)
    _rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.add_child(_rows)
    root.add_child(scroll)

    var actions := Style.hbox(14)
    var save := Style.button(tr("Spara passet"), "primary", 22)
    save.pressed.connect(_save)
    actions.add_child(save)
    if _id != "":
        var del := Style.button(tr("Ta bort passet"), "secondary", 18)
        del.pressed.connect(func():
            if not _delete_armed:
                _delete_armed = true
                del.text = tr("Säker? Tryck igen")
                return
            CustomWorkouts.delete(_id, app.custom_dir)
            app.reload_workouts()
            app.go("library", {"view": "custom"}))
        actions.add_child(del)
    _error = Style.label("", 17, Color("f07b32"), 700)
    _error.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    actions.add_child(_error)
    root.add_child(actions)
    _build_rows()


func _line(text: String, placeholder: String) -> LineEdit:
    var e := LineEdit.new()
    e.text = text
    e.placeholder_text = placeholder
    e.add_theme_font_size_override("font_size", 20)
    e.custom_minimum_size.y = 46
    return e


func _add(kind: String) -> void:
    var step := {}
    match kind:
        "steady":
            step = {"type": "steady", "duration": 300.0, "power": 0.75}
        "ramp":
            step = {"type": "ramp", "duration": 300.0, "from": 0.5, "to": 0.75}
        "intervals":
            step = {"type": "intervals", "repeat": 4, "on": {"duration": 60.0, "power": 1.1}, "off": {"duration": 60.0, "power": 0.5}}
        "free":
            step = {"type": "free", "duration": 300.0}
    _data["steps"].append(step)
    _build_rows()


## One row per block, rebuilt when blocks are added, removed, moved or change kind.
func _build_rows() -> void:
    for c in _rows.get_children():
        c.queue_free()
    var steps: Array = _data["steps"]
    for i in steps.size():
        _rows.add_child(_row(i, steps[i]))
    _refresh()


func _row(i: int, step: Dictionary) -> Control:
    var panel := Style.panel(Style.PANEL, 12, 10)
    var row := Style.hbox(10)
    panel.add_child(row)
    row.add_child(Style.label("%d" % (i + 1), 18, Style.TEXT_DIM, 900))
    var kind := OptionButton.new()
    for k in KIND_NAMES:
        kind.add_item(tr(k))
    kind.select(maxi(KINDS.find(str(step.get("type", "steady"))), 0))
    kind.add_theme_font_size_override("font_size", 17)
    kind.item_selected.connect(func(index):
        var keep := float(step.get("duration", 300.0))
        _data["steps"][i] = {}
        _add_kind_at(i, KINDS[index], keep))
    row.add_child(kind)
    match str(step.get("type", "steady")):
        "steady":
            row.add_child(_num(tr("min"), float(step["duration"]) / 60.0, 0.25, 180.0, 0.25, func(v): step["duration"] = v * 60.0))
            row.add_child(_num(tr("% FTP"), float(step["power"]) * 100.0, 20.0, 400.0, 1.0, func(v): step["power"] = v / 100.0))
        "ramp":
            row.add_child(_num(tr("min"), float(step["duration"]) / 60.0, 0.25, 180.0, 0.25, func(v): step["duration"] = v * 60.0))
            row.add_child(_num(tr("från %"), float(step["from"]) * 100.0, 20.0, 400.0, 1.0, func(v): step["from"] = v / 100.0))
            row.add_child(_num(tr("till %"), float(step["to"]) * 100.0, 20.0, 400.0, 1.0, func(v): step["to"] = v / 100.0))
        "intervals":
            var on: Dictionary = step["on"]
            var off: Dictionary = step["off"]
            row.add_child(_num(tr("gånger"), float(step["repeat"]), 1.0, 50.0, 1.0, func(v): step["repeat"] = int(v)))
            row.add_child(_num(tr("på, min"), float(on["duration"]) / 60.0, 0.05, 60.0, 0.05, func(v): on["duration"] = roundf(v * 60.0)))
            row.add_child(_num(tr("på, %"), float(on["power"]) * 100.0, 20.0, 400.0, 1.0, func(v): on["power"] = v / 100.0))
            row.add_child(_num(tr("vila, min"), float(off["duration"]) / 60.0, 0.05, 60.0, 0.05, func(v): off["duration"] = roundf(v * 60.0)))
            row.add_child(_num(tr("vila, %"), float(off["power"]) * 100.0, 20.0, 400.0, 1.0, func(v): off["power"] = v / 100.0))
        "free":
            row.add_child(_num(tr("min"), float(step["duration"]) / 60.0, 0.25, 180.0, 0.25, func(v): step["duration"] = v * 60.0))
            row.add_child(Style.label(tr("ingen målwatt: du styr själv"), 15, Style.TEXT_DIM, 600))
    row.add_child(Style.spacer())
    for b in [["↑", -1], ["↓", 1]]:
        var move := Style.button(b[0], "secondary", 16)
        var to: int = i + int(b[1])
        move.disabled = to < 0 or to >= _data["steps"].size()
        move.pressed.connect(func():
            var steps: Array = _data["steps"]
            var s = steps[i]
            steps[i] = steps[to]
            steps[to] = s
            _build_rows())
        row.add_child(move)
    var remove := Style.button("✕", "secondary", 16)
    remove.pressed.connect(func():
        _data["steps"].remove_at(i)
        _build_rows())
    row.add_child(remove)
    return panel


func _add_kind_at(i: int, kind: String, duration: float) -> void:
    _add(kind)
    var made: Dictionary = _data["steps"].pop_back()
    if made.has("duration"):
        made["duration"] = duration
    _data["steps"][i] = made
    _build_rows()


func _num(caption: String, value: float, low: float, high: float, step: float, on_change: Callable) -> Control:
    var box := Style.vbox(0)
    var spin := SpinBox.new()
    spin.min_value = low
    spin.max_value = high
    spin.step = step
    spin.value = value
    spin.custom_minimum_size.x = 104
    spin.get_line_edit().add_theme_font_size_override("font_size", 17)
    spin.value_changed.connect(func(v):
        on_change.call(v)
        _refresh())
    box.add_child(spin)
    box.add_child(Style.label(caption, 12, Style.TEXT_DIM, 700))
    return box


## The graph and the numbers from the blocks as they are now.
func _refresh() -> void:
    var w := Workout.new()
    var ok := w.parse(_data)
    w.set_ftp(Settings.ftp)
    _graph.workout = w if ok else null
    _graph.queue_redraw()
    if ok:
        var st: Dictionary = w.stats()
        _facts.text = tr("%s  ·  %d block  ·  TSS %d  ·  IF %s") % [Style.minutes(w.duration), w.segments.size(),
            roundi(st["tss"]), Style.dec(st["intensity_factor"], 2)]
    else:
        _facts.text = tr("Lägg till minst ett block.")


func _save() -> void:
    _data["name"] = _name.text.strip_edges()
    _data["description"] = _desc.text.strip_edges()
    if _data["name"] == "":
        _error.text = tr("Ge passet ett namn.")
        return
    var check := Workout.new()
    if not check.parse(_data):
        _error.text = tr("Lägg till minst ett block.")
        return
    var id := CustomWorkouts.save(_data, _id, app.custom_dir)
    app.reload_workouts()
    app.go("detail", {"workout": app.find_workout(id)})
