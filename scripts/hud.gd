class_name Hud
extends CanvasLayer
## Informações da corrida e o controle de direção livre (SteerControl).

signal back_to_garage

var _distance: Label
var _best: Label
var _coins: Label
var _fuel: ProgressBar
var _toast: Label
var _toast_time := 0.0
var _end_panel: PanelContainer
var _end_title: Label
var _end_info: Label
var _steer: SteerControl
var _tip: PanelContainer  # dica da primeira vez
var _tip_label: Label
var _tip_time := 0.0
var _trick: Label  # aviso de manobra ("+12  SALTO 1,4 s  x2")
var _trick_time := 0.0
var _best_label := "Recorde"
var _fuel_warn: Label  # "TANQUE BAIXO", piscando, embaixo da barra
var _blink := 0.0
var _flash: ColorRect  # pisca a tela inteira (batida, óleo, desvio)
var _flash_tween: Tween


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiKit.theme()
	add_child(root)

	_distance = _place(root, UiKit.label("0 m", 46), Control.PRESET_TOP_LEFT, Rect2(24, 8, 300, 60)) as Label
	_best = _place(root, UiKit.label("", 20), Control.PRESET_TOP_LEFT, Rect2(26, 66, 300, 30)) as Label
	_coins = _place(root, UiKit.label("0", 40, UiKit.GOLD), Control.PRESET_TOP_RIGHT, Rect2(-300, 10, 276, 56)) as Label
	_coins.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	_fuel = ProgressBar.new()
	_fuel.show_percentage = false
	_fuel.max_value = 1.0
	_fuel.add_theme_stylebox_override("background", UiKit.box(Color(0, 0, 0, 0.45), 8))
	_fuel.add_theme_stylebox_override("fill", UiKit.box(Color("4caf50"), 8))
	_place(root, _fuel, Control.PRESET_CENTER_TOP, Rect2(-200, 22, 400, 30))
	var fuel_label := UiKit.label("COMBUSTÍVEL", 16)
	fuel_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(root, fuel_label, Control.PRESET_CENTER_TOP, Rect2(-200, 24, 400, 26))

	_fuel_warn = UiKit.label("", 22, Color("ff6a5a"))
	_fuel_warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(root, _fuel_warn, Control.PRESET_CENTER_TOP, Rect2(-300, 54, 600, 32))

	_toast = UiKit.label("", 56)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(root, _toast, Control.PRESET_CENTER_TOP, Rect2(-400, 140, 800, 80))
	_trick = UiKit.label("", 38, UiKit.GOLD)
	_trick.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(root, _trick, Control.PRESET_CENTER_TOP, Rect2(-400, 225, 800, 60))
	_trick.pivot_offset = Vector2(400, 30)

	_tip = PanelContainer.new()
	_tip.add_theme_stylebox_override("panel", UiKit.box(Color(0.1, 0.1, 0.16, 0.8), 12))
	_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(root, _tip, Control.PRESET_CENTER_TOP, Rect2(-380, 90, 760, 0))  # abaixo do aviso de tanque
	_tip_label = UiKit.label("", 22)
	_tip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip.add_child(_tip_label)
	_tip.visible = false

	_flash = ColorRect.new()
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.color = Color(1, 1, 1, 0)
	root.add_child(_flash)
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_steer = SteerControl.new()
	root.add_child(_steer)
	_steer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_build_end_panel(root)


func set_values(distance: float, best: int, coins: int, fuel_ratio: float) -> void:
	_distance.text = "%d m" % int(distance)
	_best.text = "%s: %d m" % [_best_label, best]
	_coins.text = str(coins)
	_fuel.value = fuel_ratio
	var fill := _fuel.get_theme_stylebox("fill") as StyleBoxFlat
	fill.bg_color = Color("d23c3c") if fuel_ratio < 0.25 else (UiKit.GOLD if fuel_ratio < 0.5 else Color("4caf50"))


func toast(text: String) -> void:
	_toast.text = text
	_toast_time = 2.5


## Dica da primeira vez, num painel no alto da tela por alguns segundos.
func tip(text: String) -> void:
	_tip_label.text = "DICA: " + text
	_tip.visible = true
	_tip_time = 5.0


func showing_tip() -> bool:
	return _tip.visible


## Modo mapa do dia: o recorde mostrado é o de hoje.
func set_daily() -> void:
	_best_label = "MAPA DO DIA · hoje"


## Aviso de manobra com "pulinho" de escala.
func trick(text: String, coins: int, combo: int) -> void:
	_trick.text = "+%d  %s%s" % [coins, text, "  x%d" % combo if combo > 1 else ""]
	_trick_time = 1.6
	_trick.scale = Vector2.ONE * 1.35
	create_tween().tween_property(_trick, "scale", Vector2.ONE, 0.2)


## Aviso de tanque baixo (texto vazio esconde).
func set_fuel_warning(text: String) -> void:
	_fuel_warn.text = text


## Pisca a tela com uma cor que some em `seconds`.
func flash(color: Color, seconds := 0.35) -> void:
	if _flash_tween != null:
		_flash_tween.kill()
	_flash.color = color
	_flash_tween = create_tween()
	_flash_tween.tween_property(_flash, "color:a", 0.0, seconds)


## lines: linhas extras (manobras, missões concluídas).
func show_end(reason: String, distance: int, record: bool, earned: int, lines: PackedStringArray) -> void:
	_steer.disable()
	_end_title.text = reason
	var text := "%d m%s\n+%d moedas" % [distance, "  —  NOVO RECORDE!" if record else "", earned]
	for line in lines:
		text += "\n" + line
	_end_info.text = text
	_end_panel.visible = true


func _process(delta: float) -> void:
	_blink += delta
	_fuel_warn.modulate.a = 0.45 + 0.55 * absf(sin(_blink * 5.0))
	_toast_time -= delta
	_toast.modulate.a = clampf(_toast_time, 0.0, 1.0)
	_trick_time -= delta
	_trick.modulate.a = clampf(_trick_time * 2.0, 0.0, 1.0)
	if _tip.visible:
		_tip_time -= delta
		_tip.modulate.a = clampf(_tip_time * 2.0, 0.0, 1.0)
		_tip.visible = _tip_time > 0.0


func _build_end_panel(root: Control) -> void:
	_end_panel = PanelContainer.new()
	_end_panel.add_theme_stylebox_override("panel", UiKit.box(Color(0, 0, 0, 0.7), 16))
	_place(root, _end_panel, Control.PRESET_CENTER, Rect2(-400, -250, 800, 500))
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	_end_panel.add_child(box)
	_end_title = UiKit.label("", 48)
	_end_info = UiKit.label("", 22)
	for l in [_end_title, _end_info]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(l)
	var back := UiKit.button("Voltar à garagem", 28, Color("d2652d"))
	back.pressed.connect(func(): back_to_garage.emit())
	box.add_child(back)
	_end_panel.visible = false


## Posiciona um controle por âncora + deslocamento (rect relativo à âncora).
static func _place(root: Control, c: Control, preset: Control.LayoutPreset, rect: Rect2) -> Control:
	root.add_child(c)
	c.set_anchors_preset(preset)
	c.offset_left = rect.position.x
	c.offset_top = rect.position.y
	c.offset_right = rect.position.x + rect.size.x
	c.offset_bottom = rect.position.y + rect.size.y
	return c
