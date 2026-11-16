extends Control
## The power panel in the middle of a ride, low and wide so it does not cover much of the world:
## the watts large with a lightning bolt and the unit on the same baseline, a bar in the colour of
## the power zone under them, and beside them the four chosen fields (Settings.hud_slots) in a
## 2 × 2 grid, each with its own icon, the value and the unit under it. In a workout a strip on
## top shows the step: its target in a block of the zone's colour, its name and the time left
## counting down with a thin bar under the block that fills as it goes, and under them the whole
## workout as a small graph (set_workout): the blocks ahead in their zone colours, what is ridden
## faded, and a marker where you are. Everything else is drawn here, so the numbers sit exactly
## where they should.

const Style = preload("res://ui/style.gd")
const Zones = preload("res://core/zones.gd")

const W := 440.0
const H := 96.0                       # the watts row
const STRIP := 94.0                   # the workout step and its graph on top (show_step), same units
const WorkoutGraph = preload("res://ui/workout_graph.gd")
const SPLIT := 214.0                  # where the four fields begin

var watts := 0
var zone_share := 0.0                 # watts / FTP, for the bar's colour and length
var fields: Array = []                # four of [value, unit, kind] (kind picks the icon)
var alpha := 0.72
## Size: 1 in the world HUD (440 × 96, and the strip), larger on the gym screen. Drawn at that
## size, not scaled, so the text stays sharp.
var k := 1.0:
    set(value):
        k = value
        _resize()
## The workout step on top, as in "ride at 155 W for 5 min", with the time left counting down:
## {"target": "176 W", "length": "i 5 min", "label": "SWEET SPOT", "left": seconds, "fraction": 0–1
## done, "colour": the zone's}. {} hides it (free rides, the workout done).
var step := {}
## The workout's graph inside the panel (set_workout), placed under the step row.
var graph: Control = null


func _init() -> void:
    _resize()
    mouse_filter = Control.MOUSE_FILTER_IGNORE


func _resize() -> void:
    custom_minimum_size = Vector2(W, H + (STRIP if not step.is_empty() else 0.0)) * k
    if graph:
        graph.visible = not step.is_empty()
        graph.position = Vector2(10.0, 50.0) * k
        graph.size = Vector2(W - 20.0, 38.0) * k


## Show the workout's blocks inside the panel; the world HUD moves its cursor (progress).
func set_workout(workout, ftp: float) -> Control:
    graph = WorkoutGraph.new()
    graph.workout = workout
    graph.ftp = ftp
    graph.overlay = true
    graph.shadow = false
    graph.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(graph)
    _resize()
    return graph


func show_step(s: Dictionary) -> void:
    if s == step:
        return
    var resize := s.is_empty() != step.is_empty()
    step = s
    if resize:
        _resize()
    queue_redraw()


func show_values(w: int, share: float, slots: Array) -> void:
    if w == watts and is_equal_approx(share, zone_share) and slots == fields:
        return
    watts = w
    zone_share = share
    fields = slots
    queue_redraw()


func _draw() -> void:
    draw_style_box(Style.flat(Color(Style.PANEL, alpha), 12.0 * k), Rect2(Vector2.ZERO, size))
    var oy := 0.0
    if not step.is_empty():
        _draw_step()
        oy = STRIP * k
    var big := Style.font(900)
    var small := Style.font(800)
    # The watts: bolt, number and unit centred together on one baseline, in the left part.
    var num := "%d" % watts
    var num_w := big.get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, int(58 * k)).x
    var unit_w := small.get_string_size("W", HORIZONTAL_ALIGNMENT_LEFT, -1, int(18 * k)).x
    var total := (20.0 + 8.0 + 4.0) * k + num_w + unit_w
    var x := SPLIT * k * 0.5 - total * 0.5
    var base := oy + 64.0 * k
    _icon("power", Vector2(x + 10.0 * k, base - 20.0 * k), 13.0 * k, Color("ffd34d"))
    draw_string(big, Vector2(x + 28.0 * k, base), num, HORIZONTAL_ALIGNMENT_LEFT, -1, int(58 * k), Style.TEXT)
    draw_string(small, Vector2(x + 32.0 * k + num_w, base), "W", HORIZONTAL_ALIGNMENT_LEFT, -1, int(18 * k), Style.TEXT_DIM)
    # The zone bar: its colour is the zone, its length the share of FTP (full at 150 %).
    var bar := Rect2(16.0 * k, oy + 76.0 * k, (SPLIT - 30.0) * k, 5.0 * k)
    draw_style_box(Style.flat(Color(1, 1, 1, 0.12), 3.0 * k), bar)
    if watts > 0:
        var fill := Rect2(bar.position, Vector2(bar.size.x * clampf(zone_share / 1.5, 0.03, 1.0), bar.size.y))
        draw_style_box(Style.flat(Zones.color(zone_share), 3.0 * k), fill)
    # The four fields, 2 × 2 beside the watts.
    var gx := SPLIT * k
    var gw := (size.x - gx - 8.0 * k) * 0.5
    var gy := oy + 8.0 * k
    var cell_h := (size.y - gy - 8.0 * k) * 0.5
    var line := Color(1, 1, 1, 0.1)
    draw_line(Vector2(gx, gy + 4.0 * k), Vector2(gx, size.y - 10.0 * k), line, 1.0)
    draw_line(Vector2(gx + gw, gy + 4.0 * k), Vector2(gx + gw, size.y - 10.0 * k), line, 1.0)
    draw_line(Vector2(gx + 8.0 * k, gy + cell_h), Vector2(size.x - 14.0 * k, gy + cell_h), line, 1.0)
    for i in mini(fields.size(), 4):
        var f: Array = fields[i]
        var centre := Vector2(gx + gw * (0.5 + i % 2), gy + cell_h * (0.5 + i / 2))
        var value := str(f[0])
        var value_w := big.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, int(21 * k)).x
        var unit_text := tr(str(f[1]))         # drawn text is not translated by itself, as a Label is
        var cap_w := small.get_string_size(unit_text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(9 * k)).x
        var block := 22.0 * k + maxf(value_w, cap_w)
        var left := centre.x - block * 0.5
        _icon(str(f[2]), Vector2(left + 7.0 * k, centre.y - 3.0 * k), 7.0 * k, _icon_colour(str(f[2])))
        draw_string(big, Vector2(left + 22.0 * k, centre.y + 4.0 * k), value, HORIZONTAL_ALIGNMENT_LEFT, -1, int(21 * k), Style.TEXT)
        draw_string(small, Vector2(left + 22.0 * k, centre.y + 15.0 * k), unit_text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(9 * k), Style.TEXT_DIM)


## The step row: the target in a block of the zone's colour with a thin bar under it that fills as
## the step goes by, and what the step is and the time left large on the right. The workout graph
## (a child control) sits under it.
func _draw_step() -> void:
    var big := Style.font(900)
    var small := Style.font(800)
    var colour: Color = step.get("colour", Style.ACCENT)
    var dark := Color("12161d")
    var block := Rect2(10.0 * k, 8.0 * k, 190.0 * k, 30.0 * k)
    draw_style_box(Style.flat(colour, 7.0 * k), block)
    var target := str(step.get("target", ""))
    var tsize := int((18 if target.length() <= 7 else 16) * k)
    var target_w := big.get_string_size(target, HORIZONTAL_ALIGNMENT_LEFT, -1, tsize).x
    draw_string(big, Vector2(block.position.x + 9.0 * k, block.position.y + 21.0 * k), target,
        HORIZONTAL_ALIGNMENT_LEFT, -1, tsize, dark)
    draw_string(small, Vector2(block.position.x + 15.0 * k + target_w, block.position.y + 21.0 * k), str(step.get("length", "")),
        HORIZONTAL_ALIGNMENT_LEFT, block.end.x - (block.position.x + 18.0 * k + target_w), int(11 * k), Color(dark, 0.75))
    var bar := Rect2(block.position.x, block.end.y + 3.0 * k, block.size.x, 3.0 * k)
    draw_style_box(Style.flat(Color(1, 1, 1, 0.14), 2.0 * k), bar)
    var done := clampf(float(step.get("fraction", 0.0)), 0.0, 1.0)
    if done > 0.0:
        draw_style_box(Style.flat(colour, 2.0 * k), Rect2(bar.position, Vector2(maxf(bar.size.x * done, 4.0 * k), bar.size.y)))
    var right := size.x - 12.0 * k
    var left_text := Style.clock(float(step.get("left", 0.0)))
    var left_w := big.get_string_size(left_text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(28 * k)).x
    draw_string(big, Vector2(right - left_w, 36.0 * k), left_text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(28 * k), Style.TEXT)
    var room := right - left_w - 10.0 * k - (block.end.x + 10.0 * k)
    draw_string(small, Vector2(block.end.x + 10.0 * k, 30.0 * k), str(step.get("label", "")), HORIZONTAL_ALIGNMENT_RIGHT,
        room, int(11 * k), Style.TEXT_DIM)
    # A faint line between the step and the watts, under the graph.
    draw_line(Vector2(12.0 * k, (STRIP - 2.0) * k), Vector2(size.x - 12.0 * k, (STRIP - 2.0) * k), Color(1, 1, 1, 0.08), 1.0)


static func _icon_colour(kind: String) -> Color:
    match kind:
        "hr":
            return Color("ff5a5f")
        "kj":
            return Color("ff9b3d")
        "avg_power", "max_power", "np", "power":
            return Color("ffd34d")
    return Color(1, 1, 1, 0.85)


## A small icon centred on `c` with radius `r`: bolt (watts), arrows (cadence), heart (pulse),
## flame (kilojoules), kettlebell (W/kg) or a dial (speed).
func _icon(kind: String, c: Vector2, r: float, colour: Color) -> void:
    match kind:
        "hr":
            draw_circle(c + Vector2(-r * 0.45, -r * 0.25), r * 0.52, colour)
            draw_circle(c + Vector2(r * 0.45, -r * 0.25), r * 0.52, colour)
            draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.95, -r * 0.05), c + Vector2(r * 0.95, -r * 0.05),
                c + Vector2(0, r * 0.95)]), colour)
        "cadence":
            draw_arc(c, r * 0.8, -PI * 0.1, PI * 1.45, 18, colour, r * 0.28)
            var tip := c + Vector2(cos(-PI * 0.1), sin(-PI * 0.1)) * r * 0.8
            draw_colored_polygon(PackedVector2Array([tip + Vector2(-r * 0.45, -r * 0.1), tip + Vector2(r * 0.45, -r * 0.1),
                tip + Vector2(0, r * 0.5)]), colour)
        "kj":
            draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.55, -r * 0.1), c + Vector2(r * 0.7, r * 0.45),
                c + Vector2(0, r), c + Vector2(-r * 0.7, r * 0.45), c + Vector2(-r * 0.45, -r * 0.2), c + Vector2(-r * 0.1, r * 0.05)]), colour)
        "wkg":
            draw_arc(c + Vector2(0, -r * 0.45), r * 0.4, PI, TAU, 12, colour, r * 0.22)
            draw_circle(c + Vector2(0, r * 0.25), r * 0.68, colour)
        "speed":
            draw_arc(c + Vector2(0, r * 0.25), r * 0.85, PI, TAU, 16, colour, r * 0.25)
            draw_line(c + Vector2(0, r * 0.25), c + Vector2(r * 0.55, -r * 0.4), colour, r * 0.25)
        _:
            draw_colored_polygon(PackedVector2Array([c + Vector2(r * 0.25, -r * 1.1), c + Vector2(-r * 0.65, r * 0.15),
                c + Vector2(-r * 0.05, r * 0.15), c + Vector2(-r * 0.3, r * 1.1), c + Vector2(r * 0.65, -r * 0.2),
                c + Vector2(r * 0.05, -r * 0.2)]), colour)
