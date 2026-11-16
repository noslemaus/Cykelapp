extends RefCounted
## What can be earned and how levels work: bikes, jerseys, the battle vehicle's upgrades and the XP
## rules. Plain data with no autoloads, so the engine tests can load it (Progress uses it).

const MAX_LEVEL := 50

## Bikes: weight, drag area and rolling resistance on asphalt, gravel and terrain. They change the
## speed in the world, not how hard the trainer feels.
const BIKES := {
    "landsvag": {"name": "Landsvägscykeln", "level": 1, "kg": 8.4, "cda": 0.32,
        "crr": {"asfalt": 0.0040, "grus": 0.0085, "terrang": 0.016}, "frame": "c8302c",
        "text": "Allround. Snabb på asfalt, skakig i terrängen."},
    "klattring": {"name": "Klätterraketen", "level": 3, "kg": 6.8, "cda": 0.325,
        "crr": {"asfalt": 0.0040, "grus": 0.0085, "terrang": 0.016}, "frame": "eef0f3",
        "text": "Fjäderlätt. Bäst när det lutar uppåt."},
    "grus": {"name": "Grusracern", "level": 4, "kg": 9.4, "cda": 0.34,
        "crr": {"asfalt": 0.0048, "grus": 0.0058, "terrang": 0.0100}, "frame": "6b7a3c",
        "text": "Breda däck. Grusvägar går nästan som asfalt."},
    "aero": {"name": "Aerocykeln", "level": 6, "kg": 7.9, "cda": 0.295,
        "crr": {"asfalt": 0.0039, "grus": 0.0090, "terrang": 0.017}, "frame": "1f2124",
        "text": "Skär genom luften. Snabbast på flacken."},
    "mtb": {"name": "Mountainbiken", "level": 7, "kg": 11.8, "cda": 0.40,
        "crr": {"asfalt": 0.0065, "grus": 0.0068, "terrang": 0.0075}, "frame": "f08a24",
        "text": "Seg på asfalt, kung i terrängen när du åker fritt."},
    "stal": {"name": "Stålramen -86", "level": 8, "kg": 10.6, "cda": 0.335,
        "crr": {"asfalt": 0.0046, "grus": 0.0090, "terrang": 0.017}, "frame": "2fb8b0",
        "text": "Tour de France på 80-talet. Tung, vacker och rolig."},
    "tempo": {"name": "Tempocykeln", "level": 10, "kg": 8.9, "cda": 0.255,
        "crr": {"asfalt": 0.0039, "grus": 0.0095, "terrang": 0.020}, "frame": "1b3f8f",
        "text": "Ligg lågt och flyg. Tung i backarna."},
}
const BIKE_ORDER := ["landsvag", "klattring", "grus", "aero", "mtb", "stal", "tempo"]

## Jerseys: the main colour and the accent (the cross on the Swedish one). Unlocked by level or by
## what you do: climbs, sprints, a full lap in a world, beating your own ghost.
const JERSEYS := {
    "sverige": {"name": "Sverige", "main": "1f5aa6", "accent": "f2c230", "unlock": {"level": 1}},
    "midnatt": {"name": "Midnatt", "main": "1d2a4a", "accent": "c9d1dc", "unlock": {"level": 2}},
    "gul": {"name": "Gula tröjan", "main": "f7d117", "accent": "1f2124", "unlock": {"level": 5}},
    "neon": {"name": "Neon -86", "main": "ff3fa4", "accent": "2de2e6", "unlock": {"level": 8}},
    "svartguld": {"name": "Svart och guld", "main": "1c1d20", "accent": "d4a537", "unlock": {"level": 12}},
    "mastare": {"name": "Mästartröjan", "main": "f4f5f7", "accent": "2b6fd6", "unlock": {"level": 15}},
    "klatter": {"name": "Klättertröjan", "main": "f4f5f7", "accent": "d8262c", "unlock": {"climb": 10}},
    "gron": {"name": "Gröna tröjan", "main": "2e9e4f", "accent": "f4f5f7", "unlock": {"sprint": 10}},
    "skargard": {"name": "Falurött", "main": "a8322a", "accent": "f4f5f7", "unlock": {"lap": "skargarden"}},
    "egypten": {"name": "Sand och turkos", "main": "d9b77c", "accent": "1fa3a3", "unlock": {"lap": "egypten"}},
    "japan": {"name": "Soluppgång", "main": "f4f5f7", "accent": "c8102e", "unlock": {"lap": "japan"}},
    "spoke": {"name": "Spökjägaren", "main": "1a1f2b", "accent": "6fe8ff", "unlock": {"ghost": 1}},
}
const JERSEY_ORDER := ["sverige", "midnatt", "gul", "neon", "svartguld", "mastare", "klatter", "gron",
    "skargard", "egypten", "japan", "spoke"]

## The battle vehicle's upgrades, earned with points from the battles (all worlds together).
const UPGRADES := {
    "pansar": {"name": "Tjockare pansar", "points": 300, "text": "150 i pansar i stället för 100."},
    "laddning": {"name": "Snabbladdning", "points": 1000, "text": "Laddar om 30 % snabbare."},
    "sikte": {"name": "Bättre sikte", "points": 2000, "text": "Låser på mål i en bredare kon."},
    "sprang": {"name": "Kraftigare laddning", "points": 4000, "text": "Större sprängradie och 30 % mer skada."},
}
const UPGRADE_ORDER := ["pansar", "laddning", "sikte", "sprang"]

const WORLD_NAMES := {"skargarden": "Skärgården", "egypten": "Egypten", "japan": "Japan"}

## XP: one per kilojoule, plus these.
const XP_WORKOUT := 100
const XP_SEGMENT := 20
const XP_SEGMENT_PR := 50
const XP_LAP := 30
const XP_LAP_PR := 75
const XP_POWER_PB := 100
const XP_FTP := 200


## Total XP needed to reach a level: 500 for level 2, 1 500 for 3, 3 000 for 4 … (an hour's ride
## gives about 700).
static func xp_for(level: int) -> int:
    return 250 * (level - 1) * level


static func level_for(total: int) -> int:
    var level := 1
    while level < MAX_LEVEL and total >= xp_for(level + 1):
        level += 1
    return level
