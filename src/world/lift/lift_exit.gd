class_name LiftExit
extends Interactable
## Двери кабины: выводят героя обратно на тот этаж, где он вошёл в лифт.


## Ставит подсказку «выйти из лифта» на клавишу входа.
func _ready() -> void:
	super()
	action = ACTION_ENTER
	prompt_key = "PROMPT_LIFT_EXIT"


## Выводит героя из кабины.
## [param _player] - герой, который выходит.
func _interact(_player: Player) -> void:
	Game.leave_lift()
