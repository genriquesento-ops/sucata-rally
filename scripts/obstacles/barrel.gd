extends Obstacle
## Barril que sai de um portão e rola pela trilha na direção do carro, seguindo o relevo
## (alturas amostradas pelo trecho em params "chao"). Bater empurra o carro para trás;
## passar por ele sem bater vale manobra. Posição pelo relógio: rola em ciclo, sem física.

const RADIUS := 0.55
const LENGTH := 1.1
const PUSH := 6.0

var _body: AnimatableBody3D
var _spin: MeshInstance3D
var _ground := PackedFloat32Array()
var _start := -14  # metro (z local) da primeira amostra do chão
var _length := 28.0  # metros rolados por volta
var _speed := 6.0
var _phase := 0.0
var _hit := false
var _seen := false
var _done := false


func _build() -> void:
	_ground = params.get("chao", PackedFloat32Array())
	_length = _ground.size() - 1.0 if _ground.size() > 1 else _length
	_start = -int(_length / 2.0)
	_speed = params.get("velocidade", 6.0)
	_phase = params.get("fase", 0.0)
	var gate := _mesh("barrel_gate")
	gate.position = Vector3(0, _height_at(-_start), -_start + 0.6)
	add_child(gate)
	_body = AnimatableBody3D.new()
	_spin = _mesh("barrel")
	_body.add_child(_spin)
	var col := _cylinder(RADIUS, LENGTH)
	col.rotation.z = PI / 2.0  # deitado: eixo em x
	_body.add_child(col)
	var zone := _cylinder(RADIUS + 0.35, LENGTH + 0.5)
	zone.rotation.z = PI / 2.0
	_body.add_child(_trigger(zone, _on_hit))
	add_child(_body)
	_roll()


func _physics_process(_delta: float) -> void:
	_roll()
	if _done:
		return
	var local := _car_local()
	if local.z < _start - 1.0 and local.z > _start - 30.0:
		_seen = true
	elif _seen and local.z > -_start + 1.0:
		_done = true
		if not _hit:
			_emit("dodge", {"text": "DESVIOU DO BARRIL!", "coins": 3, "tipo": "barril"})


## Altura do chão (relativa ao objeto) no metro z local.
func _height_at(z: float) -> float:
	if _ground.is_empty():
		return 0.0
	var u := clampf(z - _start, 0.0, _ground.size() - 1.0)
	var i := mini(int(u), _ground.size() - 2)
	return lerpf(_ground[i], _ground[i + 1], u - i)


func _roll() -> void:
	var s := fposmod(clock * _speed + _phase * _length / TAU, _length)
	var z := -_start - s  # sai do portão (z alto) e rola para trás, contra o carro
	# some por baixo da terra perto das pontas, para não "piscar" ao recomeçar
	var hide := clampf(minf(s, _length - s) / 1.5, 0.0, 1.0)
	_body.position = Vector3(0, _height_at(z) + RADIUS - (1.0 - hide) * 1.4, z)
	_spin.rotation.x = -s / RADIUS


func _on_hit() -> void:
	_hit = true
	car.apply_central_impulse((-global_basis.z * PUSH + Vector3.UP * 2.5) * car.mass)
	_emit("hit", {"pos": _body.global_position.lerp(car.global_position, 0.5)})
