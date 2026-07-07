extends Node


const LEADERBOARD_PATH = "user://leaderboard.json"
const MAX_ENTRIES = 10


var leaderboard: Array = []


func _ready():
	load_leaderboard()


func load_leaderboard() -> void:
	if not FileAccess.file_exists(LEADERBOARD_PATH):
		leaderboard = []
		return
	var file = FileAccess.open(LEADERBOARD_PATH, FileAccess.READ)
	if file == null:
		print("[Leaderboard] Ошибка открытия файла: ", FileAccess.get_open_error())
		leaderboard = []
		return
	var json_text = file.get_as_text()
	file.close()
	var json = JSON.new()
	var error = json.parse(json_text)
	if error != OK:
		print("[Leaderboard] Ошибка парсинга JSON: ", error)
		leaderboard = []
		return
	leaderboard = json.data if json.data is Array else []
	print("[Leaderboard] Загружено записей: ", leaderboard.size())


func save_leaderboard() -> void:
	var file = FileAccess.open(LEADERBOARD_PATH, FileAccess.WRITE)
	if file == null:
		print("[Leaderboard] Ошибка сохранения: ", FileAccess.get_open_error())
		return
	file.store_string(JSON.stringify(leaderboard, "  "))
	file.close()
	print("[Leaderboard] Сохранено записей: ", leaderboard.size())


func add_entry(player_name: String, score: int, levels: int, breakdown: Dictionary) -> int:
	var entry = {
		"name": player_name,
		"score": score,
		"levels": levels,
		"breakdown": breakdown,
		"date": Time.get_datetime_string_from_system().substr(0, 10)
	}
	leaderboard.append(entry)
	# Сортировка по счёту (убывание)
	leaderboard.sort_custom(func(a, b): return a["score"] > b["score"])
	# Обрезаем до топ-10
	if leaderboard.size() > MAX_ENTRIES:
		leaderboard = leaderboard.slice(0, MAX_ENTRIES)
	save_leaderboard()
	# Возвращаем позицию игрока
	for i in range(leaderboard.size()):
		if leaderboard[i]["name"] == player_name and leaderboard[i]["score"] == score:
			return i + 1
	return leaderboard.size()


func get_top_entries(count: int = 10) -> Array:
	return leaderboard.slice(0, min(count, leaderboard.size()))


func clear_leaderboard() -> void:
	leaderboard = []
	save_leaderboard()
