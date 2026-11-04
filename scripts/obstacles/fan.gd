extends Obstacle
## Ventilador gigante na beira da trilha (Deserto): em rajadas, sopra o carro para o lado.
## Liga e desliga pelo relógio da corrida (params "ligado" e "desligado", em segundos).
## Fica do lado `off` da trilha e sopra para o outro lado.

const REACH := 15.0  # metros de vento atravessando a trilha
const WIDTH := 9.0  # metros ao longo da trilha
const FORCE := 8.0  # m/s² de empurrão

var _blades: MeshInstance3D
var _wind: CPUParticles3D
var _dir := Vector3.RIGHT  # para onde sopra (local)
var _on_time := 3.0
var _off_time := 2.0
var _phase := 0.0
var _inside := false
var _warned := false


func _build() -> void:
	_on_time = params.get("ligado", 3.0)
	_off_time = params.get("desligado", 2.0)
	_phase = params.get("fase", 0.0)
	# o objeto fica na beira (off); o vento vai para o centro e além
	var side := signf(params.get("off", -7.0))
	_dir = Vector3.RIGHT * -side if side != 0.0 else Vector3.RIGHT
	var body := StaticBody3D.new()
	var housing := _mesh("fan_body")
	housing.rotation.y = PI / 2.0 if _dir.x > 0.0 else -PI / 2.0  # boca virada para a trilha
	body.add_child(housing)
	body.add_child(_cylinder(0.35, 3.0, Vector3.UP * 1.5))
	add_child(body)
	_blades = _mesh("fan_blades")
	_blades.position = Vector3(_dir.x * 0.5, 2.6, 0)
	_blades.rotation.y = housing.rotation.y
	add_child(_blades)

	var zone := _box(Vector3(REACH, 4.0, WIDTH), Vector3(_dir.x * REACH / 2.0, 1.5, 0))
	var area := _trigger(zone, func(): _inside = true)
	area.body_exited.connect(func(b: Node3D):
		if b == car:
			_inside = false)
	add_child(area)
	_wind = Effects.wind(_dir, REACH, WIDTH)
	_wind.position = Vector3(_dir.x * 1.0, 1.6, 0)
	add_child(_wind)


func _blowing() -> bool:
	var cycle := _on_time + _off_time
	return fposmod(clock + _phase / TAU * cycle, cycle) < _on_time


func _physics_process(delta: float) -> void:
	var on := _blowing()
	_blades.rotate_object_local(Vector3.FORWARD, delta * (18.0 if on else 1.5))
	_wind.emitting = on
	if on and _inside and car != null:
		# empurrão um pouco à frente do centro: a traseira escorrega mais que a frente e, com
		# a força no centro, o carro virava o nariz CONTRA o vento e ia para o lado errado
		car.apply_force(global_basis * _dir * FORCE * car.mass, car.global_basis.z * 0.4)
		if not _warned:
			_warned = true
			_emit("wind")
