extends CanvasLayer
## The plates. Ink #1C1610 and paper #F4E8D0.
## The left plate names the keys. The right plate says Fuel, Health, the objective, the height line
## and the wash line, then a notice line for the stop and shot sentences.
## Extras on top of the original: ammo and lives, a radar, and a short stack of big messages.

const Rules = preload("res://core/rules.gd")
const UI = preload("res://ui/ui_theme.gd")
const MinimapSc = preload("res://ui/minimap.gd")

const LINE_H := 34
const FONT := 22

var world
var root: Control
var left: Panel
var right: Panel
var key_labels: Array[Label] = []
var status: Array[Label] = []
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
	root.theme = UI.get_theme()
	add_child(root)
	_left_plate()
	_right_plate()
	_messages()
	_radar()
	left.visible = Settings.show_keys


func _pin(c: Control, anchor: Vector2, offset: Vector2, size: Vector2) -> void:
	## Pin a control to a screen corner by anchor and offsets, so it holds at any window size.
	c.anchor_left = anchor.x
	c.anchor_right = anchor.x
	c.anchor_top = anchor.y
	c.anchor_bottom = anchor.y
	c.offset_left = offset.x
	c.offset_top = offset.y
	c.offset_right = offset.x + size.x
	c.offset_bottom = offset.y + size.y


func _plate() -> Panel:
	var p := Panel.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", UI.plate(Rules.INK, Rules.PAPER, 4))
	root.add_child(p)
	return p


func _line(parent: Control, i: int, size := FONT) -> Label:
	var l := UI.label("", size, Rules.PAPER)
	l.position = Vector2(16, 10 + i * LINE_H)
	l.size = Vector2(430, LINE_H)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.clip_text = true
	parent.add_child(l)
	return l


func _key_lines() -> Array[String]:
	var k := func(a: String) -> String: return Controls.key_name(a)
	return [
		"%s moves forward." % k.call("thrust_fwd"),
		"%s moves left." % k.call("strafe_left"),
		"%s moves back." % k.call("thrust_back"),
		"%s moves right." % k.call("strafe_right"),
		"%s turns left." % k.call("turn_left"),
		"%s turns right." % k.call("turn_right"),
		"%s goes up." % k.call("climb"),
		"%s goes down." % k.call("descend"),
		"%s fires." % k.call("fire_gun"),
		"%s fires rockets." % k.call("fire_rocket"),
		"%s fires a missile." % k.call("fire_atgm"),
		"%s shows the map." % k.call("map"),
		"%s hides this plate." % k.call("help"),
	]


func _left_plate() -> void:
	left = _plate()
	left.position = Vector2(16, 16)
	var lines := _key_lines()
	left.size = Vector2(390, 20 + lines.size() * LINE_H)
	for i in lines.size():
		var l := _line(left, i, 21 if i < 9 else 17)
		l.text = lines[i]
		if i >= 9:
			l.add_theme_color_override("font_color", UI.DIM)
		key_labels.append(l)


func _right_plate() -> void:
	right = _plate()
	_pin(right, Vector2(1, 0), Vector2(-486, 16), Vector2(470, 20 + 9 * LINE_H))
	for i in 9:
		var size := FONT
		if i == 2 or i == 3:
			size = 19
		elif i >= 6 and i <= 7:
			size = 18
		status.append(_line(right, i, size))
	status[3].add_theme_color_override("font_color", UI.ACCENT)
	status[6].add_theme_color_override("font_color", UI.DIM)
	warn_label = UI.label("MISSILE", 44, Rules.ALERT, true)
	warn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warn_label.visible = false
	root.add_child(warn_label)
	_pin(warn_label, Vector2(0.5, 0), Vector2(-200, 160), Vector2(400, 60))


func _messages() -> void:
	messages = VBoxContainer.new()
	messages.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(messages)
	_pin(messages, Vector2(0.5, 0), Vector2(-280, 24), Vector2(560, 10))


func _radar() -> void:
	minimap = MinimapSc.new()
	minimap.world = world
	minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(minimap)
	_pin(minimap, Vector2(1, 1), Vector2(-256, -256), Vector2(240, 240))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("help"):
		left.visible = not left.visible
		Settings.show_keys = left.visible
		Settings.save_settings()


func _process(delta: float) -> void:
	if world == null:
		return
	var o: Dictionary = world.current_objective()
	var obj := Rules.end_line("clear")
	var prog := ""
	if not o.is_empty():
		obj = str(o["spec"]["label"])
		prog = str(o["progress"])
	status[0].text = Rules.fuel_line(world.fuel)
	status[0].add_theme_color_override("font_color", Rules.ALERT if world.fuel < 25.0 and int(world.time * 3.0) % 2 == 0 else Rules.PAPER)
	status[1].text = Rules.health_line(world.health)
	status[1].add_theme_color_override("font_color", Rules.ALERT if world.health <= Rules.ENEMY_SHOT else Rules.PAPER)
	status[2].text = obj
	status[3].text = prog
	status[4].text = Rules.height_line(world.hind.band)
	status[5].text = Rules.wash_line(world.wash_mode())
	status[6].text = "Rockets %d   Missiles %d   Gun %d   Lives %d" % [world.ammo.get("rocket", 0), world.ammo.get("atgm", 0), world.ammo.get("gun", 0), world.lives]
	status[7].text = "Crew aboard %d of %d" % [world.aboard, Rules.CREW_CAPACITY] if world.crew.size() > 0 else ""
	if _notice_left > 0.0:
		_notice_left -= delta
		if _notice_left <= 0.0:
			_notice = ""
	status[8].text = _notice
	warn_label.visible = world.missile_warning and int(world.time * 6.0) % 2 == 0
	for m in messages.get_children():
		var t := float(m.get_meta("left")) - delta
		m.set_meta("left", t)
		if t <= 0.0:
			m.queue_free()
		elif t < 0.5:
			m.modulate.a = t / 0.5


func _on_message(text: String, tone: String) -> void:
	## Every sentence goes on the notice line. Good news and alarms also show big, center top.
	_notice = text
	_notice_left = 1.6
	if tone == "info":
		return
	var col: Color = {"good": Color(0.78, 0.92, 0.5), "alert": Color(1.0, 0.55, 0.4)}.get(tone, Rules.PAPER)
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UI.plate(Rules.INK, Rules.PAPER, 2, 12))
	box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(UI.label(text, 22, col))
	box.set_meta("left", 2.6)
	messages.add_child(box)
	while messages.get_child_count() > 3:
		var first := messages.get_child(0)
		messages.remove_child(first)
		first.queue_free()
