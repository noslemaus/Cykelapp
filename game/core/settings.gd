extends Node
## Rider profile and preferences, stored in user://settings.cfg. Autoloaded as `Settings`.

signal changed

const PATH := "user://settings.cfg"
const SafeFile = preload("res://core/safe_file.gd")
const HUD_FIELDS := {
    "cadence": "Kadens",
    "avg_power": "Snittwatt",
    "hr": "Puls",
    "kj": "Kilojoule",
    "max_power": "Maxwatt",
    "np": "NP (normaliserad watt)",
    "wkg": "Watt per kilo",
    "speed": "Fart",
}

var ftp := 200
var weight_kg := 75.0
# sim = pretend trainer, trainer = a real one via Cykelbrygga (Mac and Windows)
var source := "trainer" if OS.get_name() in ["macOS", "Windows"] else "sim"
var trainer_id := ""            # the bridge's id for the trainer picked in the settings ("" = first found)
var trainer_name := ""
var power_display := "3s"      # 3s average or instant
var cadence_guard := true      # lower the ERG target when cadence collapses
var hud_slots: Array = ["cadence", "avg_power", "hr", "kj"]
var world := "skargarden"       # the world you ride in ("" = gym screen only)
var persist := true              # false in developer runs: never write the settings file
var trainer_difficulty := 0.5   # share of the road's grade sent to the trainer in SIM
var click_enabled := true        # connect the Zwift Click pair through Cykelbrygga
var button_bindings := {}        # Click button → action (see Controls); missing = the default
var auto_ftp := true             # raise the FTP by itself when a ride shows a better 20 minutes
var language := "en"             # en (the default) or sv; the texts are in lang/texter.csv
var time_of_day := "kvall"       # morgon, dag, kvall (the worlds' own light), natt, klocka
var weather := "klart"           # klart, mulet, regn, dimma (world/atmosphere.gd)
var season := "sommar"           # sommar, host, vinter
var sound_on := true             # the game's sounds (the battle) on or off
var sound_volume := 0.8          # 0–1, on the master bus
var music_volume := 0.6          # 0–1, the ride music (core/musik.gd, bus "Musik")
var music_choice := {}           # world id → song id, or "blanda" (the default): see core/musik.gd
var fullscreen := false          # the window fills the screen (F11 switches); never in developer runs
var intro := true                # the AniCraft intro at start-up (main.gd)
var pacers := true               # pacer riders on the lap to ride with and draft (world/pacers.gd)
var routes := {}                 # world id → the chosen route's id (core/routes.gd); missing = the lap
## Developer runs (any command-line option) and headless test runs never start the bridge for the
## Clicks, so they cannot reach real hardware.
var dev_run := not OS.get_cmdline_user_args().is_empty()


## True when it is fine to start Cykelbrygga for the Clicks: a normal run with a window.
func hardware_ok() -> bool:
    return not dev_run and DisplayServer.get_name() != "headless"


func _ready() -> void:
    apply_language()
    apply_sound()
    var cfg := ConfigFile.new()
    if SafeFile.load_config(cfg, PATH) != OK:
        return
    # The same limits as the settings screen: a broken value must not divide by zero anywhere.
    ftp = clampi(int(cfg.get_value("profil", "ftp", ftp)), 50, 600)
    weight_kg = clampf(float(cfg.get_value("profil", "vikt", weight_kg)), 30.0, 200.0)
    source = str(cfg.get_value("hardvara", "kalla", source))
    trainer_id = str(cfg.get_value("hardvara", "trainer_id", trainer_id))
    trainer_name = str(cfg.get_value("hardvara", "trainer_namn", trainer_name))
    power_display = str(cfg.get_value("hardvara", "wattvisning", power_display))
    cadence_guard = bool(cfg.get_value("hardvara", "kadensskydd", cadence_guard))
    world = str(cfg.get_value("varld", "vald", world))
    trainer_difficulty = float(cfg.get_value("hardvara", "backkansla", trainer_difficulty))
    click_enabled = bool(cfg.get_value("knappar", "click", click_enabled))
    auto_ftp = bool(cfg.get_value("profil", "auto_ftp", auto_ftp))
    language = str(cfg.get_value("profil", "sprak", language))
    time_of_day = str(cfg.get_value("varld", "tid", time_of_day))
    weather = str(cfg.get_value("varld", "vader", weather))
    season = str(cfg.get_value("varld", "arstid", season))
    sound_on = bool(cfg.get_value("ljud", "pa", sound_on))
    sound_volume = float(cfg.get_value("ljud", "volym", sound_volume))
    music_volume = float(cfg.get_value("ljud", "musik", music_volume))
    var choice = cfg.get_value("ljud", "latar", {})
    if choice is Dictionary:
        music_choice = choice
    apply_sound()
    apply_language()
    var bindings = cfg.get_value("knappar", "bindningar", {})
    if bindings is Dictionary:
        button_bindings = bindings
    fullscreen = bool(cfg.get_value("skarm", "helskarm", fullscreen))
    intro = bool(cfg.get_value("skarm", "intro", intro))
    pacers = bool(cfg.get_value("varld", "pacers", pacers))
    var chosen_routes = cfg.get_value("varld", "rutter", {})
    if chosen_routes is Dictionary:
        routes = chosen_routes
    apply_window()
    var slots = cfg.get_value("hud", "falt", hud_slots)
    if slots is Array and slots.size() == 4:
        hud_slots = slots


## The game's language: English unless Swedish is chosen (the Swedish texts are the keys).
func apply_language() -> void:
    TranslationServer.set_locale(language if language in ["en", "sv"] else "en")


## Volume and mute on the master bus.
func apply_sound() -> void:
    AudioServer.set_bus_mute(0, not sound_on)
    AudioServer.set_bus_volume_db(0, linear_to_db(maxf(sound_volume, 0.001)))


## Full screen or a window. Developer and headless runs keep their window as it is.
func apply_window() -> void:
    if dev_run or DisplayServer.get_name() == "headless":
        return
    var want := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
    var now := DisplayServer.window_get_mode()
    var is_full := now == DisplayServer.WINDOW_MODE_FULLSCREEN or now == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
    if fullscreen != is_full:
        DisplayServer.window_set_mode(want)


func save() -> void:
    apply_sound()
    apply_language()
    apply_window()
    if not persist:
        changed.emit()
        return
    var cfg := ConfigFile.new()
    cfg.set_value("profil", "ftp", ftp)
    cfg.set_value("profil", "vikt", weight_kg)
    cfg.set_value("hardvara", "kalla", source)
    cfg.set_value("hardvara", "trainer_id", trainer_id)
    cfg.set_value("hardvara", "trainer_namn", trainer_name)
    cfg.set_value("hardvara", "wattvisning", power_display)
    cfg.set_value("hardvara", "kadensskydd", cadence_guard)
    cfg.set_value("hud", "falt", hud_slots)
    cfg.set_value("varld", "vald", world)
    cfg.set_value("hardvara", "backkansla", trainer_difficulty)
    cfg.set_value("knappar", "click", click_enabled)
    cfg.set_value("profil", "auto_ftp", auto_ftp)
    cfg.set_value("profil", "sprak", language)
    cfg.set_value("varld", "tid", time_of_day)
    cfg.set_value("varld", "vader", weather)
    cfg.set_value("varld", "arstid", season)
    cfg.set_value("ljud", "pa", sound_on)
    cfg.set_value("ljud", "volym", sound_volume)
    cfg.set_value("ljud", "musik", music_volume)
    cfg.set_value("ljud", "latar", music_choice)
    cfg.set_value("knappar", "bindningar", button_bindings)
    cfg.set_value("skarm", "helskarm", fullscreen)
    cfg.set_value("skarm", "intro", intro)
    cfg.set_value("varld", "pacers", pacers)
    cfg.set_value("varld", "rutter", routes)
    SafeFile.save_config(cfg, PATH)
    changed.emit()
