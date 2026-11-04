class_name Props
extends RefCounted
## Objetos do cenário (árvores, cactos, pinheiros, pedras, cristais) espalhados fora da trilha,
## e os elementos dos trechos da trilha (rampas, pedregulhos, placas de boost).
## Posição: grade de 6 m com um ponto sorteado em cada célula ("jittered grid", uma forma barata
## de ruído azul: nada amontoado e nada em fileira). Desenho: um MultiMesh por tipo e por chunk,
## então centenas de objetos custam poucas chamadas de desenho no celular.

const CELL := 6.0
const ROAD_CLEARANCE := 9.0  # metros livres de cada lado do centro da trilha

## Por região: densidade base, se gosta de umidade (1) ou de seco (-1), e tipos com peso.
const BIOME_PROPS := [
	{"density": 0.45, "moisture": 1.0, "kinds": {"tree": 0.55, "bush": 0.3, "rock": 0.15}},
	{"density": 0.22, "moisture": -1.0, "kinds": {"cactus": 0.6, "desert_rock": 0.4}},
	{"density": 0.35, "moisture": 1.0, "kinds": {"pine": 0.7, "ice": 0.3}},
	{"density": 0.25, "moisture": 0.0, "kinds": {"basalt": 0.65, "fire_crystal": 0.35}},
	{"density": 0.2, "moisture": 0.0, "kinds": {"moon_rock": 0.7, "blue_crystal": 0.3}},
]

## Raio de colisão de cada tipo (0 = atravessável, como arbustos).
const COLLIDER := {
	"tree": 0.35, "bush": 0.0, "rock": 0.8, "cactus": 0.3, "desert_rock": 0.9, "pine": 0.3,
	"ice": 0.5, "basalt": 0.9, "fire_crystal": 0.4, "moon_rock": 0.8, "blue_crystal": 0.4,
}

static var _meshes := {}  # tipo -> ArrayMesh (criados uma vez só)
static var density_scale := 1.0  # 0,5 na qualidade baixa (opções)


## Decide onde ficam os objetos de um chunk, sem criar nós (pode rodar numa thread).
## Devolve {"kinds": {tipo: [Transform3D]}, "colliders": [...]}, onde cada colisor é
## ["cyl", posição, raio, altura] ou ["box", Transform3D, tamanho].
static func plan(terrain: Terrain, chunk: Vector2i, seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(chunk.x, chunk.y, seed_value))
	var per_kind := {}  # tipo -> Array[Transform3D]
	var colliders := []
	var cells := int(Terrain.CHUNK / CELL)
	for gz in cells:
		for gx in cells:
			var px := chunk.x * Terrain.CHUNK + (gx + rng.randf_range(0.15, 0.85)) * CELL
			var pz := chunk.y * Terrain.CHUNK + (gz + rng.randf_range(0.15, 0.85)) * CELL
			var roll := rng.randf()
			var pick := rng.randf()
			var size := rng.randf_range(0.7, 1.4)
			var yaw := rng.randf() * TAU
			if pz < 15.0 or absf(px - terrain.path_x(pz)) < ROAD_CLEARANCE:
				continue
			var info: Dictionary = BIOME_PROPS[GameData.biome_index(pz)]
			var wet := terrain.moisture(px, pz)
			var density: float = info.density * lerpf(1.0, lerpf(0.3, 1.7, wet if info.moisture > 0.0 else 1.0 - wet), absf(info.moisture))
			if roll > density * density_scale:
				continue
			var kind := _pick_kind(info.kinds, pick)
			var basis := Basis(Vector3.UP, yaw).scaled(Vector3.ONE * size)
			var xf := Transform3D(basis, Vector3(px, terrain.height(px, pz) - 0.1, pz))
			if not per_kind.has(kind):
				per_kind[kind] = []
			per_kind[kind].append(xf)
			if COLLIDER[kind] > 0.0:
				colliders.append(["cyl", xf.origin + Vector3.UP * 1.5 * size, COLLIDER[kind] * size, 3.0 * size])
	_track_features(terrain, chunk, seed_value, per_kind, colliders)
	return {"kinds": per_kind, "colliders": colliders}


const BOULDER_RADIUS := 1.0


## Pedregulhos de um trecho de PEDRAS: {"lane": deslocamento da faixa livre,
## "boulders": [[posição, tamanho, giro], ...]}. Determinístico (mesma semente do trecho),
## usado pelo cenário, pelo piloto automático e pelo bônus de "passou raspando".
static func boulder_layout(terrain: Terrain, s: int, seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(s, seed_value))
	var sz := s * Track.SEGMENT
	var lane := rng.randi_range(-1, 1) * 3.0
	var list := []
	for k in rng.randi_range(3, 5):
		var z := sz + rng.randf_range(10.0, 30.0)
		var off := rng.randf_range(-4.5, 4.5)
		var size := rng.randf_range(0.8, 1.2)
		var yaw := rng.randf() * TAU
		if absf(off - lane) < 2.4:
			continue
		var x := terrain.path_x(z) + off
		list.append([Vector3(x, terrain.height(x, z) - 0.2, z), size, yaw])
	return {"lane": lane, "boulders": list}


## Rampas, pedregulhos e placas de boost dos trechos da trilha que passam por este chunk.
## Cada trecho usa sua própria semente, então um elemento na divisa entre dois chunks é
## calculado igual nos dois e só entra no chunk onde fica o seu centro.
static func _track_features(terrain: Terrain, chunk: Vector2i, seed_value: int, per_kind: Dictionary, colliders: Array) -> void:
	var x0 := chunk.x * Terrain.CHUNK
	var z0 := chunk.y * Terrain.CHUNK
	var items := []  # [tipo, Transform3D, colisor ou null]
	for s in range(floori(z0 / Track.SEGMENT), floori((z0 + Terrain.CHUNK) / Track.SEGMENT) + 1):
		if s < 0:
			continue
		var sz := s * Track.SEGMENT
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(Vector2i(s, seed_value))
		match terrain.track.kind_of(s):
			Track.RAMPA:  # rampa opcional de um lado da trilha, inclinada 14°
				var z := sz + Track.RAMP_AT
				var x := terrain.path_x(z) + (2.0 if rng.randf() < 0.5 else -2.0)
				var xf := Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-14.0)), Vector3(x, terrain.height(x, z) + 0.75, z))
				items.append(["ramp", xf, ["box", xf, Vector3(3.0, 0.3, 6.2)]])
			Track.PEDRAS:  # pedregulhos na trilha, sempre deixando uma faixa livre
				for b: Array in boulder_layout(terrain, s, seed_value).boulders:
					var size: float = b[1]
					var xf := Transform3D(Basis(Vector3.UP, b[2]).scaled(Vector3.ONE * size), b[0])
					items.append(["boulder", xf, ["cyl", xf.origin + Vector3.UP * 0.9 * size, BOULDER_RADIUS * size, 2.4 * size]])
			Track.BOOST:  # placa de boost no centro da trilha, alinhada com ela
				var z := sz + Track.BOOST_AT
				var x := terrain.path_x(z)
				var yaw := atan2(terrain.path_x(z + 1.0) - terrain.path_x(z - 1.0), 2.0)
				items.append(["boost_pad", Transform3D(Basis(Vector3.UP, yaw), Vector3(x, terrain.height(x, z) + 0.05, z)), null])
	for item: Array in items:
		var origin: Vector3 = item[1].origin
		if origin.x < x0 or origin.x >= x0 + Terrain.CHUNK or origin.z < z0 or origin.z >= z0 + Terrain.CHUNK:
			continue
		if not per_kind.has(item[0]):
			per_kind[item[0]] = []
		per_kind[item[0]].append(item[1])
		if item[2] != null:
			colliders.append(item[2])


## Cria os nós do plano como filhos de `body` (o corpo estático do chunk). Thread principal.
static func apply(body: StaticBody3D, plan_data: Dictionary) -> void:
	for c: Array in plan_data.colliders:
		var col := CollisionShape3D.new()
		if c[0] == "box":
			var box := BoxShape3D.new()
			box.size = c[2]
			col.shape = box
			col.transform = c[1]
		else:
			var cyl := CylinderShape3D.new()
			cyl.radius = c[2]
			cyl.height = c[3]
			col.shape = cyl
			col.position = c[1]
		body.add_child(col)

	var per_kind: Dictionary = plan_data.kinds
	for kind: String in per_kind:
		var list: Array = per_kind[kind]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = _mesh(kind)
		mm.instance_count = list.size()
		for i in list.size():
			mm.set_instance_transform(i, list[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		body.add_child(mmi)


static func _pick_kind(kinds: Dictionary, roll: float) -> String:
	var acc := 0.0
	var last := ""
	for kind: String in kinds:
		acc += kinds[kind]
		last = kind
		if roll <= acc:
			return kind
	return last


static func _mesh(kind: String) -> Mesh:
	if not _meshes.has(kind):
		_meshes[kind] = _build(kind)
	return _meshes[kind]


## Cada tipo é uma malha única com cores por vértice (um só material, uma só chamada de desenho).
static func _build(kind: String) -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var glow := Color.BLACK
	match kind:
		"tree":
			_part(st, _cyl(0.18, 0.22, 1.6, 6), Vector3(0, 0.8, 0), Vector3.ONE, Color("6b4a2a"))
			_part(st, _sphere(1.1, 7, 4), Vector3(0, 2.3, 0), Vector3(1, 0.9, 1), Color("3f7a32"))
			_part(st, _sphere(0.7, 6, 3), Vector3(0.5, 2.9, 0.2), Vector3.ONE, Color("4f8f3a"))
		"bush":
			_part(st, _sphere(0.7, 6, 3), Vector3(0, 0.3, 0), Vector3(1, 0.7, 1), Color("356b2c"))
		"rock":
			_part(st, _sphere(0.9, 6, 3), Vector3(0, 0.3, 0), Vector3(1.2, 0.7, 1), Color("7a766a"))
		"cactus":
			var green := Color("4f8a3a")
			_part(st, _cyl(0.25, 0.25, 2.4, 8), Vector3(0, 1.2, 0), Vector3.ONE, green)
			_part(st, _cyl(0.15, 0.15, 0.6, 6), Vector3(0.4, 1.1, 0), Vector3.ONE, green, Vector3(0, 0, PI / 2))
			_part(st, _cyl(0.15, 0.15, 0.8, 6), Vector3(0.65, 1.45, 0), Vector3.ONE, green)
			_part(st, _cyl(0.13, 0.13, 0.5, 6), Vector3(-0.35, 1.5, 0), Vector3.ONE, green, Vector3(0, 0, PI / 2))
			_part(st, _cyl(0.13, 0.13, 0.6, 6), Vector3(-0.55, 1.8, 0), Vector3.ONE, green)
		"desert_rock":
			_part(st, _cyl(0.9, 1.2, 1.4, 7), Vector3(0, 0.6, 0), Vector3.ONE, Color("a9643f"))
			_part(st, _cyl(0.7, 0.9, 0.6, 7), Vector3(0, 1.6, 0), Vector3.ONE, Color("bd7a4e"))
		"pine":
			_part(st, _cyl(0.14, 0.18, 1.0, 6), Vector3(0, 0.5, 0), Vector3.ONE, Color("5a3d22"))
			_part(st, _cyl(0.0, 1.1, 2.0, 8), Vector3(0, 1.8, 0), Vector3.ONE, Color("2f5a3a"))
			_part(st, _cyl(0.0, 0.8, 1.6, 8), Vector3(0, 2.8, 0), Vector3.ONE, Color("2f5a3a"))
			_part(st, _cyl(0.0, 0.45, 0.7, 8), Vector3(0, 3.5, 0), Vector3.ONE, Color("f2f6fa"))
		"ice":
			_part(st, _cyl(0.15, 0.6, 2.2, 4), Vector3(0, 1.0, 0), Vector3.ONE, Color("bfe3f7"))
			_part(st, _cyl(0.1, 0.4, 1.4, 4), Vector3(0.6, 0.6, 0.2), Vector3.ONE, Color("d6eefa"), Vector3(0, 0, -0.4))
		"basalt":
			_part(st, _cyl(0.6, 0.9, 2.2, 6), Vector3(0, 1.0, 0), Vector3.ONE, Color("2a2222"))
			_part(st, _cyl(0.4, 0.6, 1.4, 6), Vector3(0.9, 0.6, 0.3), Vector3.ONE, Color("332828"))
		"fire_crystal":
			_part(st, _cyl(0.0, 0.4, 2.0, 5), Vector3(0, 1.0, 0), Vector3.ONE, Color("ff7a30"))
			_part(st, _cyl(0.0, 0.3, 1.3, 5), Vector3(0.4, 0.6, 0.1), Vector3.ONE, Color("ffa040"), Vector3(0, 0, -0.5))
			glow = Color("ff5a10")
		"moon_rock":
			_part(st, _sphere(1.0, 6, 3), Vector3(0, 0.2, 0), Vector3(1.3, 0.6, 1.1), Color("9a9aa5"))
		"blue_crystal":
			_part(st, _cyl(0.0, 0.4, 2.2, 5), Vector3(0, 1.1, 0), Vector3.ONE, Color("5ac8ff"))
			_part(st, _cyl(0.0, 0.3, 1.4, 5), Vector3(-0.4, 0.7, 0.1), Vector3.ONE, Color("8ad8ff"), Vector3(0, 0, 0.5))
			glow = Color("2a8cff")
		"ramp":  # prancha de madeira com faixas amarelas (o colisor tem 3 x 0,3 x 6,2 m)
			_part(st, _box(Vector3(3.0, 0.3, 6.2)), Vector3.ZERO, Vector3.ONE, Color("8a5a32"))
			for k in 3:
				_part(st, _box(Vector3(3.02, 0.02, 0.4)), Vector3(0, 0.16, -1.8 + k * 1.8), Vector3.ONE, Color("f2c230"))
		"boulder":
			_part(st, _sphere(1.1, 7, 4), Vector3(0, 0.8, 0), Vector3(1.1, 0.9, 1.0), Color("857a6a"))
		"boost_pad":  # placa com setas apontando para a frente (+Z)
			_part(st, _box(Vector3(2.6, 0.06, 3.0)), Vector3.ZERO, Vector3.ONE, Color("1e6f8a"))
			for k in 2:
				var zc := -0.6 + k * 1.2
				_part(st, _box(Vector3(1.3, 0.04, 0.25)), Vector3(-0.45, 0.05, zc), Vector3.ONE, Color("6ff0ff"), Vector3(0, 0.7, 0))
				_part(st, _box(Vector3(1.3, 0.04, 0.25)), Vector3(0.45, 0.05, zc), Vector3.ONE, Color("6ff0ff"), Vector3(0, -0.7, 0))
			glow = Color("30c8ff")
	var mesh := st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 0.85
	if glow != Color.BLACK:
		mat.emission_enabled = true
		mat.emission = glow
		mat.emission_energy_multiplier = 0.8
	mesh.surface_set_material(0, mat)
	return mesh


## Copia uma forma primitiva para a malha, com posição, escala, rotação e cor.
static func _part(st: SurfaceTool, prim: PrimitiveMesh, pos: Vector3, scale: Vector3, color: Color, rot := Vector3.ZERO) -> void:
	var basis := Basis.from_euler(rot).scaled(scale)
	var arrays := prim.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for i in indices:
		st.set_color(color)
		st.set_normal((basis * normals[i]).normalized())
		st.add_vertex(basis * verts[i] + pos)


static func _cyl(top: float, bottom: float, height: float, sides: int) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = height
	m.radial_segments = sides
	m.rings = 1
	return m


static func _box(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m


static func _sphere(radius: float, sides: int, rings: int) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	m.radial_segments = sides
	m.rings = rings
	return m
