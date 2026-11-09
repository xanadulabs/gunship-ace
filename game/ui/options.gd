extends PanelContainer
## Options: volumes, display, control scheme and key rebinding. Emits closed.

signal closed

const UI = preload("res://ui/ui_theme.gd")
const Rules = preload("res://core/rules.gd")

var _capture := ""
var _rows: Dictionary = {}
var _first: Control


func _ready() -> void:
	theme = UI.get_theme()
	add_theme_stylebox_override("panel", UI.plate(Rules.INK, Rules.PAPER, 3, 18))
	process_mode = Node.PROCESS_MODE_ALWAYS
	custom_minimum_size = Vector2(900, 760)
	size = custom_minimum_size
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_KEEP_SIZE)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	add_child(v)
	v.add_child(UI.label("OPTIONS", 36, UI.ACCENT, true))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(860, 580)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	_first = _slider(list, "Master volume", Settings.master, func(x: float) -> void: Settings.master = x)
	_slider(list, "Music", Settings.music, func(x: float) -> void: Settings.music = x)
	_slider(list, "Sound effects", Settings.sfx, func(x: float) -> void: Settings.sfx = x)
	if not OS.has_feature("web"):
		_check(list, "Fullscreen (F11)", Settings.fullscreen, func(on: bool) -> void:
			Settings.fullscreen = on
			Settings.apply_window())
	_check(list, "Screen shake", Settings.shake, func(on: bool) -> void: Settings.shake = on)
	list.add_child(UI.label("CONTROLS", 26, UI.ACCENT, true))
	var scheme := OptionButton.new()
	scheme.add_item("Original: A/D slide, Q/E turn")
	scheme.add_item("Alternate: A/D turn, Q/E slide")
	scheme.select(1 if Settings.scheme == "classic" else 0)
	scheme.add_theme_font_size_override("font_size", 16)
	scheme.item_selected.connect(func(i: int) -> void:
		Controls.set_scheme("classic" if i == 1 else "original")
		_refresh_keys())
	list.add_child(scheme)
	list.add_child(_wrap(UI.label("Click a key to change it, then press the new key or mouse button. Esc cancels.", 18, UI.DIM)))
	for action in Controls.ACTIONS:
		if action == "pause":
			continue
		var row := HBoxContainer.new()
		var name_label := UI.label(Controls.LABELS[action], 20)
		name_label.custom_minimum_size = Vector2(260, 0)
		row.add_child(name_label)
		var b := Button.new()
		b.custom_minimum_size = Vector2(500, 40)
		b.add_theme_font_size_override("font_size", 16)
		b.pressed.connect(func() -> void:
			_capture = action
			b.text = "Press a key..."
			Sfx.play("click", -6.0))
		row.add_child(b)
		list.add_child(row)
		_rows[action] = b
	list.add_child(_wrap(UI.label("Gamepad: left stick moves, right stick turns, RB/LB up and down, A or RT gun, X or LT rockets, Y missile.", 18, UI.DIM)))
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 16)
	v.add_child(buttons)
	var reset := UI.button("Reset keys", func() -> void:
		Controls.reset_bindings()
		_refresh_keys(), 22)
	reset.custom_minimum_size = Vector2(240, 50)
	buttons.add_child(reset)
	var back := UI.button("Back", _close, 22)
	back.custom_minimum_size = Vector2(240, 50)
	buttons.add_child(back)
	_refresh_keys()
	_first.grab_focus.call_deferred()


func _wrap(l: Label) -> Label:
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 820
	return l


func _slider(parent: Control, text: String, value: float, set_value: Callable) -> Control:
	var row := HBoxContainer.new()
	var l := UI.label(text, 20)
	l.custom_minimum_size = Vector2(260, 0)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = value
	s.custom_minimum_size = Vector2(500, 32)
	s.value_changed.connect(func(x: float) -> void:
		set_value.call(x)
		Sfx.apply_volumes())
	row.add_child(s)
	parent.add_child(row)
	return s


func _check(parent: Control, text: String, value: bool, set_value: Callable) -> void:
	var c := CheckButton.new()
	c.text = text
	c.button_pressed = value
	c.add_theme_font_size_override("font_size", 16)
	c.toggled.connect(func(on: bool) -> void: set_value.call(on))
	parent.add_child(c)


func _refresh_keys() -> void:
	for action in _rows.keys():
		_rows[action].text = Controls.all_names(action)


func _input(event: InputEvent) -> void:
	if _capture == "":
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode != KEY_ESCAPE:
			Controls.rebind(_capture, event)
		_capture = ""
		_refresh_keys()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		Controls.rebind(_capture, event)
		_capture = ""
		_refresh_keys()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if _capture == "" and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()


func _close() -> void:
	Settings.save_settings()
	closed.emit()
	queue_free()
