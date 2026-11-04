extends Node
## Troca entre Garagem e Corrida. Também tem o modo demo:
##   godot --path . -- --demo=C:/pasta   (acelera sozinho, salva screenshots e fecha)

var _current: Node
var _demo_dir := ""


func _ready() -> void:
	_setup_input()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--demo="):
			_demo_dir = arg.trim_prefix("--demo=")
		elif arg.begins_with("--demo-ui="):
			_demo_dir = arg.trim_prefix("--demo-ui=")
			_ui_tour()
			return
	if _demo_dir.is_empty():
		var title := TitleScreen.new()
		title.start.connect(show_garage)
		_swap(title)
	else:
		show_garage()
		_run_demo()


func show_garage() -> void:
	var garage := Garage.new()
	garage.start_requested.connect(start_run)
	_swap(garage)


func start_run(daily := false) -> Run:
	var run := Run.new()
	run.daily = daily
	run.finished.connect(show_garage)
	_swap(run)
	return run


func _swap(next: Node) -> void:
	if _current != null:
		_current.queue_free()
	_current = next
	add_child(next)


func _setup_input() -> void:
	# o carro acelera sozinho; no PC dá para virar pelo teclado além do mouse
	_add_action("steer_left", [KEY_LEFT, KEY_A])
	_add_action("steer_right", [KEY_RIGHT, KEY_D])


func _add_action(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for key in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = key
		InputMap.action_add_event(action, ev)


func _run_demo() -> void:
	await _wait(1.5)
	await _shot("1-garagem")
	var run := start_run()
	await _wait(0.5)
	await _drag_infinity(run)
	run.auto_drive = true
	for step in [[4.0, "3-largada"], [8.0, "4-corrida"]]:
		await _wait(step[0])
		print("DEMO ", step[1], " ", run.debug_line())
		await _shot(step[1])
		await get_tree().process_frame
		run.debug_line()  # zera o "pior frame": o screenshot trava o jogo e não conta
	# deixa a corrida ir até o fim, para conferir quanto se ganha numa primeira partida
	var limit := Time.get_ticks_msec() + 150000
	while not run.is_over() and Time.get_ticks_msec() < limit:
		await _wait(2.0)
		print("DEMO t ", run.debug_line())
	print("DEMO fim ", run.debug_line(), " moedas_total=", Save.coins)
	await _shot("5-fim")

	show_garage()
	await _wait(1.0)
	await _shot("6-garagem-depois")

	# mapa do dia com um estágio avançado, para conferir o visual
	Save.tier = 3
	Save.coins = 99999
	run = start_run(true)
	run.auto_drive = true
	await _wait(0.5)
	run.debug_line()  # zera o "pior frame" da largada (que gera o mapa inicial de uma vez)
	await _wait(5.5)
	print("DEMO 7-monstro ", run.debug_line())
	await _shot("7-monstro")
	get_tree().quit()


## Simula um dedo desenhando um "infinito" na tela por 4 s (testa o controle de direção).
func _drag_infinity(run: Run) -> void:
	var center := Vector2(640, 480)
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.position = center
	touch.pressed = true
	Input.parse_input_event(touch)
	var shot_taken := false
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < 4000:
		await get_tree().physics_frame
		var t := (Time.get_ticks_msec() - start) / 1000.0 * PI
		var d := 1.0 + sin(t) * sin(t)
		var drag := InputEventScreenDrag.new()
		drag.index = 0
		drag.position = center + Vector2(cos(t) / d, sin(t) * cos(t) / d) * 160.0
		Input.parse_input_event(drag)
		if int(t * 10) % 5 == 0:
			print("DEMO dedo_x=%.0f %s" % [drag.position.x, run.debug_line()])
		if not shot_taken and t > PI * 0.4:
			shot_taken = true
			await _shot("2-controle")
	touch.pressed = false
	Input.parse_input_event(touch)


## Tour de telas para conferir o visual: tela inicial, garagem, opções, os 5 carros e dicas.
func _ui_tour() -> void:
	var title := TitleScreen.new()
	_swap(title)
	await _wait(1.5)
	await _shot("ui-1-inicio")
	Save.coins = 500  # faz aparecer a dica da garagem
	show_garage()
	await _wait(1.0)
	await _shot("ui-2-garagem-dica")
	show_garage()
	await _wait(0.5)
	(_current as Garage)._open_settings()
	await _wait(0.5)
	await _shot("ui-3-opcoes")
	for tier in GameData.TIERS.size():
		Save.tier = tier
		Save.paint = [0, 2, 4, 6, 1][tier]
		show_garage()
		await _wait(1.2)
		await _shot("ui-4-carro-%d" % tier)
	Save.tier = 0
	Save.paint = 0
	var run := start_run()
	await _wait(2.0)
	await _shot("ui-5-dica-corrida")
	run.auto_drive = true
	await _wait(12.0)
	await _shot("ui-6-corrida")
	get_tree().quit()


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_demo_dir.path_join(name + ".png"))
