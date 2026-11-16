extends RefCounted
## The power curve: the best average watts held for each duration in a ride (one value per second).
## A ride's curve and the all-time bests both use DURATIONS; FTP comes from the best 20 minutes.

const DURATIONS := [5, 15, 30, 60, 120, 300, 600, 1200, 1800, 3600]
## The four shown as personal records on the summary and in the garage.
const KEY := [5, 60, 300, 1200]
const FTP_SHARE := 0.95      # FTP = 95 % of the best 20 minutes (the common field test rule)


## Best average watts for every duration the ride is long enough for: {"5": 612.0, …}.
static func of(seconds: PackedFloat32Array) -> Dictionary:
    var n := seconds.size()
    var sums := PackedFloat64Array()
    sums.resize(n + 1)
    sums[0] = 0.0
    for i in n:
        sums[i + 1] = sums[i] + maxf(seconds[i], 0.0)
    var result := {}
    for d in DURATIONS:
        if d > n:
            break
        var best := 0.0
        for i in range(0, n - d + 1):
            best = maxf(best, sums[i + d] - sums[i])
        result[str(d)] = best / d
    return result


## FTP estimate from a curve, or 0 when the ride was shorter than 20 minutes.
static func ftp_from(curve: Dictionary) -> int:
    return roundi(float(curve.get("1200", 0.0)) * FTP_SHARE)


static func label(d: int) -> String:
    if d < 60:
        return "%d s" % d
    return "%d min" % (d / 60)
