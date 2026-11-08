extends CanvasLayer
## In-flight HUD: gauges top left, objective top center, messages, height and wash bottom left,
## radar bottom right, controls card on F1.

const Rules = preload("res://core/rules.gd")
const UI = preload("res://ui/ui_theme.gd")
const MinimapSc = preload("res://ui/minimap.gd")

var world
var root: Control
var armor_bar: ColorRect
var fuel_bar: ColorRect
var armor_label: Label
var fuel_label: Label
var ammo_label: Label
var lives_label: Label
var objective_label: Label
var progress_label: Label
var band_boxes: Array[Panel] = []
var band_labels: Array[Label] = []
var wash_bar: ColorRect
var wash_label: Label
var crew_label: Label
var warn_label: Label
var messages: VBoxContainer
var help: PanelContainer
var minimap: Control
var _help_auto := 0.0


func setup(w) -> void:
	world = w
	world.message.connect(_on_message)
	layer = 5
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UI.get_theme()
	add_child(root)
	_gauges()
	_objective()
	_height()
	_messages()
	_radar()
	_help()
	if not Settings.seen_help:
		help.visible = true
		_help_auto = 12.0
		Settings.seen_help = true
		Settings.save_settings()


func _panel(pos: Vector2, size: Vector2) -> Panel:
	var p := Panel.new()
	p.position = pos
	p.size = size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", UI.plate(Color(Rules.INK, 0.8), Color(Rules.PAPER, 0.6), 2))
	return p


func _bar(parent: Control, y: float, col: Color) -> ColorRect:
	var back := ColorRect.new()
	back.color = Color(0.25, 0.2, 0.15)
	back.position = Vector2(92, y)
	back.size = Vector2(200, 18)
	parent.add_child(back)
	var fill := ColorRect.new()
	fill.color = col
	fill.size = Vector2(200, 18)
	back.add_child(fill)
	return fill


func _gauges() -> void:
	var p := _panel(Vector2(16, 16), Vector2(380, 150))
	root.add_child(p)
	var a := UI.label("ARMOR", 18)
	a.position = Vector2(14, 10)
	p.add_child(a)
	armor_bar = _bar(p, 14, Rules.GOOD)
	armor_label = UI.label("", 18)
	armor_label.position = Vector2(300, 10)
	p.add_child(armor_label)
	var f := UI.label("FUEL", 18)
	f.position = Vector2(14, 40)
	p.add_child(f)
	fuel_bar = _bar(p, 44, UI.ACCENT)
	fuel_label = UI.label("", 18)
	fuel_label.position = Vector2(300, 40)
	p.add_child(fuel_label)
	ammo_label = UI.label("", 18)
	ammo_label.position = Vector2(14, 74)
	p.add_child(ammo_label)
	lives_label = UI.label("", 18)
	lives_label.position = Vector2(14, 108)
	p.add_child(lives_label)


func _objective() -> void:
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UI.plate(Color(Rules.INK, 0.8), Color(Rules.PAPER, 0.6), 2, 16))
	box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.position.y = 16
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(box)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	box.add_child(v)
	objective_label = UI.label("", 22)
	objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(objective_label)
	progress_label = UI.label("", 18, UI.ACCENT)
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(progress_label)
	warn_label = UI.label("MISSILE", 44, Rules.ALERT, true)
	warn_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	warn_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	warn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warn_label.position.y = 190
	warn_label.visible = false
	root.add_child(warn_label)


func _height() -> void:
	var p := _panel(Vector2(16, 0), Vector2(300, 148))
	p.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	p.position = Vector2(16, -164)
	p.grow_vertical = Control.GROW_DIRECTION_BEGIN
	root.add_child(p)
	for i in Rules.BANDS:
		var b := Panel.new()
		b.position = Vector2(14 + i * 92, 12)
		b.size = Vector2(84, 34)
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_child(b)
		band_boxes.append(b)
		var l := UI.label(Rules.BAND_NAMES[i], 18)
		l.size = b.size
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		b.add_child(l)
		band_labels.append(l)
	wash_label = UI.label("WASH", 18)
	wash_label.position = Vector2(14, 56)
	p.add_child(wash_label)
	var back := ColorRect.new()
	back.color = Color(0.25, 0.2, 0.15)
	back.position = Vector2(92, 60)
	back.size = Vector2(190, 18)
	p.add_child(back)
	wash_bar = ColorRect.new()
	wash_bar.color = Color(0.85, 0.75, 0.5)
	wash_bar.size = Vector2(0, 18)
	back.add_child(wash_bar)
	crew_label = UI.label("", 18)
	crew_label.position = Vector2(14, 92)
	p.add_child(crew_label)


func _messages() -> void:
	messages = VBoxContainer.new()
	messages.set_anchors_preset(Control.PRESET_CENTER_TOP)
	messages.grow_horizontal = Control.GROW_DIRECTION_BOTH
	messages.position = Vector2(-400, 110)
	messages.custom_minimum_size = Vector2(800, 0)
	messages.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(messages)


func _radar() -> void:
	minimap = MinimapSc.new()
	minimap.world = world
	minimap.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	minimap.size = Vector2(250, 250)
	minimap.position = Vector2(-266, -266)
	minimap.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	minimap.grow_vertical = Control.GROW_DIRECTION_BEGIN
	minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(minimap)


func _help() -> void:
	help = PanelContainer.new()
	help.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	help.position = Vector2(16, -200)
	help.mouse_filter = Control.MOUSE_FILTER_IGNORE
	help.visible = false
	root.add_child(help)
	var v := VBoxContainer.new()
	help.add_child(v)
	v.add_child(UI.label("CONTROLS  (%s to hide)" % Controls.key_name("help"), 18, UI.ACCENT))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 18)
	v.add_child(grid)
	for action in ["thrust_fwd", "thrust_back", "turn_left", "turn_right", "strafe_left", "strafe_right", "climb", "descend", "fire_gun", "fire_rocket", "fire_atgm", "map", "pause"]:
		grid.add_child(UI.label(Controls.LABELS[action], 18, UI.DIM))
		grid.add_child(UI.label(Controls.all_names(action), 18))
	v.add_child(UI.label("Hover still at NAP height next to a vehicle to flip it.", 18, UI.ACCENT))
	v.add_child(UI.label("Fly over drums and crates to collect them.", 18, UI.ACCENT))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("help"):
		help.visible = not help.visible
		_help_auto = 0.0


func _process(delta: float) -> void:
	if world == null:
		return
	if _help_auto > 0.0:
		_help_auto -= delta
		if _help_auto <= 0.0:
			help.visible = false
	var armor: float = world.armor
	armor_bar.size.x = 200.0 * clampf(armor / Rules.ARMOR_MAX, 0.0, 1.0)
	armor_bar.color = Rules.GOOD if armor > 50.0 else (UI.ACCENT if armor > 25.0 else Rules.ALERT)
	armor_label.text = str(int(ceil(minf(armor, Rules.ARMOR_MAX))))
	var fuel: float = world.fuel
	fuel_bar.size.x = 200.0 * fuel / Rules.FUEL_MAX
	var low_fuel := fuel < 25.0
	fuel_bar.color = Rules.ALERT if low_fuel and int(world.time * 3.0) % 2 == 0 else UI.ACCENT
	fuel_label.text = str(int(ceil(fuel)))
	ammo_label.text = "GUN %d    RKT %d    MSL %d" % [world.ammo.get("gun", 0), world.ammo.get("rocket", 0), world.ammo.get("atgm", 0)]
	lives_label.text = "LIVES %d    SCORE %d" % [world.lives, world.stats()["score"]]
	var o: Dictionary = world.current_objective()
	if o.is_empty():
		objective_label.text = "All objectives complete"
		progress_label.text = ""
	else:
		var done := 0
		for x in world.objectives:
			if x["done"]:
				done += 1
		objective_label.text = "%s" % o["spec"]["label"]
		progress_label.text = "Objective %d of %d    %s" % [done + 1, world.objectives.size(), o["progress"]]
	for i in Rules.BANDS:
		var on: bool = world.hind.band == i
		band_boxes[i].add_theme_stylebox_override("panel", UI.plate(UI.ACCENT if on else Color(0.2, 0.16, 0.11), Color(0, 0, 0, 0), 0))
		band_labels[i].add_theme_color_override("font_color", Rules.INK if on else UI.DIM)
	var w: float = world.wash_strength()
	wash_bar.size.x = 190.0 * w
	wash_label.add_theme_color_override("font_color", Rules.PAPER if w > 0.0 else UI.DIM)
	crew_label.text = "CREW ABOARD %d/%d" % [world.aboard, Rules.CREW_CAPACITY] if world.crew.size() > 0 else "Hover still at NAP to use the wash"
	warn_label.visible = world.missile_warning and int(world.time * 6.0) % 2 == 0
	for m in messages.get_children():
		var left := float(m.get_meta("left")) - delta
		m.set_meta("left", left)
		if left <= 0.0:
			m.queue_free()
		elif left < 0.5:
			m.modulate.a = left / 0.5


func _on_message(text: String, tone: String) -> void:
	var col: Color = {"good": Color(0.78, 0.92, 0.5), "alert": Color(1.0, 0.55, 0.4)}.get(tone, Rules.PAPER)
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UI.plate(Color(Rules.INK, 0.7), Color(0, 0, 0, 0), 0, 12))
	box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var l := UI.label(text, 22, col)
	box.add_child(l)
	box.set_meta("left", 3.0)
	messages.add_child(box)
	while messages.get_child_count() > 4:
		var first := messages.get_child(0)
		messages.remove_child(first)
		first.queue_free()
