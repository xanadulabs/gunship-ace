extends RigidBody3D

const Rules = preload("res://world/rules.gd")

var kind: String = "jeep"
var hp: int = 4
var alive: bool = true
var patrol: bool = false
var cruise_speed: float = 3.2
var point_a := Vector3.ZERO
var point_b := Vector3.ZERO
var to_b: bool = true
var half: float = 1.3
var cool: float = 0.0
var shake: float = 0.0
var heading: float = 0.0
var driving: bool = false
const TURN_RATE := 3.2


func setup(item: Dictionary) -> void:
	kind = str(item["kind"])
	hp = Rules.vehicle_hp(kind)
	half = Rules.vehicle_half(kind)
	patrol = bool(item["patrol"])
	point_a = Vector3(float(item["x"]), 0.0, float(item["z"]))
	point_b = Vector3(float(item["x2"]), 0.0, float(item["z2"]))
	mass = 650.0
	if kind == "technical":
		mass = 900.0
	elif kind == "truck":
		mass = 2800.0
		axis_lock_angular_x = true
		axis_lock_angular_z = true
	var shape := BoxShape3D.new()
	if kind == "truck":
		shape.size = Vector3(1.9, 1.7, 4.6)
	elif kind == "technical":
		shape.size = Vector3(1.5, 1.3, 3.3)
	else:
		shape.size = Vector3(1.4, 1.15, 2.5)
	var body := CollisionShape3D.new()
	body.shape = shape
	add_child(body)
	var surface := PhysicsMaterial.new()
	surface.friction = 0.45
	surface.bounce = 0.02
	physics_material_override = surface
	continuous_cd = true
	can_sleep = false
	linear_damp = 0.35
	angular_damp = 0.55
	position = Vector3(point_a.x, shape.size.y * 0.5, point_a.z)
	if patrol:
		var leg := point_b - point_a
		leg.y = 0.0
		if leg.length_squared() > 0.01:
			heading = Rules.yaw_to(leg)
			rotation.y = heading


func flat_pos() -> Vector3:
	return Vector3(global_position.x, 0.0, global_position.z)


func _flat_nose(basis: Basis) -> Vector3:
	var fwd := -basis.z
	fwd.y = 0.0
	if fwd.length_squared() < 0.0001:
		return Vector3(0.0, 0.0, -1.0)
	return fwd.normalized()


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	# The nose is the only travel axis. A side push does not skate the body.
	if not alive:
		return
	var basis := state.transform.basis
	var upright := basis.y.dot(Vector3.UP) >= 0.85
	var fwd := _flat_nose(basis)
	if driving and upright:
		# Face the commanded heading. Wash sets driving off, so a jeep can still flip.
		fwd = Vector3(-sin(heading), 0.0, -cos(heading))
		var turned := state.transform
		turned.basis = Basis(Vector3.UP, heading)
		state.transform = turned
		var spin := state.angular_velocity
		state.angular_velocity = Vector3(spin.x, 0.0, spin.z)
	var vel := state.linear_velocity
	var along := vel.x * fwd.x + vel.z * fwd.z
	state.linear_velocity = Vector3(fwd.x * along, vel.y, fwd.z * along)


func wash(hind_xz: Vector3) -> void:
	driving = false
	if not alive:
		return
	var delta := flat_pos() - Vector3(hind_xz.x, 0.0, hind_xz.z)
	var dist := delta.length()
	if dist > Rules.WASH_RADIUS or dist < 0.05:
		shake = 0.0
		return
	shake = 1.0
	if kind == "truck":
		return
	var push := delta / dist
	apply_torque(Vector3.UP.cross(push) * Rules.FLIP_TORQUE)


func cruise(delta: float = 0.016) -> void:
	# Turn until the nose points along the leg, then drive. Never slide.
	shake = 0.0
	driving = false
	if not alive or not patrol:
		return
	if global_transform.basis.y.dot(Vector3.UP) < 0.85:
		return
	if delta <= 0.0:
		delta = 0.016
	var target := point_b if to_b else point_a
	var flat := Vector3(target.x - global_position.x, 0.0, target.z - global_position.z)
	if flat.length() < 0.8:
		to_b = not to_b
		target = point_b if to_b else point_a
		flat = Vector3(target.x - global_position.x, 0.0, target.z - global_position.z)
	if flat.length_squared() < 0.04:
		linear_velocity.x = 0.0
		linear_velocity.z = 0.0
		return
	var want := Rules.yaw_to(flat)
	var gap := wrapf(want - heading, -PI, PI)
	var step := TURN_RATE * delta
	if absf(gap) > 0.12:
		heading = wrapf(heading + clampf(gap, -step, step), -PI, PI)
		linear_velocity.x = 0.0
		linear_velocity.z = 0.0
	else:
		heading = want
		var nose := Rules.yaw_forward(rad_to_deg(heading))
		linear_velocity = Vector3(nose.x * cruise_speed, linear_velocity.y, nose.z * cruise_speed)
	rotation.y = heading
	angular_velocity = Vector3(angular_velocity.x, 0.0, angular_velocity.z)
	driving = true


func ready(delta: float) -> bool:
	if not alive:
		return false
	cool -= delta
	return cool <= 0.0


func mark_shot() -> void:
	cool = Rules.ENEMY_COOLDOWN


func hurt(amount: int) -> bool:
	if not alive:
		return false
	hp -= amount
	return hp <= 0


func wreck() -> void:
	alive = false
	collision_layer = 0
	collision_mask = 0
	visible = false
	freeze = true
