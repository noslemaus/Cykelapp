extends Control
## Workout profile: one bar per segment coloured by power zone, ramps in coloured slices and
## free segments as grey blocks with a jagged top. `detailed` adds watt labels, an FTP line,
## the peak line, a progress cursor and the rider's actual power on top.

const Zones = preload("res://core/zones.gd")
const Style = preload("res://ui/style.gd")

var workout
var ftp := 200.0
var intensity := 1.0
var detailed := false
var progress := -1.0                    # seconds into the workout; < 0 hides the cursor
var actual := PackedFloat32Array()      # actual watts, one per second
var background := Style.GRAPH_BG
var label_color := Style.TEXT        # use a dark colour on light backgrounds
var radius := 12
## Over the world (the ride's HUD): no box, see-through blocks on a soft shadow, the part
## already ridden faded, and the cursor with a small marker on top.
var overlay := false
var shadow := true                      # overlay only: the soft shadow (off inside a panel)

var _left := 0.0
var _right := 0.0
var _top := 0.0
var _bottom := 0.0
var _peak := 1.0
var _cursor := -1.0                     # x of the progress cursor (overlay: faded to its left)


func _x(t: float) -> float:
    return _left + (_right - _left) * t / workout.duration


## y for a fraction of FTP *before* intensity scaling.
func _y(fraction: float) -> float:
    return _bottom - (_bottom - _top) * clampf(fraction / _peak, 0.0, 1.0)


func _draw() -> void:
    if overlay:
        # A soft shadow that deepens downwards, so the blocks read on a bright sky or snow.
        if shadow:
            Style.soft_shadow(self, Rect2(Vector2.ZERO, size))
    else:
        draw_style_box(Style.flat(background, radius), Rect2(Vector2.ZERO, size))
    if workout == null or workout.duration <= 0.0:
        return
    _left = 64.0 if detailed else 0.0
    _right = size.x - (70.0 if detailed else 0.0)
    _top = 30.0 if detailed else 10.0
    _bottom = size.y - (8.0 if detailed else 0.0)
    _peak = maxf(workout.peak() * intensity, 1.05) * 1.1
    _cursor = _x(minf(progress, workout.duration)) if overlay and progress >= 0.0 else -1.0

    for s in workout.segments:
        _draw_segment(s)
    if overlay:
        draw_line(Vector2(_left, _bottom), Vector2(_right, _bottom), Color(1, 1, 1, 0.45), 1.5)
        if _cursor >= 0.0:
            draw_line(Vector2(_cursor, _top - 4.0), Vector2(_cursor, _bottom), Color.WHITE, 2.5)
            draw_colored_polygon(PackedVector2Array([Vector2(_cursor - 7.0, _top - 12.0), Vector2(_cursor + 7.0, _top - 12.0),
                Vector2(_cursor, _top - 3.0)]), Color.WHITE)
        return

    if detailed:
        _draw_lines()
    if actual.size() > 1:
        _draw_actual()
    if progress >= 0.0:
        var x := _x(minf(progress, workout.duration))
        draw_rect(Rect2(_left, _top - 6.0, x - _left, _bottom - _top + 6.0), Color(0, 0, 0, 0.28))
        draw_line(Vector2(x, _top - 10.0), Vector2(x, _bottom), Color.WHITE, 3.0)


func _draw_segment(s: Dictionary) -> void:
    var x0 := _x(s["start"])
    var x1 := _x(s["start"] + s["duration"])
    var gap := 1.0 if x1 - x0 > 4.0 else 0.0
    x1 -= gap
    if s["free"]:
        var level := _y(0.55)
        var points := PackedVector2Array([Vector2(x0, _bottom)])
        var x := x0
        var up := true
        while x < x1:
            points.append(Vector2(x, level - (5.0 if up else 0.0)))
            up = not up
            x += 7.0
        points.append(Vector2(x1, level))
        points.append(Vector2(x1, _bottom))
        draw_colored_polygon(points, _tint(Color("6c7280"), x0, x1))
        return
    var from: float = s["from"] * intensity
    var to: float = s["to"] * intensity
    if is_equal_approx(from, to):
        if overlay and _cursor > x0 and _cursor < x1:
            # Split where the cursor is: faded behind it, clear ahead.
            draw_rect(Rect2(x0, _y(from), _cursor - x0, _bottom - _y(from)), _tint(Zones.color(from), x0, _cursor))
            draw_rect(Rect2(_cursor, _y(from), x1 - _cursor, _bottom - _y(from)), _tint(Zones.color(from), _cursor, x1))
            draw_line(Vector2(_cursor, _y(from)), Vector2(x1, _y(from)), Color(1, 1, 1, 0.8), 2.0)
        else:
            draw_rect(Rect2(x0, _y(from), x1 - x0, _bottom - _y(from)), _tint(Zones.color(from), x0, x1))
        return
    var slices := maxi(1, int((x1 - x0) / 5.0))
    for k in slices:
        var f0 := float(k) / slices
        var f1 := float(k + 1) / slices
        var p0 := lerpf(from, to, f0)
        var p1 := lerpf(from, to, f1)
        var xa := lerpf(x0, x1, f0)
        var xb := lerpf(x0, x1, f1)
        draw_colored_polygon(PackedVector2Array([
            Vector2(xa, _bottom), Vector2(xa, _y(p0)), Vector2(xb, _y(p1)), Vector2(xb, _bottom)]),
            _tint(Zones.color((p0 + p1) * 0.5), xa, xb))


## A block's colour: as it is in the menus; over the world see-through, and faded once ridden.
func _tint(c: Color, x0: float, x1: float) -> Color:
    if not overlay:
        return c
    if _cursor >= 0.0 and x1 <= _cursor + 0.5:
        return Color(c.lerp(Color(0.5, 0.52, 0.56), 0.55), 0.42)
    return Color(c, 0.86)


func _draw_lines() -> void:
    var f := Style.font(700)
    var ftp_y := _y(1.0)
    var line_color := Color(label_color, 0.55)
    draw_line(Vector2(_left, ftp_y), Vector2(_right, ftp_y), line_color, 2.0)
    draw_string(f, Vector2(10, ftp_y - 4), "FTP", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(label_color, 0.7))
    draw_string(f, Vector2(10, ftp_y + 15), "%d W" % roundi(ftp), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, label_color)
    var peak_fraction: float = workout.peak() * intensity
    var peak_y := _y(peak_fraction)
    var x := _left
    while x < _right:
        draw_line(Vector2(x, peak_y), Vector2(minf(x + 8.0, _right), peak_y), Color(label_color, 0.35), 1.5)
        x += 14.0
    draw_string(f, Vector2(_right + 8, peak_y + 6), "%d W" % roundi(peak_fraction * ftp),
        HORIZONTAL_ALIGNMENT_LEFT, -1, 16, label_color)


func _draw_actual() -> void:
    var points := PackedVector2Array()
    var stride := maxi(1, actual.size() / 900)
    for i in range(0, actual.size(), stride):
        points.append(Vector2(_x(float(i)), _y(actual[i] / ftp)))
    if points.size() > 1:
        draw_polyline(points, Color(1, 1, 1, 0.9), 2.0, true)
