extends Obstacle
## Mancha escorregadia (óleo, gelo): passar por cima tira a aderência por um instante e dá
## uma rodada no carro. params: "malha", "aderencia" (multiplicador), "segundos", "giro",
## "evento" (o que avisa a corrida).

const RADIUS := 2.2

var _used := false


func _build() -> void:
	var s: float = params.get("escala", 1.0)
	var mi := _mesh(params.get("malha", "oil"))
	mi.scale = Vector3(s, 1.0, s)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	add_child(_trigger(_cylinder(RADIUS * s, 2.0, Vector3.UP * 0.5), func():
		if _used:
			return
		_used = true
		# o lado da rodada vem da fase sorteada do trecho (igual no mapa do dia)
		var side := 1.0 if sin(params.get("fase", 0.0)) >= 0.0 else -1.0
		car.slip(params.get("segundos", 1.4), side, params.get("aderencia", 0.3), params.get("giro", 1.0))
		_emit(params.get("evento", "oil"))))
