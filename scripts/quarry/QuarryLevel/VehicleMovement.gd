extends Node


signal vehicle_moved(vehicle_id, new_cell)
signal vehicle_arrived(vehicle_id)
signal vehicle_progress(vehicle_id, progress) 


var moving_vehicles = {}
var MOVE_INTERVAL = 0.5


var floor_tile_map: TileMapLayer
var walls_tile_map: TileMapLayer
var border_tile_map: TileMapLayer
var rubbles_tile_map: TileMapLayer
var vehicles_tile_map: TileMapLayer
var level_size: Vector2


func setup(tilemaps: Dictionary, size: Vector2):
	floor_tile_map = tilemaps["floor"]
	walls_tile_map = tilemaps["walls"]
	border_tile_map = tilemaps["border"]
	rubbles_tile_map = tilemaps["rubbles"]
	vehicles_tile_map = tilemaps["vehicles"]
	level_size = size


func update(delta: float):
	for vehicle_id in moving_vehicles.keys():
		var move_data = moving_vehicles[vehicle_id]
		move_data["timer"] -= delta
		
		var total_steps = move_data["path"].size() - 1
		var current_step = move_data["step"]
		var progress = float(current_step - 1) / float(total_steps)
		progress = min(progress, 1.0)
		emit_signal("vehicle_progress", vehicle_id, progress)
		
		if move_data["timer"] <= 0:
			move_data["timer"] = MOVE_INTERVAL
			step_vehicle(vehicle_id)


func move_vehicle(vehicle_id: int, start_cell: Vector2i, target_cell: Vector2i, vehicle_type: String):
	# Проверяем, не движется ли уже этот транспорт
	if moving_vehicles.has(vehicle_id):
		print("Транспорт #", vehicle_id, " уже движется!")
		return false
	
	# Проверяем, не занята ли целевая клетка другим движущимся транспортом
	for moving_id in moving_vehicles:
		var data = moving_vehicles[moving_id]
		if data["path"].size() > 0:
			var last_cell = data["path"][-1]
			if last_cell == target_cell:
				print("Клетка ", target_cell, " занята другим транспортом!")
				return false
	
	var path = find_path(start_cell, target_cell, vehicle_id)
	if path == null or path.size() <= 1:
		print("Нет пути!")
		return false
		
	moving_vehicles[vehicle_id] = {
		"path": path,
		"step": 1,
		"timer": MOVE_INTERVAL,
		"type": vehicle_type
	}
	
	emit_signal("vehicle_moved", vehicle_id, path[0])
	return true


func step_vehicle(vehicle_id: int):
	var move_data = moving_vehicles[vehicle_id]
	var path = move_data["path"]
	var step = move_data["step"]
	
	if step >= path.size():
		finish_vehicle_move(vehicle_id)  
		return
	
	var new_cell = path[step]
	var level_data = Global.level_state[Global.current_level]
	var key = "trucks" if move_data["type"] == "truck" else "excavators"
	for entry in level_data.get(key, []):
		if entry["id"] == vehicle_id:
			entry["cell"] = [new_cell.x, new_cell.y]
			break
	
	emit_signal("vehicle_moved", vehicle_id, new_cell)
	move_data["step"] += 1


func finish_vehicle_move(vehicle_id: int):
	moving_vehicles.erase(vehicle_id)
	emit_signal("vehicle_arrived", vehicle_id)


func find_path(start: Vector2i, target: Vector2i, vehicle_id: int = -1):
	var queue = [start]
	var came_from = {}
	came_from[start] = null
	
	var directions = [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]
	
	while queue.size() > 0:
		var current = queue.pop_front()
		if current == target:
			var path = []
			while current != null:
				path.append(current)
				current = came_from[current]
			path.reverse()
			return path
		
		for dir in directions:
			var neighbor = current + dir
			
			if neighbor.x < 1 or neighbor.x >= level_size.x - 1:
				continue
			if neighbor.y < 1 or neighbor.y >= level_size.y - 1:
				continue
			
			if floor_tile_map.get_cell_source_id(neighbor) == -1:
				continue
			if walls_tile_map.get_cell_source_id(neighbor) != -1:
				continue
			if border_tile_map.get_cell_source_id(neighbor) != -1:
				continue
			if rubbles_tile_map.get_cell_source_id(neighbor) != -1:
				continue
			if vehicles_tile_map.get_cell_source_id(neighbor) != -1:
				# Проверяем, не стоит ли там этот же транспорт
				var level_data = Global.level_state[Global.current_level]
				var blocked = false
				for truck in level_data.get("trucks", []):
					if truck["id"] == vehicle_id:
						continue
					var pos = Vector2i(truck["cell"][0], truck["cell"][1])
					if pos == neighbor:
						blocked = true
						break
				if not blocked:
					for ex in level_data.get("excavators", []):
						if ex["id"] == vehicle_id:
							continue
						var pos = Vector2i(ex["cell"][0], ex["cell"][1])
						if pos == neighbor:
							blocked = true
							break
				if blocked:
					continue
			
			if neighbor in came_from:
				continue
			
			came_from[neighbor] = current
			queue.append(neighbor)
	
	return null


func get_vehicle_cell(vehicle_id: int, vehicle_type: String):
	var level_data = Global.level_state[Global.current_level]
	var key = "trucks" if vehicle_type == "truck" else "excavators"
	for entry in level_data.get(key, []):
		if entry["id"] == vehicle_id:
			return Vector2i(entry["cell"][0], entry["cell"][1])
	return null


func is_moving():
	return moving_vehicles.size() > 0


func find_free_cell_near(target: Vector2i, from: Vector2i) -> Vector2i:
	var directions = [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]
	var best_cell = null
	var best_dist = 9999
	
	for dir in directions:
		var neighbor = target + dir
		
		if neighbor.x < 1 or neighbor.x >= level_size.x - 1:
			continue
		if neighbor.y < 1 or neighbor.y >= level_size.y - 1:
			continue
		
		if floor_tile_map.get_cell_source_id(neighbor) == -1:
			continue
		if walls_tile_map.get_cell_source_id(neighbor) != -1:
			continue
		if border_tile_map.get_cell_source_id(neighbor) != -1:
			continue
		if rubbles_tile_map.get_cell_source_id(neighbor) != -1:
			continue
		if vehicles_tile_map.get_cell_source_id(neighbor) != -1:
			continue
		
		var dist = abs(neighbor.x - from.x) + abs(neighbor.y - from.y)
		if dist < best_dist:
			best_dist = dist
			best_cell = neighbor
	
	return best_cell
