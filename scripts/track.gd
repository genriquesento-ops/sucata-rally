class_name Track
extends RefCounted
## Sequência de trechos da trilha (40 m cada). Os tipos de trecho (reta, salto, pedras, óleo...)
## vêm do arquivo data/trechos.json: perfil de altura, objetos, moedas, regras de vizinhança.
## Para criar um trecho novo basta editar o arquivo (veja docs/trechos.md).
##
## A ordem é gerada com Wave Function Collapse em 1D: cada trecho começa com todos os tipos
## possíveis (o "domínio"); ao escolher um tipo, as regras "depois" cortam as opções do próximo
## trecho (propagação). Antes de escolher, só valem tipos que deixam o próximo trecho com
## alguma opção, então nunca aparece uma sequência impossível (ex.: boost sem salto depois).
## A sequência inteira é gerada na largada (é barato) e depois só é lida, inclusive por threads.

const SEGMENT := 40.0
const COUNT := 500  # 20 km; depois disso a sequência se repete
const DATA_PATH := "res://data/trechos.json"

## Trechos do arquivo (lidos uma vez só). Cada um é o Dictionary do JSON, com dois campos
## calculados: "_depois" (índices) e "_n" (o próprio índice).
static var defs: Array[Dictionary] = []
static var _ids := {}  # id -> índice em defs
static var _start := 0  # tipo da largada

var _kinds := PackedInt32Array()
var _seed := 0


func _init(seed_value: int) -> void:
	load_defs()
	_seed = seed_value
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 99
	var all := range(defs.size())
	var domains: Array = []
	for i in COUNT:
		domains.append(all.duplicate())
	for i in 3:  # largada: três trechos do tipo "largada"
		domains[i] = [_start]

	_kinds.resize(COUNT)
	for i in COUNT:
		var options: Array = domains[i]
		if i + 1 < COUNT:
			var next_domain: Array = domains[i + 1]
			options = options.filter(func(k): return defs[k]._depois.any(func(n): return next_domain.has(n)))
		if options.is_empty():
			options = [_start]  # contradição: volta para o tipo mais neutro
		var kind := _weighted_pick(options, i * SEGMENT, rng)
		_kinds[i] = kind
		if i + 1 < COUNT:
			domains[i + 1] = domains[i + 1].filter(func(k): return defs[kind]._depois.has(k))


## Lê data/trechos.json e confere se está tudo certo (ids, regras, tipos de objeto).
static func load_defs() -> void:
	if not defs.is_empty():
		return
	var text := FileAccess.get_file_as_string(DATA_PATH)
	var data: Variant = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		push_error("trechos.json inválido")
		return
	for d: Dictionary in data.trechos:
		_ids[d.id] = defs.size()
		d["_n"] = defs.size()
		defs.append(d)
	for d in defs:
		var next := []
		for id: String in d.get("depois", []):
			if _ids.has(id):
				next.append(_ids[id])
			else:
				push_error("trechos.json: '%s' tem em 'depois' um id que não existe: %s" % [d.id, id])
		d["_depois"] = next
		for spec: Dictionary in d.get("objetos", []):
			if not ObstacleFactory.exists(spec.tipo):
				push_error("trechos.json: '%s' usa um tipo de objeto que não existe: %s" % [d.id, spec.tipo])
	_start = _ids.get(data.get("largada", ""), 0)


## Peso no sorteio: base + extra × dificuldade (os obstáculos ficam mais comuns com a
## distância). Antes de "desde" metros o trecho não aparece.
static func _weight(kind: int, z: float) -> float:
	var d: Dictionary = defs[kind]
	if z < float(d.get("desde", 0.0)):
		return 0.0
	if d.has("regioes") and not d.regioes.has(GameData.BIOMES[GameData.biome_index(z)].title):
		return 0.0
	var w: Array = d.get("peso", [1.0, 0.0])
	return maxf(0.0, w[0] + w[1] * Terrain.difficulty(z))


static func _weighted_pick(options: Array, z: float, rng: RandomNumberGenerator) -> int:
	var total := 0.0
	for k in options:
		total += _weight(k, z)
	if total <= 0.0:
		return _start if options.has(_start) else options[0]
	var roll := rng.randf() * total
	for k in options:
		roll -= _weight(k, z)
		if roll <= 0.0 and _weight(k, z) > 0.0:
			return k
	return options[-1]


func index_at(z: float) -> int:
	return posmod(floori(z / SEGMENT), COUNT) if z >= 0.0 else -1


func kind_at(z: float) -> int:
	var i := index_at(z)
	return _start if i < 0 else _kinds[i]


func kind_of(index: int) -> int:
	return _start if index < 0 else _kinds[index % COUNT]


func segment_at(z: float) -> Dictionary:
	return defs[kind_at(z)]


func segment_of(index: int) -> Dictionary:
	return defs[kind_of(index)]


## Altura extra da trilha em z (lombadas, salto...). Só depende de z.
## "onda": lombadas em cosseno; "pontos": [[metro, altura, curva]], com a curva de cada
## pedaço sendo "linear" (padrão), "suave" (smoothstep) ou "acelera" (começa reto e empina,
## bom para a subida de um salto, que precisa lançar o carro para cima).
func height_offset(z: float) -> float:
	var shape: Dictionary = segment_at(z).get("altura", {})
	if shape.is_empty():
		return 0.0
	var t := fposmod(z, SEGMENT)
	if shape.has("onda"):
		var w: Dictionary = shape.onda
		if t > w.de and t < w.ate:
			return w.amplitude * 0.5 * (1.0 - cos((t - w.de) / w.periodo * TAU))
		return 0.0
	var pts: Array = shape.get("pontos", [])
	if pts.is_empty() or t <= pts[0][0]:
		return 0.0 if pts.is_empty() else float(pts[0][1])
	for k in range(1, pts.size()):
		var b: Array = pts[k]
		if t <= b[0]:
			var a: Array = pts[k - 1]
			var u: float = (t - a[0]) / (b[0] - a[0])
			match b[2] if b.size() > 2 else "linear":
				"suave": u = smoothstep(0.0, 1.0, u)
				"acelera": u = u * u
			return lerpf(a[1], b[1], u)
	return float(pts[-1][1])


## Onde ficam os objetos de um trecho (rampas, pedras, óleo, serras...), já em coordenadas
## do mundo. Determinístico: mesma semente do trecho em qualquer lugar que chamar (cenário,
## piloto automático, moedas). Pode rodar numa thread.
## Devolve {"itens": [{tipo, xf, params, z, off, evitar, arco}], "faixa": faixa livre ou NAN}.
func placements(terrain: Terrain, index: int) -> Dictionary:
	var seg := segment_of(index)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(index, _seed))
	var sz := index * SEGMENT
	var items := []
	var lane := NAN
	var hard := Terrain.difficulty(sz + SEGMENT / 2.0)
	for spec: Dictionary in seg.get("objetos", []):
		# "longe": como o objeto fica na dificuldade máxima (chance e quantidade viram esse
		# valor; params são multiplicados), misturado conforme a distância
		var far: Dictionary = spec.get("longe", {})
		if rng.randf() > lerpf(spec.get("chance", 1.0), far.get("chance", spec.get("chance", 1.0)), hard):
			continue
		var free: Dictionary = spec.get("faixa_livre", {})
		if not free.is_empty():
			lane = _choice(free.faixas, rng)
		var count := _count(spec.get("quantidade", 1), rng)
		if far.has("quantidade"):
			count = roundi(lerpf(count, maxf(count, far.quantidade), hard))
		for k in count:
			var z := sz + _num(spec.get("z", SEGMENT / 2.0), rng)
			var off := _choice(spec.x_escolha, rng) if spec.has("x_escolha") else _num(spec.get("x", 0.0), rng)
			var size := _num(spec.get("escala", 1.0), rng)
			var spin := rng.randf() * TAU
			var params := _resolve(spec.get("params", {}), rng)
			var mult: Dictionary = far.get("params", {})
			for key: String in mult:
				params[key] = params.get(key, 1.0) * lerpf(1.0, mult[key], hard)
			if not free.is_empty() and absf(off - lane) < float(free.folga):
				off = _out_of_lane(off, lane, float(free.folga), spec.get("x", [-4.5, 4.5]))
				if is_nan(off):
					continue  # nunca bloqueia a faixa livre
			var x := terrain.path_x(z) + off
			var yaw := 0.0
			if spec.get("alinhar", false):
				yaw = atan2(terrain.path_x(z + 1.0) - terrain.path_x(z - 1.0), 2.0)
			elif spec.get("girar", false):
				yaw = spin
			var basis := Basis(Vector3.UP, yaw)
			if spec.get("no_chao", false):
				basis = _on_slope(basis, terrain, x, z)  # deitado no chão (manchas: óleo, gelo, lava)
			basis = basis * Basis(Vector3.RIGHT, deg_to_rad(spec.get("inclinacao", 0.0)))
			var origin := Vector3(x, terrain.height(x, z) + float(spec.get("altura_extra", 0.0)), z)
			params["escala"] = size
			params["fase"] = rng.randf() * TAU
			params["off"] = off
			if spec.has("amostrar_chao"):
				params["chao"] = _ground_profile(terrain, Transform3D(basis, origin), spec.amostrar_chao)
			items.append({"tipo": spec.tipo, "xf": Transform3D(basis, origin), "params": params,
				"z": z, "off": off, "evitar": ObstacleFactory.avoid(spec.tipo), "arco": spec.get("arco", {})})
	return {"itens": items, "faixa": lane}


## Número fixo, ou [mín, máx] sorteado.
static func _num(v: Variant, rng: RandomNumberGenerator) -> float:
	if v is Array:
		return rng.randf_range(v[0], v[1])
	return float(v)


static func _count(v: Variant, rng: RandomNumberGenerator) -> int:
	if v is Array:
		return rng.randi_range(int(v[0]), int(v[1]))
	return int(v)


## Gira a base para o "para cima" seguir a inclinação do chão em (x, z), mantendo o giro.
static func _on_slope(basis: Basis, terrain: Terrain, x: float, z: float) -> Basis:
	var n := Vector3(terrain.height(x - 1.0, z) - terrain.height(x + 1.0, z), 2.0,
		terrain.height(x, z - 1.0) - terrain.height(x, z + 1.0)).normalized()
	var bx := (basis.x - n * basis.x.dot(n)).normalized()
	return Basis(bx, n, bx.cross(n))


## Altura do chão (relativa ao objeto) a cada metro do eixo z local, de `range[0]` a
## `range[1]`: para obstáculos que andam pela trilha (barril) seguirem o relevo.
static func _ground_profile(terrain: Terrain, xf: Transform3D, range_z: Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for dz in range(int(range_z[0]), int(range_z[1]) + 1):
		var p := xf * Vector3(0, 0, dz)
		out.append(terrain.height(p.x, p.z) - xf.origin.y)
	return out


## Objeto que caiu na faixa livre: empurra para fora dela (do lado mais perto, ou do outro
## se não couber dentro da faixa x permitida). NAN se não couber em nenhum lado.
static func _out_of_lane(off: float, lane: float, gap: float, x_range: Variant) -> float:
	var lo := -INF
	var hi := INF
	if x_range is Array:
		lo = x_range[0]
		hi = x_range[1]
	var side := signf(off - lane) if off != lane else 1.0
	for s in [side, -side]:
		var moved: float = lane + s * (gap + absf(off - lane))
		if moved >= lo and moved <= hi:
			return moved
	return NAN


static func _choice(list: Array, rng: RandomNumberGenerator) -> float:
	return float(list[rng.randi() % list.size()])


## Parâmetros de um objeto com as faixas [mín, máx] já sorteadas.
static func _resolve(params: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var out := {}
	for key: String in params:
		var v: Variant = params[key]
		out[key] = _num(v, rng) if v is Array or v is float or v is int else v
	return out
