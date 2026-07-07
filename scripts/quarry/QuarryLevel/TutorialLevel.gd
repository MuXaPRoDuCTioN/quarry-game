extends Node


func generate_tutorial_level():
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
	
	# Размер как у первого уровня (12x6)
	var size = Vector2(12, 6)
	
	for x in range(size.x):
		for y in range(size.y):
			data["floor"].append(Vector2i(x, y))
			if x == 0 or y == 0 or x == size.x - 1 or y == size.y - 1:
				data["border"].append(Vector2i(x, y))
	
	var wall_cells = []
	
	# Стена 1 - слабая (известняк) - ОДНА стена
	wall_cells.append(Vector2i(5, 3))
	
	# Стена 2 - сильная (кимберлит) - ОДНА стена
	wall_cells.append(Vector2i(9, 3))
	
	data["walls"] = wall_cells
	
	var wall_tiles = {}
	var wall_frequencies = {}
	
	# Стена 1 - известняк (ID 0), частота 250
	wall_tiles[Vector2i(5, 3)] = 0
	wall_frequencies[Vector2i(5, 3)] = 250
	
	# Стена 2 - кимберлит (ID 3), частота 2200
	wall_tiles[Vector2i(9, 3)] = 3
	wall_frequencies[Vector2i(9, 3)] = 2200
	
	data["wall_tiles"] = wall_tiles
	data["wall_frequencies"] = wall_frequencies
	
	Global.level_state[1] = data
	
	return data
