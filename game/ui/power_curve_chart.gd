extends Control
## The power curve: best watts for each duration from 5 seconds to an hour, on a log time axis.
## `curves` is a list of [curve, colour, width]; a curve maps "5", "60" … to watts.

const PowerCurve = preload("res://core/power_curve.gd")
const Style = preload("res://ui/style.gd")

var curves: Array = []
var background := Color("232a36")


func _draw() -> void:
    draw_style_box(Style.flat(background, 12), Rect2(Vector2.ZERO, size))
    var left := 52.0
    var right := 30.0
    var top := 18.0
    var bottom := 34.0
    var w := size.x - left - right
    var h := size.y - top - bottom
    var top_w := 100.0
    for c in curves:
        for key in c[0]:
            top_w = maxf(top_w, float(c[0][key]))
    top_w = ceilf(top_w * 1.1 / 100.0) * 100.0
    var lo := log(float(PowerCurve.DURATIONS[0]))
    var hi := log(float(PowerCurve.DURATIONS[-1]))
    var font := Style.font(700)
    var dim := Color(Style.TEXT_DIM, 0.9)
    # Watt grid every 100 W (every 200 W when the curve reaches high).
    var step := 100.0 if top_w <= 600.0 else 200.0
    var y_w := 0.0
    while y_w <= top_w:
        var y := top + h - h * y_w / top_w
        draw_line(Vector2(left, y), Vector2(left + w, y), Color(1, 1, 1, 0.07), 1.0)
        draw_string(font, Vector2(6, y + 5), "%d W" % roundi(y_w), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, dim)
        y_w += step
    for d in PowerCurve.DURATIONS:
        var x := left + w * (log(float(d)) - lo) / (hi - lo)
        draw_line(Vector2(x, top), Vector2(x, top + h), Color(1, 1, 1, 0.05), 1.0)
        var text := PowerCurve.label(d)
        if d == 1800:
            continue        # too close to 20 min on the log axis
        draw_string(font, Vector2(x - 30, size.y - 10), text, HORIZONTAL_ALIGNMENT_CENTER, 60, 12, dim)
    for c in curves:
        var pts := PackedVector2Array()
        for d in PowerCurve.DURATIONS:
            var key := str(d)
            if not c[0].has(key):
                continue
            var x := left + w * (log(float(d)) - lo) / (hi - lo)
            pts.append(Vector2(x, top + h - h * float(c[0][key]) / top_w))
        if pts.size() >= 2:
            draw_polyline(pts, c[1], c[2], true)
        for p in pts:
            draw_circle(p, c[2] + 1.5, c[1])
