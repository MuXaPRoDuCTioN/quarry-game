extends Node


signal digging_started(vehicle_id)
signal digging_completed(level, vehicle_id, rubble_cell)
signal digging_progress(vehicle_id, progress, cell)


var is_digging = false
var current_target = null
var rubble_tile_map: TileMapLayer
var current_level: int
var DIGGING_SPEED = 5.0
var progress_bar: ProgressBar = null


func setup(rubble_map: TileMapLayer, level: int):
	rubble_tile_map = rubble_map
	current_level = level
	
	progress_bar = ProgressBar.new()
	progress_bar.min_value = 0
	progress_bar.max_value = 100
	progress_bar.value = 0
	progress_bar.size = Vector2(60, 12)
	progress_bar.visible = false
	progress_bar.z_index = 25
	add_child(progress_bar)


func _process(delta: float) -> void:
	if not is_digging or current_target == null:
		if progress_bar:
			progress_bar.visible = false
		return
	
	var rubble_exists = false
	var actual_rubble_index = -1
	for i in range(Global.rubbles.size()):
		if Global.rubbles[i]["cell"] == current_target["rubble_cell"]:
			rubble_exists = true
			actual_rubble_index = i
			break
	
	if not rubble_exists:
		print("Куча больше не существует!")
		stop_digging()
		return
	
	if current_target["rubble_index"] != actual_rubble_index:
		current_target["rubble_index"] = actual_rubble_index
	
	current_target["progress"] += delta * DIGGING_SPEED
	
	var cell = get_excavator_cell(current_target["vehicle_id"])
	if cell != null and progress_bar:
		progress_bar.position = Vector2(cell.x * 64 + 2, cell.y * 64 - 20)
		progress_bar.visible = true
		progress_bar.value = (current_target["progress"] / 10.0) * 100
	
	emit_signal("digging_progress", current_target["vehicle_id"], current_target["progress"] / 10.0, cell)
	
	if current_target["progress"] >= 10.0:
		var rubble = Global.rubbles[current_target["rubble_index"]]
		rubble["remaining"] -= 10
		print("Отнято 10 кг от кучи. Осталось: ", rubble["remaining"])
		
		var vehicle_id = current_target["vehicle_id"]
		var rubble_cell = current_target["rubble_cell"]
		var level_to_update = current_level
		
		if rubble["remaining"] <= 0:
			_remove_rubble_from_level(level_to_update, rubble_cell)
			Global.rubbles.remove_at(current_target["rubble_index"])
			print("Куча исчерпана и удалена! Осталось куч: ", Global.rubbles.size())
		
		_set_excavator_full(vehicle_id, 10)
		
		emit_signal("digging_completed", level_to_update, vehicle_id, rubble_cell)
		stop_digging()


func get_excavator_cell(vehicle_id: int):
	var level_data = Global.level_state[current_level]
	for ex in level_data.get("excavators", []):
		if ex["id"] == vehicle_id:
			return Vector2i(ex["cell"][0], ex["cell"][1])
	return null


func _set_excavator_full(vehicle_id: int, amount: int):
	for ex in Global.vehicles["excavators"]:
		if ex["id"] == vehicle_id:
			ex["is_full"] = true
			ex["ore_amount"] = amount
			ex["status"] = "idle"
			print("Экскаватор #", vehicle_id, " полный! (", amount, " кг земли)")
			break


func _remove_rubble_from_level(level: int, cell: Vector2i):
	if Global.level_state.has(level):
		var level_data = Global.level_state[level]
		var new_rubbles = []
		for rubble_cell in level_data["rubbles"]:
			if rubble_cell != cell:
				new_rubbles.append(rubble_cell)
		level_data["rubbles"] = new_rubbles


func start_digging(vehicle_id: int, rubble_cell: Vector2i):
	if is_digging:
		print("Уже копаем!")
		return
	
	for ex in Global.vehicles["excavators"]:
		if ex["id"] == vehicle_id:
			if ex["is_full"]:
				print("Экскаватор полный! Сначала разгрузите его в грузовик.")
				return
			break
	
	var rubble_index = -1
	for i in range(Global.rubbles.size()):
		if Global.rubbles[i]["cell"] == rubble_cell:
			rubble_index = i
			break
	
	if rubble_index == -1:
		print("Куча не найдена!")
		return
	
	var level_data = Global.level_state[current_level]
	var rubble_in_level = false
	for cell in level_data["rubbles"]:
		if cell == rubble_cell:
			rubble_in_level = true
			break
	
	if not rubble_in_level:
		print("Куча не найдена в данных уровня!")
		return
	
	for ex in Global.vehicles["excavators"]:
		if ex["id"] == vehicle_id:
			ex["status"] = "working"
			break
	
	is_digging = true
	current_target = {
		"vehicle_id": vehicle_id,
		"rubble_index": rubble_index,
		"rubble_cell": rubble_cell,
		"progress": 0.0
	}
	
	print("Экскаватор #", vehicle_id, " начал копать")
	emit_signal("digging_started", vehicle_id)


func stop_digging():
	if is_digging and current_target != null:
		for ex in Global.vehicles["excavators"]:
			if ex["id"] == current_target["vehicle_id"]:
				ex["status"] = "idle"
				break
	
	is_digging = false
	current_target = null
	if progress_bar:
		progress_bar.visible = false


func is_busy() -> bool:
	return is_digging
