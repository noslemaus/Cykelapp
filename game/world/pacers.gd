extends Node3D
## Pacer riders on the lap: three riders at a steady watts per kilo who
## ride the world's road with the same physics as you (their watts against the grade and the air).
## Ride up close behind one (1–6 m) and you are in its draft: up to a third less air to push, so
## the same watts go faster, and in SIM the trainer feels it too (Ride.draft).
## One that falls far behind or gets far ahead joins you again a little way off, out of sight.

const Rider = preload("res://world/rider.gd")
const BikePhysics = preload("res://core/physics.gd")

const CREW := [
    {"name": "Lugna Lisa", "wkg": 1.8, "main": "3d8fd6", "accent": "f2f4f7", "frame": "eef0f3", "start": 60.0, "lane": -0.8},
    {"name": "Jämna Jonas", "wkg": 2.5, "main": "45bf5c", "accent": "1f2124", "frame": "1f2124", "start": -40.0, "lane": -1.6},
    {"name": "Snabba Stina", "wkg": 3.3, "main": "e0412e", "accent": "ffd34d", "frame": "c8302c", "start": 260.0, "lane": -0.8},
]
const KG := 72.0
const DRAFT_MAX := 0.33          # share of the air drag taken away right behind a rider
const DRAFT_FROM := 1.0          # metres behind the wheel where the draft starts …
const DRAFT_TO := 6.0            # … and where it has faded out
const REJOIN := 1600.0           # further away than this, a pacer joins you again
const REJOIN_AT := 350.0

var world: Node3D
var riders: Array = []           # [{"name", "wkg", "colour", "s", "speed", "node", "physics", "lane"}]


## Put the crew on the road around `s` (the lap distance you are at).
func setup(w: Node3D, s: float) -> void:
    world = w
    for c in CREW:
        var node := Rider.new()
        add_child(node)
        node.apply_look({"jersey": "", "main": Color(c["main"]), "accent": Color(c["accent"]), "bike": "landsvag",
            "frame": Color(c["frame"])})
        var physics := BikePhysics.new()
        physics.rider_kg = KG
        physics.bike_kg = 8.0
        physics.speed = 8.0
        riders.append({"name": c["name"], "wkg": c["wkg"], "colour": Color(c["main"]), "s": s + c["start"],
            "speed": 8.0, "node": node, "physics": physics, "lane": c["lane"]})


## Ride them on by `delta` seconds and return the draft you get at lap distance `me` (0 when riding
## free, or not right behind anyone).
func update(delta: float, me: float, on_lap: bool) -> float:
    var draft := 0.0
    for r in riders:
        var grade: float = world.grade_at(r["s"])
        # A steady effort that leans into the climbs a little and eases off on the descents.
        var watts: float = r["wkg"] * KG * (1.0 + clampf(grade / 6.0, -0.3, 0.15))
        r["speed"] = r["physics"].step(delta, watts, grade)
        r["s"] += r["speed"] * delta
        var gap: float = r["s"] - me
        if absf(gap) > REJOIN:
            r["s"] = me + (REJOIN_AT if gap > 0.0 else -REJOIN_AT)
            gap = r["s"] - me
        _place(r, delta)
        if on_lap and gap >= DRAFT_FROM and gap <= DRAFT_TO:
            draft = maxf(draft, DRAFT_MAX * (1.0 - (gap - DRAFT_FROM) / (DRAFT_TO - DRAFT_FROM)))
    return draft


func _place(r: Dictionary, delta: float) -> void:
    var here: Dictionary = world.sample(r["s"])
    var dir: Vector3 = here["dir"]
    var flat := Vector3(dir.x, 0.0, dir.z).normalized()
    var right := flat.cross(Vector3.UP).normalized()
    r["node"].place(here["pos"] + right * (world.RIDE_OFFSET + float(r["lane"])), dir)
    r["node"].animate(r["speed"], 86.0, delta)


## The riders near you for the HUD, nearest first: {"name", "wkg", "colour", "gap" (metres, > 0 ahead)}.
func nearby(me: float) -> Array:
    var out: Array = []
    for r in riders:
        out.append({"name": r["name"], "wkg": r["wkg"], "colour": r["colour"], "gap": r["s"] - me})
    out.sort_custom(func(a, b): return absf(a["gap"]) < absf(b["gap"]))
    return out


## Where they are, for the maps.
func dots() -> Array:
    var out: Array = []
    for r in riders:
        out.append({"pos": r["node"].global_position, "colour": r["colour"]})
    return out
