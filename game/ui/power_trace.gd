extends Control
## Free-ride power history: the last `window` seconds as thin bars coloured by zone.

const Zones = preload("res://core/zones.gd")
const Style = preload("res://ui/style.gd")

var values := PackedFloat32Array()
var ftp := 200.0
var window := 600


func _draw() -> void:
    draw_style_box(Style.flat(Style.GRAPH_BG, 12), Rect2(Vector2.ZERO, size))
    var top := 26.0
    var bottom := size.y - 6.0
    var peak := maxf(ftp * 1.6, 1.0)
    var ftp_y := bottom - (bottom - top) * ftp / peak
    draw_line(Vector2(0, ftp_y), Vector2(size.x, ftp_y), Color(1, 1, 1, 0.4), 1.5)
    draw_string(Style.font(700), Vector2(10, ftp_y - 5), "FTP %d W" % roundi(ftp), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Style.TEXT_DIM)
    draw_string(Style.font(700), Vector2(10, 20), tr("Senaste %d min") % (window / 60), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Style.TEXT_DIM)
    var start := maxi(0, values.size() - window)
    var bar := size.x / window
    for i in range(start, values.size()):
        var p := values[i]
        var h := (bottom - top) * clampf(p / peak, 0.0, 1.0)
        var x := (i - start) * bar
        draw_rect(Rect2(x, bottom - h, maxf(bar, 1.0), h), Zones.color(p / ftp))
