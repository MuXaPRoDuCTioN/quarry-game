extends Node2D


var LevelButtonsGenerator = preload("res://scripts/quarry/QuarryMap/LevelButtonsGenerator.gd")
var generator


var BuyVehicleWindow = preload("res://scenes/uis/BuyVehicleWindow.tscn")
var buy_veh_window_instance
var VehicleManagementWindow = preload("res://scenes/uis/VehicleManagementWindow.tscn")
var veh_man_window_instance


@onready var factory_progress_bar = $CanvasLayer/FactoryProgressBar
@onready var factory_label = $CanvasLayer/FactoryLabel


func _ready():
	# Проверяем флаг новой игры
	if Global.is_new_game:
		# Сбрасываем деньги (уже сброшены в reset_game)
		# Но оставляем для совместимости
		if Global.money == 0:
			Global.money = 1000
		Global.purchased_levels.clear()
		Global.is_new_game = false
		
	generator = LevelButtonsGenerator.new()
	generator.level_pressed.connect(_on_level_pressed)
	generator.generate($LevelsContainer, 10)
	generator.update_buttons()
	
	update_ui()


func _process(delta: float) -> void:
	update_factory_ui()
	Global.process_factory(delta)


func update_factory_ui():
	if factory_progress_bar == null:
		return
	
	if Global.factory_processing != null:
		var progress = Global.factory_processing.get("progress", 0.0) / Global.factory_processing.get("weight", 1.0)
		factory_progress_bar.value = clamp(progress * 100, 0, 100)
	else:
		factory_progress_bar.value = 0
	
	var total_remaining = Global.factory_queue_weight
	if Global.factory_processing != null:
		total_remaining += Global.factory_processing.get("weight", 0)
	
	if total_remaining > 0:
		factory_label.text = "Осталось " + str(total_remaining) + " кг"
	else:
		factory_label.text = "Ожидание"


func _on_level_pressed(level_num):
	if Global.purchased_levels.has(level_num):
		Global.current_level = level_num
		get_tree().change_scene_to_file("res://scenes/quarry/QuarryLevel.tscn")
	else:
		if generator.get_level_price(level_num) <= Global.money:
			Global.money -= generator.get_level_price(level_num)
			Global.purchased_levels[level_num] = generator.level_buttons[level_num]
			update_ui()
			generator.update_buttons()
			generator.update_text(level_num)
		else:
			print("Недостаточно средств!")


func update_ui():
	$CanvasLayer/MoneyLabel.text = "Деньги: " + str(Global.money)


func _on_buy_menu_pressed() -> void:
	open_buy_vehicle_window()


func open_buy_vehicle_window():
	buy_veh_window_instance = BuyVehicleWindow.instantiate()
	$CanvasLayer/PopupContainer.add_child(buy_veh_window_instance)
	buy_veh_window_instance.connect("update_ui", update_ui)


func _on_vehicle_menu_pressed() -> void:
	open_veh_man_window()


func open_veh_man_window():
	veh_man_window_instance = VehicleManagementWindow.instantiate()
	$CanvasLayer/PopupContainer.add_child(veh_man_window_instance)
