class_name UiIcon
extends Control
## Ícones desenhados por código (sem imagens nem emojis, que mudam de celular para celular).
## Uso: UiIcon.make("motor", 40). Tipos: coin, motor, tires, suspension, tank, magnet, nitro,
## trophy, gear, calendar, flag, target.

var kind := "coin"
var tint := Color.WHITE


static func make(icon_kind: String, px := 32.0, color := Color.WHITE) -> UiIcon:
	var icon := UiIcon.new()
	icon.kind = icon_kind
	icon.tint = color
	icon.custom_minimum_size = Vector2(px, px)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


func _draw() -> void:
	var s := minf(size.x, size.y)
	var c := size / 2.0
	# tudo é desenhado num quadrado de -1..1 em volta do centro
	draw_set_transform(c, 0.0, Vector2(s / 2.0, s / 2.0))
	match kind:
		"coin": _coin()
		"motor": _motor()
		"tires": _tires()
		"suspension": _suspension()
		"tank": _tank()
		"magnet": _magnet()
		"nitro": _nitro()
		"trophy": _trophy()
		"gear": _gear()
		"calendar": _calendar()
		"flag": _flag()
		"target": _target()
	draw_set_transform(Vector2.ZERO)


func _rect(x: float, y: float, w: float, h: float, color: Color) -> void:
	draw_rect(Rect2(x, y, w, h), color)


func _coin() -> void:
	draw_circle(Vector2.ZERO, 0.92, Color("b8860b"))
	draw_circle(Vector2.ZERO, 0.8, Color("ffd23f"))
	draw_arc(Vector2.ZERO, 0.52, 0.0, TAU, 24, Color("e0a800"), 0.14, true)
	draw_circle(Vector2(-0.3, -0.32), 0.12, Color(1, 1, 1, 0.75))


func _motor() -> void:
	var metal := Color("aab4c4")
	var dark := Color("5c6678")
	_rect(-0.7, -0.15, 1.3, 0.75, metal)  # bloco
	_rect(-0.55, -0.55, 0.3, 0.4, dark)  # cilindros
	_rect(-0.15, -0.55, 0.3, 0.4, dark)
	_rect(0.25, -0.55, 0.3, 0.4, dark)
	_rect(-0.62, -0.72, 1.24, 0.2, metal)  # cabeçote
	_rect(0.6, 0.05, 0.3, 0.22, Color("e0a800"))  # saída
	_rect(-0.95, 0.1, 0.25, 0.3, dark)  # polia
	draw_circle(Vector2(-0.3, 0.25), 0.14, dark)
	draw_circle(Vector2(0.2, 0.25), 0.14, dark)


func _tires() -> void:
	draw_circle(Vector2.ZERO, 0.92, Color("2a2a2e"))
	draw_circle(Vector2.ZERO, 0.55, Color("aab4c4"))
	draw_circle(Vector2.ZERO, 0.2, Color("5c6678"))
	for i in 5:
		var d := Vector2.from_angle(TAU * i / 5.0 - PI / 2.0)
		draw_line(d * 0.2, d * 0.52, Color("5c6678"), 0.1)
	for i in 10:
		var d := Vector2.from_angle(TAU * i / 10.0)
		draw_line(d * 0.78, d * 0.92, Color("55555c"), 0.1)


func _suspension() -> void:
	var points := PackedVector2Array()
	for i in 9:
		points.append(Vector2(-0.45 if i % 2 == 0 else 0.45, -0.6 + i * 0.15))
	draw_polyline(points, Color("ff7043"), 0.16, true)
	_rect(-0.6, -0.9, 1.2, 0.22, Color("aab4c4"))
	_rect(-0.6, 0.68, 1.2, 0.22, Color("aab4c4"))


func _tank() -> void:
	var red := Color("e04848")
	draw_colored_polygon(PackedVector2Array([Vector2(-0.6, -0.5), Vector2(0.25, -0.5), Vector2(0.65, -0.1),
		Vector2(0.65, 0.9), Vector2(-0.6, 0.9)]), red)
	_rect(-0.45, -0.9, 0.5, 0.28, Color("aab4c4"))  # tampa
	draw_line(Vector2(-0.3, 0.0), Vector2(0.35, 0.65), Color(1, 1, 1, 0.55), 0.12)
	draw_line(Vector2(0.35, 0.0), Vector2(-0.3, 0.65), Color(1, 1, 1, 0.55), 0.12)


func _magnet() -> void:
	var red := Color("e04848")
	draw_arc(Vector2(0, 0.1), 0.55, 0.0, PI, 20, red, 0.42, true)
	_rect(-0.76, -0.55, 0.42, 0.67, red)
	_rect(0.34, -0.55, 0.42, 0.67, red)
	_rect(-0.76, -0.9, 0.42, 0.36, Color("e8eef5"))
	_rect(0.34, -0.9, 0.42, 0.36, Color("e8eef5"))


func _nitro() -> void:
	draw_colored_polygon(PackedVector2Array([Vector2(0, -0.95), Vector2(0.5, -0.2), Vector2(0.62, 0.35),
		Vector2(0.35, 0.8), Vector2(0, 0.92), Vector2(-0.35, 0.8), Vector2(-0.62, 0.35), Vector2(-0.4, -0.25),
		Vector2(-0.2, 0.05)]), Color("ff7a1a"))
	draw_colored_polygon(PackedVector2Array([Vector2(0.05, -0.2), Vector2(0.32, 0.4), Vector2(0.18, 0.75),
		Vector2(0, 0.82), Vector2(-0.2, 0.72), Vector2(-0.3, 0.4)]), Color("ffd23f"))


func _trophy() -> void:
	var gold := Color("ffd23f")
	draw_colored_polygon(PackedVector2Array([Vector2(-0.55, -0.85), Vector2(0.55, -0.85), Vector2(0.4, 0.0),
		Vector2(0.12, 0.25), Vector2(-0.12, 0.25), Vector2(-0.4, 0.0)]), gold)
	draw_arc(Vector2(-0.55, -0.45), 0.28, PI * 0.5, PI * 1.5, 10, gold, 0.12, true)
	draw_arc(Vector2(0.55, -0.45), 0.28, -PI * 0.5, PI * 0.5, 10, gold, 0.12, true)
	_rect(-0.1, 0.2, 0.2, 0.35, gold)
	_rect(-0.45, 0.55, 0.9, 0.3, Color("b8860b"))


func _gear() -> void:
	for i in 8:
		var d := Vector2.from_angle(TAU * i / 8.0)
		draw_line(d * 0.5, d * 0.92, tint, 0.3)
	draw_circle(Vector2.ZERO, 0.68, tint)
	draw_circle(Vector2.ZERO, 0.28, Color(0, 0, 0, 0.55))


func _calendar() -> void:
	_rect(-0.8, -0.65, 1.6, 1.5, tint)
	_rect(-0.8, -0.65, 1.6, 0.42, Color("e04848"))
	_rect(-0.5, -0.92, 0.16, 0.4, tint)
	_rect(0.34, -0.92, 0.16, 0.4, tint)
	for i in 6:
		_rect(-0.58 + (i % 3) * 0.44, 0.0 + (i / 3) * 0.4, 0.28, 0.24, Color(0, 0, 0, 0.35))


func _flag() -> void:
	_rect(-0.75, -0.9, 0.14, 1.8, tint)
	for row in 3:
		for col in 4:
			_rect(-0.6 + col * 0.34, -0.85 + row * 0.3, 0.34, 0.3,
				tint if (row + col) % 2 == 0 else Color(0, 0, 0, 0.6))


func _target() -> void:
	draw_circle(Vector2.ZERO, 0.9, tint)
	draw_circle(Vector2.ZERO, 0.62, Color(0, 0, 0, 0.5))
	draw_circle(Vector2.ZERO, 0.36, tint)
