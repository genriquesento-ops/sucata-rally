class_name Pickups
extends Node3D
## Moedas e galões de combustível espalhados ao longo da trilha, e arcos de moedas
## (valendo o dobro) no ar sobre os saltos e depois das rampas.

const SEGMENT := 30.0
const SPAWN_AHEAD := 160.0

var _terrain: Terrain
var _seed := 0
var _next_segment := 20.0
var _next_fuel := 130.0
var _next_track := 0  # próximo trecho da trilha a receber arcos de moedas
var _items: Array[Dictionary] = []  # {node, fuel: bool, value}
var _coin_mesh := CylinderMesh.new()
var _fuel_mesh := BoxMesh.new()


func setup(terrain: Terrain, seed_value: int) -> void:
	_terrain = terrain
	_seed = seed_value
	_coin_mesh.top_radius = 0.45
	_coin_mesh.bottom_radius = 0.45
	_coin_mesh.height = 0.12
	_coin_mesh.material = _material(Color("ffd23f"), 0.4)
	_fuel_mesh.size = Vector3(0.7, 0.9, 0.45)
	_fuel_mesh.material = _material(Color("d23c3c"), 0.15)


## Atualiza e devolve o que o carro pegou neste frame: {"coins": int, "fuel": bool}.
func update(car_pos: Vector3, magnet: float, delta: float) -> Dictionary:
	while _next_segment < car_pos.z + SPAWN_AHEAD:
		_spawn_segment(_next_segment)
		_next_segment += SEGMENT
	while _next_track * Track.SEGMENT < car_pos.z + SPAWN_AHEAD:
		_spawn_arcs(_next_track)
		_next_track += 1

	var got := {"coins": 0, "fuel": false}
	for i in range(_items.size() - 1, -1, -1):
		var item: Dictionary = _items[i]
		var node: Node3D = item.node
		var to_car := car_pos - node.position
		var d := to_car.length()
		if not item.fuel and d < magnet and d > 0.01:
			node.position += to_car / d * minf(d, delta * 16.0)
		node.rotate_y(delta * 3.0)
		if d < 2.0:
			if item.fuel:
				got.fuel = true
				Effects.sparkle(self, node.position, Color("ff5a4a"))
				Sfx.play("fuel")
			else:
				got.coins += item.value
				Effects.sparkle(self, node.position, UiKit.GOLD)
				Sfx.play("coin", 0.12)
		if d < 2.0 or node.position.z < car_pos.z - 60.0:
			node.queue_free()
			_items.remove_at(i)
	return got


func _spawn_segment(z0: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed + int(z0)
	# fileira de moedas na trilha; valem mais quanto mais longe.
	# Não vai em trechos com "moedas": false no trechos.json (salto, rampa, pedras: lá as
	# moedas ficam nos arcos).
	var track := _terrain.track
	var clear: bool = track.segment_at(z0 + 2.0).get("moedas", true) and track.segment_at(z0 + 20.0).get("moedas", true)
	if rng.randf() < 0.8 and clear:
		var count := rng.randi_range(4, 8)
		var side := rng.randf_range(-3.0, 3.0)
		var value := 1 + int(z0 / 300.0)
		for k in count:
			var z := z0 + 2.0 + k * 2.5
			_add(_coin_mesh, _terrain.path_x(z) + side, z, 1.1, false, value)
	# galões cada vez mais espaçados
	while _next_fuel < z0 + SEGMENT:
		if _next_fuel >= z0:
			_add(_fuel_mesh, _terrain.path_x(_next_fuel) + _free_lane(_next_fuel), _next_fuel, 0.9, true, 0)
		# galões em 130, 322, 591, 967, 1494 m...: o vão cresce até passar do alcance do
		# tanque, e aí a corrida acaba (melhorar o Tanque é o que leva mais longe)
		_next_fuel += 140.0 + _next_fuel * 0.4


## Deslocamento da faixa livre do trecho em z (0 se não tiver): o galão vai nela, e não
## no meio de uma poça de óleo ou lava.
func _free_lane(z: float) -> float:
	var index := _terrain.track.index_at(z)
	if index < 0 or not _terrain.track.segment_of(index).has("objetos"):
		return 0.0
	var lane: float = _terrain.track.placements(_terrain, index).faixa
	return 0.0 if is_nan(lane) else lane


## Arcos de moedas no ar, como manda o trechos.json: "arcos" do trecho (ex.: sobre o vale
## do salto) e "arco" de um objeto (ex.: depois da rampa, do mesmo lado dela).
func _spawn_arcs(index: int) -> void:
	var track := _terrain.track
	var sz := index * Track.SEGMENT
	var value := 2 * (1 + int(sz / 300.0))
	for a: Dictionary in track.segment_of(index).get("arcos", []):
		_arc(_terrain.path_x(sz + a.de) + a.get("x", 0.0), sz + a.de, sz + a.ate, a.altura, value)
	if not track.segment_of(index).has("objetos"):
		return
	for item: Dictionary in track.placements(_terrain, index).itens:
		var a: Dictionary = item.arco
		if not a.is_empty():
			_arc(item.xf.origin.x, item.z + a.de, item.z + a.ate, a.altura, value)


func _arc(x: float, z_from: float, z_to: float, peak: float, value: int) -> void:
	var y_from := _terrain.height(x, z_from) + 1.2
	var y_to := _terrain.height(x, z_to) + 1.0
	var count := 7
	for k in count:
		var u := float(k) / (count - 1)
		var z := lerpf(z_from, z_to, u)
		_add(_coin_mesh, x, z, 0.0, false, value, lerpf(y_from, y_to, u) + peak * sin(PI * u))


## y_abs: altura absoluta; se NAN, fica `lift` metros acima do chão.
func _add(mesh: Mesh, x: float, z: float, lift: float, fuel: bool, value: int, y_abs := NAN) -> void:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	var y := _terrain.height(x, z) + lift if is_nan(y_abs) else y_abs
	node.position = Vector3(x, y, z)
	if not fuel:
		node.rotation.x = PI / 2.0  # moeda "em pé"
		var pivot := Node3D.new()
		pivot.position = node.position
		node.position = Vector3.ZERO
		pivot.add_child(node)
		add_child(pivot)
		_items.append({"node": pivot, "fuel": false, "value": value})
		return
	add_child(node)
	_items.append({"node": node, "fuel": true, "value": 0})


static func _material(color: Color, emission: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = emission
	m.roughness = 0.4
	return m
