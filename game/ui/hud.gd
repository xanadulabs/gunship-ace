extends CanvasLayer
## The in-mission HUD. No plates: one thin strip across the top, like the 16-bit arcade games,
## and callouts that pop and fade. Every word is the pixel font with a heavy ink stroke.
##   Top left:   FUEL bar and number, HEALTH in blocks (one block per enemy shot), height and wash.
##   Top middle: the objective and its progress.
##   Top right:  gun, rockets, missiles, lives, crew aboard.
##   Callouts:   big good/alert news under the strip; the notice line (stop and shot sentences)
##               low in the middle; a flashing MISSILE warning.
##   F1 shows the keys, bottom left. The radar sits bottom right.

const Rules = preload("res://core/rules.gd")
const UI = preload("res://ui/ui_theme.gd")
const MinimapSc = preload("res://ui/minimap.gd")

const GOOD := Color(0.62, 0.95, 0.35)
const BAD := Color(1.0, 0.36, 0.22)
const GOLD := Color(1.0, 0.82, 0.25)
const WHITE := Color(1.0, 0.97, 0.9)
const COOL := Color(0.55, 0.85, 1.0)
const OBJECTIVE_CHARS := 42         # fits the middle of the strip at 16 px with room each side


class Bar extends Control:
	## A segmented arcade bar: ink frame, dark trough, bright cells.
	var frac := 1.0
	var cells := 20
	var fill := Color.WHITE
	var flash := false

	func _draw() -> void:
		var s := size
		draw_rect(Rect2(Vector2(-3, -3), s + Vector2(6, 6)), Rules.INK)
		draw_rect(Rect2(Vector2.ZERO, s), Color(0.22, 0.17, 0.12))
		var cw := s.x / cells
		var lit := ceili(clampf(frac, 0.0, 1.0) * cells - 0.001)
		for i in lit:
			var c := fill if not flash else BAD
			draw_rect(Rect2(Vector2(i * cw + 1, 1), Vector2(cw - 2, s.y - 2)), c)
			draw_rect(Rect2(Vector2(i * cw + 1, 1), Vector2(cw - 2, 3)), c.lightened(0.35))


var world
var root: Control
var left: Control                 # the key list (F1); the name is kept for the tests
var fuel_bar: Bar
var fuel_num: Label
var health_bar: Bar
var height_label: Label
var objective: Label
var progress: Label
var ammo_label: Label
var lives_label: Label
var crew_label: Label
var notice_label: Label
var warn_label: Label
var messages: VBoxContainer
var minimap: Control
var _notice := ""
var _notice_left := 0.0


func setup(w) -> void:
	world = w
	world.message.connect(_on_message)
	layer = 5
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_strip_left()
	_strip_middle()
	_strip_right()
	_callouts()
	_keys()
	_radar()
	left.visible = Settings.show_keys


func _pin(c: Control, anchor: Vector2, offset: Vector2, size: Vector2) -> void:
	## Pin a control to a screen point by anchor and offsets, so it holds at any window size.
	c.anchor_left = anchor.x
	c.anchor_right = anchor.x
	c.anchor_top = anchor.y
	c.anchor_bottom = anchor.y
	c.offset_left = offset.x
	c.offset_top = offset.y
	c.offset_right = offset.x + size.x
	c.offset_bottom = offset.y + size.y


func _text(size: int, color: Color, anchor: Vector2, offset: Vector2, box: Vector2, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := UI.pixel_label("", size, color)
	l.horizontal_alignment = align
	root.add_child(l)
	_pin(l, anchor, offset, box)
	return l


func _strip_left() -> void:
	_text(16, WHITE, Vector2(0, 0), Vector2(20, 18), Vector2(110, 20)).text = "FUEL"
	fuel_bar = Bar.new()
	fuel_bar.fill = GOLD
	root.add_child(fuel_bar)
	_pin(fuel_bar, Vector2(0, 0), Vector2(136, 18), Vector2(240, 16))
	fuel_num = _text(16, WHITE, Vector2(0, 0), Vector2(390, 18), Vector2(70, 20))
	_text(16, WHITE, Vector2(0, 0), Vector2(20, 48), Vector2(110, 20)).text = "HEALTH"
	health_bar = Bar.new()
	health_bar.fill = GOOD
	health_bar.cells = int(Rules.HEALTH_START / Rules.ENEMY_SHOT)
	root.add_child(health_bar)
	_pin(health_bar, Vector2(0, 0), Vector2(136, 48), Vector2(240, 16))
	height_label = _text(16, COOL, Vector2(0, 0), Vector2(20, 78), Vector2(460, 20))


func _strip_middle() -> void:
	## One line, never wrapped: objective labels are kept to OBJECTIVE_CHARS (the probe checks).
	objective = _text(16, WHITE, Vector2(0.5, 0), Vector2(-370, 18), Vector2(740, 20), HORIZONTAL_ALIGNMENT_CENTER)
	progress = _text(24, GOLD, Vector2(0.5, 0), Vector2(-150, 48), Vector2(300, 28), HORIZONTAL_ALIGNMENT_CENTER)


func _strip_right() -> void:
	ammo_label = _text(16, WHITE, Vector2(1, 0), Vector2(-500, 18), Vector2(480, 20), HORIZONTAL_ALIGNMENT_RIGHT)
	lives_label = _text(16, WHITE, Vector2(1, 0), Vector2(-500, 48), Vector2(480, 20), HORIZONTAL_ALIGNMENT_RIGHT)
	crew_label = _text(16, GOOD, Vector2(1, 0), Vector2(-500, 78), Vector2(480, 20), HORIZONTAL_ALIGNMENT_RIGHT)


func _callouts() -> void:
	messages = VBoxContainer.new()
	messages.mouse_filter = Control.MOUSE_FILTER_IGNORE
	messages.add_theme_constant_override("separation", 10)
	root.add_child(messages)
	_pin(messages, Vector2(0.5, 0), Vector2(-400, 110), Vector2(800, 10))
	warn_label = _text(32, BAD, Vector2(0.5, 0.5), Vector2(-300, -170), Vector2(600, 40), HORIZONTAL_ALIGNMENT_CENTER)
	warn_label.text = "MISSILE!"
	warn_label.visible = false
	notice_label = _text(16, WHITE, Vector2(0.5, 1), Vector2(-420, -70), Vector2(840, 20), HORIZONTAL_ALIGNMENT_CENTER)


func _key_lines() -> Array[String]:
	var k := func(a: String) -> String: return Controls.key_name(a)
	var lines: Array[String] = [
		"%s moves forward." % k.call("thrust_fwd"),
		"%s moves back." % k.call("thrust_back"),
		"%s turns left." % k.call("turn_left"),
		"%s turns right." % k.call("turn_right"),
	]
	# Slide has no key by default; name it only once someone binds one.
	if k.call("strafe_left") != "-":
		lines.append("%s moves left." % k.call("strafe_left"))
	if k.call("strafe_right") != "-":
		lines.append("%s moves right." % k.call("strafe_right"))
	return lines + ([
		"%s goes up." % k.call("climb"),
		"%s goes down." % k.call("descend"),
		"%s fires." % k.call("fire_gun"),
		"%s fires rockets." % k.call("fire_rocket"),
		"%s fires a missile." % k.call("fire_atgm"),
		"%s shows the map." % k.call("map"),
		"%s hides the keys." % k.call("help"),
	] as Array[String])


func _keys() -> void:
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 8)
	v.alignment = BoxContainer.ALIGNMENT_END
	root.add_child(v)
	_pin(v, Vector2(0, 1), Vector2(20, -400), Vector2(560, 380))
	var lines := _key_lines()
	for i in lines.size():
		v.add_child(UI.pixel_label(lines[i].to_upper(), 16, WHITE if i < lines.size() - 4 else Color(0.8, 0.76, 0.66)))
	left = v


func _radar() -> void:
	minimap = MinimapSc.new()
	minimap.world = world
	minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(minimap)
	_pin(minimap, Vector2(1, 1), Vector2(-212, -212), Vector2(196, 196))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("help"):
		left.visible = not left.visible
		Settings.show_keys = left.visible
		Settings.save_settings()


func _process(delta: float) -> void:
	if world == null:
		return
	var o: Dictionary = world.current_objective()
	if o.is_empty():
		objective.text = Rules.end_line("clear").to_upper()
		progress.text = ""
	else:
		objective.text = str(o["spec"]["label"]).to_upper()
		progress.text = str(o["progress"])
	var blink := int(world.time * 3.0) % 2 == 0
	fuel_bar.frac = world.fuel / Rules.FUEL_START
	fuel_bar.flash = world.fuel < 25.0 and blink
	fuel_bar.queue_redraw()
	fuel_num.text = str(int(ceil(world.fuel)))
	health_bar.frac = float(world.health) / Rules.HEALTH_START
	health_bar.fill = GOOD if world.health > Rules.ENEMY_SHOT else BAD
	health_bar.queue_redraw()
	var wash: String = world.wash_mode()
	var wash_word: String = {"attack": "WASH ON", "wind": "WIND", "off": "WASH OFF"}.get(wash, "")
	height_label.text = "%s  -  %s" % [Rules.BAND_NAMES[world.hind.band].to_upper(), wash_word]
	height_label.add_theme_color_override("font_color", GOLD if wash == "attack" else COOL)
	ammo_label.text = "GUN %d  RKT %d  MSL %d" % [world.ammo.get("gun", 0), world.ammo.get("rocket", 0), world.ammo.get("atgm", 0)]
	lives_label.text = "LIVES %d" % world.lives
	crew_label.text = "CREW %d/%d" % [world.aboard, Rules.CREW_CAPACITY] if world.crew.size() > 0 else ""
	if _notice_left > 0.0:
		_notice_left -= delta
		if _notice_left <= 0.0:
			_notice = ""
	notice_label.text = _notice.to_upper()
	notice_label.modulate.a = clampf(_notice_left / 0.4, 0.0, 1.0)
	warn_label.visible = world.missile_warning and int(world.time * 6.0) % 2 == 0
	for m in messages.get_children():
		var t := float(m.get_meta("left")) - delta
		m.set_meta("left", t)
		if t <= 0.0:
			m.queue_free()
		elif t < 0.5:
			m.modulate.a = t / 0.5


func _on_message(text: String, tone: String) -> void:
	## Every sentence goes on the notice line. Good news and alarms also pop big under the strip.
	_notice = text
	_notice_left = 1.6
	if tone == "info":
		return
	var l := UI.pixel_label(text.to_upper(), 24, GOOD if tone == "good" else BAD if tone == "alert" else WHITE)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.set_meta("left", 2.6)
	messages.add_child(l)
	while messages.get_child_count() > 2:
		var first := messages.get_child(0)
		messages.remove_child(first)
		first.queue_free()
