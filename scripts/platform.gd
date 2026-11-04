extends Node
## Ponte para recursos de cada loja.
## As tags "foss" e "play" vêm do campo "Custom Features" de cada preset de exportação.
## Plugins proprietários (Play Games, anúncios) só podem ser ativados no preset "play".

var flavor := "desktop"


func _ready() -> void:
	if OS.has_feature("play"):
		flavor = "play"
	elif OS.has_feature("foss"):
		flavor = "foss"


func on_run_finished(_distance: int, _coins: int) -> void:
	if flavor == "play":
		pass  # TODO: enviar a distância para um placar online
