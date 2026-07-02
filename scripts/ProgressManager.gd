extends Node


var vehicles = Global.vehicles


var FACTORY_TRAVEL_TIME = 100.0
var UNLOAD_TIME = 50.0


func _ready() -> void:
	pass


func _process(delta: float) -> void:
	for truck in Global.vehicles["trucks"]:
		if truck.status == "traveling" and truck.task == "go_to_level":
			var template = Global.vehicle_templates[truck["template"]]
			truck.progress += delta * template.speed
			if truck.progress >= 100:
				truck.status = "idle"
				truck.task = null
				truck.progress = 0.0
				print("Грузовик #", truck.id, " прибыл на уровень ", truck.target_level)
				
				for level_key in Global.level_state.keys():
					var level_data = Global.level_state[level_key]
					var new_list = []
					for t in level_data.get("trucks", []):
						if t["id"] != truck.id:
							new_list.append(t)
					level_data["trucks"] = new_list

				var level_data = Global.level_state.get(truck.target_level)
				if level_data:
					var free_cell = find_free_cell(level_data)
					if free_cell:
						level_data["trucks"].append({
							"id": truck.id,
							"cell": [free_cell.x, free_cell.y]
						})
					truck["location"] = "level"
					truck["location_id"] = truck.target_level
		
		if truck.status == "traveling" and truck.task == "go_to_parking":
			var template = Global.vehicle_templates[truck["template"]]
			truck.progress += delta * template.speed
			if truck.progress >= 100:
				truck.status = "idle"
				truck.task = null
				truck.progress = 0.0
				
				var level_data = Global.level_state.get(truck["location_id"])
				if level_data:
					var new_list = []
					for t in level_data.get("trucks", []):
						if t["id"] != truck.id:
							new_list.append(t)
					level_data["trucks"] = new_list
				
				truck["location"] = "parking"
				truck["location_id"] = null
				print("Грузовик #", truck.id, " вернулся на парковку")
		
		if truck.status == "traveling" and truck.task == "go_to_factory":
			var template = Global.vehicle_templates[truck["template"]]
			truck.progress += delta * template.speed
			if truck.progress >= 100:
				truck.status = "idle"
				truck.task = null
				truck.progress = 0.0
				print("Грузовик #", truck.id, " прибыл на фабрику")
				
				truck.status = "unloading"
				truck.task = "unload_at_factory"
				truck.progress = 0.0
				truck["location"] = "factory"
				truck["location_id"] = null
		
		if truck.status == "unloading" and truck.task == "unload_at_factory":
			truck.progress += delta * 20.0
			if truck.progress >= UNLOAD_TIME:
				truck.status = "idle"
				truck.task = null
				truck.progress = 0.0
				
				var ore_amount = truck.get("ore", 0)
				if ore_amount > 0:
					Global.add_to_factory_queue(ore_amount)  # Используем новую функцию
					truck["ore"] = 0
					print("Грузовик #", truck.id, " разгрузил ", ore_amount, " кг на фабрике")
				
				truck["location"] = "parking"
				truck["location_id"] = null
				print("Грузовик #", truck.id, " едет на парковку")
				
				truck.status = "traveling"
				truck.task = "go_to_parking"
				truck.progress = 0.0
	
	for excavator in Global.vehicles["excavators"]:
		if excavator.status == "traveling" and excavator.task == "go_to_level":
			var template = Global.vehicle_templates[excavator["template"]]
			excavator.progress += delta * template.speed
			if excavator.progress >= 100:
				excavator.status = "idle"
				excavator.task = null
				excavator.progress = 0.0
				print("Экскаватор #", excavator.id, " прибыл на уровень ", excavator.target_level)
				
				for level_key in Global.level_state.keys():
					var level_data = Global.level_state[level_key]
					var new_list = []
					for t in level_data.get("excavators", []):
						if t["id"] != excavator.id:
							new_list.append(t)
					level_data["excavators"] = new_list

				var level_data = Global.level_state.get(excavator.target_level)
				if level_data:
					var free_cell = find_free_cell(level_data)
					if free_cell:
						level_data["excavators"].append({
							"id": excavator.id,
							"cell": [free_cell.x, free_cell.y]
						})
				excavator["location"] = "level"
				excavator["location_id"] = excavator.target_level
		
		if excavator.status == "traveling" and excavator.task == "go_to_parking":
			var template = Global.vehicle_templates[excavator["template"]]
			excavator.progress += delta * template.speed
			if excavator.progress >= 100:
				excavator.status = "idle"
				excavator.task = null
				excavator.progress = 0.0
				
				var level_data = Global.level_state.get(excavator["location_id"])
				if level_data:
					var new_list = []
					for t in level_data.get("excavators", []):
						if t["id"] != excavator.id:
							new_list.append(t)
					level_data["excavators"] = new_list
				
				excavator["location"] = "parking"
				excavator["location_id"] = null
				print("Экскаватор #", excavator.id, " вернулся на парковку")


func find_free_cell(level_data: Dictionary):
	var floor = level_data.get("floor", [])
	if floor.is_empty():
		return null
	
	var max_x = 0
	var max_y = 0
	for cell in floor:
		if cell.x > max_x:
			max_x = cell.x
		if cell.y > max_y:
			max_y = cell.y
	
	var occupied = {}
	for truck in level_data.get("trucks", []):
		var cell = Vector2i(truck["cell"][0], truck["cell"][1])
		occupied[cell] = true
	for excavator in level_data.get("excavators", []):
		var cell = Vector2i(excavator["cell"][0], excavator["cell"][1])
		occupied[cell] = true
	
	for y in range(1, max_y):
		for x in range(1, max_x):
			var cell = Vector2i(x, y)
			if not occupied.has(cell):
				return cell
	return null


func send_truck_to_factory(truck_id: int):
	for truck in Global.vehicles["trucks"]:
		if truck["id"] == truck_id:
			if truck.get("ore", 0) <= 0:
				print("Грузовик пуст!")
				return
			
			_remove_vehicle_from_current_level(truck)
			
			truck["status"] = "traveling"
			truck["task"] = "go_to_factory"
			truck["progress"] = 0.0
			truck["location"] = "traveling"
			truck["location_id"] = null
			print("Грузовик #", truck_id, " отправлен на фабрику")
			return


func _remove_vehicle_from_current_level(vehicle: Dictionary) -> void:
	if vehicle["location"] != "level":
		return
	
	var level_data = Global.level_state.get(vehicle["location_id"])
	if not level_data:
		return
	
	var key = "trucks" if vehicle["template"] == "truck" else "excavators"
	var new_list = []
	for entry in level_data.get(key, []):
		if entry["id"] != vehicle["id"]:
			new_list.append(entry)
	level_data[key] = new_list
