extends Node
## Estabilidade do carro numa corrida real, sem toque (só a ajuda na direção), em mapas fixos
## e com carros em vários pontos da evolução. Mede quanto o carro "rabeia" (giro que o volante
## não pediu), o tempo tombado, o tempo no ar, as rés automáticas e a distância.
## Rodar como cena (para carregar os autoloads); o "--demo-teste" faz usar o save do demo:
##   godot --headless --path . res://tests/stability_test.tscn -- --demo-teste

const SEEDS := [11, 22, 33]
const SECONDS := 30.0
## [estágio, nível de todas as peças]
const CARS := [[0, 0], [0, 5], [2, 15], [4, 25]]

var _main: Node
var _run: Run
var _case := -1
var _t := 0.0
var _sum_sq := 0.0
var _samples := 0
var _max_yaw := 0.0
var _revs := 0
var _last_rev := 0.0
var _tipped := 0.0
var _air := 0.0
var _max_speed := 0.0


func _ready() -> void:
	_main = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(_main)
	_next.call_deferred()


func _next() -> void:
	_case += 1
	if _case >= CARS.size() * SEEDS.size():
		get_tree().quit()
		return
	var car: Array = CARS[_case / SEEDS.size()]
	Save.tier = car[0]
	for id in Save.levels:
		Save.levels[id] = car[1]
	seed(SEEDS[_case % SEEDS.size()])
	_run = _main.start_run()
	_t = 0.0
	_sum_sq = 0.0
	_samples = 0
	_max_yaw = 0.0
	_revs = 0
	_last_rev = 0.0
	_tipped = 0.0
	_air = 0.0
	_max_speed = 0.0


func _physics_process(delta: float) -> void:
	if _run == null or _run._car == null:
		return
	_t += delta
	var car: Car = _run._car
	if car.on_ground():
		# giro que o volante não explica = rabeada
		var expected := car.forward_speed() * tan(car.steering) / car._wheelbase
		var extra := car.angular_velocity.y - expected
		_sum_sq += extra * extra
		_samples += 1
		_max_yaw = maxf(_max_yaw, absf(extra))
	else:
		_air += delta
	if car.uprightness() < 0.5:
		_tipped += delta
	_max_speed = maxf(_max_speed, car.linear_velocity.length())
	if _run._reverse_time > 0.0 and _last_rev <= 0.0:
		_revs += 1
	_last_rev = _run._reverse_time
	if _t >= SECONDS:
		var c: Array = CARS[_case / SEEDS.size()]
		print("estágio %d nível %2d mapa %d: rabeada %.2f (máx %.1f) · tombado %4.1f s · no ar %4.1f s · rés %d · vel máx %2.0f m/s · chegou a %4.0f m" % [
			c[0], c[1], SEEDS[_case % SEEDS.size()], sqrt(_sum_sq / maxf(_samples, 1)), _max_yaw,
			_tipped, _air, _revs, _max_speed, car.global_position.z])
		_run = null
		_next()
