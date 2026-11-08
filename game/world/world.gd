extends Node3D

const Rules = preload("res://world/rules.gd")
const MapData = preload("res://world/map.gd")
const Meshes = preload("res://world/meshes.gd")
const VehicleSc = preload("res://world/vehicle.gd")
const PlatesSc = preload("res://world/plates.gd")

var height_step := 0
var height_vis := 0.0
var yaw_deg := 0.0
var yaw_vis := 0.0
var pos := Vector3.ZERO
var vel := Vector3.ZERO
var held: Dictionary = {}
var tilt_p := 0.0
var tilt_r := 0.0
var moving := false
var fuel := Rules.FUEL_START
var health := Rules.HEALTH_START
var phase := "play"
var land_left := 0.0
var land_from_y := 0.0
var notice := ""
var notice_left := 0.0
var blockers: Array = []
var vehicles: Array = []
var bullets: Array = []
var booms: Array = []
var pictures: Array = []
var flag_nodes: Array[Sprite3D] = []
var tree_nodes: Array[Sprite3D] = []
var hind: Sprite3D
var rotor: Sprite3D
var dust: Sprite3D
var shadow: Sprite3D
var mast := Vector3.ZERO
var travel := Vector3(0.0, -1.0, 0.0)
var hubs: Array[Vector2] = []
var sun: DirectionalLight3D
var tracer: Sprite3D
var tracer_left := 0.0
var gun_left := 0.0
var gun_hold := false
var camera: Camera3D
var plates: CanvasLayer
var wind_t := 0.0
var capture := false
var capture_frame := 0
var _body_shift: Dictionary = {}


func _ready() -> void:
	var view := get_viewport()
	view.msaa_3d = Viewport.MSAA_DISABLED
	view.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	view.use_taa = false
	var data: Dictionary = Meshes.layout()
	var mast_row: Array = data["mast"]
	mast = Vector3(float(mast_row[0]), float(mast_row[1]), float(mast_row[2]))
	var travel_row: Array = data["travel"]
	travel = Vector3(float(travel_row[0]), float(travel_row[1]), float(travel_row[2]))
	hubs.clear()
	if data.has("hubs"):
		for row in data["hubs"]:
			hubs.append(Vector2(float(row[0]), float(row[1])))
	pos = MapData.start()
	blockers = MapData.blockers()
	_light()
	_ground()
	_props()
	_hind()
	_vehicles()
	_camera()
	plates = PlatesSc.new()
	add_child(plates)
	plates.setup()
	_place_hind()
	_refresh()


func _process(delta: float) -> void:
	if phase != "play":
		held.clear()
	if phase == "play":
		_fly(delta)
		if gun_left > 0.0:
			gun_left -= delta
			if gun_left <= 0.0 and gun_hold:
				gun_hold = false
				gun_left = 0.0
				_release_gun()
		fuel -= Rules.fuel_per_sec(_mode()) * delta
		if fuel < 0.0:
			fuel = 0.0
		_end_check()
	elif phase == "landing" or phase == "landed":
		vel = Vector3.ZERO
	if phase == "landing":
		land_left -= delta
		if land_left <= 0.0:
			phase = "landed"
			land_left = 0.0
	if notice_left > 0.0:
		notice_left -= delta
		if notice_left <= 0.0:
			notice = ""
	if tracer_left > 0.0:
		tracer_left -= delta
		tracer.visible = tracer_left > 0.0
	_spin(delta)
	_sway(delta)
	_sync_pictures(delta)
	_place_hind()
	_booms(delta)
	_refresh()
	if capture:
		_capture_tick()


func _physics_process(delta: float) -> void:
	if phase != "play":
		return
	var mode := _mode()
	for vehicle in vehicles:
		if not vehicle.alive:
			continue
		if mode == "attack":
			vehicle.wash(pos)
		else:
			vehicle.cruise(delta)
		var up: float = vehicle.global_transform.basis.y.dot(Vector3.UP)
		if Rules.tipped(vehicle.kind, up):
			_begin_tip(vehicle)
	_tick_bullets(delta)
	_enemy_shots(delta)
	_end_check()


func _input(event: InputEvent) -> void:
	if Rules.is_again(event) and (phase == "landed" or phase == "down" or phase == "clear"):
		get_tree().reload_current_scene()
		return
	if phase != "play":
		return
	if Rules.is_fire(event):
		_fire()
		return
	var name := Rules.flight_key(event)
	if name == "":
		return
	var key := event as InputEventKey
	if key.pressed:
		if name == "W" or name == "A" or name == "S" or name == "D" or name == "Q" or name == "E":
			held[name] = true
		_tap(name)
	else:
		held.erase(name)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		held.clear()


func _held(name: String) -> bool:
	return bool(held.get(name, false))


func _fly(delta: float) -> void:
	yaw_deg = Rules.hold_yaw(yaw_deg, _held("Q"), _held("E"), delta)
	yaw_vis = yaw_deg
	var fwd := Rules.yaw_forward(yaw_vis)
	var side := Rules.yaw_right(yaw_vis)
	var wish := Vector3.ZERO
	if _held("W"):
		wish += fwd
	if _held("S"):
		wish -= fwd
	if _held("D"):
		wish += side
	if _held("A"):
		wish -= side
	vel = Rules.coast(vel, delta)
	vel = Rules.hold_thrust(vel, wish, delta)
	moving = vel.length() > Rules.STILL_SPEED
	var next := pos + vel * delta
	var roof := float(height_step) * Rules.STEP_Y
	var reason := Rules.block_reason(pos, next, blockers, roof)
	if reason != "":
		vel = Vector3.ZERO
		moving = false
		_say(Rules.stop_line(reason))
	else:
		pos = next
	var goal := float(height_step) * Rules.STEP_Y
	var climb := Rules.STEP_Y / Rules.CLIMB_SEC / Rules.WEIGHT * delta
	height_vis = move_toward(height_vis, goal, climb)
	var want_p := -Rules.TILT_MAX * clampf(vel.dot(fwd) / Rules.MAX_SPEED, -1.0, 1.0)
	var want_r := Rules.TILT_MAX * clampf(vel.dot(side) / Rules.MAX_SPEED, -1.0, 1.0)
	var lag := 1.0 - exp(-Rules.TILT_LAG / Rules.WEIGHT * delta)
	tilt_p = lerpf(tilt_p, want_p, lag)
	tilt_r = lerpf(tilt_r, want_r, lag)


func _tap(key: String) -> void:
	if key == "W" or key == "A" or key == "S" or key == "D":
		var dir := Vector3.ZERO
		if key == "W":
			dir = Rules.yaw_forward(yaw_vis)
		elif key == "S":
			dir = -Rules.yaw_forward(yaw_vis)
		elif key == "D":
			dir = Rules.yaw_right(yaw_vis)
		elif key == "A":
			dir = -Rules.yaw_right(yaw_vis)
		vel += dir * Rules.SHOVE / Rules.WEIGHT
		if vel.length() > Rules.MAX_SPEED:
			vel = vel.normalized() * Rules.MAX_SPEED
		return
	# Q and E turn only while held. A press does not add a facing.
	if key == "Q" or key == "E":
		return
	if key == "R":
		if height_step >= 2:
			_say(Rules.stop_line("top"))
		else:
			height_step += 1
		return
	if key == "F":
		if height_step <= 0:
			_say(Rules.stop_line("ground"))
		else:
			height_step -= 1


func _targets() -> Array:
	var targets: Array = []
	for vehicle in vehicles:
		if not vehicle.alive:
			continue
		var flat: Vector3 = vehicle.flat_pos()
		targets.append({"x": flat.x, "z": flat.z, "half": vehicle.half, "body": vehicle})
	return targets


func _aim() -> Dictionary:
	var roof := float(height_step) * Rules.STEP_Y
	var picked: Dictionary = Rules.gun_slew(pos, yaw_vis, _targets(), blockers, roof)
	picked["body"] = null
	var index := int(picked["index"])
	if index >= 0:
		picked["body"] = _targets()[index]["body"]
	return picked


func _fire() -> void:
	if gun_left > 0.0:
		_say(Rules.gun_turning_line())
		return
	var aim := _aim()
	if str(aim["notice"]) != "":
		_say(str(aim["notice"]))
		gun_hold = false
		return
	var angle := float(aim["angle"])
	var wait := Rules.gun_wait(angle)
	if absf(angle) <= Rules.GUN_SWEET:
		_shoot(aim)
		gun_left = wait
		return
	gun_hold = true
	gun_left = wait
	_say(Rules.gun_turning_line())


func _release_gun() -> void:
	var aim := _aim()
	if str(aim["notice"]) != "":
		_say(str(aim["notice"]))
		return
	_shoot(aim)
	gun_left = Rules.gun_wait(float(aim["angle"]))


func _shoot(aim: Dictionary) -> void:
	var body = aim["body"]
	if body == null:
		_say("The shot misses.")
		return
	var flat: Vector3 = body.flat_pos()
	_show_tracer(Vector3(flat.x, 1.1, flat.z))
	if body.hurt(Rules.GUN_DAMAGE):
		_destroy(body)
		_say("The vehicle is destroyed.")
	else:
		_say("The vehicle is hit.")
	_end_check()


func _mode() -> String:
	if phase != "play":
		return "off"
	return Rules.wash_mode(height_step, moving)


func _end_check() -> void:
	if phase != "play":
		return
	if _alive() == 0:
		phase = "clear"
		return
	if health <= 0:
		phase = "down"
		_boom(hind.global_position)
		hind.visible = false
		rotor.visible = false
		dust.visible = false
		shadow.visible = false
		return
	if fuel <= 0.0:
		phase = "landing"
		land_left = Rules.LAND_SEC
		land_from_y = height_vis
		vel = Vector3.ZERO
		moving = false


func _alive() -> int:
	var count := 0
	for vehicle in vehicles:
		if vehicle.alive:
			count += 1
	return count


func _say(line: String) -> void:
	notice = line
	notice_left = 1.4


func _enemy_shots(delta: float) -> void:
	for vehicle in vehicles:
		if not vehicle.alive or not vehicle.ready(delta):
			continue
		var flat: Vector3 = vehicle.flat_pos()
		var rel := Vector3(pos.x - flat.x, 0.0, pos.z - flat.z)
		if rel.length() > Rules.ENEMY_RANGE:
			continue
		if vehicle.global_transform.basis.y.dot(Vector3.UP) < 0.85:
			continue
		if Rules._segment_blocked(flat.x, flat.z, pos.x, pos.z, blockers):
			continue
		var dir := rel.normalized()
		var mesh := Meshes.sprite("bullet.png")
		mesh.position = Vector3(flat.x, 1.2, flat.z)
		add_child(mesh)
		bullets.append({
			"pos": Vector3(flat.x, 1.2, flat.z),
			"dir": dir,
			"mesh": mesh,
			"life": 2.0,
		})
		vehicle.mark_shot()


func _tick_bullets(delta: float) -> void:
	var kept: Array = []
	for bullet in bullets:
		var mesh: Node3D = bullet["mesh"]
		var life := float(bullet["life"]) - delta
		var at: Vector3 = bullet["pos"] + bullet["dir"] * Rules.BULLET_SPEED * delta
		var blocked := Rules._segment_blocked(bullet["pos"].x, bullet["pos"].z, at.x, at.z, blockers)
		var rel := Vector3(pos.x - at.x, 0.0, pos.z - at.z)
		var hit := phase == "play" and rel.length() < 1.5
		if hit:
			health -= Rules.ENEMY_SHOT
			_say("Hit.")
			mesh.queue_free()
			continue
		if blocked or life <= 0.0:
			mesh.queue_free()
			continue
		bullet["pos"] = at
		bullet["life"] = life
		mesh.position = at
		kept.append(bullet)
	bullets = kept


func _show_tracer(at: Vector3) -> void:
	tracer.visible = true
	tracer_left = 0.12
	var from := Vector3(pos.x, _body_y() + 1.15, pos.z)
	tracer.position = from.lerp(at, 0.65)


func _boom(at: Vector3) -> void:
	var node := Meshes.sprite("boom_0.png")
	node.position = Vector3(at.x, 1.1, at.z)
	add_child(node)
	booms.append({"node": node, "life": 0.72})


func _booms(delta: float) -> void:
	var kept: Array = []
	for boom in booms:
		var life := float(boom["life"]) - delta
		var node: Sprite3D = boom["node"]
		if life <= 0.0:
			node.queue_free()
			continue
		var frame := int((0.72 - life) / 0.72 * 4.0)
		if frame > 3:
			frame = 3
		node.texture = Meshes.tex("boom_%d.png" % frame)
		boom["life"] = life
		kept.append(boom)
	booms = kept


func _body_y() -> float:
	if phase == "landing" or phase == "landed":
		var t := 1.0
		if Rules.LAND_SEC > 0.0:
			t = 1.0 - clampf(land_left / Rules.LAND_SEC, 0.0, 1.0)
		return lerpf(land_from_y, 0.0, t)
	return height_vis


func _gear_name(face: int, y: float) -> String:
	var step := y / Rules.STEP_Y
	var tag := ""
	if step >= 0.7:
		tag = "_up"
	elif step >= 0.25:
		tag = "_mid"
	var named := "hind_%d%s.png" % [face, tag]
	if tag != "" and not FileAccess.file_exists("res://art/sprites/" + named):
		return "hind_%d.png" % face
	return named


func _hang_basis(cam_basis: Basis, face: int) -> Basis:
	var nose := Vector2(1, 1)
	match face:
		1:
			nose = Vector2(0, 1)
		2:
			nose = Vector2(-1, 1)
		3:
			nose = Vector2(-1, 0)
		4:
			nose = Vector2(-1, -1)
		5:
			nose = Vector2(0, -1)
		6:
			nose = Vector2(1, -1)
		7:
			nose = Vector2(1, 0)
	nose = nose.normalized()
	var axis_2 := Vector2(-nose.y, nose.x)
	var axis := (cam_basis.x * axis_2.x + cam_basis.y * axis_2.y).normalized()
	var pitched := Basis(axis, deg_to_rad(tilt_p))
	var rolled := Basis(-cam_basis.z, deg_to_rad(tilt_r))
	return rolled * pitched * cam_basis


func _place_hind() -> void:
	var y := _body_y()
	var face := posmod(int(round(yaw_vis / 45.0)), 8)
	var step_f := y / Rules.STEP_Y
	camera.size = Rules.camera_size(step_f)
	camera.global_position = Vector3(pos.x, y, pos.z) + Rules.CAM_OFFSET
	camera.look_at(Vector3(pos.x, y + 0.6, pos.z), Vector3.UP)
	var cam_basis := camera.global_transform.basis
	var hang := _hang_basis(cam_basis, face)
	var mast_at := Vector3(pos.x, y, pos.z) + cam_basis.y * Rules.HUB_HANG
	hind.global_position = mast_at - hang.y * Rules.HUB_HANG
	hind.global_basis = hang
	if phase != "down":
		hind.texture = Meshes.tex(_spin_name(face, y))
		# Gear pictures are not framed on the same pixel. Without this, the
		# fuselage jumps sideways when the wheels change, and the zoom looks stepped.
		hind.offset = _gear_offset(face, y)
		hind.visible = true
		rotor.visible = false
	dust.position = Vector3(pos.x, 0.0, pos.z)
	var disc := _dust_scale(step_f, moving)
	dust.visible = phase != "down" and disc > 1.08
	dust.scale = Vector3.ONE * disc
	shadow.scale = Vector3.ONE * Rules.shadow_scale(step_f)
	if travel.y < -0.2:
		var reach := y / -travel.y * 1.6
		shadow.position = Vector3(pos.x + travel.x * reach, 0.03, pos.z + travel.z * reach)
	shadow.visible = phase != "down"


func _gear_stem(face: int, y: float) -> String:
	var named := _gear_name(face, y)
	return named.trim_suffix(".png")


func _spin_name(face: int, y: float) -> String:
	# Twelve pictures of the painted blades. Three turns a second.
	var frame := posmod(int(wind_t * 36.0), 12)
	var named := "spin/%s_%d.png" % [_gear_stem(face, y), frame]
	if not FileAccess.file_exists("res://art/sprites/" + named):
		return _gear_name(face, y)
	return named


func _spin(_delta: float) -> void:
	if phase == "down":
		return
	dust.texture = Meshes.tex("dust_%d.png" % posmod(int(wind_t * 10.0), 3))


func _sway(delta: float) -> void:
	wind_t += delta
	var frame := 0
	if _mode() == "wind":
		frame = posmod(int(wind_t * 8.0), 3)
	var flag_name := "flag_%d.png" % frame
	var tree_name := "tree_%d.png" % frame
	for node in flag_nodes:
		node.texture = Meshes.tex(flag_name)
	for node in tree_nodes:
		node.texture = Meshes.tex(tree_name)


func _refresh() -> void:
	var view := get_viewport().get_visible_rect().size
	plates.place(view)
	var end_s := Rules.end_line(phase)
	plates.show_state(
		Rules.fuel_line(fuel),
		Rules.health_line(health),
		Rules.vehicles_line(_alive()),
		Rules.height_line(height_step),
		Rules.wash_line(_mode()),
		notice,
		end_s
	)


func _dust_scale(step_f: float, is_moving: bool) -> float:
	if is_moving and step_f < 1.0:
		return lerpf(0.0, 1.7, clampf(step_f, 0.0, 1.0))
	return Rules.wash_scale_at(step_f)


func _thick_pixel(image: Image, x: int, y: int, rad: int) -> bool:
	var w := image.get_width()
	var h := image.get_height()
	var samples: Array[int] = [-rad, 0, rad]
	for dy in samples:
		for dx in samples:
			var xx: int = x + dx
			var yy: int = y + dy
			if xx < 0 or yy < 0 or xx >= w or yy >= h:
				return false
			if image.get_pixel(xx, yy).a < 0.5:
				return false
	return true


func _body_shift_of(stem: String) -> Vector2:
	if _body_shift.has(stem):
		return _body_shift[stem]
	var image := Image.new()
	var shift := Vector2.ZERO
	if image.load("res://art/sprites/%s.png" % stem) == OK:
		var rad := 8
		var w := image.get_width()
		var h := image.get_height()
		var sx := 0.0
		var sy := 0.0
		var n := 0
		var y := rad
		while y < h - rad:
			var x := rad
			while x < w - rad:
				if image.get_pixel(x, y).a >= 0.5 and _thick_pixel(image, x, y, rad):
					sx += x
					sy += y
					n += 1
				x += 2
			y += 2
		if n >= 8:
			shift = Vector2(sx / float(n) - float(w) * 0.5, sy / float(n) - float(h) * 0.5)
	_body_shift[stem] = shift
	return shift


func _gear_offset(face: int, y: float) -> Vector2:
	var stem := _gear_stem(face, y)
	var base := "hind_%d" % face
	return _body_shift_of(base) - _body_shift_of(stem)


func _capture_tick() -> void:
	capture_frame += 1
	if capture_frame == 20:
		_save_frame("/home/hierophant/Projects/hind-merc/art/still-ground.png")
		height_step = 2
	elif capture_frame == 40:
		_save_frame("/home/hierophant/Projects/hind-merc/art/still-high.png")
		get_tree().quit(0)


func _save_frame(path: String) -> void:
	var image := get_viewport().get_texture().get_image()
	if image == null:
		print("frame missing")
		return
	var err := image.save_png(path)
	print("frame %dx%d err %d %s" % [image.get_width(), image.get_height(), err, path])


func _light() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.62, 0.7, 0.74)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.48, 0.42, 0.34)
	env.ambient_light_energy = 0.22
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.tonemap_exposure = 1.0
	env.glow_enabled = false
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	sun = DirectionalLight3D.new()
	sun.light_energy = 0.0
	sun.shadow_enabled = false
	add_child(sun)


func _ground() -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var surface := PhysicsMaterial.new()
	surface.friction = 0.7
	surface.bounce = 0.0
	body.physics_material_override = surface
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(120, 2, 120)
	shape.shape = box
	shape.position = Vector3(0, -1, 0)
	body.add_child(shape)
	body.add_child(Meshes.ground())
	add_child(body)
	_wall(Vector3(0, 1.0, -36), Vector3(80, 2.0, 1.2))
	_wall(Vector3(0, 1.0, 36), Vector3(80, 2.0, 1.2))
	_wall(Vector3(-36, 1.0, 0), Vector3(1.2, 2.0, 80))
	_wall(Vector3(36, 1.0, 0), Vector3(1.2, 2.0, 80))


func _wall(at: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = at
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	add_child(body)


func _props() -> void:
	var index := 0
	for item in MapData.buildings():
		var node := Meshes.sprite("building_%d.png" % index)
		node.position = Vector3(float(item["x"]), 0.0, float(item["z"]))
		add_child(node)
		index += 1
	for item in MapData.trees():
		var tree := Meshes.sprite("tree_0.png")
		tree.position = Vector3(float(item["x"]), 0.0, float(item["z"]))
		add_child(tree)
		tree_nodes.append(tree)
	for item in MapData.bushes():
		var bush := Meshes.sprite("bush.png")
		bush.position = Vector3(float(item["x"]), 0.0, float(item["z"]))
		add_child(bush)
	for item in MapData.flags():
		var flag := Meshes.sprite("flag_0.png")
		flag.position = Vector3(float(item["x"]), 0.0, float(item["z"]))
		add_child(flag)
		flag_nodes.append(flag)


func _hind() -> void:
	hind = Meshes.sprite("hind_0.png")
	hind.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	hind.extra_cull_margin = 80.0
	add_child(hind)
	rotor = Meshes.sprite("rotor_0.png", false, true)
	rotor.visible = false
	add_child(rotor)
	dust = Meshes.sprite("dust_0.png")
	add_child(dust)
	shadow = Meshes.sprite("shadow.png", true)
	add_child(shadow)
	tracer = Meshes.sprite("tracer.png")
	tracer.visible = false
	add_child(tracer)


func _vehicles() -> void:
	for item in MapData.vehicles():
		var vehicle := VehicleSc.new()
		vehicle.setup(item)
		vehicle.collision_layer = 2
		vehicle.collision_mask = 3
		add_child(vehicle)
		vehicles.append(vehicle)
		var kind := str(item["kind"])
		var picture := Meshes.sprite("%s_0.png" % kind)
		picture.position = Vector3(float(item["x"]), 0.0, float(item["z"]))
		add_child(picture)
		var shade := Meshes.sprite("shadow.png", true)
		shade.scale = Vector3(0.45, 0.45, 0.45)
		shade.position = picture.position + Vector3(0.0, 0.03, 0.0)
		add_child(shade)
		var run: Array[Texture2D] = []
		for face in 8:
			run.append(Meshes.tex("%s_%d.png" % [kind, face]))
		var tip: Texture2D = null
		var wreck: Texture2D = null
		if kind != "truck":
			tip = Meshes.tex(kind + "_tip.png")
			wreck = Meshes.tex(kind + "_wreck.png")
		pictures.append({
			"body": vehicle,
			"sprite": picture,
			"shadow": shade,
			"run": run,
			"tip": tip,
			"wreck": wreck,
			"state": "run",
			"left": 0.0,
		})


func _begin_tip(vehicle) -> void:
	if not vehicle.alive:
		return
	vehicle.alive = false
	for pic in pictures:
		if pic["body"] != vehicle:
			continue
		pic["state"] = "tip"
		pic["left"] = 0.32
		var sprite: Sprite3D = pic["sprite"]
		sprite.texture = pic["tip"]
		return


func _sync_pictures(delta: float) -> void:
	for pic in pictures:
		var state := str(pic["state"])
		var sprite: Sprite3D = pic["sprite"]
		var shade: Sprite3D = pic["shadow"]
		if state == "wreck":
			continue
		var body = pic["body"]
		var at := Vector3(body.global_position.x, 0.0, body.global_position.z)
		sprite.position = at
		shade.position = at + Vector3(0.0, 0.03, 0.0)
		if state == "tip":
			pic["left"] = float(pic["left"]) - delta
			if float(pic["left"]) <= 0.0:
				pic["state"] = "wreck"
				sprite.texture = pic["wreck"]
				shade.visible = false
				body.wreck()
				_boom(at)
			continue
		var face := posmod(int(round(rad_to_deg(body.rotation.y) / 45.0)), 8)
		var run: Array = pic["run"]
		sprite.texture = run[face]
		if float(body.shake) > 0.0:
			var amp := float(body.shake)
			sprite.offset = Vector2(sin(wind_t * 47.0) * 7.0 * amp, sin(wind_t * 63.0) * 4.0 * amp)
		else:
			sprite.offset = Vector2.ZERO
		shade.offset = sprite.offset


func _destroy(vehicle) -> void:
	if not vehicle.alive:
		return
	var at: Vector3 = vehicle.global_position
	vehicle.wreck()
	for pic in pictures:
		if pic["body"] != vehicle:
			continue
		pic["state"] = "wreck"
		var sprite: Sprite3D = pic["sprite"]
		var shade: Sprite3D = pic["shadow"]
		sprite.position = Vector3(at.x, 0.0, at.z)
		if pic["wreck"] == null:
			sprite.visible = false
		else:
			sprite.texture = pic["wreck"]
		shade.visible = false
	_boom(at)


func _camera() -> void:
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = Rules.CAM_SIZE
	camera.current = true
	add_child(camera)
