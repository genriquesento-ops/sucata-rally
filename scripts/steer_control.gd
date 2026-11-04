class_name SteerControl
extends Control
## Direção livre: encoste o dedo em qualquer lugar da tela e arraste para os lados.
## O ponto de referência acompanha o dedo quando ele passa do raio, e ao inverter o
## movimento (desenhando um "infinito") ele corre ao encontro do dedo: o carro troca
## de lado logo, sem precisar voltar o dedo até o ponto onde encostou.

const RADIUS := 75.0  # pixels de arrasto para virar o máximo, na sensibilidade 1 (menor = mais rápido)
const DEAD_ZONE := 8.0
const HINT_SECONDS := 4.0

var _radius := RADIUS  # ajustado pela sensibilidade nas opções
var _finger := -1
var _anchor := Vector2.ZERO
var _pos := Vector2.ZERO
var _value := 0.0  # -1 (esquerda da tela) .. 1 (direita)
var _hint_time := HINT_SECONDS


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_radius = RADIUS / maxf(Save.settings.steer, 0.1)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		if event.pressed and _finger == -1:
			_finger = event.index
			_anchor = event.position
			_pos = event.position
			_hint_time = 0.0
			_update()
		elif not event.pressed and event.index == _finger:
			_finger = -1
			_update()
	elif event is InputEventScreenDrag and event.index == _finger:
		var move: float = event.position.x - _pos.x
		_pos = event.position
		# voltando para o outro lado: a referência anda contra o dedo, então a direção
		# troca de lado com metade do arrasto (resposta rápida no zigue-zague)
		if move * (_pos.x - _anchor.x) < 0.0:
			_anchor.x -= move
		_anchor.x = clampf(_anchor.x, _pos.x - _radius, _pos.x + _radius)
		_anchor.y = _pos.y
		_update()


## Desliga o controle (fim da corrida).
func disable() -> void:
	_finger = -1
	_update()
	visible = false


func _exit_tree() -> void:
	Input.action_release("steer_left")
	Input.action_release("steer_right")


func _process(delta: float) -> void:
	if _hint_time > 0.0:
		_hint_time -= delta
		queue_redraw()


func _update() -> void:
	var dx := 0.0 if _finger == -1 else _pos.x - _anchor.x
	_value = 0.0 if absf(dx) < DEAD_ZONE else clampf(dx / _radius, -1.0, 1.0)
	_set_action("steer_right", maxf(_value, 0.0))
	_set_action("steer_left", maxf(-_value, 0.0))
	queue_redraw()


static func _set_action(action: String, strength: float) -> void:
	if strength > 0.0:
		Input.action_press(action, strength)
	else:
		Input.action_release(action)


func _draw() -> void:
	if _finger != -1:
		var white := Color(1, 1, 1, 0.3)
		draw_line(_anchor - Vector2(_radius, 0), _anchor + Vector2(_radius, 0), white, 6.0, true)
		draw_arc(_anchor, _radius, 0.0, TAU, 48, white, 3.0, true)
		draw_circle(Vector2(_anchor.x + _value * _radius, _anchor.y), 34.0, Color(1, 1, 1, 0.6))
	elif _hint_time > 0.0:
		_draw_hint(clampf(_hint_time, 0.0, 1.0))


## Dica no começo da corrida: um "infinito" com um dedo percorrendo.
func _draw_hint(alpha: float) -> void:
	var center := Vector2(size.x / 2.0, size.y - 150.0)
	var a := 90.0
	var points := PackedVector2Array()
	for i in 65:
		points.append(center + _lemniscate(TAU * i / 64.0) * a)
	draw_polyline(points, Color(1, 1, 1, 0.5 * alpha), 4.0, true)
	var t := fmod(HINT_SECONDS - _hint_time, 2.0) / 2.0 * TAU
	draw_circle(center + _lemniscate(t) * a, 16.0, Color(1, 1, 1, 0.85 * alpha))
	var font := get_theme_default_font()
	draw_string(font, Vector2(0, size.y - 50.0), "Arraste o dedo para os lados para dirigir",
		HORIZONTAL_ALIGNMENT_CENTER, size.x, 28, Color(1, 1, 1, alpha))


static func _lemniscate(t: float) -> Vector2:
	var d := 1.0 + sin(t) * sin(t)
	return Vector2(cos(t) / d, sin(t) * cos(t) / d)
