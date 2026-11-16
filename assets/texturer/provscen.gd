extends SceneTree
# A model as the game had it (flat colours) beside the TextureCraft-painted one (<model>_tex.glb),
# under the game's own sunset sky, sun and grading (copied from skargarden.gd), on granite.
# godot --path game --resolution 1600x900 -s <abs path>/provscen.gd -- out_dir model [model ...]
# Writes <model>_sida_vid_sida.png (both), <model>_ny.png and <model>_gammal.png (close-ups).
const MODELS := "res://world/skargarden/models/"

func _init():
    _go.call_deferred()

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
    var cam := Camera3D.new()
    cam.fov = 50.0
    root.add_child(cam)
    cam.make_current()
    for model in OS.get_cmdline_user_args().slice(1):
        var dir := MODELS
        for d in ["res://world/egypten/models/", "res://world/japan/models/"]:
            if ResourceLoader.exists(d + model + ".glb"):
                dir = d
        var flat: Node3D = load(dir + model + ".glb").instantiate()
        var tex: Node3D = load(dir + model + "_tex.glb").instantiate()
        var size := 0.5
        root.add_child(flat)
        for mi in flat.find_children("*", "MeshInstance3D", true, false):
            size = maxf(size, (mi as MeshInstance3D).get_aabb().size.length())
        var gap := size * 0.75
        flat.position = Vector3(0, 0, -gap)
        tex.position = Vector3(0, 0, gap)
        for node in [flat, tex]:
            node.rotation.y = deg_to_rad(-35.0)
        root.add_child(tex)
        # The sun shines from -x, +z: look at the lit sides.
        var views := [["sida_vid_sida", Vector3(-1.4, 0.5, 1.0) * size * 1.3, Vector3(0, size * 0.12, 0)],
            ["ny", Vector3(-0.62, 0.26, 1.1) * size + Vector3(0, 0, gap), Vector3(0, size * 0.14, gap)],
            ["gammal", Vector3(-0.62, 0.26, 1.1) * size - Vector3(0, 0, gap), Vector3(0, size * 0.14, -gap)]]
        for v in views:
            cam.position = v[1]
            cam.look_at(v[2])
            for i in 8:
                await process_frame
            await RenderingServer.frame_post_draw
            get_root().get_texture().get_image().save_png("%s/%s_%s.png" % [out, model, v[0]])
        flat.queue_free()
        tex.queue_free()
    quit()
