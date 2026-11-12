class_name LevelBar
extends Control
## Barra de nível em segmentos (um quadradinho por nível), usada nos cartões das peças.

var value := 0:
	set(v):
		value = v
		queue_redraw()
var max_value := 5:
	set(v):
		max_value = v
		queue_redraw()
var fill := Color("7cc04b")
var empty := Color(1, 1, 1, 0.12)


func _init() -> void:
	custom_minimum_size = Vector2(60, 10)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var n := maxi(max_value, 1)
	var gap := 3.0 if n <= 15 else 2.0
	var w := (size.x - gap * (n - 1)) / n
	for i in n:
		var rect := Rect2(i * (w + gap), 0, w, size.y)
		draw_rect(rect, fill if i < value else empty)
