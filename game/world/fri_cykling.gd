extends RefCounted
## Free riding ("Tryck ej här"): the rider goes wherever they steer, on the roads or straight out
## across the island. Steering turns the bike. With no steering on a road the bike follows it by
## itself (a gentle road assist), so riding the roads stays hands-free and leaving one only takes a
## firm turn. Water, houses, boulders and tree trunks stop the bike or make it glance off along
## them; granite slabs are ridden over. The grade under the wheels, smoothed and capped, is what the
## trainer feels.
##
## The world supplies: ride_height(x, z), free_at(x, z, radius), road_near(x, z) and, for the tank,
## knock_trees(x, z, radius, heading).

const TURN_RATE := 1.15        # radians per second at full steer
const ASSIST_RATE := 1.3       # radians per second the road assist may turn the bike
const ASSIST_LOOK := 9.0       # metres ahead on the road the assist aims for
const MAX_GRADE := 8.0         # percent: the most the trainer is asked for off the roads
const SUBSTEP := 0.8           # metres per collision test

var world
var pos := Vector3.ZERO        # where the wheels touch; y is the ground under them
var heading := Vector2(1, 0)   # unit direction in the x–z plane
var steer := 0.0               # -1 left … 1 right, set by the HUD every frame
var grade := 0.0               # percent along the heading, smoothed and capped
var slope := 0.0               # the same as a rise per metre, smoothed, for pitching the bike
var roll := 0.0                # sideways tilt (radians) for the tank
var radius := 0.4              # how wide the rider is for collisions (the tank is wider)
var road := {}                 # the road under the wheels (see world.road_near) or {} off road
var blocked := false           # true while something stops the bike
var distance := 0.0            # metres ridden freely
var _slide := 1.0              # which side to glance off to, kept while sliding along a shore


func _init(w) -> void:
    world = w


func start(p: Vector3, h: Vector2) -> void:
    pos = p
    heading = h.normalized()
    pos.y = world.ride_height(pos.x, pos.z)
    road = world.road_near(pos.x, pos.z)
    grade = 0.0
    slope = 0.0


## The heading as a 3D direction tilted with the slope (for the bike and the camera).
func direction() -> Vector3:
    return Vector3(heading.x, slope, heading.y).normalized()


func right() -> Vector3:
    return Vector3(-heading.y, 0.0, heading.x)


## Move `ds` metres on (the ride's distance since last frame).
func advance(ds: float, delta: float) -> void:
    _turn(ds, delta)
    blocked = false
    var remaining := clampf(ds, 0.0, 200.0)
    while remaining > 0.0:
        var step := minf(remaining, SUBSTEP)
        remaining -= step
        if not _step(step):
            blocked = true
            break
        distance += step
    pos.y = world.ride_height(pos.x, pos.z)
    road = world.road_near(pos.x, pos.z)
    _measure(delta)


func _turn(ds: float, delta: float) -> void:
    if steer != 0.0:
        heading = heading.rotated(steer * TURN_RATE * delta).normalized()
        return
    if ds <= 0.0 or road.is_empty() or road["d"] > float(road["half"]) + 0.6:
        return
    # Road assist: aim for a point a little ahead on the road, in the rider's lane.
    var along: Vector2 = road["dir"]
    var sense := 1.0 if along.dot(heading) >= 0.0 else -1.0
    if absf(along.dot(heading)) < 0.57:
        return      # crossing the road at a steep angle: leave the rider alone
    var target: Vector3 = world.road_ahead(road, sense, ASSIST_LOOK)
    var want := Vector2(target.x - pos.x, target.z - pos.z)
    if want.length() < 0.5:
        return
    var angle := heading.angle_to(want.normalized())
    var limit := ASSIST_RATE * delta
    heading = heading.rotated(clampf(angle, -limit, limit)).normalized()


## One collision step: straight on if free, otherwise glance off to the side that is open. Standing
## somewhere the bike should not be (in the water, say) any step up towards higher ground is allowed,
## so it can always get out again.
func _step(step: float) -> bool:
    var here := Vector2(pos.x, pos.z)
    var stuck: bool = not world.free_at(here.x, here.y, radius)
    var ground: float = world.ride_height(here.x, here.y)
    for turn in [0.0, 0.35, 0.7, 1.05, 1.4]:
        for side in ([1.0] if turn == 0.0 else [_slide, -_slide]):
            var dir := heading.rotated(turn * side)
            var to := here + dir * step * cos(turn * 0.8)
            if world.free_at(to.x, to.y, radius) or (stuck and world.ride_height(to.x, to.y) >= ground - 0.02):
                pos.x = to.x
                pos.z = to.y
                if turn > 0.0:
                    _slide = side
                    heading = heading.rotated(turn * side * 0.2).normalized()   # turn with the edge
                if world.has_method("knock_trees") and radius > 1.0:
                    world.knock_trees(to.x, to.y, radius + 0.6, heading)
                return true
    return false


## Grade along the heading and tilt across it, from the ground just ahead and behind.
func _measure(delta: float) -> void:
    var f := Vector2(heading.x, heading.y) * 2.5
    var ahead: float = maxf(world.ride_height(pos.x + f.x, pos.z + f.y), 0.0)
    var behind: float = maxf(world.ride_height(pos.x - f.x, pos.z - f.y), 0.0)
    var rise := clampf((ahead - behind) / 5.0, -0.4, 0.4)
    var k := 1.0 - exp(-delta / 0.6) if delta > 0.0 else 1.0
    slope = lerpf(slope, rise, k)
    grade = lerpf(grade, clampf(rise * 100.0, -MAX_GRADE, MAX_GRADE), k)
    var s := Vector2(-heading.y, heading.x) * 1.5
    var left_h: float = world.ride_height(pos.x - s.x, pos.z - s.y)
    var right_h: float = world.ride_height(pos.x + s.x, pos.z + s.y)
    roll = lerpf(roll, clampf(atan2(left_h - right_h, 3.0), -0.35, 0.35), k)
