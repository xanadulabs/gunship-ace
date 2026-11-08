extends Node
## Input actions, the two control schemes, gamepad defaults and key rebinding.
## Letter keys use physical keycodes so the layout is the same on AZERTY and QWERTZ.

const ACTIONS: Array[String] = [
	"thrust_fwd", "thrust_back", "turn_left", "turn_right", "strafe_left", "strafe_right",
	"climb", "descend", "fire_gun", "fire_rocket", "fire_atgm", "pause", "map", "help",
]

const LABELS := {
	"thrust_fwd": "Forward",
	"thrust_back": "Back",
	"turn_left": "Turn left",
	"turn_right": "Turn right",
	"strafe_left": "Slide left",
	"strafe_right": "Slide right",
	"climb": "Climb",
	"descend": "Descend",
	"fire_gun": "Chin gun",
	"fire_rocket": "Rockets",
	"fire_atgm": "Missile",
	"pause": "Pause",
	"map": "Map",
	"help": "Controls card",
}

# Keyboard and mouse defaults. "k:" is a physical key, "m:" a mouse button.
const CLASSIC := {
	"thrust_fwd": ["k:W", "k:Up"],
	"thrust_back": ["k:S", "k:Down"],
	"turn_left": ["k:A", "k:Left"],
	"turn_right": ["k:D", "k:Right"],
	"strafe_left": ["k:Q"],
	"strafe_right": ["k:E"],
	"climb": ["k:R", "k:PageUp"],
	"descend": ["k:F", "k:PageDown"],
	"fire_gun": ["k:Space", "k:J", "m:1"],
	"fire_rocket": ["k:K", "m:2"],
	"fire_atgm": ["k:L", "m:3"],
	"pause": ["k:Escape", "k:P"],
	"map": ["k:Tab", "k:M"],
	"help": ["k:F1"],
}
const MODERN_SWAP := {
	"turn_left": ["k:Q", "k:Left"],
	"turn_right": ["k:E", "k:Right"],
	"strafe_left": ["k:A"],
	"strafe_right": ["k:D"],
}

var _last_device := "keyboard"


func _ready() -> void:
	apply()


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.4):
		_last_device = "pad"
	elif event is InputEventKey or event is InputEventMouseButton:
		_last_device = "keyboard"


func using_pad() -> bool:
	return _last_device == "pad"


func apply() -> void:
	var scheme: String = Settings.scheme
	for action in ACTIONS:
		if InputMap.has_action(action):
			InputMap.erase_action(action)
		InputMap.add_action(action, 0.25)
		var specs: Array = defaults_for(action, scheme)
		if Settings.bindings.has(action):
			specs = Settings.bindings[action]
		for spec in specs:
			var ev := _event_from(str(spec))
			if ev != null:
				InputMap.action_add_event(action, ev)
		for ev in _pad_events(action, scheme):
			InputMap.action_add_event(action, ev)


func defaults_for(action: String, scheme: String) -> Array:
	if scheme == "modern" and MODERN_SWAP.has(action):
		return MODERN_SWAP[action]
	return CLASSIC[action]


func set_scheme(scheme: String) -> void:
	Settings.scheme = scheme
	# A scheme change resets the keys it moves, so a stale override cannot hide it.
	for action in MODERN_SWAP.keys():
		Settings.bindings.erase(action)
	Settings.save_settings()
	apply()


func rebind(action: String, event: InputEvent) -> void:
	var spec := _spec_from(event)
	if spec == "":
		return
	# Free the key from any other action first.
	for other in ACTIONS:
		if other == action:
			continue
		var specs: Array = Settings.bindings.get(other, defaults_for(other, Settings.scheme)).duplicate()
		if specs.has(spec):
			specs.erase(spec)
			Settings.bindings[other] = specs
	var mine: Array = Settings.bindings.get(action, defaults_for(action, Settings.scheme)).duplicate()
	mine.erase(spec)
	mine.push_front(spec)
	while mine.size() > 2:
		mine.pop_back()
	Settings.bindings[action] = mine
	Settings.save_settings()
	apply()


func reset_bindings() -> void:
	Settings.bindings = {}
	Settings.save_settings()
	apply()


func key_name(action: String) -> String:
	## The name of the first keyboard or mouse binding, for prompts.
	if using_pad():
		return _pad_name(action)
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			var code: Key = ev.physical_keycode
			if code == KEY_NONE:
				code = ev.keycode
			else:
				code = DisplayServer.keyboard_get_keycode_from_physical(code)
			return OS.get_keycode_string(code)
		if ev is InputEventMouseButton:
			return ["", "Left click", "Right click", "Middle click"][clampi(ev.button_index, 0, 3)]
	return "-"


func all_names(action: String) -> String:
	var parts: Array[String] = []
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			var code: Key = ev.physical_keycode
			code = DisplayServer.keyboard_get_keycode_from_physical(code) if code != KEY_NONE else ev.keycode
			parts.append(OS.get_keycode_string(code))
		elif ev is InputEventMouseButton:
			parts.append(["", "Left click", "Right click", "Middle click"][clampi(ev.button_index, 0, 3)])
	return " / ".join(parts)


func _pad_name(action: String) -> String:
	match action:
		"fire_gun":
			return "A / RT"
		"fire_rocket":
			return "X / LT"
		"fire_atgm":
			return "Y"
		"climb":
			return "RB"
		"descend":
			return "LB"
		"pause":
			return "Start"
		"map":
			return "Back"
		"help":
			return "-"
	return "Stick"


func _event_from(spec: String) -> InputEvent:
	if spec.begins_with("k:"):
		var code := OS.find_keycode_from_string(spec.substr(2))
		if code == KEY_NONE:
			return null
		var key := InputEventKey.new()
		key.physical_keycode = code
		return key
	if spec.begins_with("m:"):
		var mouse := InputEventMouseButton.new()
		mouse.button_index = int(spec.substr(2)) as MouseButton
		return mouse
	return null


func _spec_from(event: InputEvent) -> String:
	if event is InputEventKey:
		var code: Key = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
		return "k:" + OS.get_keycode_string(code)
	if event is InputEventMouseButton and event.button_index <= 3:
		return "m:%d" % event.button_index
	return ""


func _axis(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = value
	return ev


func _button(button: JoyButton) -> InputEventJoypadButton:
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	return ev


func _pad_events(action: String, scheme: String) -> Array:
	var turn_axis := JOY_AXIS_LEFT_X if scheme == "classic" else JOY_AXIS_RIGHT_X
	var strafe_axis := JOY_AXIS_RIGHT_X if scheme == "classic" else JOY_AXIS_LEFT_X
	match action:
		"thrust_fwd":
			return [_axis(JOY_AXIS_LEFT_Y, -1.0), _button(JOY_BUTTON_DPAD_UP)]
		"thrust_back":
			return [_axis(JOY_AXIS_LEFT_Y, 1.0), _button(JOY_BUTTON_DPAD_DOWN)]
		"turn_left":
			return [_axis(turn_axis, -1.0), _button(JOY_BUTTON_DPAD_LEFT)]
		"turn_right":
			return [_axis(turn_axis, 1.0), _button(JOY_BUTTON_DPAD_RIGHT)]
		"strafe_left":
			return [_axis(strafe_axis, -1.0)]
		"strafe_right":
			return [_axis(strafe_axis, 1.0)]
		"climb":
			return [_button(JOY_BUTTON_RIGHT_SHOULDER)]
		"descend":
			return [_button(JOY_BUTTON_LEFT_SHOULDER)]
		"fire_gun":
			return [_button(JOY_BUTTON_A), _axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)]
		"fire_rocket":
			return [_button(JOY_BUTTON_X), _axis(JOY_AXIS_TRIGGER_LEFT, 1.0)]
		"fire_atgm":
			return [_button(JOY_BUTTON_Y)]
		"pause":
			return [_button(JOY_BUTTON_START)]
		"map":
			return [_button(JOY_BUTTON_BACK)]
	return []
