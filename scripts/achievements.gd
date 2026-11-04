class_name Achievements
extends RefCounted
## Conquistas permanentes: metas sobre os números somados de todas as corridas (Save.totals).
## Cada uma paga moedas uma vez só, no fim da corrida em que foi alcançada.
##
## Save.totals guarda somas ("distance", "jumps", "t_serra"...) e alguns máximos ("best",
## "region"). "t_<tipo>" conta armadilhas por tipo; "r_<n>" conta corridas que chegaram à região n.

const LIST := [
	{"id": "km1", "title": "Primeiros passos", "desc": "Rode 1 km no total", "stat": "distance", "goal": 1000, "reward": 50},
	{"id": "km10", "title": "Estradeiro", "desc": "Rode 10 km no total", "stat": "distance", "goal": 10000, "reward": 200},
	{"id": "km50", "title": "Maratonista", "desc": "Rode 50 km no total", "stat": "distance", "goal": 50000, "reward": 800},
	{"id": "far", "title": "Longe de casa", "desc": "Chegue a 2000 m numa corrida", "stat": "best", "goal": 2000, "reward": 300},
	{"id": "moon", "title": "Turista espacial", "desc": "Chegue à Lua", "stat": "region", "goal": 4, "reward": 500},
	{"id": "runs", "title": "Viciado em sucata", "desc": "Faça 50 corridas", "stat": "runs", "goal": 50, "reward": 250},
	{"id": "jumps", "title": "Voador", "desc": "Dê 100 saltos", "stat": "jumps", "goal": 100, "reward": 200},
	{"id": "perfect", "title": "Equilibrista", "desc": "Faça 25 pousos perfeitos", "stat": "perfect", "goal": 25, "reward": 200},
	{"id": "near", "title": "Por um fio", "desc": "Passe raspando por 30 pedras", "stat": "near", "goal": 30, "reward": 150},
	{"id": "boosts", "title": "Nitro!", "desc": "Use 50 placas de boost", "stat": "boosts", "goal": 50, "reward": 150},
	{"id": "dodges", "title": "Liso como sabão", "desc": "Desvie de 50 armadilhas", "stat": "dodges", "goal": 50, "reward": 300},
	{"id": "hammers", "title": "Martelo? Que martelo?", "desc": "Passe por 20 martelos sem levar martelada", "stat": "hammers", "goal": 20, "reward": 300},
	{"id": "earned", "title": "Ferro-velho rico", "desc": "Ganhe 5000 moedas no total", "stat": "earned", "goal": 5000, "reward": 400},
]

## Números que guardam o maior valor (e não a soma).
const MAX_STATS := ["best", "region"]


static func value(a: Dictionary) -> int:
	return int(Save.totals.get(a.stat, 0))


static func done(a: Dictionary) -> bool:
	return Save.achievements_done.has(a.id)


static func count_done() -> int:
	return Save.achievements_done.size()


## Soma os números de uma corrida em Save.totals e paga as conquistas novas.
## Devolve [{text, reward}] das que foram concluídas agora.
static func record_run(stats: Dictionary) -> Array:
	for key: String in stats:
		var v: Variant = stats[key]
		if not (v is int or v is float):
			continue
		if MAX_STATS.has(key):
			Save.totals[key] = maxi(int(Save.totals.get(key, 0)), int(v))
		else:
			Save.totals[key] = int(Save.totals.get(key, 0)) + int(v)
	var out := []
	for a: Dictionary in LIST:
		if not done(a) and value(a) >= int(a.goal):
			Save.achievements_done.append(a.id)
			Save.coins += int(a.reward)
			out.append({"text": a.title, "reward": int(a.reward)})
	return out
