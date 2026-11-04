class_name AchievementsPanel
extends Control
## Tela de conquistas (abre por cima da garagem): a lista de conquistas com progresso e,
## ao lado, as estatísticas de todas as corridas: distância, armadilhas e regiões.

signal closed

## Armadilhas: [chave em Save.totals, texto]
const TRAPS := [
	["t_serra", "Serras desviadas"],
	["t_martelo", "Martelos desviados"],
	["t_barril", "Barris desviados"],
	["t_oleo", "Escorregões no óleo"],
	["t_gelo", "Escorregões no gelo"],
	["t_lava", "Queimaduras na lava"],
]


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
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		panel.set("offset_" + side, 40 if side in ["left", "top"] else -40)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	var header := HBoxContainer.new()
	box.add_child(header)
	var title := UiKit.label("CONQUISTAS  %d/%d" % [Achievements.count_done(), Achievements.LIST.size()], 30, UiKit.GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close := UiKit.button("Fechar", 22)
	close.custom_minimum_size = Vector2(160, 48)
	close.pressed.connect(func():
		Sfx.play("click")
		closed.emit()
		queue_free())
	header.add_child(close)

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 20)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(cols)
	cols.add_child(_achievement_list())
	cols.add_child(_stats())


## Lista rolável de conquistas: nome, descrição, barra de progresso e prêmio (ou "feita").
func _achievement_list() -> Control:
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_stretch_ratio = 1.4
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	for a: Dictionary in Achievements.LIST:
		var finished := Achievements.done(a)
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", UiKit.box(Color("3d3a4c") if finished else Color("262330"), 10))
		list.add_child(row)
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 12)
		row.add_child(line)
		var texts := VBoxContainer.new()
		texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		texts.add_theme_constant_override("separation", 2)
		line.add_child(texts)
		texts.add_child(UiKit.label(a.title, 20, UiKit.GOLD if finished else Color.WHITE))
		var value := mini(Achievements.value(a), int(a.goal))
		texts.add_child(UiKit.label("%s   (%s / %s)" % [a.desc, _num(value), _num(a.goal)], 15, Color("c8c4d8")))
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.custom_minimum_size.y = 8
		bar.max_value = float(a.goal)
		bar.value = value
		bar.add_theme_stylebox_override("background", UiKit.box(Color("4a4658"), 4))
		bar.add_theme_stylebox_override("fill", UiKit.box(UiKit.GOLD if finished else Color("7cc04b"), 4))
		texts.add_child(bar)
		var prize := UiKit.label("FEITA!" if finished else "+%d" % a.reward, 20, Color("7cc04b") if finished else UiKit.GOLD)
		prize.custom_minimum_size.x = 110
		prize.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		prize.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		line.add_child(prize)
	return scroll


## Coluna de estatísticas: gerais, armadilhas e regiões.
func _stats() -> Control:
	var t := Save.totals
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 4)
	scroll.add_child(col)

	col.add_child(UiKit.label("ESTATÍSTICAS", 20, UiKit.GOLD))
	_stat(col, "Distância total", ("%.1f km" % (t.get("distance", 0) / 1000.0)).replace(".", ","))
	_stat(col, "Corridas", _num(t.get("runs", 0)))
	_stat(col, "Recorde", "%d m" % Save.best)
	_stat(col, "Moedas ganhas", _num(t.get("earned", 0)))
	_stat(col, "Saltos / pousos perfeitos", "%s / %s" % [_num(t.get("jumps", 0)), _num(t.get("perfect", 0))])
	_stat(col, "Raspando / boosts", "%s / %s" % [_num(t.get("near", 0)), _num(t.get("boosts", 0))])

	col.add_child(_gap())
	col.add_child(UiKit.label("ARMADILHAS", 20, UiKit.GOLD))
	for trap: Array in TRAPS:
		_stat(col, trap[1], _num(t.get(trap[0], 0)))
	_stat(col, "Pancadas levadas", _num(t.get("hits", 0)))

	col.add_child(_gap())
	col.add_child(UiKit.label("REGIÕES", 20, UiKit.GOLD))
	for i in GameData.BIOMES.size():
		var times: int = t.get("r_%d" % i, 0)
		var text := "ainda não chegou" if times == 0 else "chegou %s" % ("1 vez" if times == 1 else "%d vezes" % times)
		_stat(col, GameData.BIOMES[i].title, text, Color("8a8698") if times == 0 else Color.WHITE)
	return scroll


func _stat(col: VBoxContainer, label: String, value: String, color := Color.WHITE) -> void:
	var row := HBoxContainer.new()
	col.add_child(row)
	var l := UiKit.label(label, 17, Color("c8c4d8"))
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	row.add_child(UiKit.label(value, 17, color))


static func _gap() -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = 8
	return c


## Número com ponto de milhar (12.345).
static func _num(v: Variant) -> String:
	var s := str(int(v))
	var out := ""
	while s.length() > 3:
		out = "." + s.right(3) + out
		s = s.left(s.length() - 3)
	return s + out
