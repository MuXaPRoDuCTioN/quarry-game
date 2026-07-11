extends Button


func _ready():
	# <<< НОВОЕ: в обучении меняем текст кнопки
	if Global.is_tutorial:
		text = "Выйти из обучения"


func _process(_delta):
	pass


func _on_pressed() -> void:
	if Global.is_tutorial:
		var tm = get_node_or_null("/root/TutorialManager")
		if tm and tm.has_method("finish_tutorial"):
			tm.finish_tutorial()
		else:
			Global.is_tutorial = false
			get_tree().change_scene_to_file("res://scenes/main/MainMenu.tscn")
		return
	
	var current_scene = get_tree().current_scene
	
	# Если мы на карте карьера — сначала показываем GameOverWindow
	if current_scene and current_scene.name == "QuarryMap":
		if current_scene.has_method("_open_game_over_window"):
			current_scene._open_game_over_window()
			return
	
	# Для остальных сцен — обычный возврат в меню
	get_tree().change_scene_to_file("res://scenes/main/MainMenu.tscn")
