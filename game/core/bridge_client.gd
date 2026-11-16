extends RefCounted
## Talks to Cykelbrygga.app (bridge/ in the repo) over UDP on localhost:
## telemetry arrives on 47010, commands go to 47011. Pings every second keep the bridge's
## safety watchdog happy; if the game stops pinging, the bridge releases the trainer itself.
## The bridge also reports Zwift Click buttons ({"t":"button"}); they queue up in `buttons`.
## With `controllers_only` (pretend trainer in the game) every ping tells the bridge to leave the
## trainer alone and only keep the Clicks.

const IN_PORT := 47010
const OUT_PORT := 47011

var power := 0.0
var cadence := 0.0
var hr := 0.0
var trainer_speed := 0.0
var status := {}
var error := ""
var controllers_only := false
## The trainer picked under Settings → Hardware (the bridge's id for it, and its name for the status);
## "" = the first smart trainer the bridge finds. Sent with every ping.
var wanted_trainer := ""
var wanted_name := ""
var buttons: Array = []         # [[id, down], …] since the last poll
## The calibration (spin down) as the bridge reports it: {"state": begärd | trampa | sluta | klar |
## fel, "low", "high" (km/h to pedal up to), "reason"}; {} before one is started.
var spindown := {}
var _udp := PacketPeerUDP.new()
var _ping_timer := 0.0
var _last_status_ms := 0
var _launched_ms := 0           # when the bridge was last started (0 = not started by the game)
var _launches := 0


func start(launch := true) -> void:
    if _udp.bind(IN_PORT, "127.0.0.1") != OK:
        error = tr("Port %d är upptagen. Kör ett annat program bryggan?") % IN_PORT
        return
    _udp.set_dest_address("127.0.0.1", OUT_PORT)
    if not launch:
        return
    if not bridge_exists():
        error = tr("Hittar inte Cykelbrygga.app. Kör bridge/build.sh först.") if OS.has_feature("editor") \
            else tr("Cykelbrygga saknas i appen, så trainern kan inte nås. Installera spelet på nytt.")
        return
    _launch()


## Mac: -g keeps it in the background; an already running bridge is reused. Windows: the bridge has
## no window and writes its log to user://cykelbrygga.log; a second one finds the port taken and quits.
func _launch() -> void:
    _launches += 1
    _launched_ms = Time.get_ticks_msec()
    if OS.get_name() == "Windows":
        OS.create_process(bridge_path(), ["--log", ProjectSettings.globalize_path("user://cykelbrygga.log")])
    else:
        OS.create_process("open", ["-g", bridge_path()])


## Where the bridge is. Windows: Cykelbrygga.exe beside Cykelapp.exe (bridge-windows/, put there by
## paketera.sh). Mac: Cykelbrygga.app inside the packaged game (Cykelapp.app/Contents/Helpers), else
## beside the project (bridge/, run from the editor or the command line).
static func bridge_path() -> String:
    if OS.get_name() == "Windows":
        return OS.get_executable_path().get_base_dir().path_join("Cykelbrygga.exe")
    var helper := OS.get_executable_path().get_base_dir().path_join("../Helpers/Cykelbrygga.app").simplify_path()
    if not OS.has_feature("editor") and DirAccess.dir_exists_absolute(helper):
        return helper
    return ProjectSettings.globalize_path("res://").path_join("../bridge/Cykelbrygga.app").simplify_path()


static func bridge_exists() -> bool:
    var path := bridge_path()
    return FileAccess.file_exists(path) if OS.get_name() == "Windows" else DirAccess.dir_exists_absolute(path)


func poll(dt: float) -> void:
    while _udp.get_available_packet_count() > 0:
        var msg = JSON.parse_string(_udp.get_packet().get_string_from_utf8())
        if typeof(msg) != TYPE_DICTIONARY:
            continue
        if msg.get("t") == "data":
            power = _num(msg.get("power"))
            cadence = _num(msg.get("cadence"))
            hr = _num(msg.get("hr"))
            trainer_speed = _num(msg.get("speed"))
        elif msg.get("t") == "status":
            status = msg
            _last_status_ms = Time.get_ticks_msec()
        elif msg.get("t") == "spindown":
            spindown = msg
        elif msg.get("t") == "button":
            buttons.append([str(msg.get("id", "")), bool(msg.get("down", false))])
    _ping_timer += dt
    if _ping_timer >= 1.0:
        _ping_timer = 0.0
        send({"cmd": "ping", "controllersOnly": controllers_only, "trainer": wanted_trainer})
        # A bridge that went away (stopped by macOS, closed) is started again, three times at most.
        if _launched_ms > 0 and not alive() and _launches < 3 \
                and Time.get_ticks_msec() - maxi(_launched_ms, _last_status_ms) > 12000:
            _launch()


## Buttons that arrived since the last call.
func take_buttons() -> Array:
    var out := buttons
    buttons = []
    return out


## One line about the Zwift Clicks.
func describe_clicks() -> String:
    if not alive():
        return tr("Startar Cykelbrygga…")
    var n := int(status.get("clicks", 0))
    if n == 0:
        return tr("Söker Zwift Click (tryck på en knapp för att väcka dem)")
    if status.get("clicksLocked", false):
        return tr("%d Click anslutna men låsta: anslut dem i Zwift-appen en stund (gäller ett dygn)") % n
    return tr("%d Click anslutna") % n


func _num(v) -> float:
    return 0.0 if v == null else float(v)


func send(command: Dictionary) -> void:
    if error != "":
        return
    var result := _udp.put_packet(JSON.stringify(command).to_utf8_buffer())
    if result != OK:
        push_warning("Kunde inte skicka %s till bryggan (fel %d)" % [command.get("cmd"), result])


func set_erg(watts: int) -> void:
    send({"cmd": "erg", "watts": watts})


## SIM: the grade in percent, the rolling resistance and the air drag (kg/m), see Ride.gear_factor.
func set_sim(grade: float, crr := 0.004, cw := 0.51) -> void:
    send({"cmd": "sim", "grade": grade, "crr": crr, "cw": cw})


## Calibrate the trainer: FTMS spin down (pedal up to a speed, stop, let it roll out).
func start_spindown() -> void:
    spindown = {"state": "begärd"}
    send({"cmd": "spindown"})


## Can the trainer be calibrated? true, false, or null while the bridge has not found out.
func can_spindown():
    return status.get("spindown")


## One line about the calibration for the settings page.
func describe_spindown() -> String:
    match str(spindown.get("state", "")):
        "begärd":
            return tr("Ber trainern om kalibrering …")
        "trampa":
            if spindown.has("high"):
                return tr("Trampa upp till %d km/h (nu %d km/h). Sluta när trainern säger till.") % [
                    roundi(float(spindown["high"])), roundi(trainer_speed)]
            return tr("Trampa upp i fart (nu %d km/h). Sluta när trainern säger till.") % roundi(trainer_speed)
        "sluta":
            return tr("Sluta trampa nu och låt svänghjulet rulla ut …")
        "klar":
            return tr("Kalibrerad! ✓")
        "fel":
            return tr("Kalibreringen gick inte: %s. Prova igen, eller kalibrera i Wahoo-appen.") % tr(str(spindown.get("reason", "")))
    return ""


func release() -> void:
    send({"cmd": "release"})


func stop() -> void:
    send({"cmd": "quit"})
    _udp.close()


## The trainers the bridge has seen: [{"id", "name", "smart"}, …] (smart = FTMS, can be controlled).
func trainers() -> Array:
    var list = status.get("trainers", [])
    return list if list is Array else []


## The bridge's id for the trainer it is connected to, or "".
func connected_trainer() -> String:
    var id = status.get("trainerId")
    return str(id) if id != null else ""


## Something the player has to do: allow Bluetooth, switch it on, or a bridge that does not answer.
func needs_attention() -> bool:
    if error != "":
        return true
    if not alive():
        return _launched_ms > 0 and Time.get_ticks_msec() - _launched_ms > 10000
    return str(status.get("trainerState", "")) in ["väntar på Bluetooth-behörighet", "ingen Bluetooth-behörighet",
        "Bluetooth avstängt", "ingen Bluetooth"]


func alive() -> bool:
    return _last_status_ms > 0 and Time.get_ticks_msec() - _last_status_ms < 3000


func ready_to_ride() -> bool:
    return alive() and status.get("trainerState", "") == "klar"


## One line for menus and the ride screen.
func describe() -> String:
    if error != "":
        return error
    if not alive():
        if _launched_ms > 0 and Time.get_ticks_msec() - _launched_ms > 10000:
            if OS.get_name() == "Windows":
                return tr("Cykelbrygga svarar inte. Kontrollera att Bluetooth är på och starta om spelet.")
            return tr("Cykelbrygga svarar inte. Tillåt Cykelapp under Systeminställningar → Integritet och säkerhet → Bluetooth och starta om spelet.")
        return tr("Startar Cykelbrygga…")
    var state := str(status.get("trainerState", ""))
    if state == "ingen Bluetooth-behörighet":
        return tr("Cykelapp får inte använda Bluetooth. Tillåt den under Systeminställningar → Integritet och säkerhet → Bluetooth.")
    if state == "väntar på Bluetooth-behörighet":
        return tr("macOS frågar om Cykelapp får använda Bluetooth. Välj Tillåt i rutan.")
    if state == "Bluetooth avstängt":
        return tr("Bluetooth är avstängt på datorn.")
    if state == "ingen Bluetooth":
        return tr("Datorn har ingen Bluetooth. En USB-dongel med Bluetooth 4.0 eller senare fungerar.")
    var trainer = status.get("trainer")
    var parts: Array[String] = []
    if trainer == null:
        parts.append(tr("Söker %s …") % wanted_name if wanted_trainer != "" and wanted_name != "" else tr("Söker trainer …"))
    elif state == "klar":
        parts.append(tr("✓ %s ansluten") % trainer)
    elif state == "ansluter":
        parts.append(tr("Ansluter till %s …") % trainer)
    else:
        parts.append("%s · %s" % [trainer, tr(state)])
    var strap = status.get("hr")
    parts.append(tr("puls: %s") % (strap if strap != null else tr("inget band")))
    if status.get("control", "ingen") != "ingen":
        parts.append(tr("kontroll: %s") % status.get("control"))
    if status.get("readOnly", false):
        parts.append("skrivskyddad")
    return " · ".join(parts)
