class_name IconButton
extends Button
## Botão com ícone desenhado (UiIcon) + texto, centralizados, e uma "afundadinha" ao tocar.
## Uso: IconButton.make("coin", "Melhorar 40", 20, Color("3a7d44"))

var _row: HBoxContainer
var _icon: UiIcon
var _label: Label
var _pad := Vector2(18, 10)
## Tamanho mínimo pedido por quem usa o botão (o conteúdo pode aumentar).
var base_min := Vector2.ZERO:
	set(v):
		base_min = v
		_fit()


static func make(icon_kind: String, label_text: String, font_size := 20, color := Color("3a7d44"),
		icon_px := 0.0, bold := false) -> IconButton:
	var b := IconButton.new()
	b._setup(icon_kind, label_text, font_size, color, icon_px if icon_px > 0.0 else font_size * 1.15, bold)
	return b


func _setup(icon_kind: String, label_text: String, font_size: int, color: Color, icon_px: float, bold: bool) -> void:
	set_color(color)
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_row = HBoxContainer.new()
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_theme_constant_override("separation", 8)
	add_child(_row)
	if not icon_kind.is_empty():
		_icon = UiIcon.make(icon_kind, icon_px)
		_row.add_child(_icon)
	_label = UiKit.label(label_text, font_size)
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if bold:
		_label.add_theme_font_override("font", UiKit.bold_font())
	_label.visible = not label_text.is_empty()
	_row.add_child(_label)
	resized.connect(_layout)
	button_down.connect(func(): _press(0.95))
	button_up.connect(func(): _press(1.0))
	_fit()
	_layout()


## Cor de fundo (muda também os estados de toque e desligado).
func set_color(color: Color) -> void:
	add_theme_stylebox_override("normal", UiKit.card(color, 12, color.lightened(0.25)))
	add_theme_stylebox_override("hover", UiKit.card(color.lightened(0.08), 12, color.lightened(0.3)))
	add_theme_stylebox_override("pressed", UiKit.card(color.darkened(0.18), 12, color.lightened(0.1)))
	add_theme_stylebox_override("disabled", UiKit.card(Color("3b3852"), 12, Color(1, 1, 1, 0.06)))


func set_label(label_text: String) -> void:
	_label.text = label_text
	_label.visible = not label_text.is_empty()
	_fit()
	_layout()


func set_icon_visible(on: bool) -> void:
	if _icon != null:
		_icon.visible = on
		_fit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAW and _row != null:
		_row.modulate.a = 0.45 if disabled else 1.0


## Ajusta o tamanho mínimo ao conteúdo (ícone + texto + folga).
func _fit() -> void:
	if _row == null:
		return
	var need := _row.get_combined_minimum_size() + _pad * 2.0
	custom_minimum_size = Vector2(maxf(base_min.x, need.x), maxf(base_min.y, need.y))


func _layout() -> void:
	if _row != null:
		_row.position = Vector2.ZERO
		_row.size = size


func _press(to: float) -> void:
	if disabled:
		return
	pivot_offset = size / 2.0
	create_tween().tween_property(self, "scale", Vector2(to, to), 0.07)
