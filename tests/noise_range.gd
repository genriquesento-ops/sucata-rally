extends SceneTree
## Mede a faixa de valores do ruído celular usado nas crateras da Lua.
##   godot --headless --path . --script res://tests/noise_range.gd


func _initialize() -> void:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_CELLULAR
	n.frequency = 0.025
	n.fractal_type = FastNoiseLite.FRACTAL_NONE
	n.cellular_return_type = FastNoiseLite.RETURN_DISTANCE
	n.cellular_jitter = 0.9
	var lo := INF
	var hi := -INF
	var hist := PackedInt32Array()
	hist.resize(10)
	for i in 20000:
		var v := n.get_noise_2d(randf() * 2000.0, randf() * 2000.0) + 1.0
		lo = minf(lo, v)
		hi = maxf(hi, v)
		hist[clampi(int(v * 10.0), 0, 9)] += 1
	print("dist min=%.3f max=%.3f hist(0.1)=%s" % [lo, hi, hist])
	quit()
