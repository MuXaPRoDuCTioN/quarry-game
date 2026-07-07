extends Panel


signal game_over_closed


@onready var title_label = $TitleLabel
@onready var name_input = $NameInput
@onready var score_label = $ScoreLabel
@onready var breakdown_label = $BreakdownLabel
@onready var save_button = $SaveButton
@onready var skip_button = $SkipButton


var final_score: int = 0


func _ready():
	center_window()
	setup_ui()
	
	final_score = Global.calculate_final_score()
	
	score_label.text = "Итоговый счёт: " + str(final_score)
	
	var breakdown_text = ""
	breakdown_text += "Стены perfect: " + str(Global.score_breakdown["walls_perfect"]) + " × 500 = " + str(Global.score_breakdown["walls_perfect"] * 500) + "\n"
	breakdown_text += "Стены good: " + str(Global.score_breakdown["walls_good"]) + " × 300 = " + str(Global.score_breakdown["walls_good"] * 300) + "\n"
	breakdown_text += "Стены medium: " + str(Global.score_breakdown["walls_medium"]) + " × 100 = " + str(Global.score_breakdown["walls_medium"] * 100) + "\n"
	breakdown_text += "Уровней пройдено: " + str(Global.score_breakdown["levels_completed"]) + " × 1000 = " + str(Global.score_breakdown["levels_completed"] * 1000) + "\n"
	breakdown_text += "Бонус за время: " + str(Global.score_breakdown["time_bonus"]) + "\n"
	breakdown_text += "Бонус за деньги: " + str(Global.score_breakdown["money_bonus"])
	breakdown_label.text = breakdown_text
	
	save_button.pressed.connect(_on_save_pressed)
	skip_button.pressed.connect(_on_skip_pressed)
	name_input.text = ""
	name_input.placeholder_text = "Введите имя"
	name_input.max_length = 8
	name_input.text_changed.connect(_on_name_changed)
	name_input.grab_focus()
	
	_validate_name()


func setup_ui():
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
	panel_style.border_color = Color("#FFB84D")
	add_theme_stylebox_override("panel", panel_style)
	
	if title_label:
		title_label.add_theme_color_override("font_color", Color("#FFB84D"))
		title_label.add_theme_font_size_override("font_size", 20)
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if Global.exo2_font:
			title_label.add_theme_font_override("font", Global.exo2_font)
	
	if score_label:
		score_label.add_theme_color_override("font_color", Color("#E6F2FF"))
		score_label.add_theme_font_size_override("font_size", 16)
		if Global.exo2_font:
			score_label.add_theme_font_override("font", Global.exo2_font)
	
	if breakdown_label:
		breakdown_label.add_theme_color_override("font_color", Color("#E6F2FF"))
		breakdown_label.add_theme_font_size_override("font_size", 12)
		if Global.exo2_font:
			breakdown_label.add_theme_font_override("font", Global.exo2_font)
	
	if name_input:
		name_input.add_theme_font_size_override("font_size", 16)
		if Global.exo2_font:
			name_input.add_theme_font_override("font", Global.exo2_font)
		var input_style = StyleBoxFlat.new()
		input_style.bg_color = Color("#1A2640")
		input_style.corner_radius_top_left = 6
		input_style.corner_radius_top_right = 6
		input_style.corner_radius_bottom_left = 6
		input_style.corner_radius_bottom_right = 6
		input_style.border_width_left = 1
		input_style.border_width_right = 1
		input_style.border_width_top = 1
		input_style.border_width_bottom = 1
		input_style.border_color = Color("#3366B3")
		name_input.add_theme_stylebox_override("normal", input_style)
		name_input.add_theme_color_override("font_color", Color("#E6F2FF"))
	
	setup_button(save_button, Color("#264080"), Color("#4059A6"))
	setup_button(skip_button, Color("#402020"), Color("#603030"))


func setup_button(button: Button, normal_color: Color, hover_color: Color):
	if not button:
		return
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = normal_color
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
	btn_hover.bg_color = hover_color
	btn_hover.border_color = Color("#0099FF")
	button.add_theme_stylebox_override("normal", btn_style)
	button.add_theme_stylebox_override("hover", btn_hover)
	button.add_theme_color_override("font_color", Color("#E6F2FF"))
	button.add_theme_font_size_override("font_size", 16)
	if Global.exo2_font:
		button.add_theme_font_override("font", Global.exo2_font)


func center_window():
	var viewport = get_viewport().get_visible_rect().size
	global_position = (viewport - size) / 2


func _validate_name():
	var name = name_input.text.strip_edges()
	var is_valid = false
	
	if not name.is_empty():
		is_valid = true
		for char in name:
			var char_code = char.unicode_at(0)
			if not ((char_code >= 65 and char_code <= 90) or 
					(char_code >= 97 and char_code <= 122) or 
					(char_code >= 48 and char_code <= 57)):
				is_valid = false
				break
	
	save_button.disabled = not is_valid


func _on_name_changed(_new_text):
	_validate_name()


func _on_save_pressed():
	var player_name = name_input.text.strip_edges()
	if player_name.is_empty():
		player_name = "Anonymous"
	
	if player_name.length() > 8:
		player_name = player_name.substr(0, 8)
	
	LeaderboardManager.add_entry(
		player_name,
		final_score,
		Global.levels_completed,
		Global.score_breakdown.duplicate()
	)
	
	# Сразу закрываем окно — QuarryMap сам поменяет сцену
	emit_signal("game_over_closed")


func _on_skip_pressed():
	# Сразу закрываем окно
	emit_signal("game_over_closed")
