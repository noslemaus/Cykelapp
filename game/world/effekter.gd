extends Node3D
## Short-lived effects for the battle: shell bursts (fireball, smoke, debris, sparks, a flash of
## light and a scorch mark), muzzle flashes, puffs when monsters appear or fall, and the light beam
## a UFO lowers its aliens in. Every effect removes itself when it is done.

var _items: Array = []      # [node, kind, age, life, data]
var _scorch_tex: GradientTexture2D
var _soft: GradientTexture2D        # a soft round dot for smoke and sparks


func _process(delta: float) -> void:
    for k in range(_items.size() - 1, -1, -1):
        var it: Array = _items[k]
        it[2] += delta
        var t: float = it[2] / it[3]
        var node: Node3D = it[0]
        match it[1]:
            "ball":
                # Grows fast, then fades and darkens.
                var r: float = it[4]
                node.scale = Vector3.ONE * r * clampf(t * 5.0, 0.15, 1.0) * (1.0 + t * 0.3)
                var m: StandardMaterial3D = (node as MeshInstance3D).material_override
                m.albedo_color.a = clampf(1.4 - t * 1.4, 0.0, 1.0)
                m.emission_energy_multiplier = 6.0 * (1.0 - t)
            "light":
                (node as OmniLight3D).light_energy = it[4] * (1.0 - t) * (1.0 - t)
            "scorch":
                (node as Decal).modulate.a = clampf((1.0 - t) * 4.0, 0.0, 0.85)
            "beam":
                var m: StandardMaterial3D = (node as MeshInstance3D).material_override
                m.albedo_color.a = 0.35 * sin(t * PI)
        if t >= 1.0:
            node.queue_free()
            _items.remove_at(k)


func _keep(node: Node3D, kind: String, life: float, data = null) -> void:
    _items.append([node, kind, 0.0, life, data])


func _glow(color: Color, energy: float) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    m.albedo_color = color
    m.emission_enabled = true
    m.emission = color
    m.emission_energy_multiplier = energy
    m.cull_mode = BaseMaterial3D.CULL_DISABLED
    return m


func _ball(at: Vector3, radius: float, color: Color, life: float) -> void:
    var mi := MeshInstance3D.new()
    var sphere := SphereMesh.new()
    sphere.radius = 1.0
    sphere.height = 2.0
    sphere.radial_segments = 12
    sphere.rings = 6
    mi.mesh = sphere
    mi.material_override = _glow(color, 6.0)
    mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    mi.position = at
    add_child(mi)
    _keep(mi, "ball", life, radius)


func _light(at: Vector3, color: Color, energy: float, reach: float, life: float) -> void:
    var l := OmniLight3D.new()
    l.light_color = color
    l.light_energy = energy
    l.omni_range = reach
    l.position = at
    add_child(l)
    _keep(l, "light", life, energy)


## A particle burst: `count` pieces flung out from `at`, all in one go.
func _burst(at: Vector3, count: int, life: float, speed: Vector2, spread: float, gravity: float, size: Vector2,
        colors: Array, mesh: Mesh, unshaded := false, rising := false) -> void:
    var p := GPUParticles3D.new()
    p.amount = count
    p.lifetime = life
    p.one_shot = true
    p.explosiveness = 0.95
    p.local_coords = false
    var pm := ParticleProcessMaterial.new()
    pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
    pm.emission_sphere_radius = size.x * 1.5
    pm.direction = Vector3.UP
    pm.spread = spread
    pm.initial_velocity_min = speed.x
    pm.initial_velocity_max = speed.y
    pm.gravity = Vector3(0, gravity, 0)
    pm.damping_min = 1.0 if rising else 0.0
    pm.damping_max = 3.0 if rising else 0.5
    pm.scale_min = size.x
    pm.scale_max = size.y
    pm.angular_velocity_min = -200.0
    pm.angular_velocity_max = 200.0
    var ramp := Gradient.new()
    ramp.set_color(0, colors[0])
    ramp.set_color(1, colors[1])
    var tex := GradientTexture1D.new()
    tex.gradient = ramp
    pm.color_ramp = tex
    if rising:
        var curve := Curve.new()
        curve.add_point(Vector2(0.0, 0.5))
        curve.add_point(Vector2(1.0, 1.6))
        var ct := CurveTexture.new()
        ct.curve = curve
        pm.scale_curve = ct
    p.process_material = pm
    var m := StandardMaterial3D.new()
    m.vertex_color_use_as_albedo = true
    m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    if unshaded:
        m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    if mesh is QuadMesh:
        m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
        m.albedo_texture = _soft_dot()
    var dm: PrimitiveMesh = mesh.duplicate()
    dm.material = m
    p.draw_pass_1 = dm
    p.position = at
    p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(p)
    p.emitting = true
    _keep(p, "particles", life + 0.3)


func _soft_dot() -> GradientTexture2D:
    if _soft == null:
        var g := Gradient.new()
        g.set_color(0, Color(1, 1, 1, 1))
        g.set_color(1, Color(1, 1, 1, 0))
        g.add_point(0.45, Color(1, 1, 1, 0.75))
        _soft = GradientTexture2D.new()
        _soft.gradient = g
        _soft.fill = GradientTexture2D.FILL_RADIAL
        _soft.fill_from = Vector2(0.5, 0.5)
        _soft.fill_to = Vector2(1.0, 0.5)
        _soft.width = 64
        _soft.height = 64
    return _soft


func _quad(size: float) -> QuadMesh:
    var q := QuadMesh.new()
    q.size = Vector2(size, size)
    return q


func _chunk(size: float) -> BoxMesh:
    var b := BoxMesh.new()
    b.size = Vector3(size, size * 0.7, size * 0.9)
    return b


## A shell or Pysare going off: fireball, smoke rolling up, debris and sparks, a flash and a mark.
func explosion(at: Vector3, radius: float, ground_y: float) -> void:
    var r := radius / 7.5
    _ball(at + Vector3.UP * 0.8 * r, 3.6 * r, Color(1.0, 0.62, 0.2), 0.8)
    _ball(at + Vector3(0.9, 1.6, -0.5) * r, 2.5 * r, Color(1.0, 0.85, 0.4), 0.6)
    _ball(at + Vector3(-1.0, 1.0, 0.8) * r, 2.3 * r, Color(0.95, 0.4, 0.15), 0.9)
    _burst(at, 26, 2.6, Vector2(2.0, 6.0) * r, 70.0, 1.6, Vector2(2.0, 3.6) * r,
        [Color(0.25, 0.23, 0.22, 0.85), Color(0.5, 0.48, 0.46, 0.0)], _quad(1.0), false, true)
    _burst(at, 18, 1.5, Vector2(7.0, 15.0) * r, 60.0, -18.0, Vector2(0.18, 0.45) * r,
        [Color(0.35, 0.28, 0.2, 1.0), Color(0.25, 0.22, 0.2, 1.0)], _chunk(1.0))
    _burst(at, 30, 0.7, Vector2(10.0, 24.0) * r, 80.0, -9.0, Vector2(0.08, 0.16),
        [Color(1.0, 0.85, 0.4, 1.0), Color(1.0, 0.3, 0.1, 0.0)], _quad(1.0), true)
    _light(at + Vector3.UP * 2.0, Color(1.0, 0.6, 0.3), 14.0 * r, 26.0 * r, 0.55)
    if at.y - ground_y < 2.0:
        _scorch(Vector3(at.x, ground_y, at.z), 5.5 * r)


func _scorch(at: Vector3, size: float) -> void:
    if _scorch_tex == null:
        var g := Gradient.new()
        g.set_color(0, Color(0.06, 0.05, 0.05, 0.95))
        g.set_color(1, Color(0.1, 0.09, 0.08, 0.0))
        g.add_point(0.55, Color(0.1, 0.08, 0.07, 0.7))
        _scorch_tex = GradientTexture2D.new()
        _scorch_tex.gradient = g
        _scorch_tex.fill = GradientTexture2D.FILL_RADIAL
        _scorch_tex.fill_from = Vector2(0.5, 0.5)
        _scorch_tex.fill_to = Vector2(1.0, 0.5)
        _scorch_tex.width = 128
        _scorch_tex.height = 128
    var d := Decal.new()
    d.texture_albedo = _scorch_tex
    d.size = Vector3(size, 4.0, size)
    d.position = at
    d.rotation.y = randf() * TAU
    add_child(d)
    _keep(d, "scorch", 25.0)


func muzzle(at: Vector3, dir: Vector3) -> void:
    _ball(at + dir * 0.6, 1.1, Color(1.0, 0.8, 0.4), 0.14)
    _burst(at + dir * 0.8, 8, 1.2, Vector2(1.0, 3.0), 30.0, 0.8, Vector2(0.5, 0.9),
        [Color(0.6, 0.58, 0.55, 0.45), Color(0.7, 0.68, 0.65, 0.0)], _quad(1.0), false, true)
    _light(at, Color(1.0, 0.75, 0.4), 6.0, 12.0, 0.15)


## A machine-gun muzzle flash: a quick small glow and flicker of light.
func flash(at: Vector3, dir: Vector3) -> void:
    _ball(at + dir * 0.25, 0.35, Color(1.0, 0.85, 0.45), 0.06)
    _light(at, Color(1.0, 0.8, 0.45), 3.0, 8.0, 0.06)


## Small coloured puff (a monster rises, is hit, or a plasma shot fizzles).
func puff(at: Vector3, color: Color, size := 1.0) -> void:
    _burst(at, 12, 1.0, Vector2(1.0, 3.0) * size, 80.0, 0.5, Vector2(0.5, 0.9) * size,
        [Color(color, 0.8), Color(color, 0.0)], _quad(1.0), false, true)


func dirt(at: Vector3) -> void:
    _burst(at, 14, 1.2, Vector2(2.0, 5.0), 40.0, -12.0, Vector2(0.12, 0.3),
        [Color(0.36, 0.3, 0.22, 1.0), Color(0.3, 0.25, 0.2, 1.0)], _chunk(1.0))


## A pale green light column from a UFO to the ground for `life` seconds.
func beam(top: Vector3, bottom: Vector3, life: float) -> void:
    var mi := MeshInstance3D.new()
    var c := CylinderMesh.new()
    var h := top.y - bottom.y
    c.height = h
    c.top_radius = 1.2
    c.bottom_radius = 2.6
    c.radial_segments = 14
    c.cap_top = false
    c.cap_bottom = false
    mi.mesh = c
    var m := _glow(Color(0.6, 1.0, 0.75, 0.0), 2.5)
    mi.material_override = m
    mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    mi.position = (top + bottom) * 0.5
    add_child(mi)
    _keep(mi, "beam", life)
