extends Control
## Radar map, turned 45 degrees so "up" on the map is "up" on the screen.
## Used small on the HUD and large on the map screen.

const Rules = preload("res://core/rules.gd")
const UI = preload("res://ui/ui_theme.gd")
const K := 0.70710678

var world
var show_all := false     # the map screen also shows soldiers and buildings
var _scale := 1.0
var _origin := Vector2.ZERO


func _process(_delta: float) -> void:
	if is_visible_in_tree():
		queue_redraw()


func _to(x: float, z: float) -> Vector2:
	return _origin + Vector2((x - z) * K, (x + z) * K) * _scale


func _to3(p: Vector3) -> Vector2:
	return _to(p.x, p.z)


func _draw() -> void:
	if world == null or not is_instance_valid(world):
		return
	var s := size
	var half: float = world.half
	_scale = minf(s.x, s.y) / (half * 2.0 / K)
	_origin = s * 0.5
	var corners := PackedVector2Array([_to(-half, -half), _to(half, -half), _to(half, half), _to(-half, half)])
	draw_colored_polygon(corners, Color(0.16, 0.13, 0.09, 0.9))
	corners.append(corners[0])
	draw_polyline(corners, Color(Rules.PAPER, 0.8), 2.0)
	for r in world.mission["roads"]:
		var pts: Array = r["pts"]
		for i in range(pts.size() - 1):
			draw_line(_to(pts[i].x, pts[i].y), _to(pts[i + 1].x, pts[i + 1].y), Color(0.52, 0.42, 0.28), maxf(1.0, float(r["w"]) * _scale * 0.7))
	var blink := int(Time.get_ticks_msec() / 300) % 2 == 0
	var font: Font = UI.PIXEL
	var lz: Vector2 = _to3(world.lz)
	draw_circle(lz, maxf(5.0, Rules.LZ_RADIUS * _scale), Color(0.9, 0.9, 0.8, 0.35))
	draw_string(font, lz + Vector2(-5, 6), "H", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Rules.PAPER)
	var want_tags := {}
	var obj: Dictionary = world.current_objective()
	if not obj.is_empty() and obj["spec"].has("tag"):
		want_tags[str(obj["spec"]["tag"])] = true
	for u in world.units:
		if u.state == "waiting" or u.state == "escaped":
			continue
		var p: Vector2 = _to3(u.position)
		if u.state == "dead":
			continue
		if u.kind == "building":
			if show_all:
				draw_rect(Rect2(p - Vector2(3, 3), Vector2(6, 6)), Color(0.66, 0.54, 0.38))
			continue
		if u.kind == "soldier" and not show_all:
			continue
		var goal: bool = u.tag != "" and want_tags.has(u.tag)
		var col := Color(0.92, 0.3, 0.2)
		var r := 2.0 if u.kind == "soldier" else 3.5
		if goal:
			col = Color(1.0, 0.85, 0.2) if blink else Color(1.0, 0.55, 0.1)
			r += 2.0
		draw_circle(p, r, col)
	for pk in world.pickups:
		if pk["taken"]:
			continue
		var p: Vector2 = _to3(pk["at"])
		var col: Color = {"fuel": Color(0.9, 0.25, 0.2), "ammo": Color(0.6, 0.75, 0.3), "armor": Color(0.95, 0.95, 0.9)}[pk["kind"]]
		draw_rect(Rect2(p - Vector2(3.5, 3.5), Vector2(7, 7)), col)
		draw_rect(Rect2(p - Vector2(3.5, 3.5), Vector2(7, 7)), Color(0, 0, 0), false, 1.0)
	for c in world.crew:
		if c["state"] != "ground":
			continue
		draw_circle(_to3(c["at"]), 4.5, Color(1.0, 0.6, 0.15) if blink else Color(1, 1, 1))
	if world.hind != null and world.hind.alive:
		var hp: Vector2 = _to3(world.hind.pos)
		var f := Rules.yaw_forward(world.hind.yaw)
		var tip: Vector2 = _to(world.hind.pos.x + f.x, world.hind.pos.z + f.z) - hp
		var fwd := tip.normalized()
		var side := Vector2(-fwd.y, fwd.x)
		var pts := PackedVector2Array([hp + fwd * 9.0, hp - fwd * 5.0 + side * 5.5, hp - fwd * 5.0 - side * 5.5])
		draw_colored_polygon(pts, Color(1, 1, 1))
		draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[0]]), Color(0, 0, 0), 1.5)
