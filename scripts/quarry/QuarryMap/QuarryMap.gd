extends Node2D


var LevelButtonsGenerator = preload("res://scripts/quarry/QuarryMap/LevelButtonsGenerator.gd")
var generator


var BuyVehicleWindow = preload("res://scenes/uis/BuyVehicleWindow.tscn")
var buy_veh_window_instance
var VehicleManagementWindow = preload("res://scenes/uis/VehicleManagementWindow.tscn")
var veh_man_window_instance
var StorageWindow = preload("res://scenes/uis/StorageWindow.tscn")
var stor_window_instance


@onready var factory_progress_bar = $CanvasLayer/FactoryProgressBar
@onready var factory_label = $CanvasLayer/FactoryLabel
@onready var levels_container = $LevelsContainer
@onready var storage_button = $CanvasLayer/StorageButton
@onready var buy_menu = $CanvasLayer/BuyMenu
@onready var vehicle_menu = $CanvasLayer/VehicleMenu
@onready var back_button = $CanvasLayer/BackButton


var is_window_open = false


func _ready():
	if Global.is_new_game:
		if Global.money == 0:
			Global.money = 1000
		Global.purchased_levels.clear()
		Global.is_new_game = false
	
	# Рисуем фон (самый нижний слой)
	draw_background()
	
	# Подключаем кнопку склада
	if storage_button:
		storage_button.pressed.connect(_on_storage_button_pressed)
	
	generator = LevelButtonsGenerator.new()
	generator.level_pressed.connect(_on_level_pressed)
	generator.generate(levels_container, 50)
	generator.update_buttons()
	
	# Рисуем шахту ПОСЛЕ кнопок
	draw_quarry_pit(50)
	
	update_ui()
	
	setup_factory_progress_style()


func setup_factory_progress_style():
	if factory_progress_bar:
		var bg_style = StyleBoxFlat.new()
		bg_style.bg_color = Color("#1A2640")
		bg_style.corner_radius_top_left = 4
		bg_style.corner_radius_top_right = 4
		bg_style.corner_radius_bottom_left = 4
		bg_style.corner_radius_bottom_right = 4
		
		var fill_style = StyleBoxFlat.new()
		fill_style.bg_color = Color("#0099FF")
		fill_style.corner_radius_top_left = 4
		fill_style.corner_radius_top_right = 4
		fill_style.corner_radius_bottom_left = 4
		fill_style.corner_radius_bottom_right = 4
		
		factory_progress_bar.add_theme_stylebox_override("slider", bg_style)
		factory_progress_bar.add_theme_stylebox_override("fill", fill_style)
		factory_progress_bar.add_theme_color_override("font_color", Color("#E6F2FF"))
		factory_progress_bar.add_theme_font_size_override("font_size", 12)
		if Global.exo2_font:
			factory_progress_bar.add_theme_font_override("font", Global.exo2_font)


func draw_background():
	# Небо
	var sky = ColorRect.new()
	sky.color = Color(0.4, 0.6, 0.9, 1.0)
	sky.size = Vector2(1200, 300)
	sky.position = Vector2(0, 0)
	add_child(sky)
	move_child(sky, 0)
	
	# Трава
	var grass = ColorRect.new()
	grass.color = Color(0.2, 0.6, 0.2, 1.0)
	grass.size = Vector2(1200, 40)
	grass.position = Vector2(0, 300)
	add_child(grass)
	move_child(grass, 0)
	
	# Земля
	var ground = ColorRect.new()
	ground.color = Color(0.4, 0.25, 0.1, 1.0)
	ground.size = Vector2(1200, 400)
	ground.position = Vector2(0, 340)
	add_child(ground)
	move_child(ground, 0)


func draw_quarry_pit(max_levels: int):
	var floor_height = 65.0
	var button_h = 60.0
	var pit_top = 0.0
	var pit_bottom = floor_height * (max_levels - 1) + button_h + 50.0
	var pit_height = pit_bottom - pit_top
	
	var left_wall_x = -70.0
	var wall_width = 70.0
	var right_wall_x = 270.0
	var inner_left = 0.0
	var inner_right = 270.0
	
	var pit = Node2D.new()
	pit.name = "QuarryPit"
	levels_container.add_child(pit)
	levels_container.move_child(pit, 0)
	
	var surface_color = Color("#8A7A55")
	var deep_color = Color("#241C14")
	var wall_light = Color("#9C8055")
	var wall_dark = Color("#332619")
	
	var strips = 26
	var strip_h = pit_height / strips
	
	# Фон карьера между стенами
	for s in range(strips):
		var t = float(s) / strips
		var strip = ColorRect.new()
		strip.color = surface_color.lerp(deep_color, t)
		strip.position = Vector2(inner_left - 6, pit_top + s * strip_h)
		strip.size = Vector2(inner_right - inner_left + 12, strip_h + 1)
		pit.add_child(strip)
	
	# Стены карьера слева и справа
	for s in range(strips):
		var t = float(s) / strips
		var wall_color = wall_light.lerp(wall_dark, t)
		for wx in [left_wall_x, right_wall_x]:
			var wall_strip = ColorRect.new()
			wall_strip.color = wall_color
			wall_strip.position = Vector2(wx, pit_top + s * strip_h)
			wall_strip.size = Vector2(wall_width, strip_h + 1)
			pit.add_child(wall_strip)
	
	# Уступы (бенчи) карьера
	var bench_step = floor_height * 5.0
	var bench_i = 0
	while pit_top + bench_i * bench_step < pit_bottom:
		var by = pit_top + bench_i * bench_step
		for wx in [left_wall_x, right_wall_x]:
			var bench_edge = ColorRect.new()
			bench_edge.color = Color("#C9B385")
			bench_edge.size = Vector2(wall_width, 3)
			bench_edge.position = Vector2(wx, by)
			pit.add_child(bench_edge)
			
			var bench_shadow = ColorRect.new()
			bench_shadow.color = Color(0, 0, 0, 0.25)
			bench_shadow.size = Vector2(wall_width, 6)
			bench_shadow.position = Vector2(wx, by + 3)
			pit.add_child(bench_shadow)
		bench_i += 1
	
	# Вкрапления камней в стенах
	for i in range(90):
		var wx = left_wall_x if randi_range(0, 1) == 0 else right_wall_x
		var x = wx + randi_range(4, int(wall_width) - 8)
		var y = pit_top + randi_range(0, int(pit_height))
		var t = clamp((y - pit_top) / pit_height, 0.0, 1.0)
		var base = wall_light.lerp(wall_dark, t)
		var shade = randf_range(-0.08, 0.08)
		var speck = ColorRect.new()
		speck.color = Color(clamp(base.r + shade, 0, 1), clamp(base.g + shade, 0, 1), clamp(base.b + shade, 0, 1))
		var sp_size = randi_range(3, 7)
		speck.size = Vector2(sp_size, sp_size)
		speck.position = Vector2(x, y)
		pit.add_child(speck)
	
	draw_pit_bottom(pit, left_wall_x, right_wall_x, wall_width, pit_bottom)


func draw_pit_bottom(parent: Node2D, left_x: float, right_x: float, wall_w: float, bottom_y: float):
	var floor_rect = ColorRect.new()
	floor_rect.color = Color("#1A130C")
	floor_rect.size = Vector2((right_x + wall_w) - left_x, 50)
	floor_rect.position = Vector2(left_x, bottom_y)
	parent.add_child(floor_rect)
	
	for i in range(12):
		var s = randi_range(6, 16)
		var rock = ColorRect.new()
		rock.color = Color("#332619")
		rock.size = Vector2(s, s * 0.6)
		rock.position = Vector2(left_x + randi_range(10, int((right_x + wall_w) - left_x) - 20), bottom_y + randi_range(5, 30))
		parent.add_child(rock)


func block_all_buttons():
	if buy_menu:
		buy_menu.disabled = true
	if vehicle_menu:
		vehicle_menu.disabled = true
	if back_button:
		back_button.disabled = true
	if storage_button:
		storage_button.disabled = true


func unlock_all_buttons():
	if buy_menu:
		buy_menu.disabled = false
	if vehicle_menu:
		vehicle_menu.disabled = false
	if back_button:
		back_button.disabled = false
	if storage_button:
		storage_button.disabled = false


func _on_storage_button_pressed():
	if is_window_open:
		return
	open_storage_window()


func open_storage_window():
	block_all_buttons()
	stor_window_instance = StorageWindow.instantiate()
	$CanvasLayer/PopupContainer.add_child(stor_window_instance)
	is_window_open = true
	stor_window_instance.connect("window_closed", _on_window_closed)
	stor_window_instance.connect("update_ui", update_ui)


func _on_window_closed():
	is_window_open = false
	unlock_all_buttons()


func _process(delta: float) -> void:
	update_factory_ui()
	Global.process_factory(delta)
	if not is_window_open and Global.is_game_over():
		_open_game_over_window()


func update_factory_ui():
	if factory_progress_bar == null:
		return
	
	if Global.factory_processing != null:
		var progress = Global.factory_processing.get("progress", 0.0) / Global.factory_processing.get("weight", 1.0)
		factory_progress_bar.value = clamp(progress * 100, 0, 100)
	else:
		factory_progress_bar.value = 0
	
	var total_remaining = Global.factory_queue_weight
	if Global.factory_processing != null:
		total_remaining += Global.factory_processing.get("weight", 0)
	
	if total_remaining > 0:
		factory_label.text = "Осталось " + str(total_remaining) + " кг"
	else:
		factory_label.text = "Ожидание"


func _on_level_pressed(level_num):
	if is_window_open:
		return
	
	# <<< НОВОЕ: если уровень уже пройден — ничего не делаем
	if Global.is_level_completed(level_num):
		print("Уровень ", level_num, " уже пройден!")
		return
	
	if Global.purchased_levels.has(level_num):
		Global.current_level = level_num
		get_tree().change_scene_to_file("res://scenes/quarry/QuarryLevel.tscn")
	else:
		var price = generator.get_level_price(level_num)
		if price <= Global.money:
			Global.money -= price
			Global.purchased_levels[level_num] = true
			update_ui()
			generator.update_buttons()
			generator.update_text(level_num)
			Global.current_level = level_num
			get_tree().change_scene_to_file("res://scenes/quarry/QuarryLevel.tscn")
		else:
			print("Недостаточно средств!")


func update_ui():
	$CanvasLayer/MoneyLabel.text = "Деньги: " + str(Global.money)


func _on_buy_menu_pressed() -> void:
	if is_window_open:
		return
	open_buy_vehicle_window()


func open_buy_vehicle_window():
	block_all_buttons()
	buy_veh_window_instance = BuyVehicleWindow.instantiate()
	$CanvasLayer/PopupContainer.add_child(buy_veh_window_instance)
	is_window_open = true
	buy_veh_window_instance.connect("window_closed", _on_window_closed)
	buy_veh_window_instance.connect("update_ui", update_ui)


func _on_vehicle_menu_pressed() -> void:
	if is_window_open:
		return
	open_veh_man_window()


func open_veh_man_window():
	block_all_buttons()
	veh_man_window_instance = VehicleManagementWindow.instantiate()
	$CanvasLayer/PopupContainer.add_child(veh_man_window_instance)
	is_window_open = true
	# VehicleManagementWindow использует tree_exited вместо window_closed
	veh_man_window_instance.tree_exited.connect(_on_vehicle_window_closed)


func _on_vehicle_window_closed():
	is_window_open = false
	unlock_all_buttons()


func block_all_buttons_for_tutorial(step: int):
	var allowed = TutorialManager.get_allowed_buttons(step) if TutorialManager else []
	
	# Блокируем все кнопки
	buy_menu.disabled = true
	vehicle_menu.disabled = true
	back_button.disabled = true
	storage_button.disabled = true
	
	# Разблокируем разрешённые
	for btn_name in allowed:
		match btn_name:
			"shop_button":
				buy_menu.disabled = false
			"vehicles_button":
				vehicle_menu.disabled = false
			"storage_button":
				storage_button.disabled = false
			"level_button_1":
				# Находим кнопку первого уровня и разблокируем
				var level_btn = generator.level_buttons.get(1)
				if level_btn:
					level_btn.disabled = false


func _open_game_over_window() -> void:
	if is_instance_valid(get_node_or_null("GameOverWindow")):
		return
	var GameOverScene = preload("res://scenes/uis/GameOverWindow.tscn")
	var game_over_window = GameOverScene.instantiate()
	game_over_window.name = "GameOverWindow"
	$CanvasLayer.add_child(game_over_window)
	is_window_open = true
	game_over_window.game_over_closed.connect(func():
		is_window_open = false
		get_tree().change_scene_to_file("res://scenes/main/MainMenu.tscn")
	)
