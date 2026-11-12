extends Obstacle
## Rampa de madeira (3 x 0,3 x 6,2 m) de um lado da trilha, já inclinada pelo trecho.
## No trechos.json fica a 3 m do centro (de 1,5 a 4,5 m): quem anda no meio passa ao lado.
## A 2 m, o carro no meio pegava a rampa só com as rodas de um lado e capotava.

const SIZE := Vector3(3.0, 0.3, 6.2)


func _build() -> void:
	var body := StaticBody3D.new()
	body.add_child(_mesh("ramp"))
	body.add_child(_box(SIZE))
	add_child(body)
