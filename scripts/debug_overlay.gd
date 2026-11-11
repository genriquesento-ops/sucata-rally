extends CanvasLayer
## Diagnóstico na tela, só no APK de debug do celular (sem adb não dá para ver o log).
## Mostra um contador de quadros (se parar, o jogo travou), os toques recebidos e os
## últimos erros/avisos do Godot em vermelho. Nas versões release e no PC fica desligado.

const MAX_LINES := 6

var _label: Label
var _frames := 0
var _touches := 0
var _lines: PackedStringArray = []
var _mutex := Mutex.new()


class ErrorLogger extends Logger:
	var overlay: Node

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		var kind := "AVISO" if error_type == ERROR_TYPE_WARNING else "ERRO"
		var text := rationale if not rationale.is_empty() else code
		overlay.add_line("%s: %s (%s:%d %s)" % [kind, text, file.get_file(), line, function])

	func _log_message(_message: String, _error: bool) -> void:
		pass


func _ready() -> void:
	if not (OS.is_debug_build() and OS.has_feature("mobile")) and not OS.get_cmdline_user_args().has("--debug-overlay"):
		queue_free()
		return
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS
	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.position = Vector2(8, 4)
	_label.add_theme_font_size_override("font_size", 13)
	_label.add_theme_color_override("font_color", Color("ff6b6b"))
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 4)
	add_child(_label)
	var logger := ErrorLogger.new()
	logger.overlay = self
	OS.add_logger(logger)


## Pode ser chamado de qualquer thread (o Logger roda na thread que deu o erro).
func add_line(text: String) -> void:
	_mutex.lock()
	_lines.append(text.left(160))
	if _lines.size() > MAX_LINES:
		_lines.remove_at(0)
	_mutex.unlock()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		_touches += 1


func _process(_delta: float) -> void:
	_frames += 1
	if _frames % 10 != 0:
		return
	_mutex.lock()
	var errors := "\n".join(_lines)
	_mutex.unlock()
	_label.text = "debug · quadro %d · %d fps · toques %d\n%s" % [
		_frames, Engine.get_frames_per_second(), _touches, errors]
