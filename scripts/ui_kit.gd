class_name UiKit
extends RefCounted
## Atalhos para montar a interface em código, com o mesmo estilo em todas as telas.

const GOLD := Color("ffd23f")

static var _theme: Theme


static func theme() -> Theme:
	if _theme == null:
		_theme = Theme.new()
		_theme.default_font_size = 22
	return _theme


static func label(text: String, size := 22, color := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.55))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func button(text: String, size := 22, color := Color("3a7d44")) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_stylebox_override("normal", box(color))
	b.add_theme_stylebox_override("hover", box(color.lightened(0.12)))
	b.add_theme_stylebox_override("pressed", box(color.darkened(0.2)))
	b.add_theme_stylebox_override("disabled", box(Color("4a4658")))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return b


static func box(color: Color, radius := 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s
