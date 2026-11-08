extends RefCounted
## Prints how fast the Hind loses armor in typical spots. Not pass/fail; a tuning aid.
## Run: godot --headless --path game -- --balance

const Rules = preload("res://core/rules.gd")
const WorldSc = preload("res://world/world.gd")
const DT := 1.0 / 60.0


static func _hover(host: Node, mission: int, at: Vector3, band: int, seconds: float) -> String:
	var w = WorldSc.new()
	w.setup(mission)
	host.add_child(w)
	w.hind.place(at, 0.0)
	w.hind.band = band
	w.hind.lift = Rules.band_y(band)
	var start: float = w.armor
	var t := 0.0
	while t < seconds and w.phase == "play":
		w._physics_process(DT)
		t += DT
	var lost: float = start - w.armor
	w.queue_free()
	return "%-36s lost %5.1f armor in %4.1fs (%s)" % ["m%d (%d,%d) %s" % [mission + 1, at.x, at.z, Rules.BAND_NAMES[band]], lost, t, "survived" if t >= seconds - DT else "DOWN"]


static func run(host: Node) -> int:
	print(_hover(host, 0, Vector3(0, 0, 92), 0, 30.0))
	print(_hover(host, 0, Vector3(-8, 0, 0), 0, 20.0))
	print(_hover(host, 0, Vector3(-8, 0, 0), 1, 20.0))
	print(_hover(host, 0, Vector3(-8, 0, 0), 2, 20.0))
	print(_hover(host, 0, Vector3(62, 0, -48), 1, 20.0))
	print(_hover(host, 1, Vector3(-20, 0, 112), 0, 30.0))
	print(_hover(host, 1, Vector3(95, 0, 70), 1, 20.0))
	print(_hover(host, 1, Vector3(95, 0, 70), 0, 20.0))
	print(_hover(host, 2, Vector3(-110, 0, 110), 0, 30.0))
	print(_hover(host, 2, Vector3(70, 0, -60), 2, 20.0))
	print(_hover(host, 2, Vector3(70, 0, -60), 0, 20.0))
	print(_hover(host, 3, Vector3(0, 0, 132), 0, 30.0))
	print(_hover(host, 3, Vector3(0, 0, -95), 1, 20.0))
	print(_hover(host, 3, Vector3(0, 0, -95), 2, 20.0))
	return 0
