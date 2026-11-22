class_name LiftButtons
extends Interactable
## Панель кнопок на стене кабины: открывает её крупным планом, чтобы выбрать этаж.


## Ставит подсказку «нажать кнопку».
func _ready() -> void:
	super()
	prompt_key = "PROMPT_LIFT_BUTTONS"


## Открывает панель кнопок.
## [param _player] - герой, который подошёл к панели.
func _interact(_player: Player) -> void:
	Ui.elevator.open()
