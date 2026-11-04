extends SceneTree
## Teste das armadilhas sem janela: o carro acelera reto contra cada obstáculo num chão plano
## e confere o evento que chega na corrida (bateu, desviou, óleo, boost).
##   godot --headless --path . --script res://tests/trap_test.gd

const SECONDS := 5.5

## [nome, tipo, params, x do carro, estágio do carro, evento esperado]
const CASES := [
	["óleo no meio", "oleo", {}, 0.0, 0, "oil"],
	["gelo no meio", "gelo", {}, 0.0, 0, "ice"],
	["lava no meio", "lava", {}, 0.0, 0, "lava"],
	["boost no meio", "boost", {}, 0.0, 0, "boost"],
	["serra parada no meio", "serra", {"amplitude": 0.0}, 0.0, 0, "hit"],
	["serra parada, carro do lado", "serra", {"amplitude": 0.0}, 3.5, 0, "dodge"],
	["martelo parado (Rolimã)", "martelo", {"angulo": 0.0}, 0.0, 0, "hit"],
	["martelo parado (Monstro)", "martelo", {"angulo": 0.0}, 0.0, 3, "hit"],
	["barril na faixa do carro", "barril", {}, 0.0, 0, "hit"],
	["barril em outra faixa", "barril", {}, 3.5, 0, "dodge"],
	["ventilador ligado", "vento", {"off": -7.0, "ligado": 30.0}, 0.0, 0, "wind"],
]


class Recorder extends Node:
	var events: Array[String] = []

	func on_obstacle(event: String, _data := {}) -> void:
		events.append(event)


var _case := -1
var _time := 0.0
var _world: Node3D
var _car: Car
var _rec: Recorder
var _failed := 0


func _initialize() -> void:
	_next()


func _next() -> void:
	if _world != null:
		_world.queue_free()
	_case += 1
	_time = 0.0
	if _case >= CASES.size():
		return
	var c: Array = CASES[_case]
	_world = Node3D.new()
	root.add_child(_world)
	var ground := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(60, 1, 200)
	shape.shape = box
	ground.add_child(shape)
	ground.position = Vector3(0, -0.5, 60)
	_world.add_child(ground)

	var levels := {"motor": 0, "tires": 0, "suspension": 0, "tank": 0, "magnet": 0, "nitro": 0}
	_car = Car.new()
	_car.setup(c[4], GameData.stats(c[4], levels))
	_car.position = Vector3(c[3], 1.5, 0)
	_world.add_child(_car)
	_rec = Recorder.new()
	_world.add_child(_rec)
	Obstacle.car = _car
	Obstacle.run = _rec
	Obstacle.clock = 0.0
	var params: Dictionary = c[2].duplicate()
	params["fase"] = 0.0
	var x: float = params.get("off", 0.0)
	_world.add_child(ObstacleFactory.create(c[1], Transform3D(Basis(), Vector3(x, 0, 25)), params))


func _physics_process(delta: float) -> bool:
	if _case >= CASES.size():
		print("armadilhas: %d de %d falharam" % [_failed, CASES.size()])
		return true
	_time += delta
	Obstacle.clock += delta
	_car.throttle = 1.0 if _time > 0.3 else 0.0
	if _time >= SECONDS:
		var c: Array = CASES[_case]
		var ok: bool = _rec.events.has(c[5])
		if not ok:
			_failed += 1
		print("%s %s: esperado %s, recebido %s (carro em x %.1f, z %.1f)" % [
			"OK  " if ok else "FALHOU", c[0], c[5], _rec.events, _car.position.x, _car.position.z])
		_next()
	return false
