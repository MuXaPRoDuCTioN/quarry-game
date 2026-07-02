extends Node


var money = 1000
var purchased_levels = {}
var is_new_game = false
var current_level = 1
var level_state = {}
var vehicle_id_counter = 0
var is_on_level = false


var rubbles = []  # [{cell: Vector2i, weight: int, remaining: int}]
var factory_queue_weight = 0
var factory_processing = null
var FACTORY_PROCESSING_SPEED = 2.0


var storage = {
	"gold": 0,
	"iron": 0,
	"coal": 0
}


var ore_data = {
	"gold": {
		"name": "Золото",
		"price": 100,
		"atlas_region": Rect2(0, 0, 64, 64),
		"icon": null
	},
	"iron": {
		"name": "Железо",
		"price": 50,
		"atlas_region": Rect2(64, 0, 64, 64),
		"icon": null
	},
	"coal": {
		"name": "Уголь",
		"price": 25,
		"atlas_region": Rect2(128, 0, 64, 64),
		"icon": null
	}
}


var ore_texture_path = load("res://assets/textures/icons/ore.png")
var vehicle_texture_path = load("res://assets/textures/icons/Vehicles.png")


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
	# Инициализируем иконки только если их ещё нет
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
	
	set_process(true)


func _process(delta: float) -> void:
	process_factory(delta)


func reset_game():
	# Сбрасываем деньги
	money = 1000
	
	# Очищаем купленные уровни
	purchased_levels.clear()
	
	# Очищаем состояние уровней
	level_state.clear()
	
	# Сбрасываем счётчик ID транспорта
	vehicle_id_counter = 0
	
	# Очищаем все кучи
	rubbles.clear()
	
	# Сбрасываем фабрику
	factory_queue_weight = 0
	factory_processing = null
	
	# Очищаем склад
	storage = {
		"gold": 0,
		"iron": 0,
		"coal": 0
	}
	
	# Очищаем весь транспорт
	vehicles = {
		"trucks": [],
		"excavators": []
	}
	
	# Сбрасываем прогресс копания
	digging_progress.clear()
	
	# Сбрасываем флаг нахождения на уровне
	is_on_level = false
	
	print("=== НОВАЯ ИГРА ГОТОВА ===")
	print("Деньги: ", money)
	print("Транспорт: 0")
	print("Уровни: 0")


func add_ore(ore_id: String, amount: int):
	if storage.has(ore_id):
		storage[ore_id] += amount


func sell_ore(ore_id: String, amount: int):
	if storage.has(ore_id):
		storage[ore_id] -= amount
		money += amount * ore_data[ore_id]["price"]


func buy_vehicle(type: String) -> bool:
	var price = vehicle_templates[type]["price"]
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
				"ore_amount": 0
			})
		return true
	return false


func add_to_factory_queue(weight: int):
	factory_queue_weight += weight
	print("Добавлено ", weight, " кг земли в очередь фабрики. Всего в очереди: ", factory_queue_weight)


func process_factory(delta):
	if factory_processing == null and factory_queue_weight > 0:
		var weight = min(10, factory_queue_weight)
		factory_queue_weight -= weight
		factory_processing = {
			"weight": weight,
			"progress": 0.0
		}
		print("Начата переработка ", weight, " кг. Осталось в очереди: ", factory_queue_weight)
	
	if factory_processing != null:
		factory_processing["progress"] += delta * FACTORY_PROCESSING_SPEED
		if factory_processing["progress"] >= factory_processing["weight"]:
			var ore_types = ["gold", "iron", "coal"]
			var ore_type = ore_types[randi_range(0, 2)]
			var amount = 1 + randi_range(0, 2)
			storage[ore_type] += amount
			print("Переработано! Получено ", amount, " ", ore_type)
			factory_processing = null
