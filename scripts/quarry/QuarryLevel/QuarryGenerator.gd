extends Node


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func generate(level_num):
	var data = {
		"floor": [],
		"border": [],
		"walls": [],
		"rubbles": [],
		"trucks": [],
		"excavators": []
	}
	
	var size = get_level_size(level_num)
	
	for x in range(size.x):
		for y in range(size.y):
			data["floor"].append(Vector2i(x, y))
			
			if x == 0 or y == 0 or x == size.x - 1 or y == size.y - 1:
				data["border"].append(Vector2i(x, y))
			
			if (y >= 1 and y < size.y - 1) and (x >= 3 and x < size.x - 1):
				data["walls"].append(Vector2i(x, y))
	
	Global.level_state[level_num] = data
	
	return data


func get_level_size(level_num):
	return Vector2(12 + level_num * 2, 6 + level_num)
