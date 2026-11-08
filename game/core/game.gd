extends Node
## Screen flow: title -> briefing -> mission -> result.

const Missions = preload("res://core/missions.gd")

var main: Node
var current: Node
var mission_index := 0


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11:
		Settings.toggle_fullscreen()


func _swap(node: Node) -> void:
	get_tree().paused = false
	if current != null and is_instance_valid(current):
		current.queue_free()
	current = node
	main.add_child(node)


func title() -> void:
	Sfx.rotor(false)
	Sfx.music("music_title")
	_swap(load("res://ui/title.gd").new())


func briefing(index: int) -> void:
	mission_index = index
	Sfx.rotor(false)
	Sfx.music("music_title")
	var b = load("res://ui/briefing.gd").new()
	b.index = index
	_swap(b)


func play(index: int) -> void:
	mission_index = index
	Sfx.music("music_mission")
	var m = load("res://ui/mission.gd").new()
	m.index = index
	_swap(m)


func result(stats: Dictionary) -> void:
	Sfx.rotor(false)
	if bool(stats["won"]):
		Settings.record_win(int(stats["mission"]), int(stats["score"]), Missions.count())
	var r = load("res://ui/result.gd").new()
	r.stats = stats
	_swap(r)


func quit() -> void:
	Settings.save_settings()
	get_tree().quit()
