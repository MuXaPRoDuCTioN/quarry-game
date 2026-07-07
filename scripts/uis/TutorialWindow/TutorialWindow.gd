extends Panel

signal next_pressed
signal closed

@onready var tutorial_label = $TutorialLabel
@onready var next_button = $NextButton


func _ready():
	next_button.pressed.connect(_on_next_pressed)
	
	# Стилизуем окно
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color("#0D1426")
	panel_style.corner_radius_top_left = 16
	panel_style.corner_radius_top_right = 16
	panel_style.corner_radius_bottom_left = 16
	panel_style.corner_radius_bottom_right = 16
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_width_top = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color("#3366B3")
	add_theme_stylebox_override("panel", panel_style)
	
	# Стилизуем текст
	if tutorial_label:
		tutorial_label.add_theme_color_override("font_color", Color("#E6F2FF"))
		tutorial_label.add_theme_font_size_override("font_size", 18)
		if Global.exo2_font:
			tutorial_label.add_theme_font_override("font", Global.exo2_font)
	
	# Стилизуем кнопку
	if next_button:
		var btn_style = StyleBoxFlat.new()
		btn_style.bg_color = Color("#264080")
		btn_style.corner_radius_top_left = 8
		btn_style.corner_radius_top_right = 8
		btn_style.corner_radius_bottom_left = 8
		btn_style.corner_radius_bottom_right = 8
		btn_style.border_width_left = 1
		btn_style.border_width_right = 1
		btn_style.border_width_top = 1
		btn_style.border_width_bottom = 1
		btn_style.border_color = Color("#3366B3")
		
		var btn_hover = btn_style.duplicate()
		btn_hover.bg_color = Color("#4059A6")
		btn_hover.border_color = Color("#0099FF")
		
		next_button.add_theme_stylebox_override("normal", btn_style)
		next_button.add_theme_stylebox_override("hover", btn_hover)
		next_button.add_theme_color_override("font_color", Color("#E6F2FF"))
		next_button.add_theme_font_size_override("font_size", 18)
		if Global.exo2_font:
			next_button.add_theme_font_override("font", Global.exo2_font)
		
		size = Vector2(600, 350)


func show_text(text: String, button_text: String = "Далее →"):
	if tutorial_label:
		tutorial_label.text = text
	if next_button:
		next_button.text = button_text
	visible = true


func center_window():
	var viewport = get_viewport().get_visible_rect().size
	var size = self.size
	if size.x == 0 or size.y == 0:
		await get_tree().process_frame
		size = self.size
	global_position = (viewport - size) / 2


func _on_next_pressed():
	emit_signal("next_pressed")


func _on_close_button_pressed():
	emit_signal("closed")
	queue_free()


func enable_next_button():
	if next_button:
		next_button.disabled = false
