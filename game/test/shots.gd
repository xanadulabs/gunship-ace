extends Node
## Scripted screenshot tour for eyeballing changes.
## Run: godot --path game -- --shots /some/dir

const Rules = preload("res://core/rules.gd")

var out_dir := ""
var n := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute(out_dir)
	_tour()


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout


func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	n += 1
	var path := "%s/%02d_%s.png" % [out_dir, n, label]
	img.save_png(path)
	var info := ""
	if Game.current != null and "world" in Game.current and Game.current.world != null:
		var w = Game.current.world
		info = " paused=%s phase=%s fuel=%.1f hind=%s focus=%s" % [get_tree().paused, w.phase, w.fuel, w.hind.pos, w.cam_focus]
	print("shot ", path, info)


func _world():
	return Game.current.world


func _tour() -> void:
	Settings.seen_help = false
	Game.title()
	await _wait(2.0)
	await _shot("title")
	Game.briefing(0)
	await _wait(0.6)
	await _shot("briefing")
	Game.play(0)
	await _wait(1.5)
	await _shot("m1_start")
	var w = _world()
	w.armor = 1.0e9
	w.autopilot = {"wish": Vector2(0, 1)}
	await _wait(2.5)
	await _shot("m1_flying")
	var jeep = null
	for u in w.units:
		if u.tag == "patrol" and u.is_active():
			jeep = u
			break
	jeep.speed = 0.0
	w.autopilot = {}
	w.hind.place(jeep.position + Vector3(3.0, 0, 1.0), 120.0)
	await _wait(0.5)
	await _shot("m1_wash")
	await _wait(1.6)
	await _shot("m1_flipped")
	var aa = null
	for u in w.units:
		if u.tag == "aa" and u.is_active():
			aa = u
			break
	w.hind.place(aa.position + Vector3(0, 0, 20), 0.0)
	w.hind.band = 2
	await _wait(1.6)
	w.autopilot = {"fire": "rocket"}
	await _wait(0.5)
	await _shot("m1_rockets_high")
	w.autopilot = {"fire": "gun"}
	w.hind.band = 1
	await _wait(1.2)
	await _shot("m1_gun_low")
	w.autopilot = {}
	Game.current._open("map")
	await _wait(0.3)
	await _shot("m1_map")
	Game.current._close()
	Game.current._open("pause")
	await _wait(0.3)
	await _shot("m1_pause")
	Game.current._close()
	Game.play(2)
	await _wait(1.0)
	w = _world()
	w.armor = 1.0e9
	var sam = null
	for u in w.units:
		if u.kind == "sam":
			sam = u
			break
	w.hind.place(sam.position + Vector3(10, 0, 26), 30.0)
	w.hind.band = 2
	await _wait(5.0)
	await _shot("m3_sam")
	var crew: Dictionary = w.crew[0]
	w.hind.place(crew["at"] + Vector3(0.5, 0, 0.5), -60.0)
	await _wait(0.7)
	await _shot("m3_winch")
	Game.play(3)
	await _wait(1.0)
	w = _world()
	w.armor = 1.0e9
	w.hind.place(Vector3(0, 0, -95), 180.0)
	w.hind.band = 1
	await _wait(2.5)
	await _shot("m4_compound")
	w.armor = 30.0
	await _wait(1.0)
	await _shot("m4_damaged")
	Game.play(1)
	await _wait(14.0)
	w = _world()
	w.armor = 1.0e9
	var truck = null
	for u in w.units:
		if u.kind == "truck" and u.is_active():
			truck = u
			break
	if truck != null:
		w.hind.place(truck.position + Vector3(12, 0, 12), 135.0)
		w.hind.band = 1
	await _wait(1.0)
	await _shot("m2_convoy")
	Game.result({"mission": 0, "name": "Dust Off", "won": true, "reason": "", "time": 312.0, "kills": 14, "flips": 4, "crew": 0, "lives": 2, "score": 6420})
	await _wait(0.5)
	await _shot("result")
	Game.title()
	await _wait(0.5)
	Game.current._options()
	await _wait(0.5)
	await _shot("options")
	get_tree().quit(0)
