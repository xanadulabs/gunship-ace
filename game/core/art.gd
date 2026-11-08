extends RefCounted
## Sprite textures and Sprite3D factory. Loads imported textures, so it works in exported builds.

const DIR := "res://art/sprites/"
const PIXEL := 1.0 / 12.0   # world meters per sprite pixel; keeps the slice art at its painted size

static var _tex: Dictionary = {}
static var _exists: Dictionary = {}
static var _shift: Dictionary = {}


static func has(file_name: String) -> bool:
	if _exists.has(file_name):
		return _exists[file_name]
	var ok := ResourceLoader.exists(DIR + file_name)
	_exists[file_name] = ok
	return ok


static func tex(file_name: String) -> Texture2D:
	if _tex.has(file_name):
		return _tex[file_name]
	var t: Texture2D = null
	if has(file_name):
		t = load(DIR + file_name)
	else:
		push_warning("missing sprite %s" % file_name)
	_tex[file_name] = t
	return t


static func sprite(file_name: String, flat := false, blend := false) -> Sprite3D:
	var node := Sprite3D.new()
	node.texture = tex(file_name)
	node.pixel_size = PIXEL
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


static func body_shift(stem: String) -> Vector2:
	## Center of the thick fuselage in a Hind picture, relative to the image center.
	## The gear pictures were not framed on the same pixel; this keeps the body still.
	if _shift.has(stem):
		return _shift[stem]
	var shift := Vector2.ZERO
	var t := tex(stem + ".png")
	if t != null:
		var image := t.get_image()
		if image != null:
			if image.is_compressed():
				image.decompress()
			shift = _thick_center(image)
	_shift[stem] = shift
	return shift


static func _thick_center(image: Image) -> Vector2:
	var rad := 8
	var w := image.get_width()
	var h := image.get_height()
	var sx := 0.0
	var sy := 0.0
	var n := 0
	var y := rad
	while y < h - rad:
		var x := rad
		while x < w - rad:
			if image.get_pixel(x, y).a >= 0.5 and _thick(image, x, y, rad):
				sx += x
				sy += y
				n += 1
			x += 2
		y += 2
	if n < 8:
		return Vector2.ZERO
	return Vector2(sx / float(n) - float(w) * 0.5, sy / float(n) - float(h) * 0.5)


static func _thick(image: Image, x: int, y: int, rad: int) -> bool:
	for dy in [-rad, 0, rad]:
		for dx in [-rad, 0, rad]:
			if image.get_pixel(x + dx, y + dy).a < 0.5:
				return false
	return true
