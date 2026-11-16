extends Control
## Settings in tabs: profile (FTP, weight), hardware (trainer source, power display, cadence guard),
## HUD (the four fields under the big watt number), buttons (what each Zwift Click button does),
## sound and Strava. Changes are saved immediately.
## It is also opened over a ride (the gear button or Esc): the ride goes on underneath, the world
## shows dimmed behind, and "Tillbaka till turen" closes it. The trainer cannot be switched then.
## args: {"tab": "profil" | "hardvara" | "hud" | "knappar" | "ljud" | "strava",
##        "overlay": true, "on_close": Callable}

const Style = preload("res://ui/style.gd")

var app
var args := {}
var _status: Label
var _click_status: Label
var _button_labels := {}


var overlay := false            # opened over a ride
var _page: Control


func _ready() -> void:
    overlay = args.get("overlay", false)
    if overlay:
        var shade := ColorRect.new()
        shade.color = Color(0.03, 0.04, 0.07, 0.82)
        shade.set_anchors_preset(Control.PRESET_FULL_RECT)
        shade.mouse_filter = Control.MOUSE_FILTER_STOP
        add_child(shade)
    _show(args.get("tab", "knappar" if overlay else "profil"))


## Build the page for `tab` (switching tabs rebuilds it in place, also over a ride).
func _show(tab: String) -> void:
    if _page:
        if Controls.button_seen.is_connected(_on_button_seen):
            Controls.button_seen.disconnect(_on_button_seen)
        _button_labels.clear()
        _page.queue_free()
    var root := Style.vbox(20)
    _page = Style.margin(root, 32)
    add_child(_page)
    var close := (args["on_close"] as Callable) if overlay else (func(): app.go("menu"))
    root.add_child(Style.header(tr("Inställningar"), tr("Tillbaka till turen") if overlay else tr("Meny"), close))
    if overlay:
        var note := Style.label(tr("Turen fortsätter medan du är här. Esc stänger."), 16, Style.TEXT_DIM, 600)
        root.add_child(note)

    var tabs := HFlowContainer.new()
    tabs.add_theme_constant_override("h_separation", 10)
    tabs.add_theme_constant_override("v_separation", 10)
    for item in [[tr("Profil"), "profil"], [tr("Hårdvara"), "hardvara"], [tr("Skärmen"), "hud"], [tr("Knappar"), "knappar"],
            [tr("Ljud"), "ljud"], [tr("Strava"), "strava"]]:
        var b := Style.button(item[0], "secondary", 19)
        b.custom_minimum_size.x = 130
        Style.set_selected(b, tab == item[1])
        var key: String = item[1]
        b.pressed.connect(func(): _show(key))
        tabs.add_child(b)
    root.add_child(tabs)

    var panel := Style.panel(Style.PANEL, 18, 24)
    panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
    var scroll := ScrollContainer.new()
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    panel.add_child(scroll)
    var box := Style.vbox(22)
    box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.add_child(box)
    root.add_child(panel)
    match tab:
        "hardvara":
            _hardware(box)
        "hud":
            _hud(box)
        "knappar":
            _buttons(box)
        "strava":
            _strava(box)
        "ljud":
            _sound(box)
        _:
            _profile(box)


func _row(box: VBoxContainer, title: String, help: String, control: Control) -> void:
    var row := Style.hbox(24)
    var text := Style.vbox(2)
    text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    text.add_child(Style.label(title, 24, Style.TEXT, 800))
    var h := Style.label(help, 17, Style.TEXT_DIM, 500)
    h.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    text.add_child(h)
    row.add_child(text)
    control.custom_minimum_size = Vector2(320, 52)
    control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    row.add_child(control)
    box.add_child(row)


func _spin(value: float, low: float, high: float, step: float, suffix: String, on_change: Callable) -> SpinBox:
    var spin := SpinBox.new()
    spin.min_value = low
    spin.max_value = high
    spin.step = step
    spin.value = value
    spin.suffix = suffix
    spin.get_line_edit().add_theme_font_size_override("font_size", 22)
    spin.value_changed.connect(on_change)
    return spin


func _options(items: Array, selected: int, on_select: Callable) -> OptionButton:
    var o := OptionButton.new()
    for text in items:
        o.add_item(text)
    o.select(selected)
    o.add_theme_font_size_override("font_size", 20)
    o.item_selected.connect(on_select)
    return o


func _profile(box: VBoxContainer) -> void:
    _row(box, tr("Språk"), tr("Spelets språk. English är standard."),
        _options(["English", "Svenska"], 1 if Settings.language == "sv" else 0, func(index):
            Settings.language = "sv" if index == 1 else "en"
            Settings.save()
            _show("profil")))
    _row(box, "FTP", tr("Din funktionella tröskeleffekt. Alla pass räknas i procent av den. Vet du inte din, börja på 200 W."),
        _spin(Settings.ftp, 50, 600, 1, "W", func(v):
            Settings.ftp = int(v)
            Settings.save()))
    _row(box, tr("Vikt"), tr("Används för farten i världen och för watt per kilo."),
        _spin(Settings.weight_kg, 30, 200, 0.1, "kg", func(v):
            Settings.weight_kg = float(v)
            Settings.save()))


func _hardware(box: VBoxContainer) -> void:
    _row(box, tr("Trainer"), tr("Låtsastrainern hittar på watt och puls så att allt kan testas utan cykel. ")
        + tr("Trainer via Bluetooth startar Cykelbrygga och styr din riktiga trainer. Stäng Zwift först."),
        _trainer_choice())
    _row(box, tr("Din trainer"), tr("Cykelbrygga söker hela tiden efter smarta trainers (KICKR, Tacx, Elite, Saris och andra med FTMS) och wattmätare. ")
        + tr("Välj din här, särskilt om det finns flera i rummet. Annars tas den första smarta trainern."),
        _trainer_picker())
    # The trainer's status right under the choice: green when ready, yellow when something needs you.
    _status = Style.label("", 18, Style.ACCENT, 600)
    _status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    box.add_child(_status)
    _row(box, tr("Wattvisning"), tr("Det stora wattalet som snitt över 3 sekunder (lugnare) eller momentant."),
        _options([tr("3 sekunders snitt"), tr("Momentant")], 1 if Settings.power_display == "instant" else 0, func(i):
            Settings.power_display = "instant" if i == 1 else "3s"
            Settings.save()))
    var guard := CheckButton.new()
    guard.button_pressed = Settings.cadence_guard
    guard.text = tr("På") if Settings.cadence_guard else tr("Av")
    guard.toggled.connect(func(on):
        Settings.cadence_guard = on
        guard.text = tr("På") if on else tr("Av")
        Settings.save())
    _row(box, tr("Kadensskydd i ERG"), tr("Sänker målet till hälften om kadensen faller under 55 rpm i 3 s, ")
        + tr("så att du inte fastnar i ett för tungt motstånd. Släpper när du trampar runt 70 rpm igen."), guard)
    var levels := [0.0, 0.25, 0.5, 0.75, 1.0]
    var current := levels.find(snappedf(Settings.trainer_difficulty, 0.25))
    _row(box, tr("Backkänsla"), tr("Hur mycket av vägens lutning trainern känns som i SIM. ")
        + tr("50 % gör en 8 %-backe till 4 % i benen. Farten i världen följer alltid den riktiga lutningen."),
        _options([tr("0 % (platt)"), "25 %", tr("50 % (standard)"), "75 %", tr("100 % (verklig)")], maxi(current, 0), func(i):
            Settings.trainer_difficulty = levels[i]
            Settings.save()))
    # Calibration (FTMS spin down): only with the real trainer.
    _calibrate = Style.button(tr("Kalibrera"), "secondary", 20)
    _calibrate.pressed.connect(func():
        var link = Ride.trainer_link()
        if link:
            link.start_spindown())
    _row(box, tr("Kalibrera trainern"), tr("Trampa upp till en fart, sluta och låt svänghjulet rulla ut. ")
        + tr("Trainern mäter då sitt eget motstånd, så watten blir rätt. Gör det när trainern är varm, efter tio minuters cykling."),
        _calibrate)
    _calibrate_state = Style.label("", 18, Style.TEXT_DIM, 600)
    _calibrate_state.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    box.add_child(_calibrate_state)


## The Zwift Click pair: on/off, live status, and an action for each of the ten buttons. A button
## lights up here while it is pressed, so it is easy to see which is which.
func _buttons(box: VBoxContainer) -> void:
    var toggle := CheckButton.new()
    toggle.button_pressed = Settings.click_enabled
    toggle.text = tr("På") if Settings.click_enabled else tr("Av")
    toggle.toggled.connect(func(on):
        Settings.click_enabled = on
        toggle.text = tr("På") if on else tr("Av")
        Settings.save())
    _row(box, tr("Zwift Click"), tr("Dina Click ansluts via Cykelbrygga, även med låtsastrainern. En Click v2 skickar ")
        + tr("knappar först när den har varit ansluten i Zwift-appen en stund; det gäller sedan ett dygn. ")
        + tr("Tryck på en knapp så lyser den upp här."), toggle)
    _click_status = Style.label("", 18, Style.ACCENT, 600)
    _click_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    box.add_child(_click_status)
    var grid := GridContainer.new()
    grid.columns = 2 if get_viewport_rect().size.x > 1400.0 else 1     # one column in narrow windows
    grid.add_theme_constant_override("h_separation", 48)
    grid.add_theme_constant_override("v_separation", 12)
    var actions: Array = Controls.ACTIONS
    var labels: Array = []
    for a in actions:
        labels.append(a[1])
    for b in Controls.BUTTONS:
        var id: String = b[0]
        var cell := Style.hbox(14)
        var name := Style.label(b[1], 20, Style.TEXT, 700)
        name.custom_minimum_size.x = 220
        name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        cell.add_child(name)
        var current := 0
        for i in actions.size():
            if actions[i][0] == Controls.binding(id):
                current = i
        var o := _options(labels, current, func(i):
            Settings.button_bindings[id] = actions[i][0]
            Settings.save())
        o.custom_minimum_size = Vector2(320, 46)
        cell.add_child(o)
        grid.add_child(cell)
        _button_labels[id] = name
    box.add_child(grid)
    var keys := Style.label(tr("Tangentbordet: A/D sväng · ↑/↓ tyngre/lättare · ←/→ titta · Enter nästa steg · ")
        + tr("mellanslag paus · M byt ERG/SIM"), 17, Style.TEXT_DIM, 500)
    keys.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    box.add_child(keys)
    var reset := Style.button(tr("Återställ knapparna"), "secondary", 19)
    reset.custom_minimum_size = Vector2(260, 48)
    reset.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
    reset.pressed.connect(func():
        Settings.button_bindings = {}
        Settings.save()
        _show("knappar"))
    box.add_child(reset)
    Controls.button_seen.connect(_on_button_seen)


## Which trainer drives the ride (not changeable in the middle of one).
func _trainer_choice() -> Control:
    var o := _options([tr("Låtsastrainer"), tr("Trainer via Bluetooth")], 1 if Settings.source == "trainer" else 0, func(i):
        Settings.source = "trainer" if i == 1 else "sim"
        Settings.save())
    if overlay:
        o.disabled = true
        o.tooltip_text = tr("Byt trainer när turen är slut.")
    return o


## The trainers Cykelbrygga has found, to pick one: "the first smart trainer" or a found one. The
## list is rebuilt when the bridge finds more (not while it is open).
func _trainer_picker() -> Control:
    _trainer_pick = OptionButton.new()
    _trainer_pick.add_theme_font_size_override("font_size", 20)
    _trainer_pick.fit_to_longest_item = false      # as wide as the other choices, long names are cut
    _trainer_pick.clip_text = true
    _trainer_pick.item_selected.connect(func(i):
        if i < 0 or i >= _trainer_ids.size():
            return
        Settings.trainer_id = _trainer_ids[i]
        Settings.trainer_name = _trainer_names[i]
        Settings.save()
        _trainer_sig = "")
    _refresh_trainers()
    return _trainer_pick


func _refresh_trainers() -> void:
    var link = Ride.trainer_link()
    var found: Array = link.trainers() if link else []
    var connected: String = link.connected_trainer() if link else ""
    var sig := "%s|%s|%s|%s" % [JSON.stringify(found), connected, Settings.trainer_id, link != null]
    if sig == _trainer_sig or _trainer_pick.get_popup().visible:
        return
    _trainer_sig = sig
    _trainer_pick.clear()
    _trainer_ids.clear()
    _trainer_names.clear()
    _trainer_pick.add_item(tr("Första smarta trainern") if link else tr("Välj Trainer via Bluetooth först"))
    _trainer_ids.append("")
    _trainer_names.append("")
    for t in found:
        if not t is Dictionary:
            continue
        var id := str(t.get("id", ""))
        var text := str(t.get("name", "Trainer"))
        if not t.get("smart", false):
            text += "  ·  " + tr("bara watt")
        if id == connected:
            text += "  ·  " + tr("ansluten")
        _trainer_pick.add_item(text)
        _trainer_ids.append(id)
        _trainer_names.append(str(t.get("name", "Trainer")))
    if Settings.trainer_id != "" and not _trainer_ids.has(Settings.trainer_id):
        var name := Settings.trainer_name if Settings.trainer_name != "" else "Trainer"
        _trainer_pick.add_item(tr("%s (inte hittad än)") % name)
        _trainer_ids.append(Settings.trainer_id)
        _trainer_names.append(Settings.trainer_name)
    _trainer_pick.select(maxi(_trainer_ids.find(Settings.trainer_id), 0))
    _trainer_pick.disabled = overlay or link == null


## Sound: on or off, and how loud (the battle's cannon, bursts, gong and so on).
func _sound(box: VBoxContainer) -> void:
    var toggle := CheckButton.new()
    toggle.button_pressed = Settings.sound_on
    toggle.text = tr("På") if Settings.sound_on else tr("Av")
    toggle.toggled.connect(func(on):
        Settings.sound_on = on
        toggle.text = tr("På") if on else tr("Av")
        Settings.save())
    _row(box, tr("Ljud"), tr("Stängs av helt med Av."), toggle)
    var row := Style.hbox(14)
    var slider := HSlider.new()
    slider.min_value = 0.0
    slider.max_value = 100.0
    slider.step = 5.0
    slider.value = roundf(Settings.sound_volume * 100.0)
    slider.custom_minimum_size = Vector2(260, 32)
    var value := Style.label("%d %%" % roundi(slider.value), 20, Style.TEXT, 800)
    slider.value_changed.connect(func(v):
        Settings.sound_volume = v / 100.0
        value.text = "%d %%" % roundi(v)
        Settings.save())
    row.add_child(slider)
    row.add_child(value)
    _row(box, tr("Volym"), tr("Hur högt kanonen, smällarna, kulsprutan, kaststjärnorna, gongen och de andra ljuden låter."), row)
    _row(box, tr("Musik"), tr("Varje värld har egna låtar med 80-talskänsla. Fler instrument kommer in ju hårdare du trampar, zon för zon."),
        _volume_slider(Settings.music_volume, func(v): Settings.music_volume = v))
    for world_id in app.WORLDS:
        var ids: Array = ["blanda"] + Musik.songs_for(world_id) + ["original"]
        var names: Array = ids.map(func(id): return tr("Blanda") if id == "blanda" else tr(str(Musik.songs.get(id, {}).get("name", id))))
        var current := maxi(0, ids.find(str(Settings.music_choice.get(world_id, "blanda"))))
        var wid: String = world_id
        _row(box, tr("Musik i %s") % tr(app.WORLDS[world_id]["name"]), tr("Tre egna låtar med 80-talskänsla, eller blanda dem."),
            _options(names, current, func(index):
                Settings.music_choice[wid] = ids[index]
                Settings.save()))


func _volume_slider(start: float, on_change: Callable) -> Control:
    var row := Style.hbox(14)
    var slider := HSlider.new()
    slider.min_value = 0.0
    slider.max_value = 100.0
    slider.step = 5.0
    slider.value = roundf(start * 100.0)
    slider.custom_minimum_size = Vector2(260, 32)
    var value := Style.label("%d %%" % roundi(slider.value), 20, Style.TEXT, 800)
    slider.value_changed.connect(func(v):
        on_change.call(v / 100.0)
        value.text = "%d %%" % roundi(v)
        Settings.save())
    row.add_child(slider)
    row.add_child(value)
    return row


func _on_button_seen(id: String, down: bool) -> void:
    var label: Label = _button_labels.get(id)
    if label:
        label.add_theme_color_override("font_color", Style.ACCENT if down else Style.TEXT)


func _hud(box: VBoxContainer) -> void:
    var full := CheckButton.new()
    full.button_pressed = Settings.fullscreen
    full.text = tr("Helskärm") if Settings.fullscreen else tr("Fönster")
    full.toggled.connect(func(on):
        Settings.fullscreen = on
        full.text = tr("Helskärm") if on else tr("Fönster")
        Settings.save())
    _row(box, tr("Helskärm"), tr("Spelet fyller hela skärmen. F11 växlar var du än är i spelet."), full)
    var intro := CheckButton.new()
    intro.button_pressed = Settings.intro
    intro.text = tr("På") if Settings.intro else tr("Av")
    intro.toggled.connect(func(on):
        Settings.intro = on
        intro.text = tr("På") if on else tr("Av")
        Settings.save())
    _row(box, tr("Intro vid start"), tr("Den korta animationen med cyklisten när spelet startar. En knapptryckning hoppar över den."), intro)
    var pace := CheckButton.new()
    pace.button_pressed = Settings.pacers
    pace.text = tr("På") if Settings.pacers else tr("Av")
    pace.toggled.connect(func(on):
        Settings.pacers = on
        pace.text = tr("På") if on else tr("Av")
        Settings.save())
    _row(box, tr("Pacer-cyklister"), tr("Lugna Lisa, Jämna Jonas och Snabba Stina cyklar varvet i jämn fart. ")
        + tr("Ligg tätt bakom en så får du draft: mindre luftmotstånd och lite lättare på trainern."), pace)
    var keys: Array = Settings.HUD_FIELDS.keys()
    var names: Array = Settings.HUD_FIELDS.values()
    for i in 4:
        var slot := i
        _row(box, tr("Fält %d") % (i + 1), tr("Visas under det stora wattalet i cykelvyn."),
            _options(names, maxi(0, keys.find(Settings.hud_slots[i])), func(index):
                Settings.hud_slots[slot] = keys[index]
                Settings.save()))


var _client_id: LineEdit
var _client_secret: LineEdit
var _strava_state: Label
var _link_button: Button
var _unlink_button: Button


func _strava(box: VBoxContainer) -> void:
    var help := Style.label(tr("Använd din egen API-app från strava.com/settings/api, där Authorization Callback Domain ")
        + tr("ska vara localhost. Uppgifterna sparas bara på den här datorn."), 17, Style.TEXT_DIM, 500)
    help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    box.add_child(help)
    _client_id = LineEdit.new()
    _client_id.text = Strava.client_id
    _client_id.placeholder_text = tr("t.ex. 123456")
    _client_id.add_theme_font_size_override("font_size", 20)
    _row(box, tr("Client ID"), tr("Siffrorna under My API Application."), _client_id)
    _client_secret = LineEdit.new()
    _client_secret.secret = true
    _client_secret.placeholder_text = tr("sparad – klistra in för att byta") if Strava.client_secret != "" else tr("klistra in")
    _client_secret.add_theme_font_size_override("font_size", 20)
    _row(box, tr("Client Secret"), tr("Visas aldrig igen här. Dela den inte med någon."), _client_secret)

    var actions := Style.hbox(12)
    var save := Style.button(tr("Spara uppgifterna"), "secondary", 20)
    save.pressed.connect(_save_strava_app)
    actions.add_child(save)
    _link_button = Style.button(tr("Koppla Strava"), "primary", 20)
    _link_button.pressed.connect(func(): Strava.begin_login())
    actions.add_child(_link_button)
    _unlink_button = Style.button(tr("Koppla från"), "secondary", 20)
    _unlink_button.pressed.connect(func(): Strava.unlink())
    actions.add_child(_unlink_button)
    box.add_child(actions)
    _strava_state = Style.label("", 20, Style.ACCENT, 700)
    _strava_state.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    box.add_child(_strava_state)
    Strava.changed.connect(_refresh_strava)
    _refresh_strava()


func _save_strava_app() -> void:
    var secret := _client_secret.text if _client_secret.text.strip_edges() != "" else Strava.client_secret
    Strava.set_app(_client_id.text, secret)
    _client_secret.text = ""
    _client_secret.placeholder_text = tr("sparad – klistra in för att byta")


func _refresh_strava() -> void:
    _link_button.disabled = not Strava.has_app()
    _link_button.text = tr("Koppla om Strava") if Strava.is_linked() else tr("Koppla Strava")
    _unlink_button.visible = Strava.is_linked()
    var state := ""
    if Strava.is_linked():
        state = tr("Kopplad%s.") % (tr(" som ") + Strava.athlete_name if Strava.athlete_name != "" else "")
    elif Strava.has_app():
        state = tr("Inte kopplad än.")
    else:
        state = tr("Fyll i Client ID och Client Secret och tryck Spara.")
    if Strava.status != "":
        state += "  " + Strava.status
    _strava_state.text = state


var _calibrate: Button
var _trainer_pick: OptionButton
var _trainer_ids: Array[String] = []
var _trainer_names: Array[String] = []
var _trainer_sig := ""
var _calibrate_state: Label


func _process(_delta: float) -> void:
    if _calibrate and is_instance_valid(_calibrate):
        var link = Ride.trainer_link()
        var busy: bool = link != null and str(link.spindown.get("state", "")) in ["begärd", "trampa", "sluta"]
        _calibrate.disabled = link == null or not link.ready_to_ride() or busy or Ride.state == Ride.State.RIDING \
            or link.can_spindown() == false
        # Yellow only while it tells you what to do on the bike; otherwise a quiet note.
        var step := str(link.spindown.get("state", "")) if link else ""
        var color: Color = Style.TEXT_DIM
        if link == null:
            _calibrate_state.text = tr("Välj Trainer via Bluetooth för att kalibrera.")
        elif Ride.state == Ride.State.RIDING:
            _calibrate_state.text = tr("Kalibrera mellan turerna, inte mitt i en.")
        elif link.can_spindown() == false:
            _calibrate_state.text = tr("%s kalibreras inte härifrån, bara i tillverkarens app (Wahoo-appen för KICKR).") \
                % str(link.status.get("trainer", tr("Trainern")))
        else:
            _calibrate_state.text = link.describe_spindown()
            color = Style.ACCENT if step == "klar" else Color("ffd34d") if step in ["begärd", "trampa", "sluta", "fel"] else color
        _calibrate_state.add_theme_color_override("font_color", color)
    if _trainer_pick and is_instance_valid(_trainer_pick):
        _refresh_trainers()
    if _status:
        _status.text = tr("Status: ") + Ride.source_description()
        var link = Ride.trainer_link()
        _status.add_theme_color_override("font_color", Style.ACCENT if link and link.ready_to_ride()
            else Color("ffd34d") if link and link.needs_attention() else Style.TEXT_DIM)
    if _click_status:
        if not Settings.click_enabled:
            _click_status.text = tr("Click är avstängda.")
        elif Ride.bridge:
            _click_status.text = tr("Status: ") + Ride.bridge.describe_clicks()
        else:
            _click_status.text = tr("Status: Cykelbrygga startas inte i utvecklarläge.")
