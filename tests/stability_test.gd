extends Node
## Estabilidade do carro numa corrida real, sem toque (só a ajuda na direção), em mapas fixos.
## Mede quanto o carro "rabeia": giro médio e máximo em volta do eixo vertical, rés automáticas
## e distância. Rodar como cena (para carregar os autoloads):
##   godot --headless --path . res://tests/stability_test.tscn

const SEEDS := [11, 22, 33, 44]
const SECONDS := 30.0

var _main: Node
var _run: Run
var _seed_i := -1
var _t := 0.0
var _sum_sq := 0.0
var _samples := 0
var _max_yaw := 0.0
var _revs := 0
var _last_rev := 0.0
var _total_rms := 0.0


func _ready() -> void:
	_main = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(_main)
	_next.call_deferred()


func _next() -> void:
	_seed_i += 1
	if _seed_i >= SEEDS.size():
		print("MÉDIA giro rms=%.2f rad/s" % [_total_rms / SEEDS.size()])
		get_tree().quit()
		return
	seed(SEEDS[_seed_i])
	_run = _main.start_run()
	_t = 0.0
	_sum_sq = 0.0
	_samples = 0
	_max_yaw = 0.0
	_revs = 0
	_last_rev = 0.0


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
	if _run._reverse_time > 0.0 and _last_rev <= 0.0:
		_revs += 1
	_last_rev = _run._reverse_time
	if _t >= SECONDS:
		var rms := sqrt(_sum_sq / maxf(_samples, 1))
		_total_rms += rms
		print("mapa %d: rabeada rms=%.2f máx=%.2f rad/s · rés %d · chegou a %.0f m" % [
			SEEDS[_seed_i], rms, _max_yaw, _revs, car.global_position.z])
		_run = null
		_next()
