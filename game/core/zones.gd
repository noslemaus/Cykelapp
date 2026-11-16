extends RefCounted
## Power zones as fractions of FTP (the Coggan split most training apps use).
## Z1 < 60 % <= Z2 < 76 % <= Z3 < 90 % <= Z4 < 105 % <= Z5 < 119 % <= Z6

const UPPER: Array[float] = [0.60, 0.76, 0.90, 1.05, 1.19]
const NAMES: Array[String] = ["Återhämtning", "Distans", "Tempo", "Tröskel", "VO2max", "Anaerob"]

static var COLORS: Array[Color] = [
    Color("7d8394"), Color("3d8fd6"), Color("45bf5c"),
    Color("f2c23a"), Color("f07b32"), Color("e0412e"),
]


static func zone(pct: float) -> int:
    for i in UPPER.size():
        if pct < UPPER[i]:
            return i
    return UPPER.size()


static func color(pct: float) -> Color:
    return COLORS[zone(pct)]
