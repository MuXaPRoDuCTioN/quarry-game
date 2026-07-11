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
var level_size: Vector2i = Vector2i(20, 20)


func setup(level: int, wall_map: TileMapLayer, rubble_map: TileMapLayer, vehicle_map: TileMapLayer, floor_map: TileMapLayer):
	current_level = level
	wall_tile_map = wall_map
	rubble_tile_map = rubble_map
	vehicle_tile_map = vehicle_map
	floor_tile_map = floor_map
	level_data = Global.level_state.get(level, {})
	
	var generator = load("res://scripts/quarry/QuarryLevel/QuarryGenerator.gd").new()
	level_size = generator.get_level_size(level)
	
	wall_frequencies = level_data.get("wall_frequencies", {})
	restore_generators()


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
	
	var gen = FrequencyGenerator.new()
	gen.generator_id = next_generator_id
	gen.cell = cell
	gen.set_direction(direction)
	gen.set_frequency(0)
	
	add_child(gen)
	generators[next_generator_id] = gen
	
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
			
			if g1.frequency == 0 or g2.frequency == 0:
				continue
			
			if g1.frequency != g2.frequency:
				continue
			
			var intersections = g1.get_wave_intersection(g2)
			for cell in intersections:
				process_intersection(cell, g1.frequency)


func process_intersection(cell: Vector2i, frequency: int):
	var wall_exists = false
	for wall_cell in level_data.get("walls", []):
		if wall_cell == cell:
			wall_exists = true
			break
	
	if not wall_exists:
		return
	
	var target_freq = wall_frequencies.get(cell, 0)
	if target_freq == 0:
		return
	
	var diff = abs(frequency - target_freq)
	var accuracy = 1.0 - (diff / 3000.0)
	accuracy = clamp(accuracy, 0.0, 1.0)
	
	if diff <= 10:
		destroy_wall_perfect(cell, frequency, accuracy)
	elif diff <= 25:
		destroy_wall_good(cell, frequency, accuracy)
	elif diff <= 50:
		destroy_wall_medium(cell, frequency, accuracy)
	else:
		print("Слишком далеко от цели. Ничего не произошло.")


func destroy_wall_perfect(cell: Vector2i, frequency: int, accuracy: float):
	print("Идеальное попадание! +-10 Гц")
	
	var wall_tiles = level_data.get("wall_tiles", {})
	var rock_type_id = wall_tiles.get(cell, 0)
	
	var destroyed_cells = []
	
	destroy_single_wall(cell, frequency, accuracy)
	destroyed_cells.append(cell)
	
	var same_rock_walls = get_same_rock_walls(cell, rock_type_id, 10)
	var destroyed_count = 0
	
	for wall_cell in same_rock_walls:
		if destroyed_count >= 10:
			break
		
		var chance = 0.9 - (destroyed_count * 0.08)
		if randf() < chance:
			destroy_single_wall(wall_cell, frequency, accuracy * 0.7)
			destroyed_cells.append(wall_cell)
			destroyed_count += 1
		else:
			break
	
	if destroyed_cells.size() >= 3:
		var last_three = destroyed_cells.slice(destroyed_cells.size() - 3, destroyed_cells.size())
		for wall_cell in last_three:
			spawn_rubble(wall_cell, frequency, accuracy * 0.5, rock_type_id)
	else:
		for wall_cell in destroyed_cells:
			spawn_rubble(wall_cell, frequency, accuracy * 0.5, rock_type_id)
	
	spawn_additional_rubbles()


func destroy_wall_good(cell: Vector2i, frequency: int, accuracy: float):
	print("Хорошее попадание! +-25 Гц")
	
	var wall_tiles = level_data.get("wall_tiles", {})
	var rock_type_id = wall_tiles.get(cell, 0)
	
	var destroyed_cells = []
	
	destroy_single_wall(cell, frequency, accuracy)
	destroyed_cells.append(cell)
	
	var same_rock_walls = get_same_rock_walls(cell, rock_type_id, 10)
	var destroyed_count = 0
	
	for wall_cell in same_rock_walls:
		if destroyed_count >= 10:
			break
		
		var chance = 0.9 - (destroyed_count * 0.08)
		if randf() < chance:
			destroy_single_wall(wall_cell, frequency, accuracy * 0.7)
			destroyed_cells.append(wall_cell)
			destroyed_count += 1
		else:
			break
	
	for wall_cell in destroyed_cells:
		spawn_rubble(wall_cell, frequency, accuracy * 0.5, rock_type_id)
	
	spawn_additional_rubbles()


func destroy_wall_medium(cell: Vector2i, frequency: int, accuracy: float):
	print("Среднее попадание! +-50 Гц")
	var wall_tiles = level_data.get("wall_tiles", {})
	var rock_type_id = wall_tiles.get(cell, 0)
	destroy_single_wall(cell, frequency, accuracy)
	spawn_rubble(cell, frequency, accuracy * 0.3, rock_type_id)
	var radius_1_walls = get_walls_in_radius(cell, 1)
	for wall_cell in radius_1_walls:
		# <<< ИСПРАВЛЕНО: берём rock_type_id от каждой конкретной стены
		var wall_rock_type_id = wall_tiles.get(wall_cell, 0)
		destroy_single_wall(wall_cell, frequency, accuracy * 0.3)
		spawn_rubble(wall_cell, frequency, accuracy * 0.3, wall_rock_type_id)
	var radius_2_cells = get_floor_cells_in_radius(cell, 2)
	for floor_cell in radius_2_cells:
		if is_cell_free(floor_cell):
			spawn_rubble(floor_cell, frequency, accuracy * 0.3, rock_type_id)
	spawn_additional_rubbles()


func destroy_single_wall(cell: Vector2i, frequency: int, accuracy: float):
	wall_tile_map.set_cell(cell, -1)
	var walls = level_data.get("walls", [])
	walls.erase(cell)
	level_data["walls"] = walls
	
	# Клетка больше не стена (скоро на её месте появится куча) - чистим её
	# частоту, иначе она навсегда останется "стеной" для будущих запусков
	# резонанса, и куча на этом месте будет копить резонанс/подсвечиваться.
	var wall_freqs = level_data.get("wall_frequencies", {})
	wall_freqs.erase(cell)
	level_data["wall_frequencies"] = wall_freqs
	
	var wtiles = level_data.get("wall_tiles", {})
	wtiles.erase(cell)
	level_data["wall_tiles"] = wtiles
	
	Global.level_state[current_level] = level_data
	wall_destroyed.emit(cell, frequency, accuracy)
	# <<< НОВОЕ: начисляем очки за разрушение стены
	Global.add_wall_score(accuracy)


func get_same_rock_walls(start_cell: Vector2i, rock_type_id: int, max_distance: int) -> Array:
	var result = []
	var wall_tiles = level_data.get("wall_tiles", {})
	var walls = level_data.get("walls", [])
	
	var queue = [start_cell]
	var visited = {}
	visited[start_cell] = true
	var distances = {}
	distances[start_cell] = 0
	
	while queue.size() > 0:
		var current = queue.pop_front()
		var dist = distances[current]
		
		if dist >= max_distance:
			continue
		
		for dir in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
			var neighbor = current + dir
			
			if neighbor in visited:
				continue
			
			visited[neighbor] = true
			
			if walls.has(neighbor) and wall_tiles.get(neighbor, -1) == rock_type_id:
				result.append(neighbor)
				queue.append(neighbor)
				distances[neighbor] = dist + 1
	
	return result


func get_nearby_walls(cell: Vector2i) -> Array:
	var nearby = []
	var walls = level_data.get("walls", [])
	
	for dir in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
		var neighbor = cell + dir
		if walls.has(neighbor):
			nearby.append(neighbor)
	
	return nearby


func get_walls_in_radius(center: Vector2i, radius: int) -> Array:
	var result = []
	var walls = level_data.get("walls", [])
	
	for dx in range(-radius, radius + 1):
		for dy in range(-radius, radius + 1):
			if dx == 0 and dy == 0:
				continue
			var cell = center + Vector2i(dx, dy)
			if walls.has(cell):
				result.append(cell)
	
	return result


func get_floor_cells_in_radius(center: Vector2i, radius: int) -> Array:
	var result = []
	var floor = level_data.get("floor", [])
	
	for dx in range(-radius, radius + 1):
		for dy in range(-radius, radius + 1):
			if dx == 0 and dy == 0:
				continue
			var cell = center + Vector2i(dx, dy)
			var is_floor = false
			for floor_cell in floor:
				if floor_cell == cell:
					is_floor = true
					break
			if is_floor:
				result.append(cell)
	
	return result


func spawn_additional_rubbles():
	# Раньше механика включалась только с 8 уровня - на практике игрок
	# почти никогда её не встречал. Теперь работает с первого уровня,
	# но слабо (маленький шанс, максимум 1 куча), и постепенно усиливается
	# с глубиной - опаснее, но не жестоко на старте.
	var level_diff = max(current_level - 1, 0)
	var base_chance = 0.12 + (level_diff * 0.06)
	base_chance = clamp(base_chance, 0.12, 0.9)
	var min_count = 1
	var max_count = 1 + int(level_diff / 3)
	max_count = clamp(max_count, 1, 10)
	if randf() > base_chance:
		return
	var count = randi_range(min_count, max_count)
	print("Дополнительные кучи: шанс ", base_chance * 100, "%, количество ", count)
	var floor_cells = level_data.get("floor", [])
	var walls = level_data.get("walls", [])
	var rubbles = level_data.get("rubbles", [])
	var valid_cells = []
	for cell in floor_cells:
		if cell.x == 0 or cell.y == 0 or cell.x == level_size.x - 1 or cell.y == level_size.y - 1:
			continue
		if walls.has(cell):
			continue
		if rubbles.has(cell):
			continue
		var has_gen = false
		for gen in generators.values():
			if gen.cell == cell:
				has_gen = true
				break
		if has_gen:
			continue
		valid_cells.append(cell)
	if valid_cells.is_empty():
		print("Нет свободных клеток для дополнительных куч!")
		return
	valid_cells.shuffle()
	var selected_cells = []
	for i in range(min(count, valid_cells.size())):
		selected_cells.append(valid_cells[i])
	
	var wall_tiles = level_data.get("wall_tiles", {})
	
	for cell in selected_cells:
		var vehicle_id = get_vehicle_at_cell(cell)
		if vehicle_id != -1:
			_remove_vehicle_from_level(vehicle_id)
			print("Транспорт #", vehicle_id, " удалён перед спавном кучи в клетке ", cell)
		
		# <<< ИСПРАВЛЕНО: определяем rock_type_id по ближайшей стене
		var rock_type_id = _get_nearest_wall_rock_type(cell)
		var rock = Global.rock_types.get(rock_type_id, Global.rock_types[0])
		
		# Вес фиксирован по типу породы: известняк(0) и кимберлит(3) - 10 кг,
		# кварцит(1) и гематит(2) - 20 кг.
		var weight = 10 if rock_type_id in [0, 3] else 20
		var rubble_tiles = level_data.get("rubble_tiles", {})
		rubble_tiles[cell] = rock_type_id
		level_data["rubble_tiles"] = rubble_tiles
		rubble_tile_map.set_cell(cell, 0, Vector2i(rock_type_id, 2))
		level_data["rubbles"].append(cell)
		var rubble_data = {
			"cell": cell,
			"weight": weight,
			"remaining": weight,
			"rock_type": rock["name"],
			"rock_type_id": rock_type_id
		}
		Global.rubbles.append(rubble_data)
		rubble_spawned.emit(cell, weight)
		Global.level_state[current_level] = level_data
		print("Дополнительная куча (", rock["name"], ") появилась в клетке ", cell, " весом ", weight, " кг")

# <<< НОВОЕ: определяем тип породы по ближайшей стене
func _get_nearest_wall_rock_type(cell: Vector2i) -> int:
	var wall_tiles = level_data.get("wall_tiles", {})
	var walls = level_data.get("walls", [])
	var min_dist = 999
	var nearest_rock_id = 0
	for wall_cell in walls:
		var dist = abs(cell.x - wall_cell.x) + abs(cell.y - wall_cell.y)
		if dist < min_dist:
			min_dist = dist
			nearest_rock_id = wall_tiles.get(wall_cell, 0)
	return nearest_rock_id


func spawn_rubble(cell: Vector2i, frequency: int, accuracy: float, rock_type_id: int = 0):
	var vehicle_id = get_vehicle_at_cell(cell)
	
	# Если в клетке есть транспорт - удаляем его ДО спавна кучи
	if vehicle_id != -1:
		_remove_vehicle_from_level(vehicle_id)
		print("Транспорт #", vehicle_id, " удалён перед спавном кучи в клетке ", cell)
	
	var rock = Global.rock_types.get(rock_type_id, Global.rock_types[0])
	# Вес фиксирован по типу породы: известняк(0) и кимберлит(3) - 10 кг,
	# кварцит(1) и гематит(2) - 20 кг.
	var weight = 10 if rock_type_id in [0, 3] else 20
	
	var rubble_tiles = level_data.get("rubble_tiles", {})
	rubble_tiles[cell] = rock_type_id
	level_data["rubble_tiles"] = rubble_tiles
	
	rubble_tile_map.set_cell(cell, 0, Vector2i(rock_type_id, 2))
	level_data["rubbles"].append(cell)
	
	var rubble_data = {
		"cell": cell,
		"weight": weight,
		"remaining": weight,
		"rock_type": rock["name"],
		"rock_type_id": rock_type_id
	}
	Global.rubbles.append(rubble_data)
	
	rubble_spawned.emit(cell, weight)
	Global.level_state[current_level] = level_data


func _remove_vehicle_from_level(vehicle_id: int):
	# Удаляем из trucks
	for truck in Global.vehicles["trucks"]:
		if truck.get("id") == vehicle_id:
			Global.vehicles["trucks"].erase(truck)
			var new_list = []
			for t in level_data.get("trucks", []):
				if t.get("id") != vehicle_id:
					new_list.append(t)
			level_data["trucks"] = new_list
			vehicle_destroyed.emit(vehicle_id)
			print("Грузовик #", vehicle_id, " уничтожен обвалом!")
			return
	
	# Удаляем из excavators
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


func get_vehicle_at_cell(cell: Vector2i) -> int:
	for truck in level_data.get("trucks", []):
		var pos = Vector2i(truck.get("cell", [0, 0])[0], truck.get("cell", [0, 0])[1])
		if pos == cell:
			return truck.get("id")
	
	for excavator in level_data.get("excavators", []):
		var pos = Vector2i(excavator.get("cell", [0, 0])[0], excavator.get("cell", [0, 0])[1])
		if pos == cell:
			return excavator.get("id")
	
	return -1


func is_cell_free(cell: Vector2i) -> bool:
	if cell.x < 1 or cell.x >= level_size.x - 1 or cell.y < 1 or cell.y >= level_size.y - 1:
		return false
	var is_floor = false
	for floor_cell in level_data.get("floor", []):
		if floor_cell == cell:
			is_floor = true
			break
	if not is_floor:
		return false
	if level_data.get("walls", []).has(cell):
		return false
	if level_data.get("rubbles", []).has(cell):
		return false
	for gen in generators.values():
		if gen.cell == cell:
			return false
	# <<< НОВОЕ: проверка транспорта
	for truck in level_data.get("trucks", []):
		var truck_cell = Vector2i(truck.get("cell", [0, 0])[0], truck.get("cell", [0, 0])[1])
		if truck_cell == cell:
			return false
	for excavator in level_data.get("excavators", []):
		var excavator_cell = Vector2i(excavator.get("cell", [0, 0])[0], excavator.get("cell", [0, 0])[1])
		if excavator_cell == cell:
			return false
	return true


func destroy_vehicle(vehicle_id: int):
	_remove_vehicle_from_level(vehicle_id)


func get_wall_frequency(cell: Vector2i) -> int:
	return wall_frequencies.get(cell, 0)


func is_wall_destroyed(cell: Vector2i) -> bool:
	return not level_data.get("walls", []).has(cell)


func get_generators() -> Dictionary:
	return generators


func get_generator(generator_id: int) -> FrequencyGenerator:
	return generators.get(generator_id, null)


func destroy_wall_with_accuracy(cell: Vector2i, frequency: int, accuracy: float):
	var wall_exists = false
	for wall_cell in level_data.get("walls", []):
		if wall_cell == cell:
			wall_exists = true
			break
	
	if not wall_exists:
		return
	
	var final_accuracy = accuracy
	if final_accuracy <= 0.0:
		var target_freq = wall_frequencies.get(cell, 0)
		if target_freq == 0:
			return
		final_accuracy = _resonance_accuracy(frequency, target_freq)
	
	# Раз стену вообще разрушают - значит резонанс уже реально накопился
	# (см. WaveAnimation) - тут больше не отклоняем по разнице Гц, а лишь
	# масштабируем силу/радиус разрушения по точности совпадения частоты.
	if final_accuracy >= 0.85:
		destroy_wall_perfect(cell, frequency, final_accuracy)
	elif final_accuracy >= 0.5:
		destroy_wall_good(cell, frequency, final_accuracy)
	else:
		destroy_wall_medium(cell, frequency, final_accuracy)


func destroy_wall_by_frequency(cell: Vector2i, frequency: int):
	var wall_exists = false
	for wall_cell in level_data.get("walls", []):
		if wall_cell == cell:
			wall_exists = true
			break
	
	if not wall_exists:
		return
	
	var target_freq = wall_frequencies.get(cell, 0)
	if target_freq == 0:
		return
	
	var accuracy = _resonance_accuracy(frequency, target_freq)
	destroy_wall_with_accuracy(cell, frequency, accuracy)


# Та же колоколообразная кривая отклика, что и в WaveAnimation.resonance_response —
# держим её в одном месте с тем же смыслом: чем ближе частота к собственной
# частоте стены, тем выше точность/сила разрушения, без жёсткого обрыва по Гц.
func _resonance_accuracy(frequency: float, target_freq: float) -> float:
	var sigma = 35.0
	var diff = frequency - target_freq
	var accuracy = exp(-(diff * diff) / (2.0 * sigma * sigma))
	return clamp(accuracy, 0.15, 1.0)
