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
	task_selector.size = Vector2(200, 30)
	task_selector.clear()
	
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
	
	level_label = Label.new()
	level_label.text = "Номер уровня:"
	level_label.position = Vector2(10, 40)
	dynamic_control.add_child(level_label)
	
	level_selector = OptionButton.new()
	level_selector.position = Vector2(150, 35)
	level_selector.size = Vector2(100, 30)
	
	var purchased_levels = Global.purchased_levels
	if purchased_levels.size() == 0:
		level_selector.add_item("Нет уровней")
	else:
		for level in purchased_levels:
			level_selector.add_item(str(level))
		level_selector.selected = 0
	
	dynamic_control.add_child(level_selector)
	
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


# Добавляем обработку закрытия окна через крестик
func _on_close_button_pressed() -> void:
	emit_signal("task_cancelled")
	queue_free()
