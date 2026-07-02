extends Panel


signal frequency_selected(generator_id: int, frequency: int)
signal direction_selected(generator_id: int, direction: int)
signal window_closed
signal generator_cancelled(generator_id: int)  # новый сигнал для отмены


var generator_id: int = -1
var selected_frequency: int = 500
var selected_direction: int = 0  # 0-вверх, 1-вправо, 2-вниз, 3-влево
var is_dragging: bool = false
var drag_offset: Vector2 = Vector2.ZERO
var drag_start


func setup(gen_id: int):
	generator_id = gen_id
	
	# Устанавливаем значения по умолчанию
	selected_frequency = 500
	selected_direction = 0
	
	# Настраиваем слайдер
	$FrequencySlider.value = 500
	
	# Настраиваем выпадающий список с выбором направления
	$DirectionSelector.clear()
	$DirectionSelector.add_item("Вверх ↑")
	$DirectionSelector.add_item("Вправо →")
	$DirectionSelector.add_item("Вниз ↓")
	$DirectionSelector.add_item("Влево ←")
	$DirectionSelector.selected = 0  # Выбираем "Вверх" по умолчанию
	
	update_labels()
	center_window()
	
	# Настраиваем перемещение только по верхней панели
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
				# Проверяем, что клик был по верхней панели
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
	# Принять - генератор остаётся с настроенными параметрами
	var direction = $DirectionSelector.selected
	emit_signal("direction_selected", generator_id, direction)
	emit_signal("frequency_selected", generator_id, selected_frequency)
	emit_signal("window_closed")
	queue_free()


func _on_close_button_pressed():
	# Закрыть - генератор удаляется с уровня
	emit_signal("generator_cancelled", generator_id)
	emit_signal("window_closed")
	queue_free()


func _on_upper_panel_mouse_entered():
	# Меняем курсор при наведении на верхнюю панель
	Input.set_default_cursor_shape(Input.CURSOR_DRAG)


func _on_upper_panel_mouse_exited():
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
