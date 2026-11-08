extends RefCounted
## One theme for every screen: ink plates, paper text, hard edges, Lato.

const Rules = preload("res://core/rules.gd")

const BOLD := preload("res://ui/fonts/Lato-Bold.ttf")
const BLACK := preload("res://ui/fonts/Lato-Black.ttf")
const ACCENT := Color(0.86, 0.6, 0.2)
const DIM := Color(0.62, 0.56, 0.46)

static var _theme: Theme


static func get_theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font = BOLD
	t.default_font_size = 24
	t.set_color("font_color", "Label", Rules.PAPER)
	for kind in ["Button", "CheckButton", "OptionButton"]:
		t.set_stylebox("normal", kind, plate(Rules.INK, DIM, 2))
		t.set_stylebox("hover", kind, plate(Color(0.2, 0.16, 0.11), ACCENT, 2))
		t.set_stylebox("pressed", kind, plate(Color(0.3, 0.22, 0.12), ACCENT, 3))
		t.set_stylebox("focus", kind, plate(Color(0, 0, 0, 0), ACCENT, 3))
		t.set_stylebox("disabled", kind, plate(Color(0.1, 0.08, 0.06), Color(0.3, 0.27, 0.22), 2))
		t.set_color("font_color", kind, Rules.PAPER)
		t.set_color("font_hover_color", kind, Color(1, 0.92, 0.7))
		t.set_color("font_focus_color", kind, Color(1, 0.92, 0.7))
		t.set_color("font_pressed_color", kind, Color(1, 0.92, 0.7))
		t.set_color("font_disabled_color", kind, Color(0.45, 0.4, 0.33))
	t.set_stylebox("panel", "Panel", plate(Color(Rules.INK, 0.94), Rules.PAPER, 3))
	t.set_stylebox("panel", "PanelContainer", plate(Color(Rules.INK, 0.94), Rules.PAPER, 3))
	t.set_stylebox("slider", "HSlider", plate(Color(0.3, 0.25, 0.18), Color(0, 0, 0, 0), 0, 6))
	t.set_stylebox("grabber_area", "HSlider", plate(ACCENT, Color(0, 0, 0, 0), 0, 6))
	t.set_stylebox("grabber_area_highlight", "HSlider", plate(Color(1, 0.8, 0.4), Color(0, 0, 0, 0), 0, 6))
	t.set_stylebox("focus", "HSlider", plate(Color(0, 0, 0, 0), ACCENT, 2))
	t.set_stylebox("panel", "PopupMenu", plate(Rules.INK, DIM, 2))
	t.set_color("font_color", "PopupMenu", Rules.PAPER)
	t.set_stylebox("scroll", "VScrollBar", plate(Color(0.2, 0.16, 0.11), Color(0, 0, 0, 0), 0))
	t.set_stylebox("grabber", "VScrollBar", plate(DIM, Color(0, 0, 0, 0), 0))
	_theme = t
	return t


static func plate(fill: Color, edge: Color, width: int, pad := 14) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = edge
	s.set_border_width_all(width)
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad * 0.5
	s.content_margin_bottom = pad * 0.5
	return s


static func label(text: String, size := 24, color := Rules.PAPER, heavy := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if heavy:
		l.add_theme_font_override("font", BLACK)
	return l


static func button(text: String, callback: Callable, size := 26) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.custom_minimum_size = Vector2(360, 54)
	b.pressed.connect(func() -> void:
		Sfx.play("click", -6.0)
		callback.call())
	return b
