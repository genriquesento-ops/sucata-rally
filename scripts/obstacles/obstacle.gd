class_name Obstacle
extends Node3D
## Base dos elementos da trilha criados pela fábrica (ObstacleFactory): rampa, pedregulho,
## placa de boost, óleo, serra, martelo. Cada tipo é um script nesta pasta.
##
## A corrida atual registra aqui o carro, quem recebe os eventos e o relógio. O relógio é
## o tempo desde a largada, igual para todos os obstáculos: as armadilhas que se mexem
## calculam a posição por ele (e não somando delta), então ficam sempre em sincronia e,
## no mapa do dia, no mesmo ritmo para todo mundo.

static var car: Car  # carro da corrida (null fora dela, ex.: nos testes)
static var run: Node  # recebe on_obstacle(evento, dados)
static var clock := 0.0  # segundos desde a largada

## Camada de colisão só do carro: as áreas de gatilho (óleo, boost...) olham só para ela,
## sem gastar tempo testando o chão e as pedras.
const CAR_LAYER := 2

var params: Dictionary


func setup(xf: Transform3D, p: Dictionary) -> void:
	transform = xf
	params = p
	_build()


## Monta as malhas e colisões. Cada tipo sobrescreve.
func _build() -> void:
	pass


## Avisa a corrida (moedas de manobra, boost, batida...).
func _emit(event: String, data := {}) -> void:
	if run != null:
		run.on_obstacle(event, data)


## Posição do carro no espaço deste obstáculo (z = para a frente, ao longo da trilha).
func _car_local() -> Vector3:
	return to_local(car.global_position) if car != null else Vector3(0, 0, -INF)


static func _mesh(kind: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = Props.mesh(kind)
	return mi


static func _box(size: Vector3, pos := Vector3.ZERO) -> CollisionShape3D:
	var shape := BoxShape3D.new()
	shape.size = size
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position = pos
	return col


static func _cylinder(radius: float, height: float, pos := Vector3.ZERO) -> CollisionShape3D:
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position = pos
	return col


## Área que só detecta o carro e chama `on_enter` quando ele entra.
static func _trigger(shape: CollisionShape3D, on_enter: Callable) -> Area3D:
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = CAR_LAYER
	area.monitorable = false
	area.add_child(shape)
	area.body_entered.connect(func(body: Node3D):
		if body == car:
			on_enter.call())
	return area
