extends Control
## Elevation profile of the world's loop with the rider's position, lap and current grade.

const Style = preload("res://ui/style.gd")

var heights := PackedFloat32Array()
var length := 1.0
var distance := 0.0
var grade := 0.0
var compact := false     # smaller text for the world HUD
var route_text := ""     # the route being ridden and how far is left (shown instead of the lap)
var overlay := false     # over the world (the ride's HUD): no box, a soft shadow, outlined text


func _draw() -> void:
    if overlay:
        Style.soft_shadow(self, Rect2(Vector2.ZERO, size))
    else:
        draw_style_box(Style.flat(Color(Style.GRAPH_BG, 0.72 if compact else 0.82), 12), Rect2(Vector2.ZERO, size))
    if heights.size() < 2:
        return
    var low := 1e9
    var high := -1e9
    for h in heights:
        low = minf(low, h)
        high = maxf(high, h)
    var top := 26.0 if compact else 34.0
    var bottom := size.y - 10.0
    var left := 14.0
    var right := size.x - 14.0
    var span := maxf(high - low, 10.0)
    var points := PackedVector2Array([Vector2(left, bottom)])
    for k in heights.size():
        var x := lerpf(left, right, float(k) / (heights.size() - 1))
        points.append(Vector2(x, bottom - (heights[k] - low) / span * (bottom - top)))
    points.append(Vector2(right, bottom))
    draw_colored_polygon(points, Color("c99382", 0.85) if overlay else Color("c99382"))
    if overlay:
        draw_line(Vector2(left, bottom), Vector2(right, bottom), Color(1, 1, 1, 0.45), 1.5)
    var at := fposmod(distance, length) / length
    var x := lerpf(left, right, at)
    var k := int(at * (heights.size() - 1))
    var y := bottom - (heights[k] - low) / span * (bottom - top)
    draw_line(Vector2(x, top - 6), Vector2(x, bottom), Color.WHITE, 2.0)
    draw_circle(Vector2(x, y), 7.0, Style.ACCENT)
    var f := Style.font(700)
    var lap := int(distance / length) + 1
    var text_size := 13 if compact else 17
    var y_text := 18.0 if compact else 22.0
    var head := tr("Varv %d  ·  %s km kvar  ·  %s %%") % [
        lap, Style.dec((length - fposmod(distance, length)) / 1000.0, 1), Style.dec(grade)]
    if route_text != "":
        head = "%s  ·  %s %%" % [route_text, Style.dec(grade)]
    if overlay:
        draw_string_outline(f, Vector2(left, y_text), head, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size, 5, Color(0, 0, 0, 0.6))
    draw_string(f, Vector2(left, y_text), head, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size, Style.TEXT)
    if not compact:
        draw_string(f, Vector2(right - 120, y_text), tr("%d–%d m ö.h.") % [roundi(low), roundi(high)], HORIZONTAL_ALIGNMENT_RIGHT, 120, 15, Style.TEXT_DIM)
