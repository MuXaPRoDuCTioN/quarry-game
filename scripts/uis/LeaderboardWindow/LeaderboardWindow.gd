extends Panel


@onready var title_label = $TitleLabel
@onready var close_button = $CloseButton
@onready var entries_container = $EntriesContainer


func _ready():
	center_window()
	setup_ui()
	update_leaderboard_display()
	close_button.pressed.connect(_on_close_pressed)


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
	panel_style.border_color = Color("#3366B3")
	add_theme_stylebox_override("panel", panel_style)
	
	if title_label:
		title_label.text = "🏆 Таблица лидеров"
		title_label.add_theme_color_override("font_color", Color("#FFB84D"))
		title_label.add_theme_font_size_override("font_size", 24)
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if Global.exo2_font:
			title_label.add_theme_font_override("font", Global.exo2_font)
	
	setup_button(close_button, Color("#264080"), Color("#4059A6"))
	
	if entries_container:
		entries_container.custom_minimum_size = Vector2(400, 300)

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
	var window_size = size
	if window_size.x == 0 or window_size.y == 0:
		await get_tree().process_frame
		window_size = size
	global_position = (viewport - window_size) / 2


func update_leaderboard_display():
	for child in entries_container.get_children():
		child.queue_free()
	
	var entries = LeaderboardManager.get_top_entries(10)
	
	if entries.is_empty():
		var empty_label = Label.new()
		empty_label.text = "Таблица пуста"
		empty_label.add_theme_color_override("font_color", Color("#667F99"))
		empty_label.add_theme_font_size_override("font_size", 18)
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if Global.exo2_font:
			empty_label.add_theme_font_override("font", Global.exo2_font)
		entries_container.add_child(empty_label)
		return
	
	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	entries_container.add_child(header)
	
	var headers = ["#", "Имя", "Счёт", "Уровни", "Дата"]
	var widths = [30, 100, 80, 60, 100]
	for i in range(headers.size()):
		var label = Label.new()
		label.text = headers[i]
		label.add_theme_color_override("font_color", Color("#FFB84D"))
		label.add_theme_font_size_override("font_size", 14)
		label.custom_minimum_size.x = widths[i]
		if Global.exo2_font:
			label.add_theme_font_override("font", Global.exo2_font)
		header.add_child(label)
	
	var separator = HSeparator.new()
	entries_container.add_child(separator)
	
	for i in range(entries.size()):
		var entry = entries[i]
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		entries_container.add_child(row)
		
		var values = [
			str(i + 1),
			entry.get("name", "???"),
			str(int(entry.get("score", 0))),
			str(int(entry.get("levels", 0))),
			entry.get("date", "???")
		]
		
		for j in range(values.size()):
			var label = Label.new()
			label.text = values[j]
			label.custom_minimum_size.x = widths[j]
			label.add_theme_font_size_override("font_size", 14)
			if Global.exo2_font:
				label.add_theme_font_override("font", Global.exo2_font)
			
			if i < 3:
				var colors = [Color("#FFD700"), Color("#C0C0C0"), Color("#CD7F32")]
				label.add_theme_color_override("font_color", colors[i])
			else:
				label.add_theme_color_override("font_color", Color("#E6F2FF"))
			
			row.add_child(label)


func _on_close_pressed():
	queue_free()
