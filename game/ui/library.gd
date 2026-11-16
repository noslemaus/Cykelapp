extends Control
## Workout library: collections by length and by type, and a card grid of workouts.
## args: {"view": "collections" | "all" | "group", "group": key, "title": text}

const Style = preload("res://ui/style.gd")
const Workout = preload("res://core/workout.gd")
const WorkoutGraph = preload("res://ui/workout_graph.gd")

const LENGTH_GROUPS := [
    ["30", "30", "Upp till 30 minuter", "3d8fd6"],
    ["30-60", "30–60", "30–60 minuter", "45bf5c"],
    ["60-90", "60–90", "60–90 minuter", "f07b32"],
    ["90+", "90+", "Över 90 minuter", "e0412e"],
]
const TYPE_COLORS := {
    "recovery": "7d8394", "endurance": "2f79c2", "sweetspot": "38a852",
    "threshold": "d9a821", "vo2max": "e86a26", "ftptest": "4a4f5c", "climbing": "3cb371", "sprint": "d23a2a",
}

var app
var args := {}


func _ready() -> void:
    var root := Style.vbox(24)
    add_child(Style.margin(root, 36))
    root.add_child(Style.header(tr("Träningspass"), tr("Meny"), func(): app.go("menu")))

    var body := Style.hbox(32)
    body.size_flags_vertical = Control.SIZE_EXPAND_FILL
    root.add_child(body)

    var view: String = args.get("view", "collections")
    var nav := Style.vbox(8)
    nav.custom_minimum_size.x = 220
    for item in [[tr("Samlingar"), "collections"], [tr("Planer"), "plans"], [tr("Egna pass"), "custom"], [tr("Alla pass"), "all"]]:
        var b := Style.button(item[0], "ghost", 22)
        b.alignment = HORIZONTAL_ALIGNMENT_LEFT
        Style.set_selected(b, view == item[1] or (view == "group" and item[1] == "collections"))
        var target: String = item[1]
        b.pressed.connect(func(): app.go("library", {"view": target}))
        nav.add_child(b)
    body.add_child(nav)

    var scroll := ScrollContainer.new()
    scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    body.add_child(scroll)
    var content := Style.vbox(22)
    content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.add_child(content)

    match view:
        "collections":
            _collections(content)
        "group":
            _workouts(content, args.get("title", ""), _filter(args.get("group", "")))
        "custom":
            content.add_child(_custom_bar())
            _workouts(content, tr("Egna pass"), app.workouts.filter(func(w): return w.custom))
        "plans":
            _plans(content)
        _:
            _workouts(content, tr("Alla pass"), app.workouts)


## Egna pass: make a new one, or import Zwift workouts (.zwo) from a file or by dropping them here.
func _custom_bar() -> Control:
    var box := Style.vbox(8)
    var row := Style.hbox(12)
    var make := Style.button(tr("+ Nytt pass"), "primary", 18)
    make.pressed.connect(func(): app.go("workout_editor", {"data": {"name": tr("Mitt pass")}, "id": ""}))
    row.add_child(make)
    var load := Style.button(tr("Importera .zwo"), "secondary", 18)
    load.pressed.connect(_pick_zwo)
    row.add_child(load)
    var hint := Style.label(tr("Zwift-pass (.zwo) går också att dra in i fönstret."), 16, Style.TEXT_DIM, 600)
    hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(hint)
    box.add_child(row)
    if str(args.get("message", "")) != "":
        var msg := Style.label(str(args["message"]), 17, Style.ACCENT, 700)
        msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        box.add_child(msg)
    return box


func _pick_zwo() -> void:
    var dialog := FileDialog.new()
    dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILES
    dialog.access = FileDialog.ACCESS_FILESYSTEM
    dialog.filters = PackedStringArray(["*.zwo ; Zwift-pass"])
    dialog.current_dir = OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)
    dialog.use_native_dialog = true
    dialog.files_selected.connect(func(paths): app._on_files_dropped(paths))
    add_child(dialog)
    dialog.popup_centered(Vector2i(900, 600))


func _filter(group: String) -> Array:
    var list := []
    for w in app.workouts:
        if not w.custom and (w.length_group() == group or w.category == group):
            list.append(w)
    return list


func _collections(content: VBoxContainer) -> void:
    content.add_child(Style.label(tr("Efter tid"), 24, Style.TEXT_DIM, 700))
    var by_length := _grid()
    for g in LENGTH_GROUPS:
        by_length.add_child(_collection_card(g[1], g[2], Color(g[3]), g[0], _filter(g[0]).size()))
    content.add_child(by_length)
    content.add_child(Style.label(tr("Efter typ"), 24, Style.TEXT_DIM, 700))
    var by_type := _grid()
    for key in TYPE_COLORS:
        var count := _filter(key).size()
        if count > 0:
            by_type.add_child(_collection_card(Workout.CATEGORY_NAMES[key], "", Color(TYPE_COLORS[key]), key, count))
    content.add_child(by_type)


func _grid() -> GridContainer:
    var grid := GridContainer.new()
    grid.columns = 4
    grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    grid.add_theme_constant_override("h_separation", 22)
    grid.add_theme_constant_override("v_separation", 22)
    return grid


func _collection_card(big: String, caption: String, color: Color, group: String, count: int) -> Control:
    var card := Style.panel(Style.CARD, 18, 0)
    card.custom_minimum_size = Vector2(290, 230)
    var box := Style.vbox(0)
    card.add_child(box)
    var top := Style.panel(color, 18, 18)
    top.custom_minimum_size.y = 150
    var big_label := Style.label(big, 46 if big.length() <= 6 else 30, Style.TEXT, 900)
    big_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    big_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    big_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    top.add_child(big_label)
    box.add_child(top)
    var bottom := Style.margin(Style.vbox(2), 16)
    bottom.set_anchors_preset(Control.PRESET_TOP_LEFT)
    var text := bottom.get_child(0) as VBoxContainer
    text.add_child(Style.label(caption if caption != "" else big, 20, Style.TEXT_DARK, 800))
    text.add_child(Style.label(tr("%d pass") % count if count != 1 else tr("1 pass"), 17, Style.TEXT_DARK_DIM, 600))
    box.add_child(bottom)
    var title := caption if caption != "" else big
    Style.clickable(card, func(): app.go("library", {"view": "group", "group": group, "title": title}))
    return card


func _workouts(content: VBoxContainer, title: String, list: Array) -> void:
    var row := Style.hbox(16)
    if args.get("view") == "group":
        var back := Style.button(tr("‹  Samlingar"), "secondary", 18)
        back.pressed.connect(func(): app.go("library"))
        row.add_child(back)
    row.add_child(Style.label(title, 28, Style.TEXT, 800))
    content.add_child(row)
    if list.is_empty():
        content.add_child(Style.label(tr("Inga pass här ännu."), 20, Style.TEXT_DIM, 500))
        return
    var grid := _grid()
    for w in list:
        grid.add_child(_workout_card(w))
    content.add_child(grid)


func _workout_card(w) -> Control:
    var card := Style.panel(Style.CARD, 18, 0)
    card.custom_minimum_size = Vector2(290, 236)
    card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var box := Style.vbox(0)
    card.add_child(box)
    var graph := WorkoutGraph.new()
    graph.workout = w
    graph.ftp = Settings.ftp
    graph.custom_minimum_size.y = 120
    box.add_child(graph)
    var info := Style.margin(Style.vbox(8), 16)
    info.set_anchors_preset(Control.PRESET_TOP_LEFT)
    var text := info.get_child(0) as VBoxContainer
    var title := Style.label(w.name, 22, Style.TEXT_DARK, 800)
    title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS   # long names must not widen the column
    title.custom_minimum_size.x = 10
    title.tooltip_text = tr(w.name)
    text.add_child(title)
    var facts := Style.hbox(28)
    facts.add_child(_fact(Style.minutes(w.duration), tr("Längd")))
    facts.add_child(_fact("%s/5" % Style.dec(w.stats()["effort"]).replace(",0", ""), tr("Ansträngning")))
    var rec := Progress.workout_record(w.id)
    if rec["count"] > 0:
        facts.add_child(_fact(("✓ " if rec["completed"] else "") + "%d×" % rec["count"], tr("Kört")))
    text.add_child(facts)
    box.add_child(info)
    Style.clickable(card, func(): app.go("detail", {"workout": w}))
    return card


func _fact(value: String, caption: String) -> Control:
    var v := Style.vbox(0)
    v.add_child(Style.label(value, 19, Style.TEXT_DARK, 700))
    v.add_child(Style.label(caption, 15, Style.TEXT_DARK_DIM, 600))
    return v


## Training plans: a series of sessions towards a goal, with how far you have come.
func _plans(content: VBoxContainer) -> void:
    content.add_child(Style.label(tr("Planer"), 30, Style.TEXT, 800))
    var intro := Style.label(tr("Serier av pass i en bestämd ordning, mot ett mål. Kör ett pass i taget; planen kommer ihåg var du är."),
        17, Style.TEXT_DIM, 600)
    intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    content.add_child(intro)
    var grid := _grid()
    grid.columns = 3
    for plan in app.plans:
        grid.add_child(_plan_card(plan))
    content.add_child(grid)


func _plan_card(plan: Dictionary) -> Control:
    var card := Style.panel(Color(plan["color"]), 18, 18)
    card.custom_minimum_size = Vector2(300, 190)
    card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var box := Style.vbox(6)
    card.add_child(box)
    var title := Style.label(tr(plan["name"]), 26, Style.TEXT, 900)
    title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    title.custom_minimum_size.x = 10
    box.add_child(title)
    var goal := Style.label(tr(plan["goal"]), 15, Color(1, 1, 1, 0.88), 600)
    goal.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    goal.size_flags_vertical = Control.SIZE_EXPAND_FILL
    box.add_child(goal)
    var done: int = Progress.plan_done(plan["id"]).size()
    var count: int = plan["sessions"].size()
    var line := tr("%d pass") % count if done == 0 else tr("%d av %d pass klara") % [done, count]
    box.add_child(Style.label(line, 16, Style.TEXT, 800))
    Style.clickable(card, func(): app.go("plan", {"plan": plan}))
    return card
