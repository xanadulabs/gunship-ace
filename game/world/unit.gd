extends Node3D
## One enemy, structure or vehicle. Arcade logic: no rigid body, so nothing skates through walls.
## The world calls tick(); the unit asks the world to fire.

const Rules = preload("res://core/rules.gd")
const Art = preload("res://core/art.gd")

const FACED := ["jeep", "technical", "truck", "tank", "zsu", "aaa", "sam"]
const TURN_RATE := 100.0
const BLOCK_SIZE := {
	"building_0": Vector2(8.0, 6.0), "building_1": Vector2(7.0, 8.0), "building_2": Vector2(6.0, 6.0),
	"radar": Vector2(6.0, 5.4), "depot": Vector2(11.0, 7.4), "bunker": Vector2(10.6, 9.0),
}

var kind := "jeep"
var info: Dictionary = {}
var tag := ""
var variant := 0
var drop := ""
var hp := 1.0
var hp_max := 1.0
var state := "alive"        # waiting, alive, tip, dead, escaped
var flipped := false
var path: Array = []
var loop := true
var way := 1
var dir := 1
var speed := 0.0
var delay := 0.0
var heading := 0.0          # degrees, hull
var aim := 0.0              # degrees, turret or body when engaging
var cool := 0.0
var burst_left := 0
var burst_gap := 0.0
var tip := 0.0
var washed := false
var flash := 0.0
var anim := 0.0
var anchor := Vector3.ZERO
var wander_to := Vector3.ZERO
var wander_wait := 0.0
var engaged := false
var tip_left := 0.0
var spawn_spec: Dictionary = {}
var rng := RandomNumberGenerator.new()

var sprite: Sprite3D
var shadow: Sprite3D


func setup(spec: Dictionary, seed_value: int) -> void:
	spawn_spec = spec
	rng.seed = seed_value
	kind = str(spec["kind"])
	info = Rules.UNITS[kind]
	tag = str(spec.get("tag", ""))
	variant = int(spec.get("v", 0))
	drop = str(spec.get("drop", ""))
	hp_max = float(info["hp"])
	hp = hp_max
	speed = float(spec.get("speed", info["speed"]))
	var at: Vector2 = spec["at"]
	position = Vector3(at.x, 0.0, at.y)
	anchor = position
	wander_to = position
	heading = float(spec.get("yaw", rng.randf_range(0.0, 360.0) if kind == "soldier" else 0.0))
	path = []
	for p in spec.get("path", []):
		path.append(Vector3(p.x, 0.0, p.y))
	loop = bool(spec.get("loop", true))
	delay = float(spec.get("delay", 0.0))
	if path.size() >= 2:
		heading = Rules.yaw_to_deg(path[1] - path[0])
		position = path[0]
	aim = heading
	cool = rng.randf_range(0.5, 2.0)
	state = "waiting" if delay > 0.0 else "alive"
	sprite = Art.sprite(_picture())
	sprite.position = Rules.SPRITE_LIFT
	add_child(sprite)
	if FACED.has(kind) or kind == "soldier":
		shadow = Art.sprite("shadow.png", true)
		shadow.scale = Vector3.ONE * (float(info["radius"]) * 0.3)
		shadow.position = Vector3(0.6, 0.03, -0.3)
		shadow.modulate = Color(1, 1, 1, 0.8)
		add_child(shadow)
	visible = state != "waiting"


func is_active() -> bool:
	return state == "alive"


func is_target() -> bool:
	return state == "alive" or state == "tip"


func is_structure() -> bool:
	return bool(info.get("block", false))


func block_rect() -> Rect2:
	var key := kind
	if kind == "building":
		key = "building_%d" % variant
	var size: Vector2 = BLOCK_SIZE.get(key, Vector2(4, 4))
	return Rect2(position.x - size.x * 0.5, position.z - size.y * 0.5, size.x, size.y)


func radius() -> float:
	return float(info["radius"])


func weapon() -> String:
	return str(info.get("weapon", ""))


func tick(delta: float, world) -> void:
	anim += delta
	if flash > 0.0:
		flash -= delta
	if state == "waiting":
		delay -= delta
		if delay <= 0.0:
			state = "alive"
			visible = true
		return
	if state == "tip":
		tip_left -= delta
		sprite.offset = Vector2(sin(anim * 50.0) * 2.0, -(Rules.TIP_SEC - tip_left) * 14.0)
		if tip_left <= 0.0:
			world.unit_destroyed(self, "wash")
		_paint()
		return
	if state != "alive":
		return
	if not washed:
		tip = maxf(0.0, tip - Rules.WASH_DECAY * delta)
	washed = false
	_drive(delta, world)
	_fight(delta, world)
	_paint()


func _drive(delta: float, world) -> void:
	if speed <= 0.0:
		return
	if kind == "soldier":
		_wander(delta, world)
		return
	if path.size() < 2:
		return
	if tip > 0.2:
		return  # A vehicle in the wash stalls; the driver is hanging on.
	var target: Vector3 = path[way]
	var to := Rules.flat(target - position)
	if to.length() < 1.6:
		_next_way(world)
		return
	# Turn until the nose points along the road, then drive. Never slide sideways.
	var want := Rules.yaw_to_deg(to)
	var gap := wrapf(want - heading, -180.0, 180.0)
	if absf(gap) > 6.0:
		heading = wrapf(heading + clampf(gap, -TURN_RATE * delta, TURN_RATE * delta), -180.0, 180.0)
	else:
		heading = want
		position += Rules.yaw_forward(heading) * speed * delta
	if not engaged:
		aim = heading


func _next_way(world) -> void:
	if way + dir >= path.size() or way + dir < 0:
		if not loop:
			state = "escaped"
			visible = false
			world.unit_escaped(self)
			return
		dir = -dir
	way += dir


func _wander(delta: float, world) -> void:
	if engaged:
		return
	if wander_wait > 0.0:
		wander_wait -= delta
		return
	var to := Rules.flat(wander_to - position)
	if to.length() < 0.4:
		wander_wait = rng.randf_range(1.5, 4.0)
		var a := rng.randf_range(0.0, TAU)
		wander_to = anchor + Vector3(cos(a), 0.0, sin(a)) * rng.randf_range(1.0, 6.0)
		return
	heading = Rules.yaw_to_deg(to)
	aim = heading
	position += to.normalized() * speed * delta
	if world == null:
		return


func _fight(delta: float, world) -> void:
	var w := weapon()
	var was_engaged := engaged
	engaged = false
	if w == "" or world == null or not world.hind_targetable():
		burst_left = 0
		return
	var hind_pos: Vector3 = world.hind_aim_point()
	var dist := Rules.flat(hind_pos - position).length()
	var winfo: Dictionary = Rules.ENEMY_WEAPONS[w]
	if dist > float(winfo["range"]) or not Rules.can_reach(w, world.hind_band()):
		burst_left = 0
		cool = maxf(cool, 0.4)
		cool -= delta * 0.3
		return
	if not was_engaged:
		cool = maxf(cool, 1.4)  # a moment to react when the Hind first comes into reach
	engaged = true
	var want := Rules.yaw_to_deg(Rules.flat(hind_pos - position))
	var gap := wrapf(want - aim, -180.0, 180.0)
	aim = wrapf(aim + clampf(gap, -TURN_RATE * 1.6 * delta, TURN_RATE * 1.6 * delta), -180.0, 180.0)
	if burst_left > 0:
		burst_gap -= delta
		if burst_gap <= 0.0:
			burst_gap = 0.1
			burst_left -= 1
			world.enemy_fire(self, w)
		return
	cool -= delta
	if cool <= 0.0 and absf(gap) < 30.0:
		cool = float(winfo["cool"]) * rng.randf_range(0.85, 1.2)
		burst_left = int(winfo["burst"])
		burst_gap = 0.0


func muzzle() -> Vector3:
	var h := 2.6 if kind == "sam" else (1.4 if kind != "soldier" else 1.2)
	return position + Vector3(0.0, h, 0.0) + Rules.yaw_forward(aim) * 1.2


func hurt(amount: float, world, how: String) -> void:
	if not is_target():
		return
	hp -= amount
	flash = 0.08
	if hp <= 0.0 and state == "alive":
		world.unit_destroyed(self, how)


func wash(rate: float, delta: float) -> bool:
	## Returns true when the unit is flipped this frame.
	washed = true
	if rate <= 0.0:
		return false
	tip += rate * delta
	if tip >= 1.0 and state == "alive":
		state = "tip"
		tip_left = Rules.TIP_SEC
		flipped = true
		return true
	return false


func kill() -> void:
	state = "dead"
	sprite.offset = Vector2.ZERO
	sprite.modulate = Color.WHITE
	var wreck := _wreck_picture()
	if wreck == "":
		sprite.visible = false
	else:
		sprite.texture = Art.tex(wreck)
	if shadow != null:
		shadow.visible = false


func _picture() -> String:
	var face := Rules.facing_index(aim)
	match kind:
		"jeep", "technical", "truck":
			return "%s_%d.png" % [kind, Rules.facing_index(heading)]
		"tank", "zsu", "aaa", "sam":
			return "%s_%d.png" % [kind, face]
		"soldier":
			var step := 0 if (engaged or wander_wait > 0.0) else int(anim * 6.0) % 2
			return "soldier_%d_%d.png" % [face, step]
		"radar":
			return "radar_%d.png" % (int(anim * 4.0) % 4)
		"building":
			return "building_%d.png" % variant
	return "%s.png" % kind


func _wreck_picture() -> String:
	match kind:
		"jeep", "technical", "truck", "tank", "zsu", "aaa", "sam":
			return "%s_wreck.png" % kind
		"soldier":
			return "soldier_down.png"
		"radar", "depot", "bunker", "building":
			return "%s_wreck.png" % kind
	return ""


func _paint() -> void:
	if state == "tip":
		var tip_pic := "%s_tip.png" % kind
		if kind == "soldier":
			tip_pic = "soldier_down.png"
		if Art.has(tip_pic):
			sprite.texture = Art.tex(tip_pic)
		return
	sprite.texture = Art.tex(_picture())
	if tip > 0.0:
		var amp := clampf(tip, 0.0, 1.0)
		sprite.offset = Vector2(sin(anim * 47.0) * 5.0 * amp, absf(sin(anim * 31.0)) * 4.0 * amp)
	else:
		sprite.offset = Vector2.ZERO
	sprite.modulate = Color(1.8, 1.5, 1.3) if flash > 0.0 else Color.WHITE
