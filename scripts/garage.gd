class_name Garage
extends Control
## Garagem: comprar melhorias, evoluir o carro, ver missões e começar uma corrida
## (normal, com mapa aleatório, ou o mapa do dia).

signal start_requested(daily: bool)

var _missions: Array[Label] = []
var _daily: Button
var _coins: Label
var _tier: Label
var _info: Label
var _rows: Array[Dictionary] = []  # {part, title, bar, button}
var _evolve: Button
var _evolve_hint: Label
var _showcase: CarShowcase
var _trophies: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiKit.theme()
	var bg := ColorRect.new()
	bg.color = Color("211f29")
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 24)
	margin.add_child(cols)

	cols.add_child(_build_left())
	cols.add_child(_build_right())
	_refresh()
	_showcase.set_car(Save.tier, Save.paint)
	if Save.coins > 0 and Save.first_time("garage"):
		_show_tip()


func _build_left() -> Control:
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 4)
	var header := HBoxContainer.new()
	left.add_child(header)
	var title := UiKit.label("SUCATA RALLY", 34)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_trophies = UiKit.button("", 18, Color("8a6a1a"))
	_trophies.pressed.connect(_open_achievements)
	header.add_child(_trophies)
	var options := UiKit.button("Opções", 18, Color("4a4658"))
	options.pressed.connect(_open_settings)
	header.add_child(options)
	_tier = UiKit.label("", 24)
	left.add_child(_tier)
	_info = UiKit.label("", 16, Color("c8c4d8"))
	left.add_child(_info)

	var frame := PanelContainer.new()
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.add_theme_stylebox_override("panel", UiKit.box(Color("2e2b3a"), 14))
	left.add_child(frame)
	var stack := VBoxContainer.new()
	frame.add_child(stack)
	_showcase = CarShowcase.new()
	_showcase.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(_showcase)
	stack.add_child(_paint_row())

	_evolve = UiKit.button("", 22, Color("8c3fd2"))
	_evolve.custom_minimum_size.y = 50
	_evolve.pressed.connect(func():
		Save.evolve()
		Sfx.play("mission")
		_refresh()
		_showcase.set_car(Save.tier, Save.paint))
	left.add_child(_evolve)
	_evolve_hint = UiKit.label("", 16, Color("c8c4d8"))
	_evolve_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(_evolve_hint)

	var missions := PanelContainer.new()
	missions.add_theme_stylebox_override("panel", UiKit.box(Color("2e2b3a"), 12))
	left.add_child(missions)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 2)
	missions.add_child(list)
	list.add_child(UiKit.label("MISSÕES", 18, UiKit.GOLD))
	for i in Missions.ACTIVE:
		var l := UiKit.label("", 16)
		list.add_child(l)
		_missions.append(l)
	return left


func _build_right() -> Control:
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 6)
	_coins = UiKit.label("", 28, UiKit.GOLD)
	_coins.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(_coins)

	for part in GameData.PARTS:
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", UiKit.box(Color("2e2b3a"), 12))
		right.add_child(panel)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		panel.add_child(row)
		var texts := VBoxContainer.new()
		texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		texts.add_theme_constant_override("separation", 2)
		row.add_child(texts)
		var title := UiKit.label("", 21)
		texts.add_child(title)
		texts.add_child(UiKit.label(part.desc, 14, Color("c8c4d8")))
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.custom_minimum_size.y = 10
		bar.add_theme_stylebox_override("background", UiKit.box(Color("4a4658"), 4))
		bar.add_theme_stylebox_override("fill", UiKit.box(Color("7cc04b"), 4))
		texts.add_child(bar)
		var button := UiKit.button("", 20)
		button.custom_minimum_size = Vector2(200, 0)
		button.pressed.connect(func():
			Save.upgrade(part)
			Sfx.play("upgrade")
			_refresh())
		row.add_child(button)
		_rows.append({"part": part, "title": title, "bar": bar, "button": button})

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(spacer)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	right.add_child(buttons)
	_daily = UiKit.button("", 20, Color("2f7fb8"))
	_daily.custom_minimum_size = Vector2(220, 64)
	_daily.pressed.connect(func():
		Sfx.play("click")
		start_requested.emit(true))
	buttons.add_child(_daily)
	var run := UiKit.button("CORRER!", 36, Color("d2652d"))
	run.custom_minimum_size.y = 64
	run.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	run.pressed.connect(func():
		Sfx.play("click")
		start_requested.emit(false))
	buttons.add_child(run)
	var version := UiKit.label("versão " + Platform.flavor, 14, Color("8a8698"))
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(version)
	return right


func _refresh() -> void:
	var cap := GameData.level_cap(Save.tier)
	_coins.text = "%d moedas" % Save.coins
	_tier.text = GameData.TIERS[Save.tier].title
	_info.text = "Estágio %d de %d   |   Recorde: %d m" % [Save.tier + 1, GameData.TIERS.size(), Save.best]
	for row in _rows:
		var part: Dictionary = row.part
		var level: int = Save.levels[part.id]
		row.title.text = "%s   %d/%d" % [part.title, level, cap]
		row.bar.max_value = cap
		row.bar.value = level
		row.button.text = "MÁXIMO" if level >= cap else "Melhorar  %d" % GameData.part_cost(part, level)
		row.button.disabled = not Save.can_upgrade(part)
	_evolve.visible = Save.has_next_tier() and Save.parts_maxed()
	_evolve_hint.visible = Save.has_next_tier() and not Save.parts_maxed()
	_evolve_hint.text = "Leve todas as peças ao nível %d para evoluir" % cap
	if Save.has_next_tier():
		var next: Dictionary = GameData.TIERS[Save.tier + 1]
		_evolve.text = "EVOLUIR: %s  (%d)" % [next.title, next.cost]
		_evolve.disabled = not Save.can_evolve()
	for i in _missions.size():
		var m: Dictionary = Save.missions[i] if i < Save.missions.size() else {}
		_missions[i].text = "" if m.is_empty() else "• %s   +%d" % [Missions.text(m), m.reward]
	_daily.text = "MAPA DO DIA\nhoje: %d m" % Save.daily_best_today()
	_trophies.text = "Conquistas %d/%d" % [Achievements.count_done(), Achievements.LIST.size()]


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		start_requested.emit(false)
	elif event.is_action_pressed("ui_cancel"):
		get_tree().quit()


## Fileira de bolinhas de cor para pintar o carro (a 1ª é a cor original do estágio).
func _paint_row() -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	for i in CarModel.PAINTS.size():
		var b := Button.new()
		b.custom_minimum_size = Vector2(34, 34)
		var color: Color = CarModel.paint_color(Save.tier, i) if i == 0 else CarModel.PAINTS[i]
		for state in ["normal", "hover", "pressed"]:
			var box := UiKit.box(color, 17)
			# borda clara em todas, para a cor escura não sumir no fundo
			box.set_border_width_all(3 if state != "normal" else 2)
			box.border_color = Color.WHITE if state != "normal" else Color(1, 1, 1, 0.3)
			b.add_theme_stylebox_override(state, box)
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		b.tooltip_text = "Cor original" if i == 0 else ""
		b.pressed.connect(func():
			Save.paint = i
			Save.persist()
			Sfx.play("click")
			_showcase.set_car(Save.tier, Save.paint))
		row.add_child(b)
	return row


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
	panel.add_theme_stylebox_override("panel", UiKit.box(Color("2e2b3a"), 16))
	dim.add_child(panel)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -360
	panel.offset_right = 360
	panel.offset_top = -130
	panel.offset_bottom = 110
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	box.add_child(UiKit.label("BEM-VINDO À GARAGEM", 28, UiKit.GOLD))
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
