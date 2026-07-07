extends Button


func _on_pressed():
	if not TutorialManager:
		print("Ошибка: TutorialManager не найден!")
		return
	
	TutorialManager.start_tutorial()
