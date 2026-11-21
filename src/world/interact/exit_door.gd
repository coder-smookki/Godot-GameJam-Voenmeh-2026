class_name ExitDoor
extends Door
## Выход на улицу из вестибюля: развилка P1 «Уйти домой».
##
## Дверь работает, пока герой не уехал на лифте. Через неё можно один раз уйти
## в шуточную концовку, после которой игра возвращает героя в вестибюль.

const ENDING := "expelled"


## Сообщает, можно ли ещё уйти через дверь.
## Возвращает true, пока игрок не пробовал уйти и не пользовался лифтом.
func is_open() -> bool:
	return not World.f["escape_tried"] and not World.is_marked(Elevator.USED_MARK)


## Собирает подпись таблички: пусто, пока дверь работает, и «404», когда выхода больше нет.
## Возвращает текст таблички.
func plate_text() -> String:
	return "" if is_open() else tr("DOOR_404")


## Уводит героя в концовку «Отчислен» или объясняет, почему уйти нельзя.
## [param _player] - герой, который открывает дверь.
func _interact(_player: Player) -> void:
	if is_open():
		World.choose("escape_tried", true, "FORK_P1_TOAST")
		Game.show_ending(ENDING)
	else:
		Ui.toast(tr("LOCK_EXIT_404"), ToastStack.KIND_HINT)
