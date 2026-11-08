extends Node
## Entry point. Plain launch goes to the title screen.
## Dev flags after "--":  --probe (headless rule and simulation check)
##                        --balance (armor loss in typical spots)
##                        --licenses <file> (write Godot notices for a build)
##                        --shots <dir> (scripted screenshot tour)

func _ready() -> void:
	Game.main = self
	var args := OS.get_cmdline_user_args()
	if args.has("--probe"):
		var code: int = await load("res://test/probe.gd").run(self)
		get_tree().quit(code)
		return
	var lic := args.find("--licenses")
	if lic >= 0 and lic + 1 < args.size():
		_write_licenses(args[lic + 1])
		get_tree().quit(0)
		return
	if args.has("--balance"):
		var bcode: int = load("res://test/balance.gd").run(self)
		get_tree().quit(bcode)
		return
	var i := args.find("--shots")
	if i >= 0 and i + 1 < args.size():
		var tour = load("res://test/shots.gd").new()
		tour.out_dir = args[i + 1]
		add_child(tour)
		return
	Game.title()


func _write_licenses(path: String) -> void:
	## Third-party notices that must ship with every build.
	var out := "GUNSHIP ACE - third-party notices\n\n"
	out += "=== Godot Engine ===\n" + Engine.get_license_text() + "\n"
	for part in Engine.get_copyright_info():
		out += "\n--- %s ---\n" % part["name"]
		for p in part["parts"]:
			out += "Copyright: %s\nLicense: %s\n" % [", ".join(p["copyright"]), p["license"]]
	out += "\n=== Third-party licenses used by Godot ===\n"
	var lic: Dictionary = Engine.get_license_info()
	for key in lic.keys():
		out += "\n--- %s ---\n%s\n" % [key, lic[key]]
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(out)
	f.close()
