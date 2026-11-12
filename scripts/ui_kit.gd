class_name UiKit
extends RefCounted
## Atalhos para montar a interface em código, com o mesmo estilo em todas as telas.

const GOLD := Color("ffd23f")
const DIM := Color("a9a5c4")  # texto secundário
const CARD := Color("2a2742")  # fundo dos cartões
const CARD_BORDER := Color(1, 1, 1, 0.08)

static var _theme: Theme
static var _bold: FontVariation


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


## Cartão: fundo arredondado com borda fina e sombra suave.
static func card(color := CARD, radius := 16, border := CARD_BORDER, margin := 14) -> StyleBoxFlat:
	var s := box(color, radius)
	s.set_border_width_all(1)
	s.border_color = border
	s.shadow_color = Color(0, 0, 0, 0.28)
	s.shadow_size = 6
	s.shadow_offset = Vector2(0, 3)
	s.content_margin_left = margin
	s.content_margin_right = margin
	s.content_margin_top = margin - 4
	s.content_margin_bottom = margin - 4
	return s


## Fonte padrão engrossada, para títulos e números importantes.
static func bold_font() -> FontVariation:
	if _bold == null:
		_bold = FontVariation.new()
		_bold.base_font = ThemeDB.fallback_font
		_bold.variation_embolden = 0.8
	return _bold


## Texto em negrito (título).
static func title(text: String, size := 28, color := Color.WHITE) -> Label:
	var l := label(text, size, color)
	l.add_theme_font_override("font", bold_font())
	return l


## Degradê vertical que preenche o pai (fundo de tela).
static func gradient_bg(top: Color, bottom: Color) -> TextureRect:
	var gradient := Gradient.new()
	gradient.set_color(0, top)
	gradient.set_color(1, bottom)
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill_from = Vector2(0.5, 0.0)
	tex.fill_to = Vector2(0.5, 1.0)
	var rect := TextureRect.new()
	rect.texture = tex
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


## Brilho redondo (holofote) que some nas bordas.
static func glow(color: Color) -> TextureRect:
	var gradient := Gradient.new()
	gradient.set_color(0, color)
	gradient.set_color(1, Color(color.r, color.g, color.b, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	var rect := TextureRect.new()
	rect.texture = tex
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect
