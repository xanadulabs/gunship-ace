extends CanvasLayer
## Mission briefing: the situation, the objectives, and the keys that matter.

const UI = preload("res://ui/ui_theme.gd")
const Rules = preload("res://core/rules.gd")
const Missions = preload("res://core/missions.gd")

var index := 0


func _ready() -> void:
	var m: Dictionary = Missions.get_mission(index)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = UI.get_theme()
	add_child(root)
	var bg := ColorRect.new()
	bg.color = Rules.INK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_CENTER)
	v.grow_horizontal = Control.GROW_DIRECTION_BOTH
	v.grow_vertical = Control.GROW_DIRECTION_BOTH
	v.custom_minimum_size = Vector2(1100, 0)
	v.add_theme_constant_override("separation", 8)
	root.add_child(v)
	v.add_child(UI.label(str(m["code"]), 24, UI.ACCENT))
	v.add_child(UI.label(str(m["name"]).to_upper(), 64, Rules.PAPER, true))
	v.add_child(HSeparator.new())
	for line in m["brief"]:
		v.add_child(UI.label(str(line), 23))
	v.add_child(HSeparator.new())
	v.add_child(UI.label("OBJECTIVES", 24, UI.ACCENT))
	var n := 1
	for o in m["objectives"]:
		v.add_child(UI.label("%d.  %s" % [n, o["label"]], 23))
		n += 1
	v.add_child(HSeparator.new())
	var keys := "%s / %s fly    %s / %s turn    %s climb    %s descend    %s gun    %s rockets    %s missile    %s map" % [
		Controls.key_name("thrust_fwd"), Controls.key_name("thrust_back"), Controls.key_name("turn_left"),
		Controls.key_name("turn_right"), Controls.key_name("climb"), Controls.key_name("descend"),
		Controls.key_name("fire_gun"), Controls.key_name("fire_rocket"), Controls.key_name("fire_atgm"), Controls.key_name("map")]
	v.add_child(UI.label(keys, 18, UI.DIM))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	v.add_child(h)
	var go := UI.button("Fly the mission", func() -> void: Game.play(index))
	h.add_child(go)
	h.add_child(UI.button("Back", Game.title))
	go.grab_focus.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		Game.title()
