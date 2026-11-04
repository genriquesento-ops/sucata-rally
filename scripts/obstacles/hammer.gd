extends Obstacle
## Martelo pêndulo num pórtico sobre a trilha: balança de um lado para o outro e, embaixo,
## passa na altura do carro. É preciso passar no momento certo; passar sem levar a
## martelada vale manobra. Ângulo = máximo × sen(2π·t/período + fase), pelo relógio da corrida.

const PIVOT := 6.6  # altura do eixo
const ARM := 5.0  # do eixo até o centro da cabeça
const HEAD := Vector3(2.2, 1.4, 1.4)
const POST_X := 6.2
const PUSH := 8.0

var _arm: AnimatableBody3D
var _max := deg_to_rad(60.0)
var _period := 2.6
var _phase := 0.0
var _hit := false
var _seen := false
var _done := false


func _build() -> void:
	_max = deg_to_rad(params.get("angulo", 60.0))
	_period = params.get("periodo", 2.6)
	_phase = params.get("fase", 0.0)
	var frame := StaticBody3D.new()
	frame.add_child(_mesh("hammer_frame"))
	for side in [-1.0, 1.0]:
		frame.add_child(_cylinder(0.3, PIVOT + 0.4, Vector3(side * POST_X, PIVOT / 2.0, 0.0)))
	add_child(frame)
	_arm = AnimatableBody3D.new()
	_arm.position = Vector3.UP * PIVOT
	_arm.add_child(_mesh("hammer_arm"))
	_arm.add_child(_box(HEAD, Vector3.DOWN * ARM))
	_arm.add_child(_trigger(_box(HEAD + Vector3(0.6, 0.6, 0.8), Vector3.DOWN * ARM), _on_hit))
	add_child(_arm)
	_swing()


func _physics_process(_delta: float) -> void:
	_swing()
	if _done:
		return
	var local := _car_local()
	if local.z < -2.0 and local.z > -30.0:
		_seen = true
	elif _seen and local.z > 1.5:
		_done = true
		if not _hit:
			_emit("dodge", {"text": "PASSOU DO MARTELO!", "coins": 5})


func _angle_at(t: float) -> float:
	return _max * sin(TAU * t / _period + _phase)


func _swing() -> void:
	_arm.rotation.z = _angle_at(clock)


func _on_hit() -> void:
	_hit = true
	# empurra para o lado em que a cabeça está indo (o sinal da velocidade do pêndulo)
	var going := signf(cos(TAU * clock / _period + _phase))
	if going == 0.0:
		going = 1.0
	car.apply_central_impulse((global_basis.x * going * PUSH + Vector3.UP * 3.0) * car.mass)
	_emit("hit", {"pos": _arm.to_global(Vector3.DOWN * ARM)})
