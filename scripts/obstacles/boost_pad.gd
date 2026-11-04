extends Obstacle
## Placa de boost (2,6 x 3 m) no centro da trilha: passar por cima dá um empurrão.

var _used := false


func _build() -> void:
	add_child(_mesh("boost_pad"))
	add_child(_trigger(_box(Vector3(3.6, 2.0, 4.0), Vector3.UP * 0.8), func():
		if not _used:
			_used = true
			_emit("boost")))
