extends Panel


@onready var score_label = $ScoreLabel


var lifetime: float = 1.5
var fade_duration: float = 0.3
var timer: float = 0.0
var is_fading: bool = false


func setup(points: int) -> void:
	score_label.text = "+" + str(points)
	timer = 0.0
	is_fading = false
	modulate.a = 1.0
	visible = true


func _process(delta: float) -> void:
	if not visible:
		return
	
	timer += delta
	
	if timer >= lifetime and not is_fading:
		is_fading = true
		var tween = create_tween()
		tween.tween_property(self, "modulate:a", 0.0, fade_duration)
		tween.tween_callback(queue_free)
