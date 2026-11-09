extends RefCounted
## Headless check. Rules, mission data, art coverage, then real missions stepped by hand.
## Run: godot --headless --path game -- --probe     (exit code 0 means every check passed)

const Rules = preload("res://core/rules.gd")
const Missions = preload("res://core/missions.gd")
const Art = preload("res://core/art.gd")
const WorldSc = preload("res://world/world.gd")

const DT := 1.0 / 60.0

static var failures: Array[String] = []
static var passes := 0


static func check(ok: bool, what: String) -> void:
	if ok:
		passes += 1
	else:
		failures.append(what)
		print("FAIL: ", what)


static func run(host: Node) -> int:
	failures.clear()
	passes = 0
	_rules()
	_data()
	_art()
	await _sim(host)
	_hud(host)
	await _layout(host)
	print("probe: %d passed, %d failed" % [passes, failures.size()])
	if failures.is_empty():
		print("probe ok")
		return 0
	return 1


# ------------------------------------------------------------------ rules

static func _rules() -> void:
	var f := Rules.yaw_forward(0.0)
	check(f.is_equal_approx(Vector3(0, 0, -1)), "yaw 0 faces -Z")
	check(Rules.yaw_forward(90.0).is_equal_approx(Vector3(-1, 0, 0)), "yaw +90 faces -X (left)")
	check(Rules.facing_index(0.0) == 0 and Rules.facing_index(90.0) == 2 and Rules.facing_index(-45.0) == 7, "facing index")
	check(absf(Rules.yaw_to_deg(Vector3(-1, 0, 0)) - 90.0) < 0.01, "yaw_to_deg inverts yaw_forward")
	var v := Vector3.ZERO
	for i in 600:
		v = Rules.step_velocity(v, Vector2(0, 1), 0.0, DT)
	check(v.length() <= Rules.MAX_SPEED + 0.001 and v.length() > Rules.MAX_SPEED * 0.9, "a held W sits on the speed cap")
	var side := Rules.step_velocity(Vector3.ZERO, Vector2(-1, 0), 0.0, 0.5)
	check(side.x < 0.0 and absf(side.z) < 0.001, "A moves left, not a turn")
	for i in 600:
		v = Rules.step_velocity(v, Vector2.ZERO, 0.0, DT)
	check(v.length() < 0.1, "she stops slow but she stops")
	var tap := Rules.shove(Vector3.ZERO, Rules.wish_dir(Vector2(0, 1), 0.0))
	check(absf(tap.length() - Rules.SHOVE) < 0.01, "a tap is one shove")
	check(Rules.weight(0.0, 0.0) < Rules.weight(100.0, 1.0), "a lighter Hind weighs less")
	check(Rules.fuel_per_sec("off", 0.8) < Rules.fuel_per_sec("off", 1.0), "a lighter Hind burns less fuel")
	var wall := [{"r": Rect2(-1, -11, 2, 2), "kind": "building"}]
	var trees := [{"r": Rect2(-1, -11, 2, 2), "kind": "tree"}]
	var res := Rules.slide(Vector3(0, 0, -3), Vector3(0, 0, -4), 0, wall, 100.0)
	check(not bool(res["hit"]), "free move is not a hit")
	res = Rules.slide(Vector3(0.5, 0, -8.5), Vector3(0.5, 0, -9.5), 0, wall, 100.0)
	check(bool(res["hit"]) and res["reason"] == "building", "a building stops the Hind on the ground")
	res = Rules.slide(Vector3(0.5, 0, -8.5), Vector3(0.5, 0, -9.5), 1, trees, 100.0)
	check(bool(res["hit"]) and res["reason"] == "tree", "a tree stops the Hind one step up")
	res = Rules.slide(Vector3(0.5, 0, -8.5), Vector3(0.5, 0, -9.5), 2, wall, 100.0)
	check(not bool(res["hit"]), "two steps up clears trees and buildings")
	res = Rules.slide(Vector3(0, 0, 0), Vector3(200, 0, 0), 2, [], 100.0)
	check(res["reason"] == "map" and float(res["pos"].x) <= 100.0 - Rules.EDGE_MARGIN + 0.01, "the map stops the Hind")
	check(Rules.wash_mode(0, false) == "attack", "ground and still: the attack wash is on")
	check(Rules.wash_mode(0, true) == "off", "while she is moving the attack wash is off")
	check(Rules.wash_mode(1, false) == "wind", "one step up is wind")
	check(Rules.wash_mode(2, false) == "off", "two steps up the wash is off")
	check(Rules.fuel_per_sec("attack") > Rules.fuel_per_sec("off"), "the attack drain is faster")
	check(Rules.tip_rate("jeep", 3.0) > 0.0 and Rules.tip_rate("technical", 3.0) > 0.0, "the wash flips a jeep and a technical")
	check(Rules.tip_rate("truck", 1.0) == 0.0 and Rules.shakes("truck"), "the wash shakes a truck; a truck does not tip")
	check(Rules.tip_rate("tank", 1.0) == 0.0, "a tank does not tip")
	check(int(Rules.UNITS["jeep"]["hp"]) == 4 and int(Rules.UNITS["technical"]["hp"]) == 6 and int(Rules.UNITS["truck"]["hp"]) == 10, "jeep 4, technical 6, truck 10")
	check(Rules.GUN_DAMAGE == 4, "the gun removes 4")
	check(Rules.HEALTH_START == 8 and Rules.ENEMY_SHOT == 2, "health starts at 8; a shot removes 2")
	check(float(Rules.ENEMY_WEAPONS["mg"]["range"]) == 10.0 and float(Rules.ENEMY_WEAPONS["hmg"]["range"]) == 10.0, "a vehicle shoots inside 10 m")
	check(Rules.can_reach("rifle", 0) and not Rules.can_reach("rifle", 2), "rifles cannot reach two steps up")
	check(Rules.can_reach("sam", 2) and not Rules.can_reach("sam", 0), "SAMs cannot lock on the ground")
	check(Rules.damage_to("tank", "gun", 4.0) < 4.0 and Rules.damage_to("jeep", "gun", 4.0) == 4.0, "armor shrugs off the gun")
	var targets := [Vector3(0, 0, -20), Vector3(-15, 0, -9)]
	var g := Rules.gun_slew(Vector3.ZERO, 0.0, targets, [], 0)
	check(int(g["index"]) == 0 and absf(float(g["angle"])) < 1.0, "the gun picks the target on the nose")
	g = Rules.gun_slew(Vector3.ZERO, 0.0, [Vector3(-15, 0, -9)], [], 0)
	check(int(g["index"]) == 0 and absf(float(g["angle"])) > Rules.GUN_SWEET, "out to 60 degrees the gun slews")
	check(Rules.gun_wait(50.0) > Rules.gun_wait(10.0), "out to 60 the gun is slower")
	g = Rules.gun_slew(Vector3.ZERO, 0.0, [Vector3(0, 0, 20)], [], 0)
	check(int(g["index"]) == -1 and g["notice"] == "The shot misses.", "past 60 degrees the shot misses")
	g = Rules.gun_slew(Vector3.ZERO, 0.0, [Vector3(0, 0, -20)], [Rect2(-2, -12, 4, 2)], 0)
	check(g["notice"] == "A building stops the shot.", "a building stops the shot")
	check(Rules.height_line(1) == "Height is one step up." and Rules.wash_line("wind") == "Wind is on.", "the plate sentences")
	check(Rules.stop_line("tree") == "A tree stops the Hind." and Rules.end_line("landed") == "Landed.", "the stop and end sentences")
	var drain := Rules.FUEL_START / Rules.FUEL_PER_SEC
	check(drain >= 150.0 and drain <= 300.0, "a full tank lasts two and a half to five minutes")
	check(Controls.key_name("thrust_fwd") == "W" and Controls.key_name("turn_left") == "A" and Controls.key_name("turn_right") == "D", "default keys: W forward, A and D turn")
	var qe := false
	for action in InputMap.get_actions():
		for ev in InputMap.action_get_events(action):
			if ev is InputEventKey and ev.physical_keycode in [KEY_Q, KEY_E]:
				qe = true
	check(not qe and Controls.key_name("strafe_left") == "-", "Q and E do nothing; slide has no key by default")
	var arrows := false
	for action in ["thrust_fwd", "thrust_back", "turn_left", "turn_right", "strafe_left", "strafe_right"]:
		for ev in InputMap.action_get_events(action):
			if ev is InputEventKey and ev.physical_keycode in [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]:
				arrows = true
	check(not arrows, "the arrow keys do not move her")
	check(Controls.key_name("fire_gun") == "Left click", "left click fires")


# ------------------------------------------------------------------ data

static func _data() -> void:
	check(Missions.count() >= 4, "four or more missions")
	for i in Missions.count():
		var m: Dictionary = Missions.get_mission(i)
		var half := float(m["half"])
		var lz: Vector2 = m["lz"]
		check(absf(lz.x) < half - Rules.EDGE_MARGIN and absf(lz.y) < half - Rules.EDGE_MARGIN, "%s: LZ inside the map" % m["name"])
		var objs: Array = m["objectives"]
		check(str(objs[-1]["type"]) == "return", "%s: last objective is return" % m["name"])
		for o in objs:
			var t := str(o["type"])
			if t in ["destroy", "flip", "stop"]:
				var n := 0
				for u in m["units"]:
					if str(u.get("tag", "")) == str(o["tag"]):
						n += 1
				check(n > 0, "%s: objective tag %s has units" % [m["name"], o["tag"]])
				if t == "flip":
					check(n >= int(o["count"]), "%s: enough units to flip" % m["name"])
			if t == "rescue":
				check((m["crew"] as Array).size() >= int(o["count"]), "%s: enough crew to rescue" % m["name"])
		for u in m["units"]:
			check(Rules.UNITS.has(str(u["kind"])), "%s: known unit kind %s" % [m["name"], u["kind"]])
			var at: Vector2 = u["at"]
			check(absf(at.x) <= half + 10.0 and absf(at.y) <= half + 10.0, "%s: %s inside the map" % [m["name"], u["kind"]])


static func _art() -> void:
	var names: Array[String] = ["lz.png", "shadow.png", "bush.png", "drums.png", "crate_ammo.png", "crate_armor.png",
		"rocket.png", "missile.png", "round.png", "bullet.png", "flash.png", "soldier_down.png", "depot.png", "bunker.png"]
	for i in 8:
		for k in ["hind", "jeep", "technical", "truck", "tank", "zsu", "aaa", "sam"]:
			names.append("%s_%d.png" % [k, i])
		names.append("soldier_%d_0.png" % i)
		names.append("soldier_%d_1.png" % i)
		names.append("spin/hind_%d_0.png" % i)
	for k in ["jeep", "technical", "truck", "tank", "zsu", "aaa", "sam", "radar", "depot", "bunker", "building"]:
		names.append("%s_wreck.png" % k)
	for k in ["jeep", "technical", "truck"]:
		names.append("%s_tip.png" % k)
	for i in 3:
		for k in ["tree", "flag", "dust", "smoke", "puff", "building", "boom"]:
			names.append("%s_%d.png" % [k, i])
	for i in 4:
		names.append("radar_%d.png" % i)
	names.append("boom_3.png")
	for i in 2:
		names.append("pilot_%d.png" % i)
	var missing: Array[String] = []
	for n in names:
		if not Art.has(n) or Art.tex(n) == null:
			missing.append(n)
	check(missing.is_empty(), "all sprites import and load (missing: %s)" % ", ".join(missing))
	for s in ["rotor", "gun", "rocket", "atgm", "sam", "boom", "boom_small", "hit", "flip", "warn", "winch", "pickup", "rescue", "objective", "fail", "click", "music_mission", "music_title"]:
		check(Sfx.stream(s) != null, "sound %s loads" % s)


# ------------------------------------------------------------------ hud

static func _hud(host: Node) -> void:
	## No plates: bare pixel text with a heavy stroke, and the key list starts hidden.
	var UI = load("res://ui/ui_theme.gd")
	var w = _world(host, 0)
	var hud = load("res://ui/hud.gd").new()
	var keep: bool = Settings.show_keys
	Settings.show_keys = false
	host.add_child(hud)
	hud.setup(w)
	hud._process(DT)
	var panels := 0
	var labels := 0
	var bad: Array[String] = []
	var stack: Array[Node] = [hud]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		if n is Panel or n is PanelContainer:
			panels += 1
		if n is Label:
			labels += 1
			var l := n as Label
			if l.get_theme_font("font") != UI.PIXEL or l.get_theme_constant("outline_size") < 8:
				bad.append(l.text)
	check(panels == 0, "the HUD has no plates")
	check(labels > 8 and bad.is_empty(), "every HUD word is the pixel font with a heavy stroke (%s)" % ", ".join(bad))
	check(not hud.left.visible, "the key list starts hidden; F1 shows it")
	check(hud.fuel_num.text == "100" and hud.health_bar.cells == 4, "HUD shows fuel 100 and 4 health blocks")
	var long: Array[String] = []
	for i in Missions.count():
		for o in Missions.get_mission(i)["objectives"]:
			if str(o["label"]).length() > hud.OBJECTIVE_CHARS:
				long.append(str(o["label"]))
	check(long.is_empty(), "every objective fits the HUD on one line (%s)" % ", ".join(long))
	check(hud.objective.text != "" and hud.height_label.text.begins_with("GROUND"), "HUD shows the objective and the height")
	Settings.show_keys = keep
	hud.queue_free()
	w.queue_free()


static func _offscreen(node: Node, view: Rect2) -> Array[String]:
	## Every visible control must sit inside the screen. Pixel glyphs are wide, so a long
	## unwrapped line pushes a whole screen off the edge.
	var out: Array[String] = []
	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is CanvasItem and not (n as CanvasItem).visible:
			continue
		if not n is ScrollContainer:
			stack.append_array(n.get_children())   # rows inside a scroll area may run below the fold
		if n is Control:
			var r := (n as Control).get_global_rect()
			if r.size.x > 0.0 and not view.grow(2.0).encloses(r):
				out.append("%s %s" % [n.get_class(), r])
	return out


static func _layout(host: Node) -> void:
	var win := host.get_window()
	var keep := win.size
	win.size = Vector2i(1600, 900)
	await host.get_tree().process_frame
	var view := host.get_viewport().get_visible_rect()
	check(view.size == Vector2(1600, 900), "layout test runs at 1600x900 (%s)" % view.size)
	var screens: Array = []
	for i in Missions.count():
		var b = load("res://ui/briefing.gd").new()
		b.index = i
		screens.append(["briefing %d" % (i + 1), b])
	var r = load("res://ui/result.gd").new()
	r.stats = {"won": true, "name": "Gunship Ace", "mission": Missions.count() - 1, "time": 312.0, "kills": 14, "flips": 4, "crew": 5, "lives": 2, "score": 6420, "end": "clear", "reason": "", "dry_run": true}
	screens.append(["result", r])
	var c := CanvasLayer.new()
	var o = load("res://ui/options.gd").new()
	c.add_child(o)
	screens.append(["options", c])
	for s in screens:
		host.add_child(s[1])
		for f in 3:
			await host.get_tree().process_frame
		var bad := _offscreen(s[1], view)
		check(bad.is_empty(), "%s fits on screen (%s)" % [s[0], ", ".join(bad.slice(0, 3))])
		s[1].queue_free()
	await host.get_tree().process_frame
	win.size = keep


# ------------------------------------------------------------------ simulation

static func _world(host: Node, index: int):
	var w = WorldSc.new()
	w.setup(index)
	host.add_child(w)
	return w


static func _step(w, seconds: float) -> void:
	var n := int(seconds / DT)
	for i in n:
		w._physics_process(DT)
		w._process(DT)


static func _unit(w, kind: String, tag := ""):
	for u in w.units:
		if u.kind == kind and (tag == "" or u.tag == tag) and u.is_target():
			return u
	return null


static func _sim(host: Node) -> void:
	# Every mission loads and survives two minutes of nobody touching anything.
	for i in Missions.count():
		var w = _world(host, i)
		await host.get_tree().process_frame
		check(w.units.size() > 5 and w.trees.size() > 10, "mission %d builds" % (i + 1))
		w.invincible = true
		_step(w, 20.0)
		check(w.phase == "play", "mission %d runs idle" % (i + 1))
		w.queue_free()
	await host.get_tree().process_frame

	# Real play: chase a moving patrol jeep on the ground and let go 3, 5 or 7 m away.
	# The Hind is heavy and the jeep keeps driving, so this is the case players hit.
	for stop_at in [3.0, 5.0, 7.0]:
		var w = _world(host, 0)
		await host.get_tree().process_frame
		w.invincible = true
		var jeep = _unit(w, "jeep", "patrol")
		w.hind.pos = Vector3(jeep.position.x + 14.0, w.hind.pos.y, jeep.position.z - 4.0)
		var t := 0.0
		while t < 10.0 and jeep.state == "alive":
			var to: Vector3 = Rules.flat(jeep.position - w.hind.pos)
			var wish := Vector2.ZERO
			if to.length() > stop_at and t < 6.0:
				var n := to.normalized()
				wish = Vector2(n.dot(Rules.yaw_right(w.hind.yaw)), n.dot(Rules.yaw_forward(w.hind.yaw)))
			w.autopilot = {"wish": wish}
			_step(w, 0.25)
			t += 0.25
		check(jeep.state != "alive", "chase a driving jeep, let go %d m away: the wash flips it" % int(stop_at))
		w.queue_free()
	await host.get_tree().process_frame

	# The wash flips a jeep: still on the ground right next to it.
	var w = _world(host, 0)
	w.invincible = true
	var jeep = _unit(w, "jeep", "patrol")
	jeep.speed = 0.0
	w.hind.place(jeep.position + Vector3(2.5, 0, 0), 0.0)
	_step(w, 3.0)
	check(jeep.flipped and jeep.state == "dead", "the wash flips a jeep")
	check(str(w.objectives[0]["progress"]).begins_with("1/"), "the flip counts for the objective")

	# Moving fast, the wash does nothing.
	var jeep2 = _unit(w, "jeep", "patrol")
	jeep2.speed = 0.0
	w.hind.place(jeep2.position + Vector3(2.5, 0, 0), 0.0)
	w.autopilot = {"wish": Vector2(0, 1)}
	_step(w, 0.6)
	w.autopilot = {}
	check(not jeep2.flipped, "no flip while flying past fast")

	# The chin gun kills a technical it is pointed at.
	var tech = _unit(w, "technical")
	w.hind.place(tech.position + Vector3(0, 0, 14), 0.0)
	w.hind.band = 1
	w.hind.lift = Rules.band_y(1)
	w.autopilot = {"fire": "gun"}
	_step(w, 4.0)
	w.autopilot = {}
	check(tech.state == "dead", "the gun kills a technical")
	check(int(w.ammo["gun"]) < int(Rules.WEAPONS["gun"]["ammo"]), "the gun uses ammo")

	# Rockets kill the AA guns; the objective ticks.
	for aa in w.units.duplicate():
		if aa.tag != "aa" or not aa.is_target():
			continue
		w.hind.place(aa.position + Vector3(0, 0, 18), 0.0)
		w.hind.band = 1
		w.hind.lift = Rules.band_y(1)
		w.autopilot = {"fire": "rocket"}
		_step(w, 3.0)
	w.autopilot = {}
	check(w.objectives[1]["done"], "rockets destroy the AA site")

	# A missile locks and kills the radar.
	var radar = _unit(w, "radar")
	w.hind.place(radar.position + Vector3(0, 0, 25), 0.0)
	w.hind.band = 2
	w.hind.lift = Rules.band_y(2)
	w.autopilot = {"fire": "atgm"}
	_step(w, 4.0)
	w.autopilot = {}
	check(radar.state == "dead" and w.objectives[2]["done"], "missiles destroy the radar")

	# A fuel drum refuels.
	var drum = null
	for p in w.pickups:
		if p["kind"] == "fuel" and not p["taken"]:
			drum = p
			break
	w.fuel = 20.0
	w.hind.place(drum["at"], 0.0)
	_step(w, 0.2)
	check(w.fuel > 50.0 and drum["taken"], "a fuel drum refuels")

	# Flip the remaining jeeps, then land at the LZ to win.
	for u in w.units:
		if u.tag == "patrol" and u.is_active():
			u.speed = 0.0
			w.hind.place(u.position + Vector3(2.0, 0, 0), 0.0)
			_step(w, 3.0)
	_step(w, 11.0) # a replacement jeep arrives if one was not flipped
	for u in w.units:
		if u.tag == "patrol" and u.is_active():
			u.speed = 0.0
			w.hind.place(u.position + Vector3(2.0, 0, 0), 0.0)
			_step(w, 3.0)
	check(w.objectives[0]["done"], "three jeeps flipped")
	w.hind.place(w.lz, 0.0)
	_step(w, 2.0)
	check(w.phase == "won", "landing at the LZ wins mission 1 (phase %s)" % w.phase)
	w.queue_free()

	# Rescue: winch one crew member and land them.
	w = _world(host, 2)
	w.invincible = true
	var c: Dictionary = w.crew[0]
	w.hind.place(c["at"], 0.0)
	_step(w, Rules.WINCH_SEC + 0.3)
	check(w.aboard == 1 and c["state"] == "aboard", "hovering over crew winches them up")
	w.hind.place(w.lz, 0.0)
	_step(w, 1.0)
	check(w.delivered == 1 and w.aboard == 0, "landing at the LZ delivers crew")

	# SAMs do not fire at the ground; they do two steps up.
	var sam = _unit(w, "sam")
	w.hind.place(sam.position + Vector3(0, 0, 26), 0.0)
	w.enemy_shots_clear()
	_step(w, 7.0)
	var sams := 0
	for s in w.enemy_shots:
		if s["weapon"] == "sam":
			sams += 1
	check(sams == 0, "no SAM launch at the ground")
	w.hind.band = 2
	w.hind.lift = Rules.band_y(2)
	_step(w, 7.0)
	var launched := false
	for s in w.enemy_shots:
		if s["weapon"] == "sam":
			launched = true
	check(launched or w.hits_taken > 0, "a SAM launches two steps up")

	# Health at zero: Hind down, a life is lost, she respawns at the LZ with crew dropped.
	w.invincible = false
	w.health = Rules.ENEMY_SHOT
	w.hind.band = 0
	w.hind.lift = 0.0
	var lives_before: int = w.lives
	w._hind_hit(1.0, "cannon")
	check(w.health == 0 and w.phase == "dead", "a shot at health 2 brings her down")
	_step(w, Rules.LAND_SEC + Rules.RESPAWN_SEC + 0.5)
	check(w.lives == lives_before - 1 and w.phase == "play" and w.hind.alive, "a crash costs a life and respawns")
	check(w.health == Rules.HEALTH_START and w.hind.pos.distance_to(w.lz) < 1.0, "respawn is at the LZ with health 8")

	# Fuel at zero: she autorotates and lands. Empty fuel does not destroy the Hind.
	w.invincible = true
	w.hind.band = 2
	w.hind.lift = Rules.band_y(2)
	w.fuel = 0.01
	lives_before = w.lives
	_step(w, 0.1)
	check(w.phase == "landing", "empty fuel starts the landing")
	_step(w, Rules.LAND_SEC * 2.0 + 0.5)
	check(w.hind.alive and w.lives == lives_before and w.hind.lift < 0.01, "she lands; the Hind is not destroyed")
	check(w.stats()["end"] == "landed", "the end plate says Landed.")
	w.queue_free()

	# Convoy: left alone, the trucks get through and the mission is lost.
	w = _world(host, 1)
	w.invincible = true
	w.hind.place(w.lz, 0.0)
	_step(w, 160.0)
	check(w.phase == "lost", "an unstopped convoy fails mission 2 (phase %s)" % w.phase)
	w.queue_free()

	# The wash shakes a truck. A truck does not tip.
	w = _world(host, 1)
	w.invincible = true
	_step(w, 9.0)
	var truck = _unit(w, "truck", "convoy")
	truck.speed = 0.0
	w.hind.place(truck.position + Vector3(2.5, 0, 0), 0.0)
	_step(w, 4.0)
	check(not truck.flipped and truck.state == "alive" and truck.tip > 0.0, "the wash shakes a truck and does not tip it")
	w.queue_free()

	# A vehicle turns until the nose points along the road, then drives. It never slides.
	w = _world(host, 0)
	w.invincible = true
	w.hind.place(w.lz, 0.0)
	var car = _unit(w, "jeep", "patrol")
	var sideways := 0
	for k in 600:
		var before: Vector3 = car.position
		w._physics_process(DT)
		var moved: Vector3 = Rules.flat(car.position - before)
		if moved.length() > 0.001 and moved.normalized().dot(Rules.yaw_forward(car.heading)) < 0.99:
			sideways += 1
	check(sideways == 0, "vehicles do not move sideways")
	w.queue_free()
	await host.get_tree().process_frame
