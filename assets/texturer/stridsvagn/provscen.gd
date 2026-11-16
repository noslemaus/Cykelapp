extends SceneTree
# The flat-coloured tank beside the TextureCraft-textured one, under the game's own sunset sky,
# sun and grading (copied from skargarden.gd), on granite with the game's ground shader.
# godot --path game --resolution 1600x900 -s tankprov2.gd -- out_dir
const DIR := "res://world/skargarden/texturprov/"

func _init():
    _go.call_deferred()

func textured(set_name: String) -> ORMMaterial3D:
    var m := ORMMaterial3D.new()
    m.albedo_texture = load(DIR + "%s_BaseColor.png" % set_name)
    m.orm_texture = load(DIR + "%s_OcclusionRoughnessMetallic.png" % set_name)
    m.normal_enabled = true
    m.normal_texture = load(DIR + "%s_Normal.png" % set_name)
    return m

func _go():
    var out := OS.get_cmdline_user_args()[0]
    var root := Node3D.new()
    get_root().add_child(root)
    var sky_mat := ShaderMaterial.new()
    sky_mat.shader = load("res://world/sky.gdshader")
    var sky := Sky.new()
    sky.sky_material = sky_mat
    var env := Environment.new()
    env.background_mode = Environment.BG_SKY
    env.sky = sky
    env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
    env.ambient_light_energy = 0.75
    env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
    env.tonemap_mode = Environment.TONE_MAPPER_ACES
    env.tonemap_exposure = 0.95
    env.tonemap_white = 6.0
    env.ssao_enabled = true
    env.ssao_radius = 1.6
    env.ssao_intensity = 1.8
    env.glow_enabled = true
    env.glow_intensity = 0.7
    env.glow_bloom = 0.06
    env.glow_hdr_threshold = 1.1
    env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
    env.adjustment_enabled = true
    env.adjustment_saturation = 1.14
    env.adjustment_contrast = 1.07
    env.adjustment_brightness = 1.02
    env.ssil_enabled = true
    var we := WorldEnvironment.new()
    we.environment = env
    root.add_child(we)
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-10.0, -52.0, 0.0)
    sun.light_color = Color("ffb062")
    sun.light_energy = 2.4
    sun.light_angular_distance = 0.8
    sun.shadow_enabled = true
    sun.shadow_blur = 1.2
    sun.directional_shadow_max_distance = 120.0
    root.add_child(sun)
    var ground := MeshInstance3D.new()
    var pm := PlaneMesh.new()
    pm.size = Vector2(400, 400)
    var gm := ShaderMaterial.new()
    gm.shader = load("res://world/ground.gdshader")
    gm.set_shader_parameter("use_vertex_color", false)
    gm.set_shader_parameter("base_color", Color("bf8a7c"))
    pm.material = gm
    ground.mesh = pm
    root.add_child(ground)
    var mats := {"pansar": textured("pansar"), "larvband": textured("larvband")}
    var flat: Node3D = load("res://world/skargarden/models/stridsvagn.glb").instantiate()
    var tex: Node3D = load(DIR + "stridsvagn_tc.glb").instantiate()
    flat.position = Vector3(0, 0, -5.5)
    tex.position = Vector3(0, 0, 5.5)
    for node in [flat, tex]:
        node.rotation.y = deg_to_rad(-35.0)
        root.add_child(node)
    for mi in tex.find_children("*", "MeshInstance3D", true, false):
        var mesh: Mesh = mi.mesh
        for k in mesh.get_surface_count():
            var m := mesh.surface_get_material(k)
            var name := m.resource_name if m else ""
            if mats.has(name):
                mi.set_surface_override_material(k, mats[name])
    var cam := Camera3D.new()
    cam.fov = 50.0
    root.add_child(cam)
    cam.make_current()
    # The sun shines from -x, +z: look at the lit sides.
    var views := [["sida_vid_sida", Vector3(-15.0, 5.5, 12.0), Vector3(0, 1.2, 0)],
        ["narbild", Vector3(-7.5, 3.4, 13.5), Vector3(0, 1.4, 5.5)],
        ["narbild_gammal", Vector3(-7.5, 3.4, 2.5), Vector3(0, 1.4, -5.5)]]
    for v in views:
        cam.position = v[1]
        cam.look_at(v[2])
        for i in 8:
            await process_frame
        await RenderingServer.frame_post_draw
        get_root().get_texture().get_image().save_png("%s/%s.png" % [out, v[0]])
    quit()
