extends Node
## Simula toques de celular (InputEventScreenTouch, sem mouse) na tela inicial e confere se ela avança.
##   godot --headless --path . res://tests/touch_test.tscn  (cena, para carregar os autoloads)

const POINTS := [Vector2(640, 360), Vector2(640, 650), Vector2(100, 100)]

var _title: TitleScreen
var _ok := false
var _frame := 0
var _failed := 0


func _ready() -> void:
	_title = TitleScreen.new()
	_title.start.connect(func() -> void: _ok = true)
	get_tree().root.add_child.call_deferred(_title)


func _process(_delta: float) -> void:
	_frame += 1
	var step := _frame - 5
	if step < 0:
		return
	var i := step / 3
	if i >= POINTS.size():
		print("RESULTADO: ", "tudo OK" if _failed == 0 else "%d falha(s)" % _failed)
		get_tree().quit(_failed)
		return
	var t := InputEventScreenTouch.new()
	t.position = POINTS[i]
	match step % 3:
		0:
			_ok = false
			_title._started = false
			t.pressed = true
			get_viewport().push_input(t)
		1:
			t.pressed = false
			get_viewport().push_input(t)
		2:
			print("toque em ", POINTS[i], ": ", "OK" if _ok else "FALHOU")
			if not _ok:
				_failed += 1

