class_name WallDestructionSystem
extends Node


signal wall_destroyed(cell: Vector2i, frequency: int, accuracy: float)
signal rubble_spawned(cell: Vector2i, weight: int)
signal vehicle_destroyed(vehicle_id: int)
signal generator_placed(generator_id: int, cell: Vector2i, direction: int)
signal generator_removed(generator_id: int)


var generators: Dictionary = {} 
var next_generator_id: int = 0
var wall_frequencies: Dictionary = {}
var current_level: int
var wall_tile_map: TileMapLayer
var rubble_tile_map: TileMapLayer
var vehicle_tile_map: TileMapLayer
var floor_tile_map: TileMapLayer
var level_data: Dictionary
var selected_generator: int = -1
var generator_placement_mode: bool = false
var temp_generator_cell: Vector2i = Vector2i.ZERO
var temp_generator_direction: int = 0


func setup(level: int, wall_map: TileMapLayer, rubble_map: TileMapLayer, vehicle_map: TileMapLayer, floor_map: TileMapLayer):
	current_level = level
	wall_tile_map = wall_map
	rubble_tile_map = rubble_map
	vehicle_tile_map = vehicle_map
	floor_tile_map = floor_map
	level_data = Global.level_state.get(level, {})
	
	# Восстанавливаем генераторы из сохранения
	restore_generators()
	
	# Генерируем частоты для стен
	generate_wall_frequencies()


func generate_wall_frequencies():
	for cell in level_data.get("walls", []):
		# Частота от 100 до 1000 с шагом 10
		wall_frequencies[cell] = (randi_range(10, 100)) * 10


func restore_generators():
	for gen_data in level_data.get("generators", []):
		var gen = FrequencyGenerator.new()
		gen.generator_id = gen_data.get("id", next_generator_id)
		gen.cell = Vector2i(gen_data.get("cell", [0, 0])[0], gen_data.get("cell", [0, 0])[1])
		gen.set_direction(gen_data.get("direction", 0))
		gen.set_frequency(gen_data.get("frequency", 0))
		
		add_child(gen)
		generators[gen.generator_id] = gen
		next_generator_id = max(next_generator_id, gen.generator_id + 1)


func place_generator(cell: Vector2i, direction: int) -> int:
	if not is_cell_free(cell):
		print("Клетка занята!")
		return -1
	
	# Создаём генератор и настраиваем его
	var gen = FrequencyGenerator.new()
	gen.generator_id = next_generator_id
	gen.cell = cell
	gen.set_direction(direction)
	gen.set_frequency(0)
	
	add_child(gen)
	generators[next_generator_id] = gen
	
	# Сохраняем
	if not level_data.has("generators"):
		level_data["generators"] = []
	level_data["generators"].append({
		"id": next_generator_id,
		"cell": [cell.x, cell.y],
		"direction": direction,
		"frequency": 0
	})
	Global.level_state[current_level] = level_data
	
	generator_placed.emit(next_generator_id, cell, direction)
	var placed_id = next_generator_id
	next_generator_id += 1
	
	return placed_id


func remove_generator(generator_id: int):
	if generators.has(generator_id):
		generators[generator_id].destroy()
		generators.erase(generator_id)
		
		# Удаляем из данных
		var new_list = []
		for g in level_data.get("generators", []):
			if g.get("id") != generator_id:
				new_list.append(g)
		level_data["generators"] = new_list
		Global.level_state[current_level] = level_data
		generator_removed.emit(generator_id)


func set_generator_frequency(generator_id: int, frequency: int):
	if generators.has(generator_id):
		generators[generator_id].set_frequency(frequency)
		for g in level_data.get("generators", []):
			if g.get("id") == generator_id:
				g["frequency"] = frequency
				break
		Global.level_state[current_level] = level_data


func set_generator_direction(generator_id: int, direction: int):
	if generators.has(generator_id):
		generators[generator_id].set_direction(direction)
		for g in level_data.get("generators", []):
			if g.get("id") == generator_id:
				g["direction"] = direction
				break
		Global.level_state[current_level] = level_data


func check_wave_intersections():
	var gen_ids = generators.keys()
	
	for i in range(gen_ids.size()):
		for j in range(i + 1, gen_ids.size()):
			var g1 = generators[gen_ids[i]]
			var g2 = generators[gen_ids[j]]
			
			# Проверяем наличие частот
			if g1.frequency == 0 or g2.frequency == 0:
				continue
			
			# Проверяем совпадение частот
			if g1.frequency != g2.frequency:
				continue
			
			# Получаем точки пересечения
			var intersections = g1.get_wave_intersection(g2)
			for cell in intersections:
				process_intersection(cell, g1.frequency)


func process_intersection(cell: Vector2i, frequency: int):
	# Проверяем, есть ли стена в этой клетке
	var wall_exists = false
	for wall_cell in level_data.get("walls", []):
		if wall_cell == cell:
			wall_exists = true
			break
	
	if not wall_exists:
		# Эффект обвала - разрушаем соседние стены
		var nearby_walls = get_nearby_walls(cell)
		for wall_cell in nearby_walls:
			if randf() < 0.3:  # 30% шанс обвала
				destroy_wall_with_accuracy(wall_cell, frequency, 0.3)
		return
	
	# Проверяем точность
	var target_freq = wall_frequencies.get(cell, 0)
	if target_freq == 0:
		return
	
	var diff = abs(frequency - target_freq)
	var accuracy = 1.0 - (diff / 1000.0)
	accuracy = clamp(accuracy, 0.0, 1.0)
	
	destroy_wall_with_accuracy(cell, frequency, accuracy)


func destroy_wall_with_accuracy(cell: Vector2i, frequency: int, accuracy: float):
	var wall_exists = false
	for wall_cell in level_data.get("walls", []):
		if wall_cell == cell:
			wall_exists = true
			break
	
	if not wall_exists:
		return
	
	# Удаляем стену
	wall_tile_map.set_cell(cell, -1)
	var walls = level_data.get("walls", [])
	walls.erase(cell)
	level_data["walls"] = walls
	
	# Создаём кучу (она может уничтожить транспорт на своей клетке)
	spawn_rubble(cell, frequency, accuracy)
	
	# Обрушаем соседние стены при неточном попадании
	if accuracy < 0.8:
		var nearby_walls = get_nearby_walls(cell)
		var chance = (1.0 - accuracy) * 0.5
		for wall_cell in nearby_walls:
			if randf() < chance:
				destroy_wall_with_accuracy(wall_cell, frequency, accuracy * 0.6)
	
	wall_destroyed.emit(cell, frequency, accuracy)
	Global.level_state[current_level] = level_data


func get_nearby_walls(cell: Vector2i) -> Array:
	var nearby = []
	for dir in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
		var neighbor = cell + dir
		if level_data.get("walls", []).has(neighbor):
			nearby.append(neighbor)
	return nearby


func get_vehicles_in_range(cell: Vector2i, range: int) -> Array:
	var vehicles = []
	
	for truck in level_data.get("trucks", []):
		var pos = Vector2i(truck.get("cell", [0, 0])[0], truck.get("cell", [0, 0])[1])
		if abs(pos.x - cell.x) <= range and abs(pos.y - cell.y) <= range:
			vehicles.append(truck.get("id"))
	
	for excavator in level_data.get("excavators", []):
		var pos = Vector2i(excavator.get("cell", [0, 0])[0], excavator.get("cell", [0, 0])[1])
		if abs(pos.x - cell.x) <= range and abs(pos.y - cell.y) <= range:
			vehicles.append(excavator.get("id"))
	
	return vehicles


func destroy_vehicle(vehicle_id: int):
	for truck in Global.vehicles["trucks"]:
		if truck.get("id") == vehicle_id:
			Global.vehicles["trucks"].erase(truck)
			# Удаляем с уровня
			var new_list = []
			for t in level_data.get("trucks", []):
				if t.get("id") != vehicle_id:
					new_list.append(t)
			level_data["trucks"] = new_list
			vehicle_destroyed.emit(vehicle_id)
			print("Грузовик #", vehicle_id, " уничтожен обвалом!")
			return
	
	for excavator in Global.vehicles["excavators"]:
		if excavator.get("id") == vehicle_id:
			Global.vehicles["excavators"].erase(excavator)
			var new_list = []
			for e in level_data.get("excavators", []):
				if e.get("id") != vehicle_id:
					new_list.append(e)
			level_data["excavators"] = new_list
			vehicle_destroyed.emit(vehicle_id)
			print("Экскаватор #", vehicle_id, " уничтожен обвалом!")
			return


func spawn_rubble(cell: Vector2i, frequency: int, accuracy: float):
	# Проверяем, свободна ли клетка для кучи
	var is_free = is_cell_free(cell)
	
	# Если клетка занята транспортом - уничтожаем транспорт
	if not is_free:
		# Проверяем, есть ли транспорт в этой клетке
		var vehicle_id = get_vehicle_at_cell(cell)
		if vehicle_id != -1:
			destroy_vehicle(vehicle_id)
			print("Транспорт #", vehicle_id, " уничтожен кучей!")
	
	# Проверяем ещё раз после возможного уничтожения транспорта
	if is_cell_free(cell):
		var base_weight = 10 + randi_range(0, 20)
		var weight = int(base_weight * (1.0 + (1.0 - accuracy) * 2.0))
		weight = clamp(weight, 10, 50)
		
		rubble_tile_map.set_cell(cell, 0, Vector2i(1, 0))  # RUBBLE_TILE
		level_data["rubbles"].append(cell)
		
		var rubble_data = {
			"cell": cell,
			"weight": weight,
			"remaining": weight
		}
		Global.rubbles.append(rubble_data)
		
		rubble_spawned.emit(cell, weight)
		Global.level_state[current_level] = level_data
	else:
		print("Клетка ", cell, " занята, куча не появилась!")


func get_vehicle_at_cell(cell: Vector2i) -> int:
	# Проверяем грузовики
	for truck in level_data.get("trucks", []):
		var pos = Vector2i(truck.get("cell", [0, 0])[0], truck.get("cell", [0, 0])[1])
		if pos == cell:
			return truck.get("id")
	
	# Проверяем экскаваторы
	for excavator in level_data.get("excavators", []):
		var pos = Vector2i(excavator.get("cell", [0, 0])[0], excavator.get("cell", [0, 0])[1])
		if pos == cell:
			return excavator.get("id")
	
	return -1


func is_cell_free(cell: Vector2i) -> bool:
	# Проверяем границы
	if cell.x < 1 or cell.x >= 20 or cell.y < 1 or cell.y >= 20:
		return false
	
	# Проверяем, что клетка является полом
	var is_floor = false
	for floor_cell in level_data.get("floor", []):
		if floor_cell == cell:
			is_floor = true
			break
	
	if not is_floor:
		return false
	
	# Проверяем стены
	if level_data.get("walls", []).has(cell):
		return false
	
	# Проверяем кучи
	if level_data.get("rubbles", []).has(cell):
		return false
	
	# Проверяем транспорт
	for truck in level_data.get("trucks", []):
		var pos = Vector2i(truck.get("cell", [0, 0])[0], truck.get("cell", [0, 0])[1])
		if pos == cell:
			return false
	
	for excavator in level_data.get("excavators", []):
		var pos = Vector2i(excavator.get("cell", [0, 0])[0], excavator.get("cell", [0, 0])[1])
		if pos == cell:
			return false
	
	return true


func get_wall_frequency(cell: Vector2i) -> int:
	return wall_frequencies.get(cell, 0)


func is_wall_destroyed(cell: Vector2i) -> bool:
	return not level_data.get("walls", []).has(cell)


func get_generators() -> Dictionary:
	return generators


func get_generator(generator_id: int) -> FrequencyGenerator:
	return generators.get(generator_id, null)
