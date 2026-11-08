extends Node3D
## The player's Mi-24. Flight state plus the painted sprite, rotor frames, tilt, shadow and dust.

const Rules = preload("res://core/rules.gd")
const Art = preload("res://core/art.gd")

const HUB_HANG := 2.4

var pos := Vector3.ZERO
var vel := Vector3.ZERO
var yaw := 0.0
var band := 0
var lift := 0.0
var tilt_p := 0.0
var tilt_r := 0.0
var alive := true
var falling := false
var crashing := false
var fall_t := 0.0
var fall_from := 0.0
var spin_t := 0.0

var body: Sprite3D
var shadow: Sprite3D
var dust: Sprite3D


func _ready() -> void:
	body = Art.sprite("hind_0.png")
	body.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	body.extra_cull_margin = 80.0
	add_child(body)
	shadow = Art.sprite("shadow.png", true, true)
	shadow.modulate = Color(1, 1, 1, 0.85)
	add_child(shadow)
	dust = Art.sprite("dust_0.png", false, true)
	add_child(dust)


func place(at: Vector3, yaw_deg: float) -> void:
	pos = Rules.flat(at)
	vel = Vector3.ZERO
	yaw = yaw_deg
	band = 0
	lift = 0.0
	tilt_p = 0.0
	tilt_r = 0.0
	alive = true
	falling = false
	visible = true


func speed() -> float:
	return vel.length()


func aim_point() -> Vector3:
	return Vector3(pos.x, lift + 1.6, pos.z)


func fly(delta: float, wish: Vector2, turn: float, blockers: Array, half: float, w := 1.0) -> Dictionary:
	## wish: x strafe right, y thrust forward. turn: + is left. w: weight, 1.0 full.
	## Returns the slide result: pos, hit, reason.
	yaw = wrapf(yaw + turn * Rules.YAW_RATE / w * delta, -180.0, 180.0)
	vel = Rules.step_velocity(vel, wish, yaw, delta, w)
	var res := Rules.slide(pos, pos + vel * delta, band, blockers, half)
	var moved: Vector3 = res["pos"]
	if bool(res["hit"]):
		# She stops against what stopped her.
		vel = Vector3.ZERO
	pos = moved
	var goal := Rules.band_y(band)
	lift = move_toward(lift, goal, Rules.BAND_Y[1] / Rules.CLIMB_SEC / w * delta)
	var fwd := Rules.yaw_forward(yaw)
	var right := Rules.yaw_right(yaw)
	var want_p := -Rules.TILT_MAX * clampf(vel.dot(fwd) / Rules.MAX_SPEED, -1.0, 1.0)
	var want_r := Rules.TILT_MAX * clampf(vel.dot(right) / Rules.MAX_SPEED, -1.0, 1.0)
	var lag := 1.0 - exp(-Rules.TILT_LAG / w * delta)
	tilt_p = lerpf(tilt_p, want_p, lag)
	tilt_r = lerpf(tilt_r, want_r, lag)
	return res


func shove(wish: Vector2, w := 1.0) -> void:
	## A tap is one shove.
	var dir := Rules.wish_dir(wish, yaw)
	if dir != Vector3.ZERO:
		vel = Rules.shove(vel, dir, w)


func moving() -> bool:
	return vel.length() > Rules.STILL_SPEED


func blocker_below(next_band: int, blockers: Array) -> String:
	## What stops a descent into a tree or a roof, or "".
	return Rules.blocked_at(pos.x, pos.z, next_band, blockers)


func start_fall(crash: bool) -> void:
	## crash: health at zero, she spins down. Otherwise empty fuel: she autorotates and lands.
	falling = true
	crashing = crash
	fall_t = 0.0
	fall_from = lift
	vel = vel * 0.5 if crash else Vector3.ZERO


func fall(delta: float) -> bool:
	## Returns true on touchdown.
	fall_t += delta
	var dur := Rules.LAND_SEC * (1.0 if crashing else 1.0 + fall_from / Rules.BAND_Y[2])
	var t := clampf(fall_t / dur, 0.0, 1.0)
	if crashing:
		lift = lerpf(fall_from, 0.0, t * t)
		yaw += 120.0 * delta * t
		pos += vel * delta
		vel *= exp(-1.5 * delta)
	else:
		lift = lerpf(fall_from, 0.0, smoothstep(0.0, 1.0, t))
	return t >= 1.0


func paint(delta: float, cam_basis: Basis, wash: float, damaged: bool) -> void:
	spin_t += delta
	var face := Rules.facing_index(yaw)
	var hang := _hang_basis(cam_basis, face)
	var mast_at := Vector3(pos.x, lift, pos.z) + cam_basis.y * HUB_HANG
	body.global_position = mast_at - hang.y * HUB_HANG + Rules.SPRITE_LIFT
	body.global_basis = hang
	var stem := _gear_stem(face)
	var frame := posmod(int(spin_t * (30.0 if alive else 10.0)), 12)
	var spin := "spin/%s_%d.png" % [stem, frame]
	body.texture = Art.tex(spin if Art.has(spin) else stem + ".png")
	body.offset = Art.body_shift("hind_%d" % face) - Art.body_shift(stem)
	body.modulate = Color(0.85, 0.8, 0.75) if damaged and int(spin_t * 6.0) % 2 == 0 else Color.WHITE
	var step_f := Rules.band_of_lift(lift)
	shadow.scale = Vector3.ONE * lerpf(1.0, 2.4, clampf(step_f, 0.0, 2.0) / 2.0)
	var travel := Rules.SHADOW_TRAVEL
	var reach := lift / -travel.y * 1.6
	shadow.global_position = Vector3(pos.x + travel.x * reach, 0.04, pos.z + travel.z * reach)
	dust.global_position = Vector3(pos.x, 0.2, pos.z) + Rules.SPRITE_LIFT
	var wind := 0.0
	if lift < Rules.BAND_Y[1] + 1.0:
		wind = clampf(1.0 - lift / (Rules.BAND_Y[1] + 1.0), 0.0, 1.0) * 1.2
	var disc := maxf(wash * 2.5, wind * 1.4)
	dust.visible = alive and disc > 0.3
	dust.scale = Vector3.ONE * maxf(disc, 0.3)
	dust.texture = Art.tex("dust_%d.png" % posmod(int(spin_t * 10.0), 3))
	dust.modulate = Color(1, 1, 1, clampf(disc / 2.0, 0.3, 0.85))


func _gear_stem(face: int) -> String:
	var step := lift / Rules.BAND_Y[1]
	var tag := ""
	if step >= 0.7:
		tag = "_up"
	elif step >= 0.25:
		tag = "_mid"
	var stem := "hind_%d%s" % [face, tag]
	if tag != "" and not Art.has(stem + ".png"):
		return "hind_%d" % face
	return stem


func _hang_basis(cam_basis: Basis, face: int) -> Basis:
	var noses := [Vector2(1, 1), Vector2(0, 1), Vector2(-1, 1), Vector2(-1, 0), Vector2(-1, -1), Vector2(0, -1), Vector2(1, -1), Vector2(1, 0)]
	var nose: Vector2 = noses[face].normalized()
	var axis_2 := Vector2(-nose.y, nose.x)
	var axis := (cam_basis.x * axis_2.x + cam_basis.y * axis_2.y).normalized()
	var pitched := Basis(axis, deg_to_rad(tilt_p))
	var rolled := Basis(-cam_basis.z, deg_to_rad(tilt_r))
	return rolled * pitched * cam_basis
