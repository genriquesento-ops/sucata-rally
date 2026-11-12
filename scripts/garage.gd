class_name Garage
extends Control
## Garagem: comprar melhorias, evoluir o carro, ver missões e começar uma corrida
## (normal, com mapa aleatório, ou o mapa do dia).

signal start_requested(daily: bool)

var _missions: Array[Dictionary] = []  # {text, reward, row}
var _daily: IconButton
var _coins: Label
var _coins_shown := -1
var _tier: Label
var _stage_dots: Array[Panel] = []
var _record: Label
var _rows: Array[Dictionary] = []  # {part, level, bar, button, card}
var _evolve: IconButton
var _evolve_hint: Label
var _showcase: CarShowcase
var _trophies: IconButton
var _run: IconButton
var _paints: Array[Button] = []

## Cor de destaque de cada peça (ícone, barra de nível).
const PART_COLORS := {"motor": Color("ff8a4c"), "tires": Color("9aa7bd"), "suspension": Color("ff7043"),
	"tank": Color("ff5d5d"), "magnet": Color("5cc8ff"), "nitro": Color("ffb02e")}
const GREEN := Color("2f9e55")


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiKit.theme()
	var bg := UiKit.gradient_bg(Color("2b2a5c"), Color("14121f"))
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 10)
	margin.add_child(page)
	page.add_child(_build_top())
	var cols := HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 22)
	page.add_child(cols)
	cols.add_child(_build_left())
	cols.add_child(_build_right())
	_refresh()
	_showcase.set_car(Save.tier, Save.paint)
	if Save.coins > 0 and Save.first_time("garage"):
		_show_tip()


## Barra de cima: nome do jogo, recorde, conquistas, opções e moedas.
func _build_top() -> Control:
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	var logo := UiKit.title("SUCATA RALLY", 30, UiKit.GOLD)
	logo.add_theme_constant_override("outline_size", 10)
	logo.add_theme_color_override("font_outline_color", Color("5a2d0c"))
	logo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(logo)

	var record := _pill()
	record.get_child(0).add_child(UiIcon.make("flag", 22))
	_record = UiKit.label("", 18)
	record.get_child(0).add_child(_record)
	top.add_child(record)
	_trophies = IconButton.make("trophy", "", 18, Color("4a3f7a"), 24)
	_trophies.pressed.connect(_open_achievements)
	top.add_child(_trophies)
	var options := IconButton.make("gear", "Opções", 18, Color("4a3f7a"), 22)
	options.pressed.connect(_open_settings)
	top.add_child(options)
	var coins := _pill(Color("3d3212"), Color("ffd23f66"))
	coins.get_child(0).add_child(UiIcon.make("coin", 28))
	_coins = UiKit.title("", 26, UiKit.GOLD)
	coins.get_child(0).add_child(_coins)
	top.add_child(coins)
	return top


## "Pílula": painel arredondado com uma fileira dentro (get_child(0)).
func _pill(color := Color("26243f"), border := UiKit.CARD_BORDER) -> PanelContainer:
	var pill := PanelContainer.new()
	var style := UiKit.card(color, 22, border, 16)
	style.shadow_size = 0
	pill.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	pill.add_child(row)
	return pill


func _build_left() -> Control:
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 0.92
	left.add_theme_constant_override("separation", 6)

	# palco: holofote atrás, carro girando, nome e estágio por cima
	var stage := Control.new()
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.custom_minimum_size.y = 170
	left.add_child(stage)
	var light := UiKit.glow(Color(0.55, 0.62, 1.0, 0.34))
	stage.add_child(light)
	light.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	light.offset_left = -40
	light.offset_right = 40
	_showcase = CarShowcase.new()
	_showcase.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(_showcase)
	_showcase.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 12)
	stage.add_child(name_row)
	name_row.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_tier = UiKit.title("", 32)
	_tier.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(_tier)
	var dots := HBoxContainer.new()
	dots.add_theme_constant_override("separation", 6)
	dots.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_row.add_child(dots)
	for i in GameData.TIERS.size():
		var dot := Panel.new()
		dot.custom_minimum_size = Vector2(26, 10)
		dots.add_child(dot)
		_stage_dots.append(dot)

	left.add_child(_paint_row())

	_evolve = IconButton.make("", "", 22, Color("8c3fd2"), 0.0, true)
	_evolve.base_min = Vector2(0, 50)
	_evolve.pressed.connect(func():
		Save.evolve()
		Sfx.play("mission")
		_refresh()
		_showcase.set_car(Save.tier, Save.paint))
	left.add_child(_evolve)
	_evolve_hint = UiKit.label("", 15, UiKit.DIM)
	_evolve_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(_evolve_hint)

	var missions := PanelContainer.new()
	missions.add_theme_stylebox_override("panel", UiKit.card())
	left.add_child(missions)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 4)
	missions.add_child(list)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	head.add_child(UiIcon.make("target", 18, UiKit.GOLD))
	head.add_child(UiKit.title("MISSÕES", 16, UiKit.GOLD))
	list.add_child(head)
	for i in Missions.ACTIVE:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var text := UiKit.label("", 16)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.clip_text = true
		row.add_child(text)
		var reward := UiKit.title("", 16, UiKit.GOLD)
		row.add_child(reward)
		row.add_child(UiIcon.make("coin", 18))
		list.add_child(row)
		_missions.append({"text": text, "reward": reward, "row": row})
	return left


func _build_right() -> Control:
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 10)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	right.add_child(grid)
	for part in GameData.PARTS:
		grid.add_child(_part_card(part))

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	right.add_child(buttons)
	_daily = IconButton.make("calendar", "", 17, Color("2a6fb0"), 30)
	_daily.base_min = Vector2(210, 70)
	_daily.pressed.connect(func():
		Sfx.play("click")
		start_requested.emit(true))
	buttons.add_child(_daily)
	_run = IconButton.make("flag", "CORRER!", 36, Color("e8622a"), 34, true)
	_run.base_min = Vector2(0, 70)
	_run.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_run.pressed.connect(func():
		Sfx.play("click")
		start_requested.emit(false))
	buttons.add_child(_run)
	return right


## Cartão de uma peça: ícone, nome, nível em segmentos e botão de melhorar.
func _part_card(part: Dictionary) -> Control:
	var accent: Color = PART_COLORS.get(part.id, Color("7cc04b"))
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", UiKit.card())
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	card.add_child(box)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	box.add_child(head)
	var badge := PanelContainer.new()
	var badge_style := UiKit.box(Color(accent.r, accent.g, accent.b, 0.16), 12)
	badge_style.set_content_margin_all(7)
	badge.add_theme_stylebox_override("panel", badge_style)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.add_child(UiIcon.make(part.id, 34))
	head.add_child(badge)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", -2)
	head.add_child(texts)
	texts.add_child(UiKit.title(part.title, 20))
	var desc := UiKit.label(part.desc, 13, UiKit.DIM)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.max_lines_visible = 2
	texts.add_child(desc)
	var level := UiKit.title("", 17, accent)
	level.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	head.add_child(level)

	var bar := LevelBar.new()
	bar.fill = accent
	box.add_child(bar)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	var button := IconButton.make("coin", "", 19, GREEN, 22, true)
	button.base_min = Vector2(0, 44)
	button.pressed.connect(func():
		Save.upgrade(part)
		Sfx.play("upgrade")
		_flash(card)
		_refresh())
	box.add_child(button)
	_rows.append({"part": part, "level": level, "bar": bar, "button": button, "card": card})
	return card


## Clarão rápido no cartão ao melhorar a peça.
func _flash(node: Control) -> void:
	node.modulate = Color(1.6, 1.6, 1.6)
	create_tween().tween_property(node, "modulate", Color.WHITE, 0.35)


func _refresh() -> void:
	var cap := GameData.level_cap(Save.tier)
	_set_coins(Save.coins)
	_tier.text = GameData.TIERS[Save.tier].title
	_record.text = "Recorde %d m" % Save.best
	for i in _stage_dots.size():
		var on := i <= Save.tier
		_stage_dots[i].add_theme_stylebox_override("panel",
			UiKit.box(UiKit.GOLD if on else Color(1, 1, 1, 0.16), 5))
		_stage_dots[i].tooltip_text = GameData.TIERS[i].title
	for row in _rows:
		var part: Dictionary = row.part
		var level: int = Save.levels[part.id]
		var maxed := level >= cap
		row.level.text = "%d/%d" % [level, cap]
		row.bar.max_value = cap
		row.bar.value = level
		row.button.set_label("MÁXIMO" if maxed else str(GameData.part_cost(part, level)))
		row.button.set_icon_visible(not maxed)
		row.button.disabled = not Save.can_upgrade(part)
		# no máximo: selo dourado em vez do cinza de "sem moedas"
		row.button.add_theme_stylebox_override("disabled", UiKit.card(Color("3d3212"), 12, Color("ffd23f66"))
			if maxed else UiKit.card(Color("3b3852"), 12, Color(1, 1, 1, 0.06)))
	_evolve.visible = Save.has_next_tier() and Save.parts_maxed()
	_evolve_hint.visible = Save.has_next_tier() and not Save.parts_maxed()
	_evolve_hint.text = "Leve todas as peças ao nível %d para evoluir o carro" % cap
	if Save.has_next_tier():
		var next: Dictionary = GameData.TIERS[Save.tier + 1]
		_evolve.set_label("EVOLUIR PARA %s  ·  %d moedas" % [next.title.to_upper(), next.cost])
		_evolve.disabled = not Save.can_evolve()
	for i in _missions.size():
		var m: Dictionary = Save.missions[i] if i < Save.missions.size() else {}
		_missions[i].row.visible = not m.is_empty()
		if not m.is_empty():
			_missions[i].text.text = Missions.text(m)
			_missions[i].reward.text = "+%d" % m.reward
	_style_paints()
	_daily.set_label("MAPA DO DIA\nhoje: %d m" % Save.daily_best_today())
	_trophies.set_label("%d/%d" % [Achievements.count_done(), Achievements.LIST.size()])


## Moedas com contagem animada quando o valor muda.
func _set_coins(value: int) -> void:
	if _coins_shown < 0 or not is_inside_tree():
		_coins_shown = value
		_coins.text = _thousands(value)
		return
	var tween := create_tween()
	tween.tween_method(func(v: float): _coins.text = _thousands(int(v)), float(_coins_shown), float(value), 0.3)
	_coins_shown = value


static func _thousands(n: int) -> String:
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = " " + s.right(3) + out
		s = s.left(s.length() - 3)
	return s + out


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		start_requested.emit(false)
	elif event.is_action_pressed("ui_cancel"):
		get_tree().quit()


## Fileira de bolinhas de cor para pintar o carro (a 1ª é a cor original do estágio).
func _paint_row() -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	for i in CarModel.PAINTS.size():
		var b := Button.new()
		b.custom_minimum_size = Vector2(38, 38)
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		b.tooltip_text = "Cor original" if i == 0 else ""
		b.pressed.connect(func():
			Save.paint = i
			Save.persist()
			Sfx.play("click")
			_showcase.set_car(Save.tier, Save.paint)
			_style_paints())
		row.add_child(b)
		_paints.append(b)
	_style_paints()
	return row


## Pinta as bolinhas; a cor em uso ganha um aro dourado.
func _style_paints() -> void:
	for i in _paints.size():
		var color: Color = CarModel.paint_color(Save.tier, i) if i == 0 else CarModel.PAINTS[i]
		var selected := i == Save.paint
		for state in ["normal", "hover", "pressed"]:
			var box := UiKit.box(color, 19)
			box.set_border_width_all(4 if selected else 2)
			box.border_color = UiKit.GOLD if selected else Color(1, 1, 1, 0.3)
			_paints[i].add_theme_stylebox_override(state, box)


func _open_settings() -> void:
	Sfx.play("click")
	var panel := SettingsPanel.new()
	panel.progress_reset.connect(func():
		_refresh()
		_showcase.set_car(Save.tier, Save.paint))
	add_child(panel)


func _open_achievements() -> void:
	Sfx.play("click")
	add_child(AchievementsPanel.new())


## Dica da primeira visita à garagem (depois da primeira corrida).
func _show_tip() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiKit.card(UiKit.CARD, 18, UiKit.CARD_BORDER, 22))
	dim.add_child(panel)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -360
	panel.offset_right = 360
	panel.offset_top = -130
	panel.offset_bottom = 110
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	box.add_child(UiKit.title("BEM-VINDO À GARAGEM", 28, UiKit.GOLD))
	var text := UiKit.label("• Gaste moedas para melhorar as peças: cada nível leva o carro mais longe.\n" \
		+ "• Complete as missões para ganhar moedas extras.\n" \
		+ "• Com todas as peças no máximo, EVOLUA o carro para um modelo novo.\n" \
		+ "• O Mapa do Dia é igual para todo mundo: tente bater seu recorde de hoje!", 19)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size.x = 680
	box.add_child(text)
	var ok := UiKit.button("Entendi", 24)
	ok.pressed.connect(func():
		Sfx.play("click")
		dim.queue_free())
	box.add_child(ok)
