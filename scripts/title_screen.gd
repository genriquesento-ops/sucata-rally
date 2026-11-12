class_name TitleScreen
extends Control
## Tela inicial: logo, o seu carro girando e "toque para começar".

signal start

var _hint: Label
var _time := 0.0
var _started := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiKit.theme()
	var bg := TextureRect.new()
	var gradient := Gradient.new()
	gradient.set_color(0, Color("3f8fd8"))
	gradient.set_color(1, Color("211f29"))
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill_from = Vector2(0.5, 0.0)
	tex.fill_to = Vector2(0.5, 1.0)
	bg.texture = tex
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 6)
	add_child(box)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_top = 30
	box.offset_bottom = -30

	var logo := UiKit.label("SUCATA RALLY", 88, UiKit.GOLD)
	logo.add_theme_constant_override("outline_size", 18)
	logo.add_theme_color_override("font_outline_color", Color("5a2d0c"))
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(logo)
	var sub := UiKit.label("corrida infinita · monte, melhore e evolua o seu carro", 22)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)

	var showcase := CarShowcase.new()
	showcase.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(showcase)
	showcase.set_car(Save.tier, Save.paint)

	_hint = UiKit.label("Toque para começar", 34)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_hint)
	var version := UiKit.label("versão %s %s · software livre" % [Platform.flavor,
		ProjectSettings.get_setting("application/config/version", "")], 14, Color("c8c4d8"))
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(version)


func _process(delta: float) -> void:
	_time += delta
	_hint.modulate.a = 0.55 + 0.45 * sin(_time * 4.0)


## Em _input (e não _unhandled_input) para nenhum controle da tela — como o visor 3D do
## carro — engolir o toque antes de chegar aqui.
func _input(event: InputEvent) -> void:
	var pressed: bool = (event is InputEventScreenTouch and event.pressed) \
		or (event is InputEventMouseButton and event.pressed) \
		or event.is_action_pressed("ui_accept")
	if pressed and not _started:
		_started = true  # toque e clique emulado chegam juntos: só vale um
		get_viewport().set_input_as_handled()
		Sfx.play("click")
		start.emit.call_deferred()  # troca de tela fora do tratamento do evento
	elif event.is_action_pressed("ui_cancel"):
		get_tree().quit()
