extends Node3D
## One mission: builds the map from Missions data and runs the play loop.

signal finished(won: bool, stats: Dictionary)
signal message(text: String, tone: String)

const Rules = preload("res://core/rules.gd")
const Art = preload("res://core/art.gd")
const Missions = preload("res://core/missions.gd")
const GroundSc = preload("res://world/ground.gd")
const UnitSc = preload("res://world/unit.gd")
const HindSc = preload("res://world/hind.gd")

var mission_index := 0
var mission: Dictionary = {}
var half := 100.0
var attract := false          # title screen backdrop: no Hind, no HUD, slow camera tour
var autopilot := {}
var invincible := false       # tests and screenshots only
var hits_taken := 0           # probe and screenshot runs: {"wish": Vector2, "turn": float, "fire": String}

var ground
var hind
var camera: Camera3D
var units: Array = []
var trees: Array = []         # [{node, at, sway}]
var flags: Array = []
var pickups: Array = []       # [{kind, node, at, taken}]
var crew: Array = []          # [{node, at, state: ground/aboard/home, winch}]
var shots: Array = []         # player projectiles
var enemy_shots: Array = []
var effects: Array = []       # [{node, life, max, frames, base, rise}]
var tree_rects: Array = []
var blockers: Array = []
var _blockers_dirty := true
var lz := Vector3.ZERO
var lz_yaw := 0.0

var health := Rules.HEALTH_START
var fuel := Rules.FUEL_START
var ammo := {}
var lives := Rules.LIVES
var aboard := 0
var delivered := 0
var phase := "play"           # play, dead, won, lost
var dead_left := 0.0
var end_left := 0.0
var fail_reason := ""
var cooldown := {"gun": 0.0, "rocket": 0.0, "atgm": 0.0}
var gun_left := 0.0
var gun_pending := false
var rocket_side := 1.0
var winch_t := 0.0
var unload_t := 0.0
var land_t := 0.0
var missile_warning := false
var shake := 0.0
var cam_focus := Vector3.ZERO
var time := 0.0
var kills := 0
var flips := 0
var escaped: Dictionary = {}
var objectives: Array = []    # [{spec, done, failed, progress}]
var respawn_queue: Array = [] # [{spec, left}]
var attract_t := 0.0
var _smoke_t := 0.0
var _msg_cache: Dictionary = {}


func setup(index: int, is_attract := false) -> void:
	mission_index = index
	attract = is_attract
	mission = Missions.get_mission(index)
	half = float(mission["half"])


func _ready() -> void:
	var view := get_viewport()
	view.msaa_3d = Viewport.MSAA_DISABLED
	view.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	_environment()
	ground = GroundSc.new()
	add_child(ground)
	ground.build(mission)
	var lz2: Vector2 = mission["lz"]
	lz = Vector3(lz2.x, 0.0, lz2.y)
	lz_yaw = float(mission.get("lz_yaw", 0.0))
	var pad := Art.sprite("lz.png", true, true)
	pad.position = lz + Vector3(0, 0.05, 0)
	pad.render_priority = 1
	add_child(pad)
	_spawn_structures_and_units()
	_scatter()
	_spawn_pickups()
	_spawn_crew()
	for spec in mission["objectives"]:
		objectives.append({"spec": spec, "done": false, "failed": false, "progress": ""})
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = Rules.CAM_SIZE[0]
	camera.near = 0.5
	camera.far = 600.0
	camera.current = true
	add_child(camera)
	hind = HindSc.new()
	add_child(hind)
	_respawn_hind()
	if attract:
		hind.visible = false
		hind.alive = false
		cam_focus = Vector3(-half * 0.4, 0, half * 0.3)
	_update_objectives()


func _environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.43, 0.34, 0.22)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 1, 1)
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


# ================================================================== building the map

func _spawn_structures_and_units() -> void:
	var n := 0
	for b in mission["buildings"]:
		var spec := {"kind": "building", "at": b["at"], "v": int(b.get("v", 0)), "drop": str(b.get("drop", "")), "tag": ""}
		_add_unit(spec, n)
		n += 1
	for spec in mission["units"]:
		_add_unit(spec, n)
		n += 1


func _add_unit(spec: Dictionary, n: int):
	var u = UnitSc.new()
	u.setup(spec, int(mission["seed"]) * 1000 + n)
	add_child(u)
	units.append(u)
	if u.is_structure():
		_blockers_dirty = true
	return u


func _scatter() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(mission["seed"])
	var keep_out: Array = [] # [Vector2, radius]
	keep_out.append([Vector2(lz.x, lz.z), 14.0])
	for u in units:
		keep_out.append([Vector2(u.position.x, u.position.z), 9.0 if u.is_structure() else 5.0])
	for p in mission["pickups"]:
		keep_out.append([p["at"], 4.0])
	for c in mission["crew"]:
		keep_out.append([c, 5.0])
	var placed := 0
	var tries := 0
	while placed < int(mission["trees"]) and tries < 4000:
		tries += 1
		var p := Vector2(rng.randf_range(-half + 4, half - 4), rng.randf_range(-half + 4, half - 4))
		if not _free_spot(p, keep_out, 3.0):
			continue
		var node := Art.sprite("tree_0.png")
		node.position = Vector3(p.x, 0, p.y) + Rules.SPRITE_LIFT
		add_child(node)
		trees.append({"node": node, "at": Vector3(p.x, 0, p.y), "phase": rng.randf() * 3.0})
		tree_rects.append({"r": Rect2(p.x - 1.4, p.y - 1.4, 2.8, 2.8), "kind": "tree"})
		keep_out.append([p, 4.5])
		placed += 1
	placed = 0
	tries = 0
	while placed < int(mission["bushes"]) and tries < 4000:
		tries += 1
		var p := Vector2(rng.randf_range(-half - 30, half + 30), rng.randf_range(-half - 30, half + 30))
		if not _free_spot(p, keep_out, 1.5):
			continue
		var node := Art.sprite("bush.png")
		node.position = Vector3(p.x, 0, p.y) + Rules.SPRITE_LIFT
		add_child(node)
		placed += 1
	# Trees outside the map edge make a border, not a void.
	for k in range(int(half * 0.9)):
		var side := k % 4
		var t := rng.randf_range(-half - 40, half + 40)
		var d := rng.randf_range(half + 6, half + 40)
		var p := Vector2(t, d) if side == 0 else (Vector2(t, -d) if side == 1 else (Vector2(d, t) if side == 2 else Vector2(-d, t)))
		var node := Art.sprite("tree_0.png")
		node.position = Vector3(p.x, 0, p.y) + Rules.SPRITE_LIFT
		add_child(node)
	for f in mission["flags"]:
		var node := Art.sprite("flag_0.png")
		node.position = Vector3(f.x, 0, f.y) + Rules.SPRITE_LIFT
		add_child(node)
		flags.append({"node": node, "at": Vector3(f.x, 0, f.y)})


func _free_spot(p: Vector2, keep_out: Array, road_margin: float) -> bool:
	for k in keep_out:
		if p.distance_to(k[0]) < float(k[1]):
			return false
	for pad in mission["pads"]:
		var d: Vector2 = (p - pad["at"]) / (pad["r"] + Vector2(3, 3))
		if d.length() < 1.0:
			return false
	return not ground.on_road(p, mission["roads"], road_margin)


func _spawn_pickups() -> void:
	for p in mission["pickups"]:
		_add_pickup(str(p["kind"]), Vector3(p["at"].x, 0, p["at"].y))


func _add_pickup(kind: String, at: Vector3) -> void:
	var pic: String = {"fuel": "drums.png", "ammo": "crate_ammo.png", "armor": "crate_armor.png"}[kind]
	var node := Art.sprite(pic)
	node.position = at + Rules.SPRITE_LIFT
	add_child(node)
	pickups.append({"kind": kind, "node": node, "at": at, "taken": false})


func _spawn_crew() -> void:
	for c in mission["crew"]:
		var node := Art.sprite("pilot_0.png")
		node.position = Vector3(c.x, 0, c.y) + Rules.SPRITE_LIFT
		add_child(node)
		crew.append({"node": node, "at": Vector3(c.x, 0, c.y), "state": "ground"})


# ================================================================== queries for units and HUD

func hind_targetable() -> bool:
	return phase == "play" and hind.alive and not hind.falling


func hind_band() -> int:
	return hind.band


func hind_aim_point() -> Vector3:
	return hind.aim_point()


func get_blockers() -> Array:
	if _blockers_dirty:
		blockers = tree_rects.duplicate()
		for u in units:
			if u.is_structure() and u.is_target():
				blockers.append({"r": u.block_rect(), "kind": "building"})
		_blockers_dirty = false
	return blockers


func wash_strength() -> float:
	## 1 while the attack wash is on, else 0.
	return 1.0 if wash_mode() == "attack" else 0.0


func current_objective() -> Dictionary:
	for o in objectives:
		if not o["done"]:
			return o
	return {}


# ================================================================== main loop

func _physics_process(delta: float) -> void:
	time += delta if phase == "play" and not attract else 0.0
	if attract:
		_attract(delta)
	elif phase == "play" or phase == "dead" or phase == "landing":
		_player(delta)
	for u in units:
		u.tick(delta, self)
	if not attract:
		_wash(delta)
		_pickups_and_crew(delta)
	_tick_shots(delta)
	_tick_enemy_shots(delta)
	_tick_respawns(delta)
	if not attract:
		_update_objectives()
		_end_check(delta)


func _process(delta: float) -> void:
	_effects(delta)
	_sway(delta)
	_camera(delta)
	if not attract:
		var damaged: bool = health <= Rules.ENEMY_SHOT
		hind.paint(delta, camera.global_transform.basis, wash_strength(), damaged)
		if damaged and hind.alive:
			_smoke_t -= delta
			if _smoke_t <= 0.0:
				_smoke_t = 0.12
				_effect("smoke", hind.aim_point() + Vector3(0, 0.5, 0), 1.0, 3, 1.6)
		var ok: bool = phase == "play" and hind.alive
		Sfx.rotor(ok, hind.speed() / Rules.MAX_SPEED, hind.lift / Rules.BAND_Y[2])
	for p in pickups:
		if not p["taken"]:
			p["node"].offset = Vector2(0, sin(time * 3.0 + p["at"].x) * 3.0)
	for c in crew:
		if c["state"] == "ground":
			c["node"].texture = Art.tex("pilot_%d.png" % (int(time * 3.0) % 2))


func _attract(delta: float) -> void:
	attract_t += delta
	var a := attract_t * 0.05
	cam_focus = Vector3(cos(a) * half * 0.45, 0.0, sin(a * 1.3) * half * 0.45)


func _player(delta: float) -> void:
	if phase == "dead" or phase == "landing":
		if hind.falling:
			if hind.fall(delta):
				if hind.crashing:
					_crash()
				else:
					_landed()
			return
		if phase == "landing":
			return
		dead_left -= delta
		if dead_left <= 0.0:
			if lives > 0:
				_respawn_hind()
				phase = "play"
			else:
				_lose("Hind down. No lives left.")
		return
	for k in cooldown.keys():
		cooldown[k] = maxf(0.0, cooldown[k] - delta)
	_gun_tick(delta)
	var wish := Vector2.ZERO
	var turn := 0.0
	var fire := ""
	var w := weight()
	if autopilot.is_empty():
		wish.y = Input.get_axis("thrust_back", "thrust_fwd")
		wish.x = Input.get_axis("strafe_left", "strafe_right")
		turn = Input.get_axis("turn_right", "turn_left")
		# A tap is one shove.
		var tap := Vector2.ZERO
		if Input.is_action_just_pressed("thrust_fwd"):
			tap.y += 1.0
		if Input.is_action_just_pressed("thrust_back"):
			tap.y -= 1.0
		if Input.is_action_just_pressed("strafe_right"):
			tap.x += 1.0
		if Input.is_action_just_pressed("strafe_left"):
			tap.x -= 1.0
		if tap != Vector2.ZERO:
			hind.shove(tap, w)
		if Input.is_action_just_pressed("climb"):
			_change_band(1)
		if Input.is_action_just_pressed("descend"):
			_change_band(-1)
		if Input.is_action_pressed("fire_gun"):
			fire = "gun"
		if Input.is_action_pressed("fire_rocket"):
			fire = "rocket"
		if Input.is_action_just_pressed("fire_atgm"):
			fire = "atgm"
	else:
		wish = autopilot.get("wish", Vector2.ZERO)
		turn = float(autopilot.get("turn", 0.0))
		fire = str(autopilot.get("fire", ""))
	var res: Dictionary = hind.fly(delta, wish, turn, get_blockers(), half, w)
	if bool(res["hit"]) and str(res["reason"]) != "":
		_say(Rules.stop_line(str(res["reason"])), "info", 1.4)
	if fire != "":
		_fire(fire)
	fuel = maxf(0.0, fuel - Rules.fuel_per_sec(wash_mode(), w) * delta)
	if fuel <= 0.0:
		_land_empty()


func weight() -> float:
	var full := 0.0
	var now := 0.0
	for k in Rules.WEAPONS.keys():
		full += float(Rules.WEAPONS[k]["ammo"])
		now += float(ammo.get(k, 0))
	return Rules.weight(fuel, now / maxf(full, 1.0))


func wash_mode() -> String:
	if not hind_targetable():
		return "off"
	return Rules.wash_mode(hind.band, hind.moving())


func _change_band(step: int) -> void:
	var next: int = hind.band + step
	if next < 0:
		_say(Rules.stop_line("ground"), "info", 1.0)
		return
	if next >= Rules.BANDS:
		_say(Rules.stop_line("top"), "info", 1.0)
		return
	var below: String = hind.blocker_below(next, get_blockers())
	if step < 0 and below != "":
		_say(Rules.stop_line(below), "info", 1.0)
		return
	hind.band = next


# ================================================================== weapons

func _gun_targets() -> Dictionary:
	var targets: Array = []
	var bodies: Array = []
	for u in units:
		if u.is_target() and u.state != "waiting":
			targets.append(u.position)
			bodies.append(u)
	var rects: Array = []
	for b in get_blockers():
		if b["kind"] == "building":
			rects.append(b["r"])
	var aim := Rules.gun_slew(hind.pos, hind.yaw, targets, rects, hind.band)
	aim["body"] = bodies[aim["index"]] if int(aim["index"]) >= 0 else null
	return aim


func _fire_gun() -> void:
	## Inside 20 degrees of the nose the gun slews and fires. Out to 60 it is slower.
	## Past that the shot misses. The screen says The gun is turning. while it slews.
	if gun_left > 0.0:
		if gun_pending:
			_say(Rules.shot_line("turning"), "info", 0.6)
		return
	if int(ammo["gun"]) <= 0:
		_say("Out of gun ammo.", "alert", 1.2)
		gun_left = 0.4
		return
	var aim := _gun_targets()
	if str(aim["notice"]) != "":
		_say(str(aim["notice"]), "info", 0.8)
		gun_left = Rules.GUN_WAIT_NEAR
		return
	var angle := float(aim["angle"])
	gun_left = Rules.gun_wait(angle)
	if absf(angle) <= Rules.GUN_SWEET:
		_shoot_gun(aim["body"])
		return
	gun_pending = true
	_say(Rules.shot_line("turning"), "info", 0.6)


func _gun_tick(delta: float) -> void:
	if gun_left <= 0.0:
		return
	gun_left -= delta
	if gun_left > 0.0 or not gun_pending:
		return
	gun_pending = false
	var aim := _gun_targets()
	if str(aim["notice"]) != "":
		_say(str(aim["notice"]), "info", 0.8)
		return
	_shoot_gun(aim["body"])
	gun_left = Rules.gun_wait(float(aim["angle"]))


func _shoot_gun(body) -> void:
	ammo["gun"] = int(ammo["gun"]) - 1
	var start: Vector3 = hind.aim_point() + Rules.yaw_forward(hind.yaw) * 1.8 - Vector3(0, 0.6, 0)
	var aim_at: Vector3 = body.position + Vector3(0, 0.9, 0)
	var node := Art.sprite("round.png", false, true)
	node.position = start + Rules.SPRITE_LIFT
	add_child(node)
	shots.append({
		"kind": "gun", "pos": start, "vel": (aim_at - start).normalized() * Rules.GUN_SPEED, "node": node,
		"life": start.distance_to(aim_at) / Rules.GUN_SPEED * 2.0 + 0.2, "target": body,
	})
	_effect("flash", start, 0.06, 1, 0.0)
	Sfx.play("gun", -4.0, randf_range(0.95, 1.08))


func _fire(weapon: String) -> void:
	if weapon == "gun":
		_fire_gun()
		return
	if cooldown[weapon] > 0.0:
		return
	var info: Dictionary = Rules.WEAPONS[weapon]
	if int(ammo[weapon]) <= 0:
		_say("Out of %s." % {"gun": "gun ammo", "rocket": "rockets", "atgm": "missiles"}[weapon], "alert", 1.2)
		cooldown[weapon] = 0.4
		return
	cooldown[weapon] = float(info["rate"])
	var origin: Vector3 = hind.aim_point() + Rules.yaw_forward(hind.yaw) * 1.8 - Vector3(0, 0.6, 0)
	var targets: Array = []
	var bodies: Array = []
	for u in units:
		if u.is_target() and u.state != "waiting":
			targets.append(u.position)
			bodies.append(u)
	var pick := Rules.pick_target(hind.pos, hind.yaw, targets, float(info["cone"]), float(info["range"]))
	if weapon == "atgm" and pick < 0:
		_say("No missile lock. Point the nose at a target.", "info", 1.5)
		cooldown[weapon] = 0.3
		return
	ammo[weapon] = int(ammo[weapon]) - 1
	var aim_at: Vector3
	if pick >= 0:
		aim_at = bodies[pick].position + Vector3(0, 0.9, 0)
	else:
		aim_at = hind.pos + Rules.yaw_forward(hind.yaw) * float(info["range"]) * 0.8
	var start := origin
	if weapon == "rocket":
		start += Rules.yaw_right(hind.yaw) * 1.4 * rocket_side
		rocket_side = -rocket_side
		cooldown[weapon] = float(info["rate"]) * (0.25 if rocket_side < 0.0 else 1.0)
	var dirv := (aim_at - start).normalized()
	var pic: String = {"rocket": "rocket.png", "atgm": "missile.png"}[weapon]
	var node := Art.sprite(pic, false, true)
	node.position = start + Rules.SPRITE_LIFT
	add_child(node)
	var flight := start.distance_to(aim_at) / float(info["speed"])
	shots.append({
		"kind": weapon, "pos": start, "vel": dirv * float(info["speed"]), "node": node,
		"life": maxf(flight * 1.25, 0.3), "target": bodies[pick] if pick >= 0 and weapon == "atgm" else null,
	})
	_effect("flash", start, 0.06, 1, 0.0)
	match weapon:
		"rocket":
			Sfx.play("rocket", -4.0, randf_range(0.95, 1.05))
		"atgm":
			Sfx.play("atgm", -2.0)


func _tick_shots(delta: float) -> void:
	var kept: Array = []
	for s in shots:
		var pos: Vector3 = s["pos"]
		var vel: Vector3 = s["vel"]
		if s["kind"] == "gun" and s["target"] != null and s["target"].is_target():
			vel = (s["target"].position + Vector3(0, 0.9, 0) - pos).normalized() * vel.length()
			s["vel"] = vel
		elif s["kind"] == "atgm" and s["target"] != null and s["target"].is_target():
			var want: Vector3 = (s["target"].position + Vector3(0, 0.9, 0) - pos).normalized()
			var turn := float(Rules.WEAPONS["atgm"]["turn"]) * delta
			vel = vel.normalized().slerp(want, clampf(turn, 0.0, 1.0)).normalized() * vel.length()
			s["vel"] = vel
			if randf() < 0.5:
				_effect("puff", pos, 0.5, 3, 0.4)
		elif s["kind"] == "rocket" and randf() < 0.4:
			_effect("puff", pos, 0.4, 3, 0.4)
		var next := pos + vel * delta
		var hit = null
		for u in units:
			if not u.is_target() or u.state == "waiting":
				continue
			if s["kind"] == "gun" and s["target"] != null and u != s["target"]:
				continue
			if Rules.flat(next - u.position).length() < u.radius() and next.y < 4.0:
				hit = u
				break
		var life := float(s["life"]) - delta
		if hit != null or next.y <= 0.15 or life <= 0.0:
			_impact(s, next, hit)
			s["node"].queue_free()
			continue
		s["pos"] = next
		s["life"] = life
		s["node"].position = next + Rules.SPRITE_LIFT
		kept.append(s)
	shots = kept


func _impact(s: Dictionary, at: Vector3, hit) -> void:
	var kind: String = s["kind"]
	var info: Dictionary = Rules.WEAPONS[kind]
	if kind == "gun":
		if hit != null:
			var vehicle: bool = hit.kind in ["jeep", "technical", "truck"]
			hit.hurt(Rules.damage_to(hit.kind, "gun", float(Rules.GUN_DAMAGE)), self, "gun")
			_effect("flash", at, 0.05, 1, 0.0)
			if vehicle:
				_say(Rules.shot_line("destroyed" if hit.state == "dead" else "hit"), "info")
		else:
			_effect("puff", Vector3(at.x, 0.3, at.z), 0.35, 3, 0.6)
		return
	if kind == "rocket":
		_boom(Vector3(at.x, 0.6, at.z), false)
		ground.scorch(at, 1.2)
		var radius := float(info["splash"])
		for u in units:
			if not u.is_target() or u.state == "waiting":
				continue
			var d: float = Rules.flat(at - u.position).length() - u.radius() * 0.5
			var f := Rules.splash(maxf(d, 0.0), radius)
			if f > 0.0:
				u.hurt(Rules.damage_to(u.kind, kind, float(info["damage"]) * f), self, "rocket")
		return
	if hit != null:
		hit.hurt(Rules.damage_to(hit.kind, kind, float(info["damage"])), self, kind)
		if kind == "atgm":
			_boom(Vector3(at.x, 0.8, at.z), true)
		else:
			_effect("flash", at, 0.05, 1, 0.0)
		return
	if kind == "atgm":
		_boom(Vector3(at.x, 0.6, at.z), false)
	else:
		_effect("puff", Vector3(at.x, 0.3, at.z), 0.35, 3, 0.6)


func enemy_fire(u, weapon: String) -> void:
	var winfo: Dictionary = Rules.ENEMY_WEAPONS[weapon]
	var from: Vector3 = u.muzzle()
	var target: Vector3 = Rules.lead_point(from, hind.aim_point(), hind.vel, float(winfo["speed"]))
	var spread := float(winfo["spread"])
	var dirv := (target - from).normalized()
	dirv = (dirv + Vector3(randf_range(-spread, spread), randf_range(-spread, spread) * 0.5, randf_range(-spread, spread))).normalized()
	var pic := "missile.png" if weapon == "sam" else "bullet.png"
	var node := Art.sprite(pic, false, true)
	node.position = from + Rules.SPRITE_LIFT
	add_child(node)
	var reach := float(winfo["range"]) * 1.25 / float(winfo["speed"])
	enemy_shots.append({
		"weapon": weapon, "pos": from, "vel": dirv * float(winfo["speed"]), "node": node,
		"life": Rules.SAM_LIFE if weapon == "sam" else reach, "damage": float(Rules.ENEMY_SHOT),
	})
	match weapon:
		"sam":
			Sfx.play("sam", -2.0)
			_say("Missile launch. Get down to the ground or turn hard.", "alert", 2.0)
		"cannon":
			Sfx.play("boom_small", -8.0, 1.4)
		_:
			Sfx.play("enemy_gun", -12.0, randf_range(0.9, 1.2), 0.05)


func _tick_enemy_shots(delta: float) -> void:
	var kept: Array = []
	missile_warning = false
	for s in enemy_shots:
		var pos: Vector3 = s["pos"]
		var vel: Vector3 = s["vel"]
		if s["weapon"] == "sam":
			if hind_targetable() and hind.band > 0:
				missile_warning = true
				var want: Vector3 = (hind.aim_point() - pos).normalized()
				var turn := float(Rules.ENEMY_WEAPONS["sam"]["turn"]) * delta
				vel = vel.normalized().slerp(want, clampf(turn, 0.0, 1.0)).normalized() * vel.length()
				s["vel"] = vel
			if randf() < 0.6:
				_effect("puff", pos, 0.6, 3, 0.3)
		var next := pos + vel * delta
		var life := float(s["life"]) - delta
		var hit := false
		if hind_targetable():
			var radius := Rules.SHOT_HIT_RADIUS * (1.4 if s["weapon"] == "flak" else 1.0)
			hit = next.distance_to(hind.aim_point()) < radius
		if hit:
			_hind_hit(float(s["damage"]), s["weapon"])
			s["node"].queue_free()
			continue
		if life <= 0.0 or next.y < 0.0:
			if s["weapon"] == "sam" or s["weapon"] == "flak":
				_effect("smoke", next, 0.6, 3, 0.8)
			s["node"].queue_free()
			continue
		s["pos"] = next
		s["life"] = life
		s["node"].position = next + Rules.SPRITE_LIFT
		kept.append(s)
	enemy_shots = kept
	if missile_warning:
		Sfx.play("warn", -8.0, 1.0, 0.45)


func _hind_hit(_damage: float, weapon: String) -> void:
	## An enemy shot removes 2. At 0 the Hind crashes.
	hits_taken += 1
	if invincible:
		return
	health = maxi(0, health - Rules.ENEMY_SHOT)
	shake = maxf(shake, 0.35 if weapon != "sam" else 0.7)
	Sfx.play("hit", -6.0, randf_range(0.9, 1.1), 0.06)
	if weapon == "sam" or weapon == "cannon":
		_boom(hind.aim_point(), false)
	if health <= 0:
		_say(Rules.end_line("down"), "alert")
		_go_down()
	else:
		_say("Hit.", "alert")


# ================================================================== wash, pickups, crew

func _wash(delta: float) -> void:
	var strength := wash_strength()
	if strength <= 0.0:
		return
	for u in units:
		if not u.is_active():
			continue
		var d: float = Rules.flat(u.position - hind.pos).length()
		if d > Rules.WASH_RADIUS:
			continue
		var rate := Rules.tip_rate(u.kind, d)
		if rate > 0.0:
			if u.wash(rate, delta):
				Sfx.play("flip", -2.0)
				_effect("puff", u.position + Vector3(0, 0.5, 0), 0.6, 3, 1.0)
		elif Rules.shakes(u.kind):
			u.washed = true
			u.tip = minf(0.35, u.tip + delta * strength)


func _pickups_and_crew(delta: float) -> void:
	if not hind_targetable():
		return
	if hind.band <= 1:
		for p in pickups:
			if p["taken"]:
				continue
			if Rules.flat(p["at"] - hind.pos).length() < Rules.PICKUP_RADIUS:
				_take(p)
	var slow: bool = hind.band == 0 and not hind.moving()
	var near_crew = null
	if slow and aboard < Rules.CREW_CAPACITY:
		for c in crew:
			if c["state"] == "ground" and Rules.flat(c["at"] - hind.pos).length() < Rules.WINCH_RADIUS:
				near_crew = c
				break
	if near_crew != null:
		if winch_t <= 0.0:
			Sfx.play("winch", -6.0)
		winch_t += delta
		near_crew["node"].position.y = Rules.SPRITE_LIFT.y + winch_t / Rules.WINCH_SEC * (hind.lift + 2.0)
		if winch_t >= Rules.WINCH_SEC:
			winch_t = 0.0
			near_crew["state"] = "aboard"
			near_crew["node"].visible = false
			aboard += 1
			Sfx.play("rescue", -4.0)
			_say("Crew aboard (%d/%d). Take them to the LZ." % [aboard, Rules.CREW_CAPACITY], "good")
	else:
		if winch_t > 0.0:
			for c in crew:
				if c["state"] == "ground":
					c["node"].position.y = Rules.SPRITE_LIFT.y
		winch_t = 0.0
	var at_lz: bool = slow and Rules.flat(lz - hind.pos).length() < Rules.LZ_RADIUS
	if at_lz and aboard > 0:
		unload_t += delta
		if unload_t >= Rules.UNLOAD_SEC:
			unload_t = 0.0
			aboard -= 1
			delivered += 1
			for c in crew:
				if c["state"] == "aboard":
					c["state"] = "home"
					break
			Sfx.play("rescue", -2.0, 1.3)
			_say("Crew safe at the LZ (%d delivered)." % delivered, "good")
	else:
		unload_t = 0.0


func _take(p: Dictionary) -> void:
	p["taken"] = true
	p["node"].queue_free()
	Sfx.play("pickup", -3.0)
	match p["kind"]:
		"fuel":
			fuel = minf(Rules.FUEL_START, fuel + Rules.PICKUP_FUEL)
			_say("Fuel +%d" % int(Rules.PICKUP_FUEL), "good")
		"armor":
			health = mini(Rules.HEALTH_START, health + Rules.PICKUP_HEALTH)
			_say("Health +%d" % Rules.PICKUP_HEALTH, "good")
		"ammo":
			for w in Rules.PICKUP_AMMO.keys():
				ammo[w] = mini(int(Rules.WEAPONS[w]["ammo"]), int(ammo[w]) + int(Rules.PICKUP_AMMO[w]))
			_say("Ammo reloaded", "good")


# ================================================================== unit events

func unit_destroyed(u, how: String) -> void:
	if u.state == "dead":
		return
	u.kill()
	if u.is_structure():
		_blockers_dirty = true
	var big: bool = u.kind != "soldier"
	if big:
		_boom(u.position + Vector3(0, 1.0, 0), u.radius() > 2.5)
		ground.scorch(u.position, u.radius() * 0.9)
	if how == "wash":
		flips += 1
		_say("%s flipped!" % _unit_name(u.kind), "good", 1.5)
	kills += 1
	if u.drop != "":
		_add_pickup(u.drop, u.position + Vector3(0, 0, 3.0))
		_say("Something was hidden in there.", "good", 2.0)
	for o in objectives:
		var spec: Dictionary = o["spec"]
		if spec["type"] == "flip" and str(spec["tag"]) == u.tag and how != "wash" and u.tag != "":
			respawn_queue.append({"spec": u.spawn_spec, "left": 10.0})
			_say("That one was shot, not flipped. Another is on its way.", "info", 3.0)


func unit_escaped(u) -> void:
	escaped[u.tag] = int(escaped.get(u.tag, 0)) + 1
	if u.tag != "":
		_say("A %s got through!" % _unit_name(u.kind).to_lower(), "alert", 2.5)


func _tick_respawns(delta: float) -> void:
	var kept: Array = []
	for r in respawn_queue:
		r["left"] = float(r["left"]) - delta
		if r["left"] <= 0.0:
			_add_unit(r["spec"], units.size() + 500)
		else:
			kept.append(r)
	respawn_queue = kept


func _unit_name(kind: String) -> String:
	return {"soldier": "Soldier", "jeep": "Jeep", "technical": "Technical", "truck": "Truck", "aaa": "AA gun",
		"zsu": "ZSU-23", "sam": "SAM site", "tank": "Tank", "radar": "Radar", "depot": "Depot",
		"bunker": "Bunker", "building": "Building"}.get(kind, kind)


# ================================================================== objectives and endings

func _update_objectives() -> void:
	var others_done := true
	for o in objectives:
		var spec: Dictionary = o["spec"]
		var was: bool = o["done"]
		match str(spec["type"]):
			"destroy":
				var total := 0
				var left := 0
				for u in units:
					if u.tag == str(spec["tag"]):
						total += 1
						if u.state != "dead" and u.state != "escaped":
							left += 1
				o["progress"] = "%d/%d" % [total - left, total]
				o["done"] = total > 0 and left == 0
			"flip":
				var n := 0
				for u in units:
					if u.tag == str(spec["tag"]) and u.flipped:
						n += 1
				o["progress"] = "%d/%d" % [mini(n, int(spec["count"])), int(spec["count"])]
				o["done"] = n >= int(spec["count"])
			"rescue":
				o["progress"] = "%d/%d" % [mini(delivered, int(spec["count"])), int(spec["count"])]
				o["done"] = delivered >= int(spec["count"])
			"stop":
				var total := 0
				var open := 0
				for u in units:
					if u.tag == str(spec["tag"]):
						total += 1
						if u.state == "alive" or u.state == "waiting" or u.state == "tip":
							open += 1
				var got := int(escaped.get(str(spec["tag"]), 0))
				o["progress"] = "%d got through, %d stopped" % [got, total - open - got]
				if got > int(spec.get("allow", 0)):
					o["failed"] = true
				o["done"] = open == 0 and not o["failed"]
			"return":
				o["done"] = false
				if others_done and phase == "play" and hind.alive:
					o["progress"] = "Land on the pad"
					var slow: bool = hind.band == 0 and not hind.moving()
					if slow and Rules.flat(lz - hind.pos).length() < Rules.LZ_RADIUS and aboard == 0:
						land_t += 1.0 / 60.0
						if land_t > 1.0:
							o["done"] = true
					else:
						land_t = 0.0
				else:
					o["progress"] = ""
		if o["failed"] and phase == "play":
			_lose("Objective failed: %s" % str(spec["label"]))
		if not was and o["done"] and str(spec["type"]) != "return" and not attract:
			Sfx.play("objective", -3.0)
			_say("Objective complete: %s" % str(spec["label"]), "good", 3.0)
		if str(spec["type"]) != "return" and not o["done"]:
			others_done = false
	if phase == "play" and not objectives.is_empty() and objectives[-1]["done"]:
		_win()


func _end_check(delta: float) -> void:
	if phase == "won" or phase == "lost":
		end_left -= delta
		if end_left <= 0.0 and end_left > -100.0:
			end_left = -1000.0
			finished.emit(phase == "won", stats())


func _win() -> void:
	phase = "won"
	end_left = 2.5
	Sfx.play("objective", 0.0, 1.2)
	_say(Rules.end_line("clear"), "good", 3.0)


func _lose(reason: String) -> void:
	if phase == "won" or phase == "lost":
		return
	phase = "lost"
	fail_reason = reason
	end_left = 2.5
	Sfx.play("fail", 0.0)
	_say(reason, "alert", 3.0)


func stats() -> Dictionary:
	var score := 0
	for u in units:
		if u.state == "dead":
			score += int(u.info["score"])
	score += delivered * 500 + flips * 100
	if phase == "won":
		score += lives * 1000 + int(fuel) * 10
	return {
		"mission": mission_index, "name": mission["name"], "won": phase == "won", "reason": fail_reason,
		"time": time, "kills": kills, "flips": flips, "crew": delivered, "lives": lives, "score": score,
		"end": _end_key(),
	}


func _end_key() -> String:
	if phase == "won":
		return "clear"
	if fail_reason.begins_with("Landed"):
		return "landed"
	if fail_reason.begins_with("Hind down"):
		return "down"
	return ""


# ================================================================== death and respawn

func _go_down() -> void:
	## Health at zero: she crashes. Hind down.
	if phase != "play":
		return
	phase = "dead"
	hind.start_fall(true)
	Sfx.rotor(false)


func _land_empty() -> void:
	## Fuel at zero: she autorotates and lands. Empty fuel does not destroy the Hind.
	if phase != "play":
		return
	phase = "landing"
	hind.start_fall(false)
	_say(Rules.end_line("landing"), "alert")


func _landed() -> void:
	hind.falling = false
	Sfx.rotor(false)
	_say(Rules.end_line("landed"), "alert")
	_lose("Landed. The fuel ran out.")


func _crash() -> void:
	hind.alive = false
	hind.falling = false
	hind.visible = false
	_boom(hind.aim_point(), true)
	ground.scorch(hind.pos, 3.0)
	shake = 1.0
	lives -= 1
	dead_left = Rules.RESPAWN_SEC
	# Crew aboard jump clear and wait at the crash site.
	var dropped := 0
	for c in crew:
		if c["state"] == "aboard":
			c["state"] = "ground"
			var off := Vector3(cos(dropped * 2.1), 0, sin(dropped * 2.1)) * 3.0
			c["at"] = hind.pos + off
			c["node"].position = c["at"] + Rules.SPRITE_LIFT
			c["node"].visible = true
			dropped += 1
	aboard = 0
	if lives > 0:
		_say("Hind down. %d %s left." % [lives, "life" if lives == 1 else "lives"], "alert")


func _respawn_hind() -> void:
	hind.place(lz, lz_yaw)
	health = Rules.HEALTH_START
	fuel = Rules.FUEL_START
	ammo = {}
	for w in Rules.WEAPONS.keys():
		ammo[w] = int(Rules.WEAPONS[w]["ammo"])
	cam_focus = lz
	enemy_shots_clear()


func enemy_shots_clear() -> void:
	for s in enemy_shots:
		s["node"].queue_free()
	enemy_shots = []


# ================================================================== effects and camera

func _boom(at: Vector3, big: bool) -> void:
	var node := Art.sprite("boom_0.png", false, true)
	node.position = at + Rules.SPRITE_LIFT
	node.scale = Vector3.ONE * (2.0 if big else 1.2)
	add_child(node)
	effects.append({"node": node, "life": 0.72, "max": 0.72, "base": "boom", "frames": 4, "rise": 0.0})
	Sfx.play("boom" if big else "boom_small", -2.0 if big else -5.0, randf_range(0.9, 1.1))
	if hind != null and hind.alive:
		var d := Rules.flat(at - hind.pos).length()
		shake = maxf(shake, clampf((1.0 if big else 0.35) * (1.0 - d / 40.0), 0.0, 0.8))
	for k in range(3 if big else 1):
		_effect("smoke", at + Vector3(randf_range(-1, 1), 0.5, randf_range(-1, 1)), 1.4, 3, 1.2)


func _effect(base: String, at: Vector3, life: float, frames: int, rise: float) -> void:
	if effects.size() > 220:
		return
	var first := "%s_0.png" % base if frames > 1 else "%s.png" % base
	var node := Art.sprite(first, false, true)
	node.position = at + Rules.SPRITE_LIFT
	add_child(node)
	effects.append({"node": node, "life": life, "max": life, "base": base, "frames": frames, "rise": rise})


func _effects(delta: float) -> void:
	var kept: Array = []
	for e in effects:
		e["life"] = float(e["life"]) - delta
		var node: Sprite3D = e["node"]
		if e["life"] <= 0.0:
			node.queue_free()
			continue
		var frames := int(e["frames"])
		if frames > 1:
			var f := clampi(int((1.0 - e["life"] / e["max"]) * frames), 0, frames - 1)
			node.texture = Art.tex("%s_%d.png" % [e["base"], f])
		node.position.y += float(e["rise"]) * delta
		kept.append(e)
	effects = kept


func _sway(_delta: float) -> void:
	var near_hind: bool = hind != null and hind.alive and hind.lift < Rules.BAND_Y[1] + 2.0
	for t in trees:
		var frame := 0
		if near_hind and Rules.flat(t["at"] - hind.pos).length() < 12.0:
			frame = int(time * 10.0 + t["phase"]) % 3
		t["node"].texture = Art.tex("tree_%d.png" % frame)
	for f in flags:
		var fast: bool = near_hind and Rules.flat(f["at"] - hind.pos).length() < 14.0
		f["node"].texture = Art.tex("flag_%d.png" % (int(time * (9.0 if fast else 2.5)) % 3))


func _camera(delta: float) -> void:
	var lift := 0.0
	var target := cam_focus
	if not attract and hind != null:
		lift = hind.lift
		target = hind.pos + hind.vel * Rules.CAM_LEAD
	var k := 1.0 - exp(-4.0 * delta)
	cam_focus = cam_focus.lerp(target, k) if not attract else target
	var lim := half - 12.0
	var focus := Vector3(clampf(cam_focus.x, -lim, lim), 0.0, clampf(cam_focus.z, -lim, lim))
	var step_f := Rules.band_of_lift(lift)
	var size: float = lerpf(Rules.CAM_SIZE[0], Rules.CAM_SIZE[1], clampf(step_f, 0.0, 1.0))
	if step_f > 1.0:
		size = lerpf(Rules.CAM_SIZE[1], Rules.CAM_SIZE[2], step_f - 1.0)
	if attract:
		size = 46.0
	camera.size = size
	# Orthographic: pulling the camera far back changes nothing on screen but keeps the
	# near plane clear of the ground at the bottom of the view.
	camera.global_position = Vector3(focus.x, lift, focus.z) + Rules.CAM_OFFSET.normalized() * 160.0
	camera.look_at(Vector3(focus.x, lift + 0.6, focus.z), Vector3.UP)
	if shake > 0.0:
		shake = maxf(0.0, shake - delta * 1.8)
		if Settings.shake:
			var b := camera.global_transform.basis
			camera.global_position += (b.x * randf_range(-1, 1) + b.y * randf_range(-1, 1)) * shake * 0.7


func _say(text: String, tone := "info", gap := 0.0) -> void:
	if gap > 0.0:
		var last := float(_msg_cache.get(text, -100.0))
		if time - last < gap and time > 0.0:
			return
		_msg_cache[text] = time
	message.emit(text, tone)
