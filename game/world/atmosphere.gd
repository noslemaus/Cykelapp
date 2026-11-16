extends Node
## Time of day, weather and season laid over a world's own look (each world is designed as an
## evening in clear summer weather, "kväll"). Reads Settings.time_of_day, weather and season; the
## world HUD cycles them with T, V and Å.
##
##   time      morgon, dag, kväll (the world's own light), natt, or "klocka": follow the computer's clock
##   weather   klart; mulet (grey lid, soft light); regn (wet roads, rain, or snowfall in winter, or a
##             sandstorm in the desert); dimma (thick sea fog)
##   season    sommar; höst (birches and rowans turn, the grass goes straw-yellow); vinter (snow on
##             everything that faces up, bare broadleaf trees, ice on the sea). The desert has none.
##
## The ground, plants, road and water read the global shader uniforms snow_amount, autumn_amount,
## wet_amount and ice_amount; props (houses, boats, fences) get a snow layer through material_overlay.

const TIMES := ["morgon", "dag", "kvall", "natt", "klocka"]
const WEATHERS := ["klart", "mulet", "regn", "dimma"]
const SEASONS := ["sommar", "host", "vinter"]
const TIME_NAMES := {"morgon": "Morgon", "dag": "Dag", "kvall": "Kväll", "natt": "Natt", "klocka": "Följ klockan"}
const WEATHER_NAMES := {"klart": "Klart", "mulet": "Mulet", "regn": "Regn", "dimma": "Dimma"}
const SEASON_NAMES := {"sommar": "Sommar", "host": "Höst", "vinter": "Vinter"}
const SNOW_OVERLAY := preload("res://world/snow_overlay.gdshader")

## Sky and sun for each time of day; "kvall" is the world's own.
const PRESETS := {
    "morgon": {"zenith": Color(0.40, 0.56, 0.86), "high": Color(0.68, 0.76, 0.92), "horizon": Color(1.0, 0.84, 0.70),
        "side": Color(1.0, 0.78, 0.52), "ground": Color(0.30, 0.34, 0.42), "sun": Vector3(-13.0, 125.0, 0.0),
        "sun_color": Color("ffd9a6"), "sun_energy": 2.0, "fog": Color(0.92, 0.84, 0.80), "fog_mul": 1.8,
        "ambient": 0.75, "cloud": Color("ffe6d4"), "cloud_glow": Color("ffc8a0"), "glow": 0.2, "grey": Color(0.76, 0.72, 0.70)},
    "dag": {"zenith": Color(0.22, 0.46, 0.86), "high": Color(0.48, 0.68, 0.94), "horizon": Color(0.80, 0.88, 0.97),
        "side": Color(1.0, 0.96, 0.88), "ground": Color(0.35, 0.40, 0.48), "sun": Vector3(-52.0, 150.0, 0.0),
        "sun_color": Color("fff3e0"), "sun_energy": 2.7, "fog": Color(0.78, 0.86, 0.96), "fog_mul": 0.9,
        "ambient": 0.9, "cloud": Color("f4f6fa"), "cloud_glow": Color("000000"), "glow": 0.0, "grey": Color(0.68, 0.71, 0.76)},
    "natt": {"zenith": Color(0.015, 0.025, 0.07), "high": Color(0.03, 0.05, 0.13), "horizon": Color(0.08, 0.10, 0.22),
        "side": Color(0.22, 0.28, 0.46), "ground": Color(0.03, 0.04, 0.08), "sun": Vector3(-32.0, -25.0, 0.0),
        "sun_color": Color("9fb6ff"), "sun_energy": 0.55, "fog": Color(0.08, 0.10, 0.18), "fog_mul": 1.2,
        "ambient": 0.45, "cloud": Color(0.12, 0.14, 0.2), "cloud_glow": Color("000000"), "glow": 0.0, "grey": Color(0.07, 0.08, 0.11)},
}

var world
var env: Environment
var sun: DirectionalLight3D
var sky_mat: ShaderMaterial
var clouds: Array[GeometryInstance3D] = []
var cloud_mat: StandardMaterial3D
var time := "kvall"           # what is shown now (the clock resolved)
var weather := "klart"
var season := "sommar"
var _base := {}
var _particles: GPUParticles3D
var _lift := 0.0              # how high above the camera the rain starts
var _overlay: ShaderMaterial
var _overlaid: Array[GeometryInstance3D] = []


func _ready() -> void:
    env = world.environment
    for child in world.get_children():
        if child is DirectionalLight3D and sun == null:
            sun = child
        if child is MultiMeshInstance3D and child.material_override is StandardMaterial3D \
                and (child as MultiMeshInstance3D).multimesh.get_aabb().position.y > 150.0:
            clouds.append(child)
    if env and env.sky and env.sky.sky_material is ShaderMaterial:
        sky_mat = env.sky.sky_material
    if not clouds.is_empty():
        cloud_mat = (clouds[0].material_override as StandardMaterial3D)
    _remember()
    apply_settings()


func _exit_tree() -> void:
    for name in ["snow_amount", "autumn_amount", "wet_amount", "ice_amount"]:
        RenderingServer.global_shader_parameter_set(name, 0.0)


## What kind of place it is: "nordic" (seasons and sea ice), "temperate" (seasons, no ice) or
## "desert" (no seasons; rain becomes a sandstorm).
func climate() -> String:
    return world.climate() if world.has_method("climate") else "nordic"


func apply_settings() -> void:
    apply(Settings.time_of_day, Settings.weather, Settings.season)


## The label the HUD and the world screen show for a weather in this world and season.
static func weather_label(id: String, place_climate: String, in_season: String) -> String:
    if id == "regn":
        if place_climate == "desert":
            return "Sandstorm"
        if in_season == "vinter":
            return "Snöfall"
    return WEATHER_NAMES.get(id, id)


func apply(want_time: String, want_weather: String, want_season: String) -> void:
    time = _resolve_time(want_time)
    weather = want_weather if want_weather in WEATHERS else "klart"
    season = want_season if want_season in SEASONS else "sommar"
    var place := climate()
    if place == "desert":
        season = "sommar"
    _restore()
    var grey := Color(0.60, 0.58, 0.62)
    if PRESETS.has(time):
        var p: Dictionary = PRESETS[time]
        grey = p["grey"]
        if sky_mat:
            sky_mat.set_shader_parameter("zenith_color", p["zenith"])
            sky_mat.set_shader_parameter("high_color", p["high"])
            sky_mat.set_shader_parameter("horizon_color", p["horizon"])
            sky_mat.set_shader_parameter("sun_side_color", p["side"])
            sky_mat.set_shader_parameter("ground_color", p["ground"])
        if sun:
            sun.rotation_degrees = p["sun"]
            sun.light_color = p["sun_color"]
            sun.light_energy = p["sun_energy"]
        if env:
            env.fog_light_color = p["fog"]
            env.fog_density = float(_base["fog_density"]) * float(p["fog_mul"])
            env.ambient_light_energy = p["ambient"]
        if cloud_mat:
            cloud_mat.albedo_color = p["cloud"]
            cloud_mat.emission = p["cloud_glow"]
            cloud_mat.emission_energy_multiplier = p["glow"]
    if season == "vinter" and place != "desert" and sun and time != "natt":
        # The winter sun stays low over the Nordic sea, even at midday.
        sun.rotation_degrees.x = maxf(sun.rotation_degrees.x, -14.0)
        if env:
            env.tonemap_exposure = float(_base["exposure"]) * 0.82
    if season == "vinter" and env:
        # Grain from screen-space light bounce and from soft-shadow sampling shows on large white
        # fields; less of both in the snow.
        env.ssil_intensity = float(_base["ssil"]) * 0.35
        env.ssao_intensity = float(_base["ssao"]) * 0.6
        if sun:
            sun.light_angular_distance = float(_base["sun_soft"]) * 0.25
    if time == "natt":
        if sky_mat:
            sky_mat.set_shader_parameter("stars", 1.0)
            sky_mat.set_shader_parameter("disc_color", Vector3(0.85, 0.9, 1.0))
            sky_mat.set_shader_parameter("sun_size", 0.022)
        if env:
            # The night sky gives little light; a cool moonlit fill keeps the world readable.
            env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
            env.ambient_light_color = Color(0.2, 0.25, 0.4)
            env.ambient_light_energy = 1.0
            env.tonemap_exposure = float(_base["exposure"]) * 1.25

    var wet := 0.0
    var overcast := 0.0
    var fog_mul := 1.0
    var sun_mul := 1.0
    var desat := 1.0
    var fog_color := Color()
    var use_fog_color := false
    match weather:
        "mulet":
            overcast = 0.85
            fog_mul = 2.5
            sun_mul = 0.3
            desat = 0.85
            fog_color = grey
            use_fog_color = true
        "regn":
            if place == "desert":
                grey = Color(0.85, 0.62, 0.38)
                overcast = 0.7
                fog_mul = 14.0
                sun_mul = 0.35
                fog_color = Color(0.86, 0.62, 0.36)
            else:
                overcast = 0.95
                fog_mul = 4.0
                sun_mul = 0.18
                desat = 0.8
                fog_color = grey
                wet = 0.0 if season == "vinter" else 1.0
            use_fog_color = true
        "dimma":
            overcast = 0.55
            fog_mul = 16.0
            sun_mul = 0.5
            desat = 0.8
            fog_color = grey.lerp(Color(0.86, 0.88, 0.9), 0.0 if time == "natt" else 0.6)
            use_fog_color = true
    if sky_mat:
        sky_mat.set_shader_parameter("overcast", overcast)
        sky_mat.set_shader_parameter("overcast_color", grey)
    if sun:
        sun.light_energy *= sun_mul
    if env:
        env.fog_density *= fog_mul
        if use_fog_color:
            env.fog_light_color = fog_color
            env.fog_sun_scatter = float(_base["fog_sun_scatter"]) * (1.0 - overcast)
        env.adjustment_saturation = float(_base["saturation"]) * desat * (0.9 if season == "vinter" else 1.0)
    if cloud_mat and overcast > 0.0:
        cloud_mat.albedo_color = cloud_mat.albedo_color.lerp(grey, 0.8)
        cloud_mat.emission_energy_multiplier *= 1.0 - overcast

    var snow := 1.0 if season == "vinter" else 0.0
    RenderingServer.global_shader_parameter_set("snow_amount", snow)
    RenderingServer.global_shader_parameter_set("autumn_amount", 1.0 if season == "host" else 0.0)
    RenderingServer.global_shader_parameter_set("wet_amount", wet)
    RenderingServer.global_shader_parameter_set("ice_amount", 1.0 if season == "vinter" and place == "nordic" else 0.0)
    _set_snow_overlay(snow > 0.0)
    var kind := ""
    if weather == "regn":
        kind = "sand" if place == "desert" else ("sno" if season == "vinter" else "regn")
    _set_particles(kind)


func _resolve_time(want: String) -> String:
    if want != "klocka":
        return want if want in TIMES else "kvall"
    var hour := int(Time.get_datetime_dict_from_system()["hour"])
    if hour >= 5 and hour < 10:
        return "morgon"
    if hour >= 10 and hour < 17:
        return "dag"
    if hour >= 17 and hour < 22:
        return "kvall"
    return "natt"


func _remember() -> void:
    if sky_mat:
        for key in ["zenith_color", "high_color", "horizon_color", "sun_side_color", "ground_color", "sun_size"]:
            _base[key] = sky_mat.get_shader_parameter(key)
    if sun:
        _base["sun_rot"] = sun.rotation_degrees
        _base["sun_color"] = sun.light_color
        _base["sun_energy"] = sun.light_energy
        _base["sun_soft"] = sun.light_angular_distance
    if env:
        _base["fog_color"] = env.fog_light_color
        _base["fog_density"] = env.fog_density
        _base["fog_sun_scatter"] = env.fog_sun_scatter
        _base["ambient"] = env.ambient_light_energy
        _base["ambient_source"] = env.ambient_light_source
        _base["exposure"] = env.tonemap_exposure
        _base["saturation"] = env.adjustment_saturation
        _base["ssil"] = env.ssil_intensity
        _base["ssao"] = env.ssao_intensity
    if cloud_mat:
        _base["cloud"] = cloud_mat.albedo_color
        _base["cloud_glow"] = cloud_mat.emission
        _base["glow"] = cloud_mat.emission_energy_multiplier


func _restore() -> void:
    if sky_mat:
        for key in ["zenith_color", "high_color", "horizon_color", "sun_side_color", "ground_color", "sun_size"]:
            if _base.has(key) and _base[key] != null:
                sky_mat.set_shader_parameter(key, _base[key])
        sky_mat.set_shader_parameter("stars", 0.0)
        sky_mat.set_shader_parameter("overcast", 0.0)
        sky_mat.set_shader_parameter("disc_color", Vector3(1.0, 0.92, 0.72))
    if sun:
        sun.rotation_degrees = _base["sun_rot"]
        sun.light_color = _base["sun_color"]
        sun.light_energy = _base["sun_energy"]
        sun.light_angular_distance = _base["sun_soft"]
    if env:
        env.fog_light_color = _base["fog_color"]
        env.fog_density = _base["fog_density"]
        env.fog_sun_scatter = _base["fog_sun_scatter"]
        env.ambient_light_energy = _base["ambient"]
        env.ambient_light_source = _base["ambient_source"]
        env.tonemap_exposure = _base["exposure"]
        env.adjustment_saturation = _base["saturation"]
        env.ssil_intensity = _base["ssil"]
        env.ssao_intensity = _base["ssao"]
    if cloud_mat:
        cloud_mat.albedo_color = _base["cloud"]
        cloud_mat.emission = _base["cloud_glow"]
        cloud_mat.emission_energy_multiplier = _base["glow"]


# --- Snow on the props ---------------------------------------------------------------------------

## Houses, boats, fences and the like get a layer of snow on top through material_overlay. The
## ground, rocks, plants, road and water draw their own snow; the rider stays as it is.
func _set_snow_overlay(on: bool) -> void:
    for node in _overlaid:
        if is_instance_valid(node):
            node.material_overlay = null
    _overlaid.clear()
    if not on:
        return
    if _overlay == null:
        _overlay = ShaderMaterial.new()
        _overlay.shader = SNOW_OVERLAY
    var skip: Array = [world.rider, world.get("ghost")]
    for node in world.find_children("*", "GeometryInstance3D", true, false):
        var g := node as GeometryInstance3D
        if g is GPUParticles3D or g in clouds or _inside(g, skip) or _custom_shaded(g):
            continue
        g.material_overlay = _overlay
        _overlaid.append(g)


func _inside(node: Node, roots: Array) -> bool:
    for root in roots:
        if root != null and (node == root or (root as Node).is_ancestor_of(node)):
            return true
    return false


## Drawn with one of the world's own shaders, which already handle snow.
func _custom_shaded(g: GeometryInstance3D) -> bool:
    if g.material_override is ShaderMaterial:
        return true
    var mesh: Mesh = null
    if g is MeshInstance3D:
        mesh = (g as MeshInstance3D).mesh
        for i in (mesh.get_surface_count() if mesh else 0):
            if (g as MeshInstance3D).get_surface_override_material(i) is ShaderMaterial:
                return true
    elif g is MultiMeshInstance3D and (g as MultiMeshInstance3D).multimesh:
        mesh = (g as MultiMeshInstance3D).multimesh.mesh
    if mesh == null:
        return true
    for i in mesh.get_surface_count():
        if mesh.surface_get_material(i) is ShaderMaterial:
            return true
    return false


# --- Rain, snowfall and sand ---------------------------------------------------------------------

func _set_particles(kind: String) -> void:
    if _particles:
        _particles.queue_free()
        _particles = null
    if kind == "":
        return
    var p := GPUParticles3D.new()
    var pm := ParticleProcessMaterial.new()
    var quad := QuadMesh.new()
    var mat := StandardMaterial3D.new()
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
    mat.vertex_color_use_as_albedo = true
    pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
    match kind:
        "regn":
            p.amount = 7000
            p.lifetime = 1.1
            pm.emission_box_extents = Vector3(40.0, 1.0, 40.0)
            pm.direction = Vector3(0.08, -1.0, 0.0)
            pm.spread = 2.0
            pm.initial_velocity_min = 24.0
            pm.initial_velocity_max = 30.0
            pm.gravity = Vector3(0.0, -9.8, 0.0)
            pm.color = Color(0.80, 0.85, 0.95, 0.5)
            quad.size = Vector2(0.035, 0.8)
            p.position = Vector3(0.0, 18.0, 0.0)
        "sno":
            p.amount = 5000
            p.lifetime = 7.0
            pm.emission_box_extents = Vector3(45.0, 9.0, 45.0)
            pm.direction = Vector3(0.2, -1.0, 0.1)
            pm.spread = 25.0
            pm.initial_velocity_min = 1.2
            pm.initial_velocity_max = 2.4
            pm.gravity = Vector3(0.0, -1.0, 0.0)
            pm.turbulence_enabled = true
            pm.turbulence_noise_strength = 1.6
            pm.turbulence_noise_scale = 6.0
            pm.color = Color(0.96, 0.97, 1.0, 0.95)
            quad.size = Vector2(0.11, 0.11)
            p.position = Vector3(0.0, 9.0, 0.0)
        "sand":
            p.amount = 2600
            p.lifetime = 4.0
            pm.emission_box_extents = Vector3(45.0, 10.0, 45.0)
            pm.direction = Vector3(1.0, 0.05, 0.3)
            pm.spread = 12.0
            pm.initial_velocity_min = 7.0
            pm.initial_velocity_max = 12.0
            pm.gravity = Vector3.ZERO
            pm.color = Color(0.86, 0.66, 0.42, 0.35)
            quad.size = Vector2(0.14, 0.14)
            p.position = Vector3(0.0, 4.0, 0.0)
    quad.material = mat
    _lift = p.position.y
    p.process_material = pm
    p.draw_pass_1 = quad
    p.local_coords = false
    p.visibility_aabb = AABB(Vector3(-60.0, -40.0, -60.0), Vector3(120.0, 80.0, 120.0))
    p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    _particles = p
    add_child(p)
    _follow()
    p.preprocess = minf(p.lifetime, 3.0)


func _process(_delta: float) -> void:
    _follow()


## Keep the rain round the camera (the drops themselves stay where they fell).
func _follow() -> void:
    if _particles == null or world.camera == null:
        return
    var cam: Camera3D = world.camera
    var ahead := -cam.global_transform.basis.z
    ahead.y = 0.0
    _particles.global_position = cam.global_position + ahead.normalized() * 12.0 + Vector3.UP * _lift
