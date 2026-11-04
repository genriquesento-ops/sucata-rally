class_name CarModel
extends RefCounted
## Visual do carro montado com formas simples (caixas, cilindros, esferas), um modelo por
## estágio. A física (car.gd) usa só uma caixa e as 4 rodas; o visual pode mudar à vontade.
## Para trocar por modelos .glb do Blender, basta devolver a cena em build_body().

const REST_LENGTH := 0.2

## Pinturas da garagem; o índice 0 usa a cor original de cada estágio.
const PAINTS := [
	Color(0, 0, 0, 0), Color("e04848"), Color("3f8fd2"), Color("e8c547"),
	Color("4caf50"), Color("8c3fd2"), Color("f28c28"), Color("eeeeee"), Color("2a2a2e"),
]

const DARK := Color("2a2a2e")
const CHROME := Color("b8bcc4")
const GLASS := Color(0.7, 0.88, 1.0, 0.35)
const SHIRT := Color("2b5d9c")
const WOOD := Color("9a6b3c")


static func paint_color(tier: int, paint: int) -> Color:
	return GameData.TIERS[tier].color if paint <= 0 or paint >= PAINTS.size() else PAINTS[paint]


## Pontos de fixação das 4 rodas, relativos ao centro do chassi. Frente = +Z.
static func wheel_positions(tier: int) -> Array[Vector3]:
	var size: Vector3 = GameData.TIERS[tier].size
	var result: Array[Vector3] = []
	for sz in [1.0, -1.0]:
		for sx in [-1.0, 1.0]:
			result.append(Vector3(sx * (size.x / 2.0 + 0.08), -size.y / 2.0, sz * size.z * 0.36))
	return result


static func build_body(tier: int, paint := 0) -> Node3D:
	var size: Vector3 = GameData.TIERS[tier].size
	var c := paint_color(tier, paint)
	var root := Node3D.new()
	match tier:
		0: _rolima(root, size, c)
		1: _buggy(root, size, c)
		2: _picape(root, size, c)
		3: _monstro(root, size, c)
		_: _foguete(root, size, c)
	return root


## Carrinho de rolimã: tábuas, laterais pintadas, encosto e guidão de corda.
static func _rolima(root: Node3D, s: Vector3, c: Color) -> void:
	for i in 3:
		_box(root, Vector3(0.42, 0.08, s.z), Vector3(-0.45 + i * 0.45, -0.05, 0), WOOD.darkened(i * 0.08))
	for z in [s.z * 0.42, -s.z * 0.42]:
		_box(root, Vector3(s.x, 0.1, 0.16), Vector3(0, -0.12, z), WOOD.darkened(0.35))
	for x in [-1.0, 1.0]:
		_box(root, Vector3(0.06, 0.24, s.z * 0.75), Vector3(x * (s.x / 2.0 - 0.03), 0.1, -0.1), c)
	_box(root, Vector3(0.9, 0.5, 0.08), Vector3(0, 0.25, -s.z * 0.32), c, Vector3(-0.2, 0, 0))
	_tube(root, Vector3(-0.5, 0.15, s.z * 0.38), Vector3(0.5, 0.15, s.z * 0.38), 0.04, Color("c9b27a"))
	_driver(root, Vector3(0, 0.3, -0.25), c)


## Buggy: assoalho, laterais, bico, motor atrás e gaiola de tubos.
static func _buggy(root: Node3D, s: Vector3, c: Color) -> void:
	_box(root, Vector3(s.x * 0.9, 0.12, s.z), Vector3(0, -0.15, 0), DARK)
	for x in [-1.0, 1.0]:
		_box(root, Vector3(0.28, 0.32, s.z * 0.6), Vector3(x * s.x * 0.4, 0.02, 0.05), c)
	_box(root, Vector3(1.1, 0.25, 0.7), Vector3(0, 0.0, s.z * 0.38), c, Vector3(-0.25, 0, 0))
	_box(root, Vector3(0.9, 0.45, 0.6), Vector3(0, 0.12, -s.z * 0.38), Color("555960"))
	for x in [-0.25, 0.25]:
		_tube(root, Vector3(x, 0.25, -s.z * 0.45), Vector3(x, 0.45, -s.z * 0.6), 0.06, CHROME)
	var cage := Color("333338")
	for x in [-1.0, 1.0]:
		_tube(root, Vector3(x * 0.6, -0.05, -0.55), Vector3(x * 0.48, 1.05, -0.4), 0.05, cage)
		_tube(root, Vector3(x * 0.6, -0.05, 0.45), Vector3(x * 0.45, 0.95, 0.15), 0.05, cage)
		_tube(root, Vector3(x * 0.48, 1.05, -0.4), Vector3(x * 0.45, 0.95, 0.15), 0.05, cage)
	_tube(root, Vector3(-0.48, 1.05, -0.4), Vector3(0.48, 1.05, -0.4), 0.05, cage)
	_tube(root, Vector3(-0.45, 0.95, 0.15), Vector3(0.45, 0.95, 0.15), 0.05, cage)
	_driver(root, Vector3(0, 0.1, -0.1), c)
	_lights(root, s, 0.05, 0.6)


## Picape: capô, cabine com vidro, caçamba, para-choques e para-lamas.
static func _picape(root: Node3D, s: Vector3, c: Color) -> void:
	_box(root, s, Vector3.ZERO, c)
	_box(root, Vector3(s.x * 1.01, s.y * 0.3, s.z * 1.01), Vector3(0, -s.y * 0.35, 0), c.darkened(0.35))
	_box(root, Vector3(s.x * 0.97, 0.15, s.z * 0.3), Vector3(0, s.y / 2.0 + 0.05, s.z * 0.32), c)
	_box(root, Vector3(s.x * 0.25, 0.02, s.z * 0.25), Vector3(0, s.y / 2.0 + 0.135, s.z * 0.32), Color.WHITE)
	_cabin(root, Vector3(s.x * 0.92, 0.6, s.z * 0.3), Vector3(0, s.y / 2.0 + 0.3, -0.05), c)
	_driver(root, Vector3(s.x * 0.2, s.y / 2.0 + 0.05, -0.05), c)
	var bed_z := -s.z * 0.32
	for x in [-1.0, 1.0]:
		_box(root, Vector3(0.08, 0.35, s.z * 0.34), Vector3(x * (s.x / 2.0 - 0.04), s.y / 2.0 + 0.17, bed_z), c)
	_box(root, Vector3(s.x, 0.35, 0.08), Vector3(0, s.y / 2.0 + 0.17, -s.z / 2.0 + 0.04), c)
	_bumpers(root, s, CHROME)
	_fenders(root, 2, c.darkened(0.2))
	_lights(root, s, 0.0, 0.7)


## Monstro: carroceria alta, para-lamas largos, barra de faróis, eixos à mostra.
static func _monstro(root: Node3D, s: Vector3, c: Color) -> void:
	_box(root, s, Vector3.ZERO, c)
	_box(root, Vector3(s.x * 1.01, 0.12, s.z * 1.01), Vector3(0, 0.05, 0), Color.WHITE)
	_cabin(root, Vector3(s.x * 0.85, 0.65, s.z * 0.38), Vector3(0, s.y / 2.0 + 0.32, -0.15), c)
	_driver(root, Vector3(s.x * 0.18, s.y / 2.0 + 0.05, -0.15), c)
	for i in 4:
		_lamp(root, Vector3(0.22, 0.15, 0.1), Vector3(-0.45 + i * 0.3, s.y / 2.0 + 0.75, 0.06), Color("fff4c0"))
	_tube(root, Vector3(-0.6, s.y / 2.0 + 0.66, 0.06), Vector3(0.6, s.y / 2.0 + 0.66, 0.06), 0.04, DARK)
	_fenders(root, 3, DARK)
	_bumpers(root, s, CHROME)
	var wy := -s.y / 2.0 - REST_LENGTH * 0.5
	for z in [s.z * 0.36, -s.z * 0.36]:
		_tube(root, Vector3(-s.x / 2.0, wy, z), Vector3(s.x / 2.0, wy, z), 0.09, Color("444448"))
	_lights(root, s, 0.0, 0.8)


## Foguete: bico em cunha, bolha de vidro, aletas, aerofólio e propulsor.
static func _foguete(root: Node3D, s: Vector3, c: Color) -> void:
	_box(root, Vector3(s.x, s.y, s.z * 0.7), Vector3(0, 0, -s.z * 0.1), c)
	_box(root, Vector3(s.x * 0.85, s.y * 0.7, s.z * 0.45), Vector3(0, -0.05, s.z * 0.32), c, Vector3(0.18, 0, 0))
	_box(root, Vector3(s.x * 1.02, 0.08, s.z * 0.7), Vector3(0, -s.y * 0.35, -s.z * 0.1), DARK)
	_driver(root, Vector3(0, s.y / 2.0 - 0.05, -0.2), c)
	var bubble := _sphere(root, 0.5, Vector3(0, s.y / 2.0 + 0.15, -0.15), GLASS, Vector3(1.2, 0.8, 1.7))
	(bubble.material_override as StandardMaterial3D).transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for x in [-1.0, 1.0]:
		_box(root, Vector3(0.06, 0.6, 0.7), Vector3(x * s.x * 0.4, s.y / 2.0 + 0.25, -s.z * 0.4), c.darkened(0.3), Vector3(-0.3, 0, 0))
	_box(root, Vector3(s.x * 1.05, 0.06, 0.45), Vector3(0, s.y / 2.0 + 0.55, -s.z * 0.45), DARK)
	var booster := _cyl(root, 0.3, 0.6, Vector3(0, 0.05, -s.z / 2.0 - 0.15), Color("ffb030"))
	booster.rotation.x = PI / 2.0
	var mat := booster.material_override as StandardMaterial3D
	mat.emission_enabled = true
	mat.emission = Color("ff7a20")
	mat.emission_energy_multiplier = 2.0
	_lights(root, s, -0.05, 0.5)


static func build_wheel(radius: float, paint := Color("9a9a9a")) -> Node3D:
	var root := Node3D.new()
	var tire := _cyl(root, radius, radius * 0.7, Vector3.ZERO, Color("1e1e20"))
	tire.rotation.z = PI / 2.0
	var rim := _cyl(root, radius * 0.62, radius * 0.72, Vector3.ZERO, CHROME)
	rim.rotation.z = PI / 2.0
	var hub := _cyl(root, radius * 0.25, radius * 0.76, Vector3.ZERO, paint)
	hub.rotation.z = PI / 2.0
	for i in 5:  # raios, para dar para ver a roda girando
		var spoke := _box(root, Vector3(radius * 0.74, radius * 1.1, radius * 0.1), Vector3.ZERO, Color("6a6e76"))
		spoke.rotation.x = i * TAU / 5.0
	return root


## Carro completo parado, para a garagem e a tela inicial.
static func build_preview(tier: int, paint := 0) -> Node3D:
	var root := build_body(tier, paint)
	var radius: float = GameData.TIERS[tier].wheel
	for p in wheel_positions(tier):
		var wheel := build_wheel(radius, paint_color(tier, paint))
		wheel.position = p - Vector3(0, REST_LENGTH * 0.5, 0)
		root.add_child(wheel)
	return root


# ---------------------------------------------------------------- peças comuns

static func _driver(root: Node3D, seat: Vector3, helmet: Color) -> void:
	_box(root, Vector3(0.42, 0.45, 0.28), seat + Vector3(0, 0.22, 0), SHIRT)
	_sphere(root, 0.24, seat + Vector3(0, 0.66, 0), Color("f5f5f5") if helmet.v < 0.85 else Color("e04848"))
	_sphere(root, 0.245, seat + Vector3(0, 0.62, 0.01), helmet, Vector3(1, 0.55, 1))
	_box(root, Vector3(0.3, 0.1, 0.06), seat + Vector3(0, 0.68, 0.21), Color("1a2230"))


## Cabine com vidros, teto e colunas pintadas.
static func _cabin(root: Node3D, size: Vector3, pos: Vector3, c: Color) -> void:
	var glass := _box(root, size, pos, GLASS)
	(glass.material_override as StandardMaterial3D).transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_box(root, Vector3(size.x * 1.04, 0.07, size.z * 1.06), pos + Vector3(0, size.y / 2.0, 0), c)
	for x in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			_box(root, Vector3(0.07, size.y, 0.07), pos + Vector3(x * size.x / 2.0, 0, z * size.z / 2.0), c)


static func _bumpers(root: Node3D, s: Vector3, color: Color) -> void:
	for z in [1.0, -1.0]:
		_box(root, Vector3(s.x * 1.04, 0.16, 0.14), Vector3(0, -s.y * 0.3, z * (s.z / 2.0 + 0.06)), color)


## Para-lamas sobre as 4 rodas.
static func _fenders(root: Node3D, tier: int, color: Color) -> void:
	var r: float = GameData.TIERS[tier].wheel
	for p in wheel_positions(tier):
		_box(root, Vector3(r * 0.9, 0.1, r * 2.3), p + Vector3(0, r + 0.02 - REST_LENGTH * 0.5, 0), color)


## Faróis (frente) e lanternas (trás), acesos.
static func _lights(root: Node3D, s: Vector3, y: float, spread: float) -> void:
	for x in [-1.0, 1.0]:
		_lamp(root, Vector3(0.22, 0.12, 0.05), Vector3(x * s.x * spread * 0.5, y, s.z / 2.0 + 0.02), Color("fff4c0"))
		_lamp(root, Vector3(0.2, 0.1, 0.05), Vector3(x * s.x * spread * 0.5, y, -s.z / 2.0 - 0.02), Color("ff3030"))


static func _lamp(root: Node3D, size: Vector3, pos: Vector3, color: Color) -> void:
	var m := _box(root, size, pos, color).material_override as StandardMaterial3D
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 1.5


## Tubo (cilindro) ligando dois pontos.
static func _tube(root: Node3D, from: Vector3, to: Vector3, radius: float, color: Color) -> MeshInstance3D:
	var dir := to - from
	var mi := _cyl(root, radius, dir.length(), (from + to) / 2.0, color)
	mi.basis = Basis(Quaternion(Vector3.UP, dir.normalized()))
	return mi


static func _box(parent: Node3D, size: Vector3, pos: Vector3, color: Color, rot := Vector3.ZERO) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := _add(parent, mesh, pos, color)
	mi.rotation = rot
	return mi


static func _sphere(parent: Node3D, radius: float, pos: Vector3, color: Color, scale := Vector3.ONE) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	var mi := _add(parent, mesh, pos, color)
	mi.scale = scale
	return mi


static func _cyl(parent: Node3D, radius: float, height: float, pos: Vector3, color: Color) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 14
	return _add(parent, mesh, pos, color)


static func _add(parent: Node3D, mesh: Mesh, pos: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.55
	mi.material_override = mat
	parent.add_child(mi)
	return mi
