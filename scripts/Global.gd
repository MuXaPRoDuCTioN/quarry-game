extends Node


var money = 1000
var purchased_levels = {}
var is_new_game = false
var current_level = 1
var level_state = {}
var vehicle_id_counter = 0
var is_on_level = false


var MAX_TRUCKS = 5
var MAX_EXCAVATORS = 3


var trucks_bought_total: int = 0
var excavators_bought_total: int = 0


var rubbles = [] 
var factory_queue_weight = 0
var factory_queue = [] 
var factory_processing = null 
var FACTORY_PROCESSING_SPEED = 2.0


var storage = {
	"gold": 0,
	"iron": 0,
	"coal": 0
}


var rubble_ore_data = {
	0: { "coal": 1.0, "iron": 0.0, "gold": 0.0 },
	1: { "coal": 0.5, "iron": 0.5, "gold": 0.0 },
	2: { "coal": 0.3, "iron": 0.6, "gold": 0.1 },
	3: { "coal": 0.0, "iron": 0.5, "gold": 0.5 }
}


var ore_data = {
	"gold": {
		"name": "Золото",
		"price": 300,
		"atlas_region": Rect2(0, 0, 64, 64),
		"icon": null
	},
	"iron": {
		"name": "Железо",
		"price": 100,
		"atlas_region": Rect2(64, 0, 64, 64),
		"icon": null
	},
	"coal": {
		"name": "Уголь",
		"price": 50,
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


var current_score: int = 0
var score_breakdown: Dictionary = {
	"walls_perfect": 0,
	"walls_good": 0,
	"walls_medium": 0,
	"levels_completed": 0,
	"time_bonus": 0,
	"money_bonus": 0
}
var game_start_time: float = 0.0
var level_start_time: float = 0.0
var levels_completed: int = 0
signal score_changed(points: int, reason: String)


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


var is_tutorial: bool = false


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
	
	trucks_bought_total = 0
	excavators_bought_total = 0
	print("=== НОВАЯ ИГРА ГОТОВА ===")
	print("Деньги: ", money)
	
	# Сброс счёта при новой игре
	current_score = 0
	score_breakdown = {
		"walls_perfect": 0,
		"walls_good": 0,
		"walls_medium": 0,
		"levels_completed": 0,
		"time_bonus": 0,
		"money_bonus": 0
	}
	levels_completed = 0


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
	# Используем общий счётчик купленных, а не текущее количество
	var count = trucks_bought_total if type == "truck" else excavators_bought_total
	# Каждый следующий транспорт на 50% дороже
	var multiplier = pow(1.5, count)
	return int(base_price * multiplier)


func buy_vehicle(type: String) -> bool:
	# === ЗАЩИТА ОТ ДУРАКА: в обучении только 1 грузовик + 1 экскаватор ===
	if is_tutorial:
		var trucks_count = vehicles["trucks"].size()
		var excavators_count = vehicles["excavators"].size()
		if type == "truck" and trucks_count >= 1:
			print("[Tutorial] Нельзя купить больше 1 грузовика в обучении!")
			return false
		if type == "excavator" and excavators_count >= 1:
			print("[Tutorial] Нельзя купить больше 1 экскаватора в обучении!")
			return false
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
			
			trucks_bought_total += 1
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
			
			excavators_bought_total += 1
		return true
	return false


func add_to_factory_queue(weight: int, ore_type: String):
	factory_queue.append({
		"weight": weight,
		"ore_type": ore_type
	})
	factory_queue_weight += weight
	print("Добавлено ", weight, " кг ", ore_type, " в очередь фабрики. Всего в очереди: ", factory_queue_weight)


func _get_ore_from_dirt(dirt_type: String) -> String:
	var rock_type_id = -1
	for rock_id in rock_types:
		if rock_types[rock_id]["name"].to_lower() == dirt_type:
			rock_type_id = rock_id
			break
	if rock_type_id == -1:
		return "coal"
	var ore_table = rubble_ore_data.get(rock_type_id, rubble_ore_data[0])
	var roll = randf()
	var cumulative = 0.0
	for ore_id in ore_table:
		cumulative += ore_table[ore_id]
		if roll <= cumulative:
			return ore_id
	return ore_table.keys()[0]


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
			var dirt_type = factory_processing["ore_type"]
			var ore_type = _get_ore_from_dirt(dirt_type)
			var amount = 1 + randi_range(0, 2)
			storage[ore_type] += amount
			print("Переработано 10 кг ", dirt_type, " → получено ", amount, " ", ore_type)
			factory_processing = null


func start_new_game():
	reset_game()
	current_score = 0
	score_breakdown = {
		"walls_perfect": 0,
		"walls_good": 0,
		"walls_medium": 0,
		"levels_completed": 0,
		"time_bonus": 0,
		"money_bonus": 0
	}
	game_start_time = Time.get_ticks_msec() / 1000.0
	level_start_time = game_start_time
	levels_completed = 0
	print("=== НОВАЯ ИГРА ===")


func add_score(amount: int, reason: String):
	current_score += amount
	print("[SCORE] +", amount, " (", reason, ") → всего: ", current_score)
	emit_signal("score_changed", amount, reason)


func add_wall_score(accuracy: float):
	if is_tutorial:  
		return
	
	var diff_threshold = 1.0 - accuracy
	var points = 0
	var reason = ""
	if diff_threshold <= 0.01:  # ±10 Гц из 3000
		points = 500
		reason = "perfect wall"
		score_breakdown["walls_perfect"] += 1
	elif diff_threshold <= 0.025:  # ±25 Гц
		points = 300
		reason = "good wall"
		score_breakdown["walls_good"] += 1
	elif diff_threshold <= 0.05:  # ±50 Гц
		points = 100
		reason = "medium wall"
		score_breakdown["walls_medium"] += 1
	if points > 0:
		add_score(points, reason)


func complete_level():
	if is_tutorial: 
		return
	
	var elapsed = (Time.get_ticks_msec() / 1000.0) - level_start_time
	# Бонус за прохождение уровня
	add_score(1000, "level completed")
	score_breakdown["levels_completed"] += 1
	levels_completed += 1
	# Бонус за время
	var time_bonus = 0
	if elapsed < 300:  # меньше 5 минут
		time_bonus = 500 - int(elapsed * 10)
		time_bonus = max(time_bonus, 0)
	if time_bonus > 0:
		add_score(time_bonus, "time bonus")
		score_breakdown["time_bonus"] += time_bonus
	# Обновляем время начала следующего уровня
	level_start_time = Time.get_ticks_msec() / 1000.0


func calculate_final_score() -> int:
	if is_tutorial:  
		return 0
	
	# Бонус за оставшиеся деньги
	var money_bonus = int(money / 10.0)
	if money_bonus > 0:
		add_score(money_bonus, "money bonus")
		score_breakdown["money_bonus"] = money_bonus
	return current_score


func is_game_over() -> bool:
	# Если денег хватает на что угодно — игра не окончена
	var next_level = purchased_levels.size() + 1
	var level_price = 200 + (next_level - 1) * 100
	if money >= level_price:
		return false
	if money >= get_vehicle_price("truck") and vehicles["trucks"].size() < MAX_TRUCKS:
		return false
	if money >= get_vehicle_price("excavator") and vehicles["excavators"].size() < MAX_EXCAVATORS:
		return false
	
	# Если есть непройденные купленные уровни и есть техника — игра не окончена
	var completed = get_completed_levels()
	for level in purchased_levels:
		if not completed.has(level):
			# Есть непройденный уровень — проверяем, есть ли техника
			if vehicles["trucks"].size() > 0 and vehicles["excavators"].size() > 0:
				return false
	
	# Ничего нельзя сделать — игра окончена
	return true


func is_level_completed(level: int) -> bool:
	if not level_state.has(level):
		return false
	return level_state[level].get("completed", false)


func get_completed_levels() -> Array:
	var result = []
	for level in level_state:
		if level_state[level].get("completed", false):
			result.append(level)
	return result


func check_level_completion(level: int) -> bool:
	if not level_state.has(level):
		return false
	var data = level_state[level]
	var walls = data.get("walls", [])
	var rubbles = data.get("rubbles", [])
	if walls.is_empty() and rubbles.is_empty():
		if not data.get("completed", false):
			data["completed"] = true
			level_state[level] = data
			complete_level()
			print("[LEVEL] Уровень ", level, " пройден!")
			return true
	return false
