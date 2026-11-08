extends RefCounted

const Rules = preload("res://world/rules.gd")


static func buildings() -> Array:
	return [
		{"x": -16.0, "z": -16.0, "sx": 8.0, "sz": 6.0, "h": 4.2, "door": 0.0},
		{"x": 14.0, "z": -18.0, "sx": 7.0, "sz": 8.0, "h": 5.0, "door": 0.0},
		{"x": -2.0, "z": 12.0, "sx": 6.0, "sz": 6.0, "h": 3.6, "door": 0.0},
	]


static func trees() -> Array:
	return [
		{"x": -10.0, "z": -22.0},
		{"x": 20.0, "z": -8.0},
		{"x": -24.0, "z": 2.0},
		{"x": -14.0, "z": 20.0},
		{"x": -22.0, "z": 16.0},
		{"x": 22.0, "z": 14.0},
		{"x": -6.0, "z": 2.0},
		{"x": 16.0, "z": 6.0},
	]


static func bushes() -> Array:
	return [
		{"x": 4.0, "z": 14.0},
		{"x": -14.0, "z": 8.0},
		{"x": 10.0, "z": -4.0},
		{"x": -18.0, "z": -6.0},
		{"x": 24.0, "z": -16.0},
		{"x": 0.0, "z": -16.0},
		{"x": -8.0, "z": 16.0},
		{"x": 18.0, "z": 18.0},
	]


static func flags() -> Array:
	return [
		{"x": -12.0, "z": -12.5},
		{"x": 14.0, "z": -13.0},
		{"x": -2.0, "z": 8.2},
		{"x": 8.0, "z": 20.0},
	]


static func vehicles() -> Array:
	return [
		{"kind": "jeep", "x": 4.0, "z": 10.0, "patrol": false, "x2": 4.0, "z2": 10.0},
		{"kind": "jeep", "x": -12.0, "z": -2.0, "patrol": true, "x2": -12.0, "z2": 10.0},
		{"kind": "technical", "x": 10.0, "z": 2.0, "patrol": false, "x2": 10.0, "z2": 2.0},
		{"kind": "technical", "x": -6.0, "z": -12.0, "patrol": true, "x2": 8.0, "z2": -12.0},
		{"kind": "truck", "x": 18.0, "z": -2.0, "patrol": false, "x2": 18.0, "z2": -2.0},
	]


static func blockers() -> Array:
	var out: Array = []
	for tree in trees():
		var radius := 1.35
		out.append({
			"kind": "tree",
			"min_x": float(tree["x"]) - radius,
			"max_x": float(tree["x"]) + radius,
			"min_z": float(tree["z"]) - radius,
			"max_z": float(tree["z"]) + radius,
		})
	for building in buildings():
		out.append({
			"kind": "building",
			"min_x": float(building["x"]) - float(building["sx"]) * 0.5,
			"max_x": float(building["x"]) + float(building["sx"]) * 0.5,
			"min_z": float(building["z"]) - float(building["sz"]) * 0.5,
			"max_z": float(building["z"]) + float(building["sz"]) * 0.5,
		})
	return out


static func start() -> Vector3:
	return Vector3(0.0, 0.0, 22.0)
