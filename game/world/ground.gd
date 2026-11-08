extends MeshInstance3D
## Painted desert floor. A shader dithers three sand tones from noise at the sprite pixel grid,
## and reads a mask for roads (r), cleared pads (g) and scorch marks (b).

const PX_PER_M := 2.0
const BEYOND := 70.0

const SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform sampler2D mask_tex : filter_linear, repeat_disable;
uniform sampler2D noise_tex : filter_linear, repeat_enable;
uniform float half_size = 100.0;
uniform vec3 hi = vec3(0.776, 0.635, 0.424);
uniform vec3 mid = vec3(0.690, 0.545, 0.345);
uniform vec3 lo = vec3(0.553, 0.420, 0.255);
uniform vec3 scrub = vec3(0.329, 0.392, 0.180);
uniform vec3 road = vec3(0.580, 0.451, 0.290);
uniform vec3 rut = vec3(0.373, 0.275, 0.161);
uniform vec3 rim = vec3(0.835, 0.737, 0.545);
uniform vec3 pad = vec3(0.722, 0.596, 0.408);
uniform vec3 pad_rim = vec3(0.478, 0.361, 0.227);
uniform vec3 scorch = vec3(0.196, 0.157, 0.122);

varying vec3 wp;

float bayer(vec2 p) {
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	int i = y * 4 + x;
	float m[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return m[i] / 16.0;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 cell = floor(wp.xz * 12.0);
	vec2 w = (cell + 0.5) / 12.0;
	float n1 = texture(noise_tex, w / 96.0).r;
	float n2 = texture(noise_tex, w / 21.0 + vec2(0.37, 0.71)).r;
	float v = n1 * 0.62 + n2 * 0.38;
	float b = bayer(cell);
	float t = v + (b - 0.5) * 0.2;
	vec3 col = t > 0.56 ? hi : (t > 0.43 ? mid : lo);
	if (hash(floor(cell / 3.0)) > 0.994 && n2 > 0.45) {
		col = scrub;
	}
	vec2 uv = (w + half_size) / (2.0 * half_size);
	if (uv.x > 0.0 && uv.x < 1.0 && uv.y > 0.0 && uv.y < 1.0) {
		vec3 m = texture(mask_tex, uv).rgb;
		if (m.g > 0.03) {
			col = m.g < 0.1 ? pad_rim : pad;
			if (m.g >= 0.1 && b > 0.8) { col = mix(pad, mid, 0.5); }
		}
		if (m.r > 0.0) {
			float d = 1.0 - m.r;
			if (d > 0.84) { col = rim; }
			else if (abs(d - 0.48) < 0.11) { col = rut; }
			else { col = b > 0.85 ? mix(road, lo, 0.5) : road; }
		}
		if (m.b > 0.25 && b < m.b) {
			col = mix(col, scorch, 0.85);
		}
	}
	float out_by = max(abs(w.x), abs(w.y)) - half_size;
	if (out_by > 0.0) {
		col *= out_by > 3.0 ? 0.72 : (b < 0.5 ? 0.72 : 1.0);
	}
	ALBEDO = col;
}
"""

var half := 100.0
var mask: Image
var mask_tex: ImageTexture
var _dirty := false


func build(mission: Dictionary) -> void:
	half = float(mission["half"])
	var size := int(half * 2.0 * PX_PER_M)
	mask = Image.create(size, size, false, Image.FORMAT_RGB8)
	mask.fill(Color(0, 0, 0))
	for p in mission["pads"]:
		_pad(p["at"], p["r"])
	for r in mission["roads"]:
		var pts: Array = r["pts"]
		for i in range(pts.size() - 1):
			_segment(pts[i], pts[i + 1], float(r["w"]) * 0.5)
	mask_tex = ImageTexture.create_from_image(mask)
	var plane := PlaneMesh.new()
	plane.size = Vector2((half + BEYOND) * 2.0, (half + BEYOND) * 2.0)
	mesh = plane
	var noise := FastNoiseLite.new()
	noise.seed = int(mission["seed"])
	noise.frequency = 0.012
	noise.fractal_octaves = 3
	var noise_img := noise.get_seamless_image(256, 256)
	var mat := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = SHADER
	mat.shader = shader
	mat.set_shader_parameter("mask_tex", mask_tex)
	mat.set_shader_parameter("noise_tex", ImageTexture.create_from_image(noise_img))
	mat.set_shader_parameter("half_size", half)
	material_override = mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _to_px(p: Vector2) -> Vector2:
	return (p + Vector2(half, half)) * PX_PER_M


func _segment(a: Vector2, b: Vector2, half_w: float) -> void:
	var pa := _to_px(a)
	var pb := _to_px(b)
	var r := half_w * PX_PER_M
	var x0 := maxi(0, int(minf(pa.x, pb.x) - r - 1))
	var x1 := mini(mask.get_width() - 1, int(maxf(pa.x, pb.x) + r + 1))
	var y0 := maxi(0, int(minf(pa.y, pb.y) - r - 1))
	var y1 := mini(mask.get_height() - 1, int(maxf(pa.y, pb.y) + r + 1))
	var ab := pb - pa
	var len2 := maxf(ab.length_squared(), 0.0001)
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var p := Vector2(x + 0.5, y + 0.5)
			var t := clampf((p - pa).dot(ab) / len2, 0.0, 1.0)
			var d := p.distance_to(pa + ab * t)
			if d > r:
				continue
			var v := 1.0 - d / r
			var c := mask.get_pixel(x, y)
			if v > c.r:
				c.r = v
				mask.set_pixel(x, y, c)


func _pad(at: Vector2, radii: Vector2) -> void:
	var c := _to_px(at)
	var rx := radii.x * PX_PER_M
	var ry := radii.y * PX_PER_M
	for y in range(maxi(0, int(c.y - ry - 1)), mini(mask.get_height(), int(c.y + ry + 2))):
		for x in range(maxi(0, int(c.x - rx - 1)), mini(mask.get_width(), int(c.x + rx + 2))):
			var ex := (x + 0.5 - c.x) / rx
			var ey := (y + 0.5 - c.y) / ry
			var e := sqrt(ex * ex + ey * ey)
			if e > 1.0:
				continue
			var col := mask.get_pixel(x, y)
			col.g = maxf(col.g, clampf(1.0 - e, 0.04, 1.0))
			mask.set_pixel(x, y, col)


func scorch(at: Vector3, radius: float) -> void:
	var c := _to_px(Vector2(at.x, at.z))
	var r := radius * PX_PER_M
	for y in range(maxi(0, int(c.y - r)), mini(mask.get_height(), int(c.y + r + 1))):
		for x in range(maxi(0, int(c.x - r)), mini(mask.get_width(), int(c.x + r + 1))):
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c) / r
			if d > 1.0:
				continue
			var col := mask.get_pixel(x, y)
			col.b = maxf(col.b, 1.0 - d * 0.8)
			mask.set_pixel(x, y, col)
	_dirty = true


func _process(_delta: float) -> void:
	if _dirty:
		_dirty = false
		mask_tex.update(mask)


func on_road(p: Vector2, roads: Array, margin: float) -> bool:
	for r in roads:
		var pts: Array = r["pts"]
		for i in range(pts.size() - 1):
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[i + 1]
			var ab := b - a
			var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
			if p.distance_to(a + ab * t) < float(r["w"]) * 0.5 + margin:
				return true
	return false
