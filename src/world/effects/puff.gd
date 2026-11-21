class_name Puff
extends CPUParticles2D
## Облачко пыли из-под ног: вылетает один раз и убирает себя само.
##
## Ставится в точку, где ступня коснулась пола: прыжок, приземление, шаг.

const SCENE_PATH := "res://src/world/effects/puff.tscn"
const STEP_AMOUNT := 2
const JUMP_AMOUNT := 7


## Создаёт облачко в заданной точке комнаты.
## [param parent] - узел комнаты, в котором останется облачко, когда персонаж уйдёт.
## [param at] - точка на полу в координатах мира.
## [param count] - сколько пылинок вылетает.
static func spawn(parent: Node, at: Vector2, count: int = JUMP_AMOUNT) -> void:
	var puff: Puff = load(SCENE_PATH).instantiate()
	puff.amount = count
	parent.add_child(puff)
	puff.global_position = at


## Запускает пылинки и удаляет узел, когда они погасли.
func _ready() -> void:
	finished.connect(queue_free)
	emitting = true
