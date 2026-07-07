class_name WaveAnimation
extends Node2D

signal animation_finished(result: Dictionary)

var wave_polygons: Array = []
var intersection_points: Array = []
var resonance_effects: Array = []
var triggered_pairs: Array = []
var generators_data: Array = []
var wall_targets: Dictionary = {}
var destroyed_walls: Array = []
var current_step: int = 0
var max_steps: int = 20
var wall_map: TileMapLayer = null
var floor_map: TileMapLayer = null
var level_size: Vector2i = Vector2i(20, 20)


# Реальные частоты стен (из Global.level_state)
var real_wall_frequencies: Dictionary = {}


# Порог совпадения частоты — должен совпадать с порогом в WallDestructionSystem
const FREQ_TOLERANCE: int = 50


func setup(generators: Array, targets: Dictionary):
	generators_data = generators
	wall_targets = targets
	destroyed_walls = []
	current_step = 0
	resonance_effects.clear()
	triggered_pairs.clear()

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
		var cone_cells = get_cone_cells_with_walls(gen.cell, gen.direction)
		wave_polygons.append({
			"polygon": polygon,
			"cone_cells": cone_cells,
			"gen_cell": gen.cell,
			"direction": gen.direction,
			"current_length": 0
		})


func get_cone_cells_with_walls(start: Vector2i, direction: int) -> Array:
	var all_cells = []
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
		var hit_wall = false
		for dist in range(1, max_distance + 1):
			var angle = deg_to_rad(base_angle + angle_offset)
			var dir_vec = Vector2(cos(angle), sin(angle))
			var offset = Vector2i(round(dir_vec.x * dist), round(dir_vec.y * dist))
			var cell = start + offset
			if cell.x < 1 or cell.x >= level_size.x - 1 or cell.y < 1 or cell.y >= level_size.y - 1:
				hit_wall = true
				break
			if is_wall_at(cell):
				hit_wall = true
				if not ray_cells.has(cell):
					ray_cells.append(cell)
				break
			if not is_floor_at(cell):
				hit_wall = true
				break
			if not ray_cells.has(cell):
				ray_cells.append(cell)
		for cell in ray_cells:
			if not all_cells.has(cell):
				all_cells.append(cell)
	return all_cells


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
		var cone_cells = wave_data.cone_cells
		var start_cell = wave_data.gen_cell
		var cells_up_to_step = []
		for cell in cone_cells:
			var dist = abs(cell.x - start_cell.x) + abs(cell.y - start_cell.y)
			if dist <= current_step:
				cells_up_to_step.append(cell)
		var points = []
		if cells_up_to_step.size() > 0:
			var sorted_cells = sort_cells_for_polygon(cells_up_to_step, start_cell)
			for cell in sorted_cells:
				points.append(cell * 64 + Vector2i(32, 32))
			if points.size() > 0:
				points.append(points[0])
		polygon.polygon = points
		check_intersections_at_step(current_step)
	current_step += 1
	var timer = get_tree().create_timer(0.08)
	timer.timeout.connect(_process_animation_step)


func sort_cells_for_polygon(cells: Array, start: Vector2i) -> Array:
	if cells.size() <= 1:
		return cells
	var center = Vector2(start.x + 0.5, start.y + 0.5)
	cells.sort_custom(func(a, b):
		var angle_a = atan2(a.y - center.y, a.x - center.x)
		var angle_b = atan2(b.y - center.y, b.x - center.x)
		return angle_a < angle_b
	)
	return cells


func check_intersections_at_step(step: int):
	var pair_overlaps: Array = []
	for i in range(generators_data.size()):
		for j in range(i + 1, generators_data.size()):
			var pair_key = str(i) + "_" + str(j)
			var gen1 = generators_data[i]
			var gen2 = generators_data[j]
			if gen1.frequency == 0 or gen2.frequency == 0:
				continue
			var cells1 = get_cells_up_to_step(wave_polygons[i].cone_cells, gen1.cell, step)
			var cells2 = get_cells_up_to_step(wave_polygons[j].cone_cells, gen2.cell, step)
			var overlap = []
			for cell1 in cells1:
				if cells2.has(cell1):
					overlap.append(cell1)
			if overlap.is_empty():
				continue
			# МЕХАНИКА НЕ МЕНЯЕТСЯ: combined_freq = сумма частот
			var combined_freq = gen1.frequency + gen2.frequency
			pair_overlaps.append({"key": pair_key, "cells": overlap, "freq": combined_freq})
			if not triggered_pairs.has(pair_key):
				triggered_pairs.append(pair_key)
				var geo = compute_zone_geometry(overlap)
				# Сравниваем с РЕАЛЬНОЙ частотой стены
				var is_target = zone_has_target(overlap, combined_freq)
				create_resonance_effect(geo.center_px, geo.extent_cells, is_target, 1)
			# Собираем стены для разрушения — сравниваем с РЕАЛЬНОЙ частотой
			for cell in overlap:
				if real_wall_frequencies.has(cell):
					var real_freq = real_wall_frequencies[cell]
					if abs(combined_freq - real_freq) <= FREQ_TOLERANCE:
						var already_destroyed = false
						for wall in destroyed_walls:
							if wall.cell == cell:
								already_destroyed = true
								break
						if not already_destroyed:
							destroyed_walls.append({
								"cell": cell,
								"frequency": combined_freq,
								"accuracy": 1.0
							})
	# Супер-резонанс
	for a in range(pair_overlaps.size()):
		for b in range(a + 1, pair_overlaps.size()):
			var zone_a = pair_overlaps[a]
			var zone_b = pair_overlaps[b]
			var meta_key = "meta_" + zone_a.key + "_" + zone_b.key
			if triggered_pairs.has(meta_key):
				continue
			var meta_overlap = []
			for cell in zone_a.cells:
				if zone_b.cells.has(cell):
					meta_overlap.append(cell)
			if meta_overlap.is_empty():
				continue
			triggered_pairs.append(meta_key)
			# МЕХАНИКА НЕ МЕНЯЕТСЯ: meta_freq = (a+b)*3
			var meta_freq = (zone_a.freq + zone_b.freq) * 3.0
			var geo = compute_zone_geometry(meta_overlap)
			var is_target = zone_has_target(meta_overlap, meta_freq)
			create_resonance_effect(geo.center_px, geo.extent_cells, is_target, 2)
			for cell in meta_overlap:
				if real_wall_frequencies.has(cell):
					var real_freq = real_wall_frequencies[cell]
					if abs(meta_freq - real_freq) <= FREQ_TOLERANCE:
						var already_destroyed = false
						for wall in destroyed_walls:
							if wall.cell == cell:
								already_destroyed = true
								break
						if not already_destroyed:
							destroyed_walls.append({
								"cell": cell,
								"frequency": meta_freq,
								"accuracy": 1.0
							})


func compute_zone_geometry(cells: Array) -> Dictionary:
	var min_x = cells[0].x
	var max_x = cells[0].x
	var min_y = cells[0].y
	var max_y = cells[0].y
	var sum_x = 0
	var sum_y = 0
	for cell in cells:
		min_x = min(min_x, cell.x)
		max_x = max(max_x, cell.x)
		min_y = min(min_y, cell.y)
		max_y = max(max_y, cell.y)
		sum_x += cell.x
		sum_y += cell.y
	var center_px = Vector2(
		(float(sum_x) / cells.size() + 0.5) * 64.0,
		(float(sum_y) / cells.size() + 0.5) * 64.0
	)
	var extent_cells = max(max_x - min_x + 1, max_y - min_y + 1)
	return {"center_px": center_px, "extent_cells": extent_cells}


# Сравниваем с РЕАЛЬНОЙ частотой стены
func zone_has_target(cells: Array, freq: float) -> bool:
	for cell in cells:
		if real_wall_frequencies.has(cell):
			var real_freq = real_wall_frequencies[cell]
			if abs(freq - real_freq) <= FREQ_TOLERANCE:
				return true
	return false


func try_destroy_walls_in_zone(cells: Array, freq: float) -> void:
	for cell in cells:
		if not real_wall_frequencies.has(cell):
			continue
		var real_freq = real_wall_frequencies[cell]
		if abs(freq - real_freq) > FREQ_TOLERANCE:
			continue
		var already_destroyed = false
		for wall in destroyed_walls:
			if wall.cell == cell:
				already_destroyed = true
				break
		if not already_destroyed:
			destroyed_walls.append({
				"cell": cell,
				"frequency": freq,
				"accuracy": 1.0
			})


func create_resonance_effect(center_px: Vector2, extent_cells: int, is_target: bool, resonance_level: int = 1):
	var circle = Sprite2D.new()
	circle.centered = true
	circle.z_index = 22 if resonance_level < 2 else 23
	var size = 56
	var image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var color
	if resonance_level >= 2:
		color = Color(1, 0.1, 0.9, 0.95) if is_target else Color(1, 0, 0.2, 0.75)
	else:
		color = Color(1, 1, 0, 0.9) if is_target else Color(1, 0.5, 0, 0.7)
	for x in range(size):
		for y in range(size):
			var dx = x - size/2
			var dy = y - size/2
			var dist = sqrt(dx*dx + dy*dy)
			if dist < size/2:
				var alpha = 1.0 - (dist / (size/2))
				image.set_pixel(x, y, Color(color.r, color.g, color.b, color.a * alpha))
	for x in range(size):
		for y in range(size):
			var dx = x - size/2
			var dy = y - size/2
			var dist = sqrt(dx*dx + dy*dy)
			if dist > size/2 - 3 and dist < size/2:
				image.set_pixel(x, y, Color(1, 1, 1, 0.9))
	var texture = ImageTexture.create_from_image(image)
	circle.texture = texture
	circle.position = center_px
	add_child(circle)
	var target_diameter_px = max(extent_cells * 64.0 * 1.25, 90.0)
	var max_scale = target_diameter_px / float(size)
	var effect_data = {
		"circle": circle,
		"max_scale": max_scale,
		"timer": 0.0,
		"max_timer": 1.25,
		"is_target": is_target
	}
	resonance_effects.append(effect_data)
	animate_resonance_effect(effect_data)


func animate_resonance_effect(effect_data: Dictionary):
	var circle = effect_data.circle
	var max_scale = effect_data.max_scale
	var start_scale = max_scale * 0.3
	var grow_duration = 0.25
	var hold_duration = 0.6
	var fade_duration = 0.4
	var tween = create_tween()
	effect_data["tween"] = tween
	tween.tween_method(
		func(scale):
			if is_instance_valid(circle):
				circle.scale = Vector2(scale, scale),
		start_scale, max_scale, grow_duration
	)
	tween.tween_interval(hold_duration)
	tween.tween_method(
		func(alpha):
			if is_instance_valid(circle):
				circle.modulate.a = alpha,
		1.0, 0.0, fade_duration
	)
	tween.tween_callback(func():
		if is_instance_valid(circle):
			circle.queue_free()
		var idx = resonance_effects.find(effect_data)
		if idx != -1:
			resonance_effects.remove_at(idx)
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
	for effect in resonance_effects:
		if effect.has("tween") and effect.tween:
			effect.tween.kill()
		if is_instance_valid(effect.circle):
			effect.circle.queue_free()
	resonance_effects.clear()
	for marker in intersection_points:
		if is_instance_valid(marker):
			marker.queue_free()
	intersection_points.clear()
	queue_free()
