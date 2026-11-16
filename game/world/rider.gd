extends Node3D
## The cyclist: bike and rider from cyklist.glb (loose parts made by the Blender script).
## Wheels turn with speed, the crank turns with cadence, and the legs follow the pedals with
## two-bone IK (hip → knee → ankle) in the bike's plane. Local axes: +X forward, +Y up, ±Z sides.

const BB := Vector3(0.0, 0.29, 0.0)        # bottom bracket (crank axle)
const HIP := Vector3(-0.12, 0.95, 0.0)
const CRANK := 0.17
const THIGH := 0.44
const SHIN := 0.43
const WHEEL_R := 0.34

var _parts := {}
var _crank_angle := 0.0
var _wheel_angle := 0.0


func _ready() -> void:
    # The TextureCraft-painted cyclist (assets/texturer/cyklist) when it has been built.
    var path := "res://world/skargarden/models/cyklist_tex.glb"
    if not ResourceLoader.exists(path):
        path = "res://world/skargarden/models/cyklist.glb"
    var model: Node3D = load(path).instantiate()
    add_child(model)
    for name in ["Ram", "Kropp", "HjulBak", "HjulFram", "Vev", "LarV", "LarH", "BenV", "BenH"]:
        var node := model.find_child(name, true, false)
        if node:
            _parts[name] = node
    _model = model
    _pose()
    var progress := get_node_or_null("/root/Progress")
    if progress:
        apply_look(progress.look())


var _model: Node3D

const GHOST_SHADER := preload("res://world/ghost.gdshader")
const RECOLOR_SHADER := preload("res://world/recolor.gdshader")
## The model's paint names and the colour each was painted in (assets/blender: "trika", "ram" …).
const PAINT := {"trika": "1f5aa6", "flagga_gul": "f2c230", "ram": "c8302c"}


## Jersey and frame colours from the garage: {"main", "accent", "frame"} (Progress.look()).
func apply_look(look: Dictionary) -> void:
    var want := {"trika": look.get("main"), "flagga_gul": look.get("accent"), "ram": look.get("frame")}
    for mi in _meshes(_model):
        for i in mi.mesh.get_surface_count():
            var mat := mi.mesh.surface_get_material(i)
            if mat == null:
                continue
            var paint := _paint_of(mat.resource_name)
            if paint == "" or want[paint] == null:
                mi.set_surface_override_material(i, null)
                continue
            var colour: Color = want[paint]
            if colour.is_equal_approx(Color(PAINT[paint])):
                mi.set_surface_override_material(i, null)      # the model's own paint
                continue
            var sm := ShaderMaterial.new()
            sm.shader = RECOLOR_SHADER
            var base := mat as BaseMaterial3D
            var tex: Texture2D = base.albedo_texture if base else null
            sm.set_shader_parameter("has_tex", tex != null)
            if tex:
                sm.set_shader_parameter("tex", tex)
            var ref := Color(PAINT[paint]).srgb_to_linear()
            sm.set_shader_parameter("ref_lum", 0.2126 * ref.r + 0.7152 * ref.g + 0.0722 * ref.b)
            sm.set_shader_parameter("target", colour)
            sm.set_shader_parameter("roughness_value", base.roughness if base else 0.7)
            mi.set_surface_override_material(i, sm)


## Turn this rider into the ghost: see-through cyan, no shadow.
func ghostify() -> void:
    var mat := ShaderMaterial.new()
    mat.shader = GHOST_SHADER
    for mi in _meshes(_model):
        for i in mi.mesh.get_surface_count():
            mi.set_surface_override_material(i, null)
        mi.material_override = mat
        mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## "tx_trika" or "trika" → "trika"; "trika_vit" is the white trim and keeps its colour.
func _paint_of(material_name: String) -> String:
    var n := material_name.to_lower()
    if n.begins_with("tx_"):
        n = n.substr(3)
    n = n.get_slice(".", 0)
    return n if PAINT.has(n) else ""


func _meshes(node: Node) -> Array[MeshInstance3D]:
    var list: Array[MeshInstance3D] = []
    if node == null:
        return list
    if node is MeshInstance3D and (node as MeshInstance3D).mesh:
        list.append(node)
    for child in node.get_children():
        list.append_array(_meshes(child))
    return list


## Put the bike on the road at `pos`, facing `dir` (pitched with the slope).
func place(pos: Vector3, dir: Vector3) -> void:
    position = pos
    var flat := Vector3(dir.x, 0, dir.z).normalized()
    var yaw := atan2(-flat.z, flat.x)
    var pitch := atan2(dir.y, Vector2(dir.x, dir.z).length())
    rotation = Vector3(0, yaw, pitch)


func animate(speed: float, cadence: float, delta: float) -> void:
    _wheel_angle -= speed / WHEEL_R * delta
    _crank_angle -= cadence / 60.0 * TAU * delta
    _pose()


func _pose() -> void:
    for name in ["HjulBak", "HjulFram"]:
        if _parts.has(name):
            _parts[name].rotation.z = _wheel_angle
    if _parts.has("Vev"):
        _parts["Vev"].rotation.z = _crank_angle
    # The left crank arm (-Z) points forward at angle 0, the right arm (+Z) half a turn later.
    _leg("LarV", "BenV", -0.09, _crank_angle)
    _leg("LarH", "BenH", 0.09, _crank_angle + PI)


func _leg(thigh_name: String, shin_name: String, side: float, angle: float) -> void:
    if not (_parts.has(thigh_name) and _parts.has(shin_name)):
        return
    var hip := Vector2(HIP.x, HIP.y)
    var ankle := Vector2(BB.x, BB.y) + Vector2(cos(angle), sin(angle)) * CRANK + Vector2(0, 0.05)
    var d := clampf(hip.distance_to(ankle), absf(THIGH - SHIN) + 0.01, THIGH + SHIN - 0.002)
    var base := (ankle - hip).angle()
    var bend := acos(clampf((THIGH * THIGH + d * d - SHIN * SHIN) / (2.0 * THIGH * d), -1.0, 1.0))
    var knee_a := hip + Vector2.from_angle(base + bend) * THIGH
    var knee_b := hip + Vector2.from_angle(base - bend) * THIGH
    var knee := knee_a if knee_a.x > knee_b.x else knee_b      # knees point forward
    _parts[thigh_name].transform = _bone(hip, knee, side)
    _parts[shin_name].transform = _bone(knee, ankle, side)


## A part modelled hanging along -Y from its origin, aimed from `from` to `to` in the bike plane
## and placed `side` metres out to the side (the Blender origins sit at the leg's side offset).
func _bone(from: Vector2, to: Vector2, side: float) -> Transform3D:
    var y := Vector3(from.x - to.x, from.y - to.y, 0.0).normalized()
    var z := Vector3(0, 0, 1)
    var x := y.cross(z).normalized()
    return Transform3D(Basis(x, y, z), Vector3(from.x, from.y, side))
