extends RefCounted
## Pretend trainer and rider, so everything can be tested without sitting on the bike.
## The pretend rider aims for the ERG target (or `rider_target` in SIM) plus `bias`,
## which the W/S keys change. Power, cadence and heart rate get a little noise and lag.

var power := 0.0
var cadence := 0.0
var hr := 68.0
var erg_target := -1        # watts; -1 = not in ERG
var grade := 0.0
var rider_target := 150.0   # what the rider aims for when the trainer is not in ERG
var bias := 0.0
var _clock := 0.0
var _rng := RandomNumberGenerator.new()


func _init() -> void:
    _rng.seed = 7


func update(dt: float) -> void:
    _clock += dt
    var aim := maxf((float(erg_target) if erg_target >= 0 else rider_target) + bias, 0.0)
    var follow := clampf(dt * 1.5, 0.0, 1.0)
    power += (aim - power) * follow
    if aim <= 0.0:
        power = maxf(power - 50.0 * dt, 0.0)
    var wobble := sin(_clock * 1.7) * 4.0 + _rng.randf_range(-5.0, 5.0)
    if power < 1.0:
        wobble = 0.0
    power = maxf(power + wobble * clampf(dt * 3.0, 0.0, 1.0), 0.0)
    var target_cadence := 0.0 if aim <= 0.0 else 88.0 + sin(_clock * 0.31) * 3.0
    cadence += (target_cadence - cadence) * clampf(dt * 2.0, 0.0, 1.0)
    var target_hr := 62.0 + minf(power, 400.0) * 0.42
    hr += (target_hr - hr) * clampf(dt / 20.0, 0.0, 1.0)
