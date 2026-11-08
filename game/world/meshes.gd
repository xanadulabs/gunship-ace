extends RefCounted

const ADOBE := Color(0.78, 0.66, 0.48)
const ROOF := Color(0.45, 0.32, 0.24)
const DOOR := Color(0.28, 0.18, 0.13)
const WINDOW := Color(0.16, 0.2, 0.22)
const OLIVE := Color(0.36, 0.4, 0.22)
const SAND := Color(0.71, 0.62, 0.4)
const GLASS := Color(0.5, 0.72, 0.76)
const DARK := Color(0.14, 0.14, 0.12)
const METAL := Color(0.28, 0.3, 0.26)
const TRUNK := Color(0.36, 0.24, 0.16)
const LEAF := Color(0.3, 0.4, 0.18)
const LEAF_DARK := Color(0.2, 0.28, 0.12)
const JEEP := Color(0.4, 0.44, 0.24)
const TECHNICAL := Color(0.55, 0.4, 0.24)
const TRUCK := Color(0.32, 0.36, 0.34)
const FLAG := Color(0.62, 0.2, 0.14)
const DUST := Color(0.78, 0.68, 0.46, 0.55)
const BOOM := Color(0.86, 0.42, 0.12)
const BOOM_HOT := Color(0.96, 0.82, 0.4)

static var _mats: Dictionary = {}


static func mat(color: Color, transparent := false) -> StandardMaterial3D:
	var key := "%s-%s" % [color.to_html(), transparent]
	if _mats.has(key):
		return _mats[key]
	var made := StandardMaterial3D.new()
	made.albedo_color = color
	made.roughness = 1.0
	made.metallic = 0.0
	made.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	if transparent:
		made.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		made.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mats[key] = made
	return made


static func box(parent: Node3D, size: Vector3, at: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = at
	node.material_override = mat(color)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(node)
	return node


static func ball(parent: Node3D, radius: float, at: Vector3, color: Color) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = at
	node.material_override = mat(color)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(node)
	return node


static func tube(parent: Node3D, radius: float, height: float, at: Vector3, color: Color) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = at
	node.material_override = mat(color)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(node)
	return node


static func hind() -> Dictionary:
	var root := Node3D.new()
	root.name = "Hind"
	box(root, Vector3(1.45, 1.05, 3.5), Vector3(0, 0.1, -0.15), OLIVE)
	box(root, Vector3(1.15, 0.32, 2.7), Vector3(0, -0.42, 0.05), SAND)
	box(root, Vector3(0.82, 0.38, 1.05), Vector3(0, 0.48, -1.25), GLASS)
	box(root, Vector3(0.9, 0.42, 0.85), Vector3(0, 0.78, -0.2), GLASS)
	box(root, Vector3(0.55, 0.28, 0.7), Vector3(0, 0.15, -1.85), DARK)
	box(root, Vector3(2.15, 0.1, 0.72), Vector3(1.55, 0.02, 0.15), OLIVE)
	box(root, Vector3(2.15, 0.1, 0.72), Vector3(-1.55, 0.02, 0.15), OLIVE)
	box(root, Vector3(0.32, 0.32, 1.25), Vector3(2.45, -0.16, 0.12), DARK)
	box(root, Vector3(0.32, 0.32, 1.25), Vector3(-2.45, -0.16, 0.12), DARK)
	box(root, Vector3(0.42, 0.38, 3.1), Vector3(0, 0.28, 2.35), OLIVE)
	box(root, Vector3(0.08, 1.15, 0.7), Vector3(0, 0.95, 3.55), SAND)
	box(root, Vector3(1.7, 0.07, 0.32), Vector3(0, 0.42, 3.45), SAND)
	box(root, Vector3(0.1, 0.1, 0.7), Vector3(0.15, -0.2, -2.05), DARK)
	for side in [-1.0, 1.0]:
		box(root, Vector3(0.08, 0.08, 2.4), Vector3(side * 0.55, -0.82, 0.1), DARK)
		box(root, Vector3(0.06, 0.45, 0.06), Vector3(side * 0.55, -0.55, -0.7), DARK)
		box(root, Vector3(0.06, 0.45, 0.06), Vector3(side * 0.55, -0.55, 0.9), DARK)
	var mast := tube(root, 0.1, 0.55, Vector3(0, 1.05, -0.15), DARK)
	mast.position = Vector3(0, 0.95, -0.15)
	var rotor := Node3D.new()
	rotor.name = "Rotor"
	rotor.position = Vector3(0, 1.25, -0.15)
	root.add_child(rotor)
	for i in 5:
		var pivot := Node3D.new()
		pivot.rotation.y = deg_to_rad(float(i) * 72.0)
		rotor.add_child(pivot)
		box(pivot, Vector3(4.4, 0.04, 0.22), Vector3(2.2, 0, 0), DARK)
	var tail := Node3D.new()
	tail.name = "TailRotor"
	tail.position = Vector3(-0.22, 0.9, 3.55)
	root.add_child(tail)
	for i in 3:
		var blade := box(tail, Vector3(0.06, 0.7, 0.1), Vector3.ZERO, DARK)
		blade.rotation.x = deg_to_rad(i * 120.0)
	return {"root": root, "rotor": rotor, "tail": tail}


static func jeep() -> Node3D:
	var root := Node3D.new()
	box(root, Vector3(1.25, 0.4, 2.3), Vector3(0, 0.45, 0), JEEP)
	box(root, Vector3(1.15, 0.28, 0.7), Vector3(0, 0.72, -0.45), SAND)
	box(root, Vector3(1.05, 0.35, 0.08), Vector3(0, 0.85, -0.95), GLASS)
	box(root, Vector3(0.15, 0.45, 0.15), Vector3(0, 1.05, 0.35), DARK)
	_wheels(root, 0.95, 0.72, 0.32)
	return root


static func technical() -> Node3D:
	var root := Node3D.new()
	box(root, Vector3(1.35, 0.42, 3.15), Vector3(0, 0.5, 0.1), TECHNICAL)
	box(root, Vector3(1.25, 0.7, 1.05), Vector3(0, 0.95, -0.85), SAND)
	box(root, Vector3(1.1, 0.4, 0.08), Vector3(0, 1.05, -1.4), GLASS)
	box(root, Vector3(0.9, 0.35, 1.3), Vector3(0, 0.85, 0.85), OLIVE)
	tube(root, 0.08, 0.55, Vector3(0, 1.2, 0.7), DARK)
	box(root, Vector3(0.1, 0.1, 0.8), Vector3(0.15, 1.35, 0.35), DARK)
	_wheels(root, 1.15, 1.05, 0.34)
	return root


static func truck() -> Node3D:
	var root := Node3D.new()
	box(root, Vector3(1.7, 1.05, 1.7), Vector3(0, 0.95, -1.55), TRUCK)
	box(root, Vector3(1.15, 0.45, 0.08), Vector3(0, 1.15, -2.4), GLASS)
	box(root, Vector3(1.75, 1.15, 3.3), Vector3(0, 1.05, 0.7), SAND)
	for z in [-1.55, 0.35, 1.35]:
		for side in [-1.0, 1.0]:
			var wheel := tube(root, 0.42, 0.24, Vector3(side * 0.95, 0.42, z), DARK)
			wheel.rotation.z = PI * 0.5
	return root


static func _wheels(parent: Node3D, z: float, x: float, radius: float) -> void:
	for side in [-1.0, 1.0]:
		for end in [-1.0, 1.0]:
			var wheel := tube(parent, radius, 0.22, Vector3(side * x, radius, end * z), DARK)
			wheel.rotation.z = PI * 0.5


static func tree() -> Dictionary:
	var root := Node3D.new()
	tube(root, 0.16, 2.4, Vector3(0, 1.2, 0), TRUNK)
	var crown := Node3D.new()
	crown.name = "Crown"
	root.add_child(crown)
	ball(crown, 1.15, Vector3(0, 2.7, 0), LEAF)
	ball(crown, 0.75, Vector3(0.45, 2.35, 0.2), LEAF_DARK)
	ball(crown, 0.6, Vector3(-0.4, 2.5, -0.25), LEAF)
	return {"root": root, "crown": crown}


static func bush() -> Node3D:
	var root := Node3D.new()
	var node := ball(root, 0.55, Vector3(0, 0.32, 0), LEAF_DARK)
	node.scale = Vector3(1.3, 0.55, 1.3)
	return root


static func flag() -> Dictionary:
	var root := Node3D.new()
	tube(root, 0.05, 2.6, Vector3(0, 1.3, 0), DARK)
	var cloth := box(root, Vector3(0.9, 0.48, 0.04), Vector3(0.5, 2.25, 0), FLAG)
	return {"root": root, "cloth": cloth}


static func dust_ring() -> Node3D:
	var root := Node3D.new()
	root.name = "Dust"
	for i in 8:
		var puff := ball(root, 0.55, Vector3.ZERO, DUST)
		puff.material_override = mat(DUST, true)
		var ang := float(i) / 8.0 * TAU
		puff.position = Vector3(sin(ang) * 3.2, 0.4, cos(ang) * 3.2)
		puff.scale = Vector3(1.6, 0.45, 1.6)
	return root


static func boom() -> Node3D:
	var root := Node3D.new()
	ball(root, 0.8, Vector3.ZERO, BOOM_HOT)
	ball(root, 1.3, Vector3(0.2, 0.3, 0), BOOM)
	ball(root, 0.7, Vector3(-0.5, 0.4, 0.3), DARK)
	return root


static func building(item: Dictionary) -> Node3D:
	var root := Node3D.new()
	var sx := float(item["sx"])
	var sz := float(item["sz"])
	var h := float(item["h"])
	root.position = Vector3(float(item["x"]), 0, float(item["z"]))
	root.rotation.y = deg_to_rad(float(item["door"]))
	box(root, Vector3(sx, h, sz), Vector3(0, h * 0.5, 0), ADOBE)
	box(root, Vector3(sx + 0.7, 0.28, sz + 0.7), Vector3(0, h + 0.08, 0), ROOF)
	box(root, Vector3(0.95, 1.7, 0.12), Vector3(0, 0.85, sz * 0.5 + 0.02), DOOR)
	box(root, Vector3(0.12, 1.7, 0.95), Vector3(sx * 0.5 + 0.02, 0.85, 0), DOOR)
	box(root, Vector3(0.7, 0.7, 0.1), Vector3(-sx * 0.25, h * 0.62, sz * 0.5 + 0.05), WINDOW)
	box(root, Vector3(0.7, 0.7, 0.1), Vector3(sx * 0.25, h * 0.62, sz * 0.5 + 0.05), WINDOW)
	box(root, Vector3(0.1, 0.7, 0.7), Vector3(sx * 0.5 + 0.05, h * 0.62, -sz * 0.22), WINDOW)
	box(root, Vector3(0.1, 0.7, 0.7), Vector3(sx * 0.5 + 0.05, h * 0.62, sz * 0.22), WINDOW)
	return root


static var _tex: Dictionary = {}


static func layout() -> Dictionary:
	var text := FileAccess.get_file_as_string("res://art/sprites/layout.json")
	var data = JSON.parse_string(text)
	if data is Dictionary:
		return data
	return {}


static func tex(file_name: String) -> Texture2D:
	if _tex.has(file_name):
		return _tex[file_name]
	var image := Image.new()
	var err := image.load("res://art/sprites/" + file_name)
	if err != OK:
		push_error("missing sprite %s" % file_name)
	var made := ImageTexture.create_from_image(image)
	_tex[file_name] = made
	return made


static func sprite(file_name: String, flat := false, blend := false) -> Sprite3D:
	var node := Sprite3D.new()
	node.texture = tex(file_name)
	node.pixel_size = 1.0 / 12.0
	node.shaded = false
	node.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	node.double_sided = true
	node.transparent = true
	if blend:
		node.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
		node.render_priority = 10
	else:
		node.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
		node.alpha_scissor_threshold = 0.5
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.extra_cull_margin = 30.0
	if flat:
		node.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		node.axis = Vector3.AXIS_Y
	else:
		node.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	return node


static func ground() -> MeshInstance3D:
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(100, 100)
	var node := MeshInstance3D.new()
	node.mesh = mesh
	var made := StandardMaterial3D.new()
	made.albedo_texture = tex("ground.png")
	made.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	made.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	made.texture_repeat = false
	node.material_override = made
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


static func _ground_material() -> StandardMaterial3D:
	var image := Image.create(1024, 1024, false, Image.FORMAT_RGB8)
	var dirt := Color(0.72, 0.58, 0.36)
	var dark := Color(0.52, 0.4, 0.24)
	var track := Color(0.4, 0.32, 0.22)
	var scrub := Color(0.36, 0.42, 0.2)
	for y in 1024:
		for x in 1024:
			var wx := (float(x) / 1024.0 - 0.5) * 100.0
			var wz := (float(y) / 1024.0 - 0.5) * 100.0
			var n := _noise(x, y)
			var color := dirt.lerp(dark, n * 0.55)
			if absf(wx - 2.0) < 1.3 or absf(wz + 6.0) < 1.3:
				color = track.lerp(dark, n * 0.35)
			elif _noise(x + 90, y + 40) > 0.82:
				color = scrub
			image.set_pixel(x, y, color)
	var texture := ImageTexture.create_from_image(image)
	var made := StandardMaterial3D.new()
	made.albedo_texture = texture
	made.roughness = 1.0
	made.metallic = 0.0
	made.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	made.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	return made


static func _noise(x: int, y: int) -> float:
	var n := x * 374761393 + y * 668265263
	n = (n ^ (n >> 13)) * 1274126177
	n = n ^ (n >> 16)
	return float(n & 65535) / 65535.0
