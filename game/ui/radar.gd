extends Control
## The tank's radar in the HUD: heading up, 150 m out. Zombies are green dots, aliens pale
## green, Pysare yellow, the UFO a big purple dot; the gun's target gets a red ring.

const RANGE := 150.0

var strid      # the battle (world/strid.gd)
var _sweep := 0.0


func _process(delta: float) -> void:
    _sweep = fmod(_sweep + delta * 2.2, TAU)
    queue_redraw()


func _draw() -> void:
    var r := minf(size.x, size.y) * 0.5
    var c := size * 0.5
    draw_circle(c, r, Color(0.05, 0.12, 0.08, 0.75))
    for k in [0.33, 0.66, 1.0]:
        draw_arc(c, r * k, 0.0, TAU, 40, Color(0.4, 0.9, 0.5, 0.35), 1.0, true)
    draw_line(c - Vector2(r, 0), c + Vector2(r, 0), Color(0.4, 0.9, 0.5, 0.2))
    draw_line(c - Vector2(0, r), c + Vector2(0, r), Color(0.4, 0.9, 0.5, 0.2))
    var a := -PI / 2.0 + _sweep
    draw_line(c, c + Vector2.from_angle(a) * r, Color(0.5, 1.0, 0.6, 0.5), 2.0, true)
    draw_colored_polygon(PackedVector2Array([c, c + Vector2.from_angle(a - 0.35) * r, c + Vector2.from_angle(a) * r]),
        Color(0.5, 1.0, 0.6, 0.12))
    if strid == null or strid.tank == null:
        return
    var me: Vector3 = strid.tank.position
    var yaw: float = strid.tank.rotation.y
    var dots: Array = []
    for m in strid.monsters:
        if is_instance_valid(m) and not m.dead:
            var col: Color = {"zombie": Color("8fd16a"), "alien": Color("bff5c8"), "pysare": Color("ffd94a"),
                "mumie": Color("f0e6c8"), "skarabe": Color("5fe0d0"), "farao": Color("ffc83a"), "oni": Color("ff6a4a"),
                "ninja": Color("c0c0d8"), "kitsune": Color("6fd0ff")}.get(m.kind, Color.WHITE)
            dots.append([m.position, col, 6.0 if m.kind == "farao" else 3.5, m == strid.target])
    if strid.ufo:
        dots.append([strid.ufo.position, Color("c38bff"), 6.0, strid.ufo == strid.target])
    for d in dots:
        var v: Vector3 = d[0] - me
        # Heading up: rotate so the tank's forward (+X at yaw) points to the top of the dial.
        var local := Vector2(v.x, v.z).rotated(yaw)      # forward becomes +X
        var p := c + Vector2(local.y, -local.x) / RANGE * r
        if p.distance_to(c) > r - 2.0:
            p = c + (p - c).normalized() * (r - 2.0)
        draw_circle(p, d[2], d[1])
        if d[3]:
            draw_arc(p, d[2] + 4.0, 0.0, TAU, 16, Color("ff4d3d"), 2.0, true)
    draw_colored_polygon(PackedVector2Array([c + Vector2(0, -7), c + Vector2(5, 5), c + Vector2(-5, 5)]), Color.WHITE)
