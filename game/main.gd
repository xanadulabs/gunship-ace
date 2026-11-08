extends Node
## Entry point. Plain launch goes to the title screen.
## Dev flags after "--":  --probe (headless rule and simulation check)
##                        --shots <dir> (scripted screenshot tour)

func _ready() -> void:
	Game.main = self
	var args := OS.get_cmdline_user_args()
	if args.has("--probe"):
		var code: int = await load("res://test/probe.gd").run(self)
		get_tree().quit(code)
		return
	var i := args.find("--shots")
	if i >= 0 and i + 1 < args.size():
		var tour = load("res://test/shots.gd").new()
		tour.out_dir = args[i + 1]
		add_child(tour)
		return
	Game.title()
