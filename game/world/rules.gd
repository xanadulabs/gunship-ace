extends RefCounted

# Yaw 0 faces -Z. Positive yaw turns the nose toward -X (left).

const STEP_M := 4.0
const MOVE_SEC := 0.16
const GROUND_Y := 2.15
const STEP_Y := 6.5
const CLEAR_Y := 12.0
const HIND_RADIUS := 1.8
const MAP_MIN := -28.0
const MAP_MAX := 28.0
const WASH_RADIUS := 7.0
const FUEL_START := 100.0
const FUEL_PER_SEC := 1.5
const FUEL_ATTACK_PER_SEC := 3.0
const HEALTH_START := 8
const ENEMY_SHOT := 2
const ENEMY_RANGE := 10.0
const ENEMY_COOLDOWN := 3.0
const BULLET_SPEED := 28.0
const GUN_RANGE := 36.0
const GUN_DAMAGE := 4
const LAND_SEC := 2.2
const ROTOR_SPEED := 18.0
const CAM_OFFSET := Vector3(14, 12, 14)
const CAM_GROUND := 36.0
const CAM_STEP := 48.0
const CAM_TOP := 62.0
const CAM_SIZE := 36.0
const WEIGHT := 1.0
const SHOVE := 7.5
const DRAG := 2.0
const MAX_SPEED := 9.5
const STILL_SPEED := 0.55
const YAW_RATE := 180.0
const TILT_MAX := 12.0
const TILT_LAG := 3.0
const CLIMB_SEC := 0.85
const HUB_HANG := 2.4
const GUN_SWEET := 20.0
const GUN_ARC := 60.0
const GUN_WAIT_NEAR := 0.25
const GUN_WAIT_FAR := 0.9
const FLIP_TORQUE := 16000.0
const TIP_DOT := 0.55
const INK := Color(28.0 / 255.0, 22.0 / 255.0, 16.0 / 255.0, 1.0)
const PAPER := Color(244.0 / 255.0, 232.0 / 255.0, 208.0 / 255.0, 1.0)

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


static func height_y(step: int) -> float:
	return GROUND_Y + float(step) * STEP_Y


static func yaw_forward(yaw_deg: float) -> Vector3:
	var yaw := deg_to_rad(yaw_deg)
	return Vector3(-sin(yaw), 0.0, -cos(yaw))


static func yaw_right(yaw_deg: float) -> Vector3:
	return yaw_forward(yaw_deg).cross(Vector3.UP)


static func yaw_to(dir: Vector3) -> float:
	# rotation.y that points the nose, local -Z, along dir.
	return atan2(-dir.x, -dir.z)


static func wash_mode(height_step: int, moving: bool) -> String:
	if height_step <= 0 and not moving:
		return "attack"
	if height_step == 1:
		return "wind"
	return "off"


static func wash_verb(kind: String) -> String:
	if kind == "truck":
		return "shake"
	return "flip"


static func fuel_per_sec(mode: String) -> float:
	if mode == "attack":
		return FUEL_ATTACK_PER_SEC
	return FUEL_PER_SEC


static func fuel_line(left: float) -> String:
	var shown := 0
	if left > 0.0:
		shown = int(ceil(left))
	return "Fuel %d" % shown


static func health_line(hp: int) -> String:
	return "Health %d" % hp


static func vehicles_line(left: int) -> String:
	return "Vehicles left %d" % left


static func height_line(step: int) -> String:
	if step <= 0:
		return "Height is ground."
	if step == 1:
		return "Height is one step up."
	return "Height is two steps up."


static func wash_line(mode: String) -> String:
	if mode == "attack":
		return "Wash is on."
	if mode == "wind":
		return "Wind is on."
	return "Wash is off."


static func stop_line(reason: String) -> String:
	if reason == "tree":
		return "A tree stops the Hind."
	if reason == "building":
		return "A building stops the Hind."
	if reason == "map":
		return "The map stops the Hind."
	if reason == "ground":
		return "The ground stops the Hind."
	if reason == "top":
		return "The Hind stays up."
	return ""


static func end_line(phase: String) -> String:
	if phase == "landing":
		return "The Hind is landing."
	if phase == "landed":
		return "Landed."
	if phase == "down":
		return "Hind down."
	if phase == "clear":
		return "The area is clear."
	return ""


static func vehicle_hp(kind: String) -> int:
	if kind == "truck":
		return 10
	if kind == "technical":
		return 6
	return 4


static func vehicle_half(kind: String) -> float:
	if kind == "truck":
		return 1.8
	if kind == "technical":
		return 1.5
	return 1.3


static func tipped(kind: String, up_dot: float) -> bool:
	if kind == "truck":
		return false
	return up_dot < TIP_DOT


static func flight_key(event: InputEvent) -> String:
	# Press and release. Echoes, modifiers, and arrows stay out.
	if not (event is InputEventKey):
		return ""
	var key := event as InputEventKey
	if key.echo:
		return ""
	if key.ctrl_pressed or key.alt_pressed or key.meta_pressed or key.shift_pressed:
		return ""
	if key.keycode == KEY_W:
		return "W"
	if key.keycode == KEY_A:
		return "A"
	if key.keycode == KEY_S:
		return "S"
	if key.keycode == KEY_D:
		return "D"
	if key.keycode == KEY_Q:
		return "Q"
	if key.keycode == KEY_E:
		return "E"
	if key.keycode == KEY_R:
		return "R"
	if key.keycode == KEY_F:
		return "F"
	return ""


static func action_key(event: InputEvent) -> String:
	if not (event is InputEventKey):
		return ""
	var key := event as InputEventKey
	if not key.pressed:
		return ""
	return flight_key(event)


static func coast(vel: Vector3, delta: float) -> Vector3:
	var drag := exp(-DRAG / WEIGHT * delta)
	var next := vel * drag
	if next.length() < 0.05:
		return Vector3.ZERO
	return next


static func hold_thrust(vel: Vector3, wish: Vector3, delta: float) -> Vector3:
	# MAX_SPEED * DRAG balances exponential drag, so a hold sits on the cap.
	if wish.length_squared() < 0.000001:
		return vel
	var accel := MAX_SPEED * DRAG / WEIGHT
	var next := vel + wish.normalized() * accel * delta
	if next.length() > MAX_SPEED:
		next = next.normalized() * MAX_SPEED
	return next


static func hold_yaw(yaw_deg: float, turn_left: bool, turn_right: bool, delta: float) -> float:
	var step := YAW_RATE * delta
	if turn_left:
		yaw_deg += step
	if turn_right:
		yaw_deg -= step
	return yaw_deg


static func is_fire(event: InputEvent) -> bool:
	if not (event is InputEventMouseButton):
		return false
	var mouse := event as InputEventMouseButton
	if mouse.button_index != MOUSE_BUTTON_LEFT or not mouse.pressed:
		return false
	if mouse.ctrl_pressed or mouse.alt_pressed or mouse.meta_pressed or mouse.shift_pressed:
		return false
	return true


static func is_again(event: InputEvent) -> bool:
	if not (event is InputEventKey):
		return false
	var key := event as InputEventKey
	if key.echo or not key.pressed:
		return false
	return key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER


static func destination(at: Vector3, yaw_deg: float, key: String) -> Vector3:
	var dir := Vector3.ZERO
	if key == "W":
		dir = yaw_forward(yaw_deg)
	elif key == "S":
		dir = -yaw_forward(yaw_deg)
	elif key == "D":
		dir = yaw_right(yaw_deg)
	elif key == "A":
		dir = -yaw_right(yaw_deg)
	return at + dir * STEP_M


static func block_reason(at: Vector3, dest: Vector3, blockers: Array, height_y: float = 0.0) -> String:
	var samples: Array[Vector3] = [dest, at.lerp(dest, 0.5)]
	for sample in samples:
		if sample.x < MAP_MIN or sample.x > MAP_MAX or sample.z < MAP_MIN or sample.z > MAP_MAX:
			return "map"
		for block in blockers:
			var kind := str(block["kind"])
			# Two steps up is clear of the pictures. The map edge still stops her.
			if height_y >= CLEAR_Y and (kind == "building" or kind == "tree"):
				continue
			if _circle_hits(sample.x, sample.z, HIND_RADIUS, block):
				return str(block["kind"])
	return ""


static func camera_size(step_f: float) -> float:
	var t := clampf(step_f, 0.0, 2.0)
	if t <= 1.0:
		return lerpf(CAM_GROUND, CAM_STEP, t)
	return lerpf(CAM_STEP, CAM_TOP, t - 1.0)


static func shadow_scale(step_f: float) -> float:
	return lerpf(1.0, 2.8, clampf(step_f, 0.0, 2.0) / 2.0)


static func wash_scale(mode: String) -> float:
	if mode == "attack":
		return 2.4
	if mode == "wind":
		return 1.7
	return 1.0


static func wash_scale_at(step_f: float) -> float:
	var t := clampf(step_f, 0.0, 2.0)
	if t <= 1.0:
		return lerpf(2.4, 1.7, t)
	return lerpf(1.7, 1.0, t - 1.0)


static func gun_wait(angle_deg: float) -> float:
	var a := absf(angle_deg)
	if a <= GUN_SWEET:
		return GUN_WAIT_NEAR
	var t := clampf((a - GUN_SWEET) / (GUN_ARC - GUN_SWEET), 0.0, 1.0)
	return lerpf(GUN_WAIT_NEAR, GUN_WAIT_FAR, t)


static func gun_turning_line() -> String:
	return "The gun is turning."


static func gun_slew(origin: Vector3, yaw_deg: float, targets: Array, blockers: Array, height_y: float = 0.0) -> Dictionary:
	var forward := yaw_forward(yaw_deg)
	var right := yaw_right(yaw_deg)
	var best := -1
	var best_ang := 999.0
	var blocked := false
	for i in targets.size():
		var item: Dictionary = targets[i]
		var rel := Vector3(item["x"], 0.0, item["z"]) - Vector3(origin.x, 0.0, origin.z)
		var ahead := rel.dot(forward)
		var side := rel.dot(right)
		var dist := Vector2(rel.x, rel.z).length()
		if dist < 1.0 or dist > GUN_RANGE:
			continue
		var angle := rad_to_deg(atan2(side, ahead))
		if absf(angle) > GUN_ARC:
			continue
		if height_y < CLEAR_Y and _segment_blocked(origin.x, origin.z, item["x"], item["z"], blockers):
			blocked = true
			continue
		if absf(angle) < absf(best_ang):
			best_ang = angle
			best = i
	if best >= 0:
		return {"index": best, "angle": best_ang, "notice": ""}
	if blocked:
		return {"index": -1, "angle": 0.0, "notice": "A building stops the shot."}
	return {"index": -1, "angle": 0.0, "notice": "The shot misses."}


static func _circle_hits(x: float, z: float, radius: float, block: Dictionary) -> bool:
	var min_x := float(block["min_x"])
	var max_x := float(block["max_x"])
	var min_z := float(block["min_z"])
	var max_z := float(block["max_z"])
	var cx := clampf(x, min_x, max_x)
	var cz := clampf(z, min_z, max_z)
	var dx := x - cx
	var dz := z - cz
	return dx * dx + dz * dz <= radius * radius


static func gun_pick(origin: Vector3, yaw_deg: float, targets: Array, blockers: Array) -> Dictionary:
	var forward := yaw_forward(yaw_deg)
	var right := yaw_right(yaw_deg)
	var best := -1
	var best_d := GUN_RANGE + 1.0
	var blocked := false
	for i in targets.size():
		var item: Dictionary = targets[i]
		var rel := Vector3(item["x"], 0.0, item["z"]) - Vector3(origin.x, 0.0, origin.z)
		var ahead := rel.dot(forward)
		var side := absf(rel.dot(right))
		if ahead < 1.0 or ahead > GUN_RANGE:
			continue
		if side > float(item["half"]) + 1.2:
			continue
		if _segment_blocked(origin.x, origin.z, item["x"], item["z"], blockers):
			blocked = true
			continue
		if ahead < best_d:
			best_d = ahead
			best = i
	if best >= 0:
		return {"index": best, "notice": ""}
	if blocked:
		return {"index": -1, "notice": "A building stops the shot."}
	return {"index": -1, "notice": "The shot misses."}


static func _segment_blocked(ax: float, az: float, bx: float, bz: float, blockers: Array) -> bool:
	for block in blockers:
		if str(block["kind"]) != "building":
			continue
		if segment_hits_rect(ax, az, bx, bz, float(block["min_x"]), float(block["min_z"]), float(block["max_x"]), float(block["max_z"])):
			return true
	return false


static func segment_hits_rect(ax: float, az: float, bx: float, bz: float, min_x: float, min_z: float, max_x: float, max_z: float) -> bool:
	var dx := bx - ax
	var dz := bz - az
	var t0 := 0.0
	var t1 := 1.0
	var p: Array[float] = [-dx, dx, -dz, dz]
	var q: Array[float] = [ax - min_x, max_x - ax, az - min_z, max_z - az]
	for i in 4:
		if absf(p[i]) < 0.00001:
			if q[i] < 0.0:
				return false
		else:
			var r := q[i] / p[i]
			if p[i] < 0.0:
				if r > t1:
					return false
				if r > t0:
					t0 = r
			else:
				if r < t0:
					return false
				if r < t1:
					t1 = r
	return true
