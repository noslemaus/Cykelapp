extends RefCounted
## Routes (rutter): ways to ride a world's lap with their own start, length,
## climbing and segments. They run on the lap's road: a route starts at a point on the lap and is
## done after its length (whole laps, or a part of the lap with chosen climbs or sprints). The chosen
## route per world is Settings.routes; free rides and workouts alike start where it starts.
##
## Length, climbing and the segments on each route are worked out from the real worlds by
## `--kartor` (main.gd) into res://world/rutter.json, so the menus can show them without building a
## world.

const FACTS_PATH := "res://world/rutter.json"

## Per world: id, name, start (metres into the lap), and "laps" or "length" (metres).
const LIST := {
    "skargarden": [
        {"id": "varvet", "name": "Hela varvet", "start": 0.0, "laps": 1.0,
            "text": "Hela skärgården: Klipporna, kyrkbyn, fyren, Storberget och broarna."},
        {"id": "kustvagen", "name": "Kustvägen till fyren", "start": 0.0, "length": 5500.0,
            "text": "Från starten längs kusten, genom kyrkbyn och upp till fyren."},
        {"id": "tre_berg", "name": "Tre berg", "start": 3900.0, "length": 3400.0,
            "text": "Kyrkbacken, Fyrberget och Storberget i ett svep. Kort och brant."},
        {"id": "sprintarna", "name": "Sprintarnas runda", "start": 7400.0, "length": 3900.0,
            "text": "Platt och snabbt över broarna: Storöspurten, Långöbron och Strandspurten."},
        {"id": "dubbelvarvet", "name": "Dubbelvarvet", "start": 0.0, "laps": 2.0,
            "text": "Två hela varv. Andra varvet cyklar spöket med dig."},
        {"id": "stora_turen", "name": "Stora skärgårdsturen", "start": 0.0, "laps": 3.0,
            "text": "Tre varv runt hela skärgården för den långa dagen."},
    ],
    "egypten": [
        {"id": "varvet", "name": "Hela varvet", "start": 0.0, "laps": 1.0,
            "text": "Alexandria, pyramiderna, öknen, Kungadalen, Aswan och Kairo."},
        {"id": "pyramiderna", "name": "Till pyramiderna", "start": 0.0, "length": 3700.0,
            "text": "Längs promenaden och upp till Giza, med spurt på platån."},
        {"id": "oknen", "name": "Genom öknen", "start": 4400.0, "length": 3900.0,
            "text": "Dynbacken, Vita öknens kritspurt och klättringen in i Kungadalen."},
        {"id": "nilen", "name": "Längs Nilen", "start": 8300.0, "length": 4000.0,
            "text": "Katarakten vid Aswan, palmdjungeln och basaren i Kairo."},
        {"id": "dubbelvarvet", "name": "Dubbelvarvet", "start": 0.0, "laps": 2.0,
            "text": "Två hela varv genom Egypten."},
    ],
    "japan": [
        {"id": "varvet", "name": "Hela varvet", "start": 0.0, "laps": 1.0,
            "text": "Tokyo, gamla stan, sjön under Fuji, Irohabackarna, landsbygden och hamnen."},
        {"id": "irohabackarna", "name": "Irohabackarna", "start": 2400.0, "length": 2500.0,
            "text": "Tempelbacken, sjöspurten och de slingrande Irohabackarna."},
        {"id": "landsbygden", "name": "Landsbygden", "start": 6000.0, "length": 2800.0,
            "text": "Från slottet ut bland teodlingarna och upp till gasshobyn."},
        {"id": "neonstaden", "name": "Neonstaden", "start": 10900.0, "length": 2600.0,
            "text": "Kustspurten, neonet i Tokyo och Odaibaspurten. Snabbt och platt."},
        {"id": "dubbelvarvet", "name": "Dubbelvarvet", "start": 0.0, "laps": 2.0,
            "text": "Två hela varv genom Japan."},
    ],
}

const XP_BASE := 50          # a route ridden to the end, plus XP_PER_KM for each kilometre
const XP_PER_KM := 5

static var _facts := {}


static func for_world(world_id: String) -> Array:
    return LIST.get(world_id, [])


## The route chosen for a world in `choices` (Settings.routes), the first route when none is; {} for
## the gym screen or an unknown world.
static func chosen(world_id: String, choices: Dictionary) -> Dictionary:
    var list := for_world(world_id)
    if list.is_empty():
        return {}
    var want := str(choices.get(world_id, "varvet"))
    for r in list:
        if r["id"] == want:
            return r
    return list[0]


static func find(world_id: String, route_id: String) -> Dictionary:
    for r in for_world(world_id):
        if r["id"] == route_id:
            return r
    return {}


## The route's length in metres on a lap of `lap_length`.
static func length_of(route: Dictionary, lap_length: float) -> float:
    if route.has("length"):
        return float(route["length"])
    return float(route.get("laps", 1.0)) * lap_length


## {"km", "hm", "segments": [names]} from res://world/rutter.json, or {} before `--kartor` has run.
static func facts(world_id: String, route_id: String) -> Dictionary:
    if _facts.is_empty() and FileAccess.file_exists(FACTS_PATH):
        var parsed = JSON.parse_string(FileAccess.get_file_as_string(FACTS_PATH))
        if parsed is Dictionary:
            _facts = parsed
    return _facts.get(world_id, {}).get(route_id, {})


## Climbing and the segments passed on a route, from a built world: the lap's road heights and its
## segments ({"km", "hm", "segments"}). Used by `--kartor` and the tests.
static func measure(world, route: Dictionary) -> Dictionary:
    var total := length_of(route, world.length)
    var start := float(route["start"])
    var climb := 0.0
    var step: float = world.STEP
    var last: float = world.sample(start)["pos"].y
    var d := step
    while d <= total:
        var y: float = world.sample(start + d)["pos"].y
        climb += maxf(y - last, 0.0)
        last = y
        d += step
    var names: Array = []
    for seg in world.segments():
        # A segment counts when the route rides it from its start to its end (on any lap).
        var from: float = fposmod(float(seg["from"]) - start, world.length)
        var length: float = float(seg["to"]) - float(seg["from"])
        if from + length <= total and not seg["name"] in names:
            names.append(seg["name"])
    return {"km": snappedf(total / 1000.0, 0.1), "hm": roundi(climb), "segments": names}


static func xp_for(route_length: float) -> int:
    return XP_BASE + XP_PER_KM * roundi(route_length / 1000.0)
