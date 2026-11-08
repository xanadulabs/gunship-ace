extends RefCounted
## Every tunable number and every pure rule. No nodes here, so the probe can test it headless.
## Frame: Godot Y-up. Yaw 0 faces -Z. Positive yaw turns the nose toward -X (left).

# ------------------------------------------------------------------ flight
const BANDS := 3                     # 0 nap-of-earth, 1 low, 2 high
const BAND_NAMES: Array[String] = ["NAP", "LOW", "HIGH"]
const BAND_Y: Array[float] = [0.0, 6.5, 13.0]   # sprite lift above the hover height
const HOVER_Y := 2.2                 # skid height in world meters at band 0
const CLIMB_RATE := 9.0              # m/s of visual climb between bands
const MAX_SPEED := 12.0
const ACCEL := 20.0
const DRAG := 1.6
const REVERSE_FACTOR := 0.6
const STRAFE_FACTOR := 0.75
const YAW_RATE := 165.0              # degrees per second
const TILT_MAX := 12.0
const HIND_RADIUS := 1.6
const EDGE_MARGIN := 6.0             # the Hind stays this far inside the map edge

# ------------------------------------------------------------------ resources
const ARMOR_MAX := 100.0
const FUEL_MAX := 100.0
const FUEL_PER_SEC := 0.5            # three minutes and twenty seconds of flight from full
const FUEL_WASH_FACTOR := 1.6
const LIVES := 3
const RESPAWN_SEC := 2.8
const AUTOROTATE_SEC := 2.4

const PICKUP_RADIUS := 2.8
const PICKUP_FUEL := 45.0
const PICKUP_ARMOR := 40.0
const PICKUP_AMMO := {"gun": 300, "rocket": 16, "atgm": 2}

const CREW_CAPACITY := 6
const WINCH_SEC := 1.1
const WINCH_RADIUS := 3.6
const WINCH_MAX_SPEED := 3.0
const LZ_RADIUS := 6.0
const UNLOAD_SEC := 0.45

# ------------------------------------------------------------------ wash
const WASH_RADIUS := 7.5
const WASH_MAX_SPEED := 4.0          # above this speed the wash does not bite
const WASH_DECAY := 0.7              # tip lost per second once out of the wash
const TIP_SEC := 0.45                # tipping frame before the wreck

# ------------------------------------------------------------------ weapons
const WEAPONS := {
	"gun": {"ammo": 600, "rate": 0.1, "speed": 75.0, "range": 34.0, "damage": 1.0, "cone": 24.0},
	"rocket": {"ammo": 32, "rate": 0.32, "speed": 42.0, "range": 40.0, "damage": 9.0, "cone": 9.0, "splash": 3.6},
	"atgm": {"ammo": 6, "rate": 1.0, "speed": 30.0, "range": 52.0, "damage": 34.0, "cone": 50.0, "turn": 4.0},
}
const ARMORED_GUN_FACTOR := 0.15     # the chin gun barely scratches armor

# ------------------------------------------------------------------ enemies
# bands: which Hind heights the weapon can reach. wash: flip, shake or none.
# tip: how fast the wash fills the tip meter at the center of the disc.
const UNITS := {
	"soldier": {"hp": 1.0, "radius": 0.9, "speed": 1.6, "weapon": "rifle", "wash": "flip", "tip": 5.0, "score": 25, "armored": false},
	"jeep": {"hp": 8.0, "radius": 2.2, "speed": 6.0, "weapon": "mg", "wash": "flip", "tip": 1.5, "score": 100, "armored": false},
	"technical": {"hp": 12.0, "radius": 2.4, "speed": 5.0, "weapon": "hmg", "wash": "flip", "tip": 1.05, "score": 150, "armored": false},
	"truck": {"hp": 16.0, "radius": 2.8, "speed": 4.2, "weapon": "", "wash": "flip", "tip": 0.42, "tip_reach": 5.0, "score": 150, "armored": false},
	"aaa": {"hp": 14.0, "radius": 2.6, "speed": 0.0, "weapon": "flak", "wash": "none", "tip": 0.0, "score": 250, "armored": false, "turret": true},
	"zsu": {"hp": 34.0, "radius": 3.0, "speed": 3.2, "weapon": "flak", "wash": "shake", "tip": 0.0, "score": 400, "armored": true, "turret": true},
	"sam": {"hp": 20.0, "radius": 2.6, "speed": 0.0, "weapon": "sam", "wash": "none", "tip": 0.0, "score": 400, "armored": false, "turret": true},
	"tank": {"hp": 40.0, "radius": 3.2, "speed": 3.0, "weapon": "cannon", "wash": "shake", "tip": 0.0, "score": 500, "armored": true, "turret": true},
	"radar": {"hp": 30.0, "radius": 3.0, "speed": 0.0, "weapon": "", "wash": "none", "tip": 0.0, "score": 500, "armored": false, "block": true},
	"depot": {"hp": 36.0, "radius": 4.0, "speed": 0.0, "weapon": "", "wash": "none", "tip": 0.0, "score": 600, "armored": false, "block": true},
	"bunker": {"hp": 60.0, "radius": 4.5, "speed": 0.0, "weapon": "", "wash": "none", "tip": 0.0, "score": 1000, "armored": true, "block": true},
	"building": {"hp": 26.0, "radius": 3.6, "speed": 0.0, "weapon": "", "wash": "none", "tip": 0.0, "score": 50, "armored": false, "block": true},
}

const ENEMY_WEAPONS := {
	"rifle": {"range": 15.0, "cool": 2.2, "damage": 2.0, "speed": 30.0, "bands": [0, 1], "burst": 1, "spread": 0.06},
	"mg": {"range": 18.0, "cool": 2.6, "damage": 2.0, "speed": 32.0, "bands": [0, 1], "burst": 3, "spread": 0.07},
	"hmg": {"range": 21.0, "cool": 2.8, "damage": 2.5, "speed": 34.0, "bands": [0, 1], "burst": 4, "spread": 0.07},
	"flak": {"range": 26.0, "cool": 2.8, "damage": 3.0, "speed": 40.0, "bands": [0, 1, 2], "burst": 3, "spread": 0.09},
	"cannon": {"range": 22.0, "cool": 3.8, "damage": 12.0, "speed": 30.0, "bands": [0], "burst": 1, "spread": 0.02},
	"sam": {"range": 38.0, "cool": 6.5, "damage": 22.0, "speed": 17.0, "bands": [1, 2], "burst": 1, "spread": 0.0, "turn": 1.7},
}
const SHOT_HIT_RADIUS := 1.7
const SAM_LIFE := 6.0

# ------------------------------------------------------------------ camera
const CAM_OFFSET := Vector3(14, 12, 14)
const CAM_SIZE: Array[float] = [40.0, 50.0, 62.0]
const CAM_LEAD := 0.55
# Standing sprites sit this far toward the camera. In an orthographic view that moves
# nothing on screen, but it keeps the ground from clipping the lower half of tall art.
const SPRITE_LIFT := Vector3(14, 12, 14) / 23.216 * 22.0
const SHADOW_TRAVEL := Vector3(0.495196, -0.820071, -0.286817)
const INK := Color(28.0 / 255.0, 22.0 / 255.0, 16.0 / 255.0, 1.0)
const PAPER := Color(244.0 / 255.0, 232.0 / 255.0, 208.0 / 255.0, 1.0)
const ALERT := Color(0.86, 0.28, 0.16, 1.0)
const GOOD := Color(0.56, 0.74, 0.32, 1.0)


# ================================================================== helpers

static func band_y(band: int) -> float:
	return BAND_Y[clampi(band, 0, BANDS - 1)]


static func band_of_lift(lift: float) -> float:
	# Fractional band from the visual lift, for the camera and shadow.
	if lift <= BAND_Y[1]:
		return lift / BAND_Y[1]
	return 1.0 + (lift - BAND_Y[1]) / (BAND_Y[2] - BAND_Y[1])


static func yaw_forward(yaw_deg: float) -> Vector3:
	var yaw := deg_to_rad(yaw_deg)
	return Vector3(-sin(yaw), 0.0, -cos(yaw))


static func yaw_right(yaw_deg: float) -> Vector3:
	return yaw_forward(yaw_deg).cross(Vector3.UP)


static func yaw_to_deg(dir: Vector3) -> float:
	return rad_to_deg(atan2(-dir.x, -dir.z))


static func facing_index(yaw_deg: float) -> int:
	return posmod(int(round(yaw_deg / 45.0)), 8)


static func flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


static func angle_off(from_yaw_deg: float, origin: Vector3, target: Vector3) -> float:
	# Signed degrees between the nose and the target. Positive is to the left.
	var to := flat(target - origin)
	if to.length_squared() < 0.0001:
		return 0.0
	return wrapf(yaw_to_deg(to) - from_yaw_deg, -180.0, 180.0)


# ================================================================== flight

static func step_velocity(vel: Vector3, wish_local: Vector2, yaw_deg: float, delta: float) -> Vector3:
	# wish_local.x is strafe (right +), wish_local.y is thrust (forward +). Both -1..1.
	var fwd := yaw_forward(yaw_deg)
	var right := yaw_right(yaw_deg)
	var thrust := wish_local.y
	if thrust < 0.0:
		thrust *= REVERSE_FACTOR
	var wish := fwd * thrust + right * wish_local.x * STRAFE_FACTOR
	if wish.length() > 1.0:
		wish = wish.normalized()
	var next := vel * exp(-DRAG * delta)
	next += wish * ACCEL * delta
	if next.length() > MAX_SPEED:
		next = next.normalized() * MAX_SPEED
	if wish.length_squared() < 0.0001 and next.length() < 0.08:
		next = Vector3.ZERO
	return next


static func circle_hits_rect(x: float, z: float, radius: float, r: Rect2) -> bool:
	var cx := clampf(x, r.position.x, r.end.x)
	var cz := clampf(z, r.position.y, r.end.y)
	var dx := x - cx
	var dz := z - cz
	return dx * dx + dz * dz <= radius * radius


static func blocked_at(x: float, z: float, band: int, blockers: Array) -> bool:
	if band >= 2:
		return false
	for r in blockers:
		if circle_hits_rect(x, z, HIND_RADIUS, r):
			return true
	return false


static func slide(from: Vector3, to: Vector3, band: int, blockers: Array, half_size: float) -> Dictionary:
	## Move from -> to, sliding along walls one axis at a time. Returns pos and hit.
	var lim := half_size - EDGE_MARGIN
	var goal := Vector3(clampf(to.x, -lim, lim), 0.0, clampf(to.z, -lim, lim))
	var edge := not is_equal_approx(goal.x, to.x) or not is_equal_approx(goal.z, to.z)
	if not blocked_at(goal.x, goal.z, band, blockers):
		return {"pos": goal, "hit": edge, "edge": edge}
	var try_x := Vector3(goal.x, 0.0, from.z)
	if not blocked_at(try_x.x, try_x.z, band, blockers):
		return {"pos": try_x, "hit": true, "edge": edge}
	var try_z := Vector3(from.x, 0.0, goal.z)
	if not blocked_at(try_z.x, try_z.z, band, blockers):
		return {"pos": try_z, "hit": true, "edge": edge}
	return {"pos": from, "hit": true, "edge": edge}


# ================================================================== fuel and wash

static func fuel_drain(washing: bool) -> float:
	return FUEL_PER_SEC * (FUEL_WASH_FACTOR if washing else 1.0)


static func wash_strength(band: int, speed: float) -> float:
	## 0..1. Only at nap height, and only while slow.
	if band != 0:
		return 0.0
	return clampf(1.0 - speed / WASH_MAX_SPEED, 0.0, 1.0)


static func tip_rate(kind: String, dist: float, strength: float) -> float:
	var info: Dictionary = UNITS.get(kind, {})
	if info.is_empty() or str(info["wash"]) != "flip" or strength <= 0.0:
		return 0.0
	var reach := float(info.get("tip_reach", WASH_RADIUS))
	if dist > reach:
		return 0.0
	var falloff := sqrt(clampf(1.0 - dist / reach, 0.0, 1.0))
	return float(info["tip"]) * strength * falloff


static func shakes(kind: String) -> bool:
	var info: Dictionary = UNITS.get(kind, {})
	return not info.is_empty() and str(info["wash"]) != "none"


# ================================================================== weapons

static func damage_to(kind: String, weapon: String, base: float) -> float:
	var info: Dictionary = UNITS.get(kind, {})
	if weapon == "gun" and bool(info.get("armored", false)):
		return base * ARMORED_GUN_FACTOR
	return base


static func pick_target(origin: Vector3, yaw_deg: float, targets: Array, cone: float, max_range: float) -> int:
	## Index of the target nearest the nose inside the cone, weighted toward close ones.
	var best := -1
	var best_score := 1.0e9
	for i in targets.size():
		var t: Vector3 = targets[i]
		var d := flat(t - origin).length()
		if d < 1.0 or d > max_range:
			continue
		var off := absf(angle_off(yaw_deg, origin, t))
		if off > cone:
			continue
		var score := off * 1.5 + d * 0.6
		if score < best_score:
			best_score = score
			best = i
	return best


static func can_reach(weapon: String, band: int) -> bool:
	var info: Dictionary = ENEMY_WEAPONS.get(weapon, {})
	if info.is_empty():
		return false
	return (info["bands"] as Array).has(band)


static func lead_point(shooter: Vector3, target: Vector3, target_vel: Vector3, speed: float) -> Vector3:
	var d := (target - shooter).length()
	var t := d / maxf(speed, 1.0)
	return target + target_vel * t * 0.8


static func splash(dist: float, radius: float) -> float:
	if dist >= radius:
		return 0.0
	return 1.0 - dist / radius * 0.6


# ================================================================== text

static func time_text(sec: float) -> String:
	var s := int(sec)
	return "%d:%02d" % [s / 60, s % 60]
