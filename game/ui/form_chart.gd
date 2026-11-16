extends Control
## Fitness, fatigue and form over the last 90 days (Progress.fitness): fitness (CTL) as a blue line,
## fatigue (ATL) as a pink line, form (TSB) as bars around zero, as in Strava and TrainingPeaks.

const Style = preload("res://ui/style.gd")

var data := {}


func _draw() -> void:
    draw_style_box(Style.flat(Style.GRAPH_BG, 12), Rect2(Vector2.ZERO, size))
    var ctl: PackedFloat32Array = data.get("ctl", PackedFloat32Array())
    var atl: PackedFloat32Array = data.get("atl", PackedFloat32Array())
    var tsb: PackedFloat32Array = data.get("tsb", PackedFloat32Array())
    var n := ctl.size()
    var font := Style.font(700)
    var left := 16.0
    var right := size.x - 16.0
    var top := 30.0
    var bottom := size.y - 14.0
    draw_string(font, Vector2(left, 20), tr("Kondition"), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("5aa9ff"))
    draw_string(font, Vector2(left + 100, 20), tr("Trötthet"), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("ff7ab0"))
    draw_string(font, Vector2(left + 190, 20), tr("Form"), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("ffd34d"))
    if n < 2:
        return
    var hi := 20.0
    var lo := -10.0
    for i in n:
        hi = maxf(hi, maxf(ctl[i], atl[i]))
        lo = minf(lo, tsb[i])
    hi *= 1.1
    var y0 := func(v: float) -> float: return bottom - (bottom - top) * (v - lo) / (hi - lo)
    var zero: float = y0.call(0.0)
    draw_line(Vector2(left, zero), Vector2(right, zero), Color(1, 1, 1, 0.12), 1.0)
    var step := (right - left) / (n - 1)
    for i in n:
        var x := left + i * step
        var y: float = y0.call(tsb[i])
        draw_line(Vector2(x, zero), Vector2(x, y), Color("ffd34d", 0.45), maxf(step - 1.0, 1.0))
    var pc := PackedVector2Array()
    var pa := PackedVector2Array()
    for i in n:
        pc.append(Vector2(left + i * step, y0.call(ctl[i])))
        pa.append(Vector2(left + i * step, y0.call(atl[i])))
    draw_polyline(pa, Color("ff7ab0"), 2.0, true)
    draw_polyline(pc, Color("5aa9ff"), 3.0, true)
    draw_string(font, Vector2(right - 260, 20), tr("Kondition %d  ·  Form %+d") % [roundi(ctl[n - 1]), roundi(tsb[n - 1])],
        HORIZONTAL_ALIGNMENT_RIGHT, 260, 13, Style.TEXT)
