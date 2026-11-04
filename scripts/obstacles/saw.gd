extends Obstacle
## Serra circular gigante que rola de um lado para o outro da trilha, num trilho no chão.
## Bater nela empurra o carro para longe; passar sem bater vale manobra.
## A posição vem do relógio da corrida: x = amplitude × sen(2π·t/período + fase).

const RADIUS := 1.3
const THICKNESS := 0.35
const PUSH := 7.0  # m/s de empurrão para o lado

var _blade: AnimatableBody3D
var _spin: MeshInstance3D
var _amp := 4.2
var _period := 3.0
var _phase := 0.0
var _hit := false
var _seen := false  # o carro já esteve antes da serra (para contar a passagem)
var _done := false


func _build() -> void:
	_amp = params.get("amplitude", 4.2)
	_period = params.get("periodo", 3.0)
	_phase = params.get("fase", 0.0)
	add_child(_mesh("saw_rail"))
	_blade = AnimatableBody3D.new()
	_spin = _mesh("saw")
	_blade.add_child(_spin)
	# disco de pé, virado para o carro: cilindro com o eixo ao longo de z
	var col := _cylinder(RADIUS, THICKNESS)
	col.rotation.x = PI / 2.0
	_blade.add_child(col)
	var zone := _cylinder(RADIUS + 0.4, THICKNESS + 1.2)
	zone.rotation.x = PI / 2.0
	_blade.add_child(_trigger(zone, _on_hit))
	add_child(_blade)
	_place()


func _physics_process(_delta: float) -> void:
	_place()
	if _done:
		return
	var local := _car_local()
	if local.z < -2.0 and local.z > -30.0:
		_seen = true
	elif _seen and local.z > 1.5:
		_done = true
		if not _hit:
			_emit("dodge", {"text": "DESVIOU DA SERRA!", "coins": 4, "tipo": "serra"})


func _place() -> void:
	var x := _amp * sin(TAU * clock / _period + _phase)
	_blade.position = Vector3(x, RADIUS + 0.05, 0.0)
	_spin.rotation.z = -x / RADIUS  # rola sem escorregar


func _on_hit() -> void:
	_hit = true
	var away := car.global_position - _blade.global_position
	away.y = 0.0
	away = away.normalized() if away.length() > 0.1 else global_basis.x
	car.apply_central_impulse((away * PUSH + Vector3.UP * 2.0) * car.mass)
	_emit("hit", {"pos": _blade.global_position.lerp(car.global_position, 0.5)})
