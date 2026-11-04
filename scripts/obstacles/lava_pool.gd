extends Obstacle
## Poça de lava (Vulcão): passar por cima queima combustível e dá um pulinho no carro.

const RADIUS := 2.0
const FUEL_LOSS := 0.15  # fração do tanque

var _used := false


func _build() -> void:
	var s: float = params.get("escala", 1.0)
	var mi := _mesh("lava")
	mi.scale = Vector3(s, 1.0, s)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	add_child(_trigger(_cylinder(RADIUS * s, 2.0, Vector3.UP * 0.5), func():
		if _used:
			return
		_used = true
		car.apply_central_impulse(Vector3.UP * car.mass * 2.5)
		_emit("lava", {"fuel": FUEL_LOSS, "pos": global_position + Vector3.UP * 0.3})))
