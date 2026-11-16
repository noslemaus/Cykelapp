extends RefCounted
## Virtual bike speed from rider power and road grade: gravity, rolling resistance and air drag,
## with inertia so speed changes smoothly. Defaults are a road bike on the hoods.

const G := 9.81
const AIR_DENSITY := 1.225
const WHEEL_INERTIA_KG := 1.2   # rotating wheels behave like a little extra mass

var rider_kg := 75.0
var bike_kg := 9.0
var cda := 0.32          # drag area m²
var crr := 0.004         # rolling resistance
var drivetrain := 0.976  # chain and bearing losses
var speed := 0.0         # m/s


func step(dt: float, power: float, grade_pct: float) -> float:
    var mass := rider_kg + bike_kg
    var angle := atan(grade_pct / 100.0)
    var resist := mass * G * (sin(angle) + crr * cos(angle)) + 0.5 * AIR_DENSITY * cda * speed * speed
    # Below 1 m/s the force is capped so a standing start does not divide by zero.
    var drive := maxf(power, 0.0) * drivetrain / maxf(speed, 1.0)
    var accel := (drive - resist) / (mass + WHEEL_INERTIA_KG)
    speed = maxf(0.0, speed + accel * dt)
    return speed
