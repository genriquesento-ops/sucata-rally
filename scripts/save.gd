extends Node
## Progresso do jogador, salvo só no aparelho (user://save.cfg).

var coins := 0
var best := 0
var tier := 0
var levels := {}
var missions: Array = []  # [{type, goal, reward}] (ver missions.gd)
var mission_level := 0
var daily_date := ""  # "AAAA-MM-DD" do mapa do dia
var daily_best := 0  # recorde no mapa do dia de daily_date
var paint := 0  # índice em CarModel.PAINTS (0 = cor original do estágio)
var tips_seen: Array = []  # dicas da primeira vez já mostradas
const DEFAULT_SETTINGS := {"steer": 1.0, "music": 0.6, "sfx": 0.8, "vibration": true, "quality": 1}
var settings := DEFAULT_SETTINGS.duplicate()  # quality: 1 = alta, 0 = baixa

var _path := "user://save.cfg"


func _ready() -> void:
	# o modo demo usa um save separado e zerado, para não mexer no progresso real
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--demo"):
			_path = "user://demo_save.cfg"
			DirAccess.remove_absolute(ProjectSettings.globalize_path(_path))
	var cfg := ConfigFile.new()
	cfg.load(_path)
	coins = cfg.get_value("progress", "coins", 0)
	best = cfg.get_value("progress", "best", 0)
	tier = cfg.get_value("progress", "tier", 0)
	for part in GameData.PARTS:
		levels[part.id] = cfg.get_value("levels", part.id, 0)
	missions = cfg.get_value("missions", "active", [])
	mission_level = cfg.get_value("missions", "level", 0)
	daily_date = cfg.get_value("daily", "date", "")
	daily_best = cfg.get_value("daily", "best", 0)
	paint = cfg.get_value("progress", "paint", 0)
	tips_seen = cfg.get_value("tips", "seen", [])
	for key in DEFAULT_SETTINGS:
		settings[key] = cfg.get_value("settings", key, DEFAULT_SETTINGS[key])
	Missions.ensure()


func persist() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "coins", coins)
	cfg.set_value("progress", "best", best)
	cfg.set_value("progress", "tier", tier)
	for id in levels:
		cfg.set_value("levels", id, levels[id])
	cfg.set_value("missions", "active", missions)
	cfg.set_value("missions", "level", mission_level)
	cfg.set_value("daily", "date", daily_date)
	cfg.set_value("daily", "best", daily_best)
	cfg.set_value("progress", "paint", paint)
	cfg.set_value("tips", "seen", tips_seen)
	for key in settings:
		cfg.set_value("settings", key, settings[key])
	cfg.save(_path)


## Dica da primeira vez: devolve true só na primeira chamada para cada id.
func first_time(tip: String) -> bool:
	if tips_seen.has(tip):
		return false
	tips_seen.append(tip)
	persist()
	return true


## Zera o progresso (moedas, peças, estágio, recordes, missões, dicas); mantém as configurações.
func reset_progress() -> void:
	coins = 0
	best = 0
	tier = 0
	paint = 0
	for id in levels:
		levels[id] = 0
	missions = []
	mission_level = 0
	daily_date = ""
	daily_best = 0
	tips_seen = []
	Missions.ensure()


## Recorde de hoje no mapa do dia (0 se ainda não correu hoje).
func daily_best_today() -> int:
	return daily_best if daily_date == GameData.today() else 0


func record_daily(distance: int) -> bool:
	if daily_date != GameData.today():
		daily_date = GameData.today()
		daily_best = 0
	if distance > daily_best:
		daily_best = distance
		return true
	return false


func can_upgrade(part: Dictionary) -> bool:
	var level: int = levels[part.id]
	return level < GameData.level_cap(tier) and coins >= GameData.part_cost(part, level)


func upgrade(part: Dictionary) -> void:
	if not can_upgrade(part):
		return
	coins -= GameData.part_cost(part, levels[part.id])
	levels[part.id] += 1
	persist()


func parts_maxed() -> bool:
	for id in levels:
		if levels[id] < GameData.level_cap(tier):
			return false
	return true


func has_next_tier() -> bool:
	return tier + 1 < GameData.TIERS.size()


func can_evolve() -> bool:
	return has_next_tier() and parts_maxed() and coins >= GameData.TIERS[tier + 1].cost


func evolve() -> void:
	if not can_evolve():
		return
	coins -= GameData.TIERS[tier + 1].cost
	tier += 1
	persist()
