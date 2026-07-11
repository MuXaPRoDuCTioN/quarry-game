class_name WaveAnimation
extends Node2D

signal animation_finished(result: Dictionary)

var wave_polygons: Array = []
var intersection_points: Array = []
var generators_data: Array = []
var wall_targets: Dictionary = {}
var destroyed_walls: Array = []
var current_step: int = 0
var max_steps: int = 20
var wall_map: TileMapLayer = null
var floor_map: TileMapLayer = null
var level_size: Vector2i = Vector2i(20, 20)


# Реальные частоты стен (из Global.level_state) - у каждой стены СВОЯ
# собственная резонансная частота, как у любого физического объекта в жизни
var real_wall_frequencies: Dictionary = {}

# ===== Физика резонанса =====
# Вместо мгновенного разрушения по попаданию - стена накапливает
# "резонансное напряжение" каждый кадр анимации, пока по ней бьёт волна
# подходящей частоты. Чем ближе частота генератора к собственной частоте
# стены - тем сильнее отклик (колоколообразная кривая, как добротность
# резонатора в реальной физике). Несколько генераторов ОДНОЙ частоты,
# бьющих в одну точку, складывают свои отклики (конструктивная
# интерференция амплитуд) - отсюда и ускоренное разрушение при совместной
# работе, без всякого "сложения частот".
var wall_stress: Dictionary = {}       # cell -> накопленное напряжение (0..1+)
var wall_best_freq: Dictionary = {}    # cell -> частота лучшего попадания (для итоговой оценки точности)
var wall_indicators: Dictionary = {}   # cell -> Sprite2D индикатор накопления
var break_effects: Array = []          # временные "вспышки" в момент разрушения


func setup(generators: Array, targets: Dictionary):
	generators_data = generators
	wall_targets = targets
	destroyed_walls = []
	current_step = 0
	wall_stress.clear()
	wall_best_freq.clear()
	wall_indicators.clear()
	break_effects.clear()

	var level = get_tree().current_scene
	wall_map = level.wall_tile_map
	floor_map = level.floor_tile_map

	var generator = load("res://scripts/quarry/QuarryLevel/QuarryGenerator.gd").new()
	level_size = generator.get_level_size(Global.current_level)

	# Получаем РЕАЛЬНЫЕ частоты стен
	var level_data = Global.level_state.get(Global.current_level, {})
	real_wall_frequencies = level_data.get("wall_frequencies", {}).duplicate()
	print("[WaveAnimation] Реальные частоты стен: ", real_wall_frequencies)
	print("[WaveAnimation] Цели игрока (wall_targets): ", wall_targets)

	create_wave_visuals()


func create_wave_visuals():
	for i in range(generators_data.size()):
		var gen = generators_data[i]
		var polygon = Polygon2D.new()
		polygon.color = Color(0, 0.8, 1, 0.3)
		polygon.z_index = 20
		add_child(polygon)
		var cone_data = get_cone_cells_with_walls(gen.cell, gen.direction)
		wave_polygons.append({
			"polygon": polygon,
			"cone_cells": cone_data.all_cells,
			"rays": cone_data.rays,
			"gen_cell": gen.cell,
			"direction": gen.direction,
			"current_length": 0
		})


func get_cone_cells_with_walls(start: Vector2i, direction: int) -> Dictionary:
	var all_cells = []
	var rays = []  # Array лучей, каждый - Array[Vector2i] от ближней к дальней клетке
	var max_distance = 20
	var angle_deg = 30.0
	var base_angle = 0.0
	match direction:
		0: base_angle = -90.0
		1: base_angle = 0.0
		2: base_angle = 90.0
		3: base_angle = 180.0
	for angle_offset in range(-int(angle_deg/2), int(angle_deg/2) + 1, 2):
		var ray_cells = []
		for dist in range(1, max_distance + 1):
			var angle = deg_to_rad(base_angle + angle_offset)
			var dir_vec = Vector2(cos(angle), sin(angle))
			var offset = Vector2i(round(dir_vec.x * dist), round(dir_vec.y * dist))
			var cell = start + offset
			if cell.x < 1 or cell.x >= level_size.x - 1 or cell.y < 1 or cell.y >= level_size.y - 1:
				break
			if is_wall_at(cell):
				if not ray_cells.has(cell):
					ray_cells.append(cell)
				break
			if not is_floor_at(cell):
				break
			if not ray_cells.has(cell):
				ray_cells.append(cell)
		if not ray_cells.is_empty():
			rays.append(ray_cells)
		for cell in ray_cells:
			if not all_cells.has(cell):
				all_cells.append(cell)
	return {"all_cells": all_cells, "rays": rays}


func is_wall_at(cell: Vector2i) -> bool:
	if wall_map == null:
		return false
	return wall_map.get_cell_source_id(cell) != -1


func is_floor_at(cell: Vector2i) -> bool:
	if floor_map == null:
		return false
	return floor_map.get_cell_source_id(cell) != -1


func start_animation():
	current_step = 0
	_process_animation_step()


func _process_animation_step():
	if current_step >= max_steps:
		finish_animation()
		return
	for wave_data in wave_polygons:
		var polygon = wave_data.polygon
		var start_cell = wave_data.gen_cell
		
		# Строим веер: генератор -> кончик первого луча -> ... -> кончик последнего.
		# Лучи уже идут в правильном угловом порядке (от -15° до +15° смещения),
		# поэтому пересортировка по atan2 не нужна - именно она и ломала "влево"
		# (разрыв диапазона atan2 на ±180°) и давала кривую заливку для "вверх"/"вниз".
		var points = []
		points.append(start_cell * 64 + Vector2i(32, 32))
		for ray in wave_data.rays:
			var visible_cell = null
			for cell in ray:
				var dist = abs(cell.x - start_cell.x) + abs(cell.y - start_cell.y)
				if dist <= current_step:
					visible_cell = cell
				else:
					break
			if visible_cell != null:
				points.append(visible_cell * 64 + Vector2i(32, 32))
		
		polygon.polygon = points if points.size() > 2 else []
		update_resonance_at_step(current_step)
	current_step += 1
	var timer = get_tree().create_timer(0.08)
	timer.timeout.connect(_process_animation_step)


func resonance_response(freq: float, target_freq: float) -> float:
	var diff = freq - target_freq
	var sigma = 35.0  # используем значение по умолчанию
	return exp(-(diff * diff) / (2.0 * sigma * sigma))


func resonance_response_with_sigma(freq: float, target_freq: float, sigma: float) -> float:
	var diff = freq - target_freq
	return exp(-(diff * diff) / (2.0 * sigma * sigma))


func update_resonance_at_step(step: int) -> void:
	var touched_cells: Dictionary = {}
	
	# Получаем wall_tiles один раз, чтобы не дёргать каждый кадр
	var level_data = Global.level_state.get(Global.current_level, {})
	var wall_tiles = level_data.get("wall_tiles", {})
	
	# Базовая мощность генератора (вместо старой константы STRESS_PER_STEP)
	var base_power = 0.10
	
	for i in range(generators_data.size()):
		var gen = generators_data[i]
		if gen.frequency == 0:
			continue
		var cells = get_cells_up_to_step(wave_polygons[i].cone_cells, gen.cell, step)
		for cell in cells:
			if not real_wall_frequencies.has(cell) or _is_wall_destroyed(cell):
				continue
			if not is_wall_at(cell):
				continue
			touched_cells[cell] = true
			var target_freq = real_wall_frequencies[cell]
			
			# <<< НОВОЕ: берём параметры породы этой конкретной стены
			var rock_id = wall_tiles.get(cell, 0)
			var rock = Global.rock_types.get(rock_id, Global.rock_types[0])
			var tolerance = rock.get("frequency_tolerance", 35.0)
			var damping = rock.get("damping", 0.03)
			var sigma = tolerance / 2.355  # FWHM → sigma гауссианы
			
			# Гауссов отклик с учётом породы
			var response = resonance_response_with_sigma(gen.frequency, target_freq, sigma)
			wall_stress[cell] = wall_stress.get(cell, 0.0) + response * base_power
			
			if not wall_best_freq.has(cell) or response > resonance_response_with_sigma(wall_best_freq[cell], target_freq, sigma):
				wall_best_freq[cell] = gen.frequency
	
	# Затухание — тоже зависит от породы
	for cell in wall_stress.keys():
		if not touched_cells.has(cell) and not _is_wall_destroyed(cell):
			var rock_id = wall_tiles.get(cell, 0)
			var rock = Global.rock_types.get(rock_id, Global.rock_types[0])
			var damping = rock.get("damping", 0.03)
			wall_stress[cell] = max(0.0, wall_stress[cell] - damping)
	
	# Проверка разрушения — порог тоже от породы
	for cell in wall_stress.keys():
		if _is_wall_destroyed(cell):
			continue
		update_resonance_indicator(cell)
		var rock_id = wall_tiles.get(cell, 0)
		var rock = Global.rock_types.get(rock_id, Global.rock_types[0])
		var threshold = rock.get("stress_threshold", 1.0)
		if wall_stress[cell] >= threshold:
			var freq = wall_best_freq.get(cell, real_wall_frequencies.get(cell, 0))
			destroyed_walls.append({"cell": cell, "frequency": freq, "accuracy": 1.0})
			trigger_break_effect(cell)


func _is_wall_destroyed(cell: Vector2i) -> bool:
	for wall in destroyed_walls:
		if wall.cell == cell:
			return true
	return false


func make_resonance_sprite() -> Sprite2D:
	var circle = Sprite2D.new()
	circle.centered = true
	circle.z_index = 22
	var size = 56
	var image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	
	for x in range(size):
		for y in range(size):
			var dx = x - size / 2
			var dy = y - size / 2
			var dist = sqrt(dx * dx + dy * dy)
			if dist < size / 2:
				var alpha = 1.0 - (dist / (size / 2))
				image.set_pixel(x, y, Color(1, 1, 1, alpha))
	
	for x in range(size):
		for y in range(size):
			var dx = x - size / 2
			var dy = y - size / 2
			var dist = sqrt(dx * dx + dy * dy)
			if dist > size / 2 - 3 and dist < size / 2:
				image.set_pixel(x, y, Color(1, 1, 1, 0.9))
	
	var texture = ImageTexture.create_from_image(image)
	circle.texture = texture
	return circle


func update_resonance_indicator(cell: Vector2i) -> void:
	var stress = clamp(wall_stress.get(cell, 0.0), 0.0, 1.0)
	
	if not wall_indicators.has(cell):
		if stress < 0.05:
			return  # пока почти ничего не накопилось - индикатор ещё не нужен
		var sprite = make_resonance_sprite()
		sprite.position = cell * 64 + Vector2i(32, 32)
		sprite.scale = Vector2.ONE * 0.3
		add_child(sprite)
		wall_indicators[cell] = sprite
	
	var sprite = wall_indicators[cell]
	if not is_instance_valid(sprite):
		wall_indicators.erase(cell)
		return
	
	# Растёт и "созревает" по мере накопления напряжения: от тускло-жёлтого
	# (только начали раскачивать) до яркого зелёного (почти разрушение)
	sprite.scale = Vector2.ONE * lerp(0.3, 1.0, stress)
	sprite.modulate = Color(1.0 - stress * 0.5, 0.85 + stress * 0.15, 0.25 + stress * 0.35, 0.3 + stress * 0.6)


func trigger_break_effect(cell: Vector2i) -> void:
	var sprite = wall_indicators.get(cell, null)
	if sprite == null or not is_instance_valid(sprite):
		sprite = make_resonance_sprite()
		sprite.position = cell * 64 + Vector2i(32, 32)
		add_child(sprite)
	wall_indicators.erase(cell)
	
	sprite.modulate = Color(0.5, 1.0, 0.5, 1.0)
	
	var tween = create_tween()
	tween.set_parallel(true)
	var effect_data = {"sprite": sprite, "tween": tween}
	break_effects.append(effect_data)
	
	tween.tween_method(
		func(scale):
			if is_instance_valid(sprite):
				sprite.scale = Vector2(scale, scale),
		sprite.scale.x, 2.0, 0.3
	)
	tween.tween_method(
		func(alpha):
			if is_instance_valid(sprite):
				sprite.modulate.a = alpha,
		1.0, 0.0, 0.35
	)
	tween.chain().tween_callback(func():
		if is_instance_valid(sprite):
			sprite.queue_free()
		var idx = break_effects.find(effect_data)
		if idx != -1:
			break_effects.remove_at(idx)
	)


func get_cells_up_to_step(cone_cells: Array, gen_cell: Vector2i, step: int) -> Array:
	var cells = []
	for cell in cone_cells:
		var dist = abs(cell.x - gen_cell.x) + abs(cell.y - gen_cell.y)
		if dist <= step:
			cells.append(cell)
	return cells


func finish_animation():
	var result = {
		"destroyed_walls": destroyed_walls
	}
	await get_tree().create_timer(1.4).timeout
	clear_visuals()
	emit_signal("animation_finished", result)


func clear_visuals():
	for wave_data in wave_polygons:
		if is_instance_valid(wave_data.polygon):
			wave_data.polygon.queue_free()
	wave_polygons.clear()
	
	for cell in wall_indicators:
		var sprite = wall_indicators[cell]
		if is_instance_valid(sprite):
			sprite.queue_free()
	wall_indicators.clear()
	
	for effect in break_effects:
		if effect.has("tween") and effect.tween:
			effect.tween.kill()
		if is_instance_valid(effect.sprite):
			effect.sprite.queue_free()
	break_effects.clear()
	
	for marker in intersection_points:
		if is_instance_valid(marker):
			marker.queue_free()
	intersection_points.clear()
	
	queue_free()
