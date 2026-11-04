extends Obstacle
## Pedregulho na trilha. Passar raspando ao lado (sem bater) vale manobra.

const RADIUS := 1.0
const NEAR_GAP := 1.6  # metros entre a lateral do carro e a pedra

var _done := false


func _build() -> void:
	var s: float = params.get("escala", 1.0)
	var body := StaticBody3D.new()
	var mi := _mesh("boulder")
	mi.scale = Vector3.ONE * s
	body.add_child(mi)
	body.add_child(_cylinder(RADIUS * s, 2.4 * s, Vector3.UP * 0.9 * s))
	add_child(body)


func _physics_process(_delta: float) -> void:
	if _done or car == null:
		return
	var p := car.global_position
	if absf(p.z - global_position.z) > 0.6:
		return
	_done = true
	# mede em x do mundo (a pedra pode estar girada), descontando meia largura do carro
	var gap := absf(p.x - global_position.x) - RADIUS * float(params.get("escala", 1.0)) - 0.9
	if gap > 0.15 and gap < NEAR_GAP:
		_emit("near")
