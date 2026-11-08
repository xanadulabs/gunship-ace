extends RefCounted
## Every tunable number and every pure rule. No nodes here, so the probe can test it headless.
## The floor is the original design (MODE_BIBLE.md, "Minimums"). The campaign builds on top of it.
## Frame: Godot Y-up. Yaw 0 faces -Z. Positive yaw turns the nose toward -X (left).

# ------------------------------------------------------------------ flight
const BANDS := 3                     # 0 ground, 1 one step up, 2 two steps up
const BAND_NAMES: Array[String] = ["Ground", "One step up", "Two steps up"]
const BAND_Y: Array[float] = [0.0, 6.5, 13.0]
const CLIMB_SEC := 0.85              # one step of climb
const MAX_SPEED := 9.5
const DRAG := 2.0                    # MAX_SPEED * DRAG balances the drag, so a hold sits on the cap
const SHOVE := 7.5                   # a tap is one shove
const STILL_SPEED := 0.55            # under this she is still
const YAW_RATE := 180.0              # degrees per second while Q or E is held
const TILT_MAX := 12.0
const TILT_LAG := 3.0
const HIND_RADIUS := 1.8
const EDGE_MARGIN := 6.0

# Next slice in the original design: a lighter Hind burns less fuel and answers faster.
const WEIGHT_EMPTY := 0.75           # weight with no fuel and no ammo; full is 1.0

# ------------------------------------------------------------------ resources
const HEALTH_START := 8
const ENEMY_SHOT := 2                # an enemy shot removes 2
const FUEL_START := 100.0
const FUEL_PER_SEC := 0.5
const FUEL_ATTACK_PER_SEC := 1.0     # the attack drain is faster
const LIVES := 3
const RESPAWN_SEC := 2.8
const LAND_SEC := 2.2                # autorotation on empty fuel

const PICKUP_RADIUS := 2.8
const PICKUP_FUEL := 45.0
const PICKUP_HEALTH := 4
const PICKUP_AMMO := {"gun": 80, "rocket": 16, "atgm": 2}

const CREW_CAPACITY := 6
const WINCH_SEC := 1.1
const WINCH_RADIUS := 3.6
const LZ_RADIUS := 6.0
const UNLOAD_SEC := 0.45

# ------------------------------------------------------------------ wash
const WASH_RADIUS := 7.0
const WASH_DECAY := 0.7
const TIP_SEC := 0.45

# ------------------------------------------------------------------ the chin gun
const GUN_RANGE := 36.0
const GUN_DAMAGE := 4                # the gun removes 4
const GUN_SWEET := 20.0              # inside 20 degrees the gun slews and fires
const GUN_ARC := 60.0                # out to 60 it is slower; past that the shot misses
const GUN_WAIT_NEAR := 0.25
const GUN_WAIT_FAR := 0.9
const GUN_SPEED := 75.0

const WEAPONS := {
	"gun": {"ammo": 240},
	"rocket": {"ammo": 32, "rate": 0.32, "speed": 42.0, "range": 40.0, "damage": 6.0, "cone": 9.0, "splash": 3.6},
	"atgm": {"ammo": 6, "rate": 1.0, "speed": 30.0, "range": 52.0, "damage": 16.0, "cone": 50.0, "turn": 4.0},
}
const ARMORED_GUN_FACTOR := 0.25

# ------------------------------------------------------------------ enemies
# Points: a jeep has 4, a technical 6, a truck 10. The campaign units sit on the same scale.
# wash: flip, shake or none. The wash flips a jeep or a technical and shakes a truck.
const UNITS := {
	"soldier": {"hp": 1.0, "radius": 0.9, "speed": 1.4, "weapon": "rifle", "wash": "flip", "tip": 5.0, "score": 25, "armored": false},
	"jeep": {"hp": 4.0, "radius": 2.2, "speed": 4.5, "weapon": "mg", "wash": "flip", "tip": 1.6, "score": 100, "armored": false},
	"technical": {"hp": 6.0, "radius": 2.4, "speed": 4.0, "weapon": "hmg", "wash": "flip", "tip": 1.2, "score": 150, "armored": false},
	"truck": {"hp": 10.0, "radius": 2.8, "speed": 4.2, "weapon": "", "wash": "shake", "tip": 0.0, "score": 150, "armored": false},
	"aaa": {"hp": 8.0, "radius": 2.6, "speed": 0.0, "weapon": "flak", "wash": "none", "tip": 0.0, "score": 250, "armored": false},
	"zsu": {"hp": 16.0, "radius": 3.0, "speed": 3.0, "weapon": "flak", "wash": "shake", "tip": 0.0, "score": 400, "armored": true},
	"sam": {"hp": 10.0, "radius": 2.6, "speed": 0.0, "weapon": "sam", "wash": "none", "tip": 0.0, "score": 400, "armored": false},
	"tank": {"hp": 20.0, "radius": 3.2, "speed": 3.0, "weapon": "cannon", "wash": "shake", "tip": 0.0, "score": 500, "armored": true},
	"radar": {"hp": 16.0, "radius": 3.0, "speed": 0.0, "weapon": "", "wash": "none", "tip": 0.0, "score": 500, "armored": false, "block": true},
	"depot": {"hp": 20.0, "radius": 4.0, "speed": 0.0, "weapon": "", "wash": "none", "tip": 0.0, "score": 600, "armored": false, "block": true},
	"bunker": {"hp": 32.0, "radius": 4.5, "speed": 0.0, "weapon": "", "wash": "none", "tip": 0.0, "score": 1000, "armored": true, "block": true},
	"building": {"hp": 12.0, "radius": 3.6, "speed": 0.0, "weapon": "", "wash": "none", "tip": 0.0, "score": 50, "armored": false, "block": true},
}

# Every enemy shot removes 2. A vehicle shoots inside 10 m. Air defence reaches further.
# bands: which heights the weapon can reach.
const ENEMY_WEAPONS := {
	"rifle": {"range": 10.0, "cool": 4.2, "speed": 28.0, "bands": [0, 1], "burst": 1, "spread": 0.14},
	"mg": {"range": 10.0, "cool": 3.6, "speed": 30.0, "bands": [0, 1], "burst": 1, "spread": 0.1},
	"hmg": {"range": 10.0, "cool": 3.2, "speed": 32.0, "bands": [0, 1], "burst": 1, "spread": 0.09},
	"cannon": {"range": 10.0, "cool": 4.6, "speed": 28.0, "bands": [0, 1], "burst": 1, "spread": 0.02},
	"flak": {"range": 24.0, "cool": 4.2, "speed": 38.0, "bands": [0, 1, 2], "burst": 1, "spread": 0.12},
	"sam": {"range": 36.0, "cool": 8.0, "speed": 16.0, "bands": [1, 2], "burst": 1, "spread": 0.0, "turn": 1.6},
}
const SHOT_HIT_RADIUS := 1.4
const SAM_LIFE := 6.0

# ------------------------------------------------------------------ camera
const CAM_OFFSET := Vector3(14, 12, 14)
const CAM_SIZE: Array[float] = [36.0, 48.0, 62.0]
const CAM_LEAD := 0.5
# Standing sprites sit this far toward the camera. In an orthographic view that moves
# nothing on screen, but it keeps the ground from clipping the lower half of tall art.
const SPRITE_LIFT := Vector3(14, 12, 14) / 23.216 * 22.0
const SHADOW_TRAVEL := Vector3(0.495196, -0.820071, -0.286817)
const INK := Color(28.0 / 255.0, 22.0 / 255.0, 16.0 / 255.0, 1.0)
const PAPER := Color(244.0 / 255.0, 232.0 / 255.0, 208.0 / 255.0, 1.0)
const ALERT := Color(0.86, 0.28, 0.16, 1.0)
const GOOD := Color(0.56, 0.74, 0.32, 1.0)

# ------------------------------------------------------------------ the left plate
const LINES: Array[String] = [
	"W moves forward.",
	"A moves left.",
	"S moves back.",
	"D moves right.",
	"Q turns left.",
	"E turns right.",
	"R goes up.",
	"F goes down.",
	"Left click fires.",
]
const EXTRA_LINES: Array[String] = [
	"Right click fires rockets.",
	"Middle click fires a missile.",
	"Tab shows the map.",
	"F1 hides this plate.",
]


# ================================================================== helpers

static func band_y(band: int) -> float:
	return BAND_Y[clampi(band, 0, BANDS - 1)]


static func band_of_lift(lift: float) -> float:
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
	## Signed degrees between the nose and the target. Positive is to the left.
	var to := flat(target - origin)
	if to.length_squared() < 0.0001:
		return 0.0
	return wrapf(yaw_to_deg(to) - from_yaw_deg, -180.0, 180.0)


# ================================================================== flight

static func weight(fuel: float, ammo_frac: float) -> float:
	## 1.0 full, WEIGHT_EMPTY with no fuel and no ammo. Fuel is most of it.
	var load := 0.7 * clampf(fuel / FUEL_START, 0.0, 1.0) + 0.3 * clampf(ammo_frac, 0.0, 1.0)
	return WEIGHT_EMPTY + (1.0 - WEIGHT_EMPTY) * load


static func wish_dir(wish_local: Vector2, yaw_deg: float) -> Vector3:
	## wish_local.x right (+), y forward (+). W, A, S and D all push the same.
	var w := yaw_forward(yaw_deg) * wish_local.y + yaw_right(yaw_deg) * wish_local.x
	return w.normalized() if w.length_squared() > 0.0001 else Vector3.ZERO


static func step_velocity(vel: Vector3, wish_local: Vector2, yaw_deg: float, delta: float, w := 1.0) -> Vector3:
	## Heavy: she starts slow and stops slow. A held key sits on the speed cap.
	var next := vel * exp(-DRAG / w * delta)
	var dir := wish_dir(wish_local, yaw_deg)
	if dir != Vector3.ZERO:
		next += dir * (MAX_SPEED * DRAG / w) * delta
		if next.length() > MAX_SPEED:
			next = next.normalized() * MAX_SPEED
	elif next.length() < 0.05:
		next = Vector3.ZERO
	return next


static func shove(vel: Vector3, dir: Vector3, w := 1.0) -> Vector3:
	## A tap is one shove.
	var next := vel + dir * SHOVE / w
	if next.length() > MAX_SPEED:
		next = next.normalized() * MAX_SPEED
	return next


static func circle_hits_rect(x: float, z: float, radius: float, r: Rect2) -> bool:
	var cx := clampf(x, r.position.x, r.end.x)
	var cz := clampf(z, r.position.y, r.end.y)
	var dx := x - cx
	var dz := z - cz
	return dx * dx + dz * dz <= radius * radius


static func blocked_at(x: float, z: float, band: int, blockers: Array) -> String:
	## A tree or a building stops her on the ground and one step up. Two steps up is clear.
	## blockers: [{"r": Rect2, "kind": "tree" or "building"}]. Returns the kind, or "".
	if band >= 2:
		return ""
	for b in blockers:
		if circle_hits_rect(x, z, HIND_RADIUS, b["r"]):
			return str(b["kind"])
	return ""


static func slide(from: Vector3, to: Vector3, band: int, blockers: Array, half_size: float) -> Dictionary:
	## Move from -> to, sliding along walls one axis at a time.
	## Returns pos, hit, and reason: "map", "tree", "building" or "".
	var lim := half_size - EDGE_MARGIN
	var goal := Vector3(clampf(to.x, -lim, lim), 0.0, clampf(to.z, -lim, lim))
	var edge := not is_equal_approx(goal.x, to.x) or not is_equal_approx(goal.z, to.z)
	var reason := blocked_at(goal.x, goal.z, band, blockers)
	if reason == "":
		return {"pos": goal, "hit": edge, "reason": "map" if edge else ""}
	var try_x := Vector3(goal.x, 0.0, from.z)
	if blocked_at(try_x.x, try_x.z, band, blockers) == "":
		return {"pos": try_x, "hit": true, "reason": reason}
	var try_z := Vector3(from.x, 0.0, goal.z)
	if blocked_at(try_z.x, try_z.z, band, blockers) == "":
		return {"pos": try_z, "hit": true, "reason": reason}
	return {"pos": from, "hit": true, "reason": reason}


# ================================================================== fuel and wash

static func wash_mode(band: int, moving: bool) -> String:
	## Ground and still: attack. One step up: wind. Otherwise off.
	if band <= 0 and not moving:
		return "attack"
	if band == 1:
		return "wind"
	return "off"


static func fuel_per_sec(mode: String, w := 1.0) -> float:
	return (FUEL_ATTACK_PER_SEC if mode == "attack" else FUEL_PER_SEC) * w


static func tip_rate(kind: String, dist: float) -> float:
	## Flip rate inside the attack wash. A truck only shakes; it does not tip.
	var info: Dictionary = UNITS.get(kind, {})
	if info.is_empty() or str(info["wash"]) != "flip" or dist > WASH_RADIUS:
		return 0.0
	return float(info["tip"]) * sqrt(clampf(1.0 - dist / WASH_RADIUS, 0.0, 1.0))


static func shakes(kind: String) -> bool:
	var info: Dictionary = UNITS.get(kind, {})
	return not info.is_empty() and str(info["wash"]) != "none"


# ================================================================== weapons

static func gun_wait(angle_deg: float) -> float:
	var a := absf(angle_deg)
	if a <= GUN_SWEET:
		return GUN_WAIT_NEAR
	var t := clampf((a - GUN_SWEET) / (GUN_ARC - GUN_SWEET), 0.0, 1.0)
	return lerpf(GUN_WAIT_NEAR, GUN_WAIT_FAR, t)


static func gun_slew(origin: Vector3, yaw_deg: float, targets: Array, buildings: Array, band: int) -> Dictionary:
	## The chin gun picks the target nearest the nose inside 60 degrees and the gun range.
	## Below two steps up a building in the line stops the shot.
	## Returns index (or -1), angle, and notice ("" or a shot sentence).
	var best := -1
	var best_ang := 999.0
	var blocked := false
	for i in targets.size():
		var t: Vector3 = targets[i]
		var d := flat(t - origin).length()
		if d < 1.0 or d > GUN_RANGE:
			continue
		var ang := angle_off(yaw_deg, origin, t)
		if absf(ang) > GUN_ARC:
			continue
		if band < 2 and _line_blocked(origin, t, buildings):
			blocked = true
			continue
		if absf(ang) < absf(best_ang):
			best_ang = ang
			best = i
	if best >= 0:
		return {"index": best, "angle": best_ang, "notice": ""}
	if blocked:
		return {"index": -1, "angle": 0.0, "notice": shot_line("building")}
	return {"index": -1, "angle": 0.0, "notice": shot_line("miss")}


static func _line_blocked(a: Vector3, b: Vector3, rects: Array) -> bool:
	for r in rects:
		if segment_hits_rect(a.x, a.z, b.x, b.z, r):
			return true
	return false


static func segment_hits_rect(ax: float, az: float, bx: float, bz: float, r: Rect2) -> bool:
	var dx := bx - ax
	var dz := bz - az
	var t0 := 0.0
	var t1 := 1.0
	var p: Array[float] = [-dx, dx, -dz, dz]
	var q: Array[float] = [ax - r.position.x, r.end.x - ax, az - r.position.y, r.end.y - az]
	for i in 4:
		if absf(p[i]) < 0.00001:
			if q[i] < 0.0:
				return false
		else:
			var k := q[i] / p[i]
			if p[i] < 0.0:
				if k > t1:
					return false
				t0 = maxf(t0, k)
			else:
				if k < t0:
					return false
				t1 = minf(t1, k)
	return true


static func damage_to(kind: String, weapon: String, base: float) -> float:
	var info: Dictionary = UNITS.get(kind, {})
	if weapon == "gun" and bool(info.get("armored", false)):
		return base * ARMORED_GUN_FACTOR
	return base


static func pick_target(origin: Vector3, yaw_deg: float, targets: Array, cone: float, max_range: float) -> int:
	## For rockets and the missile: the target nearest the nose inside the cone.
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


# ================================================================== the sentences

static func fuel_line(left: float) -> String:
	return "Fuel %d" % (int(ceil(left)) if left > 0.0 else 0)


static func health_line(hp: int) -> String:
	return "Health %d" % hp


static func height_line(band: int) -> String:
	if band <= 0:
		return "Height is ground."
	if band == 1:
		return "Height is one step up."
	return "Height is two steps up."


static func wash_line(mode: String) -> String:
	if mode == "attack":
		return "Wash is on."
	if mode == "wind":
		return "Wind is on."
	return "Wash is off."


static func stop_line(reason: String) -> String:
	match reason:
		"tree":
			return "A tree stops the Hind."
		"building":
			return "A building stops the Hind."
		"map":
			return "The map stops the Hind."
		"ground":
			return "The ground stops the Hind."
		"top":
			return "The Hind stays up."
	return ""


static func shot_line(what: String) -> String:
	match what:
		"turning":
			return "The gun is turning."
		"miss":
			return "The shot misses."
		"building":
			return "A building stops the shot."
		"hit":
			return "The vehicle is hit."
		"destroyed":
			return "The vehicle is destroyed."
	return ""


static func end_line(phase: String) -> String:
	match phase:
		"landing":
			return "The Hind is landing."
		"landed":
			return "Landed."
		"down":
			return "Hind down."
		"clear":
			return "The area is clear."
	return ""


static func time_text(sec: float) -> String:
	var s := int(sec)
	return "%d:%02d" % [s / 60, s % 60]
