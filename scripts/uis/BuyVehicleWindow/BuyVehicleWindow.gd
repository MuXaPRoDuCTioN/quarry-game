extends Panel


signal window_closed
signal update_ui


var is_dragging = false
var drag_start = Vector2()


var selected_type = "truck"
var tab_buttons = {}


var stat_names = {
	"capacity": "Грузоподъёмность",
	"speed": "Скорость",
	"damage": "Мощность копания",
	"price": "Цена"
}


@onready var buy_button = $VBoxContainer/VehicleInfo/BuyButton
@onready var vehicle_name = $VBoxContainer/VehicleInfo/VehicleName
@onready var vehicle_description = $VBoxContainer/VehicleInfo/VehicleDescription
@onready var vehicle_stats = $VBoxContainer/VehicleInfo/VehicleStats
@onready var vehicle_count = $VBoxContainer/VehicleInfo/VehicleCount
@onready var vehicle_price = $VBoxContainer/VehicleInfo/VehiclePrice
@onready var vehicle_icon = $VBoxContainer/VehicleInfo/VehicleIcon


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


func create_tabs():
	var tab_container = $VBoxContainer/TabContainer
	
	for child in tab_container.get_children():
		child.queue_free()
	
	tab_buttons.clear()
	
	var tab_normal = StyleBoxFlat.new()
	tab_normal.bg_color = Color("#141F33")
	tab_normal.corner_radius_top_left = 6
	tab_normal.corner_radius_top_right = 6
	tab_normal.border_width_left = 1
	tab_normal.border_width_right = 1
	tab_normal.border_width_top = 1
	tab_normal.border_width_bottom = 1
	tab_normal.border_color = Color("#1A2640")
	
	var tab_hover = tab_normal.duplicate()
	tab_hover.bg_color = Color("#1A2E59")
	tab_hover.border_color = Color("#3366B3")
	
	var tab_selected = tab_normal.duplicate()
	tab_selected.bg_color = Color("#264080")
	tab_selected.border_color = Color("#0099FF")
	
	for type in Global.vehicle_templates:
		var data = Global.vehicle_templates[type]
		var button = Button.new()
		button.text = data["name"]
		button.custom_minimum_size = Vector2(100, 40)
		button.set_meta("type", type)
		button.pressed.connect(_on_tab_pressed.bind(type))
		
		button.add_theme_stylebox_override("normal", tab_normal)
		button.add_theme_stylebox_override("hover", tab_hover)
		button.add_theme_color_override("font_color", Color("#99BFFF"))
		apply_font_to_button(button, 20)
		
		tab_container.add_child(button)
		tab_buttons[type] = button
		
	if tab_buttons.size() > 0:
		highlight_tab(tab_buttons.keys()[0])


func highlight_tab(type: String):
	var tab_selected = StyleBoxFlat.new()
	tab_selected.bg_color = Color("#264080")
	tab_selected.corner_radius_top_left = 6
	tab_selected.corner_radius_top_right = 6
	tab_selected.border_width_left = 1
	tab_selected.border_width_right = 1
	tab_selected.border_width_top = 1
	tab_selected.border_width_bottom = 1
	tab_selected.border_color = Color("#0099FF")
	
	var tab_normal = StyleBoxFlat.new()
	tab_normal.bg_color = Color("#141F33")
	tab_normal.corner_radius_top_left = 6
	tab_normal.corner_radius_top_right = 6
	tab_normal.border_width_left = 1
	tab_normal.border_width_right = 1
	tab_normal.border_width_top = 1
	tab_normal.border_width_bottom = 1
	tab_normal.border_color = Color("#1A2640")
	
	for t in tab_buttons:
		var button = tab_buttons[t]
		if t == type:
			button.add_theme_stylebox_override("normal", tab_selected)
			button.add_theme_stylebox_override("hover", tab_selected)
			button.add_theme_color_override("font_color", Color("#E6F2FF"))
		else:
			button.add_theme_stylebox_override("normal", tab_normal)
			button.add_theme_stylebox_override("hover", tab_normal)
			button.add_theme_color_override("font_color", Color("#99BFFF"))
		apply_font_to_button(button, 20)


func _on_tab_pressed(type):
	selected_type = type
	highlight_tab(type)
	update_info_panel()


func update_info_panel():
	var template = Global.vehicle_templates[selected_type]
	var count = Global.get_vehicle_count(selected_type)
	var max_count = Global.get_max_vehicles(selected_type)
	var current_price = Global.get_vehicle_price(selected_type)
	
	if vehicle_name:
		vehicle_name.text = template["name"]
		vehicle_name.add_theme_color_override("font_color", Color("#E6F2FF"))
		apply_font_to_label(vehicle_name, 26)
	
	if vehicle_description:
		vehicle_description.text = template["description"]
		vehicle_description.add_theme_color_override("font_color", Color("#99BFFF"))
		apply_font_to_label(vehicle_description, 18)
	
	var stats_text = ""
	var stat_values = []
	
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
	
	if vehicle_stats:
		vehicle_stats.text = stats_text
		vehicle_stats.add_theme_color_override("font_color", Color("#E6F2FF"))
		apply_font_to_label(vehicle_stats, 18)
	
	if vehicle_count:
		vehicle_count.text = "Куплено: " + str(count) + " / " + str(max_count)
		vehicle_count.add_theme_color_override("font_color", Color("#99BFFF"))
		apply_font_to_label(vehicle_count, 18)
	
	if vehicle_price:
		vehicle_price.text = "Цена: " + str(current_price) + " монет"
		vehicle_price.add_theme_color_override("font_color", Color("#FFD933"))
		apply_font_to_label(vehicle_price, 20)
	
	if vehicle_icon:
		vehicle_icon.texture = template["icon"]
	
	if buy_button:
		var can_buy = Global.can_buy_vehicle(selected_type)
		buy_button.disabled = not can_buy
		if not can_buy:
			buy_button.text = "Лимит достигнут!"
		else:
			buy_button.text = "Купить"


func _on_buy_button_pressed() -> void:
	if Global.buy_vehicle(selected_type):
		print("Куплен ", selected_type)
		update_info_panel()
		emit_signal("update_ui")
	else:
		if not Global.can_buy_vehicle(selected_type):
			print("Достигнут лимит!")
		else:
			print("Не хватает средств!")


func center_window():
	var viewport_size = get_viewport().get_visible_rect().size
	var window_size = size
	
	if window_size.x == 0 and window_size.y == 0:
		await get_tree().process_frame
		window_size = size
	
	global_position = (viewport_size - window_size) / 2
