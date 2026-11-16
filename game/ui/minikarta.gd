extends Control
## The map of the world, top right: the baked map picture (res://world/<id>/karta.png,
## made by `--kartor`) with you as an arrow, the ghost, the pacers, the teleport gates, the start line
## and the world's secret: where the bike turns into the tank, the pickup or the samurai.
## `whole` shows all of the world with names (the big map, K); otherwise a window of `span` metres
## follows you.

const Style = preload("res://ui/style.gd")
const SCALE := 3.0                    # metres per pixel in the baked map (main.gd MAP_SCALE)

## The secret vehicle per world: what you become and where it waits.
const SECRETS := {
    "stridsvagn": ["Stridsvagnen", "hemliga militärbasen"],
    "flakbil": ["Flakbilen", "utgrävningslägret"],
    "samurai": ["Samurajen", "dojon bakom vattenfallet"],
}

var world: Node3D
var world_id := ""
var whole := false
var span := 900.0                     # metres across in the small map
var pacers: Array = []                # [{"pos": Vector3, "colour": Color}] from world/pacers.gd
var ghost_pos = null                  # Vector3 or null
var _texture: Texture2D
var _area := Rect2()


func setup(w: Node3D, id: String) -> void:
    world = w
    world_id = id
    _area = w.CORE.grow(180.0)
    var path := "res://world/%s/karta.png" % id
    _texture = load(path) if ResourceLoader.exists(path) else null
    clip_contents = true


## Where you are and which way you look, on the lap or riding free.
func _me() -> Array:
    if world.roam and world.fri:
        return [world.fri.pos, Vector2(world.fri.heading.x, world.fri.heading.y)]
    var here: Dictionary = world.sample(world.lap_distance(Ride.distance))
    var dir: Vector3 = here["dir"]
    return [here["pos"], Vector2(dir.x, dir.z).normalized()]


func _process(_delta: float) -> void:
    if world and is_visible_in_tree():
        queue_redraw()


func _draw() -> void:
    if world == null:
        return
    draw_style_box(Style.flat(Color("17435f"), 12), Rect2(Vector2.ZERO, size))
    var me := _me()
    var view: Rect2
    if whole:
        view = _fit(_area, size)
    else:
        var h := span * size.y / maxf(size.x, 1.0)
        view = Rect2(Vector2(me[0].x, me[0].z) - Vector2(span, h) * 0.5, Vector2(span, h))
    if _texture:
        # The whole baked map where it lies in the view (the control clips what falls outside).
        draw_texture_rect(_texture, Rect2((_area.position - view.position) / view.size * size, _area.size / view.size * size), false)
    var to_px := func(p: Vector3) -> Vector2:
        return (Vector2(p.x, p.z) - view.position) / view.size * size
    # The start line.
    var start: Dictionary = world.sample(0.0)
    var sp: Vector2 = to_px.call(start["pos"])
    var across := Vector2(-start["dir"].z, start["dir"].x).normalized() * 7.0
    draw_line(sp - across, sp + across, Color("ffd34d"), 3.0)
    # Teleport gates.
    var gates = world.get("teleports")
    for t in (gates if gates != null else []):
        var p: Vector2 = to_px.call(t[0])
        draw_arc(p, 7.0, 0.0, TAU, 20, Color("6fe8ff"), 2.5)
        if whole:
            _text(p + Vector2(10, 4), tr("Teleport till %s") % tr(_world_name(str(t[1]))), Color("6fe8ff"), 13)
    # The secret vehicle.
    var tank = world.get("base_tank")
    if tank:
        var p: Vector2 = to_px.call(tank.position)
        var theme: Dictionary = world.battle_theme() if world.has_method("battle_theme") else {}
        var secret: Array = SECRETS.get(str(theme.get("vehicle", "")), ["?", ""])
        if whole:
            _star(p, 9.0, Color("ffd34d"))
            _text(p + Vector2(13, -2), tr(secret[0]), Color("ffd34d"), 16)
            _text(p + Vector2(13, 15), tr("vid %s: Tryck ej här och cykla dit") % tr(secret[1]), Color(1, 1, 1, 0.85), 12)
        elif Rect2(Vector2.ZERO, size).grow(-8.0).has_point(p):
            _star(p, 7.0, Color("ffd34d"))
        else:
            # Off the small map: a pointer on the map's edge shows the way, with how far it is.
            var metres := Vector2(tank.position.x - me[0].x, tank.position.z - me[0].z).length()
            _pointer(p, metres)
    for b in pacers:
        draw_circle(to_px.call(b["pos"]), 4.5, Color(0, 0, 0, 0.6))
        draw_circle(to_px.call(b["pos"]), 3.5, b["colour"])
    if ghost_pos != null:
        draw_circle(to_px.call(ghost_pos), 4.0, Color(0.55, 0.95, 1.0, 0.9))
    # You: an arrow the way you ride.
    var at: Vector2 = to_px.call(me[0])
    var f: Vector2 = me[1] if me[1].length() > 0.01 else Vector2.RIGHT
    var side := Vector2(-f.y, f.x)
    var arrow := PackedVector2Array([at + f * 11.0, at - f * 7.0 + side * 7.0, at - f * 3.0, at - f * 7.0 - side * 7.0])
    draw_colored_polygon(arrow, Color.WHITE)
    draw_polyline(arrow + PackedVector2Array([arrow[0]]), Style.ACCENT, 2.0)
    if whole:
        _text(Vector2(14, 24), tr(_world_name(world_id)).to_upper(), Color.WHITE, 18)
        _text(Vector2(14, size.y - 14), tr("K stänger kartan  ·  ★ hemligheten  ·  ◯ teleport  ·  gult streck = start"),
            Color(1, 1, 1, 0.8), 12)


## The secret beyond the small map's edge: a dark badge with the star on the edge, in its direction,
## an arrowhead pointing on outwards, and the distance beside it, so it reads as "that way", not as
## something lying there.
func _pointer(target: Vector2, metres: float) -> void:
    var c := size * 0.5
    var d := (target - c).normalized()
    var margin := 26.0
    var t := minf((size.x * 0.5 - margin) / maxf(absf(d.x), 0.001), (size.y * 0.5 - margin) / maxf(absf(d.y), 0.001))
    var e := c + d * t
    var side := Vector2(-d.y, d.x)
    var gold := Color("ffd34d")
    draw_circle(e, 13.0, Color(0.05, 0.07, 0.1, 0.85))
    draw_arc(e, 13.0, 0.0, TAU, 24, gold, 2.0)
    _star(e, 7.0, gold)
    var tip := e + d * 24.0
    draw_colored_polygon(PackedVector2Array([tip, e + d * 14.0 + side * 7.0, e + d * 14.0 - side * 7.0]), gold)
    var text := "%d m" % roundi(metres) if metres < 1000.0 else "%s km" % Style.dec(metres / 1000.0, 1)
    var f := Style.font(800)
    var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
    # Beside the badge, on the side towards the middle of the map.
    var at: Vector2
    if absf(d.x) >= absf(d.y):
        at = Vector2(e.x - 19.0 - w if d.x > 0.0 else e.x + 19.0, e.y + 4.0)
    else:
        at = Vector2(e.x - w * 0.5, e.y - 19.0 if d.y > 0.0 else e.y + 27.0)
    at.x = clampf(at.x, 4.0, size.x - w - 4.0)
    _text(at, text, gold, 12)


## The whole area into the control, keeping its shape.
static func _fit(area: Rect2, box: Vector2) -> Rect2:
    var aspect := box.x / maxf(box.y, 1.0)
    var r := area
    if r.size.x / r.size.y > aspect:
        var h := r.size.x / aspect
        r = Rect2(r.position.x, r.position.y - (h - r.size.y) * 0.5, r.size.x, h)
    else:
        var w := r.size.y * aspect
        r = Rect2(r.position.x - (w - r.size.x) * 0.5, r.position.y, w, r.size.y)
    return r


func _star(p: Vector2, r: float, colour: Color) -> void:
    var pts := PackedVector2Array()
    for k in 10:
        var a := -PI / 2.0 + k * PI / 5.0
        pts.append(p + Vector2(cos(a), sin(a)) * (r if k % 2 == 0 else r * 0.45))
    draw_colored_polygon(pts, colour)
    draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0, 0, 0, 0.6), 1.5)


func _text(p: Vector2, text: String, colour: Color, font_size: int) -> void:
    var f := Style.font(800)
    draw_string_outline(f, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, Color(0, 0, 0, 0.7))
    draw_string(f, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, colour)


static func _world_name(id: String) -> String:
    return {"skargarden": "Skärgården", "egypten": "Egypten", "japan": "Japan"}.get(id, id)
