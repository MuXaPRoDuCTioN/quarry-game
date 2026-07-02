extends Camera2D


var camera_speed = 30.0
var min_y = 324.0
var max_y = 700.0


func _input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			position.y -= camera_speed
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			position.y += camera_speed
		
		position.y = clamp(position.y, min_y, max_y)
