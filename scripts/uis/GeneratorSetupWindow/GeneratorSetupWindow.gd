extends Panel
signal frequency_selected(generator_id: int, frequency: int)
signal direction_selected(generator_id: int, direction: int)
signal window_closed
signal generator_cancelled(generator_id: int)


var generator_id: int = -1
var selected_frequency: int = 250
var selected_direction: int = 0
var is_dragging: bool = false
var drag_offset: Vector2 = Vector2.ZERO
var drag_start


func setup(gen_id: int, current_freq: int = 250, current_dir: int = 0):
	generator_id = gen_id
	selected_frequency = current_freq   # используем переданное значение
	selected_direction = current_dir    # используем переданное значение
	
	# <<< ИСПРАВЛЕНО: диапазон 100-500, шаг 1
	$FrequencySlider.min_value = 100
	$FrequencySlider.max_value = 500
	$FrequencySlider.step = 1
	$FrequencySlider.value = current_freq
	
	$DirectionSelector.clear()
	$DirectionSelector.add_item("Вверх ↑")
	$DirectionSelector.add_item("Вправо →")
	$DirectionSelector.add_item("Вниз ↓")
	$DirectionSelector.add_item("Влево ←")
	$DirectionSelector.selected = current_dir  # используем переданное значение
	
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
	$DirectionSelector.add_theme_stylebox_override("normal", option_normal)
	$DirectionSelector.add_theme_stylebox_override("hover", option_hover)
	$DirectionSelector.add_theme_color_override("font_color", Color("#E6F2FF"))
	$DirectionSelector.add_theme_font_size_override("font_size", 18)
	if Global.exo2_font:
		$DirectionSelector.add_theme_font_override("font", Global.exo2_font)
	
	# Стилизуем ВЫПАДАЮЩИЙ СПИСОК (popup)
	var popup = $DirectionSelector.get_popup()
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
		popup.min_size.x = 150
	
	update_labels()
	center_window()
	
	var upper_panel = $UpperPanel
	if not upper_panel.mouse_entered.is_connected(_on_upper_panel_mouse_entered):
		upper_panel.mouse_entered.connect(_on_upper_panel_mouse_entered)
	if not upper_panel.mouse_exited.is_connected(_on_upper_panel_mouse_exited):
		upper_panel.mouse_exited.connect(_on_upper_panel_mouse_exited)


func update_labels():
	$FrequencyLabel.text = "Частота: " + str(selected_frequency) + " Гц"
	var directions = ["Вверх ↑", "Вправо →", "Вниз ↓", "Влево ←"]
	var selected_dir = $DirectionSelector.selected
	if selected_dir >= 0 and selected_dir < directions.size():
		$DirectionLabel.text = "Направление: " + directions[selected_dir]
		selected_direction = selected_dir


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				var mouse_pos = get_global_mouse_position()
				var upper_panel = $UpperPanel
				if upper_panel.get_global_rect().has_point(mouse_pos):
					is_dragging = true
					drag_offset = global_position - mouse_pos
					drag_start = mouse_pos
				else:
					is_dragging = false
	if event is InputEventMouseMotion and is_dragging:
		var mouse_pos = get_global_mouse_position()
		global_position = mouse_pos + drag_offset


func center_window():
	var viewport_size = get_viewport().get_visible_rect().size
	var window_size = size
	if window_size.x == 0 and window_size.y == 0:
		await get_tree().process_frame
		window_size = size
	global_position = (viewport_size - window_size) / 2


func _on_frequency_slider_value_changed(value: float):
	selected_frequency = int(value)
	update_labels()


func _on_direction_selector_item_selected(index: int):
	update_labels()


func _on_confirm_button_pressed():
	var direction = $DirectionSelector.selected
	emit_signal("direction_selected", generator_id, direction)
	emit_signal("frequency_selected", generator_id, selected_frequency)
	emit_signal("window_closed")
	queue_free()


func _on_close_button_pressed():
	emit_signal("generator_cancelled", generator_id)
	emit_signal("window_closed")
	queue_free()


func _on_upper_panel_mouse_entered():
	Input.set_default_cursor_shape(Input.CURSOR_DRAG)


func _on_upper_panel_mouse_exited():
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
