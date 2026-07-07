extends Button


func _ready() -> void:
	pass


func _process(_delta: float) -> void:
	pass


func _on_pressed() -> void:
	# Открываем окно таблицы лидеров
	var leaderboard_scene = preload("res://scenes/uis/LeaderboardWindow.tscn")
	var leaderboard_window = leaderboard_scene.instantiate()
	get_tree().current_scene.add_child(leaderboard_window)
