class_name GameData
extends RefCounted
## Tabelas do jogo: peças, estágios do carro e regiões do mapa.
## Para balancear o jogo, quase tudo se ajusta aqui.

const PARTS := [
	{"id": "motor", "title": "Motor", "desc": "Mais força e velocidade", "base": 40},
	{"id": "tires", "title": "Pneus", "desc": "Mais aderência nas curvas e subidas", "base": 30},
	{"id": "suspension", "title": "Suspensão", "desc": "Absorve pulos e buracos", "base": 30},
	{"id": "tank", "title": "Tanque", "desc": "Mais combustível", "base": 35},
	{"id": "magnet", "title": "Ímã", "desc": "Puxa moedas de longe", "base": 25},
	{"id": "nitro", "title": "Nitro", "desc": "Boost mais forte; pouso perfeito dá mini-boost", "base": 45},
]

## size = largura (x), altura (y), comprimento (z) do chassi em metros.
const TIERS := [
	{"title": "Carrinho de Rolimã", "color": Color("c8873a"), "size": Vector3(1.4, 0.35, 2.2), "wheel": 0.36, "mass": 350.0, "cost": 0},
	{"title": "Buggy", "color": Color("e8c547"), "size": Vector3(1.7, 0.45, 2.6), "wheel": 0.45, "mass": 550.0, "cost": 600},
	{"title": "Picape", "color": Color("3f8fd2"), "size": Vector3(1.9, 0.6, 3.6), "wheel": 0.5, "mass": 1000.0, "cost": 3000},
	{"title": "Monstro", "color": Color("8c3fd2"), "size": Vector3(2.2, 0.7, 3.4), "wheel": 0.8, "mass": 1400.0, "cost": 10000},
	{"title": "Foguete", "color": Color("e04848"), "size": Vector3(1.8, 0.45, 3.8), "wheel": 0.55, "mass": 900.0, "cost": 30000},
]

## Cada região dura BIOME_LENGTH metros; depois o ciclo recomeça, mais difícil.
## ground = chão seco, ground2 = chão úmido (misturados pelo ruído de umidade), rock = encostas íngremes.
const BIOME_LENGTH := 700.0
const BIOME_BLEND := 60.0  # metros de transição suave no fim de cada região
const BIOMES := [
	{"title": "Campo", "ground": Color("7a9a40"), "ground2": Color("3f7a32"), "rock": Color("6b6656"), "road": Color("a08a5a"), "sky": Color("3f8fd8"), "horizon": Color("cfe8fa"), "grip": 1.0, "gravity": 9.8},
	{"title": "Deserto", "ground": Color("d0a462"), "ground2": Color("b88a50"), "rock": Color("9a5a3a"), "road": Color("96684a"), "sky": Color("4f9ad0"), "horizon": Color("f2d9a8"), "grip": 0.8, "gravity": 9.8},
	{"title": "Neve", "ground": Color("e8eef5"), "ground2": Color("c9dcef"), "rock": Color("5d6672"), "road": Color("8f9fb3"), "sky": Color("6f8fb8"), "horizon": Color("dfe9f5"), "grip": 0.5, "gravity": 9.8},
	{"title": "Vulcão", "ground": Color("3b2a2a"), "ground2": Color("5a3a30"), "rock": Color("1e1616"), "road": Color("6b4a3a"), "sky": Color("2a1414"), "horizon": Color("c0502a"), "grip": 0.9, "gravity": 9.8},
	{"title": "Lua", "ground": Color("8a8a95"), "ground2": Color("70707c"), "rock": Color("4a4a55"), "road": Color("5a5a65"), "sky": Color("05050f"), "horizon": Color("2d2d48"), "grip": 0.8, "gravity": 3.0},
]


static func level_cap(tier: int) -> int:
	return 5 * (tier + 1)


static func part_cost(part: Dictionary, level: int) -> int:
	return int(round(part.base * pow(1.38, level)))


static func biome_index(z: float) -> int:
	if z < 0.0:
		return 0
	return int(z / BIOME_LENGTH) % BIOMES.size()


## Cor de uma região na distância z, misturando suavemente perto da fronteira.
static func biome_color(z: float, key: String) -> Color:
	var i := biome_index(z)
	var c: Color = BIOMES[i][key]
	var w := biome_blend(z)
	if w > 0.0:
		var next: Color = BIOMES[(i + 1) % BIOMES.size()][key]
		c = c.lerp(next, w)
	return c


## Peso (0..1) da próxima região na distância z: só passa de 0 nos últimos BIOME_BLEND metros.
static func biome_blend(z: float) -> float:
	var into := fposmod(maxf(z, 0.0), BIOME_LENGTH)
	return smoothstep(BIOME_LENGTH - BIOME_BLEND, BIOME_LENGTH, into)


## Desempenho do carro a partir do estágio e dos níveis das peças.
static func stats(tier: int, levels: Dictionary) -> Dictionary:
	var t: Dictionary = TIERS[tier]
	var motor: int = levels.motor
	var tires: int = levels.tires
	var susp: int = levels.suspension
	return {
		"top_speed": 14.0 + 1.6 * motor + 3.0 * tier,  # m/s
		"engine_force": t.mass * (3.0 + 0.45 * motor),  # Newtons: aceleração ~3 m/s² no nível 0
		"friction": 2.2 + 0.35 * tires,
		"stiffness": 30.0 + 4.0 * susp,
		"travel": 0.25 + 0.02 * susp,
		"compression": 0.3 + 0.02 * susp,
		"relaxation": 0.5 + 0.02 * susp,
		"fuel": 35.0 + 6.0 * levels.tank + 5.0 * tier,  # segundos de corrida
		"magnet": 1.5 + 0.8 * levels.magnet,
		"boost_power": 1.0 + 0.12 * levels.get("nitro", 0),  # força e duração do boost
		"landing_boost": levels.get("nitro", 0) >= 1,  # pouso perfeito dá mini-boost
	}


## Data de hoje "AAAA-MM-DD" (define o mapa do dia).
static func today() -> String:
	return Time.get_date_string_from_system()


## Semente do mapa do dia: a mesma para todo mundo no mesmo dia.
static func daily_seed() -> int:
	return hash("sucata-rally-" + today())
