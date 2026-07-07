extends Panel


signal task_selected(task_type: String, target: int)
signal task_cancelled()


var dynamic_control: Control
var task_selector: OptionButton
var level_label: Label
var level_selector: OptionButton  
var vehicle_type: String = "truck"  


func _ready() -> void:
	task_selector = $StaticControl/TaskSelector
	dynamic_control = $DynamicControl
	
	select_tasks()
	build_dynamic_control()
	
	_on_task_selector_item_selected(0)
	
	center_window()


func center_window():
	var viewport_size = get_viewport().get_visible_rect().size
	var window_size = size
	
	if window_size.x == 0 and window_size.y == 0:
		await get_tree().process_frame
		window_size = size
	
	global_position = (viewport_size - window_size) / 2


func select_tasks():
	task_selector.size = Vector2(250, 35)
	task_selector.clear()
	
	# Стилизуем OptionButton
	var option_normal = StyleBoxFlat.new()
	option_normal.bg_color = Color("#141F33")
	option_normal.corner_radius_top_left = 4
	option_normal.corner_radius_top_right = 4
	option_normal.corner_radius_bottom_left = 4
	option_normal.corner_radius_bottom_right = 4
	option_normal.border_width_left = 1
	option_normal.border_width_right = 1
	option_normal.border_width_top = 1
	option_normal.border_width_bottom = 1
	option_normal.border_color = Color("#1A2640")
	
	var option_hover = option_normal.duplicate()
	option_hover.bg_color = Color("#1A2E59")
	option_hover.border_color = Color("#3366B3")
	
	task_selector.add_theme_stylebox_override("normal", option_normal)
	task_selector.add_theme_stylebox_override("hover", option_hover)
	task_selector.add_theme_color_override("font_color", Color("#E6F2FF"))
	task_selector.add_theme_font_size_override("font_size", 18)
	if Global.exo2_font:
		task_selector.add_theme_font_override("font", Global.exo2_font)
	
	# Стилизуем ВЫПАДАЮЩИЙ СПИСОК (popup)
	var popup = task_selector.get_popup()
	if popup:
		var popup_style = StyleBoxFlat.new()
		popup_style.bg_color = Color("#0D1426")
		popup_style.corner_radius_top_left = 8
		popup_style.corner_radius_top_right = 8
		popup_style.corner_radius_bottom_left = 8
		popup_style.corner_radius_bottom_right = 8
		popup_style.border_width_left = 1
		popup_style.border_width_right = 1
		popup_style.border_width_top = 1
		popup_style.border_width_bottom = 1
		popup_style.border_color = Color("#3366B3")
		popup.add_theme_stylebox_override("panel", popup_style)
		
		var item_style = StyleBoxFlat.new()
		item_style.bg_color = Color("#141F33")
		item_style.corner_radius_top_left = 4
		item_style.corner_radius_top_right = 4
		item_style.corner_radius_bottom_left = 4
		item_style.corner_radius_bottom_right = 4
		
		var item_hover = item_style.duplicate()
		item_hover.bg_color = Color("#264080")
		
		popup.add_theme_stylebox_override("normal", item_style)
		popup.add_theme_stylebox_override("hover", item_hover)
		popup.add_theme_color_override("font_color", Color("#E6F2FF"))
		popup.add_theme_font_size_override("font_size", 18)
		if Global.exo2_font:
			popup.add_theme_font_override("font", Global.exo2_font)
		
		# Увеличиваем минимальную ширину выпадающего списка
		popup.min_size.x = 200
	
	if vehicle_type == "truck":
		task_selector.add_item("Отправить на уровень")
		task_selector.add_item("Отвезти на фабрику")
		task_selector.add_item("Вернуться на парковку")
	elif vehicle_type == "excavator":
		task_selector.add_item("Отправить на уровень")
		task_selector.add_item("Вернуться на парковку")
	task_selector.selected = 0 


func _on_task_selector_item_selected(index: int) -> void:
	if index == 0:
		level_label.visible = true
		level_selector.visible = true
	else:
		level_label.visible = false
		level_selector.visible = false


func build_dynamic_control():
	for child in dynamic_control.get_children():
		child.queue_free()
	var hbox = HBoxContainer.new()
	hbox.position = Vector2(10, 40)
	hbox.size = Vector2(250, 35)
	hbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	dynamic_control.add_child(hbox)
	level_label = Label.new()
	level_label.text = "Номер уровня:"
	level_label.add_theme_color_override("font_color", Color("#E6F2FF"))
	level_label.add_theme_font_size_override("font_size", 18)
	if Global.exo2_font:
		level_label.add_theme_font_override("font", Global.exo2_font)
	hbox.add_child(level_label)
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(10, 0)
	hbox.add_child(spacer)
	level_selector = OptionButton.new()
	level_selector.size = Vector2(100, 35)
	level_selector.custom_minimum_size = Vector2(100, 35)
	var option_normal = StyleBoxFlat.new()
	option_normal.bg_color = Color("#141F33")
	option_normal.corner_radius_top_left = 4
	option_normal.corner_radius_top_right = 4
	option_normal.corner_radius_bottom_left = 4
	option_normal.corner_radius_bottom_right = 4
	option_normal.border_width_left = 1
	option_normal.border_width_right = 1
	option_normal.border_width_top = 1
	option_normal.border_width_bottom = 1
	option_normal.border_color = Color("#1A2640")
	var option_hover = option_normal.duplicate()
	option_hover.bg_color = Color("#1A2E59")
	option_hover.border_color = Color("#3366B3")
	level_selector.add_theme_stylebox_override("normal", option_normal)
	level_selector.add_theme_stylebox_override("hover", option_hover)
	level_selector.add_theme_color_override("font_color", Color("#E6F2FF"))
	level_selector.add_theme_font_size_override("font_size", 18)
	if Global.exo2_font:
		level_selector.add_theme_font_override("font", Global.exo2_font)
	var popup = level_selector.get_popup()
	if popup:
		var popup_style = StyleBoxFlat.new()
		popup_style.bg_color = Color("#0D1426")
		popup_style.corner_radius_top_left = 8
		popup_style.corner_radius_top_right = 8
		popup_style.corner_radius_bottom_left = 8
		popup_style.corner_radius_bottom_right = 8
		popup_style.border_width_left = 1
		popup_style.border_width_right = 1
		popup_style.border_width_top = 1
		popup_style.border_width_bottom = 1
		popup_style.border_color = Color("#3366B3")
		popup.add_theme_stylebox_override("panel", popup_style)
		var item_style = StyleBoxFlat.new()
		item_style.bg_color = Color("#141F33")
		item_style.corner_radius_top_left = 4
		item_style.corner_radius_top_right = 4
		item_style.corner_radius_bottom_left = 4
		item_style.corner_radius_bottom_right = 4
		var item_hover = item_style.duplicate()
		item_hover.bg_color = Color("#264080")
		popup.add_theme_stylebox_override("normal", item_style)
		popup.add_theme_stylebox_override("hover", item_hover)
		popup.add_theme_color_override("font_color", Color("#E6F2FF"))
		popup.add_theme_font_size_override("font_size", 18)
		if Global.exo2_font:
			popup.add_theme_font_override("font", Global.exo2_font)
		popup.min_size.x = 120
	hbox.add_child(level_selector)
	
	var purchased_levels = Global.purchased_levels
	var completed_levels = Global.get_completed_levels()
	var has_available_levels = false
	if purchased_levels.size() == 0:
		level_selector.add_item("Нет уровней")
	else:
		for level in purchased_levels:
			# Пропускаем пройденные уровни
			if completed_levels.has(level):
				continue
			level_selector.add_item(str(level))
			has_available_levels = true
		if not has_available_levels:
			level_selector.add_item("Нет доступных уровней")
		else:
			level_selector.selected = 0
	level_label.visible = false
	level_selector.visible = false


func _on_confirm_button_pressed() -> void:
	var selected_index = task_selector.selected
	var task_text = task_selector.get_item_text(selected_index)
	
	var target = 0
	if selected_index == 0:
		var level_text = level_selector.get_item_text(level_selector.selected)
		target = int(level_text)
	
	emit_signal("task_selected", task_text, target)
	queue_free()


func _on_cancle_button_pressed() -> void:
	emit_signal("task_cancelled")
	queue_free()


func _on_close_button_pressed() -> void:
	emit_signal("task_cancelled")
	queue_free()
