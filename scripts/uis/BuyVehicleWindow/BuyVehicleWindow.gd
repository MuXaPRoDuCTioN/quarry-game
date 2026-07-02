extends Panel


signal window_closed
signal update_ui


var is_dragging = false
var drag_start = Vector2()


var selected_type = "truck"
var tab_buttons = {}


# Словарь для перевода названий характеристик
var stat_names = {
	"capacity": "Грузоподъёмность",
	"speed": "Скорость",
	"damage": "Мощность копания",
	"price": "Цена"
}


func _ready() -> void:
	center_window()
	create_tabs()
	update_info_panel()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				var mouse_pos = get_global_mouse_position()
				var ui_nodes = get_tree().get_nodes_in_group("ui")
				for ui in ui_nodes:
					if ui.visible and ui.get_global_rect().has_point(mouse_pos):
						print("Клик по UI")
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


func _on_close_button_pressed() -> void:
	emit_signal("window_closed")
	queue_free()


func create_tabs():
	var tab_container = $VBoxContainer/TabContainer
	
	for child in tab_container.get_children():
		child.queue_free()
		
	tab_buttons.clear()
	
	for type in Global.vehicle_templates:
		var data = Global.vehicle_templates[type]
		var button = Button.new()
		button.text = data["name"]
		button.custom_minimum_size = Vector2(100, 30)
		button.set_meta("type", type)
		button.pressed.connect(_on_tab_pressed.bind(type))
		
		tab_container.add_child(button)
		tab_buttons[type] = button
		
	if tab_buttons.size() > 0:
		highlight_tab(tab_buttons.keys()[0])


func highlight_tab(type: String):
	for t in tab_buttons:
		var button = tab_buttons[t]
		if t == type:
			button.add_theme_color_override("font_color", Color.YELLOW)
		else:
			button.remove_theme_color_override("font_color")


func _on_tab_pressed(type):
	selected_type = type
	highlight_tab(type)
	update_info_panel()


func update_info_panel():
	var template = Global.vehicle_templates[selected_type]
	var count = get_vehicle_count(selected_type)
	
	$VBoxContainer/VehicleInfo/VehicleName.text = template["name"]
	$VBoxContainer/VehicleInfo/VehicleDescription.text = template["description"]
	
	var stats_text = ""
	var stat_values = []
	
	# Собираем характеристики в понятном виде
	if selected_type == "truck":
		stat_values = [
			["Грузоподъёмность", str(template.get("capacity", 0)) + " кг"],
			["Скорость", str(template.get("speed", 0)) + " ед/с"]
		]
	elif selected_type == "excavator":
		stat_values = [
			["Мощность копания", str(template.get("damage", 0)) + " кг/цикл"],
			["Скорость", str(template.get("speed", 0)) + " ед/с"]
		]
	
	for stat in stat_values:
		stats_text += stat[0] + ": " + stat[1] + "\n"
	
	$VBoxContainer/VehicleInfo/VehicleStats.text = stats_text
	$VBoxContainer/VehicleInfo/VehicleCount.text = "Куплено: " + str(count)
	$VBoxContainer/VehicleInfo/VehiclePrice.text = "Цена: " + str(template["price"]) + " монет"
	$VBoxContainer/VehicleInfo/VehicleIcon.texture = template["icon"]


func get_vehicle_count(type: String) -> int:
	if type == "truck":
		return Global.vehicles["trucks"].size()
	elif type == "excavator":
		return Global.vehicles["excavators"].size()
	return 0


func _on_buy_button_pressed() -> void:
	if Global.buy_vehicle(selected_type):
		print("Куплен ", selected_type)
		update_info_panel()
		emit_signal("update_ui")
	else:
		print("Не хватает средств!")


func center_window():
	var viewport_size = get_viewport().get_visible_rect().size
	var window_size = size
	
	if window_size.x == 0 and window_size.y == 0:
		await get_tree().process_frame
		window_size = size
	
	global_position = (viewport_size - window_size) / 2
