extends Node


signal level_pressed(level_num)


var level_buttons = {}


func generate(container, max_levels):
	# Стили для генерируемых кнопок
	var btn_normal = StyleBoxFlat.new()
	btn_normal.bg_color = Color("#141F33")
	btn_normal.corner_radius_top_left = 8
	btn_normal.corner_radius_top_right = 8
	btn_normal.corner_radius_bottom_left = 8
	btn_normal.corner_radius_bottom_right = 8
	btn_normal.border_width_left = 2
	btn_normal.border_width_right = 2
	btn_normal.border_width_top = 2
	btn_normal.border_width_bottom = 2
	btn_normal.border_color = Color("#1A2640")
	
	var btn_hover = btn_normal.duplicate()
	btn_hover.bg_color = Color("#1A2E59")
	btn_hover.border_color = Color("#3366B3")
	
	var btn_purchased = btn_normal.duplicate()
	btn_purchased.bg_color = Color("#264080")
	btn_purchased.border_color = Color("#0099FF")
	
	var btn_locked = btn_normal.duplicate()
	btn_locked.bg_color = Color("#0D1426")
	btn_locked.border_color = Color("#1A2640")
	
	for i in range(1, max_levels + 1):
		var button = Button.new()
		button.name = "level_button_" + str(i)
		level_buttons[i] = button
		button.custom_minimum_size = Vector2(120, 60)
		
		if (i % 2) == 0:
			button.position = Vector2(0, 65 * (i - 1))
		else:
			button.position = Vector2(150, 65 * (i - 1))
		
		# Применяем стиль
		if Global.purchased_levels.has(i):
			button.add_theme_stylebox_override("normal", btn_purchased)
			button.add_theme_stylebox_override("hover", btn_purchased)
			button.add_theme_color_override("font_color", Color("#E6F2FF"))
			update_text(i)
		else:
			button.add_theme_stylebox_override("normal", btn_normal)
			button.add_theme_stylebox_override("hover", btn_hover)
			button.add_theme_color_override("font_color", Color("#99BFFF"))
			button.text = "Этаж " + str(i) + "\nЦена: " + str(get_level_price(i))
		
		button.add_theme_font_size_override("font_size", 14)
		if Global.exo2_font:
			button.add_theme_font_override("font", Global.exo2_font)
		
		button.pressed.connect(_on_level_button_pressed.bind(i))
		container.add_child(button)
		
		# Сохраняем стили для обновления
		button.set_meta("btn_normal", btn_normal)
		button.set_meta("btn_hover", btn_hover)
		button.set_meta("btn_purchased", btn_purchased)
		button.set_meta("btn_locked", btn_locked)


func _on_level_button_pressed(level_num):
	emit_signal("level_pressed", level_num)


func update_buttons():
	var last_purchased = get_max_purchased_level()
	var completed_levels = Global.get_completed_levels()
	
	for level_num in level_buttons:
		var button = level_buttons[level_num]
		
		# Если уровень пройден — блокируем (без галочки!)
		if completed_levels.has(level_num):
			button.visible = true
			button.disabled = true
			button.text = "Этаж " + str(level_num)
			var btn_locked = button.get_meta("btn_locked")
			button.add_theme_stylebox_override("normal", btn_locked)
			button.add_theme_stylebox_override("hover", btn_locked)
			button.add_theme_color_override("font_color", Color("#667F99"))
			continue
		
		if level_num <= last_purchased + 1:
			button.visible = true
			button.disabled = false
			update_text(level_num)
		elif level_num == last_purchased + 2:
			button.visible = true
			button.disabled = true
			var btn_locked = button.get_meta("btn_locked")
			button.add_theme_stylebox_override("normal", btn_locked)
			button.add_theme_stylebox_override("hover", btn_locked)
			button.add_theme_color_override("font_color", Color("#667F99"))
			button.text = "Этаж " + str(level_num) + "\nЦена: " + str(get_level_price(level_num))
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
	# Новая цена: 200 + (level_num - 1) * 80
	return 200 + (level_num - 1) * 80


func update_text(level_num: int):
	var button = level_buttons[level_num]
	if Global.purchased_levels.has(level_num):
		button.text = "Этаж " + str(level_num)
	else:
		button.text = "Этаж " + str(level_num) + "\nЦена: " + str(get_level_price(level_num))
