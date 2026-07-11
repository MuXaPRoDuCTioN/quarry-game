extends Button


func _ready():
	if Global.is_tutorial:
		text = "Выйти из обучения"


func _on_pressed():
	if Global.is_tutorial:
		var tm = get_node_or_null("/root/TutorialManager")
		if tm and tm.has_method("finish_tutorial"):
			tm.finish_tutorial()
		else:
			Global.is_tutorial = false
			get_tree().change_scene_to_file("res://scenes/main/MainMenu.tscn")
		return
	
	# Обычное поведение — возврат на карту
	get_tree().change_scene_to_file("res://scenes/quarry/QuarryMap.tscn")
