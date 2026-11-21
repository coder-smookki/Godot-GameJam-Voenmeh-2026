extends Node
## Ход игры: новая игра, продолжение, переходы между комнатами и показ концовок.
##
## Единственное место, которое меняет сцены. Комнаты и двери просят переход здесь,
## поэтому затемнение, автосохранение и защита от двойного перехода работают одинаково везде.

signal room_entered(code: String)
signal rooms_left
signal game_started
signal task_changed(text_key: String)
signal slow_motion_changed(active: bool)

const START_ROOM := "1-01"
const START_SPAWN := "start"
const MAIN_MENU_SCENE := "res://src/ui/main_menu/main_menu.tscn"
const EPILOGUE_SCENE := "res://src/ui/epilogue/epilogue_screen.tscn"
const SLOW_SCALE := 0.5

var room_code: String = ""
var spawn_id: String = ""
var task_key: String = ""
var pending_ending: String = ""
var in_room: bool = false

var _busy: bool = false
var _slow: bool = false


## Сообщает, идёт ли сейчас переход между сценами.
## Возвращает true, пока экран затемнён и сцена меняется.
func is_busy() -> bool:
	return _busy


## Начинает новое прохождение: сбрасывает мир, журнал, заражение и сохранение.
func new_game() -> void:
	World.reset()
	Journal.clear()
	Infection.reset()
	SaveSystem.delete_save()
	task_key = ""
	game_started.emit()
	await goto_room(START_ROOM, START_SPAWN)


## Продолжает сохранённое прохождение с той комнаты, где игрок остановился.
## Возвращает true, если сохранение загружено.
func continue_game() -> bool:
	if not SaveSystem.load_game():
		return false
	var session: Dictionary = SaveSystem.session
	var code: String = str(session.get("room", START_ROOM))
	var spawn: String = str(session.get("spawn", START_SPAWN))
	task_key = str(session.get("task", ""))
	if not LocationCatalog.is_built(code):
		code = START_ROOM
		spawn = START_SPAWN
	await goto_room(code, spawn)
	return true


## Переводит героя в другую комнату с затемнением и автосохранением.
## [param code] - код локации из каталога.
## [param spawn] - имя точки появления в комнате.
func goto_room(code: String, spawn: String = START_SPAWN) -> void:
	if _busy:
		return
	if not LocationCatalog.is_built(code):
		push_warning("Game.goto_room: комната %s ещё не собрана" % code)
		return
	_busy = true
	await _switch_scene(LocationCatalog.scene_path(code), code, spawn)
	in_room = true
	_store_session()
	SaveSystem.save_game()
	_busy = false
	room_entered.emit(code)
	task_changed.emit(task_key)


## Ставит текущее задание, которое показывает интерфейс.
## [param text_key] - ключ текста задания; пустая строка убирает задание.
func set_task(text_key: String) -> void:
	if task_key == text_key:
		return
	task_key = text_key
	_store_session()
	task_changed.emit(task_key)


## Открывает концовку и показывает её экран.
## [param ending_id] - код концовки из каталога.
func show_ending(ending_id: String) -> void:
	if _busy or not EndingCatalog.has(ending_id):
		return
	_busy = true
	SaveSystem.unlock_ending(ending_id)
	pending_ending = ending_id
	in_room = false
	rooms_left.emit()
	await _switch_scene(EPILOGUE_SCENE, room_code, spawn_id)
	_busy = false


## Завершает показ концовки: основная ведёт в главное меню, остальные возвращают в игру.
func finish_ending() -> void:
	var ending_id := pending_ending
	pending_ending = ""
	if EndingCatalog.is_final(ending_id) or not LocationCatalog.is_built(room_code):
		await to_main_menu()
	else:
		await goto_room(room_code, spawn_id)


## Возвращает в главное меню.
func to_main_menu() -> void:
	if _busy:
		return
	_busy = true
	in_room = false
	rooms_left.emit()
	await _switch_scene(MAIN_MENU_SCENE, "", "")
	_busy = false


## Включает или выключает замедление мира (режим отладчика).
## [param active] - true замедляет время, false возвращает обычную скорость.
func set_slow_motion(active: bool) -> void:
	if _slow == active:
		return
	_slow = active
	Engine.time_scale = SLOW_SCALE if active else 1.0
	slow_motion_changed.emit(active)


## Меняет сцену под затемнением и снимает паузу и замедление.
## [param path] - путь к сцене.
## [param code] - код комнаты после перехода; пустой для меню.
## [param spawn] - точка появления после перехода.
func _switch_scene(path: String, code: String, spawn: String) -> void:
	set_slow_motion(false)
	Ui.close_all_modals()
	await Ui.fade_out()
	room_code = code
	spawn_id = spawn
	if LocationCatalog.has(code):
		Infection.current_floor = LocationCatalog.floor_of(code)
	if get_tree().change_scene_to_file(path) != OK:
		push_error("Game: не удалось открыть сцену %s" % path)
	await get_tree().process_frame
	await Ui.fade_in()


## Записывает место героя и задание в данные сохранения.
func _store_session() -> void:
	SaveSystem.session = {"room": room_code, "spawn": spawn_id, "task": task_key}
