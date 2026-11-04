extends SceneTree
## Teste de física sem janela: acelera cada estágio do carro num chão plano e mede a velocidade.
##   godot --headless --path . --script res://tests/drive_test.gd

const ACCEL_UNTIL := 4.0
const SECONDS := 6.0

var _cars: Array = []
var _time := 0.0
var _printed := false


func _initialize() -> void:
	var levels := {"motor": 0, "tires": 0, "suspension": 0, "tank": 0, "magnet": 0}
	for tier in GameData.TIERS.size():
		var world := Node3D.new()
		root.add_child(world)
		var ground := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(400, 1, 400)
		shape.shape = box
		ground.add_child(shape)
		ground.position = Vector3(tier * 30.0, -0.5, 0)
		world.add_child(ground)
		var car := Car.new()
		car.setup(tier, GameData.stats(tier, levels))
		car.position = Vector3(tier * 30.0, 1.5, 0)
		world.add_child(car)
		_cars.append(car)


func _physics_process(delta: float) -> bool:
	_time += delta
	for car: Car in _cars:
		car.throttle = 1.0 if _time > 0.5 and _time < ACCEL_UNTIL else 0.0
		car.brake_input = 1.0 if _time >= ACCEL_UNTIL else 0.0
	if _time >= ACCEL_UNTIL and not _printed:
		_printed = true
		_report("acelerou 3.5s")
	if _time >= SECONDS:
		_report("freou 2s")
		return true
	return false


func _report(label: String) -> void:
	for i in _cars.size():
		var car: Car = _cars[i]
		print("%s tier=%d fwd_speed=%.2f top=%.1f z=%.2f upright=%.2f" % [
			label, i, car.forward_speed(), car.stats.top_speed, car.position.z, car.uprightness()])
