extends Panel
signal window_closed
signal frequency_selected(freq, status)

var secret_frequency: int = 0
var target_freq: int = 0  # частота точки в мини-игре
var attempts: int = 5
var current_freq: int = 0
var status: int = 0
var is_dragging: bool = false
var drag_start: Vector2 = Vector2.ZERO
var wall_cell: Vector2i = Vector2i.ZERO
var indicator_circle: TextureRect = null
var circle_texture: ImageTexture = null


func setup(cell: Vector2i, frequency: int):
	wall_cell = cell
	secret_frequency = frequency
	current_freq = 300  # середина диапазона 100-500
	attempts = 5
	
	var level_data = Global.level_state.get(Global.current_level, {})
	var wall_tiles = level_data.get("wall_tiles", {})
	var tile_id = wall_tiles.get(cell, 0)
	var rock = Global.rock_types.get(tile_id, Global.rock_types[0])
	
	if has_node("RockTypeLabel"):
		$RockTypeLabel.text = "Порода: " + rock["name"]
		$RockTypeLabel.modulate = rock["color"]
	
	target_freq = frequency
	
	$FrequencyLabel.text = "Частота: " + str(current_freq) + " Гц"
	$AttemptsLabel.text = "Попытки: " + str(attempts)
	$ConfirmButton.visible = false
	$ResultLabel.visible = false
	
	create_circle_texture()
	create_indicator_circle()
	update_indicator()
	set_process(true)


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
	
	var dist = abs(target_freq - current_freq)
	var max_dist = 50.0
	var normalized_dist = clamp(dist / max_dist, 0.0, 1.0)
	
	# Цвет: от серого (далеко) к зелёному (близко) — плавно
	var gray = Color(0.3, 0.3, 0.3)
	var green = Color(0, 1, 0)
	var target_color = gray.lerp(green, 1.0 - normalized_dist)
	
	# Пульсация: плавная, не зависит резко от расстояния
	var pulse = sin(Time.get_ticks_msec() / 400.0) * 0.5 + 0.5  # плавная синусоида
	
	# Масштаб: базовый + небольшая пульсация (не зависит от normalized_dist)
	var base_scale = 0.85 + (1.0 - normalized_dist) * 0.15  # ближе = чуть больше
	var scale_pulse = base_scale + pulse * 0.05  # маленькая пульсация
	
	# Альфа: зависит от расстояния, но плавно
	var base_alpha = 0.4 + (1.0 - normalized_dist) * 0.5  # ближе = ярче
	var alpha_pulse = base_alpha + pulse * 0.1  # небольшая пульсация
	
	indicator_circle.scale = Vector2(scale_pulse, scale_pulse)
	indicator_circle.modulate = Color(target_color.r, target_color.g, target_color.b, alpha_pulse)
	
	var bg = $GraphBackground
	if bg:
		var bg_color = Color(target_color.r * 0.2, target_color.g * 0.2, target_color.b * 0.2, 0.3)
		bg.color = bg_color


func _process(delta: float) -> void:
	if is_visible_in_tree():
		update_indicator()


func _ready() -> void:
	# Диапазон 100-500 Гц
	$HSlider.min_value = 100
	$HSlider.max_value = 500
	$HSlider.step = 1
	$HSlider.value = 300
	
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
	
	var dist = abs(target_freq - current_freq)
	var hint_text = ""
	var hint_color = Color.WHITE
	
	if dist < 10:
		hint_text = "Точное попадание!"
		hint_color = Color(0, 1, 0)
		status = 1
	elif dist < 25:
		hint_text = "Хорошее попадание!"
		hint_color = Color(0.5, 1, 0)
		status = 2
	elif dist < 50:
		hint_text = "Приблизительно!"
		hint_color = Color(1, 1, 0)
		status = 3
	else:
		hint_text = "Далеко от цели."
		hint_color = Color(1, 0.2, 0.2)
		status = 5
	
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
