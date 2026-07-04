extends Node


func generate(level_num):
	var data = {
		"floor": [],
		"border": [],
		"walls": [],
		"rubbles": [],
		"trucks": [],
		"excavators": [],
		"wall_frequencies": {},
		"wall_tiles": {}
	}
	
	var size = get_level_size(level_num)
	
	# Заполняем пол и границы
	for x in range(size.x):
		for y in range(size.y):
			data["floor"].append(Vector2i(x, y))
			
			if x == 0 or y == 0 or x == size.x - 1 or y == size.y - 1:
				data["border"].append(Vector2i(x, y))
	
	# Генерируем стены справа налево
	var wall_density = get_wall_density(level_num)
	var wall_cells = []
	
	var last_col = size.x - 2
	var first_col = 1
	
	var cols_to_fill = int((last_col - first_col + 1) * wall_density)
	
	# Заполняем справа налево
	for col in range(last_col, last_col - cols_to_fill, -1):
		for y in range(1, size.y - 1):
			wall_cells.append(Vector2i(col, y))
	
	wall_cells.sort()
	data["walls"] = wall_cells
	
	# Получаем доступные породы для этого уровня
	var available_rocks = get_available_rocks(level_num)
	
	# Генерируем wall_tiles с паттернами
	var wall_tiles = {}
	var wall_frequencies = {}
	
	# Разделяем стены по породам с разными паттернами
	var rock_groups = assign_rocks_to_walls(wall_cells, available_rocks, level_num, size)
	
	for cell in wall_cells:
		var rock_id = rock_groups[cell]
		wall_tiles[cell] = rock_id
		
		var rock = Global.rock_types[rock_id]
		var freq = randi_range(rock["min_freq"], rock["max_freq"])
		freq = round(freq / 10.0) * 10
		wall_frequencies[cell] = freq
	
	data["wall_tiles"] = wall_tiles
	data["wall_frequencies"] = wall_frequencies
	
	Global.level_state[level_num] = data
	
	return data


func get_available_rocks(level_num):
	var rocks = []
	
	# Добавляем породы по уровням
	if level_num <= 2:
		rocks = [0]
	elif level_num <= 4:
		rocks = [0, 1]
	elif level_num <= 6:
		rocks = [0, 1, 2]
	elif level_num <= 8:
		rocks = [0, 1, 2, 3]
	elif level_num <= 10:
		rocks = [1, 2, 3]
	elif level_num <= 12:
		rocks = [2, 3]
	else:
		rocks = [3]
	
	return rocks


func assign_rocks_to_walls(wall_cells: Array, available_rocks: Array, level_num: int, size: Vector2) -> Dictionary:
	var result = {}
	var wall_count = wall_cells.size()
	
	# Если порода одна — все стены одной породы
	if available_rocks.size() == 1:
		for cell in wall_cells:
			result[cell] = available_rocks[0]
		return result
	
	# Создаём копию клеток для работы
	var cells_copy = wall_cells.duplicate()
	
	# Для каждой породы, кроме последней, выделяем область
	for rock_id in available_rocks:
		var pattern = get_pattern_for_rock(rock_id)
		var cells_for_rock = get_cells_by_pattern(cells_copy, pattern, size)
		
		for cell in cells_for_rock:
			result[cell] = rock_id
			# Удаляем использованные клетки
			var idx = cells_copy.find(cell)
			if idx != -1:
				cells_copy.remove_at(idx)
	
	# Оставшиеся клетки отдаём последней породе
	var last_rock = available_rocks[available_rocks.size() - 1]
	for cell in cells_copy:
		result[cell] = last_rock
	
	return result


func get_pattern_for_rock(rock_id: int) -> String:
	match rock_id:
		0: return "big_circles"      # Известняк — большие круги
		1: return "scattered"        # Кварцит — вкрапления
		2: return "small_circles"    # Гематит — маленькие круги
		3: return "scattered"        # Кимберлит — вкрапления
	return "scattered"


func get_cells_by_pattern(cells: Array, pattern: String, size: Vector2) -> Array:
	var result = []
	var cells_copy = cells.duplicate()
	
	match pattern:
		"big_circles":
			# Большие круги диаметром 5-8 клеток
			var attempts = 0
			while attempts < 10 and cells_copy.size() > 0:
				var center = cells_copy[randi_range(0, cells_copy.size() - 1)]
				var radius = randi_range(2, 4)  # 2-4 клетки в радиусе = диаметр 5-8
				var circle_cells = get_circle_cells(center, radius, size)
				
				# Проверяем, есть ли эти клетки в доступных
				var valid_cells = []
				for cell in circle_cells:
					if cells_copy.has(cell):
						valid_cells.append(cell)
				
				if valid_cells.size() > 0:
					for cell in valid_cells:
						result.append(cell)
						cells_copy.erase(cell)
					
					# Прерываем если набрали достаточно
					if result.size() > cells.size() * 0.3:
						break
				
				attempts += 1
		
		"small_circles":
			# Маленькие круги диаметром 2-4 клетки
			var attempts = 0
			while attempts < 15 and cells_copy.size() > 0:
				var center = cells_copy[randi_range(0, cells_copy.size() - 1)]
				var radius = randi_range(1, 2)  # 1-2 клетки в радиусе = диаметр 2-4
				var circle_cells = get_circle_cells(center, radius, size)
				
				var valid_cells = []
				for cell in circle_cells:
					if cells_copy.has(cell):
						valid_cells.append(cell)
				
				if valid_cells.size() > 0:
					for cell in valid_cells:
						result.append(cell)
						cells_copy.erase(cell)
					
					if result.size() > cells.size() * 0.2:
						break
				
				attempts += 1
		
		"scattered":
			# Вкрапления — одиночные клетки или пары
			var target_count = int(cells.size() * 0.15)  # 15% от всех клеток
			var attempts = 0
			while attempts < target_count and cells_copy.size() > 0:
				var idx = randi_range(0, cells_copy.size() - 1)
				var cell = cells_copy[idx]
				result.append(cell)
				cells_copy.remove_at(idx)
				
				# Иногда добавляем соседнюю клетку (пара)
				if randi_range(0, 1) == 0 and cells_copy.size() > 0:
					var neighbors = get_neighbors(cell, size)
					var available_neighbors = []
					for n in neighbors:
						if cells_copy.has(n):
							available_neighbors.append(n)
					
					if available_neighbors.size() > 0:
						var neighbor = available_neighbors[randi_range(0, available_neighbors.size() - 1)]
						result.append(neighbor)
						cells_copy.erase(neighbor)
				
				attempts += 1
	
	return result


func get_circle_cells(center: Vector2i, radius: int, size: Vector2) -> Array:
	var cells = []
	for dx in range(-radius, radius + 1):
		for dy in range(-radius, radius + 1):
			var dist = abs(dx) + abs(dy)  # Манхэттенское расстояние
			if dist <= radius:
				var cell = center + Vector2i(dx, dy)
				if cell.x > 0 and cell.x < size.x - 1 and cell.y > 0 and cell.y < size.y - 1:
					cells.append(cell)
	return cells


func get_neighbors(cell: Vector2i, size: Vector2) -> Array:
	var dirs = [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]
	var neighbors = []
	for dir in dirs:
		var n = cell + dir
		if n.x > 0 and n.x < size.x - 1 and n.y > 0 and n.y < size.y - 1:
			neighbors.append(n)
	return neighbors


func get_level_size(level_num):
	var base_width = 12
	var base_height = 6
	
	var width_cycle = (level_num - 1) % 4
	var width_add = width_cycle
	var width = base_width + width_add
	
	var height_cycle = floor((level_num - 1) / 4)
	var height_add = height_cycle * 2
	var height = base_height + height_add
	
	return Vector2(width, height)


func get_wall_density(level_num):
	var cycle = (level_num - 1) % 4
	var densities = [0.3, 0.4, 0.5, 0.6]
	return densities[cycle]
