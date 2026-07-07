extends CanvasLayer


var notification_scene = preload("res://scenes/uis/ScoreNotification.tscn")
var active_notifications: Array = []
var MAX_NOTIFICATIONS = 5
var SPACING = 10
var TOP_MARGIN = 280  
var RIGHT_MARGIN = 20


func _ready() -> void:
	layer = 200
	process_mode = Node.PROCESS_MODE_ALWAYS
	if Global.has_signal("score_changed"):
		Global.score_changed.connect(_on_score_changed)


func _on_score_changed(points: int, reason: String) -> void:
	_show_notification(points, reason)


func _show_notification(points: int, reason: String) -> void:
	if active_notifications.size() >= MAX_NOTIFICATIONS:
		var oldest = active_notifications[0]
		if is_instance_valid(oldest):
			oldest.queue_free()
		active_notifications.remove_at(0)
	
	var notification = notification_scene.instantiate()
	add_child(notification)
	notification.setup(points)
	active_notifications.append(notification)
	
	await get_tree().process_frame
	_update_positions()


func _update_positions() -> void:
	var viewport_size = get_viewport().get_visible_rect().size
	var y = TOP_MARGIN
	for notification in active_notifications:
		if is_instance_valid(notification):
			notification.position = Vector2(
				viewport_size.x - notification.size.x - RIGHT_MARGIN,
				y
			)
			y += notification.size.y + SPACING


func _process(_delta: float) -> void:
	var to_remove = []
	for i in range(active_notifications.size()):
		if not is_instance_valid(active_notifications[i]):
			to_remove.append(i)
	for i in to_remove:
		active_notifications.remove_at(i)
	if to_remove.size() > 0:
		_update_positions()
