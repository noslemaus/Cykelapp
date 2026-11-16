extends Node3D
## The battle's sounds, made in code when the tank is taken (no sound files): the cannon's boom, a
## burst, the Pysare's hiss, an alien plasma shot, a hit on the armour, the base alarm and the
## UFO's hum. Sounds in the world play from where they happen.

const RATE := 22050

var _streams := {}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
    _rng.seed = 47
    # About a second of work, so it runs beside the game; sounds asked for before then are skipped.
    _task = WorkerThreadPool.add_task(_build)


var _task := -1


func _exit_tree() -> void:
    if _task >= 0:
        WorkerThreadPool.wait_for_task_completion(_task)
        _task = -1


func _build() -> void:
    var built := {}
    built["kanon"] = _make(1.2, _kanon)
    built["small"] = _make(1.6, _smell)
    built["pys"] = _make(1.4, _pys)
    built["plasma"] = _make(0.3, _plasma)
    built["traff"] = _make(0.5, _traff)
    built["larm"] = _make(2.6, _larm)
    built["mg"] = _make(0.14, _mg)
    built["kast"] = _make(0.22, _kast)
    built["gong"] = _make(3.0, _gong)
    var hum := _make(1.0, _hum)
    hum.loop_mode = AudioStreamWAV.LOOP_FORWARD
    hum.loop_end = RATE
    built["hum"] = hum
    _streams = built


## Play `name` at `at` (or everywhere when at is null).
func play(name: String, at = null, volume_db := 0.0) -> void:
    if not _streams.has(name):
        return
    if at == null:
        var p := AudioStreamPlayer.new()
        p.stream = _streams[name]
        p.volume_db = volume_db - 4.0
        add_child(p)
        p.play()
        p.finished.connect(p.queue_free)
        return
    var p3 := AudioStreamPlayer3D.new()
    p3.stream = _streams[name]
    p3.volume_db = volume_db
    p3.unit_size = 18.0
    p3.max_distance = 600.0
    p3.position = at
    add_child(p3)
    p3.play()
    p3.finished.connect(p3.queue_free)


## A looping sound that follows `node` (the UFO's hum).
func attach_loop(name: String, node: Node3D, volume_db := 0.0) -> bool:
    if not _streams.has(name):
        return false
    var p3 := AudioStreamPlayer3D.new()
    p3.stream = _streams[name]
    p3.volume_db = volume_db
    p3.unit_size = 25.0
    p3.max_distance = 500.0
    node.add_child(p3)
    p3.play()
    return true


func _make(seconds: float, voice: Callable) -> AudioStreamWAV:
    var n := int(seconds * RATE)
    var data := PackedByteArray()
    data.resize(n * 2)
    var state := {"lp": 0.0, "lp2": 0.0, "phase": 0.0}
    for i in n:
        var t := float(i) / RATE
        var v: float = clampf(voice.call(t, state), -1.0, 1.0)
        data.encode_s16(i * 2, int(v * 32000.0))
    var s := AudioStreamWAV.new()
    s.format = AudioStreamWAV.FORMAT_16_BITS
    s.mix_rate = RATE
    s.stereo = false
    s.data = data
    return s


func _noise() -> float:
    return _rng.randf_range(-1.0, 1.0)


func _kanon(t: float, st: Dictionary) -> float:
    st["lp"] += (_noise() - st["lp"]) * lerpf(0.5, 0.04, minf(t * 3.0, 1.0))
    var thump := sin(TAU * (48.0 + 30.0 * exp(-t * 12.0)) * t) * exp(-t * 5.0)
    return (st["lp"] * 2.2 * exp(-t * 4.0) + thump * 0.9) * minf(t * 400.0, 1.0)


func _smell(t: float, st: Dictionary) -> float:
    st["lp"] += (_noise() - st["lp"]) * lerpf(0.35, 0.03, minf(t * 1.5, 1.0))
    var crackle := (_noise() if _rng.randf() < 0.02 * exp(-t * 2.0) else 0.0) * 0.6
    var thump := sin(TAU * (36.0 + 40.0 * exp(-t * 8.0)) * t) * exp(-t * 3.0)
    return (st["lp"] * 2.6 * exp(-t * 2.2) + thump + crackle) * minf(t * 300.0, 1.0)


func _pys(t: float, st: Dictionary) -> float:
    var x := _noise()
    st["lp"] += (x - st["lp"]) * 0.3
    var hiss: float = x - st["lp"]
    return hiss * 0.45 * minf(t * 1.2, 1.0) * (0.8 + 0.2 * sin(t * 60.0))


func _plasma(t: float, st: Dictionary) -> float:
    var f := 1500.0 * exp(-t * 8.0) + 220.0
    st["phase"] += TAU * f / RATE
    return signf(sin(st["phase"])) * 0.25 * exp(-t * 9.0)


func _traff(t: float, st: Dictionary) -> float:
    var ring := sin(TAU * 420.0 * t) * 0.5 + sin(TAU * 1130.0 * t) * 0.3 + sin(TAU * 2290.0 * t) * 0.2
    return (ring * exp(-t * 9.0) + _noise() * exp(-t * 60.0) * 0.6) * 0.8


func _mg(t: float, st: Dictionary) -> float:
    st["lp"] += (_noise() - st["lp"]) * 0.45
    var crack := _noise() * exp(-t * 90.0)
    var thump := sin(TAU * 110.0 * t) * exp(-t * 35.0)
    return (st["lp"] * exp(-t * 30.0) * 1.4 + crack * 0.8 + thump * 0.6) * minf(t * 2000.0, 1.0)


## A shuriken leaving the hand: a short rising whoosh.
func _kast(t: float, st: Dictionary) -> float:
    var x := _noise()
    st["lp"] += (x - st["lp"]) * 0.5
    var whoosh: float = x - st["lp"]
    return whoosh * 0.5 * sin(PI * t / 0.22)


## A temple gong for Japan's alarm.
func _gong(t: float, st: Dictionary) -> float:
    var env := exp(-t * 1.2) * minf(t * 60.0, 1.0)
    var wob := 1.0 + 0.01 * sin(TAU * 3.0 * t)
    return (sin(TAU * 110.0 * t * wob) * 0.5 + sin(TAU * 196.0 * t) * 0.25 + sin(TAU * 293.0 * t) * 0.15
        + sin(TAU * 415.0 * t) * 0.1 * exp(-t * 3.0)) * env * 0.7


func _larm(t: float, st: Dictionary) -> float:
    var f := 650.0 if fmod(t, 0.8) < 0.4 else 870.0
    st["phase"] += TAU * f / RATE
    var env := minf(t * 8.0, 1.0) * minf((2.6 - t) * 4.0, 1.0)
    return (sin(st["phase"]) * 0.6 + signf(sin(st["phase"])) * 0.1) * env * 0.5


func _hum(t: float, st: Dictionary) -> float:
    var wob := sin(TAU * 3.0 * t) * 0.3
    return (sin(TAU * 90.0 * t + wob) * 0.4 + sin(TAU * 93.0 * t) * 0.3 + sin(TAU * 181.0 * t) * 0.15) * 0.6
