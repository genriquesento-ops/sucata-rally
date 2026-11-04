extends Node
## Sons e música gerados por código (autoload "Sfx"). Nenhum arquivo de áudio: tudo é
## sintetizado na abertura do jogo (ondas seno/quadrada/dente-de-serra, ruído e envelopes),
## então não há licenças de som para cuidar e o APK fica pequeno.
## Uso: Sfx.play("coin"), Sfx.set_engine(ligado, 0..1), Sfx.apply_volumes().

const RATE := 22050  # Hz, mono: suficiente para efeitos e economiza memória
const POOL := 8

var _sfx := {}  # nome -> AudioStreamWAV
var _players: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer
var _engine: AudioStreamPlayer


func _ready() -> void:
	_setup_buses()
	_sfx.coin = _wav(_notes([[988.0, 0.05], [1319.0, 0.12]], 0.35))
	_sfx.fuel = _wav(_sweep(300.0, 900.0, 0.25, 0.4))
	_sfx.trick = _wav(_notes([[660.0, 0.05], [880.0, 0.05], [1175.0, 0.12]], 0.3))
	_sfx.mission = _wav(_notes([[523.0, 0.1], [659.0, 0.1], [784.0, 0.1], [1047.0, 0.3]], 0.35))
	_sfx.click = _wav(_notes([[1200.0, 0.03]], 0.25))
	_sfx.upgrade = _wav(_sweep(400.0, 1200.0, 0.18, 0.35))
	_sfx.boost = _wav(_noise(0.7, 0.5, true))
	_sfx.crash = _wav(_noise(0.35, 0.7, false))
	_sfx.land = _wav(_sweep(110.0, 45.0, 0.2, 0.8))
	for i in POOL:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_players.append(p)
	_engine = AudioStreamPlayer.new()
	_engine.bus = "SFX"
	_engine.stream = _wav(_engine_loop(), true)
	_engine.volume_db = -10.0
	add_child(_engine)
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	_music.stream = _wav(_music_loop(), true)
	_music.volume_db = -6.0
	add_child(_music)
	_music.play()
	apply_volumes()


func play(name: String, pitch_jitter := 0.05) -> void:
	for p in _players:
		if not p.playing:
			p.stream = _sfx[name]
			p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
			p.play()
			return


## Ronco do motor: rotação (tom) acompanha a velocidade, de 0 a 1.
func set_engine(on: bool, rpm: float) -> void:
	if on and not _engine.playing:
		_engine.play()
	elif not on and _engine.playing:
		_engine.stop()
	_engine.pitch_scale = 0.7 + clampf(rpm, 0.0, 1.5) * 1.1


func apply_volumes() -> void:
	_set_bus("Music", Save.settings.music)
	_set_bus("SFX", Save.settings.sfx)


func _setup_buses() -> void:
	for bus in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, bus)
			AudioServer.set_bus_send(i, "Master")


func _set_bus(bus: String, volume: float) -> void:
	var i := AudioServer.get_bus_index(bus)
	AudioServer.set_bus_mute(i, volume <= 0.01)
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(volume, 0.01)))


# ---------------------------------------------------------------- síntese

static func _wav(samples: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = samples.size()
	return w


## Sequência de notas [[Hz, segundos], ...] com timbre "chip" (seno + 3º harmônico).
static func _notes(notes: Array, volume: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for n in notes:
		var count := int(n[1] * RATE)
		for i in count:
			var t := float(i) / RATE
			var env := 1.0 - float(i) / count
			var s := sin(TAU * n[0] * t) + 0.3 * sin(TAU * n[0] * 3.0 * t)
			out.append(s * env * volume * 0.8)
	return out


## Varredura de frequência (sobe ou desce) com decaimento.
static func _sweep(from: float, to: float, seconds: float, volume: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var count := int(seconds * RATE)
	var phase := 0.0
	for i in count:
		var u := float(i) / count
		phase += TAU * lerpf(from, to, u) / RATE
		out.append(sin(phase) * (1.0 - u) * volume)
	return out


## Ruído filtrado: rising = "whoosh" que abre (boost); senão estouro abafado (batida).
static func _noise(seconds: float, volume: float, rising: bool) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var count := int(seconds * RATE)
	var lp := 0.0
	for i in count:
		var u := float(i) / count
		var cutoff := lerpf(0.02, 0.35, u) if rising else lerpf(0.25, 0.03, u)
		lp += (randf_range(-1.0, 1.0) - lp) * cutoff
		var env := sin(PI * u) if rising else (1.0 - u) * (1.0 - u)
		out.append(lp * env * volume * 2.0)
	return out


## Ronco: 0,4 s a 50 Hz (20 ciclos exatos, então o loop não estala).
static func _engine_loop() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var count := int(0.4 * RATE)
	var f := 50.0
	for i in count:
		var t := float(i) / RATE
		var saw := 2.0 * fposmod(f * t, 1.0) - 1.0
		var sub := 1.0 if fposmod(f * 0.5 * t, 1.0) < 0.5 else -1.0
		out.append((0.5 * saw + 0.3 * sin(TAU * 2.0 * f * t) + 0.15 * sub) * 0.35)
	return out


## Música: 8 s em loop a 120 BPM, acordes C - Am - F - G (2 s cada):
## baixo em colcheias, arpejo em semicolcheias e um bumbo leve em cada tempo.
static func _music_loop() -> PackedFloat32Array:
	var chords := [[261.6, 329.6, 392.0], [220.0, 261.6, 329.6], [174.6, 220.0, 261.6], [196.0, 246.9, 293.7]]
	var out := PackedFloat32Array()
	var total := 8 * RATE
	out.resize(total)
	var sixteenth := RATE / 8  # 120 BPM: semicolcheia = 0,125 s
	for i in total:
		var t := float(i) / RATE
		var chord: Array = chords[int(t / 2.0) % 4]
		var step := i / sixteenth
		var in_step := float(i % sixteenth) / sixteenth
		# baixo (triangular), uma oitava abaixo da tônica, em colcheias
		var bass_f: float = chord[0] / 2.0
		var tri := 2.0 * absf(2.0 * fposmod(bass_f * t, 1.0) - 1.0) - 1.0
		var bass := tri * 0.22 * (1.0 - 0.6 * fposmod(t * 4.0, 1.0))
		# arpejo
		var arp_f: float = chord[step % 3] * 2.0
		var arp := (sin(TAU * arp_f * t) + 0.25 * sin(TAU * arp_f * 3.0 * t)) * 0.09 * (1.0 - in_step)
		# bumbo: seno que cai de 120 para 40 Hz no começo de cada tempo
		var beat := fposmod(t * 2.0, 1.0) / 2.0
		var kick := sin(TAU * lerpf(120.0, 40.0, minf(beat * 10.0, 1.0)) * beat) * maxf(0.0, 1.0 - beat * 8.0) * 0.35
		out[i] = bass + arp + kick
	return out
