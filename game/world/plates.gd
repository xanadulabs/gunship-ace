extends CanvasLayer

const Rules = preload("res://world/rules.gd")

var font: Font
var left: ColorRect
var right: ColorRect
var end_plate: ColorRect
var lines: Array[Label] = []
var status: Array[Label] = []
var end_title: Label
var end_again: Label


func setup() -> void:
	font = _font()
	left = _plate()
	right = _plate()
	end_plate = _plate()
	for i in Rules.LINES.size():
		lines.append(_label(left, 24))
	for i in 6:
		status.append(_label(right, 28))
	end_title = _label(end_plate, 48)
	end_again = _label(end_plate, 28)
	end_again.text = "Press Enter."


func place(view: Vector2) -> void:
	left.position = Vector2(16, 16)
	left.size = Vector2(470, 24 + Rules.LINES.size() * 44)
	right.position = Vector2(view.x - 486, 16)
	right.size = Vector2(470, 24 + 6 * 48)
	for i in lines.size():
		lines[i].position = Vector2(16, 12 + i * 44)
		lines[i].size = Vector2(438, 44)
		lines[i].text = Rules.LINES[i]
	for i in status.size():
		status[i].position = Vector2(16, 12 + i * 48)
		status[i].size = Vector2(438, 48)
	end_plate.size = Vector2(760, 180)
	end_plate.position = Vector2((view.x - 760.0) * 0.5, (view.y - 180.0) * 0.5)
	end_title.position = Vector2(24, 28)
	end_title.size = Vector2(712, 72)
	end_again.position = Vector2(24, 108)
	end_again.size = Vector2(712, 48)


func show_state(fuel_s: String, health_s: String, vehicles_s: String, height_s: String, wash_s: String, notice_s: String, end_s: String) -> void:
	status[0].text = fuel_s
	status[1].text = health_s
	status[2].text = vehicles_s
	status[3].text = height_s
	status[4].text = wash_s
	status[5].text = notice_s
	var ended := end_s != ""
	end_plate.visible = ended
	end_title.visible = ended
	end_again.visible = ended and end_s != "The Hind is landing."
	end_title.text = end_s


func _plate() -> ColorRect:
	var plate := ColorRect.new()
	plate.color = Rules.INK
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(plate)
	var edge := ReferenceRect.new()
	edge.border_color = Rules.PAPER
	edge.border_width = 4.0
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	edge.set_anchors_preset(Control.PRESET_FULL_RECT)
	plate.add_child(edge)
	return plate


func _label(parent: Node, size_px: int) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size_px)
	label.add_theme_color_override("font_color", Rules.PAPER)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	parent.add_child(label)
	return label


func _font() -> Font:
	var file := FontFile.new()
	file.load_dynamic_font("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf")
	return file
