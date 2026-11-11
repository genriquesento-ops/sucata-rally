class_name Car
extends VehicleBody3D
## Carro com física de veículo do Godot (suspensão por raycast em cada roda).
## Frente = +Z local. steering positivo vira para +X local (esquerda do carro).

var stats: Dictionary
var throttle := 0.0  # 0..1
var brake_input := 0.0  # 0..1 (freia; parado, dá ré)
var steer_input := 0.0  # -1 (direita) .. 1 (esquerda)
var grip := 1.0  # multiplicador da região atual

## Rodas de trás com um pouco menos de aderência: a traseira escorrega de leve nas curvas.
const REAR_GRIP := 0.85
const BOOST_SECONDS := 1.5

var _wheels: Array[VehicleWheel3D] = []
var _boost_time := 0.0
var _slip_time := 0.0  # óleo, gelo
var _slip_grip := 0.3
var _dust: CPUParticles3D
var _boost_flame: CPUParticles3D
var _rocket_flame: CPUParticles3D  # só no Foguete


func _enter_tree() -> void:
	add_to_group("car")  # o painel de diagnóstico lê o volante daqui


func setup(tier: int, car_stats: Dictionary, paint := 0) -> void:
	stats = car_stats
	collision_layer = 1 | Obstacle.CAR_LAYER  # camada 2: só o carro (as áreas de óleo/boost olham para ela)
	var t: Dictionary = GameData.TIERS[tier]
	var size: Vector3 = t.size
	mass = t.mass
	# centro de massa baixo = mais difícil de capotar
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, -size.y * 0.8 - t.wheel * 0.6, 0)

	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	col.shape = box
	add_child(col)
	add_child(CarModel.build_body(tier, paint))
	var hub_color := CarModel.paint_color(tier, paint)

	for p in CarModel.wheel_positions(tier):
		var w := VehicleWheel3D.new()
		w.position = p
		w.wheel_radius = t.wheel
		w.wheel_rest_length = CarModel.REST_LENGTH
		w.suspension_travel = stats.travel
		w.suspension_stiffness = stats.stiffness
		w.suspension_max_force = mass * 12.0
		w.damping_compression = stats.compression
		w.damping_relaxation = stats.relaxation
		w.wheel_friction_slip = stats.friction
		w.wheel_roll_influence = 0.2
		w.use_as_traction = true
		w.use_as_steering = p.z > 0.0
		w.add_child(CarModel.build_wheel(t.wheel, hub_color))
		add_child(w)
		_wheels.append(w)

	var rear := Vector3(0, -size.y / 2.0 - t.wheel * 0.5, -size.z * 0.4)
	_dust = Effects.dust()
	_dust.position = rear
	add_child(_dust)
	_boost_flame = Effects.flame(Color("30a8ff"))
	_boost_flame.position = Vector3(0, 0, -size.z / 2.0 - 0.2)
	add_child(_boost_flame)
	if tier == 4:
		_rocket_flame = Effects.flame(Color("ff6a10"))
		_rocket_flame.position = Vector3(0, 0.1, -size.z / 2.0 - 0.6)
		add_child(_rocket_flame)


## Cor da poeira (a cor da trilha da região).
func set_dust_color(color: Color) -> void:
	_dust.color = color.lightened(0.55)


func forward_speed() -> float:
	return linear_velocity.dot(global_basis.z)


func on_ground() -> bool:
	for w in _wheels:
		if w.is_in_contact():
			return true
	return false


## Quanto o carro está de cabeça para baixo (1 = em pé, -1 = virado).
func uprightness() -> float:
	return global_basis.y.y


## Boost: empurrão para a frente e velocidade máxima 40% maior por um instante.
## strength 1 = placa de boost; o mini-boost do pouso perfeito usa menos.
## O Nitro (stats.boost_power) aumenta força e duração.
func boost(strength := 1.0) -> void:
	var power: float = stats.boost_power * strength
	_boost_time = maxf(_boost_time, BOOST_SECONDS * power)
	apply_central_impulse(global_basis.z * mass * 6.0 * power)


func is_boosting() -> bool:
	return _boost_time > 0.0


## Óleo, gelo: aderência multiplicada por `grip_mult` por alguns segundos e um giro para o
## lado `side` (±1), com força `spin`.
func slip(seconds: float, side: float, grip_mult := 0.3, spin := 1.0) -> void:
	_slip_time = maxf(_slip_time, seconds)
	_slip_grip = grip_mult
	apply_torque_impulse(global_basis.y * side * mass * 1.2 * spin)


func _physics_process(delta: float) -> void:
	var speed := forward_speed()
	var force: float = stats.engine_force
	var top: float = stats.top_speed
	if _boost_time > 0.0:
		_boost_time -= delta
		top *= 1.4
		force *= 2.0
	brake = 0.0
	if throttle > 0.0:
		engine_force = throttle * force if speed < top else 0.0
	elif brake_input > 0.0:
		if speed > 1.0:
			engine_force = 0.0
			brake = brake_input * mass * 0.3
		else:
			engine_force = -brake_input * force * 0.4 if speed > -5.0 else 0.0  # ré, até 5 m/s
	else:
		engine_force = 0.0
		brake = mass * 0.02  # leve resistência ao rolar

	# em alta velocidade a direção vira menos, para não capotar nas curvas
	var max_steer := lerpf(0.6, 0.2, clampf(absf(speed) / 30.0, 0.0, 1.0))
	steering = move_toward(steering, steer_input * max_steer, delta * 6.0)

	var oil := 1.0
	if _slip_time > 0.0:
		_slip_time -= delta
		oil = _slip_grip
	for w in _wheels:
		w.wheel_friction_slip = stats.friction * grip * oil * (1.0 if w.use_as_steering else REAR_GRIP)

	var grounded := on_ground()
	_dust.emitting = grounded and absf(speed) > 4.0
	_boost_flame.emitting = _boost_time > 0.0
	if _rocket_flame != null:
		_rocket_flame.emitting = throttle > 0.0

	# no ar o carro tende a se endireitar sozinho, para cair de rodas
	if not grounded:
		var tilt := global_basis.y.cross(Vector3.UP)
		var spin := angular_velocity - Vector3.UP * angular_velocity.dot(Vector3.UP)
		apply_torque((tilt * 2.0 - spin * 0.6) * mass)
