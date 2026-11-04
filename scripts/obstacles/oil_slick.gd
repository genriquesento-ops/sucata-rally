extends Obstacle
## Poça de óleo: passar por cima tira a aderência por um instante e dá uma rodada no carro.

const RADIUS := 1.9
const SLIP_SECONDS := 1.4

var _used := false


func _build() -> void:
	var s: float = params.get("escala", 1.0)
	var mi := _mesh("oil")
	mi.scale = Vector3(s, 1.0, s)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	add_child(_trigger(_cylinder(RADIUS * s, 2.0, Vector3.UP * 0.5), func():
		if _used:
			return
		_used = true
		# o lado da rodada vem da fase sorteada do trecho (igual no mapa do dia)
		car.slip(SLIP_SECONDS, 1.0 if sin(params.get("fase", 0.0)) >= 0.0 else -1.0)
		_emit("oil")))
