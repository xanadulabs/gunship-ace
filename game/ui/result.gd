extends CanvasLayer
## Mission result: stats, then next, retry or title.

const UI = preload("res://ui/ui_theme.gd")
const Rules = preload("res://core/rules.gd")
const Missions = preload("res://core/missions.gd")

var stats: Dictionary = {}


func _ready() -> void:
	var won := bool(stats["won"])
	var idx := int(stats["mission"])
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
	v.add_theme_constant_override("separation", 10)
	root.add_child(v)
	var last := idx + 1 >= Missions.count()
	var head := "MISSION COMPLETE" if won else "MISSION FAILED"
	if won and last:
		head = "CAMPAIGN COMPLETE"
	var t := UI.label(head, 64, Rules.GOOD if won else Rules.ALERT, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var end_text := Rules.end_line(str(stats.get("end", "")))
	if end_text != "":
		var e := UI.label(end_text, 40, Rules.PAPER, true)
		e.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(e)
	var name_l := UI.label(str(stats["name"]), 28, UI.ACCENT)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(name_l)
	if not won and str(stats["reason"]) != "":
		var r := UI.label(str(stats["reason"]), 24)
		r.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(r)
	if won and last:
		var c := UI.label("The valley is quiet. Every crew came home. You are the Gunship Ace.", 24)
		c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(c)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 40)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(grid)
	for row in [["Time", Rules.time_text(float(stats["time"]))], ["Destroyed", str(stats["kills"])],
			["Flipped by the wash", str(stats["flips"])], ["Crew rescued", str(stats["crew"])],
			["Lives left", str(stats["lives"])], ["Score", str(stats["score"])]]:
		grid.add_child(UI.label(row[0], 24, UI.DIM))
		grid.add_child(UI.label(row[1], 24))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	h.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(h)
	var first: Button
	if won and not last:
		first = UI.button("Next mission", func() -> void: Game.briefing(idx + 1))
		h.add_child(first)
	var retry := UI.button("Fly it again" if won else "Retry", func() -> void: Game.play(idx))
	h.add_child(retry)
	h.add_child(UI.button("Title", Game.title))
	if first == null:
		first = retry
	var again := UI.label("Press Enter.", 24, UI.DIM)
	again.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(again)
	first.grab_focus.call_deferred()
	Sfx.music("music_title")


func _input(event: InputEvent) -> void:
	## Press Enter on an end plate starts the outing again.
	if event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER):
		get_viewport().set_input_as_handled()
		Game.play(int(stats["mission"]))
