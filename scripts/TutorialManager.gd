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
				if scene.get_generators_count() >= 1:
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
	Step.WELCOME: { "text": "Добро пожаловать в игру Quarry Mining!\nЗдесь вы будете добывать руду, управлять техникой\nи исследовать глубины карьера.\n\nИгра идет на счёт, поэтому если захотите\nпосоревноваться с другом, у вас это легко выйдет!", "button": "Далее"},
	Step.INTRO: { "text": "В этой игре вы управляете карьером.\nВаша задача - разрушать стены с помощью звуковых генераторов,\nдобывать землю и перерабатывать её на фабрике,\nполучая за это деньги.", "button": "Далее"},
	Step.INTERFACE: { "text": "Основные элементы интерфейса:\nДеньги - это валюта, на неё вы сможете покупать\nновый транспорт или уровни.\nМагазин - здесь вы сможете покупать новую технику,\nно учтите, каждая новая техника будет стоить дороже,\nчем предыдущая.\nТехника - здесь вы сможете управлять купленной техникой,\nа именно: отправлять её на уровни,\nотправлять на парковку или на фабрику.\nСклад - здесь вы сможете продавать руду,\nкоторую получите за переработку земли.", "button": "Далее"},
	Step.BUY_VEHICLES: { "text": "Любая сессия в игре начинается\nс покупки транспорта. Для начала работы хватит одного грузовика\nи одного экскаватора. Зайдите в магазин и купите их.\nПостарайтесь не тратить лишние деньги,\nа то вам не хватит на покупку уровня.\n\n(Сейчас вы больше одного транспорта купить не сможете :))", "button": "Понятно", "wait_for": "vehicles_bought"},
	Step.BUY_LEVEL: { "text": "Теперь нужно приобрести уровень.\nДля покупки достаточно нажать на доступную кнопку уровня и,\nесли денег достаточно, то уровень купится.\n\n(Для перемещения камеры на уровне\nиспользуйте СКМ)", "button": "Понятно", "wait_for": "level_bought"},
	Step.LEVEL_INTRO: { "text": "Добро пожаловать на учебный уровень!\nКак вы видите, на уровне две стены. Они отличаются не только\nвидом, но и разной частотой для уничтожения.\nВсего будет 4 вида стен, и у каждой стены будет появляться\nсвоя куча.\nПосле переработки, у каждой кучи свои шансы на руду.\nТакже с каждым последующим уровнем\nразмеры его будут только увеличиваться.\nТакже на более глубоких уровнях будет опаснее\nуничтожать стены, так как кучи будут появляться\nне только у разрушенных стен.", "button": "Понятно"},
	Step.SEND_VEHICLES: { "text": "Но перед уничтожением стен лучше\nотправить на уровень транспорт.\nДля этого воспользуйтесь меню 'Техника'.", "button": "Понятно", "wait_for": "vehicles_sent"},
	Step.VEHICLES_ARRIVED: { "text": "Транспорт прибыл! Теперь нужно разрушить стены резонансом.\nДля этого нужно определить частоту, на которой стена разрушится,\nи приблизительно повторить её с помощью резонанса.\n\nКаждый раз определять частоту не обязательно,\nно просто подбирать её будет дольше.", "button": "Далее"},
	Step.FREQUENCY_GAME_INTRO: { "text": "У каждой стены есть своя резонансная частота.\nЭто физическое свойство материала - как у любого объекта,\nкоторый может вибрировать.\nРезонанс возникает, когда частота генератора\nсовпадает (или близка) с собственной частотой стены.\nТогда колебания стены начинают нарастать -\nи со временем стена разрушается.\nЧем ближе частота - тем быстрее идёт нарастание.\nУ каждой породы свой диапазон частот:\nизвестняк (стена с черными точками) - 100-200 Гц,\nкварцит (с черными и серыми точками) - 200-300 Гц,\nгематит (с черными, серыми и золотыми точками) - 300-400 Гц,\nкимберлит (с серыми и золотыми точками) - 400-500 Гц.", "button": "Понятно"},
	Step.FREQUENCY_GAME_PLAY: { "text": "Ладно, теперь найдите частоту стены. Для этого нажмите на стену\nс помощью ЛКМ. Откроется мини-игра по угадыванию\nчастоты стены. В ней будет индикатор,\nкоторый меняет цвет и пульсацию\nпри приближении к нужной частоте.\nПопробуйте найти нужную частоту!", "button": "Понятно", "wait_for": "frequency_found"},
	Step.FREQUENCY_GAME_RESULT: { "text": "Отлично! Частота найдена.\nТеперь стена может быть разрушена резонансом.", "button": "Далее"},
	Step.RESONANCE_EXPLAIN: { "text": "О резонансе:\nГенератор создаёт волну на выбранной частоте.\nЭто не мгновенный удар - резонанс копится постепенно:\nпока волна нужной частоты бьёт по стене,\nв ней нарастают колебания.\nЧем точнее частота - тем быстрее идёт нарастание.\n\nДля мягких пород (известняк) достаточно одного генератора,\nнаправленного на стену - нужно только подождать.\nДля более прочных пород можно направить на одну стену\nнесколько генераторов с одинаковой частотой -\nв точке, где их волны пересекаются, колебания\nскладываются, и резонанс нарастает в разы быстрее.", "button": "Далее"},
	Step.PLACE_GENERATORS: { "text": "Для разрушения известняковой стены достаточно одного генератора.\nОн установлен слева от стены на расстоянии одной клетки\nи направлен на неё.\n\nПОтом вам самим нужно будет устанавливать генераторы для разрушения стены,\nно сейчас, в качестве обучения, он уже установлен и настроен.\nЕсли хотите посмотреть его настройку,\nможете просто кликнуть по нему на уровне.\nТолько если вы удалите, вам самим придется настраивать новый.\n\nНажмите 'Запуск генераторов' для начала работы.", "button": "Понятно", "wait_for": "generators_placed"},
	Step.RUN_GENERATORS: { "text": "Для разрушения известняковой стены достаточно одного генератора.\nОн установлен слева от стены на расстоянии одной клетки\nи направлен на неё.\n\nПотом вам самим нужно будет устанавливать\nгенераторы для разрушения стены,\nно сейчас, в качестве обучения, он уже установлен и настроен.\nЕсли хотите посмотреть его настройку,\nможете просто кликнуть по нему на уровне.\nТолько если вы удалите, вам самим придется настраивать новый.\n\nНажмите 'Запуск генераторов' для начала работы.", "button": "Понятно", "wait_for": "generators_run"},
	Step.RESONANCE_RESULT: { "text": "Резонанс сработал! Стена разрушена.\nКак вы видели, на стене появился зелёный круг,\n и когда он вырос максимально, он исчез.\nЭто означает, что стена разрушится.\nЕсли бы круг не исчез, а остался на стене,\nто это бы означало что либо частота подобрана не до конца верно,\nлибо амплитуды не достаточно, и нужно ставить ещё генераторы.\nЕсли бы круг вообще не появился на стене,\nто это бы означало, что частота подобрана очень далеко\nот верного значения.\n\nТеперь нужно добыть руду из кучи.", "button": "Далее"},
	Step.LOAD_TRUCK: { "text": "1. Кликните на экскаватор.\n2. Кликните на кучу.\n3. Когда заполнится (красный индикатор) - кликните на грузовик.\n\nВ один грузовик можно класть только\nодин вид кучи!\nКогда у грузовика появится зелёный индикатор,\nто это будет означать, что в грузовик\nбольше не загрузить.", "button": "Понятно", "wait_for": "truck_loaded"},
	Step.SEND_TO_FACTORY: { "text": "В грузовике теперь есть земля!\nОтправьте его на фабрику, для получения руды.\n\nДля этого воспользуйтесь меню 'Техника'.", "button": "Понятно", "wait_for": "sent_to_factory"},
	Step.SELL_ORE: { "text": "Руда появилась на складе!\nТеперь попробуйте её продать с помощью\nменю 'Склад'.\n\nУ каждой руды своя цена, и чем глубже\nвы будете спускаться, тем дороже будет\nпоявляться руда.", "button": "Понятно", "wait_for": "ore_sold"},
	Step.SUPER_RESONANCE_EXPLAIN: { "text": "Теперь обсудим ещё один приём: групповой резонанс.\nДля особо прочных пород (вроде кимберлита) одного\nгенератора может не хватить - накопление резонанса\nзаймёт слишком много времени.\n\nРешение простое: направьте на одну стену несколько\nгенераторов с одной и той же частотой. В точке,\nгде их волны пересекаются, колебания складываются -\nэто называется конструктивной интерференцией.\nВ этой точке резонанс нарастает в несколько раз быстрее,\nчем от одного генератора.\n\n", "button": "Далее"},
	Step.SUPER_RESONANCE_SETUP: { "text": "Важно: частота должна быть одинаковой у всех\nгенераторов, направленных на одну стену - иначе\nволны не усилят друг друга.\n\nТри генератора установлены столбиком слева от кимберлитовой стены\nна расстоянии одной клетки и направлены на неё.\n\nНажмите 'Запуск генераторов', чтобы увидеть результат.\n\n(Вы также можете нажать на\nкаждый из генераторов, и посмотреть, как они настроены)", "button": "Понятно", "wait_for": "super_resonance_setup"},
	Step.SUPER_RESONANCE_RUN: { "text": "Важно: частота должна быть одинаковой у всех\nгенераторов, направленных на одну стену - иначе\nволны не усилят друг друга.\n\nТри генератора установлены столбиком слева от кимберлитовой стены\nна расстоянии одной клетки и направлены на неё.\n\nНажмите 'Запуск генераторов', чтобы увидеть результат.\n\n(Вы также можете нажать на\nкаждый из генераторов, и посмотреть, как они настроены)", "button": "Понятно", "wait_for": "super_resonance_run"},
	Step.SUPER_RESONANCE_RESULT: { "text": "Отлично! Вы освоили все механики.\n\n- Покупка техники и уровней\n- Поиск частот\n- Резонанс и групповой резонанс\n- Добыча и продажа руды", "button": "Далее"},
	Step.FINAL: { "text": "Поздравляю!\n\nТеперь вы готовы к самостоятельной игре.\n\nУдачи в добыче!", "button": "Круто!"}
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
	
	# <<< НОВОЕ: автоматическая расстановка генераторов
	# <<< НОВОЕ: автоматическая расстановка генераторов
	if step == Step.PLACE_GENERATORS:
		# 1 генератор слева от известняковой стены (5, 3) на расстоянии 1 блока
		_place_generators_for_resonance(scene, Vector2i(5, 3), [Vector2i(3, 3)])
		current_step += 1
		if current_step > Step.FINAL:
			finish_tutorial()
			return
		process_step(current_step)
		return

	elif step == Step.SUPER_RESONANCE_SETUP:
		# 3 генератора столбиком слева от кимберлитовой стены (9, 3) на расстоянии 1 блока
		_place_generators_for_super_resonance(scene, Vector2i(9, 3), [Vector2i(7, 2), Vector2i(7, 3), Vector2i(7, 4)])
		current_step += 1
		if current_step > Step.FINAL:
			finish_tutorial()
			return
		process_step(current_step)
		return
	
	# Проверка 1: если игрок принял неправильную частоту известняка
	if step == Step.FREQUENCY_GAME_RESULT:
		if scene and scene.has_method("was_frequency_guessed_correctly"):
			var cell = Vector2i(5, 3)  # первая стена (известняк)
			if not scene.was_frequency_guessed_correctly(cell):
				var correct_freq = scene.get_correct_frequency(cell)
				final_text = "Почти угадали.\n\nПравильная частота стены, на которую вы ткнули (известняк): %d Гц\nКаждый раз идеально угадывать чатсоту\nне обязательно, достаточно найти близкое.\nНо всё-равно, запомни частоту — для разрушения стены резонансом\nнужно установить именно эту частоту на генераторе.\n\n(Стена вокруг уровня неразрушаемая, даже не пытайтесь :))" % correct_freq
	# Проверка 2: если резонанс не сработал
	elif step == Step.RESONANCE_RESULT:
		if resonance_failed_flag:
			var cell = Vector2i(5, 3)  # первая стена (известняк)
			var correct_freq = _get_wall_frequency(cell)
			final_text = "Резонанс не сработал 😕\n\nПравильная частота стены: %d Гц\n\nДля разрушения нужно:\n• Установить частоту %d Гц на генераторе\n• Направить его на стену\n• Дать резонансу время накопиться - если частота\n  подобрана неточно или генератор смотрит мимо,\n  колебания не успеют нарасти" % [correct_freq, correct_freq]
			resonance_failed_flag = false
		else:
			final_text = "Резонанс сработал! Стена разрушена.\nКак вы видели, на стене появился зелёный круг,\n и когда он вырос максимально, он исчез.\nЭто означает, что стена разрушится.\nЕсли бы круг не исчез, а остался на стене,\nто это бы означало что либо частота подобрана не до конца верно,\nлибо амплитуды не достаточно, и нужно ставить ещё генераторы.\nЕсли бы круг вообще не появился на стене,\nто это бы означало, что частота подобрана очень далеко\nот верного значения.\n\nТеперь нужно добыть руду из кучи."
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
			final_text = "Групповой резонанс не сработал 😕\n\nПравильная частота стены: %d Гц\n\nДля разрушения нужно:\n• Направить на стену несколько генераторов\n• Установить ОДИНАКОВУЮ частоту %d Гц на всех\n• Направить волны к стене и подождать, пока резонанс наберётся" % [correct_freq, correct_freq]
			resonance_failed_flag = false
		else:
			final_text = "Отлично! Вы освоили все механики.\n\n✅ Покупка техники и уровней\n✅ Поиск частот\n✅ Резонанс и групповой резонанс\n✅ Добыча и продажа руды"
	
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

# <<< НОВОЕ: функция для автоматической расстановки генераторов
func _place_generators_for_resonance(scene: Node, wall_cell: Vector2i, generator_cells: Array):
	if not scene or not scene.has_method("place_generator_at_cell"):
		return
	for gen_cell in generator_cells:
		scene.place_generator_at_cell(gen_cell)
		var gen_id = scene.get_generator_at_cell(gen_cell)
		if gen_id != -1:
			scene._on_generator_frequency_selected(gen_id, _get_wall_frequency(wall_cell))
			scene._on_generator_direction_selected(gen_id, _get_direction_to_wall(gen_cell, wall_cell))
	print("[Tutorial] Автоматически расставлен 1 генератор для обычного резонанса")

func _place_generators_for_super_resonance(scene: Node, wall_cell: Vector2i, generator_cells: Array):
	if not scene or not scene.has_method("place_generator_at_cell"):
		return
	for gen_cell in generator_cells:
		scene.place_generator_at_cell(gen_cell)
		var gen_id = scene.get_generator_at_cell(gen_cell)
		if gen_id != -1:
			scene._on_generator_frequency_selected(gen_id, _get_wall_frequency(wall_cell))
			scene._on_generator_direction_selected(gen_id, _get_direction_to_wall(gen_cell, wall_cell))
	print("[Tutorial] Автоматически расставлены 3 генератора столбиком для супер-резонанса")

func _get_direction_to_wall(gen_cell: Vector2i, wall_cell: Vector2i) -> int:
	var diff = wall_cell - gen_cell
	if abs(diff.x) > abs(diff.y):
		return 1 if diff.x > 0 else 3  # вправо или влево
	else:
		return 2 if diff.y > 0 else 0  # вниз или вверх


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
			if child.name == "BackButton":
				child.disabled = false
			else:
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
