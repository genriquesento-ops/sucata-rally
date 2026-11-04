class_name Track
extends RefCounted
## Sequência de trechos da trilha (40 m cada): reta, lombadas, salto, rampa, pedras, boost.
## Gerada com Wave Function Collapse em 1D: cada trecho começa com todos os tipos possíveis
## (o "domínio"); ao escolher um tipo, as regras de vizinhança cortam as opções do próximo
## trecho (propagação). Antes de escolher, só valem tipos que deixam o próximo trecho com
## alguma opção, então nunca aparece uma sequência impossível (ex.: boost sem salto depois).
## A sequência inteira é gerada na largada (é barato) e depois só é lida, inclusive por threads.

const SEGMENT := 40.0
const COUNT := 500  # 20 km; depois disso a sequência se repete

enum { RETA, LOMBADAS, SALTO, RAMPA, PEDRAS, BOOST }

## Quem pode vir logo depois de quem.
const NEXT := {
	RETA: [RETA, LOMBADAS, SALTO, RAMPA, PEDRAS, BOOST],
	LOMBADAS: [RETA, PEDRAS, BOOST],
	SALTO: [RETA],  # pouso tranquilo depois do salto
	RAMPA: [RETA, LOMBADAS],
	PEDRAS: [RETA, LOMBADAS, BOOST],
	BOOST: [SALTO, RAMPA],  # o boost sempre leva a um salto ou rampa
}

## Posição (metros dentro do trecho) dos elementos de cada tipo.
const BOOST_AT := 20.0
const RAMP_AT := 16.0

var _kinds := PackedInt32Array()


func _init(seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 99
	var all := NEXT.keys()
	var domains: Array = []
	for i in COUNT:
		domains.append(all.duplicate())
	for i in 3:  # largada: três retas
		domains[i] = [RETA]

	_kinds.resize(COUNT)
	for i in COUNT:
		var options: Array = domains[i]
		if i + 1 < COUNT:
			var next_domain: Array = domains[i + 1]
			options = options.filter(func(k): return NEXT[k].any(func(n): return next_domain.has(n)))
		if options.is_empty():
			options = [RETA]  # contradição: volta para o tipo mais neutro
		var kind := _weighted_pick(options, i * SEGMENT, rng)
		_kinds[i] = kind
		if i + 1 < COUNT:
			domains[i + 1] = domains[i + 1].filter(func(k): return NEXT[kind].has(k))


## Peso de cada tipo; obstáculos e saltos ficam mais comuns com a distância.
static func _weight(kind: int, z: float) -> float:
	var d := Terrain.difficulty(z)
	match kind:
		RETA: return 3.0 - 1.5 * d
		LOMBADAS: return 1.0
		SALTO: return 0.6 + 1.2 * d
		RAMPA: return 0.8
		PEDRAS: return 0.4 + 1.6 * d
		BOOST: return 0.7
	return 1.0


static func _weighted_pick(options: Array, z: float, rng: RandomNumberGenerator) -> int:
	var total := 0.0
	for k in options:
		total += _weight(k, z)
	var roll := rng.randf() * total
	for k in options:
		roll -= _weight(k, z)
		if roll <= 0.0:
			return k
	return options[-1]


func index_at(z: float) -> int:
	return posmod(floori(z / SEGMENT), COUNT) if z >= 0.0 else -1


func kind_at(z: float) -> int:
	var i := index_at(z)
	return RETA if i < 0 else _kinds[i]


func kind_of(index: int) -> int:
	return RETA if index < 0 else _kinds[index % COUNT]


## Altura extra da trilha em z (lombadas e salto). Só depende de z.
func height_offset(z: float) -> float:
	var t := fposmod(z, SEGMENT)
	match kind_at(z):
		LOMBADAS:
			if t > 5.0 and t < 35.0:
				return 0.25 * (1.0 - cos((t - 5.0) / 6.0 * TAU))
		SALTO:
			# estilo motocross: subida curva que lança para cima, borda, vale, e um morro de
			# pouso com descida. A 14 m/s o carro voa ~15 m e pousa na descida sem perder
			# velocidade; quem pula curto cai no vale e precisa subir.
			if t < 4.0:
				return 0.0
			if t < 14.0:
				return 2.4 * pow((t - 4.0) / 10.0, 2.0)
			if t < 16.0:
				return lerpf(2.4, -1.5, (t - 14.0) / 2.0)
			if t < 22.0:
				return -1.5
			if t < 26.0:
				return lerpf(-1.5, 1.8, smoothstep(22.0, 26.0, t))
			return 1.8 * (1.0 - smoothstep(26.0, 40.0, t))
	return 0.0
