extends Button


func _on_pressed():
	# Сначала сбрасываем всё состояние игры
	Global.reset_game()
	
	# Устанавливаем флаг новой игры
	Global.is_new_game = true
	
	# Переходим на карту уровней
	get_tree().change_scene_to_file("res://scenes/quarry/QuarryMap.tscn")
