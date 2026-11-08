extends RefCounted

const Rules = preload("res://world/rules.gd")
const MapData = preload("res://world/map.gd")
const VehicleSc = preload("res://world/vehicle.gd")


static func run(host: Node) -> int:
	if not _logic():
		return 1
	if not await _bodies(host):
		return 1
	print("probe ok")
	return 0


static func _logic() -> bool:
	var forward := Rules.yaw_forward(0.0)
	print("forward %.2f %.2f %.2f" % [forward.x, forward.y, forward.z])
	if absf(forward.x) > 0.01 or absf(forward.z + 1.0) > 0.01:
		return _fail("yaw 0 forward")
	var left := Rules.yaw_forward(45.0)
	print("left %.2f %.2f" % [left.x, left.z])
	if left.x >= 0.0 or left.z >= 0.0:
		return _fail("left turn")
	var right := Rules.yaw_right(0.0)
	print("right %.2f %.2f" % [right.x, right.z])
	if absf(right.x - 1.0) > 0.01:
		return _fail("right vector")
	var east := Rules.yaw_to(Vector3(1.0, 0.0, 0.0))
	var east_fwd := Rules.yaw_forward(rad_to_deg(east))
	print("east yaw %.1f fwd %.2f %.2f" % [rad_to_deg(east), east_fwd.x, east_fwd.z])
	if east_fwd.dot(Vector3.RIGHT) < 0.99:
		return _fail("yaw to east")
	var north := Rules.yaw_forward(rad_to_deg(Rules.yaw_to(Vector3(0.0, 0.0, -1.0))))
	if north.dot(Vector3(0.0, 0.0, -1.0)) < 0.99:
		return _fail("yaw to north")
	if Rules.wash_mode(0, false) != "attack":
		return _fail("attack wash")
	if Rules.wash_mode(0, true) != "off":
		return _fail("move wash")
	if Rules.wash_mode(1, false) != "wind":
		return _fail("wind")
	if Rules.wash_mode(2, false) != "off":
		return _fail("high wash")
	if Rules.wash_verb("truck") != "shake" or Rules.wash_verb("jeep") != "flip":
		return _fail("wash verb")
	if Rules.fuel_per_sec("attack") <= Rules.fuel_per_sec("off"):
		return _fail("fuel rate")
	if Rules.fuel_line(100.0) != "Fuel 100" or Rules.fuel_line(0.0) != "Fuel 0":
		return _fail("fuel line")
	if Rules.fuel_line(0.2) != "Fuel 1":
		return _fail("fuel ceil")
	if Rules.health_line(8) != "Health 8":
		return _fail("health line")
	if Rules.vehicles_line(5) != "Vehicles left 5":
		return _fail("vehicles line")
	if Rules.height_line(0) != "Height is ground.":
		return _fail("height ground")
	if Rules.height_line(1) != "Height is one step up.":
		return _fail("height step")
	if Rules.wash_line("attack") != "Wash is on." or Rules.wash_line("wind") != "Wind is on.":
		return _fail("wash line")
	if Rules.end_line("landed") != "Landed.":
		return _fail("landed")
	if Rules.end_line("down") != "Hind down.":
		return _fail("down")
	if Rules.end_line("clear") != "The area is clear.":
		return _fail("clear")
	if Rules.end_line("landing") != "The Hind is landing.":
		return _fail("landing line")
	if Rules.stop_line("tree") != "A tree stops the Hind.":
		return _fail("tree line")
	if Rules.stop_line("ground") != "The ground stops the Hind.":
		return _fail("ground line")
	if Rules.LINES.size() != 9 or Rules.LINES[8] != "Left click fires.":
		return _fail("control lines")
	if Rules.tipped("truck", 0.1) or not Rules.tipped("jeep", 0.2):
		return _fail("tip rule")
	if Rules.vehicle_hp("jeep") != 4 or Rules.vehicle_hp("technical") != 6 or Rules.vehicle_hp("truck") != 10:
		return _fail("vehicle hp")
	var blockers := MapData.blockers()
	var start := MapData.start()
	if Rules.block_reason(start, start, blockers) != "":
		return _fail("start blocked")
	var step := Rules.destination(start, 0.0, "W")
	print("step %.1f %.1f" % [step.x, step.z])
	if absf(step.z - (start.z - Rules.STEP_M)) > 0.01:
		return _fail("W step")
	if Rules.block_reason(start, step, blockers) != "":
		return _fail("first step blocked")
	var building: Dictionary = blockers[MapData.trees().size()]
	var inside := Vector3((float(building["min_x"]) + float(building["max_x"])) * 0.5, 0, (float(building["min_z"]) + float(building["max_z"])) * 0.5)
	if Rules.block_reason(inside, inside, blockers) != "building":
		return _fail("building block")
	if Rules.block_reason(inside, inside, blockers, Rules.CLEAR_Y) == "building":
		return _fail("roof block")
	var tree: Dictionary = blockers[0]
	var tree_at := Vector3((float(tree["min_x"]) + float(tree["max_x"])) * 0.5, 0.0, (float(tree["min_z"]) + float(tree["max_z"])) * 0.5)
	if Rules.block_reason(tree_at, tree_at, blockers) != "tree":
		return _fail("tree block")
	if Rules.block_reason(tree_at, tree_at, blockers, Rules.CLEAR_Y) == "tree":
		return _fail("tree roof")
	if Rules.gun_wait(0.0) >= Rules.gun_wait(50.0):
		return _fail("gun wait")
	if Rules.camera_size(0.0) >= Rules.camera_size(1.0) or Rules.camera_size(1.0) >= Rules.camera_size(2.0):
		return _fail("zoom")
	if Rules.gun_turning_line() != "The gun is turning.":
		return _fail("gun line")
	if not Rules.segment_hits_rect(0, 0, 10, 0, 4, -1, 6, 1):
		return _fail("segment hit")
	if Rules.segment_hits_rect(0, 0, 10, 0, 4, 2, 6, 4):
		return _fail("segment miss")
	var targets: Array = [{"x": start.x, "z": start.z - 4.0, "half": 1.3}]
	var hit: Dictionary = Rules.gun_pick(start, 0.0, targets, blockers)
	if int(hit["index"]) != 0:
		return _fail("gun hit %s" % str(hit))
	var behind: Array = [{"x": 0.0, "z": 8.0, "half": 1.3}]
	var stopped: Dictionary = Rules.gun_pick(start, 0.0, behind, blockers)
	if str(stopped["notice"]) != "A building stops the shot.":
		return _fail("gun block %s" % str(stopped))
	var wide: Array = [{"x": start.x + 12.0, "z": start.z - 6.0, "half": 1.3}]
	var miss := Rules.gun_pick(start, 0.0, wide, blockers)
	if str(miss["notice"]) != "The shot misses.":
		return _fail("gun miss")
	var key := InputEventKey.new()
	key.pressed = true
	key.keycode = KEY_W
	if Rules.action_key(key) != "W":
		return _fail("W key")
	key.keycode = KEY_UP
	if Rules.action_key(key) != "":
		return _fail("arrow key")
	key.keycode = KEY_W
	key.ctrl_pressed = true
	if Rules.action_key(key) != "":
		return _fail("ctrl W")
	key.ctrl_pressed = false
	key.pressed = false
	if Rules.flight_key(key) != "W" or Rules.action_key(key) != "":
		return _fail("W up")
	key.pressed = true
	key.echo = true
	if Rules.flight_key(key) != "" or Rules.action_key(key) != "":
		return _fail("W echo")
	key.echo = false
	var dt := 1.0 / 60.0
	var vel := Vector3.ZERO
	var nose := Vector3(0.0, 0.0, -1.0)
	for _i in 150:
		vel = Rules.coast(vel, dt)
		vel = Rules.hold_thrust(vel, nose, dt)
	print("hold %.2f" % vel.length())
	if vel.dot(nose) < Rules.MAX_SPEED - 0.05:
		return _fail("hold speed")
	var diag := Vector3(1.0, 0.0, -1.0)
	vel = Vector3.ZERO
	for _i in 150:
		vel = Rules.coast(vel, dt)
		vel = Rules.hold_thrust(vel, diag, dt)
	if vel.normalized().dot(diag.normalized()) < 0.99 or vel.length() < Rules.MAX_SPEED - 0.05:
		return _fail("hold diag")
	var cancel := Rules.hold_thrust(Vector3.ZERO, Vector3.ZERO, 1.0)
	if cancel.length() > 0.001:
		return _fail("hold still")
	var tap := nose * Rules.SHOVE
	for _i in 12:
		tap = Rules.coast(tap, dt)
	if tap.dot(nose) < 1.0:
		return _fail("tap coast")
	for _i in 120:
		vel = Rules.coast(vel, dt)
	if vel.length() > Rules.STILL_SPEED:
		return _fail("coast stop")
	var yaw := 0.0
	for _i in 60:
		yaw = Rules.hold_yaw(yaw, true, false, dt)
	if absf(yaw - Rules.YAW_RATE) > 0.05:
		return _fail("yaw hold")
	if absf(Rules.hold_yaw(10.0, true, true, 0.5) - 10.0) > 0.001:
		return _fail("yaw cancel")
	var mouse := InputEventMouseButton.new()
	mouse.pressed = true
	mouse.button_index = MOUSE_BUTTON_LEFT
	if not Rules.is_fire(mouse):
		return _fail("click")
	mouse.ctrl_pressed = true
	if Rules.is_fire(mouse):
		return _fail("ctrl click")
	if MapData.vehicles().size() != 5 or MapData.buildings().size() != 3:
		return _fail("map counts")
	print("logic ok")
	return true


static func _bodies(host: Node) -> bool:
	var ground := StaticBody3D.new()
	ground.collision_layer = 1
	ground.collision_mask = 0
	var surface := PhysicsMaterial.new()
	surface.friction = 0.7
	surface.bounce = 0.0
	ground.physics_material_override = surface
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(80, 2, 80)
	shape.shape = box
	shape.position = Vector3(0, -1, 0)
	ground.add_child(shape)
	host.add_child(ground)
	var jeep := VehicleSc.new()
	jeep.setup({"kind": "jeep", "x": 0.0, "z": -3.0, "patrol": false, "x2": 0.0, "z2": -3.0})
	jeep.collision_layer = 2
	jeep.collision_mask = 1
	host.add_child(jeep)
	var truck := VehicleSc.new()
	truck.setup({"kind": "truck", "x": 5.0, "z": 0.0, "patrol": false, "x2": 5.0, "z2": 0.0})
	truck.collision_layer = 2
	truck.collision_mask = 1
	host.add_child(truck)
	var slider := VehicleSc.new()
	slider.setup({"kind": "truck", "x": 0.0, "z": 6.0, "patrol": false, "x2": 0.0, "z2": 6.0})
	slider.rotation.y = PI
	slider.collision_layer = 2
	slider.collision_mask = 1
	host.add_child(slider)
	var runner := VehicleSc.new()
	runner.setup({"kind": "truck", "x": -20.0, "z": 20.0, "patrol": true, "x2": -12.0, "z2": 20.0})
	runner.collision_layer = 2
	runner.collision_mask = 1
	host.add_child(runner)
	for _i in 25:
		await host.get_tree().physics_frame
	var crab_from := truck.global_position
	truck.linear_velocity = Vector3(4.0, 0.0, 0.0)
	for _i in 15:
		await host.get_tree().physics_frame
	var crabbed := truck.global_position - crab_from
	print("truck crab %.2f %.2f" % [crabbed.x, crabbed.z])
	if Vector2(crabbed.x, crabbed.z).length() > 0.2:
		return _fail("truck slid sideways")
	var jeep_up := 1.0
	var truck_up := 1.0
	var nose_from := slider.global_position
	var run_from := runner.global_position
	var truck_shake := 0.0
	var nose_shake := 0.0
	for _i in 50:
		jeep.wash(Vector3.ZERO)
		truck.wash(Vector3.ZERO)
		slider.wash(Vector3.ZERO)
		runner.cruise()
		await host.get_tree().physics_frame
		jeep_up = minf(jeep_up, jeep.global_transform.basis.y.dot(Vector3.UP))
		truck_up = minf(truck_up, truck.global_transform.basis.y.dot(Vector3.UP))
		truck_shake = maxf(truck_shake, truck.shake)
		nose_shake = maxf(nose_shake, slider.shake)
	var nose_move := slider.global_position - nose_from
	var nose_yaw := rad_to_deg(slider.rotation.y)
	var along := Vector3(nose_move.x, 0.0, nose_move.z).dot(Rules.yaw_forward(nose_yaw))
	var lateral := Vector3(nose_move.x, 0.0, nose_move.z).dot(Rules.yaw_right(nose_yaw))
	var run := runner.global_position - run_from
	var run_yaw := rad_to_deg(runner.rotation.y)
	var run_along := Vector3(run.x, 0.0, run.z).dot(Rules.yaw_forward(run_yaw))
	var run_side := Vector3(run.x, 0.0, run.z).dot(Rules.yaw_right(run_yaw))
	var stayed := truck.global_position - crab_from
	print("jeep up %.2f truck up %.2f shake %.1f %.1f along %.2f side %.2f run along %.2f side %.2f stay %.2f" % [jeep_up, truck_up, truck_shake, nose_shake, along, lateral, run_along, run_side, Vector2(stayed.x, stayed.z).length()])
	if jeep_up > Rules.TIP_DOT:
		return _fail("jeep did not tip")
	if truck_up < 0.9:
		return _fail("truck tipped")
	if truck_shake < 1.0 or nose_shake < 1.0:
		return _fail("truck did not shake")
	if absf(along) > 0.2 or absf(lateral) > 0.2:
		return _fail("wash moved the truck")
	if Vector2(stayed.x, stayed.z).length() > 0.25:
		return _fail("broadside truck moved")
	if runner.shake > 0.0:
		return _fail("runner shook")
	truck.wash(Vector3(40.0, 0.0, 40.0))
	if truck.shake > 0.0:
		return _fail("shake stuck")
	if run_along < 0.5:
		return _fail("truck did not drive")
	if absf(run_side) > 0.15:
		return _fail("truck drove sideways")
	# A technical aimed backward turns in place. It does not creep sideways.
	var tech := VehicleSc.new()
	tech.setup({"kind": "technical", "x": -6.0, "z": -12.0, "patrol": true, "x2": 8.0, "z2": -12.0})
	tech.heading = PI * 0.5
	tech.rotation.y = tech.heading
	tech.collision_layer = 2
	tech.collision_mask = 1
	host.add_child(tech)
	for _i in 8:
		await host.get_tree().physics_frame
	var turn_from := tech.global_position
	var creep := 0.0
	for _i in 45:
		tech.cruise(1.0 / 60.0)
		await host.get_tree().physics_frame
		var moved := Vector2(tech.global_position.x - turn_from.x, tech.global_position.z - turn_from.z)
		creep = maxf(creep, moved.length())
	print("turn creep %.2f heading %.0f" % [creep, rad_to_deg(tech.heading)])
	if creep > 0.35:
		return _fail("technical slid while turning")
	for _i in 80:
		tech.cruise(1.0 / 60.0)
		await host.get_tree().physics_frame
	var drove := tech.global_position - turn_from
	var nose := Rules.yaw_forward(rad_to_deg(tech.rotation.y))
	var tech_along := Vector3(drove.x, 0.0, drove.z).dot(nose)
	var tech_side := Vector3(drove.x, 0.0, drove.z).dot(Rules.yaw_right(rad_to_deg(tech.rotation.y)))
	print("tech along %.2f side %.2f yaw %.0f" % [tech_along, tech_side, rad_to_deg(tech.rotation.y)])
	if tech_along < 1.0:
		return _fail("technical did not drive forward")
	if absf(tech_side) > 0.35:
		return _fail("technical drove sideways")
	if nose.dot(Vector3.RIGHT) < 0.9:
		return _fail("technical nose is not east")
	return true


static func _fail(reason: String) -> bool:
	print("probe fail: %s" % reason)
	return false
