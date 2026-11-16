extends Node
## The music, autoloaded as `Musik`: six stems of one 32-second loop (French touch with 80s Tour de
## France electro, made in SoundCraft by assets/ljud/musik.py) that play in sync. Which stems are
## heard follows how hard you ride, like a band joining in:
##
##   menus              the whole tune, gently: pad, chords, bass, a soft beat and the hook
##   resting in a ride  the pad and soft chords
##   zone 1             pad and bass
##   zone 2             + the beat
##   zone 3             + the chord stabs
##   zone 4             + 16th hats, open hats and fills
##   zone 5–6           + the lead (arpeggio and hook)
##
## The zone comes from your power over the last ten seconds against FTP; going up happens after
## two seconds there, going down after six, so a short spike or a breath does not jerk the music.
## Paused, or not pedalling, it settles back to the pad. Settings.music_volume sets the level.
##
## Every world has three songs of its own with an 80s feel (assets/ljud/latar.py, listed in
## res://audio/musik/latar.json), plus the first song ("Klassikern"). Settings.music_choice says
## per world which to play or "blanda" (a new one each time you enter the world). In the menus the
## chosen world's song plays; the gym screen plays the first song.

const Zones = preload("res://core/zones.gd")
const STEMS := ["matta", "bas", "trummor", "ackord", "extra", "melodi"]
## Volume (dB) of each stem per level; -80 = silent. Level 0 is the menus and resting.
const LEVELS := [
    [-2.0, -80.0, -80.0, -9.0, -80.0, -80.0],
    [0.0, -3.0, -80.0, -80.0, -80.0, -80.0],
    [0.0, 0.0, -2.0, -80.0, -80.0, -80.0],
    [-3.0, 0.0, 0.0, 0.0, -80.0, -80.0],
    [-6.0, 0.0, 0.0, 0.0, 0.0, -80.0],
    [-8.0, 0.0, 0.0, 0.0, 0.0, 0.0],
    [-2.0, -3.0, -8.0, -3.0, -80.0, -4.0],
]
const MENU := 6                # the menus' own mix (the last row above)
const FADE_DB_PER_S := 30.0
const BASE_DB := -5.0          # the stems together, under the game's sounds

var level := 0                 # what the music plays now (0–5, 6 = the menus)
var _want := 0
var _want_for := 0.0
var _player: AudioStreamPlayer
var _sync: AudioStreamSynchronized
var _db := PackedFloat32Array()
var _power := PackedFloat32Array()   # the last ten seconds, one value per second
var _second := 0.0
var _idle := 0.0
var songs := {}               # id → {"name", "en", "world", "bpm", "folder"} from latar.json
var song := ""                # the song playing now
var _next_song := ""          # fading out towards this one
var _world := "-"             # the world whose music plays ("" = gym screen)
var _last_pick := {}          # world → the song "blanda" picked last time


func _ready() -> void:
    # Tests and headless runs have no sound to play.
    if DisplayServer.get_name() == "headless":
        return
    if AudioServer.get_bus_index("Musik") < 0:
        AudioServer.add_bus()
        AudioServer.set_bus_name(AudioServer.bus_count - 1, "Musik")
    var path := "res://audio/musik/latar.json"
    if FileAccess.file_exists(path):
        var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
        if parsed is Dictionary:
            songs = parsed
    if not songs.has("original"):
        songs["original"] = {"name": "Klassikern", "en": "The Classic", "world": "", "folder": ""}
    _player = AudioStreamPlayer.new()
    _player.bus = "Musik"
    add_child(_player)
    for i in STEMS.size():
        _db.append(-80.0)
    apply_volume()
    Settings.changed.connect(apply_volume)
    # A new song choice, or (in the menus) a new world chosen on the start screen, plays at once.
    Settings.changed.connect(func(): set_world(_world if Ride.state == Ride.State.RIDING else Settings.world, true))
    set_world(Settings.world)


## The songs of a world, in order ("" = the gym screen: just the first song).
func songs_for(world_id: String) -> Array:
    var list := []
    for id in songs:
        if songs[id].get("world", "") == world_id and world_id != "":
            list.append(id)
    return list


## Play the music of this world (on entering it, and in the menus for the chosen world).
func set_world(world_id: String, settings_changed := false) -> void:
    if _player == null:
        return
    if world_id == _world and not settings_changed:
        return
    var changed_world := world_id != _world
    _world = world_id
    var choice := str(Settings.music_choice.get(world_id, "blanda"))
    var own := songs_for(world_id)
    var pick := "original"
    if songs.has(choice) and (choice in own or choice == "original"):
        pick = choice
    elif not own.is_empty():
        if settings_changed and not changed_world and song in own and choice == "blanda":
            return                    # already playing one of this world's songs
        var pool := own.filter(func(id): return id != _last_pick.get(world_id, ""))
        pick = pool[randi() % pool.size()] if not pool.is_empty() else own[0]
        _last_pick[world_id] = pick
    if pick != song:
        _next_song = pick


func _load_song(id: String) -> void:
    var folder: String = songs.get(id, {}).get("folder", "")
    var base := "res://audio/musik/" + (folder + "/" if folder != "" else "")
    _sync = AudioStreamSynchronized.new()
    _sync.stream_count = STEMS.size()
    for i in STEMS.size():
        _sync.set_sync_stream(i, load(base + STEMS[i] + ".wav"))
        _sync.set_sync_stream_volume(i, -80.0)
        _db[i] = -80.0
    _player.stream = _sync
    _player.play()
    song = id


func _exit_tree() -> void:
    if _player:
        _player.stop()
        _player.stream = null
    _sync = null


func apply_volume() -> void:
    var bus := AudioServer.get_bus_index("Musik")
    if bus < 0:
        return
    var v: float = Settings.music_volume
    AudioServer.set_bus_mute(bus, v <= 0.001)
    AudioServer.set_bus_volume_db(bus, BASE_DB + linear_to_db(maxf(v, 0.001)))


func _process(delta: float) -> void:
    if _player == null:
        return
    var real := delta / maxf(Engine.time_scale, 0.001)    # fades in real time, also when fast-forwarding
    _follow_ride(delta)
    if _next_song != "":
        # Fade the old song out quickly, then start the new one from silence.
        var quiet := true
        for i in STEMS.size():
            _db[i] = move_toward(_db[i], -80.0, 60.0 * real)
            quiet = quiet and _db[i] <= -79.0
            if _sync:
                _sync.set_sync_stream_volume(i, _db[i])
        if quiet or _sync == null:
            _load_song(_next_song)
            _next_song = ""
        return
    if _sync == null:
        return
    for i in STEMS.size():
        var target: float = LEVELS[level][i]
        _db[i] = move_toward(_db[i], target, FADE_DB_PER_S * real)
        _sync.set_sync_stream_volume(i, _db[i])


## Pick the level from the ride: zone of the ten-second power, with the hold times.
func _follow_ride(delta: float) -> void:
    var riding := Ride.state == Ride.State.RIDING
    if not riding:
        _power.clear()
        _set_want(MENU, delta)
        return
    _second += delta
    if _second >= 1.0:
        _second = 0.0
        _power.append(Ride.power)
        if _power.size() > 10:
            _power.remove_at(0)
    _idle = _idle + delta if Ride.power < 5.0 else 0.0
    if Ride.paused or _idle > 4.0 or _power.is_empty():
        _set_want(0, delta)
        return
    var sum := 0.0
    for p in _power:
        sum += p
    var zone := Zones.zone(sum / _power.size() / float(maxi(Settings.ftp, 1)))
    _set_want(clampi(zone + 1, 1, 5), delta)


func _set_want(want: int, delta: float) -> void:
    if want != _want:
        _want = want
        _want_for = 0.0
    _want_for += delta
    var hold := 2.0 if _want > level else 6.0
    if _want == MENU or level == MENU:
        hold = 0.3              # into and out of the menus at once
    if _want != level and _want_for >= hold:
        level = _want
