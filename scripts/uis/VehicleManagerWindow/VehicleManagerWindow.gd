extends Panel


var TaskWindow = preload("res://scenes/uis/TaskWindow.tscn")
var task_window_instance


var is_dragging = false
var drag_start = Vector2()


var selected_vehicle_id = null
var vehicle_buttons = {}
var last_status = ""
var update_timer = 0.0
var UPDATE_INTERVAL = 1.0
var is_task_window_open = false


func _ready() -> void:
	center_window()
	update_vehicle_list()
	set_process(true)


func _process(delta: float) -> void:
	update_timer += delta
	if update_timer >= UPDATE_INTERVAL:
		update_timer = 0.0
		var has_changes = false
		for truck in Global.vehicles["trucks"]:
			if truck.get("status") != truck.get("_cached_status", ""):
				has_changes = true
				break
		if not has_changes:
			for excavator in Global.vehicles["excavators"]:
				if excavator.get("status") != excavator.get("_cached_status", ""):
					has_changes = true
					break
		
		if has_changes:
			update_vehicle_list()
			if selected_vehicle_id != null:
				show_info_panel()
	
	if selected_vehicle_id != null:
		var vehicle = get_vehicle_by_id(selected_vehicle_id)
		if vehicle:
			vehicle["_cached_status"] = vehicle.get("status", "")
			
			if vehicle.get("status") == "traveling":
				$Control/ProgressBar.visible = true
				$Control/ProgressBar.value = vehicle.get("progress", 0.0)
			else:
				$Control/ProgressBar.visible = false
			
			if vehicle.get("status") != last_status:
				last_status = vehicle.get("status", "")
				update_vehicle_list()
				show_info_panel()
	else:
		$Control/ProgressBar.visible = false


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				var mouse_pos = get_global_mouse_position()
				var ui_nodes = get_tree().get_nodes_in_group("ui")
				for ui in ui_nodes:
					if ui.visible and ui.get_global_rect().has_point(mouse_pos):
						return
				
				is_dragging = true
				drag_start = get_global_mouse_position()
			else:
				is_dragging = false
	
	if event is InputEventMouseMotion and is_dragging:
		var mouse_pos = get_global_mouse_position()
		var delta = mouse_pos - drag_start
		global_position += delta
		drag_start = mouse_pos


func center_window():
	var viewport_size = get_viewport().get_visible_rect().size
	var window_size = size
	
	if window_size.x == 0 and window_size.y == 0:
		await get_tree().process_frame
		window_size = size
	
	global_position = (viewport_size - window_size) / 2


func apply_font_to_button(button: Button, size: int = 20):
	if not button:
		return
	if Global.exo2_font:
		button.add_theme_font_override("font", Global.exo2_font)
		button.add_theme_font_size_override("font_size", size)


func apply_font_to_label(label: Label, size: int = 20):
	if not label:
		return
	if Global.exo2_font:
		label.add_theme_font_override("font", Global.exo2_font)
		label.add_theme_font_size_override("font_size", size)


func _on_close_button_pressed() -> void:
	queue_free()


func update_vehicle_list():
	for truck in Global.vehicles["trucks"]:
		truck["_cached_status"] = truck.get("status", "")
	for excavator in Global.vehicles["excavators"]:
		excavator["_cached_status"] = excavator.get("status", "")
	
	for child in $VehicleContainer.get_children():
		child.queue_free()
	vehicle_buttons.clear()
	
	var all_vehicles = []
	for truck in Global.vehicles["trucks"]:
		all_vehicles.append({"type": "truck", "data": truck})
	for excavator in Global.vehicles["excavators"]:
		all_vehicles.append({"type": "excavator", "data": excavator})
	
	if all_vehicles.size() == 0:
		var label = Label.new()
		label.text = "Нет техники"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_color", Color("#667F99"))
		apply_font_to_label(label, 20)
		$VehicleContainer.add_child(label)
		return
	
	var btn_normal = StyleBoxFlat.new()
	btn_normal.bg_color = Color("#141F33")
	btn_normal.corner_radius_top_left = 6
	btn_normal.corner_radius_top_right = 6
	btn_normal.corner_radius_bottom_left = 6
	btn_normal.corner_radius_bottom_right = 6
	btn_normal.border_width_left = 1
	btn_normal.border_width_right = 1
	btn_normal.border_width_top = 1
	btn_normal.border_width_bottom = 1
	btn_normal.border_color = Color("#1A2640")
	
	var btn_hover = btn_normal.duplicate()
	btn_hover.bg_color = Color("#1A2E59")
	btn_hover.border_color = Color("#3366B3")
	
	var btn_selected = btn_normal.duplicate()
	btn_selected.bg_color = Color("#264080")
	btn_selected.border_color = Color("#0099FF")
	
	for entry in all_vehicles:
		var vehicle = entry["data"]
		var template = Global.vehicle_templates.get(vehicle.get("template", "truck"), {})
		
		var button = Button.new()
		var status_text = get_status_text(vehicle.get("status", "idle"))
		button.text = template.get("name", "Транспорт") + " #" + str(vehicle.get("id", 0)) + " (" + status_text + ")"
		button.size = Vector2(192, 44)
		button.set_meta("vehicle_id", vehicle.get("id", 0))
		button.pressed.connect(_on_vehicle_selected.bind(vehicle.get("id", 0)))
		
		if selected_vehicle_id == vehicle.get("id", 0):
			button.add_theme_stylebox_override("normal", btn_selected)
			button.add_theme_stylebox_override("hover", btn_selected)
			button.add_theme_color_override("font_color", Color("#E6F2FF"))
		else:
			button.add_theme_stylebox_override("normal", btn_normal)
			button.add_theme_stylebox_override("hover", btn_hover)
			button.add_theme_color_override("font_color", Color("#99BFFF"))
		
		apply_font_to_button(button, 18)
		
		$VehicleContainer.add_child(button)
		vehicle_buttons[vehicle.get("id", 0)] = button


func get_status_text(status: String) -> String:
	var map = {
		"idle": "Ожидает",
		"traveling": "В пути",
		"working": "Копает",
		"unloading": "Разгружается",
		"loading": "Загружается",
		"returning": "Возвращается"
	}
	return map.get(status, status)


func _on_vehicle_selected(vehicle_id: int):
	if is_task_window_open:
		print("Сначала закройте окно задачи!")
		return
	
	selected_vehicle_id = vehicle_id
	
	var btn_normal = StyleBoxFlat.new()
	btn_normal.bg_color = Color("#141F33")
	btn_normal.corner_radius_top_left = 6
	btn_normal.corner_radius_top_right = 6
	btn_normal.corner_radius_bottom_left = 6
	btn_normal.corner_radius_bottom_right = 6
	btn_normal.border_width_left = 1
	btn_normal.border_width_right = 1
	btn_normal.border_width_top = 1
	btn_normal.border_width_bottom = 1
	btn_normal.border_color = Color("#1A2640")
	
	var btn_hover = btn_normal.duplicate()
	btn_hover.bg_color = Color("#1A2E59")
	btn_hover.border_color = Color("#3366B3")
	
	var btn_selected = btn_normal.duplicate()
	btn_selected.bg_color = Color("#264080")
	btn_selected.border_color = Color("#0099FF")
	
	for id in vehicle_buttons:
		var btn = vehicle_buttons.get(id)
		if btn:
			if id == selected_vehicle_id:
				btn.add_theme_stylebox_override("normal", btn_selected)
				btn.add_theme_stylebox_override("hover", btn_selected)
				btn.add_theme_color_override("font_color", Color("#E6F2FF"))
			else:
				btn.add_theme_stylebox_override("normal", btn_normal)
				btn.add_theme_stylebox_override("hover", btn_hover)
				btn.add_theme_color_override("font_color", Color("#99BFFF"))
			apply_font_to_button(btn, 18)
	show_info_panel()


func show_info_panel():
	if selected_vehicle_id == null:
		hide_info_panel()
		return
	
	var vehicle = get_vehicle_by_id(selected_vehicle_id)
	if vehicle == null:
		hide_info_panel()
		return
	
	var template = Global.vehicle_templates.get(vehicle.get("template", "truck"), {})
	
	$Control.visible = true
	
	if template.get("icon"):
		$Control/VehicleIcon.texture = template.get("icon")
		$Control/VehicleIcon.visible = true
	else:
		$Control/VehicleIcon.visible = false
	
	$Control/VehicleInfo.add_theme_color_override("font_color", Color("#E6F2FF"))
	apply_font_to_label($Control/VehicleInfo, 18)
	
	var info_text = ""
	info_text += template.get("name", "Транспорт") + " #" + str(vehicle.get("id", 0)) + "\n"
	info_text += "Статус: " + get_status_text(vehicle.get("status", "idle")) + "\n"
	
	if vehicle.get("template") == "truck":
		var current_ore = vehicle.get("ore", 0)
		var capacity = vehicle.get("capacity", 50)
		info_text += "Груз: " + str(current_ore) + " / " + str(capacity) + " кг\n"
		info_text += "Грузоподъёмность: " + str(capacity) + " кг"
	elif vehicle.get("template") == "excavator":
		var current_ore = vehicle.get("ore_amount", 0)
		var capacity = 10
		info_text += "Груз: " + str(current_ore) + " / " + str(capacity) + " кг\n"
		if vehicle.get("is_full", false):
			info_text += "Ковш полон! Нужно разгрузить в грузовик."
		else:
			info_text += "Ковш готов к работе"
	
	if vehicle.get("task"):
		info_text += "\nЗадача: " + get_task_text(vehicle.get("task"))
	
	var location_text = ""
	var location = vehicle.get("location", "parking")
	if location == "parking":
		location_text = "На парковке"
	elif location == "level":
		location_text = "На уровне #" + str(vehicle.get("location_id", 0))
	elif location == "factory":
		location_text = "На фабрике"
	elif location == "traveling":
		location_text = "В пути"
	info_text += "\nГде: " + location_text + "\n"
	
	$Control/VehicleInfo.text = info_text
	
	var can_assign_task = vehicle.get("status") == "idle" and not is_task_window_open
	$Control/TaskButton.visible = true
	$Control/TaskButton.disabled = not can_assign_task
	$Control/TaskButton.text = "Задача" if can_assign_task else "Занят"
	
	if vehicle.get("status") == "traveling":
		$Control/ProgressBar.visible = true
		$Control/ProgressBar.value = vehicle.get("progress", 0.0)
	else:
		$Control/ProgressBar.visible = false


func hide_info_panel():
	$Control.visible = false
	selected_vehicle_id = null


func get_vehicle_by_id(vehicle_id: int):
	if vehicle_id == null:
		return null
	for truck in Global.vehicles["trucks"]:
		if truck.get("id") == vehicle_id:
			return truck
	for excavator in Global.vehicles["excavators"]:
		if excavator.get("id") == vehicle_id:
			return excavator


func _on_task_button_pressed() -> void:
	open_task_window()


func _remove_vehicle_from_current_level(vehicle: Dictionary) -> void:
	if vehicle.get("location") != "level":
		return
	
	var level_data = Global.level_state.get(vehicle.get("location_id", 0))
	if not level_data:
		return
	
	var key = "trucks" if vehicle.get("template") == "truck" else "excavators"
	var new_list = []
	for entry in level_data.get(key, []):
		if entry.get("id") != vehicle.get("id"):
			new_list.append(entry)
	level_data[key] = new_list


func _dispatch_vehicle(vehicle: Dictionary, task: String, target_level: int = 0) -> void:
	_remove_vehicle_from_current_level(vehicle)
	vehicle["status"] = "traveling"
	vehicle["task"] = task
	vehicle["progress"] = 0.0
	if task == "go_to_level":
		vehicle["target_level"] = target_level


func on_task_selected(task_type: String, target: int):
	var vehicle = get_vehicle_by_id(selected_vehicle_id)
	if vehicle == null:
		return
	
	if task_type == "Отправить на уровень":
		if vehicle.get("location") == "level" and vehicle.get("location_id") == target:
			print("Транспорт уже на этом уровне!")
			return
		_dispatch_vehicle(vehicle, "go_to_level", target)
		print("Транспорт #", vehicle.get("id"), " отправлен на уровень ", target)
	
	elif task_type == "Отвезти на фабрику":
		if vehicle.get("ore", 0) <= 0:
			print("Грузовик пуст! Нечего везти на фабрику.")
			return
		if vehicle.get("location") == "factory":
			print("Грузовик уже на фабрике!")
			return
		
		_remove_vehicle_from_current_level(vehicle)
		
		vehicle["status"] = "traveling"
		vehicle["task"] = "go_to_factory"
		vehicle["progress"] = 0.0
		vehicle["location"] = "traveling"
		vehicle["location_id"] = null
		print("Грузовик #", vehicle.get("id"), " отправлен на фабрику")
	
	elif task_type == "Вернуться на парковку":
		if vehicle.get("location") == "parking":
			print("Транспорт уже на парковке!")
			return
		_dispatch_vehicle(vehicle, "go_to_parking")
		print("Транспорт #", vehicle.get("id"), " возвращается на парковку")
	
	is_task_window_open = false
	update_vehicle_list()
	show_info_panel()


func open_task_window():
	if selected_vehicle_id == null:
		return
	
	var vehicle = get_vehicle_by_id(selected_vehicle_id)
	if vehicle == null:
		return
	
	if is_task_window_open:
		return
	
	var task_window = TaskWindow.instantiate()
	task_window.vehicle_type = vehicle.get("template", "truck")
	task_window.task_selected.connect(on_task_selected)
	task_window.task_cancelled.connect(_on_task_window_cancelled)
	
	task_window.tree_exited.connect(_on_task_window_closed)
	
	$PopupContainer.add_child(task_window)
	is_task_window_open = true
	
	show_info_panel()


func _on_task_window_closed():
	is_task_window_open = false
	show_info_panel()


func _on_task_window_cancelled():
	is_task_window_open = false
	show_info_panel()


func get_task_text(task: String) -> String:
	if task == null or task == "":
		return "Нет"
	var map = {
		"go_to_level": "Едет на уровень",
		"go_to_factory": "Едет на фабрику",
		"go_to_parking": "Едет на парковку",
		"unload_at_factory": "Разгружается"
	}
	return map.get(task, task)
