class_name FrequencyGenerator
extends Node2D


signal generator_placed(generator_id: int, cell: Vector2i, direction: int)
signal generator_destroyed(generator_id: int)


var generator_id: int
var cell: Vector2i
var frequency: int = 250
var direction: int = 0
var is_placed: bool = false
var sprite: Sprite2D
var direction_indicator: Sprite2D


func _ready():
	sprite = Sprite2D.new()
	sprite.texture = load("res://assets/textures/icons/generator.png")
	sprite.centered = true
	sprite.position = cell * 64 + Vector2i(32, 32)
	add_child(sprite)
	
	direction_indicator = Sprite2D.new()
	direction_indicator.centered = true
	var arrow_image = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	arrow_image.fill(Color.YELLOW)
	var arrow_texture = ImageTexture.create_from_image(arrow_image)
	direction_indicator.texture = arrow_texture
	update_direction_indicator()
	add_child(direction_indicator)


func update_direction_indicator():
	if direction_indicator == null:
		return
	match direction:
		0:
			direction_indicator.position = cell * 64 + Vector2i(32, -16)
			direction_indicator.rotation = 0
		1:
			direction_indicator.position = cell * 64 + Vector2i(80, 32)
			direction_indicator.rotation = deg_to_rad(90)
		2:
			direction_indicator.position = cell * 64 + Vector2i(32, 80)
			direction_indicator.rotation = deg_to_rad(180)
		3:
			direction_indicator.position = cell * 64 + Vector2i(-16, 32)
			direction_indicator.rotation = deg_to_rad(270)


func set_frequency(freq: int):
	frequency = clamp(freq, 10, 500)


func set_direction(dir: int):
	direction = dir
	update_direction_indicator()


func get_wave_intersection(other_generator: FrequencyGenerator) -> Array:
	var intersection = []
	var start1 = cell
	var start2 = other_generator.cell
	var dir1 = direction
	var dir2 = other_generator.direction
	
	var ray1 = get_ray_cells(start1, dir1)
	var ray2 = get_ray_cells(start2, dir2)
	
	for cell1 in ray1:
		for cell2 in ray2:
			if cell1 == cell2:
				intersection.append(cell1)
	
	return intersection


func get_ray_cells(start: Vector2i, dir: int) -> Array:
	var cells = []
	var pos = start
	var max_distance = 10
	
	for i in range(1, max_distance + 1):
		match dir:
			0: pos = start + Vector2i(0, -i)
			1: pos = start + Vector2i(i, 0)
			2: pos = start + Vector2i(0, i)
			3: pos = start + Vector2i(-i, 0)
		cells.append(pos)
	
	return cells


func destroy():
	emit_signal("generator_destroyed", generator_id)
	queue_free()
