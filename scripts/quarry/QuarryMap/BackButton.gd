extends Button


func _ready():
	pass


func _process(_delta):
	pass


func _on_pressed() -> void:
	var current_scene = get_tree().current_scene
	
	# Если мы на карте карьера — сначала показываем GameOverWindow
	if current_scene and current_scene.name == "QuarryMap":
		if current_scene.has_method("_open_game_over_window"):
			current_scene._open_game_over_window()
			return
	
	# Для остальных сцен — обычный возврат в меню
	get_tree().change_scene_to_file("res://scenes/main/MainMenu.tscn")
