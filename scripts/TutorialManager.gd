extends Node


signal tutorial_step_changed(step: int)
signal tutorial_finished


var is_active: bool = false
var current_step: int = 0
var tutorial_window: Panel = null
var tutorial_layer: CanvasLayer = null
var tutorial_window_scene = preload("res://scenes/uis/TutorialWindow.tscn")


var _resonance_connected: bool = false
var _resonance_failed_connected: bool = false
var resonance_failed_flag: bool = false


var waiting_for_action: bool = false
var hidden_for_action: bool = false
var current_allowed_buttons: Array = []


const POPUP_CONTAINER_NAMES = ["PopupContainer", "popup_container"]


var money_at_sell_ore_start: int = -1


func _process(_delta: float) -> void:
	if not is_active:
		return
	_enforce_blocking()
	if waiting_for_action and hidden_for_action:
		_check_auto_conditions()


func _enforce_blocking() -> void:
	var scene = get_tree().current_scene
	if scene:
		_set_buttons_recursive(scene, current_allowed_buttons)


func _connect_resonance_signal() -> void:
	if _resonance_connected:
		return
	var scene = get_tree().current_scene
	if scene and scene.has_signal("resonance_completed"):
		if not scene.is_connected("resonance_completed", _on_resonance_completed):
			scene.resonance_completed.connect(_on_resonance_completed)
			_resonance_connected = true
			print("[Tutorial] Подписались на resonance_completed")


func _connect_resonance_failed_signal() -> void:
	if _resonance_failed_connected:
		return
	var scene = get_tree().current_scene
	if scene and scene.has_signal("resonance_failed"):
		if not scene.is_connected("resonance_failed", _on_resonance_failed):
			scene.resonance_failed.connect(_on_resonance_failed)
			_resonance_failed_connected = true
			print("[Tutorial] Подписались на resonance_failed")


func _on_resonance_completed(_wall_cell: Vector2i) -> void:
	if not is_active:
		return
	if current_step != Step.RUN_GENERATORS and current_step != Step.SUPER_RESONANCE_RUN:
		return
	if not waiting_for_action or not hidden_for_action:
		return
	print("[Tutorial] Резонанс завершён — переходим дальше (шаг: ", current_step, ")")
	resonance_failed_flag = false  # сбрасываем флаг неудачи
	current_step += 1
	waiting_for_action = false
	hidden_for_action = false
	if current_step > Step.FINAL:
		finish_tutorial()
		return
	process_step(current_step)


func _on_resonance_failed() -> void:
	if not is_active:
		return
	if current_step != Step.RUN_GENERATORS and current_step != Step.SUPER_RESONANCE_RUN:
		return
	print("[Tutorial] Резонанс не сработал!")
	resonance_failed_flag = true


func _check_auto_conditions() -> void:
	var data = step_data.get(current_step)
	if not data or not data.has("wait_for"):
		return
	if _is_any_popup_open():
		return
	var scene = get_tree().current_scene
	if not scene:
		return
	match data["wait_for"]:
		"vehicles_bought":
			if Global.vehicles.get("trucks", []).size() >= 1 and Global.vehicles.get("excavators", []).size() >= 1:
				on_action_completed("vehicles_bought")
		"level_bought":
			if Global.purchased_levels.has(1):
				on_action_completed("level_bought")
		"vehicles_sent":
			var truck_arrived = false
			var excavator_arrived = false
			for truck in Global.vehicles.get("trucks", []):
				if truck.get("location") == "level" and truck.get("location_id") == Global.current_level:
					truck_arrived = true
					break
			for excavator in Global.vehicles.get("excavators", []):
				if excavator.get("location") == "level" and excavator.get("location_id") == Global.current_level:
					excavator_arrived = true
					break
			if truck_arrived and excavator_arrived:
				on_action_completed("vehicles_sent")
		"frequency_found":
			if scene.has_method("is_frequency_guessed_for_tutorial"):
				if scene.is_frequency_guessed_for_tutorial():
					on_action_completed("frequency_found")
		"generators_placed":
			if scene.has_method("get_generators_count"):
				if scene.get_generators_count() >= 2:
					on_action_completed("generators_placed")
		"truck_loaded":
			var truck_has_ore = false
			for truck in Global.vehicles.get("trucks", []):
				if truck.get("location") == "level" and truck.get("location_id") == Global.current_level:
					if truck.get("ore", 0) > 0:
						truck_has_ore = true
						break
			if truck_has_ore:
				on_action_completed("truck_loaded")
		"sent_to_factory":
			var total_ore = Global.storage.get("gold", 0) + Global.storage.get("iron", 0) + Global.storage.get("coal", 0)
			if total_ore > 0:
				on_action_completed("sent_to_factory")
		"ore_sold":
			var scene_node = get_tree().current_scene
			var window_closed = true
			if scene_node and "is_window_open" in scene_node:
				window_closed = not scene_node.is_window_open
			if money_at_sell_ore_start != -1 and Global.money > money_at_sell_ore_start and window_closed:
				on_action_completed("ore_sold")
		"super_resonance_setup":
			if scene.has_method("get_generators_count"):
				if scene.get_generators_count() >= 3:
					on_action_completed("super_resonance_setup")


func _is_any_popup_open() -> bool:
	var scene = get_tree().current_scene
	if not scene:
		return false
	var popup = _find_node_by_name(scene, "PopupContainer")
	if popup:
		return popup.get_child_count() > 0
	return false


func _find_node_by_name(node: Node, target_name: String) -> Node:
	if node.name == target_name:
		return node
	for child in node.get_children():
		var found = _find_node_by_name(child, target_name)
		if found:
			return found
	return null


enum Step {
	WELCOME, INTRO, INTERFACE, BUY_VEHICLES, BUY_LEVEL, LEVEL_INTRO,
	SEND_VEHICLES, VEHICLES_ARRIVED, FREQUENCY_GAME_INTRO, FREQUENCY_GAME_PLAY,
	FREQUENCY_GAME_RESULT, RESONANCE_EXPLAIN, PLACE_GENERATORS, RUN_GENERATORS,
	RESONANCE_RESULT, LOAD_TRUCK, SEND_TO_FACTORY, SELL_ORE,
	SUPER_RESONANCE_EXPLAIN, SUPER_RESONANCE_SETUP, SUPER_RESONANCE_RUN,
	SUPER_RESONANCE_RESULT, FINAL
}


var step_data = {
	Step.WELCOME: {"text": "Добро пожаловать в игру Quarry Mining!\nЗдесь вы будете добывать руду, управлять техникой\n и исследовать глубины карьера.\n\nИгра идет на счёт, поэтому если захотите\n посоревноваться с другом, у вас это легко выйдет!", "button": "Далее"},
	Step.INTRO: {"text": "В этой игре вы управляете карьером.\nВаша задача - разрушать землю с помощью звуковых генераторов, \nдобывать землю и перерабатывать её на фабрике,\n получая за это деньги.", "button": "Далее"},
	Step.INTERFACE: {"text": "Основные элементы интерфейса:\nДеньги - это валюта, на неё вы сможете покупать\n новый транспорт или уровни.\nМагазин - здесь вы сможете покупать новую технику,\n но учтите, каждая новая техника будет стоить дороже,\nчем предыдущая\nТехника - здесь вы сможете управлять купленной техникой,\n а именно: отправлять её на уровни,\n отправлять на парковку или на фабрику\nСклад - здесь вы сможете продавать руду,\n которую получите за переработку земли", "button": "Далее"},
	Step.BUY_VEHICLES: {"text": "Любая сессия в игре начинается\n с покупки транспорта. Для начала работы хватит одного грузовика\nи одного экскаватора. Зайдите в магазин и купите их.\n Постарайтесь не тратить лишние деньги,\n а то вам не хватит на покупке уровня.\n\n(Сейчас вы больше одного транспорта купить не сможете :) )", "button": "Понятно", "wait_for": "vehicles_bought"},
	Step.BUY_LEVEL: {"text": "Теперь нужно приобрести уровень.\nДля покупки достаточно нажать на доступную кнопку уровня и,\n если денег достаточно, то уровень купится.\n\n (Для перемещения камеры на уровне\nиспользуйте СКМ)", "button": "Понятно", "wait_for": "level_bought"},
	Step.LEVEL_INTRO: {"text": "Добро пожаловать на учебный уровень!\nКак вы видите, на уровне две стены. Они отличабтся не только\n видом, но и разной частотой для уничтожения.\nВсего будет 4 вида стен, и у каждой стены будет появляться\n своя куча.\nПосле переработки, у каждой кучи свои шансы на руду.\nТакже с каждым последующим уровнем\n размеры его будут только увеличиваться.\nТакже на более глубоких уровнях будет опаснее\n унчтожать стены, так как кучи будут появляться\n не только у разрушенных стен.", "button": "Понятно"},
	Step.SEND_VEHICLES: {"text": "Но перед уничтожением стен лучше\n отправить на уровень транспорт.\nДля этого воспользуйтесь меню 'Техника'.", "button": "Понятно", "wait_for": "vehicles_sent"},
	Step.VEHICLES_ARRIVED: {"text": "Транспорт прибыл! Теперь нужно разрушить стены резонансом.\nДля этого нужно определить частоту, на которой стена разрушится,\n и приближенно повторить её с помощью резонанса.\n\nКаждый раз определять частоту не обязательно,\n но просто подбирать её с помощью резонанс будет дольше.", "button": "Далее"},
	Step.FREQUENCY_GAME_INTRO: {"text": "У каждой стены есть своя частота, на которой она уничтожается.\nНо она умеет не какую-то точку, а промежуток.\nИ если попасть в этот промежуток, то стена разрушится,\n но с разными последствиями.\nЕсли попадёте точно, то разрушится не только та стена,\n в которую попал резонанс, но и рядом стоящие,\nпричем эти стены могут разрушиться без куч.\nЕсли попадание будет хуже, то рядом стоящие\n стены тоже разрушаться,\n но каждая оставит после себя кучу.\nЕсли же попадание ещё хуже,\n то кучи могу появиться не только на месте стен...\n", "button": "Понятно"},
	Step.FREQUENCY_GAME_PLAY: {"text": "Ладно, теперь найдите частоту стены.\nДля этого нажмите на стену с помощью\n ЛКМ. Откроется мини-игра по угадыванию\nчастоты стены. В ней будет 4 промежутка\nв одном из которых скывается нужная частота.\nКогда пульсация круга останавливается,\nто можете проверить эту точку.\nПопробуйте найти нужную частоту!", "button": "Понятно", "wait_for": "frequency_found"},
	Step.FREQUENCY_GAME_RESULT: {"text": "Отлично! Частота найдена.\nТеперь стена может быть разрушена резонансом.", "button": "Далее"},
	Step.RESONANCE_EXPLAIN: {"text": "О резонансе:\nГенераторы создают волны, при пересечении\nволн присходит резонанс\nЕсли частота резонанса совпадает с чатотой\nразрущения стены, то она разрушится.\n\nЧастота резонанса = частота генератора №1\n+ частота генератора №2\n\nЖелтый цвет внутри рзонанса - попал,\nоранжевый - не попал.", "button": "Далее"},
	Step.PLACE_GENERATORS: {"text": "Установите 2 генератора на свободные клетки пола.\nДля резонанса генераторы должны стоять рядом\nдруг с другом. А резонанс должен появиться в области стены.\n\nЕсли не получится с первого раза,\nто не расстраивайтесь! Поэкспериментируйте!", "button": "Понятно", "wait_for": "generators_placed"},
	Step.RUN_GENERATORS: {"text": "Когда генераоры расставлены, то для\nзапуска нажмите кнопку 'Запуск генераторов'.", "button": "Понятно", "wait_for": "generators_run"},
	Step.RESONANCE_RESULT: {"text": "Резонанс сработал! Стена разрушена.\nТеперь нужно добыть руду из кучи.", "button": "Далее"},
	Step.LOAD_TRUCK: {"text": "1. Кликните на экскаватор\n2. Кликните на кучу\n3. Когда заполнится (красный индикатор) — кликните на грузовик\n\nВ один грузовик можно класть только\nодин вид кучи!\nКогда у грузовика появится зелёный индикатор,\nто это будет означать, что в грузовик\nбольше не загрузить.", "button": "Понятно", "wait_for": "truck_loaded"},
	Step.SEND_TO_FACTORY: {"text": "В грузовике теперь есть земля!\nОтправьте его на фабрику, для получения руды.\n\nДля этого воспользуйтесь меню 'Техника'.", "button": "Понятно", "wait_for": "sent_to_factory"},
	Step.SELL_ORE: {"text": "Руда появилась на складе!\nТеперь попробуйте её продать с помощью\n меню 'Склад'.\n\nУ каждой руды своя цена, и чем глубже\nвы будете спускаться, тем дороже будет\nпоявляться руда.", "button": "Понятно", "wait_for": "ore_sold"},
	Step.SUPER_RESONANCE_EXPLAIN: {"text": "Теперь обсудим ещё одну механику: супер-резонанс.\nНе для каждой стены хватит обычного резонанса.\nДля более прочных стен используйте супер-резонанс.\n\nСупер-резонанс - пересечение двух резонансов.\nЕсли области двух резонансов пересеклись,\nто на их пересечении образуется супер-резонанс.\n Частота супер-резонанса = (частота резонанса №1\n+ частота резонанса №2) * 3", "button": "Далее"},
	Step.SUPER_RESONANCE_SETUP: {"text": "Попробуйте найти частоту правой стены.\nПосле чего установите генераторы.\nТрех рядом стоящих будет доастаточно.\n\nЕсли цвет внутри супер-резонанса ближе к розовому,\n то вы попали, если же красный - то нет.", "button": "Понятно", "wait_for": "super_resonance_setup"},
	Step.SUPER_RESONANCE_RUN: {"text": "Теперь запустите генераторы.", "button": "Понятно", "wait_for": "super_resonance_run"},
	Step.SUPER_RESONANCE_RESULT: {"text": "Отлично! Вы освоили все механики.\n Покупка техники и уровней\n Поиск частот\n Резонанс и супер-резонанс\n Добыча и продажа руды", "button": "Далее"},
	Step.FINAL: {"text": "Поздравляю! \n\nТеперь вы готовы к самостоятельной игре.\n\nУдачи в добыче!", "button": "Круто!"}
}


func start_tutorial():
	if is_active:
		return
	is_active = true
	current_step = Step.WELCOME
	Global.is_tutorial = true
	waiting_for_action = false
	hidden_for_action = false
	current_allowed_buttons = []
	_resonance_connected = false
	_resonance_failed_connected = false
	resonance_failed_flag = false
	money_at_sell_ore_start = -1

	Global.reset_game()
	Global.money = 1000

	tutorial_layer = CanvasLayer.new()
	tutorial_layer.layer = 100
	get_tree().root.add_child(tutorial_layer)

	tutorial_window = tutorial_window_scene.instantiate()
	tutorial_window.next_pressed.connect(_on_next_pressed)
	tutorial_window.closed.connect(_on_tutorial_closed)
	tutorial_layer.add_child(tutorial_window)

	get_tree().change_scene_to_file("res://scenes/quarry/QuarryMap.tscn")
	await get_tree().process_frame
	show_step(current_step)


func show_step(step: int):
	if not tutorial_window:
		return
	var data = step_data.get(step)
	if not data:
		return

	var final_text = data["text"]
	var scene = get_tree().current_scene

	# Проверка 1: если игрок принял неправильную частоту известняка
	if step == Step.FREQUENCY_GAME_RESULT:
		if scene and scene.has_method("was_frequency_guessed_correctly"):
			var cell = Vector2i(5, 3)  # первая стена (известняк)
			if not scene.was_frequency_guessed_correctly(cell):
				var correct_freq = scene.get_correct_frequency(cell)
				final_text = "Частота была выбрана неверно.\n\nПравильная частота этой стены: %d Гц\n\nЗапомни это — для разрушения стены резонансом\nнужно установить именно эту частоту." % correct_freq

	# Проверка 2: если резонанс не сработал
	elif step == Step.RESONANCE_RESULT:
		if resonance_failed_flag:
			var cell = Vector2i(5, 3)  # первая стена (известняк)
			var correct_freq = _get_wall_frequency(cell)
			final_text = "Резонанс не сработал 😕\n\nПравильная частота стены: %d Гц\n\nДля разрушения нужно:\n• Поставить 2 генератора по сторонам от стены\n• Установить частоту %d Гц на обоих\n• Направить волны к стене" % [correct_freq, correct_freq]
			resonance_failed_flag = false
		else:
			final_text = "Резонанс сработал! Стена разрушена.\n\nТеперь нужно добыть руду из кучи."

	# Проверка 3: если игрок принял неправильную частоту кимберлита
	elif step == Step.SUPER_RESONANCE_SETUP:
		if scene and scene.has_method("was_frequency_guessed_correctly") and scene.has_method("is_frequency_guessed_for_cell"):
			var cell = Vector2i(9, 3)  # вторая стена (кимберлит)
			# Проверяем, что частота УЖЕ угадана (игрок открыл мини-игру)
			if scene.is_frequency_guessed_for_cell(cell):
				if not scene.was_frequency_guessed_correctly(cell):
					var correct_freq = scene.get_correct_frequency(cell)
					final_text = "Частота кимберлита была выбрана неверно 😕\n\nПравильная частота: %d Гц\n\nУстанови эту частоту на всех 3 генераторах и направь их к стене." % correct_freq

	# Проверка 4: если супер-резонанс не сработал
	elif step == Step.SUPER_RESONANCE_RESULT:
		if resonance_failed_flag:
			var cell = Vector2i(9, 3)  # вторая стена (кимберлит)
			var correct_freq = _get_wall_frequency(cell)
			final_text = "Супер-резонанс не сработал 😕\n\nПравильная частота стены: %d Гц\n\nДля разрушения нужно:\n• Поставить 3 генератора вокруг стены\n• Установить частоту %d Гц на всех\n• Направить волны к стене" % [correct_freq, correct_freq]
			resonance_failed_flag = false
		else:
			final_text = "Отлично! Вы освоили все механики.\n\n✅ Покупка техники и уровней\n✅ Поиск частот\n✅ Резонанс и супер-резонанс\n✅ Добыча и продажа руды"

	hidden_for_action = false
	tutorial_window.visible = true
	tutorial_window.show_text(final_text, data["button"])
	tutorial_window.center_window()
	apply_button_blocking([])
	if data.has("wait_for"):
		waiting_for_action = true
	else:
		waiting_for_action = false

	# Запоминаем деньги в момент начала шага SELL_ORE
	if step == Step.SELL_ORE:
		money_at_sell_ore_start = Global.money
		print("[Tutorial] Запомнили деньги на начало SELL_ORE: ", money_at_sell_ore_start)

	emit_signal("tutorial_step_changed", step)


func _get_wall_frequency(cell: Vector2i) -> int:
	var level_data = Global.level_state.get(Global.current_level, {})
	var wall_freqs = level_data.get("wall_frequencies", {})
	return wall_freqs.get(cell, 0)


func _on_next_pressed():
	var data = step_data.get(current_step)
	if current_step == Step.RESONANCE_RESULT or current_step == Step.SUPER_RESONANCE_RESULT:
		current_step += 1
		if current_step > Step.FINAL:
			finish_tutorial()
			return
		process_step(current_step)
		return
	if data and data.has("wait_for") and not hidden_for_action:
		hide_for_action()
		return
	if waiting_for_action:
		return
	current_step += 1
	if current_step > Step.FINAL:
		finish_tutorial()
		return
	process_step(current_step)


func hide_for_action():
	hidden_for_action = true
	if tutorial_window:
		tutorial_window.visible = false
	apply_button_blocking(get_allowed_buttons(current_step))
	if current_step == Step.RUN_GENERATORS or current_step == Step.SUPER_RESONANCE_RUN:
		_connect_resonance_signal()
		_connect_resonance_failed_signal()


func process_step(step: int):
	match step:
		Step.WELCOME, Step.INTRO, Step.INTERFACE, Step.BUY_VEHICLES, Step.BUY_LEVEL:
			show_step(step)
		Step.LEVEL_INTRO:
			Global.current_level = 1
			get_tree().change_scene_to_file("res://scenes/quarry/QuarryLevel.tscn")
			await get_tree().process_frame
			show_step(step)
		_:
			show_step(step)


func finish_tutorial():
	is_active = false
	Global.is_tutorial = false
	waiting_for_action = false
	hidden_for_action = false
	current_allowed_buttons = []
	_resonance_connected = false
	_resonance_failed_connected = false
	resonance_failed_flag = false
	money_at_sell_ore_start = -1
	unblock_all_buttons()
	var scene = get_tree().current_scene
	if scene:
		if scene.has_signal("resonance_completed") and scene.is_connected("resonance_completed", _on_resonance_completed):
			scene.resonance_completed.disconnect(_on_resonance_completed)
		if scene.has_signal("resonance_failed") and scene.is_connected("resonance_failed", _on_resonance_failed):
			scene.resonance_failed.disconnect(_on_resonance_failed)
	if tutorial_window:
		tutorial_window.queue_free()
		tutorial_window = null
	if tutorial_layer:
		tutorial_layer.queue_free()
		tutorial_layer = null
	emit_signal("tutorial_finished")
	get_tree().change_scene_to_file("res://scenes/main/MainMenu.tscn")


func _on_tutorial_closed():
	finish_tutorial()


func on_action_completed(action: String):
	if not is_active or not waiting_for_action:
		return
	var current_data = step_data.get(current_step)
	if not current_data or not current_data.has("wait_for"):
		return
	if current_data["wait_for"] == action:
		waiting_for_action = false
		hidden_for_action = false
		current_step += 1
		if current_step > Step.FINAL:
			finish_tutorial()
			return
		process_step(current_step)


func on_vehicles_bought(): on_action_completed("vehicles_bought")
func on_level_bought(): on_action_completed("level_bought")
func on_vehicles_sent(): on_action_completed("vehicles_sent")
func on_frequency_found(): on_action_completed("frequency_found")
func on_generators_placed(): on_action_completed("generators_placed")
func on_generators_run(): on_action_completed("generators_run")
func on_truck_loaded(): on_action_completed("truck_loaded")
func on_sent_to_factory(): on_action_completed("sent_to_factory")
func on_ore_sold(): on_action_completed("ore_sold")
func on_super_resonance_setup(): on_action_completed("super_resonance_setup")
func on_super_resonance_run(): on_action_completed("super_resonance_run")


func apply_button_blocking(allowed: Array) -> void:
	current_allowed_buttons = allowed
	_enforce_blocking()


func _set_buttons_recursive(node: Node, allowed: Array) -> void:
	for child in node.get_children():
		if child.name in POPUP_CONTAINER_NAMES:
			continue
		if child is BaseButton:
			child.disabled = not (child.name in allowed)
		_set_buttons_recursive(child, allowed)


func unblock_all_buttons() -> void:
	var scene = get_tree().current_scene
	if not scene:
		return
	_enable_buttons_recursive(scene)


func _enable_buttons_recursive(node: Node) -> void:
	for child in node.get_children():
		if child is BaseButton:
			child.disabled = false
		_enable_buttons_recursive(child)


func get_allowed_buttons(step: int) -> Array:
	match step:
		Step.BUY_VEHICLES: return ["BuyMenu"]
		Step.BUY_LEVEL: return ["level_button_1"]
		Step.LEVEL_INTRO: return ["VehiclesButton"]
		Step.SEND_VEHICLES: return ["VehiclesButton"]
		Step.FREQUENCY_GAME_PLAY: return []
		Step.PLACE_GENERATORS: return ["PlaceGeneratorButton"]
		
		Step.RUN_GENERATORS: return ["StartGeneratorsButton", "PlaceGeneratorButton"]
		Step.LOAD_TRUCK: return []
		Step.SEND_TO_FACTORY: return ["VehiclesButton"]
		Step.SELL_ORE: return ["StorageButton"]
		Step.SUPER_RESONANCE_SETUP: return ["PlaceGeneratorButton"]
		
		Step.SUPER_RESONANCE_RUN: return ["StartGeneratorsButton", "PlaceGeneratorButton"]
		_: return []


func can_click_kimberlite() -> bool:
	if not is_active:
		return true  # вне обучения — всегда можно
	return current_step >= Step.SUPER_RESONANCE_SETUP
