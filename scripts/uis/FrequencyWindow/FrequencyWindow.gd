extends Panel


signal window_closed
signal frequency_selected


var secret_frequency
var attempts = 5
var current_freq
var status
var is_dragging = false
var drag_start = Vector2()


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	randomize()
	secret_frequency = randi_range(100, 1000)
	current_freq = $HSlider.value
	$FrequencyLabel.text = "Частота: " + str(current_freq) + " Гц"
	$AttemptsLabel.text = "Попытки: " + str(attempts)
	$ConfirmButton.visible = false
	$ResultLabel.visible = false
	draw_graphic()
	$Marker.visible = true
	move_point($HSlider.value)


func _gui_input(event: InputEvent) -> void:
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


func _on_confirm_button_pressed() -> void:
	emit_signal("frequency_selected", current_freq, status)
	emit_signal("window_closed")
	queue_free()


func _on_h_slider_value_changed(value: float) -> void:
	current_freq = $HSlider.value
	$FrequencyLabel.text = "Частота: " + str(current_freq) + " Гц"
	
	$ConfirmButton.visible = false
	$ResultLabel.visible = false
	
	move_point(current_freq)


func _on_apply_button_pressed() -> void:
	attempts -= 1
	$AttemptsLabel.text = "Попытки: " + str(attempts)
	
	var delta = abs(secret_frequency - current_freq)
	
	if delta <= 10:
		$ResultLabel.text = "Идеально! (+-" + str(delta) + " Гц)"
		$ResultLabel.add_theme_color_override("font_color", Color.GREEN)
		status = 1
	elif delta <= 50:
		$ResultLabel.text = "Хорошо! (+-" + str(delta) + " Гц)"
		$ResultLabel.add_theme_color_override("font_color", Color.YELLOW)
		status = 2
	elif delta <= 100:
		$ResultLabel.text = "Плохо! (+-" + str(delta) + " Гц)"
		$ResultLabel.add_theme_color_override("font_color", Color.ORANGE)
		status = 3
	else:
		$ResultLabel.text = "КАТАСТРОФА! (+-" + str(delta) + " Гц)"
		$ResultLabel.add_theme_color_override("font_color", Color.RED)
		status = 4
	
	$ResultLabel.visible = true
	$ConfirmButton.visible = true
	
	if attempts == 0:
		$HSlider.editable = false
		$ApplyButton.disabled = true


func draw_graphic():
	var graphic = $Line2D
	graphic.clear_points()
	
	var x = 56
	var y = 288
	var freq = 100
	var diff
	var value
	
	for i in range(100):
		diff = secret_frequency - freq
		value = exp(-diff * diff / 1000.0)
		graphic.add_point(Vector2(x, y - value * 200))
		x += 4.3
		freq += 10


func move_point(freq):
	var x = 56
	var y = 288
	var diff
	var value
	
	diff = secret_frequency - freq
	value = exp(-diff * diff / 1000.0)
	$Marker.position = Vector2(x + (freq - 100) * 0.43, y - value * 200)
