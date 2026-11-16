extends Node3D
## The battle after the vehicle is found (free riding only). The world's battle_theme() says who
## is in it:
##   Skärgården  a tank with a cannon whose shells burst; zombies, Pysare and aliens, and a UFO
##               that beams down more aliens (eight hits bring it down)
##   Egypten     a pickup with a machine gun firing tracer bursts; mummies (four hits) and scarabs
##               that burst, and a giant pharaoh who rises by the great pyramid (sixty hits)
##   Japan       a running samurai who throws shuriken in fans of three; oni (three hits),
##               ninjas who throw stars back, fox spirits that burst in blue fire, and a dragon
##               that circles over the city breathing fire (twenty-five hits)
## The vehicle drives exactly like the bike (your watts make its speed, steering turns it). The gun
## aims where you look; a monster inside a narrow cone ahead is locked onto (red marker) and the
## gun lifts itself to reach it. Monsters keep coming, more as time goes on. Armour runs out from
## bites, plasma and blasts; then the vehicle is knocked out and a new one comes a few seconds later.
## Points per monster are in monster.gd (POINTS).

const Monster = preload("res://world/monster.gd")
const Effekter = preload("res://world/effekter.gd")
const Ljud = preload("res://world/ljud.gd")

const SHELL_SPEED := 75.0
const GRAVITY := 12.0
const BLAST := 7.5            # shell burst radius (metres)
const RELOAD := 0.85          # seconds between shots
const AIM_CONE := 0.42        # radians either side of where you look that the gun locks on
const UFO_HP := 8
const MG_SPEED := 260.0       # machine-gun bullets: fast and nearly flat
const MG_GRAVITY := 4.0
const MG_RELOAD := 0.09
const SHELL_DAMAGE := 10.0    # a shell burst; a bullet does 1
const STAR_SPEED := 48.0      # shuriken: thrown in a fan of three, spinning, with a gentle arc
const STAR_GRAVITY := 6.0
const STAR_RELOAD := 0.28

var world                     # the world (skargarden.gd)
var tank: Node3D
var armor := 100.0
var armor_max := 100.0        # 150 with the "Tjockare pansar" upgrade
var score := 0
var banked := 0               # points already handed to Progress (main.gd bank_battle)
# Upgrades from the garage (Progress.UPGRADES), read when the battle starts.
var _reload_mul := 1.0
var _aim_mul := 1.0
var _blast_mul := 1.0
var _damage_mul := 1.0
var kills := {}
var theme := {}               # the world's battle_theme()
var boss: Node3D = null       # a walking boss (the pharaoh) while it is about
var monsters: Array = []
var news: Array[String] = []  # lines for the HUD to show, oldest first
var target: Node3D = null     # what the gun is locked onto (a monster or the UFO)
var shake := 0.0              # camera shake, read by the world
var auto_fire := false        # developer screenshots: fire whenever the gun has a target
var ufo: Node3D = null
var ufo_hp := 0
var effects: Effekter
var ljud: Ljud

var _fri
var _torn: Node3D
var _kanon: Node3D
var _hull_yaw := 0.0
var _turret_yaw := 0.0        # turret angle relative to the hull
var _elevation := 0.05
var _recoil := 0.0
var _reload := 0.0
var _shells: Array = []       # [node, velocity, age]
var _plasma: Array = []       # [node, velocity, age]
var _pending: Array = []      # delayed bursts: [position, from player, radius, seconds left]
var _spawn_t := 4.0
var _elapsed := 0.0
var _ufo_t := 30.0            # seconds until the next UFO
var _ufo_angle := 0.0
var _ufo_fall := Vector3.ZERO
var _ufo_down := false
var _ufo_hum := false
var _beam_t := 6.0
var _knocked := 0.0           # seconds left until the new tank arrives
var _alarm := 2.0
var _marker: Label3D
var _smoke_t := 0.0
var _shell_mesh: SphereMesh
var _shell_mat: StandardMaterial3D
var _plasma_mat: StandardMaterial3D
var _tracer_mesh: BoxMesh
var _gun_rest := Vector3.ZERO
var _legs: Array = []          # a running vehicle's legs (the samurai)
var _stride := 0.0
var _star_mesh: Mesh
var _fire_mat: StandardMaterial3D
var _boss_t := 40.0           # seconds until the walking boss rises


func activate(fri) -> void:
    _fri = fri
    if Progress.upgrade_on("pansar"):
        armor_max = 150.0
    armor = armor_max
    _reload_mul = 0.7 if Progress.upgrade_on("laddning") else 1.0
    _aim_mul = 1.5 if Progress.upgrade_on("sikte") else 1.0
    if Progress.upgrade_on("sprang"):
        _blast_mul = 1.35
        _damage_mul = 1.3
    effects = Effekter.new()
    add_child(effects)
    ljud = Ljud.new()
    add_child(ljud)
    theme = world.battle_theme()
    for e in theme["monsters"]:
        kills[e[0]] = 0
    kills[theme["boss"]] = 0
    tank = world._scene(theme["vehicle"])      # the painted model when there is one
    add_child(tank)
    _torn = tank.find_child(theme["turret"], true, false)
    _kanon = tank.find_child(theme["gun"], true, false)
    _kanon.reparent(_torn)
    _gun_rest = _kanon.position
    for leg in ["BenV", "BenH"]:
        var node := tank.find_child(leg, true, false)
        if node:
            _legs.append(node)
    if theme.get("weapon", "") == "shuriken":
        _star_mesh = world._model_mesh("shuriken")
    _fire_mat = _glow_mat(Color(1.0, 0.55, 0.2), 5.0)
    _marker = Label3D.new()
    _marker.text = "▼"
    _marker.font_size = 96
    _marker.outline_size = 12
    _marker.modulate = Color("ff4d3d")
    _marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    _marker.no_depth_test = true
    _marker.fixed_size = true
    _marker.pixel_size = 0.0006
    _marker.visible = false
    add_child(_marker)
    _shell_mesh = SphereMesh.new()
    _shell_mesh.radius = 0.2
    _shell_mesh.height = 0.4
    _shell_mesh.radial_segments = 8
    _shell_mesh.rings = 4
    _shell_mat = _glow_mat(Color(1.0, 0.75, 0.35), 3.0)
    _plasma_mat = _glow_mat(Color(0.5, 1.0, 0.6), 5.0)
    _tracer_mesh = BoxMesh.new()
    _tracer_mesh.size = Vector3(1.8, 0.07, 0.07)
    _tracer_mesh.material = _glow_mat(Color(1.0, 0.85, 0.4), 6.0)
    place_tank(fri, 0.0)
    news.append(theme["found"])


func title() -> String:
    return theme.get("title", tr("STRIDSVAGN"))


## "Mumier 3 · Skarabéer 1 · Farao 0" for the HUD.
func kill_line() -> String:
    var parts: Array[String] = []
    for kind in kills:
        if kind == theme["boss"] and kills[kind] == 0:
            continue
        parts.append("%s %d" % [theme["names"].get(kind, kind), kills[kind]])
    return " · ".join(parts)


func _kanon_weapon() -> bool:
    return theme.get("weapon", "kanon") == "kanon"


func _speed() -> float:
    return {"kanon": SHELL_SPEED, "kulspruta": MG_SPEED, "shuriken": STAR_SPEED}.get(theme.get("weapon", "kanon"), SHELL_SPEED)


func _gravity() -> float:
    return {"kanon": GRAVITY, "kulspruta": MG_GRAVITY, "shuriken": STAR_GRAVITY}.get(theme.get("weapon", "kanon"), GRAVITY)


func _glow_mat(c: Color, energy: float) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    m.albedo_color = c
    m.emission_enabled = true
    m.emission = c
    m.emission_energy_multiplier = energy
    return m


func knocked_out() -> bool:
    return _knocked > 0.0


func alive_count() -> int:
    var n := 0
    for m in monsters:
        if is_instance_valid(m) and not m.dead:
            n += 1
    return n


## Put the tank where the free ride is: tilted with the ground, turret and gun aimed.
func place_tank(fri, delta: float) -> void:
    tank.position = fri.pos
    _hull_yaw = atan2(-fri.heading.y, fri.heading.x)
    tank.rotation = Vector3(fri.roll, _hull_yaw, atan(fri.slope))
    var want := _aim_yaw() - _hull_yaw
    var diff := wrapf(want - _turret_yaw, -PI, PI)
    _turret_yaw += clampf(diff, -2.6 * delta, 2.6 * delta) if delta > 0.0 else diff
    _torn.rotation.y = _turret_yaw
    _kanon.rotation.z = clampf(_elevation - atan(fri.slope) * cos(_turret_yaw), -0.12, 0.7)
    _recoil = move_toward(_recoil, 0.0, delta * 1.6)
    _kanon.position = _gun_rest - Vector3(_recoil, 0.0, 0.0)
    if not _legs.is_empty():
        # A running stride from the speed: legs swing, the body bobs.
        _stride += delta * (2.0 + Ride.speed * 0.9)
        var swing := sin(_stride) * clampf(Ride.speed / 4.0, 0.0, 1.0) * 0.7
        (_legs[0] as Node3D).rotation.z = swing
        if _legs.size() > 1:
            (_legs[1] as Node3D).rotation.z = -swing
        tank.position.y += absf(sin(_stride)) * 0.08 * clampf(Ride.speed / 4.0, 0.0, 1.0)


## World yaw the turret should point: at the locked target, else where the camera looks.
func _aim_yaw() -> float:
    if target and is_instance_valid(target):
        var v: Vector3 = _target_point(target) - tank.position
        return atan2(-v.z, v.x)
    return _hull_yaw + float(world.orbit)


func _target_point(node: Node3D) -> Vector3:
    return node.centre() if node.has_method("centre") else node.position


func _process(delta: float) -> void:
    if tank == null:
        return
    _elapsed += delta
    _reload -= delta
    shake = maxf(shake - delta * 1.5, 0.0)
    if _alarm > 0.0:
        _alarm -= delta
        if _alarm <= 0.0:
            ljud.play(theme.get("alarm_sound", "larm"))
            news.append(theme["alarm"] % fire_keys())
    if _knocked > 0.0:
        _knocked -= delta
        if _knocked <= 0.0:
            armor = armor_max
            tank.visible = true
            effects.puff(tank.position + Vector3.UP * 1.5, Color(0.9, 0.9, 0.85), 2.0)
            news.append(theme["new"])
    elif Input.is_action_pressed("skjut") or (auto_fire and target != null):
        fire()
    _choose_target()
    _update_shells(delta)
    _update_plasma(delta)
    _update_pending(delta)
    _update_monsters(delta)
    _spawn(delta)
    if theme["boss"] in ["ufo", "drake"]:
        _update_ufo(delta)          # flying bosses
    else:
        _update_walking_boss(delta)
    if armor < armor_max * 0.4 and _knocked <= 0.0:
        _smoke_t -= delta
        if _smoke_t <= 0.0:
            _smoke_t = 0.35
            effects.puff(tank.position + Vector3.UP * 2.0 - Vector3(_fri.heading.x, 0, _fri.heading.y) * 2.4,
                Color(0.2, 0.2, 0.2), 0.9)


## "F eller upp på vänstra Clicken": the key and the first Click button bound to shooting.
func fire_keys() -> String:
    for b in Controls.BUTTONS:
        if Controls.binding(b[0]) == "skjut":
            var parts := (b[1] as String).split(": ")
            return tr("F eller %s på %s Clicken") % [parts[1], tr("vänstra") if parts[0].begins_with(tr("Vänster")) else tr("högra")]
    return "F"


# --- The gun --------------------------------------------------------------------------------------

func _choose_target() -> void:
    var look := _hull_yaw + float(world.orbit)
    var best: Node3D = null
    var best_score := INF
    var candidates: Array = monsters.duplicate()
    if ufo and not _ufo_down:
        candidates.append(ufo)
    for m in candidates:
        if not is_instance_valid(m) or (m.has_method("centre") and (m.dead or m.state == "appear")):
            continue
        var v: Vector3 = _target_point(m) - tank.position
        var d := Vector2(v.x, v.z).length()
        if d < 4.0 or d > (230.0 if m == ufo else 170.0):
            continue
        var off := absf(wrapf(atan2(-v.z, v.x) - look, -PI, PI))
        if off > AIM_CONE * _aim_mul:
            continue
        var s := off * 80.0 + d * 0.25
        if s < best_score:
            best_score = s
            best = m
    target = best
    if target:
        var muzzle := _muzzle()
        var aim := _target_point(target)
        var flight := muzzle.distance_to(aim) / _speed()
        if target.has_method("centre"):
            aim += (target.velocity as Vector3) * flight
        elif target == ufo:
            aim += _ufo_velocity() * flight
        _elevation = _solve(muzzle, aim)
        _marker.visible = true
        _marker.position = _target_point(target) + Vector3.UP * (9.0 if target == ufo else 1.4 + 0.6 * target.scale.x)
    else:
        _elevation = 0.05
        _marker.visible = false


## Elevation (radians) that lands a shell from `from` on `to` on the flat trajectory.
func _solve(from: Vector3, to: Vector3) -> float:
    var d := Vector2(to.x - from.x, to.z - from.z).length()
    var dy := to.y - from.y
    var g := _gravity()
    var v2 := _speed() * _speed()
    var disc := v2 * v2 - g * (g * d * d + 2.0 * dy * v2)
    if disc < 0.0:
        return 0.7
    return atan((v2 - sqrt(disc)) / (g * maxf(d, 0.1)))


func _muzzle() -> Vector3:
    return _kanon.global_transform * Vector3(float(theme.get("muzzle", 4.15)), 0.0, 0.0)


func fire() -> bool:
    if _reload > 0.0 or _knocked > 0.0 or tank == null:
        return false
    var basis := _kanon.global_transform.basis
    var dir := basis.x.normalized()
    var at := _muzzle()
    if theme.get("weapon", "") == "shuriken":
        # Three stars in a fan, spinning, one point of damage each.
        _reload = STAR_RELOAD * _reload_mul
        for k in 3:
            var star := MeshInstance3D.new()
            star.mesh = _star_mesh
            star.scale = Vector3.ONE * 2.2
            star.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
            star.position = at
            add_child(star)
            var fan := dir.rotated(Vector3.UP, (k - 1) * 0.07)
            _shells.append([star, fan * STAR_SPEED, 0.0, "stjarna"])
        ljud.play("kast", at, 0.0)
        _recoil = 0.25
        return true
    if not _kanon_weapon():
        # A machine-gun round: a glowing tracer, nearly flat, one point of damage.
        _reload = MG_RELOAD * _reload_mul
        var tracer := MeshInstance3D.new()
        tracer.mesh = _tracer_mesh
        tracer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        tracer.position = at
        tracer.basis = basis
        add_child(tracer)
        var spread := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * 0.012
        _shells.append([tracer, (dir + spread).normalized() * MG_SPEED, 0.0, "kula"])
        effects.flash(at, dir)
        ljud.play("mg", at, 0.0)
        _recoil = 0.06
        shake = maxf(shake, 0.06)
        return true
    _reload = RELOAD * _reload_mul
    var shell := MeshInstance3D.new()
    shell.mesh = _shell_mesh
    shell.material_override = _shell_mat
    shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    shell.position = at
    add_child(shell)
    _shells.append([shell, dir * SHELL_SPEED, 0.0, "granat"])
    effects.muzzle(at, dir)
    ljud.play("kanon", at, 4.0)
    _recoil = 0.45
    shake = maxf(shake, 0.35)
    return true


func _update_shells(delta: float) -> void:
    for k in range(_shells.size() - 1, -1, -1):
        var s: Array = _shells[k]
        if s[3] == "kula" or s[3] == "stjarna":
            if _update_bullet(s, delta):
                (s[0] as Node3D).queue_free()
                _shells.remove_at(k)
            continue
        var node: Node3D = s[0]
        var v: Vector3 = s[1]
        v.y -= GRAVITY * delta
        s[1] = v
        s[2] += delta
        var p := node.position + v * delta
        node.position = p
        var hit: bool = s[2] > 6.0
        var ground: float = world.height(p.x, p.z)
        if p.y <= maxf(ground, 0.0):
            p.y = maxf(ground, 0.0) + 0.2
            hit = true
        for m in monsters:
            if is_instance_valid(m) and not m.dead and m.state != "appear" and p.distance_to(m.centre()) < 0.6 + 0.9 * m.scale.x:
                hit = true
        if ufo and not _ufo_down and p.distance_to(ufo.position) < 7.0:
            _hit_ufo(p)
            effects.explosion(p, 4.0, -100.0)
            node.queue_free()
            _shells.remove_at(k)
            continue
        if hit:
            explode(p, true, BLAST * _blast_mul)
            node.queue_free()
            _shells.remove_at(k)


## A burst at `at`: knocks over monsters (and trees) within `radius`. A Pysare's own blast
## (from_player false) also dents the tank if it is close. `delay` holds it back a moment, so a
## chain of Pysare goes off one after another.
func explode(at: Vector3, from_player: bool, radius: float, delay := 0.0) -> void:
    if delay > 0.0:
        _pending.append([at, from_player, radius, delay])
        return
    var ground: float = world.height(at.x, at.z)
    effects.explosion(at, radius, maxf(ground, 0.0))
    ljud.play("small", at, 6.0)
    var near: float = tank.position.distance_to(at)
    shake = maxf(shake, clampf(1.2 - near / 60.0, 0.0, 1.0))
    for m in monsters:
        if not is_instance_valid(m) or m.dead or m.state == "appear":
            continue
        if m.position.distance_to(at) < radius + (m.scale.x - 1.0):
            if m.damage(SHELL_DAMAGE * (_damage_mul if from_player else 1.0), at):
                _score(m)
    if not from_player and near < radius + 1.5 and _knocked <= 0.0:
        hurt(24.0 * (1.0 - near / (radius + 1.5)) + 6.0, "pysare")
    world.knock_trees(at.x, at.z, radius * 0.55, Vector2.ZERO)


func _update_pending(delta: float) -> void:
    for k in range(_pending.size() - 1, -1, -1):
        _pending[k][3] -= delta
        if _pending[k][3] <= 0.0:
            var p: Array = _pending[k]
            _pending.remove_at(k)
            explode(p[0], p[1], p[2])


func _score(m) -> void:
    score += Monster.POINTS.get(m.kind, 10)
    kills[m.kind] = kills.get(m.kind, 0) + 1
    if m == boss:
        news.append(theme["boss_down"])


## A bullet in flight: true when it is done (hit something, or spent). Hits are tested along the
## stretch it flew this frame, so a fast bullet cannot skip through a monster.
func _update_bullet(s: Array, delta: float) -> bool:
    var node: Node3D = s[0]
    var v: Vector3 = s[1]
    v.y -= (STAR_GRAVITY if s[3] == "stjarna" else MG_GRAVITY) * delta
    s[1] = v
    s[2] += delta
    var a := node.position
    var b := a + v * delta
    node.position = b
    if s[3] == "stjarna":
        node.rotation.y += delta * 30.0
    if ufo and not _ufo_down and b.distance_to(ufo.position) < 6.5:
        effects.puff(b, Color(1.0, 0.8, 0.4), 1.0)
        _hit_ufo(b)
        return true
    for m in monsters:
        if not is_instance_valid(m) or m.dead or m.state == "appear":
            continue
        var c: Vector3 = m.centre()
        var reach: float = 0.9 * m.scale.x
        var ab := b - a
        var t := clampf((c - a).dot(ab) / maxf(ab.length_squared(), 1e-4), 0.0, 1.0)
        if (a + ab * t).distance_to(c) < reach:
            var at := a + ab * t
            effects.puff(at, Monster.COLOUR.get(m.kind, Color.WHITE), 0.35)
            if m.damage(_damage_mul, at):
                _score(m)
            return true
    var ground: float = world.height(b.x, b.z)
    if b.y <= maxf(ground, 0.0):
        effects.puff(Vector3(b.x, maxf(ground, 0.0) + 0.1, b.z), Color(0.85, 0.72, 0.5), 0.3)
        return true
    return s[2] > (3.0 if s[3] == "stjarna" else 1.6)


# --- Monsters -------------------------------------------------------------------------------------

func _update_monsters(delta: float) -> void:
    var speed: float = 0.0 if _knocked > 0.0 else Ride.speed
    for k in range(monsters.size() - 1, -1, -1):
        var m = monsters[k]
        if not is_instance_valid(m):
            monsters.remove_at(k)
            continue
        if not m.dead and m.position.distance_to(tank.position) > 240.0:
            m.queue_free()
            monsters.remove_at(k)
            continue
        m.think(delta, tank.position, speed)


func _spawn(delta: float) -> void:
    _spawn_t -= delta
    if _spawn_t > 0.0 or _knocked > 0.0:
        return
    _spawn_t = 2.2
    var want := mini(6 + int(_elapsed / 30.0), 16)
    if alive_count() >= want:
        return
    var roll := randf()
    var kind: String = theme["monsters"][0][0]
    for e in theme["monsters"]:
        roll -= float(e[1])
        if roll <= 0.0:
            kind = e[0]
            break
    var at := _spawn_point(45.0, 110.0)
    if at == Vector3.INF:
        return
    spawn(kind, at)


## A random free spot on land between `near` and `far` metres from the tank, mostly ahead.
func _spawn_point(near: float, far: float) -> Vector3:
    for attempt in 12:
        var off := randf_range(-1.8, 1.8) if randf() < 0.75 else randf_range(-PI, PI)
        var dir := Vector2(_fri.heading).rotated(off)
        var p := Vector2(_fri.pos.x, _fri.pos.z) + dir * randf_range(near, far)
        if world.free_at(p.x, p.y, 0.6) and world.ride_height(p.x, p.y) > 0.6:
            return Vector3(p.x, world.ride_height(p.x, p.y), p.y)
    return Vector3.INF


func spawn(kind: String, at: Vector3) -> Node3D:
    var m := Monster.new()
    m.strid = self
    add_child(m)
    m.setup(kind, at)
    monsters.append(m)
    match kind:
        "zombie", "mumie":
            effects.dirt(at)
        "pysare", "skarabe":
            effects.puff(at + Vector3.UP * 0.5, Monster.COLOUR[kind], 1.2)
        "alien":
            effects.beam(at + Vector3.UP * 26.0, at, 1.6)
        "farao":
            for k in 6:
                effects.dirt(at + Vector3(randf_range(-4, 4), 0, randf_range(-4, 4)))
            effects.puff(at + Vector3.UP * 2.0, Color(0.85, 0.72, 0.5), 4.0)
    return m


## Armour damage from a bite, a plasma shot or a blast.
func hurt(amount: float, _by: String) -> void:
    if _knocked > 0.0:
        return
    armor -= amount
    if armor <= 0.0:
        armor = 0.0
        _knocked = 4.0
        tank.visible = false
        effects.explosion(tank.position + Vector3.UP * 1.5, 12.0, tank.position.y)
        ljud.play("small", tank.position, 10.0)
        shake = 1.5
        for m in monsters:
            if is_instance_valid(m) and not m.dead and m.position.distance_to(tank.position) < 16.0:
                m.damage(SHELL_DAMAGE, tank.position)
        news.append(theme["knocked"])


func crush(m) -> void:
    _score(m)
    m.flatten()
    effects.puff(m.position + Vector3.UP * 0.3, Monster.COLOUR.get(m.kind, Color.WHITE), 1.0)
    news.append(tr("Överkörd! +%d") % Monster.POINTS.get(m.kind, 10))


## The boss stamps the ground: the vehicle takes a knock when it is close.
func stomp(m) -> void:
    for k in 5:
        effects.dirt(m.position + Vector3(randf_range(-3, 3), 0.0, randf_range(-3, 3)))
    ljud.play("small", m.position, 2.0)
    var near: float = Vector2(tank.position.x - m.position.x, tank.position.z - m.position.z).length()
    shake = maxf(shake, clampf(1.0 - near / 40.0, 0.2, 1.0))
    if near < 10.0:
        hurt(14.0, m.kind)


## The boss calls up mummies round about.
func summon(m) -> void:
    if alive_count() > 18:
        return
    for k in 3:
        var a := randf() * TAU
        var p := Vector2(m.position.x, m.position.z) + Vector2(cos(a), sin(a)) * randf_range(7.0, 13.0)
        if world.free_at(p.x, p.y, 0.6) and world.ride_height(p.x, p.y) > 0.6:
            spawn("mumie", Vector3(p.x, world.ride_height(p.x, p.y), p.y))


func boss_fell(m) -> void:
    effects.explosion(m.position + Vector3.UP * 3.0, 12.0, m.position.y)
    for k in 8:
        effects.puff(m.position + Vector3(randf_range(-5, 5), randf_range(1, 8), randf_range(-5, 5)), Color(0.85, 0.72, 0.5), 3.0)
    ljud.play("small", m.position, 10.0)
    shake = maxf(shake, 1.0)


func hiss(m) -> void:
    ljud.play("pys", m.position, 2.0)


func alien_shoot(m) -> void:
    _enemy_shot((m.centre() as Vector3) + Vector3.UP * 0.2, m.kind)


## A shot at the vehicle: green plasma from an alien, a dark star from a ninja, fire from the dragon.
func _enemy_shot(from: Vector3, kind: String) -> void:
    var aim := tank.position + Vector3.UP * 1.4
    var dir := (aim - from).normalized()
    var ball := MeshInstance3D.new()
    var s := SphereMesh.new()
    s.radius = 0.35 if kind != "drake" else 0.9
    s.height = s.radius * 2.0
    s.radial_segments = 8
    s.rings = 4
    ball.mesh = s
    ball.material_override = _fire_mat if kind == "drake" else _plasma_mat
    if kind == "ninja" and _star_mesh:
        ball.mesh = _star_mesh
        ball.scale = Vector3.ONE * 2.0
        ball.material_override = null
    ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    ball.position = from
    add_child(ball)
    _plasma.append([ball, dir * (26.0 if kind == "ninja" else 22.0), 0.0])
    ljud.play("kast" if kind == "ninja" else "plasma", from)


func _update_plasma(delta: float) -> void:
    for k in range(_plasma.size() - 1, -1, -1):
        var s: Array = _plasma[k]
        var node: Node3D = s[0]
        s[2] += delta
        node.position += (s[1] as Vector3) * delta
        node.rotation.y += delta * 20.0
        var p := node.position
        var gone: bool = s[2] > 4.0 or p.y < world.height(p.x, p.z)
        if _knocked <= 0.0 and p.distance_to(tank.position + Vector3.UP * 1.4) < 2.6:
            hurt(7.0, "alien")
            ljud.play("traff", p, 2.0)
            gone = true
        if gone:
            effects.puff(p, Color(0.5, 1.0, 0.6), 0.6)
            node.queue_free()
            _plasma.remove_at(k)


# --- The UFO --------------------------------------------------------------------------------------

func _update_ufo(delta: float) -> void:
    if ufo == null:
        _ufo_t -= delta
        if _ufo_t <= 0.0:
            ufo = world._scene(theme["boss"])      # the painted model when there is one
            add_child(ufo)
            ufo_hp = int(theme.get("boss_hp", UFO_HP))
            _ufo_down = false
            _ufo_hum = false
            _ufo_angle = randf() * TAU
            ufo.position = tank.position + Vector3(cos(_ufo_angle), 0, sin(_ufo_angle)) * 260.0 + Vector3.UP * 60.0
            news.append(theme["boss_in"])
        return
    if not _ufo_hum and theme["boss"] == "ufo":
        _ufo_hum = ljud.attach_loop("hum", ufo, 4.0)
    if _ufo_down:
        _ufo_fall.y -= 14.0 * delta
        ufo.position += _ufo_fall * delta
        ufo.rotation += Vector3(1.4, 2.0, 0.9) * delta
        if _elapsed - floorf(_elapsed / 0.15) * 0.15 < delta:
            effects.puff(ufo.position, Color(0.2, 0.2, 0.22), 2.2)
        var ground: float = maxf(world.height(ufo.position.x, ufo.position.z), 0.0)
        if ufo.position.y < ground + 1.0:
            explode(Vector3(ufo.position.x, ground + 0.5, ufo.position.z), true, 14.0)
            ufo.queue_free()
            ufo = null
            _ufo_t = 90.0
        return
    # Circle the tank at 75 m, 38 m up, drifting in from afar.
    _ufo_angle += delta * 0.12
    var flyer_r := 75.0 if theme["boss"] == "ufo" else 55.0
    var want := tank.position + Vector3(cos(_ufo_angle), 0, sin(_ufo_angle)) * flyer_r
    want.y = maxf(world.height(want.x, want.z), 0.0) + (38.0 if theme["boss"] == "ufo" else 16.0)
    ufo.position = ufo.position.lerp(want, clampf(delta * 0.35, 0.0, 1.0))
    if theme["boss"] != "ufo":
        # The dragon flies head first round its circle, rolling into the turn and weaving, and
        # breathes fire at you every few seconds.
        var v := _ufo_velocity()
        ufo.rotation = Vector3(sin(_elapsed * 1.3) * 0.15, atan2(-v.z, v.x), sin(_elapsed * 0.9) * 0.12 - 0.25)
        _beam_t -= delta
        if _beam_t <= 0.0:
            _beam_t = 3.5
            var head: Vector3 = ufo.global_transform * Vector3(14.0, 0.0, 0.0)
            _enemy_shot(head, "drake")
        return
    ufo.rotation.y += delta * 0.8
    ufo.rotation.z = sin(_elapsed * 0.7) * 0.05
    _beam_t -= delta
    if _beam_t <= 0.0:
        _beam_t = 9.0
        var below := Vector2(ufo.position.x, ufo.position.z)
        if world.free_at(below.x, below.y, 0.6) and world.ride_height(below.x, below.y) > 0.6 and alive_count() < 18:
            var ground_pt := Vector3(below.x, world.ride_height(below.x, below.y), below.y)
            effects.beam(ufo.position - Vector3.UP * 1.8, ground_pt, 1.8)
            var m := Monster.new()
            m.strid = self
            add_child(m)
            m.setup("alien", ground_pt)
            monsters.append(m)


func _ufo_velocity() -> Vector3:
    return Vector3(-sin(_ufo_angle), 0, cos(_ufo_angle)) * 75.0 * 0.12


func _hit_ufo(at: Vector3) -> void:
    ufo_hp -= 1
    ljud.play("traff", at, 6.0)
    if ufo_hp <= 0:
        _ufo_down = true
        _ufo_fall = _ufo_velocity() + Vector3.UP * 4.0
        score += 500
        kills[theme["boss"]] = kills.get(theme["boss"], 0) + 1
        news.append(theme["boss_down"])


# --- A walking boss (the pharaoh) ----------------------------------------------------------------

## The boss rises where the world says (by the great pyramid) when that is near enough, otherwise
## ahead of the vehicle; it walks at you, stamps when close and calls up mummies (monster.gd).
func _update_walking_boss(delta: float) -> void:
    if boss != null and is_instance_valid(boss) and not boss.dead:
        return
    if boss != null:
        boss = null
        _boss_t = 90.0
    _boss_t -= delta
    if _boss_t > 0.0 or _knocked > 0.0:
        return
    var at: Vector3 = world.boss_spawn()
    if at.distance_to(tank.position) > 260.0:
        at = _spawn_point(70.0, 110.0)
        if at == Vector3.INF:
            return
    boss = spawn(theme["boss"], at)
    news.append(theme["boss_in"])
