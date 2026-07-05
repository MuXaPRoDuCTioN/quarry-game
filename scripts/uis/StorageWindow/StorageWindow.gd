extends Panel


signal window_closed
signal update_ui


var is_dragging = false
var drag_start = Vector2()
var selected_ore = null
var price = 0
var count = 1
var ore_buttons = {}
var update_timer = 0.0
var UPDATE_INTERVAL = 0.5


func _ready() -> void:
	$BottomPanel/HSlider.min_value = 1
	update_bottom_panel()
	update_ore_grid()
	set_process(true)


func _process(delta: float) -> void:
	update_timer += delta
	if update_timer >= UPDATE_INTERVAL:
		update_timer = 0.0
		update_ore_grid()
		if selected_ore != null:
			update_bottom_panel()


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


func _on_close_button_pressed() -> void:
	emit_signal("window_closed")
	queue_free()


func _on_ore_button_pressed(ore_id):
	if selected_ore == ore_id:
		highlight_button(ore_id, false)
		selected_ore = null
	else:
		if selected_ore != null:
			highlight_button(selected_ore, false)
		selected_ore = ore_id
		highlight_button(ore_id, true)
	update_bottom_panel()


func update_ore_grid():
	var has_changes = false
	for ore_id in Global.storage:
		var current_count = Global.storage[ore_id]
		if ore_buttons.has(ore_id):
			var button = ore_buttons[ore_id]
			for child in button.get_children():
				if child is Label:
					child.text = str(current_count)
					break
		else:
			has_changes = true
			break
	
	if has_changes or ore_buttons.size() != Global.storage.size():
		_rebuild_ore_grid()


func _rebuild_ore_grid():
	for child in $GridContainer.get_children():
		child.queue_free()
	ore_buttons.clear()
	
	for ore_id in Global.storage:
		var count = Global.storage[ore_id]
		if count == 0:
			continue
		
		var ore_data = Global.ore_data[ore_id]
		var button = Button.new()
		button.custom_minimum_size = Vector2(80, 80)
		
		var texture_rect = TextureRect.new()
		texture_rect.texture = ore_data["icon"]
		texture_rect.size = Vector2(64, 64)
		texture_rect.position = Vector2(8, 8)
		button.add_child(texture_rect)
		
		var count_label = Label.new()
		count_label.text = str(count)
		count_label.position = Vector2(55, 62)
		button.add_child(count_label)
		
		button.set_meta("ore_id", ore_id)
		button.pressed.connect(_on_ore_button_pressed.bind(ore_id))
		
		$GridContainer.add_child(button)
		ore_buttons[ore_id] = button


func update_bottom_panel():
	if selected_ore == null:
		$BottomPanel/SelectedLabel.visible = false
		$BottomPanel/HSlider.visible = false
		$BottomPanel/PriceLabel.visible = false
		$BottomPanel/SellButton.disabled = true
		$BottomPanel/HSlider.max_value = 1
		$BottomPanel/HSlider.value = 1
	else:
		var current_count = Global.storage.get(selected_ore, 0)
		if current_count <= 0:
			highlight_button(selected_ore, false)
			selected_ore = null
			update_bottom_panel()
			return
		
		$BottomPanel/SelectedLabel.visible = true
		$BottomPanel/HSlider.visible = true
		$BottomPanel/PriceLabel.visible = true
		$BottomPanel/SellButton.disabled = false
		
		price = Global.ore_data[selected_ore]["price"]
		$BottomPanel/SelectedLabel.text = "Выбрано: " + str(int($BottomPanel/HSlider.value)) + " шт."
		$BottomPanel/PriceLabel.text = "Цена: " + str(price * int($BottomPanel/HSlider.value)) + " монет"
		$BottomPanel/HSlider.max_value = current_count
		if $BottomPanel/HSlider.value > current_count:
			$BottomPanel/HSlider.value = current_count


func _on_h_slider_value_changed(value: float) -> void:
	if selected_ore != null:
		$BottomPanel/SelectedLabel.text = "Выбрано: " + str(int(value)) + " шт."
		$BottomPanel/PriceLabel.text = "Цена: " + str(price * int(value)) + " монет"


func _on_sell_button_pressed() -> void:
	if selected_ore == null:
		return
	var amount = int($BottomPanel/HSlider.value)
	if amount <= 0:
		return
	Global.sell_ore(selected_ore, amount)
	emit_signal("update_ui")
	selected_ore = null
	_rebuild_ore_grid()
	update_bottom_panel()


func highlight_button(ore_id, highlight):
	if ore_buttons.has(ore_id):
		var button = ore_buttons[ore_id]
		if highlight:
			var style = StyleBoxFlat.new()
			style.set_border_width_all(2)
			style.border_color = Color.YELLOW
			button.add_theme_stylebox_override("normal", style)
			button.add_theme_color_override("font_color", Color.YELLOW)
		else:
			button.remove_theme_color_override("font_color")
			button.remove_theme_stylebox_override("normal")
