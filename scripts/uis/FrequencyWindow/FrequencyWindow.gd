extends Panel


signal window_closed
signal frequency_selected(freq, status)


var secret_frequency: int = 0
var attempts: int = 5
var current_freq: int = 0
var status: int = 0
var is_dragging: bool = false
var drag_start: Vector2 = Vector2.ZERO
var wall_cell: Vector2i = Vector2i.ZERO


var indicator_circle: TextureRect = null
var circle_texture: ImageTexture = null
var points: Array = []


func setup(cell: Vector2i, frequency: int):
	wall_cell = cell
	secret_frequency = frequency
	current_freq = 500
	attempts = 5
	
	# Получаем породу стены
	var level_data = Global.level_state.get(Global.current_level, {})
	var wall_tiles = level_data.get("wall_tiles", {})
	var tile_id = wall_tiles.get(cell, 0)
	var rock = Global.rock_types.get(tile_id, Global.rock_types[0])
	
	# Показываем название породы
	if has_node("RockTypeLabel"):
		$RockTypeLabel.text = "Порода: " + rock["name"]
		$RockTypeLabel.modulate = rock["color"]
	
	generate_points(tile_id)
	
	$FrequencyLabel.text = "Частота: " + str(current_freq) + " Гц"
	$AttemptsLabel.text = "Попытки: " + str(attempts)
	$ConfirmButton.visible = false
	$ResultLabel.visible = false
	
	create_circle_texture()
	create_indicator_circle()
	update_indicator()
	
	set_process(true)


func generate_points(rock_type_id: int):
	points.clear()
	
	# Получаем диапазон породы
	var rock = Global.rock_types.get(rock_type_id, Global.rock_types[0])
	var min_freq = rock["min_freq"]
	var max_freq = rock["max_freq"]
	
	# Секретная частота всегда в этом диапазоне
	# Генерируем 3 фейковые частоты в том же диапазоне
	var fake_freqs = []
	var attempts = 0
	while fake_freqs.size() < 3 and attempts < 100:
		attempts += 1
		var fake = randi_range(min_freq, max_freq)
		# Округляем до 10
		fake = round(fake / 10.0) * 10
		# Не совпадает с секретной и не повторяется
		if abs(fake - secret_frequency) > 30 and not fake in fake_freqs:
			fake_freqs.append(fake)
	
	# Если не удалось найти 3 уникальные частоты, добиваем рандомом
	while fake_freqs.size() < 3:
		var fake = randi_range(min_freq, max_freq)
		fake = round(fake / 10.0) * 10
		if abs(fake - secret_frequency) > 30 and not fake in fake_freqs:
			fake_freqs.append(fake)
	
	# Собираем все частоты (секретная + 3 фейковые)
	var all_freqs = [secret_frequency] + fake_freqs
	all_freqs.shuffle()
	
	# Цвета: 2 красных, 2 зелёных
	var colors = [Color.RED, Color.RED, Color.GREEN, Color.GREEN]
	colors.shuffle()
	
	for i in range(4):
		var is_correct = (all_freqs[i] == secret_frequency)
		points.append({
			"freq": all_freqs[i],
			"color": colors[i],
			"is_correct": is_correct
		})


func create_circle_texture():
	if circle_texture == null:
		var size = 200
		var image = Image.create(size, size, false, Image.FORMAT_RGBA8)
		image.fill(Color(0, 0, 0, 0))
		for x in range(size):
			for y in range(size):
				var dx = x - size/2
				var dy = y - size/2
				if dx*dx + dy*dy < (size/2) * (size/2):
					image.set_pixel(x, y, Color.WHITE)
		circle_texture = ImageTexture.create_from_image(image)


func create_indicator_circle():
	var bg = $GraphBackground
	if bg == null:
		return
	
	for child in bg.get_children():
		child.queue_free()
	
	var bg_width = 424.0
	var bg_height = 252.0
	var center_x = bg_width / 2 - 50
	var center_y = bg_height / 2 - 30
	
	indicator_circle = TextureRect.new()
	indicator_circle.texture = circle_texture
	indicator_circle.size = Vector2(150, 150)
	indicator_circle.position = Vector2(center_x - 75, center_y - 75)
	indicator_circle.z_index = 1
	indicator_circle.modulate = Color(0.3, 0.3, 0.3, 0.3)
	bg.add_child(indicator_circle)


func update_indicator():
	if indicator_circle == null:
		return
	
	var nearest_point = null
	var nearest_dist = 9999
	
	for point in points:
		var dist = abs(point["freq"] - current_freq)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest_point = point
	
	if nearest_point == null:
		return
	
	var target_color: Color
	var bg_color: Color
	var scale_pulse: float
	var alpha_pulse: float
	
	if nearest_dist < 20:
		scale_pulse = 1.0
		alpha_pulse = 0.8
		target_color = nearest_point["color"]
		bg_color = Color(
			target_color.r * 0.3,
			target_color.g * 0.3,
			target_color.b * 0.3,
			0.6
		)
	elif nearest_dist < 100:
		var pulse = sin(Time.get_ticks_msec() / 400.0) * 0.5 + 0.5
		var fade = 1.0 - (nearest_dist / 100.0) * 0.8
		scale_pulse = 0.9 + pulse * 0.1 * fade
		alpha_pulse = 0.5 + pulse * 0.2 * fade
		target_color = nearest_point["color"]
		bg_color = Color(
			target_color.r * 0.2,
			target_color.g * 0.2,
			target_color.b * 0.2,
			0.4
		)
	else:
		var pulse = sin(Time.get_ticks_msec() / 300.0) * 0.5 + 0.5
		scale_pulse = 0.85 + pulse * 0.15
		alpha_pulse = 0.3 + pulse * 0.2
		target_color = Color(0.2, 0.2, 0.2, 0.3)
		bg_color = Color(0.05, 0.05, 0.05, 0.2)
	
	indicator_circle.scale = Vector2(scale_pulse, scale_pulse)
	indicator_circle.modulate = Color(
		target_color.r,
		target_color.g,
		target_color.b,
		alpha_pulse
	)
	
	var bg = $GraphBackground
	if bg:
		bg.color = bg_color


func _process(delta: float) -> void:
	if is_visible_in_tree():
		update_indicator()


func _ready() -> void:
	$HSlider.min_value = 100
	$HSlider.max_value = 3000
	$HSlider.step = 1
	$HSlider.value = 500
	
	if has_node("Line2D"):
		$Line2D.visible = false
	if has_node("Marker"):
		$Marker.visible = false
	
	create_circle_texture()
	create_indicator_circle()


func _on_h_slider_value_changed(value: float) -> void:
	current_freq = int(value)
	$FrequencyLabel.text = "Частота: " + str(current_freq) + " Гц"
	$ConfirmButton.visible = false
	$ResultLabel.visible = false


func _on_apply_button_pressed() -> void:
	attempts -= 1
	$AttemptsLabel.text = "Попытки: " + str(attempts)
	
	var matched_point = null
	for point in points:
		if abs(point["freq"] - current_freq) < 20:
			matched_point = point
			break
	
	var hint_text = ""
	var hint_color = Color.WHITE
	
	if matched_point == null:
		hint_text = "Холодно. Далеко от цели."
		hint_color = Color(0.3, 0.5, 1)
		status = 5
	elif matched_point["is_correct"]:
		hint_text = "Идеально! Нужная частота!"
		hint_color = Color(0, 0.8, 0.2)
		status = 1
	else:
		hint_text = "Ложный сигнал! Не та частота."
		hint_color = Color(1, 0.2, 0.2)
		status = 6
	
	$ResultLabel.text = hint_text
	$ResultLabel.add_theme_color_override("font_color", hint_color)
	$ResultLabel.visible = true
	$ConfirmButton.visible = true
	
	if attempts == 0:
		$HSlider.editable = false
		$ApplyButton.disabled = true


func _on_close_button_pressed() -> void:
	set_process(false)
	emit_signal("window_closed")
	queue_free()


func _on_confirm_button_pressed() -> void:
	set_process(false)
	emit_signal("frequency_selected", current_freq, status)
	emit_signal("window_closed")
	queue_free()


func _gui_input(event: InputEvent) -> void:
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


func move_point(freq):
	pass
