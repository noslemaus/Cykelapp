extends RefCounted
## Training-load maths shared by workouts (planned) and rides (actual).


## Normalized power: 30 s rolling average, then the fourth-power mean.
## Shorter series than the window fall back to the plain average.
static func normalized(values: PackedFloat32Array) -> float:
    var n := values.size()
    if n == 0:
        return 0.0
    var window := 30
    if n < window:
        var total := 0.0
        for v in values:
            total += v
        return total / n
    var rolling := 0.0
    var acc := 0.0
    var count := 0
    for i in n:
        rolling += values[i]
        if i >= window:
            rolling -= values[i - window]
        if i >= window - 1:
            acc += pow(rolling / window, 4.0)
            count += 1
    return pow(acc / count, 0.25)


## Training stress score from duration, normalized power and FTP.
static func tss(seconds: float, np: float, ftp: float) -> float:
    if ftp <= 0.0:
        return 0.0
    var intensity := np / ftp
    return seconds / 3600.0 * intensity * intensity * 100.0


## Effort rating 1–5 in half steps, driven by intensity factor (0.55 → 1, 1.15 → 5).
static func effort(intensity_factor: float) -> float:
    var raw := clampf(1.0 + 4.0 * (intensity_factor - 0.55) / 0.6, 1.0, 5.0)
    return roundf(raw * 2.0) / 2.0
