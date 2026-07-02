extends Camera2D


var LevelGenerator = preload("res://scripts/quarry/QuarryLevel/QuarryGenerator.gd")
var generator


var is_dragging = false
var drag_start = Vector2()
var camera_limits = Rect2()
var level_size
var tile_size = 64


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	generator = LevelGenerator.new()
	level_size = generator.get_level_size(Global.current_level)
	
	setup_camera_limits()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				is_dragging = true
				drag_start = get_global_mouse_position()
			else:
				is_dragging = false
	
	if event is InputEventMouseMotion and is_dragging:
		var mouse_pos = get_global_mouse_position()
		var delta = mouse_pos - drag_start
		
		position -= delta * 0.5
		clamp_camera_position()
		
		drag_start = mouse_pos


func setup_camera_limits():
	camera_limits = Rect2(0, 0, level_size.x * tile_size, level_size.y * tile_size)


func clamp_camera_position():
	var pos = position
	
	pos.x = clamp(pos.x, 0, level_size.x * tile_size)
	pos.y = clamp(pos.y, 0, level_size.y * tile_size)
	
	position = pos
