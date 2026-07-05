extends Node


var money = 1000
var purchased_levels = {}
var is_new_game = false
var current_level = 1
var level_state = {}
var vehicle_id_counter = 0
var is_on_level = false


# Лимиты на технику
var MAX_TRUCKS = 5
var MAX_EXCAVATORS = 3


var rubbles = []  # [{cell: Vector2i, weight: int, remaining: int, rock_type_id: int}]
var factory_queue_weight = 0
var factory_queue = []  # [{"weight": int, "ore_type": String}]
var factory_processing = null  # {"weight": int, "progress": float, "ore_type": String}
var FACTORY_PROCESSING_SPEED = 2.0


var storage = {
	"gold": 0,
	"iron": 0,
	"coal": 0
}


# Данные о руде в зависимости от породы кучи
var rubble_ore_data = {
	0: {  
		"coal": 1.0,
		"iron": 0.0,
		"gold": 0.0
	},
	1: {  
		"coal": 0.7,
		"iron": 0.3,
		"gold": 0.0
	},
	2: { 
		"coal": 0.25,
		"iron": 0.7,
		"gold": 0.05
	},
	3: { 
		"coal": 0.0,
		"iron": 0.5,
		"gold": 0.5
	}
}


var ore_data = {
	"gold": {
		"name": "Золото",
		"price": 300,  # было 100
		"atlas_region": Rect2(0, 0, 64, 64),
		"icon": null
	},
	"iron": {
		"name": "Железо",
		"price": 100,  # было 50
		"atlas_region": Rect2(64, 0, 64, 64),
		"icon": null
	},
	"coal": {
		"name": "Уголь",
		"price": 50,  # было 25
		"atlas_region": Rect2(128, 0, 64, 64),
		"icon": null
	}
}


var rock_types = {
	0: {
		"name": "Известняк",
		"min_freq": 100,
		"max_freq": 600,
		"color": Color(0.7, 0.7, 0.6),
		"weight_multiplier": 1.0,
		"min_level": 1
	},
	1: {
		"name": "Кварцит",
		"min_freq": 600,
		"max_freq": 1300,
		"color": Color(0.9, 0.8, 0.7),
		"weight_multiplier": 1.3,
		"min_level": 3
	},
	2: {
		"name": "Гематит",
		"min_freq": 1300,
		"max_freq": 2000,
		"color": Color(0.6, 0.3, 0.2),
		"weight_multiplier": 1.6,
		"min_level": 5
	},
	3: {
		"name": "Кимберлит",
		"min_freq": 2000,
		"max_freq": 3000,
		"color": Color(0.3, 0.5, 0.8),
		"weight_multiplier": 2.0,
		"min_level": 8
	}
}


var ore_texture_path = load("res://assets/textures/icons/ore.png")
var vehicle_texture_path = load("res://assets/textures/icons/Vehicles.png")
var exo2_font: FontFile


var vehicle_templates = {
	"truck": {
		"name": "Грузовик",
		"price": 100,
		"capacity": 50.0,
		"speed": 20.0,
		"description": "Перевозит землю",
		"icon": null,
		"atlas_region": Rect2(64, 0, 64, 64)
	},
	"excavator": {
		"name": "Экскаватор",
		"price": 150,
		"damage": 10.0,
		"speed": 20.0,
		"description": "Загружает грузовик",
		"icon": null,
		"atlas_region": Rect2(0, 0, 64, 64)
	}
}


var digging_progress = {}


var vehicles = {
	"trucks": [],
	"excavators": []
}


func _ready() -> void:
	if ore_data["gold"]["icon"] == null:
		for ore_id in ore_data:
			var data = ore_data[ore_id]
			var ore_texture = AtlasTexture.new()
			ore_texture.atlas = ore_texture_path
			ore_texture.region = data["atlas_region"]
			data["icon"] = ore_texture
		
		for vehicle in vehicle_templates:
			var data = vehicle_templates[vehicle]
			var vehicle_texture = AtlasTexture.new()
			vehicle_texture.atlas = vehicle_texture_path
			vehicle_texture.region = data["atlas_region"]
			data["icon"] = vehicle_texture
	
	exo2_font = load("res://assets/fonts/Exo2-VariableFont_wght.ttf") as FontFile
	
	set_process(true)


func _process(delta: float) -> void:
	process_factory(delta)


func reset_game():
	money = 1000
	purchased_levels.clear()
	level_state.clear()
	vehicle_id_counter = 0
	rubbles.clear()
	factory_queue.clear()
	factory_queue_weight = 0
	factory_processing = null
	storage = {
		"gold": 0,
		"iron": 0,
		"coal": 0
	}
	vehicles = {
		"trucks": [],
		"excavators": []
	}
	digging_progress.clear()
	is_on_level = false
	
	print("=== НОВАЯ ИГРА ГОТОВА ===")
	print("Деньги: ", money)


func add_ore(ore_id: String, amount: int):
	if storage.has(ore_id):
		storage[ore_id] += amount


func sell_ore(ore_id: String, amount: int):
	if storage.has(ore_id):
		storage[ore_id] -= amount
		money += amount * ore_data[ore_id]["price"]


func get_vehicle_count(type: String) -> int:
	if type == "truck":
		return vehicles["trucks"].size()
	elif type == "excavator":
		return vehicles["excavators"].size()
	return 0


func get_max_vehicles(type: String) -> int:
	if type == "truck":
		return MAX_TRUCKS
	elif type == "excavator":
		return MAX_EXCAVATORS
	return 0


func can_buy_vehicle(type: String) -> bool:
	var current = get_vehicle_count(type)
	var max_count = get_max_vehicles(type)
	return current < max_count


func get_vehicle_price(type: String) -> int:
	var base_price = vehicle_templates[type]["price"]
	var count = get_vehicle_count(type)
	# Каждый следующий транспорт на 50% дороже
	# 1-й: base_price, 2-й: base_price * 1.5, 3-й: base_price * 2.25, и т.д.
	var multiplier = pow(1.5, count)
	return int(base_price * multiplier)


func buy_vehicle(type: String) -> bool:
	if not can_buy_vehicle(type):
		print("Достигнут лимит ", type, "ов! Максимум: ", get_max_vehicles(type))
		return false
	
	var price = get_vehicle_price(type)
	if money >= price:
		money -= price
		vehicle_id_counter += 1
		var new_id = vehicle_id_counter
		
		if type == "truck":
			vehicles["trucks"].append({
				"id": new_id,
				"template": type,
				"status": "idle",
				"task": null,
				"progress": 0.0,
				"ore": 0,
				"ore_type": "",
				"capacity": vehicle_templates[type]["capacity"],
				"location": "parking",   
				"location_id": null         
			})
		elif type == "excavator":
			vehicles["excavators"].append({
				"id": new_id,
				"template": type,
				"status": "idle",
				"task": null,
				"progress": 0.0,
				"damage": vehicle_templates[type]["damage"],
				"location": "parking",   
				"location_id": null,
				"is_full": false,
				"ore_amount": 0,
				"ore_type": ""
			})
		return true
	return false


func add_to_factory_queue(weight: int, ore_type: String):
	factory_queue.append({
		"weight": weight,
		"ore_type": ore_type
	})
	factory_queue_weight += weight
	print("Добавлено ", weight, " кг ", ore_type, " в очередь фабрики. Всего в очереди: ", factory_queue_weight)


func process_factory(delta):
	if factory_processing == null and factory_queue.size() > 0:
		var item = factory_queue[0]
		var weight = min(10, item["weight"])
		
		if item["weight"] <= 10:
			factory_queue.pop_front()
		else:
			item["weight"] -= 10
		
		factory_queue_weight -= weight
		
		factory_processing = {
			"weight": weight,
			"progress": 0.0,
			"ore_type": item["ore_type"]
		}
		print("Начата переработка ", weight, " кг ", item["ore_type"], ". Осталось в очереди: ", factory_queue_weight)
	
	if factory_processing != null:
		factory_processing["progress"] += delta * FACTORY_PROCESSING_SPEED
		if factory_processing["progress"] >= factory_processing["weight"]:
			var ore_type = factory_processing["ore_type"]
			var amount = 1 + randi_range(0, 2)
			storage[ore_type] += amount
			print("Переработано! Получено ", amount, " ", ore_type)
			factory_processing = null
