extends RefCounted
## Shared look for every screen: colours, fonts, number formatting and small widget factories.

static var BG := Color("12161d")
static var PANEL := Color("1f2530")
static var PANEL_LIGHT := Color("2b3341")
static var CARD := Color("f4f5f7")
static var TEXT := Color("f3f5f9")
static var TEXT_DIM := Color("98a2b3")
static var TEXT_DARK := Color("1b2130")
static var TEXT_DARK_DIM := Color("5d6677")
static var ACCENT := Color("14b8a6")
static var GRAPH_BG := Color("232a36")

static var _fonts := {}


static func font(weight := 600) -> Font:
    if not _fonts.has(weight):
        var f := SystemFont.new()
        f.font_names = PackedStringArray(["Avenir Next", "Helvetica Neue", "Arial"])
        f.font_weight = weight
        _fonts[weight] = f
    return _fonts[weight]


static func make_theme() -> Theme:
    var t := Theme.new()
    t.default_font = font(500)
    t.default_font_size = 20
    return t


# --- Formatting (Swedish: decimal comma) --------------------------------------------------------

static func dec(value: float, decimals := 1) -> String:
    var text := ("%." + str(decimals) + "f") % value
    return text.replace(".", ",") if TranslationServer.get_locale().begins_with("sv") else text


static func clock(seconds: float) -> String:
    var s := maxi(0, roundi(seconds))
    if s >= 3600:
        return "%d:%02d:%02d" % [s / 3600, (s / 60) % 60, s % 60]
    return "%d:%02d" % [s / 60, s % 60]


static func minutes(seconds: float) -> String:
    var m := roundi(seconds / 60.0)
    if m >= 60:
        return str(TranslationServer.translate("%d h %d min")) % [m / 60, m % 60] if m % 60 != 0 else "%d h" % (m / 60)
    return "%d min" % m


# --- Widgets -----------------------------------------------------------------------------------

static func label(text: String, size := 20, color := TEXT, weight := 600) -> Label:
    var l := Label.new()
    l.text = text
    l.add_theme_font_override("font", font(weight))
    l.add_theme_font_size_override("font_size", size)
    l.add_theme_color_override("font_color", color)
    return l


static func flat(color: Color, radius := 14, pad := 0.0) -> StyleBoxFlat:
    var s := StyleBoxFlat.new()
    s.bg_color = color
    s.set_corner_radius_all(radius)
    s.set_content_margin_all(pad)
    return s


static func panel(color := PANEL, radius := 16, pad := 18.0) -> PanelContainer:
    var p := PanelContainer.new()
    p.add_theme_stylebox_override("panel", flat(color, radius, pad))
    return p


## kind: "primary" (accent), "secondary" (dark), "ghost" (transparent).
static func button(text: String, kind := "primary", size := 22) -> Button:
    var b := Button.new()
    b.text = text
    b.focus_mode = Control.FOCUS_NONE
    var base := ACCENT
    if kind == "secondary":
        base = PANEL_LIGHT
    elif kind == "ghost":
        base = Color(1, 1, 1, 0.0)
    var hover := base.lightened(0.12) if kind != "ghost" else Color(1, 1, 1, 0.08)
    b.add_theme_stylebox_override("normal", flat(base, 12, 14))
    b.add_theme_stylebox_override("hover", flat(hover, 12, 14))
    b.add_theme_stylebox_override("pressed", flat(base.darkened(0.15), 12, 14))
    b.add_theme_stylebox_override("hover_pressed", flat(base.darkened(0.1), 12, 14))
    b.add_theme_stylebox_override("disabled", flat(Color(base, 0.35) if kind != "ghost" else base, 12, 14))
    b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
    b.add_theme_font_override("font", font(700))
    b.add_theme_font_size_override("font_size", size)
    for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
        b.add_theme_color_override(state, TEXT)
    b.add_theme_color_override("font_disabled_color", Color(TEXT, 0.45))
    return b


## A two-state toggle styled like a segment of a segmented control.
static func set_selected(b: Button, selected: bool) -> void:
    var base := ACCENT if selected else PANEL_LIGHT
    b.add_theme_stylebox_override("normal", flat(base, 12, 14))
    b.add_theme_stylebox_override("hover", flat(base.lightened(0.1), 12, 14))


## A shadow behind graphs drawn straight on the world: clear at the top, deepening smoothly
## downwards, and fading out at the sides (one polygon with a colour per corner, no bands).
static func soft_shadow(item: CanvasItem, r: Rect2) -> void:
    var clear := Color(0.04, 0.05, 0.08, 0.0)
    var deep := Color(0.04, 0.05, 0.08, 0.42)
    var side := minf(40.0, r.size.x * 0.1)
    var x0 := r.position.x - 12.0
    var x3 := r.end.x + 12.0
    var x1 := x0 + side
    var x2 := x3 - side
    var top := r.position.y - 6.0
    var bottom := r.end.y + 4.0
    item.draw_polygon(PackedVector2Array([Vector2(x1, top), Vector2(x2, top), Vector2(x2, bottom), Vector2(x1, bottom)]),
        PackedColorArray([clear, clear, deep, deep]))
    item.draw_polygon(PackedVector2Array([Vector2(x0, top), Vector2(x1, top), Vector2(x1, bottom), Vector2(x0, bottom)]),
        PackedColorArray([clear, clear, deep, clear]))
    item.draw_polygon(PackedVector2Array([Vector2(x2, top), Vector2(x3, top), Vector2(x3, bottom), Vector2(x2, bottom)]),
        PackedColorArray([clear, clear, clear, deep]))


static func vbox(separation := 12) -> VBoxContainer:
    var v := VBoxContainer.new()
    v.add_theme_constant_override("separation", separation)
    return v


static func hbox(separation := 12) -> HBoxContainer:
    var h := HBoxContainer.new()
    h.add_theme_constant_override("separation", separation)
    return h


static func spacer() -> Control:
    var c := Control.new()
    c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    c.size_flags_vertical = Control.SIZE_EXPAND_FILL
    return c


static func margin(child: Control, all := 28) -> MarginContainer:
    var m := MarginContainer.new()
    for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
        m.add_theme_constant_override(side, all)
    m.set_anchors_preset(Control.PRESET_FULL_RECT)
    m.add_child(child)
    return m


## Screen header: back button, title and an optional right-hand widget.
static func header(title: String, back_text: String, on_back: Callable) -> HBoxContainer:
    var row := hbox(20)
    if back_text != "":
        var back := button("‹  " + back_text, "secondary", 20)
        back.pressed.connect(on_back)
        row.add_child(back)
    row.add_child(label(title, 34, TEXT, 800))
    return row


## Let clicks fall through every child so a card's own gui_input receives them.
static func pass_clicks(node: Node) -> void:
    for child in node.get_children():
        if child is Control:
            child.mouse_filter = Control.MOUSE_FILTER_IGNORE
        pass_clicks(child)


## Make a container clickable with a hover highlight.
static func clickable(card: Control, on_click: Callable) -> void:
    pass_clicks(card)
    card.mouse_filter = Control.MOUSE_FILTER_STOP
    card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    card.mouse_entered.connect(func(): card.modulate = Color(1.08, 1.08, 1.08))
    card.mouse_exited.connect(func(): card.modulate = Color.WHITE)
    card.gui_input.connect(func(event: InputEvent):
        if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
            on_click.call())


## A world's diorama picture on a soft sky gradient (the picture itself has a transparent background).
static func world_picture(thumb_path: String, min_height := 300.0) -> Control:
    var holder := Control.new()
    holder.custom_minimum_size.y = min_height
    holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
    holder.clip_contents = true
    var gradient := Gradient.new()
    gradient.colors = PackedColorArray([Color("8fb6ea"), Color("c9d6f0"), Color("f6d2b6")])
    gradient.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
    var texture := GradientTexture2D.new()
    texture.gradient = gradient
    texture.fill_from = Vector2(0, 0)
    texture.fill_to = Vector2(0, 1)
    var sky := TextureRect.new()
    sky.texture = texture
    sky.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    sky.stretch_mode = TextureRect.STRETCH_SCALE
    sky.set_anchors_preset(Control.PRESET_FULL_RECT)
    holder.add_child(sky)
    if ResourceLoader.exists(thumb_path):
        var picture := TextureRect.new()
        picture.texture = load(thumb_path)
        picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        # Concept art has its own sky and fills the card; transparent dioramas sit on the gradient.
        var covers := not thumb_path.ends_with("kort.png")
        picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED if covers else TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 0 if covers else 14)
        holder.add_child(picture)
    return holder
