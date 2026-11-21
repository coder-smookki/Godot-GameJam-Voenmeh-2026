class_name ElevatorDoor
extends Interactable
## Двери лифта: открывают панель выбора этажа.
##
## Пока лифт не работает, двери объясняют, что нужно сделать сначала.
## Если лифт уже нарисован на фоне комнаты, заглушка отключается флажком drawn.

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
## [param _player] - герой, который вызвал лифт.
func _interact(_player: Player) -> void:
	if Elevator.is_working():
		Ui.elevator.open()
	else:
		Ui.toast(tr("LOCK_ELEVATOR_EARLY"), ToastStack.KIND_HINT)
