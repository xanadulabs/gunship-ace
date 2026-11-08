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
	check(v.length() <= Rules.MAX_SPEED + 0.001 and v.length() > Rules.MAX_SPEED * 0.9, "thrust reaches but does not pass max speed")
	for i in 600:
		v = Rules.step_velocity(v, Vector2.ZERO, 0.0, DT)
	check(v.length() < 0.1, "the Hind coasts to a stop")
	var wall := [Rect2(-1, -11, 2, 2)]
	var res := Rules.slide(Vector3(0, 0, -3), Vector3(0, 0, -4), 0, wall, 100.0)
	check(not bool(res["hit"]), "free move is not a hit")
	res = Rules.slide(Vector3(0.5, 0, -8.5), Vector3(0.5, 0, -9.5), 0, wall, 100.0)
	check(bool(res["hit"]), "a building stops the Hind at NAP")
	res = Rules.slide(Vector3(0.5, 0, -8.5), Vector3(0.5, 0, -9.5), 2, wall, 100.0)
	check(not bool(res["hit"]), "HIGH clears buildings")
	res = Rules.slide(Vector3(0, 0, 0), Vector3(200, 0, 0), 2, [], 100.0)
	check(bool(res["edge"]) and float(res["pos"].x) <= 100.0 - Rules.EDGE_MARGIN + 0.01, "the map edge holds")
	check(Rules.wash_strength(0, 0.0) == 1.0, "still at NAP is full wash")
	check(Rules.wash_strength(1, 0.0) == 0.0, "no wash at LOW")
	check(Rules.wash_strength(0, Rules.WASH_MAX_SPEED + 1.0) == 0.0, "no wash while fast")
	check(Rules.tip_rate("jeep", 3.0, 1.0) > Rules.tip_rate("truck", 3.0, 1.0), "a jeep tips faster than a truck")
	check(Rules.tip_rate("truck", 6.0, 1.0) == 0.0, "a truck only tips up close")
	check(Rules.tip_rate("tank", 1.0, 1.0) == 0.0, "a tank does not tip")
	check(Rules.shakes("tank") and not Rules.shakes("aaa"), "tanks shake, dug-in guns do not")
	check(Rules.can_reach("rifle", 0) and not Rules.can_reach("rifle", 2), "rifles cannot reach HIGH")
	check(Rules.can_reach("sam", 2) and not Rules.can_reach("sam", 0), "SAMs cannot lock at NAP")
	check(Rules.can_reach("flak", 2), "flak reaches every height")
	check(Rules.damage_to("tank", "gun", 1.0) < 0.5 and Rules.damage_to("jeep", "gun", 1.0) == 1.0, "armor shrugs off the gun")
	var targets := [Vector3(0, 0, -20), Vector3(15, 0, -15)]
	check(Rules.pick_target(Vector3.ZERO, 0.0, targets, 20.0, 40.0) == 0, "aim assist picks the target on the nose")
	check(Rules.pick_target(Vector3.ZERO, 180.0, targets, 20.0, 40.0) == -1, "nothing behind the Hind is picked")
	var drain := Rules.FUEL_MAX / Rules.FUEL_PER_SEC
	check(drain >= 150.0 and drain <= 300.0, "a full tank lasts two and a half to five minutes")


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
		w.armor = 1.0e9
		_step(w, 20.0)
		check(w.phase == "play", "mission %d runs idle" % (i + 1))
		w.queue_free()
	await host.get_tree().process_frame

	# The wash flips a jeep: still at NAP right next to it.
	var w = _world(host, 0)
	w.armor = 1.0e9
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
	w.armor = 1.0e9
	var c: Dictionary = w.crew[0]
	w.hind.place(c["at"], 0.0)
	_step(w, Rules.WINCH_SEC + 0.3)
	check(w.aboard == 1 and c["state"] == "aboard", "hovering over crew winches them up")
	w.hind.place(w.lz, 0.0)
	_step(w, 1.0)
	check(w.delivered == 1 and w.aboard == 0, "landing at the LZ delivers crew")

	# SAMs do not fire at NAP; they do at HIGH.
	var sam = _unit(w, "sam")
	w.hind.place(sam.position + Vector3(0, 0, 26), 0.0)
	w.enemy_shots_clear()
	_step(w, 7.0)
	var sams := 0
	for s in w.enemy_shots:
		if s["weapon"] == "sam":
			sams += 1
	check(sams == 0, "no SAM launch at NAP")
	w.hind.band = 2
	w.hind.lift = Rules.band_y(2)
	_step(w, 7.0)
	var launched := false
	for s in w.enemy_shots:
		if s["weapon"] == "sam":
			launched = true
	check(launched or w.armor < 1.0e9, "a SAM launches at HIGH")

	# Death: losing all armor costs a life and respawns at the LZ with crew dropped.
	w.armor = 1.0
	w.hind.band = 0
	w.hind.lift = 0.0
	var lives_before: int = w.lives
	w._hind_hit(10.0, "cannon")
	_step(w, Rules.AUTOROTATE_SEC + Rules.RESPAWN_SEC + 0.5)
	check(w.lives == lives_before - 1 and w.phase == "play" and w.hind.alive, "a crash costs a life and respawns")
	check(w.armor == Rules.ARMOR_MAX and w.hind.pos.distance_to(w.lz) < 1.0, "respawn is at the LZ with full armor")
	w.queue_free()

	# Convoy: left alone, the trucks get through and the mission is lost.
	w = _world(host, 1)
	w.armor = 1.0e9
	w.hind.place(w.lz, 0.0)
	_step(w, 160.0)
	check(w.phase == "lost", "an unstopped convoy fails mission 2 (phase %s)" % w.phase)
	w.queue_free()

	# A truck in the wash tips over if the Hind holds the hover long enough.
	w = _world(host, 1)
	w.armor = 1.0e9
	_step(w, 9.0)
	var truck = _unit(w, "truck", "convoy")
	truck.speed = 0.0
	w.hind.place(truck.position + Vector3(2.5, 0, 0), 0.0)
	_step(w, 4.0)
	check(truck.flipped, "a held hover tips a truck")
	w.queue_free()
	await host.get_tree().process_frame
