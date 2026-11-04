class_name Terrain
extends Node3D
## Terreno 3D infinito, gerado em pedaços (chunks) ao redor do carro.
## A altura é uma função pura de (x, z) e da semente, então os pedaços sempre se encaixam.
## Uma trilha sinuosa segue para +Z: perto dela o chão é suave; longe dela aparece o relevo
## de cada região (colinas, platôs, cristas, crateras), cada vez maior.
## Técnicas (Red Blob Games "Making maps with noise"): oitavas, redistribuição por expoente,
## terraços, ruído "ridged", distorção de domínio, umidade como 2º ruído e grade com sorteio
## (ruído azul) para os objetos.

const CHUNK := 48.0  # metros por lado
const RES := 24  # quadrados por lado (2 m cada)
const AHEAD := 3  # chunks gerados à frente do carro (+Z)
const AROUND := 2  # chunks para os lados e para trás

var _large := FastNoiseLite.new()  # perfil de subidas/descidas da trilha
var _hills := FastNoiseLite.new()  # colinas com domínio distorcido (Campo, Deserto, Lua)
var _ridge := FastNoiseLite.new()  # cristas de montanha (Neve, Vulcão)
var _craters := FastNoiseLite.new()  # células de Voronoi viram crateras (Lua)
var _moist := FastNoiseLite.new()  # umidade: varia cor e quantidade de objetos
var _detail := FastNoiseLite.new()
var _path := FastNoiseLite.new()
var _path_offset := 0.0
var _seed := 0
var track: Track  # trechos da trilha (lombadas, saltos, rampas, pedras, boost)
var _chunks := {}  # Vector2i -> StaticBody3D
var _material := StandardMaterial3D.new()

# Geração em segundo plano: o cálculo pesado roda numa thread do WorkerThreadPool e a
# thread principal só monta a malha pronta. Os ruídos só são lidos, nunca alterados.
var _pending := {}  # Vector2i -> id da tarefa
var _results := {}  # Vector2i -> dados prontos (escrito pela thread)
var _mutex := Mutex.new()
const MAX_TASKS := 2


func setup(seed_value: int) -> void:
	_seed = seed_value
	track = Track.new(seed_value)
	_large.seed = seed_value
	_large.frequency = 0.008
	_large.fractal_octaves = 3

	_hills.seed = seed_value + 3
	_hills.frequency = 0.012
	_hills.fractal_octaves = 4
	_hills.domain_warp_enabled = true
	_hills.domain_warp_amplitude = 40.0
	_hills.domain_warp_frequency = 0.006
	_hills.domain_warp_fractal_octaves = 2

	_ridge.seed = seed_value + 4
	_ridge.frequency = 0.01
	_ridge.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	_ridge.fractal_octaves = 4
	_ridge.domain_warp_enabled = true
	_ridge.domain_warp_amplitude = 25.0
	_ridge.domain_warp_frequency = 0.008

	_craters.seed = seed_value + 5
	_craters.noise_type = FastNoiseLite.TYPE_CELLULAR
	_craters.frequency = 0.025
	_craters.fractal_type = FastNoiseLite.FRACTAL_NONE
	_craters.cellular_return_type = FastNoiseLite.RETURN_DISTANCE
	_craters.cellular_jitter = 0.9

	_moist.seed = seed_value + 6
	_moist.frequency = 0.008
	_moist.fractal_octaves = 2

	_detail.seed = seed_value + 1
	_detail.frequency = 0.05
	_detail.fractal_octaves = 2
	_path.seed = seed_value + 2
	_path.frequency = 0.003
	_path.fractal_octaves = 1
	_path_offset = _path.get_noise_1d(0.0)

	_material.vertex_color_use_as_albedo = true
	_material.vertex_color_is_srgb = true
	_material.roughness = 0.95


## 0 nos primeiros 300 m, depois sobe devagar até 1: morros maiores e mais irregulares.
static func difficulty(z: float) -> float:
	return 1.0 - exp(-maxf(z - 300.0, 0.0) / 3000.0)


## Centro (x) da trilha na distância z. Começa em x = 0, com curvas suaves no início
## que vão ficando mais abertas para os lados nos primeiros 1500 m.
func path_x(z: float) -> float:
	var swing := lerpf(35.0, 70.0, smoothstep(0.0, 1500.0, z))
	return (_path.get_noise_1d(z) - _path_offset) * swing


## Umidade de 0 (seco) a 1 (úmido).
func moisture(x: float, z: float) -> float:
	return _moist.get_noise_2d(x, z) * 0.5 + 0.5


func height(x: float, z: float) -> float:
	return _height_at(x, z, path_x(z), _large.get_noise_2d(0.0, z), difficulty(z), track.height_offset(z))


## Mesma conta de height(), recebendo pronto o que só depende de z (calculado uma vez por linha).
## feature = altura extra do trecho da trilha (lombadas, salto).
func _height_at(x: float, z: float, px: float, large0: float, d: float, feature: float) -> float:
	var amp := 3.5 + 18.0 * d
	var off := absf(x - px)
	var detail := _detail.get_noise_2d(x, z)
	var road_h := large0 * amp + detail * 0.6 * d
	# longe da trilha o relevo da região cresce
	var rise := clampf(off / 40.0, 0.0, 1.0)
	var wild := road_h + _relief(x, z) * (4.0 + 14.0 * d + 10.0 * rise) + detail * (0.4 + 1.5 * d)
	var h := lerpf(wild, road_h, 1.0 - smoothstep(5.0, 16.0, off))
	h += feature * (1.0 - smoothstep(7.0, 14.0, off))
	return h * smoothstep(10.0, 50.0, z)  # largada plana


## Relevo da região em (x, z), misturado com a próxima região perto da fronteira.
func _relief(x: float, z: float) -> float:
	var i := GameData.biome_index(z)
	var r := _biome_relief(i, x, z)
	var w := GameData.biome_blend(z)
	if w > 0.0:
		r = lerpf(r, _biome_relief((i + 1) % GameData.BIOMES.size(), x, z), w)
	return r


## Forma do relevo de cada região, aproximadamente entre -1 e 1.
func _biome_relief(biome: int, x: float, z: float) -> float:
	match biome:
		0:  # Campo: colinas; o expoente achata os vales e arredonda os topos
			var e := _hills.get_noise_2d(x, z) * 0.5 + 0.5
			return pow(e, 1.8) * 2.0 - 0.6
		1:  # Deserto: platôs em degraus (terraços suaves) com dunas por cima
			var e := _hills.get_noise_2d(x, z) * 0.5 + 0.5
			var t := e * 5.0
			var step := floorf(t)
			var mesa := (step + smoothstep(0.35, 0.65, t - step)) / 5.0
			var dunes := sin(x * 0.15 + _detail.get_noise_2d(x * 0.5, z * 0.5) * 3.0) * 0.06
			return mesa * 2.0 - 0.8 + dunes
		2:  # Neve: cristas de montanha
			var r := _ridge.get_noise_2d(x, z) * 0.5 + 0.5
			return pow(r, 1.5) * 2.2 - 0.8
		3:  # Vulcão: cristas mais afiadas e altas
			var r := _ridge.get_noise_2d(x * 1.3, z * 1.3) * 0.5 + 0.5
			return pow(r, 2.5) * 3.0 - 0.6
		4:  # Lua: crateras (tigela + borda elevada) sobre uma planície ondulada.
			# A distância ao centro da célula vai de 0 a ~1 (mediana ~0,45); raio 0,28 deixa
			# cerca de 1/4 do chão em crateras, separadas por planície.
			var dist := _craters.get_noise_2d(x, z) + 1.0
			var bowl := smoothstep(0.0, 0.28, dist) - 1.0
			var rim := exp(-pow((dist - 0.28) / 0.06, 2.0)) * 0.4
			return (bowl + rim) * 1.4 + _hills.get_noise_2d(x, z) * 0.25 + 0.3
	return 0.0


## Cria/remove pedaços conforme o carro anda. O cálculo vai para threads em segundo plano
## (no máximo MAX_TASKS ao mesmo tempo) e cada pedaço pronto é montado aqui.
func update(around: Vector3) -> void:
	var center := Vector2i(floori(around.x / CHUNK), floori(around.z / CHUNK))
	_collect_finished(center)
	while _pending.size() < MAX_TASKS:
		var c = _closest_missing(center)
		if c == null:
			break
		_pending[c] =WorkerThreadPool.add_task(_compute_in_thread.bind(c))

	for c: Vector2i in _chunks.keys():
		if not _in_range(c, center):
			_chunks[c].queue_free()
			_chunks.erase(c)


## Gera tudo de uma vez, sem threads (usado na largada).
func generate_all(around: Vector3) -> void:
	var center := Vector2i(floori(around.x / CHUNK), floori(around.z / CHUNK))
	while true:
		var c = _closest_missing(center)
		if c == null:
			break
		_apply_chunk(c, _chunk_data(c))


func _exit_tree() -> void:
	for id in _pending.values():
		WorkerThreadPool.wait_for_task_completion(id)


func _in_range(c: Vector2i, center: Vector2i) -> bool:
	return absi(c.x - center.x) <= AROUND + 1 and c.y >= center.y - AROUND - 1 and c.y <= center.y + AHEAD + 1


## Pedaço faltando mais próximo do centro (ou null).
func _closest_missing(center: Vector2i) -> Variant:
	var found: Variant = null
	var best := INF
	for cz in range(center.y - AROUND, center.y + AHEAD + 1):
		for cx in range(center.x - AROUND, center.x + AROUND + 1):
			var c := Vector2i(cx, cz)
			if _chunks.has(c) or _pending.has(c):
				continue
			var dist := Vector2(c - center).length()
			if dist < best:
				best = dist
				found = c
	return found


func _compute_in_thread(c: Vector2i) -> void:
	var data := _chunk_data(c)
	_mutex.lock()
	_results[c] = data
	_mutex.unlock()


func _collect_finished(center: Vector2i) -> void:
	for c: Vector2i in _pending.keys():
		var id: int = _pending[c]
		if not WorkerThreadPool.is_task_completed(id):
			continue
		WorkerThreadPool.wait_for_task_completion(id)
		_pending.erase(c)
		_mutex.lock()
		var data: Dictionary = _results[c]
		_results.erase(c)
		_mutex.unlock()
		if _in_range(c, center):
			var t0 := Time.get_ticks_usec()
			_apply_chunk(c, data)
			var ms := (Time.get_ticks_usec() - t0) / 1000.0
			if ms > 10.0 and OS.is_debug_build():
				print("CHUNK %s montado em %.0f ms" % [c, ms])


## Monta na cena um pedaço já calculado: malha, colisão e objetos.
func _apply_chunk(c: Vector2i, data: Dictionary) -> void:
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, data.arrays)
	var body := StaticBody3D.new()
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _material
	body.add_child(mi)
	var shape := CollisionShape3D.new()
	var faces := ConcavePolygonShape3D.new()
	faces.set_faces(data.faces)
	faces.backface_collision = true
	shape.shape = faces
	body.add_child(shape)
	Props.apply(body, data.props)
	add_child(body)
	_chunks[c] = body


## Todo o cálculo de um pedaço, sem criar nós (pode rodar numa thread).
func _chunk_data(c: Vector2i) -> Dictionary:
	var step := CHUNK / RES
	var x0 := c.x * CHUNK
	var z0 := c.y * CHUNK
	var n := RES + 1

	# alturas com uma borda extra de 1 ponto, para calcular normais sem costura entre chunks
	var h := PackedFloat32Array()
	h.resize((n + 2) * (n + 2))
	var row_px := PackedFloat32Array()
	row_px.resize(n + 2)
	for j in n + 2:
		var z := z0 + (j - 1) * step
		var px := path_x(z)
		var large0 := _large.get_noise_2d(0.0, z)
		var d := difficulty(z)
		var feature := track.height_offset(z)
		row_px[j] = px
		for i in n + 2:
			h[j * (n + 2) + i] = _height_at(x0 + (i - 1) * step, z, px, large0, d, feature)

	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	verts.resize(n * n)
	normals.resize(n * n)
	colors.resize(n * n)
	for j in n:
		var z := z0 + j * step
		var road_color := GameData.biome_color(z, "road")
		# faixa amarela de aviso na borda do salto
		var t := fposmod(z, Track.SEGMENT)
		if track.kind_at(z) == Track.SALTO and t >= 11.0 and t <= 15.0:
			road_color = Color("f2c230")
		var palette := [GameData.biome_color(z, "ground"), GameData.biome_color(z, "ground2"),
			GameData.biome_color(z, "rock"), road_color]
		for i in n:
			var x := x0 + i * step
			var k := (j + 1) * (n + 2) + (i + 1)
			var normal := Vector3(h[k - 1] - h[k + 1], 2.0 * step, h[k - (n + 2)] - h[k + (n + 2)]).normalized()
			var v := j * n + i
			verts[v] = Vector3(x, h[k], z)
			normals[v] = normal
			colors[v] = _ground_color(x, z, normal, row_px[j + 1], palette)

	var indices := PackedInt32Array()
	var faces := PackedVector3Array()  # triângulos soltos, para a colisão
	for j in RES:
		for i in RES:
			var a := j * n + i
			# sentido horário visto de cima = face virada para cima no Godot
			for idx in [a, a + 1, a + n, a + 1, a + n + 1, a + n]:
				indices.append(idx)
				faces.append(verts[idx])

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	return {"arrays": arrays, "faces": faces, "props": Props.plan(self, c, _seed)}


## Cor do chão: seco/úmido pela umidade, rocha nas encostas, um pouco de variação fina, e a trilha.
## palette = [chão seco, chão úmido, rocha, trilha] da linha z.
func _ground_color(x: float, z: float, normal: Vector3, px: float, palette: Array) -> Color:
	var ground: Color = palette[0].lerp(palette[1], smoothstep(0.35, 0.75, moisture(x, z)))
	ground = ground.lerp(palette[2], smoothstep(0.25, 0.5, 1.0 - normal.y))
	ground = ground.darkened(0.06 * (_detail.get_noise_2d(x * 3.0, z * 3.0) + 1.0))
	var road := 1.0 - smoothstep(4.0, 6.0, absf(x - px))
	return ground.lerp(palette[3], road)
