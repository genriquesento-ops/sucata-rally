class_name Run
extends Node3D
## Uma corrida: ir o mais longe possível (+Z) até acabar o combustível ou capotar.
## Manobras dão moedas extras: tempo no ar, pouso perfeito e passar raspando por pedras,
## com combo multiplicador se encadeadas em até 3 s.

signal finished

const START_Z := 5.0
const AIR_MIN := 0.7  # segundos no ar para contar como salto
const COMBO_WINDOW := 3.0
const NEAR_MISS_GAP := 1.6  # metros entre a lateral do carro e a pedra

var auto_drive := false  # usado pelo modo demo
var daily := false  # mapa do dia (semente fixa pela data); definir antes de entrar na cena
var distance := 0.0
var run_coins := 0
var fuel := 0.0

var _stats: Dictionary
var _terrain_seed := 0
var _terrain: Terrain
var _pickups: Pickups
var _car: Car
var _cam: Camera3D
var _cam_fwd := Vector3.BACK  # +Z
var _hud: Hud
var _env: Environment
var _sky: ProceduralSkyMaterial
var _weather: CPUParticles3D  # neve/cinzas, preso à câmera
var _biome := -1
var _best_z := START_Z
var _stuck := 0.0
var _flipped := 0.0
var _empty := 0.0
var _end_reason := ""

# ré automática
var _blocked := 0.0
var _reverse_time := 0.0
var _reverse_steer := 0.0

# manobras e contadores (para as missões)
var _air_time := 0.0
var _combo := 0
var _combo_time := 0.0
var _trick_coins := 0
var _counts := {"jumps": 0, "perfect": 0, "near": 0, "boosts": 0}
var _last_boost := -1  # índice do último trecho de boost usado (cada placa vale uma vez)
var _near_done := {}  # pedras já contadas: "trecho:n"
var _layouts := {}  # trecho -> layout das pedras (cache)

# impacto
var _shake := 0.0
var _prev_speed := 0.0


func _ready() -> void:
	var seed_value := GameData.daily_seed() if daily else randi()
	_terrain_seed = seed_value
	# qualidade baixa (opções): metade dos objetos do cenário, sem antisserrilhado e sem sombras
	var high: bool = Save.settings.quality == 1
	Props.density_scale = 1.0 if high else 0.5
	get_viewport().msaa_3d = Viewport.MSAA_2X if high else Viewport.MSAA_DISABLED
	_terrain = Terrain.new()
	_terrain.setup(seed_value)
	add_child(_terrain)
	_terrain.generate_all(Vector3(0, 0, START_Z))
	_pickups = Pickups.new()
	_pickups.setup(_terrain, seed_value)
	add_child(_pickups)
	_setup_environment()

	_stats = GameData.stats(Save.tier, Save.levels)
	fuel = _stats.fuel
	_car = Car.new()
	_car.setup(Save.tier, _stats, Save.paint)
	_car.position = Vector3(0, _terrain.height(0, START_Z) + 1.5, START_Z)
	add_child(_car)

	_cam = Camera3D.new()
	_cam.fov = 70.0
	_cam.far = 300.0
	add_child(_cam)
	_cam.global_position = _car.position + Vector3(0, 6.5, -11)
	_cam.look_at(_car.position)
	_cam.current = true
	_weather = Effects.weather()
	if not high:
		_weather.amount /= 2
	_cam.add_child(_weather)

	_hud = Hud.new()
	add_child(_hud)
	if daily:
		_hud.set_daily()
	_hud.back_to_garage.connect(func(): finished.emit())


func _physics_process(delta: float) -> void:
	# o carro acelera sozinho enquanto houver combustível; o jogador só dirige
	var running := _end_reason.is_empty()
	_car.brake_input = 0.0
	if not running:
		_car.throttle = 0.0
		_car.steer_input = 0.0
	else:
		fuel = maxf(0.0, fuel - delta)
		_car.throttle = 1.0 if fuel > 0.0 else 0.0
		if auto_drive:
			_auto_steer()
		else:
			_car.steer_input = Input.get_action_strength("steer_left") - Input.get_action_strength("steer_right")
		_unstick(delta)

	var pos := _car.global_position
	var biome := GameData.biome_index(pos.z)
	if biome != _biome:
		_apply_biome(biome)
	distance = maxf(distance, pos.z - START_Z)

	var got := _pickups.update(pos, _stats.magnet, delta)
	run_coins += got.coins
	if got.fuel:
		fuel = _stats.fuel
	_terrain.update(pos)

	if running:
		_check_boost_pad(pos)
		_check_air(delta)
		_check_near_miss(pos)
		_check_impact()
		_check_tips(pos)
		_combo_time -= delta
		_check_end(delta)
	Sfx.set_engine(running and fuel > 0.0, _car.forward_speed() / float(_stats.top_speed))
	_follow_camera(delta)
	var best := Save.daily_best_today() if daily else Save.best
	_hud.set_values(distance, best, run_coins, fuel / _stats.fuel)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _end_reason.is_empty():
			_finish("Desistiu")
		else:
			finished.emit()
	elif event.is_action_pressed("ui_accept") and not _end_reason.is_empty():
		finished.emit()


func _notification(what: int) -> void:
	# Android: saiu do app no meio da corrida -> encerra e salva as moedas
	if what == NOTIFICATION_APPLICATION_PAUSED and _end_reason.is_empty() and _car != null:
		_finish("Pausado")


## Piloto automático: segue a trilha olhando 12 m à frente.
func _auto_steer() -> void:
	var pos := _car.global_position
	var look_z := pos.z + 12.0
	var target_x := _terrain.path_x(look_z)
	# desvia dos pedregulhos usando a faixa livre (como um jogador faria)
	if _terrain.track.kind_at(look_z) == Track.PEDRAS:
		target_x += _layout(_terrain.track.index_at(look_z)).lane
	var local := _car.to_local(Vector3(target_x, pos.y, look_z))
	_car.steer_input = clampf(atan2(local.x, local.z) * 2.0, -1.0, 1.0)


## Ré automática: sem freio na mão, um carro empacado numa pedra ou árvore ficaria
## empurrando para sempre. Se empacar acelerando, ele dá ré por um instante virando
## para o outro lado e depois segue.
func _unstick(delta: float) -> void:
	if _reverse_time > 0.0:
		_reverse_time -= delta
		_car.throttle = 0.0
		_car.brake_input = 1.0
		_car.steer_input = -_reverse_steer
		return
	if _car.throttle > 0.0 and _car.forward_speed() < 1.0 and _car.on_ground():
		_blocked += delta
		if _blocked > 0.8:
			_blocked = 0.0
			_reverse_time = 1.1
			_reverse_steer = 1.0 if _car.steer_input >= 0.0 else -1.0
	else:
		_blocked = 0.0


func _exit_tree() -> void:
	Sfx.set_engine(false, 0.0)


## Dicas da primeira vez: aparecem uma de cada vez, quando a situação chega.
func _check_tips(pos: Vector3) -> void:
	if _hud.showing_tip():
		return
	var ahead := _terrain.track.kind_at(pos.z + 35.0)
	if Save.first_time("steer"):
		_hud.tip("o carro acelera sozinho. Arraste o dedo para os lados para dirigir.")
	elif ahead in [Track.SALTO, Track.RAMPA] and Save.first_time("jump"):
		_hud.tip("salto à frente! Tempo no ar vale moedas, e pousar reto dá bônus de pouso perfeito.")
	elif ahead == Track.PEDRAS and Save.first_time("rocks"):
		_hud.tip("pedras! Desvie pela faixa livre. Passar raspando sem bater dá bônus.")
	elif ahead == Track.BOOST and Save.first_time("boost"):
		_hud.tip("passe por cima da placa azul para ganhar um BOOST.")
	elif fuel < _stats.fuel * 0.5 and Save.first_time("fuel"):
		_hud.tip("pegue os galões vermelhos: quando o combustível acaba, a corrida termina.")


## Passou por cima de uma placa de boost (2,6 x 3 m no centro da trilha)?
func _check_boost_pad(pos: Vector3) -> void:
	var track := _terrain.track
	var index := track.index_at(pos.z)
	if index < 0 or index == _last_boost or track.kind_of(index) != Track.BOOST:
		return
	var t := fposmod(pos.z, Track.SEGMENT)
	if absf(t - Track.BOOST_AT) < 2.0 and absf(pos.x - _terrain.path_x(pos.z)) < 1.8:
		_last_boost = index
		_counts.boosts += 1
		_car.boost()
		Sfx.play("boost")
		_hud.toast("BOOST!")


## Saltos: conta o tempo no ar e, no pouso, dá moedas; pouso de rodas e reto é "perfeito".
func _check_air(delta: float) -> void:
	if not _car.on_ground():
		_air_time += delta
		return
	if _air_time >= AIR_MIN:
		_counts.jumps += 1
		_trick("SALTO %.1f s" % _air_time, int(round(_air_time * 6.0)))
		_shake = maxf(_shake, clampf(_air_time * 0.25, 0.1, 0.5))
		_vibrate(40 + int(_air_time * 40.0))
		Sfx.play("land")
		Effects.landing_dust(self, _car.global_position - Vector3.UP * 0.5, GameData.biome_color(_car.global_position.z, "road"))
		if _car.uprightness() > 0.96 and _car.forward_speed() > 8.0:
			_counts.perfect += 1
			_trick("POUSO PERFEITO", 5)
			if _stats.landing_boost:
				_car.boost(0.4)
	_air_time = 0.0


## Passou raspando (sem bater) ao lado de um pedregulho.
func _check_near_miss(pos: Vector3) -> void:
	var index := _terrain.track.index_at(pos.z)
	if index < 0 or _terrain.track.kind_of(index) != Track.PEDRAS:
		return
	var boulders: Array = _layout(index).boulders
	for n in boulders.size():
		var key := "%d:%d" % [index, n]
		var b: Vector3 = boulders[n][0]
		if _near_done.has(key) or absf(pos.z - b.z) > 0.6:
			continue
		_near_done[key] = true
		var gap := absf(pos.x - b.x) - Props.BOULDER_RADIUS * float(boulders[n][1]) - 0.9
		if gap > 0.15 and gap < NEAR_MISS_GAP:
			_counts.near += 1
			_trick("RASPANDO!", 4)


## Batida: queda brusca de velocidade treme a câmera e vibra o celular.
func _check_impact() -> void:
	var speed := _car.linear_velocity.length()
	if _prev_speed - speed > 4.0:
		_shake = maxf(_shake, 0.6)
		_vibrate(120)
		Sfx.play("crash")
	_prev_speed = speed


func _trick(text: String, coins: int) -> void:
	_combo = _combo + 1 if _combo_time > 0.0 else 1
	_combo_time = COMBO_WINDOW
	var total := coins * _combo
	run_coins += total
	_trick_coins += total
	_hud.trick(text, total, _combo)
	Sfx.play("trick")


func _layout(index: int) -> Dictionary:
	if not _layouts.has(index):
		_layouts[index] = Props.boulder_layout(_terrain, index, _terrain_seed)
	return _layouts[index]


static func _vibrate(ms: int) -> void:
	if OS.has_feature("mobile") and Save.settings.vibration:
		Input.vibrate_handheld(ms)


func _check_end(delta: float) -> void:
	var pos := _car.global_position
	var speed := _car.linear_velocity.length()
	_flipped = _flipped + delta if _car.uprightness() < 0.2 else 0.0
	if _flipped > 2.5:
		_finish("Capotou!")
		return
	if fuel <= 0.0:
		# sem combustível: termina logo que o carro quase parar, ou após ~6 s rolando na banguela
		_empty += delta * (1.0 if speed < 2.0 else 0.25)
		if _empty > 1.5:
			_finish("Acabou o combustível")
		return
	if pos.z > _best_z + 1.0:
		_best_z = pos.z
		_stuck = 0.0
	else:
		_stuck += delta
		if _stuck > 15.0:
			_finish("Sem avançar")
			return
	if pos.y < -200.0:
		_finish("Caiu do mapa")


func _finish(reason: String) -> void:
	_end_reason = reason
	var dist := int(distance)
	var earned := run_coins + int(distance / 5.0)
	Save.coins += earned
	var record := false
	if daily:
		record = Save.record_daily(dist)
	elif dist > Save.best:
		Save.best = dist
		record = true

	var lines := PackedStringArray()
	lines.append("(%d coletadas, %d de manobras + bônus de distância)" % [run_coins - _trick_coins, _trick_coins])
	lines.append("Saltos %d · Pousos perfeitos %d · Raspando %d · Boosts %d" % [
		_counts.jumps, _counts.perfect, _counts.near, _counts.boosts])
	var stats := _counts.duplicate()
	stats["distance"] = distance
	stats["coins"] = run_coins
	var done := Missions.complete_from_run(stats)
	for m in done:
		lines.append("Missão concluída: %s  +%d" % [m.text, m.reward])
	Sfx.play("mission" if not done.is_empty() or record else "click")
	Save.persist()
	Platform.on_run_finished(dist, earned)
	_hud.show_end(reason, dist, record, earned, lines)


func _follow_camera(delta: float) -> void:
	var fwd := _car.global_basis.z
	fwd.y = 0.0
	if fwd.length() > 0.3:
		_cam_fwd = _cam_fwd.lerp(fwd.normalized(), clampf(delta * 3.0, 0.0, 1.0)).normalized()
	# alta e um pouco longe, para ver as curvas que vêm pela frente
	var target := _car.global_position - _cam_fwd * 11.0 + Vector3.UP * 6.5
	target.y = maxf(target.y, _terrain.height(target.x, target.z) + 2.0)  # câmera nunca entra no chão
	_cam.global_position = _cam.global_position.lerp(target, clampf(delta * 5.0, 0.0, 1.0))
	_cam.look_at(_car.global_position + _cam_fwd * 9.0)
	# tremida de impacto (pouso forte, batida)
	if _shake > 0.0:
		_cam.global_position += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * _shake * 0.35
		_shake = move_toward(_shake, 0.0, delta * 1.5)
	# a lente abre com a velocidade (e mais ainda no boost): sensação de velocidade
	var speed := _car.linear_velocity.length()
	var target_fov := 70.0 + clampf(speed - 8.0, 0.0, 25.0) * 0.6 + (10.0 if _car.is_boosting() else 0.0)
	_cam.fov = lerpf(_cam.fov, target_fov, clampf(delta * 3.0, 0.0, 1.0))


func _setup_environment() -> void:
	_sky = ProceduralSkyMaterial.new()
	var sky := Sky.new()
	sky.sky_material = _sky
	_env = Environment.new()
	_env.background_mode = Environment.BG_SKY
	_env.sky = sky
	# luz ambiente por cor (segue a região) e tonemap linear: no renderizador
	# Compatibility, ambiente do céu + filmic deixavam tudo pálido
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_energy = 0.6
	_env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	# neblina leve: esconde a borda do mapa gerado sem lavar as cores
	_env.fog_enabled = true
	_env.fog_density = 0.002
	_env.fog_light_energy = 0.7
	_env.fog_sky_affect = 0.0
	var world_env := WorldEnvironment.new()
	world_env.environment = _env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.light_energy = 0.9
	sun.shadow_enabled = Save.settings.quality == 1
	sun.directional_shadow_max_distance = 50.0
	add_child(sun)


func _apply_biome(index: int) -> void:
	_biome = index
	var b: Dictionary = GameData.BIOMES[index]
	var t := create_tween().set_parallel()
	t.tween_property(_sky, "sky_top_color", b.sky, 2.0)
	t.tween_property(_sky, "sky_horizon_color", b.horizon, 2.0)
	t.tween_property(_sky, "ground_horizon_color", b.horizon, 2.0)
	t.tween_property(_sky, "ground_bottom_color", b.ground, 2.0)
	t.tween_property(_env, "fog_light_color", b.horizon, 2.0)
	t.tween_property(_env, "ambient_light_color", b.horizon.lerp(Color(0.55, 0.55, 0.55), 0.6), 2.0)
	_car.grip = b.grip
	_car.gravity_scale = b.gravity / 9.8
	_car.set_dust_color(b.road)
	Effects.set_weather(_weather, b.title)
	_hud.toast(b.title)


# ---------------------------------------------------------------- testes / modo demo

var _worst_frame_ms := 0.0


func _process(delta: float) -> void:
	_worst_frame_ms = maxf(_worst_frame_ms, delta * 1000.0)
	if delta > 0.05 and OS.is_debug_build():
		print("FRAME LENTO %.0f ms em z=%.0f" % [delta * 1000.0, _car.global_position.z])


func is_over() -> bool:
	return not _end_reason.is_empty()


func debug_line() -> String:
	var line := "dist=%.1f speed=%.1f fuel=%.1f coins=%d (manobras %d) %s pior_frame=%.0fms" % [
		distance, _car.linear_velocity.length(), fuel, run_coins, _trick_coins, _counts, _worst_frame_ms]
	_worst_frame_ms = 0.0
	return line
