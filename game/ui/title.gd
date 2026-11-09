extends Node
## Title: the first map drifts behind the logo. Main menu, mission select, options, credits.

const UI = preload("res://ui/ui_theme.gd")
const Rules = preload("res://core/rules.gd")
const Missions = preload("res://core/missions.gd")
const WorldSc = preload("res://world/world.gd")

var layer: CanvasLayer
var menu: VBoxContainer
var panel: Control


func _ready() -> void:
	var world = WorldSc.new()
	world.setup(0, true)
	add_child(world)
	layer = CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = UI.get_theme()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	var shade := ColorRect.new()
	shade.color = Color(Rules.INK, 0.45)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)
	var logo := VBoxContainer.new()
	logo.set_anchors_preset(Control.PRESET_CENTER_TOP)
	logo.grow_horizontal = Control.GROW_DIRECTION_BOTH
	logo.position.y = 90
	logo.add_theme_constant_override("separation", 18)
	root.add_child(logo)
	var t := UI.label("GUNSHIP ACE", 96, Rules.PAPER, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_constant_override("outline_size", 18)
	t.add_theme_color_override("font_outline_color", Rules.INK)
	logo.add_child(t)
	var sub := UI.label("Fly low. Flip jeeps. Bring the crews home.", 26, UI.ACCENT)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_constant_override("outline_size", 8)
	sub.add_theme_color_override("font_outline_color", Rules.INK)
	logo.add_child(sub)
	panel = Control.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(panel)
	var foot := UI.label("v%s   F11 fullscreen" % ProjectSettings.get_setting("application/config/version"), 16, UI.DIM)
	foot.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	foot.position = Vector2(16, -36)
	root.add_child(foot)
	_main_menu()


func _clear() -> void:
	for c in panel.get_children():
		c.queue_free()


func _box() -> VBoxContainer:
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_CENTER)
	v.grow_horizontal = Control.GROW_DIRECTION_BOTH
	v.grow_vertical = Control.GROW_DIRECTION_BOTH
	v.position.y = 80
	v.add_theme_constant_override("separation", 12)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(v)
	return v


func _main_menu() -> void:
	_clear()
	var v := _box()
	var first: Button
	if Settings.unlocked > 1:
		first = UI.button("Continue: Mission %d" % mini(Settings.unlocked, Missions.count()), func() -> void: Game.briefing(mini(Settings.unlocked, Missions.count()) - 1))
		v.add_child(first)
		v.add_child(UI.button("Mission select", _missions))
	else:
		first = UI.button("Start campaign", func() -> void: Game.briefing(0))
		v.add_child(first)
	v.add_child(UI.button("Options", _options))
	v.add_child(UI.button("Credits", _credits))
	if not OS.has_feature("web"):
		v.add_child(UI.button("Quit", Game.quit))
	first.grab_focus.call_deferred()


func _missions() -> void:
	_clear()
	var v := _box()
	var first: Button
	for i in Missions.count():
		var m: Dictionary = Missions.get_mission(i)
		var best := int(Settings.best.get(str(i), 0))
		var text := "%d. %s" % [i + 1, m["name"]]
		if best > 0:
			text += "   (best %d)" % best
		var idx := i
		var b := UI.button(text, func() -> void: Game.briefing(idx))
		b.custom_minimum_size.x = 520
		b.disabled = i + 1 > Settings.unlocked
		v.add_child(b)
		if first == null:
			first = b
	v.add_child(UI.button("Back", _main_menu))
	first.grab_focus.call_deferred()


func _options() -> void:
	_clear()
	var o = load("res://ui/options.gd").new()
	o.closed.connect(_main_menu)
	panel.add_child(o)


func _credits() -> void:
	_clear()
	var v := _box()
	var p := PanelContainer.new()
	v.add_child(p)
	var t := VBoxContainer.new()
	p.add_child(t)
	for line in [
		["GUNSHIP ACE", 30, UI.ACCENT],
		["Design and direction: William Hinds", 22, Rules.PAPER],
		["Code, sprites, sound and music made for this game.", 20, Rules.PAPER],
		["Painted sprite sources were generated with AI image tools,", 20, UI.DIM],
		["then keyed, scaled and cleaned for the game camera.", 20, UI.DIM],
		["Built with Godot Engine (MIT license, godotengine.org).", 20, UI.DIM],
		["Press Start 2P typeface by Cody Boisclair, SIL Open Font License 1.1.", 20, UI.DIM],
		["A love letter to the top-down helicopter games of the early 90s.", 20, UI.DIM],
	]:
		t.add_child(UI.label(line[0], line[1], line[2]))
	var back := UI.button("Back", _main_menu)
	v.add_child(back)
	back.grab_focus.call_deferred()
