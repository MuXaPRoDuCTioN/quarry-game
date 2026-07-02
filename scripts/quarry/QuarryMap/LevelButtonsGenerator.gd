extends Node


signal level_pressed(level_num)


var level_buttons = {}


func generate(container, max_levels):
	for i in range(1, max_levels + 1):
		var button = Button.new()
		level_buttons[i] = button
		button.custom_minimum_size = Vector2(100, 50)
		if (i % 2) == 0:
			button.position = Vector2(0, 50 * (i - 1))
		else:
			button.position = Vector2(150, 50 * (i - 1))
		if Global.purchased_levels.has(i):
			update_text(i)
		else:
			button.text = "Этаж " + str(i) + "\nЦена: " + str(get_level_price(i))
		button.pressed.connect(_on_level_button_pressed.bind(i))
		container.add_child(button)


func _on_level_button_pressed(level_num):
	emit_signal("level_pressed", level_num)


func update_buttons():
	var last_puschased = get_max_purchased_level()
	for level_num in level_buttons:
		var button = level_buttons[level_num]
		
		if level_num <= last_puschased + 1:
			button.visible = true
			button.disabled = false
		elif level_num == last_puschased + 2:
			button.visible = true
			button.disabled = true
		else:
			button.visible = false
			button.disabled = true


func get_max_purchased_level():
	var max_level = 0
	for level in Global.purchased_levels.keys():
		if level > max_level:
			max_level = level
	return max_level


func get_level_price(level_num: int) -> int:
	return 50 + (level_num - 1) * 30


func update_text(level_num: int):
	level_buttons[level_num].text = "Этаж " + str(level_num)
