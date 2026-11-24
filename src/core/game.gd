extends Node
## Ход игры: новая игра, продолжение, переходы между комнатами и показ концовок.
##
## Единственное место, которое меняет сцены. Комнаты и двери просят переход здесь,
## поэтому затемнение, автосохранение и защита от двойного перехода работают одинаково везде.
## Здесь же сердца героя: проигранная мини-игра или бой отнимают одно, без сердец игра
## начинается заново после заставки.

signal room_entered(code: String)
signal rooms_left
signal game_started
signal task_changed(text_key: String)
signal slow_motion_changed(active: bool)
signal heart_lost(left: int)

const START_ROOM := "vestibule"
const START_SPAWN := "start"
const MAIN_MENU_SCENE := "res://src/ui/main_menu/main_menu.tscn"
const ENDING_SCENE := "res://src/ui/ending/ending_screen.tscn"
const FINALE_SCENE := "res://src/ui/finale/finale_screen.tscn"
const FINAL_FADE_SEC := 2.5
const SLOW_SCALE := 0.5
const LIFT_ROOM := "lift"
const HEARTS := "hearts"

var room_code: String = ""
var spawn_id: String = ""
var task_key: String = ""
var pending_ending: String = ""
var last_ending: String = ""
var in_room: bool = false
var lift_floor: int = 1

var _busy: bool = false
var _slow: bool = false


## Сообщает, идёт ли сейчас переход между сценами.
## Возвращает true, пока экран затемнён и сцена меняется.
func is_busy() -> bool:
	return _busy


## Начинает новое прохождение: сбрасывает мир, журнал, заражение и сохранение.
## [param level] - уровень сложности из [Difficulty]; пустая строка оставляет уровень
## прошлой игры (так игра начинается заново после проигрыша).
func new_game(level: String = "") -> void:
	if level.is_empty():
		level = Difficulty.current()
	World.reset({Difficulty.KEY: level, HEARTS: Difficulty.value("hearts", level)})
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
	await _resume_session()
	return true


## Начинает заново с последнего сохранения (комнаты, куда герой вошёл последней) с полными
## сердцами. Так проигрыш не стирает пройденные этажи.
## Возвращает true, если сохранение нашлось.
func restart_from_save() -> bool:
	if not SaveSystem.load_game():
		return false
	World.set_value(HEARTS, Difficulty.value("hearts"))
	await _resume_session()
	return true


## Сохраняет прохождение, когда игрок закрывает окно игры.
## [param what] - код уведомления.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and in_room:
		_store_session()
		SaveSystem.save_game()


## Ведёт героя в комнату из загруженного сохранения.
func _resume_session() -> void:
	var session: Dictionary = SaveSystem.session
	var code: String = str(session.get("room", START_ROOM))
	var spawn: String = str(session.get("spawn", START_SPAWN))
	task_key = str(session.get("task", ""))
	lift_floor = int(session.get("lift_from", 1))
	if not LocationCatalog.is_built(code):
		code = START_ROOM
		spawn = START_SPAWN
	await goto_room(code, spawn)


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


## Отнимает у героя сердце за проигранную мини-игру или бой.
## Когда сердец не осталось, показывает заставку проигрыша и начинает игру заново.
## Возвращает, сколько сердец осталось.
func lose_heart() -> int:
	var left := World.bump(HEARTS, -1)
	heart_lost.emit(left)
	if left > 0:
		SaveSystem.save_game()
	else:
		await game_over()
	return left


## Показывает заставку проигрыша и возвращает героя к последнему сохранению с полными
## сердцами; без сохранения начинает новую игру. Открытые концовки в профиле остаются.
func game_over() -> void:
	if _busy:
		return
	_busy = true
	in_room = false
	await Ui.game_over.play()
	await Ui.fade_out()
	Ui.game_over.close()
	_busy = false
	if not await restart_from_save():
		await new_game()


## Заводит героя в кабину лифта и запоминает этаж, с которого он вошёл.
func enter_lift() -> void:
	if _busy:
		return
	lift_floor = LocationCatalog.floor_of(room_code)
	await goto_room(LIFT_ROOM, START_SPAWN)


## Выводит героя из кабины на тот этаж, с которого он вошёл.
func leave_lift() -> void:
	await goto_room(Elevator.room(lift_floor), Elevator.SPAWN)


## Сообщает, на каком этаже сейчас герой; в кабине лифта это этаж, где он в неё вошёл.
## Возвращает номер этажа.
func current_floor() -> int:
	if room_code == LIFT_ROOM:
		return lift_floor
	return LocationCatalog.floor_of(room_code)


## Ставит текущее задание, которое показывает интерфейс.
## [param text_key] - ключ текста задания; пустая строка убирает задание.
func set_task(text_key: String) -> void:
	if task_key == text_key:
		return
	task_key = text_key
	_store_session()
	task_changed.emit(task_key)


## Открывает концовку. Основная концовка без отдельного экрана: картинка медленно темнеет
## и переходит в финал (эпилог с «тшшш» Мажайцева и END, потом титры). Остальные концовки
## показывают свой экран.
## [param ending_id] - код концовки из каталога.
func show_ending(ending_id: String) -> void:
	if _busy or not EndingCatalog.has(ending_id):
		return
	SaveSystem.unlock_ending(ending_id)
	if EndingCatalog.is_final(ending_id):
		_busy = true
		last_ending = ending_id
		in_room = false
		Music.stop()
		await Ui.fade_out(FINAL_FADE_SEC)
		_busy = false
		await show_finale()
		return
	_busy = true
	pending_ending = ending_id
	in_room = false
	rooms_left.emit()
	await _switch_scene(ENDING_SCENE, room_code, spawn_id)
	_busy = false


## Завершает показ концовки: основная ведёт в финал (эпилог и титры), остальные возвращают
## в игру.
func finish_ending() -> void:
	var ending_id := pending_ending
	pending_ending = ""
	last_ending = ending_id
	if EndingCatalog.is_final(ending_id):
		await show_finale()
	elif not LocationCatalog.is_built(room_code):
		await to_main_menu()
	else:
		await goto_room(room_code, spawn_id)


## Показывает финал: эпилог после хорошей концовки и титры, потом главное меню.
func show_finale() -> void:
	if _busy:
		return
	_busy = true
	in_room = false
	rooms_left.emit()
	await _switch_scene(FINALE_SCENE, "", "")
	_busy = false


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
	if LocationCatalog.floor_of(code) > 0:
		Infection.current_floor = LocationCatalog.floor_of(code)
	if get_tree().change_scene_to_file(path) != OK:
		push_error("Game: не удалось открыть сцену %s" % path)
	await get_tree().process_frame
	await Ui.fade_in()


## Записывает место героя и задание в данные сохранения.
func _store_session() -> void:
	SaveSystem.session = {
		"room": room_code, "spawn": spawn_id, "task": task_key, "lift_from": lift_floor
	}
