extends Node3D
## One monster of the battle (see strid.gd):
##   zombie  rises out of the ground and shambles at the tank; bites when it gets there, and is
##           flattened if the tank runs it over
##   alien   is beamed down from the UFO, hovers on its disc, keeps its distance, circles and
##           fires slow green plasma shots
##   pysare  pops up and hops at the tank; close by it stops, swells, flashes and hisses, then goes
##           off (a shell sets it off at once, which can take its neighbours with it)
##   mumie   (Egypten) shambles like the zombie, but takes four machine-gun hits
##   skarabe (Egypten) scuttles up and bursts like the Pysare
##   farao   (Egypten) the boss: a giant mummy king who rises from the sand, walks at you, stamps
##           when close and calls up mummies round him; sixty hits
##   oni     (Japan) a big red ogre with an iron club who stomps at you; three hits
##   ninja   (Japan) keeps its distance, circles and throws stars back; two hits
##   kitsune (Japan) a fox spirit that dashes up and bursts in blue fire
## Models: zombie, alien, mumie and farao in jointed parts, pysare and skarabe in one piece, loaded
## through the world (so painted models and each world's folder are used). Front is +X.

const MODELS := {
    "zombie": preload("res://world/skargarden/models/zombie.glb"),
    "alien": preload("res://world/skargarden/models/alien.glb"),
    "pysare": preload("res://world/skargarden/models/pysare.glb"),
}
## The TextureCraft-painted model (assets/texturer/<kind>) when it has been built, else the flat one.
static func model(name: String) -> PackedScene:
    var tex := "res://world/skargarden/models/%s_tex.glb" % name
    return load(tex) if ResourceLoader.exists(tex) else MODELS[name]


## How each kind behaves: shamble (walk up and bite), hover, fuse (rush up and burst), boss.
const ROLE := {"zombie": "shamble", "mumie": "shamble", "alien": "hover", "pysare": "fuse", "skarabe": "fuse",
    "farao": "boss", "oni": "shamble", "ninja": "ranged", "kitsune": "fuse"}
const SPEED := {"zombie": 1.5, "alien": 2.8, "pysare": 3.6, "mumie": 1.4, "skarabe": 4.2, "farao": 1.3, "oni": 1.7,
    "ninja": 3.4, "kitsune": 4.6}
const POINTS := {"zombie": 10, "alien": 25, "pysare": 15, "mumie": 10, "skarabe": 15, "farao": 500, "oni": 15,
    "ninja": 25, "kitsune": 15}
const SIZE := {"zombie": 1.35, "alien": 1.5, "pysare": 1.5, "mumie": 1.35, "skarabe": 1.4, "farao": 4.5, "oni": 1.5,
    "ninja": 1.3, "kitsune": 1.4}
const HP := {"zombie": 1.0, "alien": 1.0, "pysare": 1.0, "mumie": 4.0, "skarabe": 1.0, "farao": 60.0, "oni": 3.0,
    "ninja": 2.0, "kitsune": 1.0}
const CENTRE := {"zombie": 1.0, "alien": 1.7, "pysare": 0.6, "mumie": 1.0, "skarabe": 0.35, "farao": 1.1, "oni": 1.1,
    "ninja": 1.0, "kitsune": 0.5}
const COLOUR := {"zombie": Color("93b07a"), "alien": Color("a5dcae"), "pysare": Color("82bf55"),
    "mumie": Color("d9c9a3"), "skarabe": Color("2f8f8a"), "farao": Color("e0b043"), "oni": Color("c83a2a"),
    "ninja": Color("3a3a4a"), "kitsune": Color("6fd0ff")}

var kind := "zombie"
var role := "shamble"
var hp := 1.0
var _summon_t := 6.0            # the boss calls up mummies now and then
var strid                       # the battle (strid.gd)
var dead := false
var state := "appear"           # appear, chase, fuse, dead
var velocity := Vector3.ZERO    # metres per second (for aiming ahead and flying when hit)
var t := 0.0                    # seconds in the current state
var _parts := {}
var _body: Node3D
var _phase := 0.0
var _shot_t := 3.0
var _circle := 1.0              # which way an alien circles
var _spin := Vector3.ZERO
var _flash: MeshInstance3D      # the Pysare's white flash while its fuse burns
var _ground := 0.0


func setup(what: String, at: Vector3) -> void:
    kind = what
    role = ROLE.get(kind, "shamble")
    hp = HP.get(kind, 1.0)
    _phase = randf() * TAU
    _circle = -1.0 if randf() < 0.5 else 1.0
    _shot_t = randf_range(2.0, 4.0)
    _body = strid.world._scene(kind) if strid and strid.world else model(kind).instantiate()
    add_child(_body)
    scale = Vector3.ONE * SIZE[kind]       # a little larger than life, so they read from the tank
    for name in ["Kropp", "ArmV", "ArmH", "BenV", "BenH", "Skiva"]:
        var node := _body.find_child(name, true, false)
        if node:
            _parts[name] = node
    position = at
    _ground = at.y
    if role == "fuse":
        _flash = MeshInstance3D.new()
        var s := SphereMesh.new()
        var small := kind == "skarabe"
        s.radius = 0.5 if small else 0.62
        s.height = 0.6 if small else 1.15
        s.radial_segments = 10
        s.rings = 5
        _flash.mesh = s
        var m := StandardMaterial3D.new()
        m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        m.albedo_color = Color(1, 1, 1, 0.0)
        _flash.material_override = m
        _flash.position = Vector3(0, 0.35 if small else 0.62, 0)
        _flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        add_child(_flash)
    _pose_appear(0.0)


## Where to aim: the middle of the body.
func centre() -> Vector3:
    return position + Vector3.UP * float(CENTRE.get(kind, 1.0)) * scale.x


func think(delta: float, tank: Vector3, tank_speed: float) -> void:
    t += delta
    match state:
        "appear":
            _pose_appear(t)
            if t > {"shamble": 1.6, "hover": 1.4, "fuse": 0.45, "boss": 3.0, "ranged": 0.45}[role]:
                _enter("chase")
        "chase":
            _chase(delta, tank, tank_speed)
        "fuse":
            var k := clampf(t / 1.3, 0.0, 1.0)
            _body.scale = Vector3.ONE * (1.0 + 0.35 * k)
            (_flash.material_override as StandardMaterial3D).albedo_color.a = 0.75 * k * (0.5 + 0.5 * sin(t * (12.0 + 30.0 * k)))
            _flash.scale = _body.scale
            if t >= 1.3:
                strid.explode(position + Vector3.UP * 0.6, false, 6.5)
                _vanish()
        "dead":
            velocity.y -= 18.0 * delta
            position += velocity * delta
            rotation += _spin * delta
            var floor_y: float = strid.world.ride_height(position.x, position.z)
            if position.y < floor_y:
                position.y = floor_y
                velocity = velocity * 0.3
                _spin *= 0.5
            if t > 1.8:
                position.y -= delta * 1.2
            if t > 3.2:
                queue_free()


func _enter(s: String) -> void:
    state = s
    t = 0.0


## Rising out of the ground (zombie, mummy, pharaoh), lowered in a beam (alien) or popping up.
func _pose_appear(time: float) -> void:
    match role:
        "shamble":
            _body.position.y = lerpf(-1.9, 0.0, clampf(time / 1.6, 0.0, 1.0))
            _body.rotation.x = sin(time * 9.0) * 0.12 * (1.0 - clampf(time / 1.6, 0.0, 1.0))
        "boss":
            _body.position.y = lerpf(-2.1, 0.0, smoothstep(0.0, 3.0, time))
            _body.rotation.x = sin(time * 5.0) * 0.06 * (1.0 - clampf(time / 3.0, 0.0, 1.0))
        "hover":
            _body.position.y = lerpf(12.0, 0.6, smoothstep(0.0, 1.4, time))
        "fuse", "ranged":
            _body.scale = Vector3.ONE * clampf(time / 0.45, 0.05, 1.0)


func _chase(delta: float, tank: Vector3, tank_speed: float) -> void:
    var to := Vector2(tank.x - position.x, tank.z - position.z)
    var d := to.length()
    var dir := to / maxf(d, 0.01)
    var move := Vector2.ZERO
    var speed: float = SPEED[kind]
    match role:
        "shamble":
            if d < 2.6 and tank_speed > 2.0:
                strid.crush(self)
                return
            if d > 2.4:
                move = dir * speed * (1.0 if d < 90.0 else 0.4)
            else:
                strid.hurt(5.0 * delta, kind)
        "boss":
            # Walk at the vehicle; stamp when close; call up mummies round about now and then.
            _shot_t -= delta
            _summon_t -= delta
            if d > 7.0:
                move = dir * speed
            elif _shot_t <= 0.0:
                _shot_t = 2.5
                strid.stomp(self)
            if _summon_t <= 0.0:
                _summon_t = 9.0
                strid.summon(self)
        "hover", "ranged":
            var side := Vector2(-dir.y, dir.x) * _circle
            if d > 34.0:
                move = dir * speed
            elif d < 18.0:
                move = -dir * speed * 0.8 + side * speed * 0.5
            else:
                move = side * speed * 0.8
            _shot_t -= delta
            if _shot_t <= 0.0 and d < 65.0:
                _shot_t = randf_range(2.6, 4.2)
                strid.alien_shoot(self)
        "fuse":
            if d < 5.5:
                _enter("fuse")
                velocity = Vector3.ZERO
                strid.hiss(self)
                return
            if d < 110.0:
                move = dir * speed
    var next := Vector2(position.x, position.z) + move * delta
    var ground: float = strid.world.ride_height(next.x, next.y)
    if ground > 0.25:
        position.x = next.x
        position.z = next.y
        _ground = ground
    velocity = Vector3(move.x, 0.0, move.y)
    if d > 0.5:
        rotation.y = lerp_angle(rotation.y, atan2(-dir.y, dir.x), clampf(delta * 5.0, 0.0, 1.0))
    _animate(delta, move.length())


func _animate(delta: float, speed: float) -> void:
    var now := t + _phase
    match role:
        "shamble", "boss", "ranged":
            position.y = _ground
            var pace: float = {"shamble": 4.2, "boss": 2.0, "ranged": 7.0}[role]
            var swing := sin(now * pace) * 0.45 * clampf(speed, 0.0, 1.0)
            if _parts.has("BenV"):
                _parts["BenV"].rotation.z = swing
                _parts["BenH"].rotation.z = -swing
                _parts["ArmV"].rotation.z = 0.08 * sin(now * 4.2 + 0.6) - 0.05
                _parts["ArmH"].rotation.z = 0.08 * sin(now * 4.2 + 2.2) - 0.05
            _body.rotation.x = sin(now * 2.1) * 0.08
        "hover":
            position.y = _ground
            _body.position.y = 0.6 + sin(now * 2.4) * 0.15
            if _parts.has("Skiva"):
                _parts["Skiva"].rotation.y += delta * 4.0
            _body.rotation.z = -0.12 * clampf(speed / 3.0, 0.0, 1.0)
        "fuse":
            var hop := absf(sin(now * (6.0 if kind == "pysare" else 11.0))) * (1.0 if kind == "pysare" else 0.3)
            position.y = _ground
            _body.position.y = hop * 0.4
            _body.scale = Vector3(1.0 + (1.0 - hop) * 0.08, 0.92 + hop * 0.1, 1.0 + (1.0 - hop) * 0.08)


## Hit by a burst at `from`: thrown up and away, spinning, then sinking out of sight.
func kill(from: Vector3) -> void:
    if dead:
        return
    dead = true
    if role == "fuse":
        strid.explode(position + Vector3.UP * 0.6, false, 6.5, 0.12)
        _vanish()
        return
    _enter("dead")
    if role == "boss":
        # The pharaoh topples where he stands and crumbles into the sand.
        velocity = Vector3.UP * 2.0
        _spin = Vector3(randf_range(-0.6, 0.6), 0.0, 0.9)
        strid.boss_fell(self)
        return
    var away := position - from
    away.y = 0.0
    away = away.normalized() if away.length() > 0.1 else Vector3(randf() - 0.5, 0.0, randf() - 0.5).normalized()
    velocity = away * randf_range(6.0, 10.0) + Vector3.UP * randf_range(8.0, 12.0)
    _spin = Vector3(randf_range(-6, 6), randf_range(-3, 3), randf_range(-6, 6))


## `amount` of damage from `from` (a bullet 1, a shell burst 10): true when it kills.
func damage(amount: float, from: Vector3) -> bool:
    if dead:
        return false
    if role == "fuse":
        kill(from)
        return true
    hp -= amount
    if hp <= 0.0:
        kill(from)
        return true
    return false


## Run over by the tank: flat as a pancake, then gone.
func flatten() -> void:
    dead = true
    _enter("dead")
    velocity = Vector3.ZERO
    _body.scale = Vector3(1.3, 0.12, 1.3)
    _body.position.y = 0.05


func _vanish() -> void:
    dead = true
    state = "dead"
    t = 2.9
    visible = false
