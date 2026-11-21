class_name ExitDoor
extends Door
## Выход на улицу из вестибюля: развилка P1 «Уйти домой».
##
## Первые 60 секунд после запуска ЛАБЫ дверь ещё не заражена, и через неё можно уйти
## в шуточную концовку. Потом дверь заражается и закрывается навсегда.

const WINDOW_SEC := 60.0
const LAUNCH_MARK := "laba_launched"
const ENDING := "expelled"
const TIMER_MARGIN_SEC := 0.1

var _closing_timer: SceneTreeTimer = null


## Настраивает дверь и заводит таймер до её заражения.
func _ready() -> void:
	super()
	_arm_timer()


## Сообщает, можно ли ещё уйти через дверь.
## Возвращает true в течение 60 секунд после запуска ЛАБЫ, пока игрок не пробовал уйти.
func is_open() -> bool:
	return not World.f["escape_tried"] and World.marked_ago(LAUNCH_MARK) < WINDOW_SEC


## Собирает подпись таблички: название выхода или «404», когда дверь заражена.
## Возвращает текст таблички.
func plate_text() -> String:
	if World.is_marked(LAUNCH_MARK) and not is_open():
		return tr("DOOR_404")
	return super()


## Уводит героя в концовку «Отчислен» или объясняет, почему уйти нельзя.
## [param _player] - герой, который открывает дверь.
func _interact(_player: Player) -> void:
	if is_open():
		World.choose("escape_tried", true, "FORK_P1_TOAST")
		Game.show_ending(ENDING)
	elif World.is_marked(LAUNCH_MARK):
		Ui.toast(tr("LOCK_EXIT_404"), ToastStack.KIND_HINT)
	else:
		Ui.toast(tr("LOCK_EXIT_EARLY"), ToastStack.KIND_HINT)


## Заводит таймер на остаток окна, когда ЛАБА запущена.
## [param id] - имя новой отметки.
func _on_world_marked(id: String) -> void:
	super(id)
	if id == LAUNCH_MARK:
		_arm_timer()


## Запускает одноразовый таймер, который обновит дверь в момент заражения.
func _arm_timer() -> void:
	var left := WINDOW_SEC - World.marked_ago(LAUNCH_MARK)
	if left > 0.0 and left <= WINDOW_SEC and _closing_timer == null:
		_closing_timer = get_tree().create_timer(left + TIMER_MARGIN_SEC, false)
		_closing_timer.timeout.connect(refresh)
