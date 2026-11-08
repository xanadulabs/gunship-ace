extends Node
## A mission in play: the world, the HUD, and the pause and map overlays.

const UI = preload("res://ui/ui_theme.gd")
const Rules = preload("res://core/rules.gd")
const WorldSc = preload("res://world/world.gd")
const HudSc = preload("res://ui/hud.gd")
const MinimapSc = preload("res://ui/minimap.gd")

var index := 0
var world
var hud
var overlay: CanvasLayer
var overlay_root: Control
var mode := ""   # "", "pause", "map"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	world = WorldSc.new()
	world.setup(index)
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world)
	world.finished.connect(func(_won: bool, stats: Dictionary) -> void: Game.result(stats))
	hud = HudSc.new()
	hud.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(hud)
	hud.setup(world)
	overlay = CanvasLayer.new()
	overlay.layer = 20
	add_child(overlay)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and mode == "" and world != null and world.phase == "play":
		_open("pause")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		if mode == "":
			_open("pause")
		elif overlay_root != null and overlay_root.get_node_or_null("Options") == null:
			_close()
	elif event.is_action_pressed("map"):
		get_viewport().set_input_as_handled()
		if mode == "":
			_open("map")
		elif mode == "map":
			_close()
	elif mode != "" and event.is_action_pressed("ui_cancel"):
		if overlay_root != null and overlay_root.get_node_or_null("Options") == null:
			get_viewport().set_input_as_handled()
			_close()


func _open(which: String) -> void:
	if world.phase == "won" or world.phase == "lost":
		return
	mode = which
	get_tree().paused = true
	Sfx.rotor(false)
	overlay_root = Control.new()
	overlay_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay_root.theme = UI.get_theme()
	overlay.add_child(overlay_root)
	var shade := ColorRect.new()
	shade.color = Color(Rules.INK, 0.6)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay_root.add_child(shade)
	if which == "map":
		_map()
	else:
		_pause_menu()


func _close() -> void:
	mode = ""
	get_tree().paused = false
	if overlay_root != null:
		overlay_root.queue_free()
		overlay_root = null


func _pause_menu() -> void:
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_CENTER)
	v.grow_horizontal = Control.GROW_DIRECTION_BOTH
	v.grow_vertical = Control.GROW_DIRECTION_BOTH
	v.add_theme_constant_override("separation", 12)
	overlay_root.add_child(v)
	var t := UI.label("PAUSED", 56, Rules.PAPER, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var resume := UI.button("Resume", _close)
	v.add_child(resume)
	v.add_child(UI.button("Map and objectives", func() -> void:
		_close()
		_open("map")))
	v.add_child(UI.button("Restart mission", func() -> void: Game.play(index)))
	v.add_child(UI.button("Options", func() -> void:
		v.visible = false
		var o = load("res://ui/options.gd").new()
		o.name = "Options"
		o.closed.connect(func() -> void:
			v.visible = true
			resume.grab_focus())
		overlay_root.add_child(o)))
	v.add_child(UI.button("Quit to title", Game.title))
	resume.grab_focus.call_deferred()


func _map() -> void:
	var h := HBoxContainer.new()
	h.set_anchors_preset(Control.PRESET_CENTER)
	h.grow_horizontal = Control.GROW_DIRECTION_BOTH
	h.grow_vertical = Control.GROW_DIRECTION_BOTH
	h.add_theme_constant_override("separation", 24)
	overlay_root.add_child(h)
	var mm = MinimapSc.new()
	mm.world = world
	mm.show_all = true
	mm.custom_minimum_size = Vector2(720, 720)
	mm.process_mode = Node.PROCESS_MODE_ALWAYS
	h.add_child(mm)
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(560, 0)
	h.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	v.add_child(UI.label(str(world.mission["name"]).to_upper(), 36, Rules.PAPER, true))
	v.add_child(UI.label("Time %s" % Rules.time_text(world.time), 20, UI.DIM))
	for o in world.objectives:
		var mark := "[x]" if o["done"] else ("[!]" if o["failed"] else "[ ]")
		var col: Color = Rules.GOOD if o["done"] else (Rules.ALERT if o["failed"] else Rules.PAPER)
		var l := UI.label("%s  %s" % [mark, o["spec"]["label"]], 21, col)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(520, 0)
		v.add_child(l)
		if str(o["progress"]) != "" and not o["done"]:
			v.add_child(UI.label("      " + str(o["progress"]), 18, UI.ACCENT))
	v.add_child(HSeparator.new())
	for item in [["Target", Color(1.0, 0.85, 0.2)], ["Enemy", Color(0.92, 0.3, 0.2)], ["Crew to rescue", Color(1.0, 0.6, 0.15)],
			["Fuel", Color(0.9, 0.25, 0.2)], ["Ammo", Color(0.6, 0.75, 0.3)], ["Armor repair", Color(0.95, 0.95, 0.9)], ["H  Landing zone", Rules.PAPER]]:
		v.add_child(UI.label(str(item[0]), 18, item[1]))
	var back := UI.button("Back to the fight", _close, 22)
	v.add_child(back)
	back.grab_focus.call_deferred()
