class_name SettingsPanel
extends Control
## Tela de configurações (abre por cima da garagem). Tudo é salvo na hora.

signal closed
signal progress_reset

var _reset: Button
var _reset_armed := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiKit.theme()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiKit.box(Color("2e2b3a"), 16))
	add_child(panel)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -330
	panel.offset_right = 330
	panel.offset_top = -300
	panel.offset_bottom = 300
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)

	var title := UiKit.label("OPÇÕES", 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	_slider(box, "Sensibilidade da direção", "steer", 0.6, 1.6)
	_slider(box, "Música", "music", 0.0, 1.0)
	_slider(box, "Efeitos sonoros", "sfx", 0.0, 1.0)

	var vibration := CheckButton.new()
	vibration.text = "Vibração"
	vibration.add_theme_font_size_override("font_size", 22)
	vibration.button_pressed = Save.settings.vibration
	vibration.toggled.connect(func(on: bool): _save_setting("vibration", on))
	box.add_child(vibration)

	box.add_child(UiKit.label("Qualidade gráfica", 20, Color("c8c4d8")))
	var quality := HBoxContainer.new()
	quality.add_theme_constant_override("separation", 10)
	box.add_child(quality)
	var group := ButtonGroup.new()
	for q in [[1, "Alta"], [0, "Baixa (celular fraco)"]]:
		var b := Button.new()
		b.text = q[1]
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = Save.settings.quality == q[0]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 20)
		b.pressed.connect(func(): _save_setting("quality", q[0]))
		quality.add_child(b)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	_reset = UiKit.button("Zerar progresso", 20, Color("8a2d2d"))
	_reset.pressed.connect(_on_reset)
	box.add_child(_reset)
	var close := UiKit.button("Fechar", 26)
	close.custom_minimum_size.y = 56
	close.pressed.connect(func():
		Sfx.play("click")
		closed.emit()
		queue_free())
	box.add_child(close)


func _slider(box: VBoxContainer, text: String, key: String, lo: float, hi: float) -> void:
	box.add_child(UiKit.label(text, 20, Color("c8c4d8")))
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 0.05
	s.value = Save.settings[key]
	s.custom_minimum_size.y = 32
	s.value_changed.connect(func(v: float): _save_setting(key, v))
	box.add_child(s)


func _save_setting(key: String, value: Variant) -> void:
	Save.settings[key] = value
	Save.persist()
	Sfx.apply_volumes()


## Zerar pede dois toques (o primeiro só arma), para não apagar sem querer.
func _on_reset() -> void:
	if not _reset_armed:
		_reset_armed = true
		_reset.text = "Toque de novo para APAGAR tudo"
		return
	Save.reset_progress()
	Sfx.play("crash")
	progress_reset.emit()
	closed.emit()
	queue_free()
