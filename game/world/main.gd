extends Node

const ProbeSc = preload("res://world/probe.gd")
const WorldSc = preload("res://world/world.gd")


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.has("--probe"):
		_probe()
		return
	var world = WorldSc.new()
	world.capture = args.has("--frame")
	add_child(world)
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_title("Gunship Ace")
	if args.has("--boot"):
		_boot()


func _probe() -> void:
	var code: int = await ProbeSc.run(self)
	get_tree().quit(code)


func _boot() -> void:
	await get_tree().create_timer(1.2).timeout
	print("boot ok")
	get_tree().quit(0)
