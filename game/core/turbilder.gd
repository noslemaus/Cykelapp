extends Node
## Ride pictures (turbilder). During a ride in a 3D world a photo is taken every minute from the
## world camera, without the HUD: a second viewport shares the world and renders one frame. When the
## ride is done, three of the photos (about a quarter in, a little past half and near the end) get the
## ride's numbers drawn on them like a share card: the ride, the segments (or time in zone) and the
## power curve. The summary shows them and saves them to Downloads/Cykelapp (made the first time).

const Style = preload("res://ui/style.gd")
const History = preload("res://ui/history.gd")
const PowerCurve = preload("res://core/power_curve.gd")
const Workout = preload("res://core/workout.gd")
const SafeFile = preload("res://core/safe_file.gd")

const SIZE := Vector2i(2560, 1440)        # the finished pictures
## The photos are taken in full HD and scaled up for the pictures: a second rendering of the world in
## 2560 × 1440 made the ride stutter for a frame or two every minute.
const PHOTO_SIZE := Vector2i(1920, 1080)
const FIRST := 20.0               # seconds of riding before the first photo
const MAX_SHOTS := 60
const GOLD := Color("ffd34d")
const CURVE := [5, 15, 60, 300, 1200]

signal composed

var app
var shots: Array[PackedByteArray] = []   # JPEG photos of the ride so far
var images: Array[Image] = []            # the three finished pictures
var title := ""
var _ride_id := -1.0
var _every := 60.0
var _next := FIRST
var _busy := false


func _process(_delta: float) -> void:
    if Ride.state != Ride.State.RIDING:
        return
    if Ride.started_unix != _ride_id:      # a new ride: start over
        _ride_id = Ride.started_unix
        shots.clear()
        images.clear()
        _every = 60.0
        _next = FIRST
    if _busy or Ride.paused or app == null or app.world == null or not is_instance_valid(app.world):
        return
    if app.world.get("camera") == null or Ride.moving_time < _next:
        return
    _next = Ride.moving_time + _every
    _capture(app.world.camera)


func _capture(cam: Camera3D) -> void:
    _busy = true
    var vp := SubViewport.new()
    vp.size = PHOTO_SIZE
    vp.world_3d = get_viewport().world_3d
    vp.msaa_3d = get_viewport().msaa_3d
    vp.render_target_update_mode = SubViewport.UPDATE_ONCE
    var c := Camera3D.new()
    c.fov = cam.fov
    c.near = cam.near
    c.far = cam.far
    c.environment = cam.environment
    c.attributes = cam.attributes
    vp.add_child(c)
    add_child(vp)
    c.global_transform = cam.global_transform
    c.current = true
    await RenderingServer.frame_post_draw
    var img := await _read_back(vp)
    vp.queue_free()
    if img != null and not img.is_empty():
        # Encoding 2560×1440 as JPEG takes a few hundredths of a second: done on a worker thread.
        var out := [PackedByteArray()]
        var task := WorkerThreadPool.add_task(func(): out[0] = img.save_jpg_to_buffer(0.9))
        while not WorkerThreadPool.is_task_completed(task):
            await get_tree().process_frame
        WorkerThreadPool.wait_for_task_completion(task)
        if not out[0].is_empty():
            shots.append(out[0])
        if shots.size() > MAX_SHOTS:        # a long ride: keep every other photo, and take fewer
            var kept: Array[PackedByteArray] = []
            for i in range(0, shots.size(), 2):
                kept.append(shots[i])
            shots = kept
            _every *= 2.0
    _busy = false


## The rendered photo as an Image. Reading a 2560×1440 picture back from the GPU the plain way
## (get_image) stops the game for about 50 ms, a stutter once a minute; asking the rendering device
## for it asynchronously lets the ride go on while it arrives a frame or two later. Falls back to
## get_image when the texture is not plain 8-bit RGBA (or with no rendering device).
func _read_back(vp: SubViewport) -> Image:
    var rd := RenderingServer.get_rendering_device()
    var rid := RenderingServer.texture_get_rd_texture(vp.get_texture().get_rid()) if rd else RID()
    if rid.is_valid():
        var fmt := rd.texture_get_format(rid)
        if fmt.format in [RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM, RenderingDevice.DATA_FORMAT_R8G8B8A8_SRGB]:
            var got := [null]
            if rd.texture_get_data_async(rid, 0, func(data: PackedByteArray): got[0] = data) == OK:
                for i in 30:
                    if got[0] != null:
                        break
                    await get_tree().process_frame
                if got[0] is PackedByteArray and got[0].size() == fmt.width * fmt.height * 4:
                    return Image.create_from_data(fmt.width, fmt.height, false, Image.FORMAT_RGBA8, got[0])
    return vp.get_texture().get_image()


## The three photos for the pictures: about 25 %, 55 % and 85 % through the ride.
func _picks(n: int) -> Array[int]:
    var out: Array[int] = []
    for f in [0.25, 0.55, 0.85]:
        var i := clampi(int(f * n), 0, n - 1)
        if not out.has(i):
            out.append(i)
    return out


## Draw the finished ride onto three of its photos (the history entry of the ride just saved).
func compose(activity_title: String) -> void:
    images.clear()
    title = activity_title
    var rides: Array = Progress.data["rides"]
    # The ride must be the one just saved: a ride under a minute is not kept in the history, and its
    # pictures would otherwise carry the numbers of the ride before it.
    if shots.is_empty() or rides.is_empty() or int(rides[-1].get("id", 0)) != int(Ride.summary.get("started", -1.0)):
        composed.emit()
        return
    var entry: Dictionary = rides[-1]
    var picks := _picks(shots.size())
    for k in picks.size():
        var photo := Image.new()
        if photo.load_jpg_from_buffer(shots[picks[k]]) != OK:
            continue
        if photo.get_size() != SIZE:
            photo.resize(SIZE.x, SIZE.y, Image.INTERPOLATE_LANCZOS)
        images.append(await _card(photo, _content(entry, k)))
    composed.emit()


## Save the pictures in Downloads/Cykelapp ("Hämtade filer"), made the first time, or in `folder`;
## return the folder.
func save(folder := "") -> String:
    if folder == "":
        folder = OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS).path_join("Cykelapp")
    DirAccess.make_dir_recursive_absolute(folder)
    var bias := float(Time.get_time_zone_from_system().get("bias", 0)) * 60.0
    var stamp := Time.get_datetime_string_from_unix_time(int(_ride_id + bias)).replace("T", "_").replace(":", "")
    var slug := SafeFile.slug(title)
    for i in images.size():
        images[i].save_jpg(folder.path_join("%s_%s_%d.jpg" % [stamp.left(15), slug, i + 1]), 0.92)
    return folder


# --- What each picture says ---------------------------------------------------------------------

func _content(e: Dictionary, k: int) -> Dictionary:
    var hr := float(e.get("avg_hr", 0.0))
    var subtitle := History.when(float(e.get("date", 0.0)))         # the world is in the title
    var cat := str(e.get("category", ""))
    var kind: String = tr(Workout.CATEGORY_NAMES[cat]) if Workout.CATEGORY_NAMES.has(cat) else tr("Fri cykling")
    if not title.ends_with(kind):                                    # plan sessions are named by their kind
        subtitle += "  ·  " + kind
    subtitle += "  ·  " + (tr("låtsastrainer") if e.get("pretend", false) else tr("trainer"))
    var xp := int(e.get("xp", 0))
    var c := {"title": title, "subtitle": subtitle, "badge": "", "heading": "", "tiles": [], "line": ""}
    match k:
        0:
            c["heading"] = tr("Turen")
            c["tiles"] = [[Style.clock(float(e.get("seconds", 0.0))), tr("tid")],
                [Style.dec(float(e.get("km", 0.0)), 2) + " km", tr("distans")],
                ["%d W" % roundi(float(e.get("avg_w", 0.0))), tr("snitt")],
                ["%d W" % roundi(float(e.get("np", 0.0))), "NP"]]
            if hr > 0:
                c["tiles"].append(["%d" % roundi(hr), tr("snittpuls")])
            c["tiles"].append(["%d m" % roundi(float(e.get("elev", 0.0))), tr("höjdmeter")])
            var bits := ["TSS %d" % roundi(float(e.get("tss", 0.0))), "IF " + Style.dec(float(e.get("if", 0.0)), 2),
                "%d kJ" % int(e.get("kj", 0)), "%d rpm" % roundi(float(e.get("avg_cad", 0.0))), tr("max %d W") % int(e.get("max_w", 0))]
            if xp > 0:
                bits.append("+%d XP" % xp)
            c["line"] = "   ·   ".join(bits)
            if e.get("completed", false):
                c["badge"] = tr("✓ GENOMFÖRT")
        1:
            var segs: Array = e.get("segments", [])
            if segs.is_empty():
                c["heading"] = tr("Tid i zon")
                var zs: Array = Ride.summary.get("zone_seconds", [])
                for z in zs.size():
                    if zs[z] >= 30:
                        c["tiles"].append([Style.minutes(float(zs[z])), "Z%d" % (z + 1)])
            else:
                var prs := segs.filter(func(s): return s.get("pr", false)).size()
                c["heading"] = tr("%d segmentrekord") % prs if prs > 0 else tr("Segment")
                for s in segs.slice(0, 5):
                    var t := float(s["time"])
                    var v := ("%s s" % Style.dec(t)) if t < 60.0 else Style.clock(t)
                    c["tiles"].append([v, ("★ " if s.get("pr", false) else "") + tr(str(s["name"]))])
                if prs > 1 and prs == segs.size():
                    c["line"] = tr("Alla %d segment längs vägen är nya rekord.") % prs
                elif prs > 0:
                    c["line"] = tr("★ = nytt rekord")
                if prs > 0:
                    c["badge"] = tr("★ %d PR") % prs
        _:
            var curve: Dictionary = e.get("curve", {})
            var pbs := {}
            for b in e.get("bests", []):
                pbs[int(b[0])] = true
            c["heading"] = tr("Personbästa") if not pbs.is_empty() else tr("Wattkurvan")
            for d in CURVE:
                if curve.has(str(d)):
                    c["tiles"].append(["%d W" % roundi(float(curve[str(d)])), ("★ " if pbs.has(d) else "") + PowerCurve.label(d)])
            var bits := [tr("max %d W") % int(e.get("max_w", 0))]
            if int(e.get("max_hr", 0)) > 0:
                bits.append(tr("maxpuls %d") % int(e.get("max_hr", 0)))
            var plan = e.get("plan")
            if plan is Array and app:
                var p: Dictionary = app.find_plan(plan[0])
                if not p.is_empty():
                    bits.append(tr("pass %d av %d i %s") % [int(plan[1]) + 1, p["sessions"].size(), tr(p["name"])])
            c["line"] = "   ·   ".join(bits)
            if xp > 0:
                c["badge"] = "+%d XP" % xp
    return c


# --- Drawing ------------------------------------------------------------------------------------

func _card(photo: Image, c: Dictionary) -> Image:
    var vp := SubViewport.new()
    vp.size = SIZE
    vp.disable_3d = true
    vp.transparent_bg = false
    vp.render_target_update_mode = SubViewport.UPDATE_ONCE
    add_child(vp)
    var root := Control.new()
    root.size = Vector2(SIZE)
    vp.add_child(root)
    var pic := TextureRect.new()
    pic.texture = ImageTexture.create_from_image(photo)
    pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    pic.size = Vector2(SIZE)
    root.add_child(pic)

    var brand := Style.label("CYKELAPP", 26, Color(1, 1, 1, 0.85), 800)
    brand.position = Vector2(SIZE.x - 230, 40)
    root.add_child(brand)

    var panel := PanelContainer.new()
    var sb := StyleBoxFlat.new()
    sb.bg_color = Color(0.06, 0.07, 0.10, 0.74)
    sb.set_corner_radius_all(26)
    sb.border_width_top = 8
    sb.border_color = Style.ACCENT
    sb.content_margin_left = 44
    sb.content_margin_right = 44
    sb.content_margin_top = 34
    sb.content_margin_bottom = 36
    panel.add_theme_stylebox_override("panel", sb)
    var box := Style.vbox(4)
    panel.add_child(box)
    var head := Style.hbox(24)
    var t := Style.label(c["title"], 44, Style.TEXT, 800)
    t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    head.add_child(t)
    if c["badge"] != "":
        var badge := PanelContainer.new()
        var bs := StyleBoxFlat.new()
        bs.bg_color = Style.ACCENT
        bs.set_corner_radius_all(20)
        bs.content_margin_left = 16
        bs.content_margin_right = 16
        bs.content_margin_top = 4
        bs.content_margin_bottom = 4
        badge.add_theme_stylebox_override("panel", bs)
        badge.add_child(Style.label(c["badge"], 20, Color("10141b"), 800))
        badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        head.add_child(badge)
    box.add_child(head)
    box.add_child(Style.label(c["subtitle"], 21, Color(1, 1, 1, 0.68), 600))
    var gap := Control.new()
    gap.custom_minimum_size.y = 14
    box.add_child(gap)
    if c["heading"] != "":
        box.add_child(Style.label(str(c["heading"]).to_upper(), 18, GOLD, 800))
    var row := Style.hbox(40)
    for tile in c["tiles"]:
        var col := Style.vbox(-6)
        col.add_child(Style.label(tile[0], 58, Style.TEXT, 800))
        var name := str(tile[1])
        var plain := name.trim_prefix("★ ")
        if plain == "" or not plain[0].is_valid_int():      # "5 s", "1 min" keep their small letters
            name = name.to_upper()
        col.add_child(Style.label(name, 16, Color(1, 1, 1, 0.68), 700))
        row.add_child(col)
    box.add_child(row)
    if c["line"] != "":
        var gap2 := Control.new()
        gap2.custom_minimum_size.y = 10
        box.add_child(gap2)
        box.add_child(Style.label(c["line"], 22, Style.TEXT, 600))
    root.add_child(panel)
    # Let the containers size themselves, then sit the panel in the bottom left corner.
    await get_tree().process_frame
    await get_tree().process_frame
    panel.size = panel.get_combined_minimum_size()
    panel.position = Vector2(48, SIZE.y - 48 - panel.size.y)
    vp.render_target_update_mode = SubViewport.UPDATE_ONCE
    await RenderingServer.frame_post_draw
    var img := await _read_back(vp)
    vp.queue_free()
    return img
