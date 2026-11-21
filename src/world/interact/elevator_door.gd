class_name ElevatorDoor
extends Interactable
## Двери лифта: открывают панель выбора этажа.
##
## Пока лифт не работает, двери объясняют, что нужно сделать сначала.
## Если лифт уже нарисован на фоне комнаты, заглушка отключается флажком drawn.

const FIRST_TALK := "elevator_first"

@export var drawn: bool = true

@onready var _body: Control = $Body
@onready var _plate: Plate = $Plate


## Ставит подсказку и прячет заглушку, если лифт нарисован на фоне.
func _ready() -> void:
	super()
	prompt_key = "PROMPT_ELEVATOR"
	_body.visible = drawn
	_plate.show_text(tr("ELEVATOR_PLATE") if drawn else "")


## Открывает панель этажей или объясняет, почему лифт пока не едет.
## В первый раз герой сначала замечает, что кнопок почти не осталось.
## [param _player] - герой, который вызвал лифт.
func _interact(_player: Player) -> void:
	if not Elevator.is_working():
		Ui.toast(tr("LOCK_ELEVATOR_EARLY"), ToastStack.KIND_HINT)
		return
	await Story.play_once(FIRST_TALK)
	Ui.elevator.open()
