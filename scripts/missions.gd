class_name Missions
extends RefCounted
## Missões: sempre 3 ativas, de tipos diferentes. Cada uma é cumprida dentro de uma única
## corrida. Ao completar, paga moedas e é trocada por outra; a cada missão concluída o
## "nível de missão" sobe e as metas e recompensas crescem.

const ACTIVE := 3
const TYPES := ["distance", "coins", "jumps", "perfect", "near", "boosts", "region", "dodges", "hammers"]

## Recorde mínimo para a missão aparecer (as armadilhas só existem depois de certa distância).
const NEEDS_BEST := {"dodges": 600, "hammers": 900}


## Garante 3 missões ativas no save.
static func ensure() -> void:
	while Save.missions.size() < ACTIVE:
		Save.missions.append(_new_mission())
	Save.persist()


static func text(m: Dictionary) -> String:
	var goal: int = m.goal
	match m.type:
		"distance": return "Chegue a %d m numa corrida" % goal
		"coins": return "Junte %d moedas numa corrida" % goal
		"jumps": return "Dê %s numa corrida" % _count(goal, "salto", "saltos")
		"perfect": return "Faça %s numa corrida" % _count(goal, "pouso perfeito", "pousos perfeitos")
		"near": return "Passe raspando por %s numa corrida" % _count(goal, "pedra", "pedras")
		"boosts": return "Use %s numa corrida" % _count(goal, "placa de boost", "placas de boost")
		"region": return "Chegue à região %s" % GameData.BIOMES[goal].title
		"dodges": return "Desvie de %s numa corrida" % _count(goal, "armadilha", "armadilhas")
		"hammers": return "Passe por %s sem levar martelada" % _count(goal, "martelo", "martelos")
	return "?"


static func _count(n: int, one: String, many: String) -> String:
	return "%d %s" % [n, one if n == 1 else many]


## Confere as missões com os números da corrida; paga as concluídas e troca por novas.
## stats: {"distance", "coins", "jumps", "perfect", "near", "boosts", "dodges", "hammers"}.
## Devolve [{text, reward}].
static func complete_from_run(stats: Dictionary) -> Array:
	var done := []
	for i in Save.missions.size():
		var m: Dictionary = Save.missions[i]
		if _value(m, stats) >= int(m.goal):
			done.append({"text": text(m), "reward": int(m.reward)})
			Save.coins += int(m.reward)
			Save.mission_level += 1
			Save.missions[i] = {}
	Save.missions = Save.missions.filter(func(m): return not m.is_empty())
	ensure()
	return done


static func _value(m: Dictionary, stats: Dictionary) -> int:
	match m.type:
		"region": return int(stats.distance / GameData.BIOME_LENGTH)
		_: return int(stats.get(m.type, 0))


static func _new_mission() -> Dictionary:
	var used := Save.missions.map(func(m): return m.type)
	var options := TYPES.filter(func(t): return not used.has(t) and Save.best >= NEEDS_BEST.get(t, 0))
	var type: String = options[randi() % options.size()]
	var lv: int = Save.mission_level
	var goal := 0
	match type:
		"distance": goal = 300 + 150 * lv
		"coins": goal = 40 + 25 * lv
		"jumps": goal = 2 + lv / 2
		"perfect": goal = 1 + lv / 3
		"near": goal = 1 + lv / 3
		"boosts": goal = 2 + lv / 3
		"region": goal = mini(1 + lv / 2, GameData.BIOMES.size() - 1)
		"dodges": goal = 2 + lv / 3
		"hammers": goal = 1 + lv / 4
	return {"type": type, "goal": goal, "reward": 60 + 40 * lv}
