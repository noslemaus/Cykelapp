extends Control
## One training plan: its goal, how far you have come, the next session and every session in order.
## args: {"plan": Dictionary from PlanLibrary}

const Style = preload("res://ui/style.gd")
const Workout = preload("res://core/workout.gd")
const WorkoutGraph = preload("res://ui/workout_graph.gd")
const PlanLibrary = preload("res://core/plan_library.gd")
const TYPE_COLORS := {
    "recovery": "7d8394", "endurance": "2f79c2", "sweetspot": "38a852", "threshold": "d9a821",
    "vo2max": "e86a26", "ftptest": "4a4f5c", "climbing": "3cb371", "sprint": "d23a2a",
}

var app
var args := {}


func _ready() -> void:
    var plan: Dictionary = args["plan"]
    var sessions: Array = plan["sessions"]
    var done: Array = Progress.plan_done(plan["id"])
    var root := Style.vbox(18)
    add_child(Style.margin(root, 36))
    root.add_child(Style.header(tr(plan["name"]), tr("Planer"), func(): app.go("library", {"view": "plans"})))

    var top := Style.hbox(24)
    var info := Style.vbox(8)
    info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var goal := Style.label(tr(plan["goal"]), 20, Style.TEXT_DIM, 600)
    goal.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    info.add_child(goal)
    info.add_child(Style.label(tr("%d pass  ·  %s totalt") % [sessions.size(), Style.minutes(PlanLibrary.total_seconds(plan))],
        17, Style.TEXT_DIM, 700))
    var bar := ProgressBar.new()
    bar.show_percentage = false
    bar.max_value = sessions.size()
    bar.value = done.size()
    bar.custom_minimum_size = Vector2(0, 12)
    bar.add_theme_stylebox_override("background", Style.flat(Color(0, 0, 0, 0.35), 6))
    bar.add_theme_stylebox_override("fill", Style.flat(Color(plan["color"]).lightened(0.15), 6))
    info.add_child(bar)
    info.add_child(Style.label(tr("%d av %d pass klara") % [done.size(), sessions.size()], 17, Style.TEXT, 800))
    top.add_child(info)
    var next := _next_index(sessions, done)
    var start := Style.button(tr("Kör nästa pass") if next >= 0 else tr("Planen är klar!"), "primary", 24)
    start.custom_minimum_size = Vector2(300, 70)
    start.disabled = next < 0
    if next >= 0:
        start.pressed.connect(func(): app.go("detail", {"workout": sessions[next]}))
    top.add_child(start)
    root.add_child(top)

    var scroll := ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    var list := Style.vbox(10)
    list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.add_child(list)
    root.add_child(scroll)
    for i in sessions.size():
        list.add_child(_row(sessions[i], i, i in done, i == next))


func _next_index(sessions: Array, done: Array) -> int:
    for i in sessions.size():
        if not i in done:
            return i
    return -1


func _row(w, i: int, is_done: bool, is_next: bool) -> Control:
    var card := PanelContainer.new()
    var box := Style.flat(Style.PANEL if not is_done else Color(Style.PANEL, 0.6), 14, 12)
    if is_next:
        box.border_color = Style.ACCENT
        box.set_border_width_all(3)
    card.add_theme_stylebox_override("panel", box)
    var row := Style.hbox(18)
    card.add_child(row)
    var num := Style.label("✓" if is_done else str(i + 1), 26, Style.ACCENT if is_done else Style.TEXT, 900)
    num.custom_minimum_size.x = 44
    num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    num.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    row.add_child(num)
    var chip := ColorRect.new()
    chip.color = Color(TYPE_COLORS.get(w.category, "5c6475"))
    chip.custom_minimum_size = Vector2(8, 52)
    row.add_child(chip)
    var text := Style.vbox(2)
    text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    text.add_child(Style.label("%s  ·  %s" % [tr(w.name), Style.minutes(w.duration)], 19, Style.TEXT, 800))
    var desc := Style.label(tr(w.description), 15, Style.TEXT_DIM, 600)
    desc.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    desc.custom_minimum_size.x = 10
    text.add_child(desc)
    row.add_child(text)
    var graph := WorkoutGraph.new()
    graph.workout = w
    graph.ftp = Settings.ftp
    graph.custom_minimum_size = Vector2(320, 56)
    row.add_child(graph)
    Style.clickable(card, func(): app.go("detail", {"workout": w}))
    return card
