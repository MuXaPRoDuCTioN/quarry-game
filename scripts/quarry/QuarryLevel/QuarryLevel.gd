extends Node2D


var FLOOR_TILE = Vector2i(2, 0)
var BORDER_TILE = Vector2i(3, 0)
var WALL_TILE = Vector2i(0, 0)
var RUBBLE_TILE = Vector2i(1, 0)
var TRUCK_TILE = Vector2i(1, 0)
var EXCAVATOR_TILE = Vector2i(0, 0)


@onready var wall_tile_map = $WallTileMap
@onready var border_tile_map = $BorderTileMap
@onready var rubble_tile_map = $RubbleTileMap
@onready var popup_container = $CanvasLayer/PopupContainer
@onready var vehicle_tile_map = $VehicleTileMap
@onready var floor_tile_map = $FloorTileMap


@onready var factory_progress_bar = $CanvasLayer/UIPanel/FactoryProgressBar
@onready var factory_label = $CanvasLayer/UIPanel/FactoryLabel


# Кнопки
@onready var place_generator_button = $CanvasLayer/UIPanel/PlaceGeneratorButton
@onready var start_generators_button = $CanvasLayer/UIPanel/StartGeneratorsButton


var QuarryGenerator = preload("res://scripts/quarry/QuarryLevel/QuarryGenerator.gd")
var generator
var current_level
var selected_cell
var is_window_open = false
var drawn_trucks_count = 0
var drawn_excavators_count = 0


var VehicleMovement = preload("res://scripts/quarry/QuarryLevel/VehicleMovement.gd")
var movement
var ExcavatorDigging = preload("res://scripts/quarry/QuarryLevel/ExcavatorDigging.gd")
var digging


var selection_sprite: Sprite2D = null
var selected_vehicle_for_move = null
var path_sprites = []  
var move_progress_bars = {}  # {vehicle_id: ProgressBar}
var pending_rubble_for_excavator = null


# Переменные для разгрузки
var selected_excavator_for_unload = null
var unloading_target_truck = null
var is_unloading = false
var unload_progress = 0.0
var UNLOAD_DURATION = 2.0
var pending_unload_to_truck = null


var progress_bars = {
	"travel_to_truck": null,
	"loading": null,
	"extraction": null
}
var marker_queue = []


var FrequencyWindow = preload("res://scenes/uis/FrequencyWindow.tscn")
var freq_window_instance
var StorageWindow = preload("res://scenes/uis/StorageWindow.tscn")
var stor_window_instate
var VehicleManagementWindow = preload("res://scenes/uis/VehicleManagementWindow.tscn")
var veh_man_window_instance


var WallDestructionSystem = preload("res://scripts/quarry/QuarryLevel/WallDestructionSystem.gd")
var wall_destruction_system: WallDestructionSystem
var selected_generator_id: int = -1
var GeneratorSetupWindow = preload("res://scenes/uis/GeneratorSetupWindow.tscn")
var gen_setup_instance
var WaveAnimation = preload("res://scripts/quarry/QuarryLevel/WaveAnimation.gd")
var wave_animation_instance


# Храним целевую частоту для каждой стены (после мини-игры)
var wall_target_frequencies: Dictionary = {}  # {cell: int} - частота для стены


# Состояния генераторов
var generator_placement_mode: bool = false
var generator_list: Array = []  # [{cell: Vector2i, direction: int, frequency: int, id: int}]
var is_generator_animation_running: bool = false


# Для подсветки клетки при наведении
var hover_sprite: Sprite2D = null


func _ready():
	current_level = Global.current_level
	Global.is_on_level = true
	
	if not Global.level_state.has(current_level):
		generator = QuarryGenerator.new()
		generator.generate(current_level)
		print("Сгенерирован уровень ", str(current_level))
	else:
		print("Загружен уровень ", str(current_level))
	
	# Создаём спрайт выделения
	selection_sprite = Sprite2D.new()
	selection_sprite.visible = false
	selection_sprite.centered = false
	selection_sprite.z_index = 10
	var image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for x in range(64):
		image.set_pixel(x, 0, Color.YELLOW)
		image.set_pixel(x, 63, Color.YELLOW)
	for y in range(64):
		image.set_pixel(0, y, Color.YELLOW)
		image.set_pixel(63, y, Color.YELLOW)
	var texture = ImageTexture.create_from_image(image)
	selection_sprite.texture = texture
	add_child(selection_sprite)
	
	# Создаём спрайт для подсветки при наведении
	hover_sprite = Sprite2D.new()
	hover_sprite.visible = false
	hover_sprite.centered = false
	hover_sprite.z_index = 9
	var hover_image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	hover_image.fill(Color(0, 1, 0, 0.3))
	var hover_texture = ImageTexture.create_from_image(hover_image)
	hover_sprite.texture = hover_texture
	add_child(hover_sprite)
	
	for key in progress_bars:
		var bar = ProgressBar.new()
		bar.min_value = 0
		bar.max_value = 100
		bar.value = 0
		bar.visible = false
		bar.size = Vector2(60, 12)
		bar.z_index = 25
		add_child(bar)
		progress_bars[key] = bar
	
	movement = VehicleMovement.new()
	add_child(movement)
	movement.setup({
		"floor": floor_tile_map,
		"walls": wall_tile_map,
		"border": border_tile_map,
		"rubbles": rubble_tile_map,
		"vehicles": vehicle_tile_map
	}, QuarryGenerator.new().get_level_size(current_level))
	
	movement.vehicle_moved.connect(_on_vehicle_moved)
	movement.vehicle_arrived.connect(_on_vehicle_arrived)
	movement.vehicle_progress.connect(_on_vehicle_progress)
	
	digging = ExcavatorDigging.new()
	add_child(digging)
	digging.setup(rubble_tile_map, current_level)
	digging.digging_started.connect(_on_digging_started)
	digging.digging_completed.connect(_on_digging_completed)
	digging.digging_progress.connect(_on_digging_progress)
	
	# Настраиваем систему разрушения стен
	setup_wall_destruction_system()
	
	# Настраиваем кнопки
	setup_ui_buttons()
	
	draw_quarry()
	update_ui()


func setup_ui_buttons():
	if place_generator_button:
		if not place_generator_button.is_connected("pressed", Callable(self, "_on_place_generator_button_pressed")):
			place_generator_button.pressed.connect(_on_place_generator_button_pressed)
		place_generator_button.text = "Установить генератор"
	
	if start_generators_button:
		if not start_generators_button.is_connected("pressed", Callable(self, "_on_start_generators_button_pressed")):
			start_generators_button.pressed.connect(_on_start_generators_button_pressed)
		start_generators_button.text = "Запустить генераторы"
		start_generators_button.disabled = true


func setup_wall_destruction_system():
	wall_destruction_system = WallDestructionSystem.new()
	add_child(wall_destruction_system)
	wall_destruction_system.setup(
		current_level, 
		wall_tile_map, 
		rubble_tile_map, 
		vehicle_tile_map,
		floor_tile_map
	)
	
	wall_destruction_system.wall_destroyed.connect(_on_wall_destroyed)
	wall_destruction_system.rubble_spawned.connect(_on_rubble_spawned)
	wall_destruction_system.vehicle_destroyed.connect(_on_vehicle_destroyed)


func _process(delta: float) -> void:
	if is_generator_animation_running:
		return
	
	var level_data = Global.level_state.get(current_level, {})
	var current_trucks = level_data.get("trucks", [])
	var current_excavators = level_data.get("excavators", [])
	
	if current_trucks.size() != drawn_trucks_count or current_excavators.size() != drawn_excavators_count:
		draw_quarry()
		drawn_trucks_count = current_trucks.size()
		drawn_excavators_count = current_excavators.size()
	
	movement.update(delta)
	
	if is_unloading:
		unload_progress += delta
		update_progress_bar("loading", unload_progress / UNLOAD_DURATION)
		
		if unload_progress >= UNLOAD_DURATION:
			finish_unloading()
	
	update_factory_ui()
	
	# Обновляем подсветку при наведении в режиме установки
	if generator_placement_mode and hover_sprite and not is_window_open:
		var mouse_pos = get_global_mouse_position()
		var cell = floor_tile_map.local_to_map(mouse_pos)
		
		# Проверяем, является ли клетка полом и свободна
		var is_floor = false
		for floor_cell in level_data.get("floor", []):
			if floor_cell == cell:
				is_floor = true
				break
		
		if is_floor and wall_destruction_system.is_cell_free(cell):
			hover_sprite.position = cell * 64
			hover_sprite.visible = true
		else:
			hover_sprite.visible = false
	else:
		if hover_sprite:
			hover_sprite.visible = false


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed:
			if event.button_index == MOUSE_BUTTON_LEFT and not is_window_open and not is_generator_animation_running:
				var mouse_pos = get_viewport().get_mouse_position()
				
				# Проверяем, не кликнули ли по UI
				var ui_nodes = get_tree().get_nodes_in_group("ui")
				for ui in ui_nodes:
					if ui.visible and ui.get_global_rect().has_point(mouse_pos):
						return
				
				var world_pos = get_global_mouse_position()
				var cell = floor_tile_map.local_to_map(world_pos)
				
				# ===== РЕЖИМ УСТАНОВКИ ГЕНЕРАТОРА =====
				if generator_placement_mode:
					# Проверяем, что клетка находится на полу
					var is_floor = false
					var level_data = Global.level_state.get(current_level, {})
					for floor_cell in level_data.get("floor", []):
						if floor_cell == cell:
							is_floor = true
							break
					
					if is_floor and wall_destruction_system.is_cell_free(cell):
						place_generator_at_cell(cell)
						return
					else:
						if not is_floor:
							print("Клетка ", cell, " не является полом!")
						else:
							print("Клетка ", cell, " занята!")
						return
				
				# ===== КЛИК ПО СТЕНЕ (мини-игра) =====
				if wall_tile_map.get_cell_source_id(cell) != -1:
					if level_data_has_wall(cell):
						if wall_target_frequencies.has(cell):
							print("Для этой стены уже определена частота: ", wall_target_frequencies[cell])
							return
						else:
							selected_cell = cell
							open_frequency_window()
							return
				
				# ===== КЛИК ПО ТРАНСПОРТУ =====
				if vehicle_tile_map.get_cell_source_id(cell) != -1:
					var vehicle_data = get_vehicle_at_cell(cell)
					if vehicle_data != null:
						if vehicle_data.get("type") == "excavator" and is_excavator_full(vehicle_data.get("id")):
							select_excavator_for_unload(vehicle_data, cell)
							return
						elif selected_excavator_for_unload != null and vehicle_data.get("type") == "truck":
							if is_truck_on_level(vehicle_data.get("id")) and not is_truck_full(vehicle_data.get("id")):
								if is_excavator_adjacent_to_truck(selected_excavator_for_unload.get("id"), vehicle_data.get("id")):
									start_unloading(selected_excavator_for_unload.get("id"), vehicle_data.get("id"))
									return
								else:
									move_excavator_to_truck(selected_excavator_for_unload.get("id"), vehicle_data.get("id"))
									return
							else:
								print("Грузовик полный или не на уровне!")
								return
						else:
							select_vehicle_for_move(vehicle_data, cell)
							return
				
				if selected_excavator_for_unload != null:
					if floor_tile_map.get_cell_source_id(cell) != -1:
						cancel_unload_selection()
				
				if selected_vehicle_for_move != null:
					var target_cell = cell
					if floor_tile_map.get_cell_source_id(target_cell) != -1 and vehicle_tile_map.get_cell_source_id(target_cell) == -1:
						move_vehicle_to(target_cell)
				
				if selected_vehicle_for_move != null and selected_vehicle_for_move.get("type") == "excavator":
					if rubble_tile_map.get_cell_source_id(cell) != -1:
						var excavator_cell = selected_vehicle_for_move.get("cell")
						var is_adjacent = false
						for dir in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
							if excavator_cell + dir == cell:
								is_adjacent = true
								break
						
						if is_adjacent:
							if digging.is_busy():
								print("Экскаватор уже копает!")
								return
							digging.start_digging(selected_vehicle_for_move.get("id"), cell)
							unselect_vehicle()
							return
						
						pending_rubble_for_excavator = {
							"vehicle_id": selected_vehicle_for_move.get("id"),
							"rubble_cell": cell
						}
						
						var target_cell = movement.find_free_cell_near(cell, selected_vehicle_for_move.get("cell"))
						if target_cell == null:
							print("Нет свободной клетки рядом с кучей!")
							return
						
						move_vehicle_to(target_cell)
						return


func _on_place_generator_button_pressed():
	if is_generator_animation_running:
		return
	
	# Переключаем режим
	generator_placement_mode = not generator_placement_mode
	
	if generator_placement_mode:
		place_generator_button.text = "Отмена"
		selection_sprite.visible = false
		if hover_sprite:
			hover_sprite.visible = false
		print("Режим установки генератора. Нажмите на свободную клетку пола.")
	else:
		place_generator_button.text = "Установить генератор"
		if hover_sprite:
			hover_sprite.visible = false
		selection_sprite.visible = false


func place_generator_at_cell(cell: Vector2i):
	# Создаём генератор с направлением по умолчанию (вверх)
	var gen_id = wall_destruction_system.place_generator(cell, 0)
	
	if gen_id != -1:
		# Добавляем в список
		var gen_data = {
			"cell": cell,
			"direction": 0,
			"frequency": 0,
			"id": gen_id
		}
		generator_list.append(gen_data)
		
		print("Генератор #", gen_id, " установлен в клетке ", cell)
		
		# Выходим из режима установки
		generator_placement_mode = false
		place_generator_button.text = "Установить генератор"
		if hover_sprite:
			hover_sprite.visible = false
		selection_sprite.visible = false
		
		# Открываем окно настройки
		open_generator_setup_window(gen_id)


func update_start_button_state():
	# Проверяем, можно ли разблокировать кнопку запуска
	if generator_list.size() >= 2:
		var all_have_frequency = true
		for gen_data in generator_list:
			if gen_data.frequency == 0:
				all_have_frequency = false
				break
		
		if all_have_frequency and not is_generator_animation_running:
			start_generators_button.disabled = false
		else:
			start_generators_button.disabled = true
	else:
		start_generators_button.disabled = true


func _on_start_generators_button_pressed():
	if generator_list.size() < 2:
		print("Нужно минимум 2 генератора!")
		return
	
	if is_generator_animation_running:
		return
	
	# Проверяем, все ли генераторы имеют частоту
	for gen_data in generator_list:
		if gen_data.frequency == 0:
			print("Генератор #", gen_data.id, " не имеет частоты!")
			return
	
	# Блокируем интерфейс
	is_generator_animation_running = true
	start_generators_button.disabled = true
	place_generator_button.disabled = true
	
	# Закрываем все окна если они открыты
	if is_window_open:
		is_window_open = false
		if gen_setup_instance:
			gen_setup_instance.queue_free()
			gen_setup_instance = null
	
	# Запускаем анимацию волн
	start_wave_animation()


func start_wave_animation():
	# Создаём анимацию
	wave_animation_instance = WaveAnimation.new()
	add_child(wave_animation_instance)
	
	# Подготавливаем данные для анимации
	var generators_data = []
	for gen_data in generator_list:
		generators_data.append({
			"cell": gen_data.cell,
			"direction": gen_data.direction,
			"frequency": gen_data.frequency
		})
	
	wave_animation_instance.setup(generators_data, wall_target_frequencies)
	wave_animation_instance.animation_finished.connect(_on_wave_animation_finished)
	
	# Запускаем анимацию
	wave_animation_instance.start_animation()


func _on_wave_animation_finished(result: Dictionary):
	# Обрабатываем результат
	if result.destroyed_walls.size() > 0:
		print("Разрушено стен: ", result.destroyed_walls.size())
		for wall_data in result.destroyed_walls:
			# Разрушаем стену через систему
			wall_destruction_system.destroy_wall_with_accuracy(
				wall_data.cell, 
				wall_data.frequency, 
				wall_data.accuracy
			)
			# Удаляем из целевых частот
			if wall_target_frequencies.has(wall_data.cell):
				wall_target_frequencies.erase(wall_data.cell)
	else:
		print("Ни одна стена не была разрушена")
	
	# Убираем все генераторы
	remove_all_generators()
	
	# Разблокируем интерфейс
	is_generator_animation_running = false
	start_generators_button.disabled = true
	place_generator_button.disabled = false
	is_window_open = false
	
	# Обновляем отрисовку
	draw_quarry()


func remove_all_generators():
	# Удаляем все генераторы
	for gen_data in generator_list:
		wall_destruction_system.remove_generator(gen_data.id)
	
	generator_list.clear()
	
	# Обновляем кнопки
	place_generator_button.text = "Установить генератор"
	start_generators_button.disabled = true
	generator_placement_mode = false
	if hover_sprite:
		hover_sprite.visible = false
	selection_sprite.visible = false


func open_generator_setup_window(generator_id: int):
	if gen_setup_instance != null:
		gen_setup_instance.queue_free()
		gen_setup_instance = null
	
	gen_setup_instance = GeneratorSetupWindow.instantiate()
	popup_container.add_child(gen_setup_instance)
	is_window_open = true
	gen_setup_instance.setup(generator_id)
	gen_setup_instance.frequency_selected.connect(_on_generator_frequency_selected)
	gen_setup_instance.direction_selected.connect(_on_generator_direction_selected)
	gen_setup_instance.window_closed.connect(_on_generator_setup_closed)
	gen_setup_instance.generator_cancelled.connect(_on_generator_cancelled)


func _on_generator_cancelled(generator_id: int):
	# Удаляем генератор с уровня
	wall_destruction_system.remove_generator(generator_id)
	
	# Удаляем из списка
	var idx = -1
	for i in range(generator_list.size()):
		if generator_list[i].id == generator_id:
			idx = i
			break
	
	if idx != -1:
		generator_list.remove_at(idx)
	
	# Обновляем кнопку запуска
	update_start_button_state()
	
	print("Генератор #", generator_id, " удалён")


func _on_generator_frequency_selected(generator_id: int, frequency: int):
	wall_destruction_system.set_generator_frequency(generator_id, frequency)
	
	# Обновляем в списке
	for gen_data in generator_list:
		if gen_data.id == generator_id:
			gen_data.frequency = frequency
			break
	
	update_start_button_state()


func _on_generator_direction_selected(generator_id: int, direction: int):
	wall_destruction_system.set_generator_direction(generator_id, direction)
	
	# Обновляем в списке
	for gen_data in generator_list:
		if gen_data.id == generator_id:
			gen_data.direction = direction
			break


func _on_generator_setup_closed():
	is_window_open = false
	gen_setup_instance = null
	
	# Обновляем состояние кнопки запуска
	update_start_button_state()
	
	# Выходим из режима установки если он был включён
	if generator_placement_mode:
		generator_placement_mode = false
		place_generator_button.text = "Установить генератор"
		if hover_sprite:
			hover_sprite.visible = false
		selection_sprite.visible = false


func level_data_has_wall(cell: Vector2i) -> bool:
	var level_data = Global.level_state.get(current_level, {})
	for wall_cell in level_data.get("walls", []):
		if wall_cell == cell:
			return true
	return false


func draw_quarry():
	for marker in marker_queue:
		marker.queue_free()
	marker_queue.clear()
	
	var level_data = Global.level_state.get(current_level, {})
	
	floor_tile_map.clear()
	border_tile_map.clear()
	wall_tile_map.clear()
	vehicle_tile_map.clear()
	rubble_tile_map.clear()
	
	for cell in level_data.get("floor", []):
		floor_tile_map.set_cell(cell, 0, FLOOR_TILE)
	
	for cell in level_data.get("border", []):
		border_tile_map.set_cell(cell, 0, BORDER_TILE)
	
	for cell in level_data.get("walls", []):
		wall_tile_map.set_cell(cell, 0, WALL_TILE)
		
	for cell in level_data.get("rubbles", []):
		rubble_tile_map.set_cell(cell, 0, RUBBLE_TILE)
	
	for truck_data in level_data.get("trucks", []):
		var cell = Vector2i(truck_data.get("cell", [0, 0])[0], truck_data.get("cell", [0, 0])[1])
		vehicle_tile_map.set_cell(cell, 0, TRUCK_TILE)
		
		var is_full = false
		for truck in Global.vehicles.get("trucks", []):
			if truck.get("id") == truck_data.get("id"):
				var capacity = Global.vehicle_templates.get("truck", {}).get("capacity", 50)
				if truck.get("ore", 0) >= capacity:
					is_full = true
				break
		
		if is_full:
			var marker = Sprite2D.new()
			marker.centered = true
			marker.z_index = 10
			var marker_image = Image.create(16, 16, false, Image.FORMAT_RGBA8)
			marker_image.fill(Color.GREEN)
			var marker_texture = ImageTexture.create_from_image(marker_image)
			marker.texture = marker_texture
			marker.position = cell * 64 + Vector2i(32, 48)
			add_child(marker)
			marker_queue.append(marker)
	
	for excavator_data in level_data.get("excavators", []):
		var cell = Vector2i(excavator_data.get("cell", [0, 0])[0], excavator_data.get("cell", [0, 0])[1])
		vehicle_tile_map.set_cell(cell, 0, EXCAVATOR_TILE)
		
		var is_full = false
		for ex in Global.vehicles.get("excavators", []):
			if ex.get("id") == excavator_data.get("id") and ex.get("is_full", false):
				is_full = true
				break
		
		if is_full:
			var marker = Sprite2D.new()
			marker.centered = true
			marker.z_index = 10
			var marker_image = Image.create(16, 16, false, Image.FORMAT_RGBA8)
			marker_image.fill(Color.RED)
			var marker_texture = ImageTexture.create_from_image(marker_image)
			marker.texture = marker_texture
			marker.position = cell * 64 + Vector2i(32, 48)
			add_child(marker)
			marker_queue.append(marker)


func spawn_rubble(cell):
	var level_data = Global.level_state.get(current_level, {})
	if border_tile_map.get_cell_source_id(cell) == -1 and rubble_tile_map.get_cell_source_id(cell) == -1:
		rubble_tile_map.set_cell(cell, 0, RUBBLE_TILE)
		level_data["rubbles"].append(cell)
		Global.level_state[current_level]["rubbles"] = level_data["rubbles"]


func destroy_cell(cell):
	if wall_tile_map.get_cell_source_id(cell) != -1:
		wall_tile_map.set_cell(cell, -1)
		var level_data = Global.level_state.get(current_level, {})
		var walls = level_data.get("walls", [])
		walls.erase(cell)
		level_data["walls"] = walls
		Global.level_state[current_level] = level_data
		update_ui()


func update_ui():
	$CanvasLayer/UIPanel/MoneyLabel.text = "Деньги: " + str(Global.money)


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


func change_money(pos, value) -> void:
	if pos == "+":
		Global.money += value
	elif pos == "-":
		Global.money -= value


func open_frequency_window():
	freq_window_instance = FrequencyWindow.instantiate()
	popup_container.add_child(freq_window_instance)
	is_window_open = true
	freq_window_instance.connect("frequency_selected", _on_frequency_selected_for_wall)
	freq_window_instance.connect("window_closed", window_closed)


func _on_frequency_selected_for_wall(freq, status):
	var target_frequency = freq
	wall_target_frequencies[selected_cell] = target_frequency
	print("Для стены в клетке ", selected_cell, " определена целевая частота: ", target_frequency)
	window_closed()


func window_closed():
	is_window_open = false


func destroy_more_cells(cond):
	if cond == "center":
		destroy_cell(selected_cell)
		destroy_cell(Vector2i(selected_cell.x, selected_cell.y - 1))
		destroy_cell(Vector2i(selected_cell.x, selected_cell.y + 1))
		destroy_cell(Vector2i(selected_cell.x - 1, selected_cell.y))
		destroy_cell(Vector2i(selected_cell.x + 1, selected_cell.y))


func open_storage_window():
	stor_window_instate = StorageWindow.instantiate()
	popup_container.add_child(stor_window_instate)
	is_window_open = true
	stor_window_instate.connect("window_closed", window_closed)
	stor_window_instate.connect("update_ui", update_ui)


func open_vehicle_management_window():
	veh_man_window_instance = VehicleManagementWindow.instantiate()
	popup_container.add_child(veh_man_window_instance)
	is_window_open = true
	veh_man_window_instance.tree_exited.connect(_on_vehicle_window_closed)


func _on_vehicle_window_closed():
	is_window_open = false


func spawn_more_rubble(cond):
	if cond == "center":
		spawn_rubble(selected_cell)
		spawn_rubble(Vector2i(selected_cell.x, selected_cell.y - 1))
		spawn_rubble(Vector2i(selected_cell.x, selected_cell.y + 1))
		spawn_rubble(Vector2i(selected_cell.x - 1, selected_cell.y))
		spawn_rubble(Vector2i(selected_cell.x + 1, selected_cell.y))


func get_vehicle_at_cell(cell: Vector2i):
	var level_data = Global.level_state.get(current_level, {})
	for truck_data in level_data.get("trucks", []):
		var pos = Vector2i(truck_data.get("cell", [0, 0])[0], truck_data.get("cell", [0, 0])[1])
		if pos == cell:
			return {"type": "truck", "id": truck_data.get("id"), "cell": cell}
	for excavator_data in level_data.get("excavators", []):
		var pos = Vector2i(excavator_data.get("cell", [0, 0])[0], excavator_data.get("cell", [0, 0])[1])
		if pos == cell:
			return {"type": "excavator", "id": excavator_data.get("id"), "cell": cell}
	return null


func select_vehicle_for_move(vehicle_data, cell: Vector2i):
	if is_generator_animation_running:
		return
	
	if vehicle_data.get("type") == "excavator" and is_vehicle_busy(vehicle_data.get("id")):
		print("Экскаватор занят копанием!")
		return
	
	if selected_vehicle_for_move != null:
		unselect_vehicle()
	
	selected_vehicle_for_move = vehicle_data
	highlight_vehicle(cell, true)
	print("Выбран транспорт #", vehicle_data.get("id"))


func unselect_vehicle():
	if selected_vehicle_for_move != null:
		highlight_vehicle(selected_vehicle_for_move.get("cell"), false)
		selected_vehicle_for_move = null


func highlight_vehicle(cell: Vector2i, highlight: bool, color: Color = Color.YELLOW):
	if selection_sprite == null:
		return
	if highlight:
		selection_sprite.position = cell * 64
		selection_sprite.visible = true
		selection_sprite.modulate = color
	else:
		selection_sprite.visible = false
		selection_sprite.modulate = Color.WHITE


func move_vehicle_to(target_cell: Vector2i):
	if selected_vehicle_for_move == null:
		return
	
	var start_cell = selected_vehicle_for_move.get("cell")
	var vehicle_id = selected_vehicle_for_move.get("id")
	var vehicle_type = selected_vehicle_for_move.get("type")
	
	if movement.move_vehicle(vehicle_id, start_cell, target_cell, vehicle_type):
		var path = movement.find_path(start_cell, target_cell, vehicle_id)
		if path != null:
			draw_path(path)
		unselect_vehicle()


func draw_path(path: Array):
	clear_path()
	if path == null:
		return
	
	for cell in path:
		var sprite = Sprite2D.new()
		sprite.centered = false
		sprite.z_index = 5
		var image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
		image.fill(Color(0, 1, 0, 0.3))
		var texture = ImageTexture.create_from_image(image)
		sprite.texture = texture
		sprite.position = cell * 64
		add_child(sprite)
		path_sprites.append(sprite)


func clear_path():
	for sprite in path_sprites:
		sprite.queue_free()
	path_sprites.clear()


func _on_vehicle_moved(vehicle_id, new_cell):
	draw_quarry()


func _on_vehicle_arrived(vehicle_id):
	if move_progress_bars.has(vehicle_id):
		move_progress_bars[vehicle_id].queue_free()
		move_progress_bars.erase(vehicle_id)
	
	clear_path()
	print("Транспорт #", vehicle_id, " прибыл")
	
	if pending_rubble_for_excavator and pending_rubble_for_excavator.get("vehicle_id") == vehicle_id:
		var rubble_cell = pending_rubble_for_excavator.get("rubble_cell")
		
		if digging.is_busy():
			print("Экскаватор уже копает!")
			pending_rubble_for_excavator = null
			return
		
		var excavator_cell = movement.get_vehicle_cell(vehicle_id, "excavator")
		if excavator_cell:
			var is_adjacent = false
			for dir in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
				if excavator_cell + dir == rubble_cell:
					is_adjacent = true
					break
			
			if is_adjacent:
				digging.start_digging(vehicle_id, rubble_cell)
				print("Экскаватор #", vehicle_id, " начал копать после прибытия к куче!")
		
		pending_rubble_for_excavator = null
	
	if pending_unload_to_truck and pending_unload_to_truck.get("excavator_id") == vehicle_id:
		var truck_id = pending_unload_to_truck.get("truck_id")
		if is_excavator_adjacent_to_truck(vehicle_id, truck_id):
			start_unloading(vehicle_id, truck_id)
		else:
			print("Экскаватор не рядом с грузовиком после перемещения!")
		pending_unload_to_truck = null


func _on_vehicle_progress(vehicle_id, progress):
	if not move_progress_bars.has(vehicle_id):
		var bar = ProgressBar.new()
		bar.min_value = 0
		bar.max_value = 100
		bar.value = 0
		bar.size = Vector2(60, 12)
		bar.visible = true
		bar.z_index = 25
		add_child(bar)
		move_progress_bars[vehicle_id] = bar
	
	var bar = move_progress_bars[vehicle_id]
	bar.value = progress * 100
	
	var cell = movement.get_vehicle_cell(vehicle_id, "truck")
	if cell == null:
		cell = movement.get_vehicle_cell(vehicle_id, "excavator")
	
	if cell != null:
		bar.position = Vector2(cell.x * 64 + 2, cell.y * 64 - 20)


func update_progress_bar(key: String, progress: float):
	if progress_bars.has(key):
		var bar = progress_bars[key]
		if progress <= 0:
			bar.visible = false
		else:
			bar.value = clamp(progress * 100, 0, 100)
			bar.visible = true
			if key == "loading" and selected_excavator_for_unload != null:
				var cell = selected_excavator_for_unload.get("cell")
				bar.position = Vector2(cell.x * 64 + 2, cell.y * 64 - 20)
			elif key == "loading" and is_unloading:
				var level_data = Global.level_state.get(current_level, {})
				for ex in level_data.get("excavators", []):
					if ex.get("status") == "unloading":
						var cell = Vector2i(ex.get("cell", [0, 0])[0], ex.get("cell", [0, 0])[1])
						bar.position = Vector2(cell.x * 64 + 2, cell.y * 64 - 20)
						break


func _on_digging_progress(vehicle_id, progress, cell):
	if progress_bars.has("extraction"):
		var bar = progress_bars["extraction"]
		if progress <= 0:
			bar.visible = false
		else:
			bar.value = clamp(progress * 100, 0, 100)
			bar.visible = true
			if cell != null:
				bar.position = Vector2(cell.x * 64 + 2, cell.y * 64 - 20)


func _on_digging_completed(level, vehicle_id, rubble_cell):
	if level == current_level:
		print("_on_digging_completed вызван для кучи в клетке ", rubble_cell)
		
		if progress_bars.has("extraction"):
			progress_bars["extraction"].visible = false
		update_progress_bar("extraction", 0.0)
		
		draw_quarry()


func is_vehicle_busy(vehicle_id: int) -> bool:
	return digging.is_busy() and digging.current_target and digging.current_target.get("vehicle_id") == vehicle_id


func _on_digging_started(vehicle_id):
	if selected_vehicle_for_move and selected_vehicle_for_move.get("id") == vehicle_id:
		unselect_vehicle()


func _exit_tree():
	if digging.is_busy():
		digging.stop_digging()
	Global.is_on_level = false


func is_excavator_full(vehicle_id: int) -> bool:
	for ex in Global.vehicles.get("excavators", []):
		if ex.get("id") == vehicle_id:
			return ex.get("is_full", false)
	return false


func is_truck_on_level(truck_id: int) -> bool:
	var level_data = Global.level_state.get(current_level, {})
	for truck in level_data.get("trucks", []):
		if truck.get("id") == truck_id:
			return true
	return false


func is_truck_full(truck_id: int) -> bool:
	for truck in Global.vehicles.get("trucks", []):
		if truck.get("id") == truck_id:
			var capacity = Global.vehicle_templates.get("truck", {}).get("capacity", 50)
			return truck.get("ore", 0) >= capacity
	return false


func is_excavator_adjacent_to_truck(excavator_id: int, truck_id: int) -> bool:
	var level_data = Global.level_state.get(current_level, {})
	
	var excavator_cell = Vector2i(0, 0)
	for ex in level_data.get("excavators", []):
		if ex.get("id") == excavator_id:
			excavator_cell = Vector2i(ex.get("cell", [0, 0])[0], ex.get("cell", [0, 0])[1])
			break
	
	var truck_cell = Vector2i(0, 0)
	for truck in level_data.get("trucks", []):
		if truck.get("id") == truck_id:
			truck_cell = Vector2i(truck.get("cell", [0, 0])[0], truck.get("cell", [0, 0])[1])
			break
	
	for dir in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
		if excavator_cell + dir == truck_cell:
			return true
	
	return false


func move_excavator_to_truck(excavator_id: int, truck_id: int):
	var level_data = Global.level_state.get(current_level, {})
	
	var truck_cell = Vector2i(0, 0)
	for truck in level_data.get("trucks", []):
		if truck.get("id") == truck_id:
			truck_cell = Vector2i(truck.get("cell", [0, 0])[0], truck.get("cell", [0, 0])[1])
			break
	
	var excavator_cell = Vector2i(0, 0)
	for ex in level_data.get("excavators", []):
		if ex.get("id") == excavator_id:
			excavator_cell = Vector2i(ex.get("cell", [0, 0])[0], ex.get("cell", [0, 0])[1])
			break
	
	var target_cell = movement.find_free_cell_near(truck_cell, excavator_cell)
	if target_cell == null:
		print("Нет свободной клетки рядом с грузовиком!")
		return
	
	cancel_unload_selection()
	
	var vehicle_data = {"type": "excavator", "id": excavator_id, "cell": excavator_cell}
	selected_vehicle_for_move = vehicle_data
	
	pending_unload_to_truck = {
		"excavator_id": excavator_id,
		"truck_id": truck_id
	}
	
	move_vehicle_to(target_cell)


func select_excavator_for_unload(vehicle_data, cell: Vector2i):
	cancel_unload_selection()
	
	selected_excavator_for_unload = {
		"id": vehicle_data.get("id"),
		"cell": cell
	}
	
	highlight_vehicle(cell, true, Color.BLUE)
	print("Выберите грузовик для разгрузки экскаватора #", vehicle_data.get("id"))


func cancel_unload_selection():
	if selected_excavator_for_unload != null:
		highlight_vehicle(selected_excavator_for_unload.get("cell"), false)
		selected_excavator_for_unload = null
		selection_sprite.modulate = Color.WHITE


func start_unloading(excavator_id: int, truck_id: int):
	if is_unloading:
		print("Уже идёт разгрузка!")
		return
	
	var excavator = null
	var ore_amount = 0
	for ex in Global.vehicles.get("excavators", []):
		if ex.get("id") == excavator_id:
			excavator = ex
			ore_amount = ex.get("ore_amount", 0)
			break
	
	if excavator == null or not excavator.get("is_full", false):
		print("Экскаватор не полный!")
		return
	
	var truck_on_level = false
	var level_data = Global.level_state.get(current_level, {})
	for truck in level_data.get("trucks", []):
		if truck.get("id") == truck_id:
			truck_on_level = true
			break
	
	if not truck_on_level:
		print("Грузовик не на этом уровне!")
		return
	
	is_unloading = true
	unload_progress = 0.0
	unloading_target_truck = {
		"id": truck_id
	}
	
	for ex in Global.vehicles.get("excavators", []):
		if ex.get("id") == excavator_id:
			ex["status"] = "unloading"
			break
	
	for truck in Global.vehicles.get("trucks", []):
		if truck.get("id") == truck_id:
			truck["status"] = "loading"
			break
	
	if progress_bars.has("loading"):
		var bar = progress_bars["loading"]
		bar.value = 0
		bar.visible = true
		for ex in level_data.get("excavators", []):
			if ex.get("id") == excavator_id:
				var cell = Vector2i(ex.get("cell", [0, 0])[0], ex.get("cell", [0, 0])[1])
				bar.position = Vector2(cell.x * 64 + 2, cell.y * 64 - 20)
				break
	
	cancel_unload_selection()
	
	print("Началась разгрузка экскаватора #", excavator_id, " в грузовик #", truck_id)


func finish_unloading():
	print("Разгрузка завершена!")
	
	var excavator_id = -1
	var truck_id = -1
	var ore_amount = 0
	
	for ex in Global.vehicles.get("excavators", []):
		if ex.get("status") == "unloading":
			excavator_id = ex.get("id")
			ore_amount = ex.get("ore_amount", 0)
			ex["is_full"] = false
			ex["ore_amount"] = 0
			ex["status"] = "idle"
			break
	
	for truck in Global.vehicles.get("trucks", []):
		if truck.get("status") == "loading":
			truck_id = truck.get("id")
			truck["ore"] = truck.get("ore", 0) + ore_amount
			truck["status"] = "idle"
			break
	
	is_unloading = false
	unload_progress = 0.0
	unloading_target_truck = null
	selected_excavator_for_unload = null
	
	if progress_bars.has("loading"):
		progress_bars["loading"].visible = false
	
	print("Экскаватор #", excavator_id, " разгрузил ", ore_amount, " кг в грузовик #", truck_id)
	print("В грузовике теперь: ", get_truck_ore(truck_id), " кг")
	
	draw_quarry()


func get_truck_ore(truck_id: int) -> int:
	for truck in Global.vehicles.get("trucks", []):
		if truck.get("id") == truck_id:
			return truck.get("ore", 0)
	return 0


func _on_vehicles_button_pressed() -> void:
	open_vehicle_management_window()


func _on_wall_destroyed(cell: Vector2i, frequency: int, accuracy: float):
	print("Стена разрушена в клетке ", cell, " с частотой ", frequency, " (точность: ", accuracy, ")")
	if wall_target_frequencies.has(cell):
		wall_target_frequencies.erase(cell)
	draw_quarry()


func _on_rubble_spawned(cell: Vector2i, weight: int):
	print("Куча появилась в клетке ", cell, " весом ", weight, " кг")
	draw_quarry()


func _on_vehicle_destroyed(vehicle_id: int):
	print("Транспорт #", vehicle_id, " уничтожен!")
	draw_quarry()
