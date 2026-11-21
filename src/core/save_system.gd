extends Node
## Сохранения и профиль игрока.
##
## Сохранение хранит одно прохождение: мир, журнал, заражение и место героя.
## Профиль переживает новые игры: открытые концовки и доступ к «Новой игре+».
## Перед каждой развилкой делается снимок, чтобы решение можно было переиграть.

signal saved
signal profile_changed

const VERSION := 1
const SAVE_FILE := "save.json"
const PROFILE_FILE := "profile.json"
const CHAPTERS_DIR := "chapters"
const TMP_SUFFIX := ".tmp"

var dir: String = "user://"
var session: Dictionary = {}

var _profile: Dictionary = {}


## Загружает профиль и подписывается на решения мира для автосохранения.
func _ready() -> void:
	_profile = _default_profile()
	load_profile()
	World.deciding.connect(_on_world_deciding)
	World.decided.connect(_on_world_decided)


## Сообщает, есть ли сохранённое прохождение.
## Возвращает true, если файл сохранения (или его незавершённая копия) существует.
func has_save() -> bool:
	return FileAccess.file_exists(dir + SAVE_FILE) or FileAccess.file_exists(_tmp(SAVE_FILE))


## Записывает текущее прохождение на диск.
## Возвращает true, если файл записан.
func save_game() -> bool:
	var ok := _write(SAVE_FILE, _collect())
	if ok:
		saved.emit()
	return ok


## Загружает прохождение с диска и применяет его к миру, журналу и заражению.
## Возвращает true, если сохранение найдено и прочитано.
func load_game() -> bool:
	var data := _read(SAVE_FILE)
	if data.is_empty():
		return false
	_apply(data)
	return true


## Удаляет сохранённое прохождение и снимки развилок.
func delete_save() -> void:
	_remove(SAVE_FILE)
	if DirAccess.dir_exists_absolute(dir + CHAPTERS_DIR):
		for file: String in DirAccess.get_files_at(dir + CHAPTERS_DIR):
			DirAccess.remove_absolute("%s%s/%s" % [dir, CHAPTERS_DIR, file])


## Делает снимок прохождения перед развилкой.
## [param fork_id] - код развилки, по нему снимок потом находится.
## Возвращает true, если снимок записан.
func snapshot(fork_id: String) -> bool:
	DirAccess.make_dir_recursive_absolute(dir + CHAPTERS_DIR)
	return _write(_chapter_file(fork_id), _collect())


## Сообщает, есть ли снимок перед развилкой.
## [param fork_id] - код развилки.
## Возвращает true, если снимок существует.
func has_snapshot(fork_id: String) -> bool:
	return FileAccess.file_exists(dir + _chapter_file(fork_id))


## Возвращает игру к снимку перед развилкой.
## [param fork_id] - код развилки.
## Возвращает true, если снимок найден и применён.
func load_snapshot(fork_id: String) -> bool:
	var data := _read(_chapter_file(fork_id))
	if data.is_empty():
		return false
	_apply(data)
	return true


## Открывает концовку в профиле и запоминает лучший счёт посланий.
## [param ending_id] - код концовки из каталога.
func unlock_ending(ending_id: String) -> void:
	if not EndingCatalog.has(ending_id):
		push_error("SaveSystem.unlock_ending: концовки %s нет в каталоге" % ending_id)
		return
	var endings: Array = _profile["endings"]
	if ending_id not in endings:
		endings.append(ending_id)
	if ending_id == "loop":
		_profile["ng_plus"] = true
	_profile["best_messages"] = maxi(int(_profile["best_messages"]), int(World.f["messages"]))
	_write(PROFILE_FILE, _profile)
	profile_changed.emit()


## Сообщает, открыта ли концовка.
## [param ending_id] - код концовки.
## Возвращает true, если игрок уже получал эту концовку.
func is_ending_unlocked(ending_id: String) -> bool:
	return ending_id in _profile["endings"]


## Возвращает открытые концовки.
## Возвращает копию массива кодов концовок.
func unlocked_endings() -> Array:
	return _profile["endings"].duplicate()


## Сообщает, открыта ли «Новая игра+».
## Возвращает true после концовки «Петля».
func is_ng_plus_unlocked() -> bool:
	return bool(_profile["ng_plus"])


## Возвращает наибольшее число посланий ЛАБЫ, собранных за одно прохождение.
## Возвращает число от 0 до 5; нужно для истинной концовки.
func best_messages() -> int:
	return int(_profile["best_messages"])


## Загружает профиль с диска, если он есть.
func load_profile() -> void:
	_profile = _default_profile()
	var data := _read(PROFILE_FILE)
	var endings: Variant = data.get("endings", [])
	if endings is Array:
		for ending_id: Variant in endings:
			if ending_id is String and EndingCatalog.has(ending_id):
				if ending_id not in _profile["endings"]:
					_profile["endings"].append(ending_id)
	_profile["ng_plus"] = data.get("ng_plus", false) == true
	var best: Variant = data.get("best_messages", 0)
	if typeof(best) == TYPE_INT or typeof(best) == TYPE_FLOAT:
		_profile["best_messages"] = clampi(int(best), 0, int(World.SCHEMA["messages"]["max"]))
	profile_changed.emit()


## Собирает пустой профиль.
## Возвращает словарь профиля без открытых концовок.
func _default_profile() -> Dictionary:
	return {"version": VERSION, "endings": [], "ng_plus": false, "best_messages": 0}


## Собирает данные прохождения из всех систем.
## Возвращает словарь, готовый к записи в JSON.
func _collect() -> Dictionary:
	return {
		"version": VERSION,
		"world": World.to_dict(),
		"journal": Journal.to_array(),
		"infection": Infection.to_dict(),
		"session": session.duplicate(true),
	}


## Раздаёт прочитанные данные по системам.
## [param data] - словарь прохождения из файла.
func _apply(data: Dictionary) -> void:
	var world: Variant = data.get("world", {})
	World.from_dict(world if world is Dictionary else {})
	var journal: Variant = data.get("journal", [])
	Journal.from_array(journal if journal is Array else [])
	var infection: Variant = data.get("infection", {})
	Infection.from_dict(infection if infection is Dictionary else {})
	var loaded: Variant = data.get("session", {})
	session = loaded.duplicate(true) if loaded is Dictionary else {}


## Записывает словарь в файл через временную копию, чтобы сбой не испортил сохранение.
## [param file] - имя файла внутри папки сохранений.
## [param data] - словарь для записи.
## Возвращает true, если запись прошла.
func _write(file: String, data: Dictionary) -> bool:
	DirAccess.make_dir_recursive_absolute(dir)
	var handle := FileAccess.open(_tmp(file), FileAccess.WRITE)
	if handle == null:
		push_error("SaveSystem: не удалось открыть %s на запись" % _tmp(file))
		return false
	handle.store_string(JSON.stringify(data, "\t"))
	handle.close()
	if FileAccess.file_exists(dir + file):
		DirAccess.remove_absolute(dir + file)
	if DirAccess.rename_absolute(_tmp(file), dir + file) != OK:
		push_error("SaveSystem: не удалось заменить %s" % (dir + file))
		return false
	return true


## Читает словарь из файла; при отсутствии основного файла берёт временную копию.
## [param file] - имя файла внутри папки сохранений.
## Возвращает прочитанный словарь или пустой, если файла нет либо он испорчен.
func _read(file: String) -> Dictionary:
	for path: String in [dir + file, _tmp(file)]:
		if not FileAccess.file_exists(path):
			continue
		var json := JSON.new()
		if json.parse(FileAccess.get_file_as_string(path)) == OK and json.data is Dictionary:
			return json.data
		push_warning("SaveSystem: файл %s испорчен и пропущен" % path)
	return {}


## Удаляет файл и его временную копию.
## [param file] - имя файла внутри папки сохранений.
func _remove(file: String) -> void:
	for path: String in [dir + file, _tmp(file)]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


## Собирает путь к временной копии файла.
## [param file] - имя файла внутри папки сохранений.
## Возвращает полный путь с окончанием ".tmp".
func _tmp(file: String) -> String:
	return dir + file + TMP_SUFFIX


## Собирает имя файла снимка развилки.
## [param fork_id] - код развилки.
## Возвращает относительный путь внутри папки сохранений.
func _chapter_file(fork_id: String) -> String:
	return "%s/%s.json" % [CHAPTERS_DIR, fork_id.validate_filename()]


## Делает снимок перед тем, как мир запишет решение развилки.
## [param fork_id] - код развилки.
func _on_world_deciding(fork_id: String) -> void:
	snapshot(fork_id)


## Автоматически сохраняет игру после решения.
## [param _key] - имя переменной, сохранению не нужно.
## [param _value] - выбранное значение, сохранению не нужно.
## [param _toast_key] - ключ тоста, сохранению не нужен.
func _on_world_decided(_key: String, _value: Variant, _toast_key: String) -> void:
	save_game()
