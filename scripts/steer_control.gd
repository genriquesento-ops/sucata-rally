class_name SteerControl
extends Control
## Direção livre: encoste o dedo em qualquer lugar da tela e arraste para os lados.
## A direção é a distância do dedo até o ponto onde encostou. Se o dedo passar do raio,
## o ponto de referência vai junto, então voltar um pouco já começa a desvirar.
## (Antes a referência corria contra o dedo ao inverter, mas no celular o tremor do dedo
## fazia o volante oscilar sozinho.)

const RADIUS := 150.0  # unidades da tela (altura 720) para virar o máximo, na sensibilidade 1
const DEAD_ZONE := 16.0  # ignora o tremor do dedo parado
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
		_pos = event.position
		_anchor.x = clampf(_anchor.x, _pos.x - _radius, _pos.x + _radius)
		_anchor.y = _pos.y
		_update()


## No PC dá para virar pelas setas/A/D: não confundir com ação presa.
static func _keyboard_steering() -> bool:
	for key in [KEY_LEFT, KEY_RIGHT, KEY_A, KEY_D]:
		if Input.is_physical_key_pressed(key):
			return true
	return false


## Desliga o controle (fim da corrida).
func disable() -> void:
	_finger = -1
	_update()
	visible = false


func _exit_tree() -> void:
	Input.action_release("steer_left")
	Input.action_release("steer_right")


func _notification(what: int) -> void:
	# app perdeu o foco (notificação, tela desligada): o Android pode não mandar o "soltou"
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_WINDOW_FOCUS_OUT]:
		_finger = -1
		_update()


func _process(delta: float) -> void:
	# sem dedo na tela a direção é zero, sempre (proteção contra ação "presa")
	if _finger == -1 and (Input.is_action_pressed("steer_left") or Input.is_action_pressed("steer_right")) \
			and not _keyboard_steering():
		Input.action_release("steer_left")
		Input.action_release("steer_right")
	if _hint_time > 0.0:
		_hint_time -= delta
		queue_redraw()


func _update() -> void:
	var dx := 0.0 if _finger == -1 else _pos.x - _anchor.x
	# zona morta sem "degrau": depois dela a direção cresce desde zero até o máximo
	var amount := clampf((absf(dx) - DEAD_ZONE) / (_radius - DEAD_ZONE), 0.0, 1.0)
	_value = signf(dx) * amount
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
