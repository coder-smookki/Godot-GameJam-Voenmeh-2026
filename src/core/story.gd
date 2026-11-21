extends Node
## Ход сюжета: какое задание показать и что меняется в мире после ключевых событий.
##
## Реагирует на отметки мира. Комнаты и объекты только ставят отметки,
## а что из этого следует, описано здесь в одной таблице.

const START_TASK := "TASK_GO_AUDITORIUM"
const STEPS: Dictionary = {
	"laba_launched": {"task": "TASK_GET_DEBUGGER", "infect_floor": 1, "infection": 10.0},
	"ability_debugger": {"task": "TASK_BREAK_TOTEM"},
	"first_totem": {"task": "TASK_FIND_STAIRS"},
}


## Подписывается на начало игры и отметки мира.
func _ready() -> void:
	Game.game_started.connect(_on_game_started)
	World.marked.connect(_on_world_marked)


## Ставит первое задание в начале новой игры.
func _on_game_started() -> void:
	Game.set_task(START_TASK)


## Выполняет шаг сюжета, привязанный к отметке.
## [param id] - имя новой отметки мира.
func _on_world_marked(id: String) -> void:
	if not STEPS.has(id):
		return
	var step: Dictionary = STEPS[id]
	if step.has("infect_floor"):
		Infection.start(int(step["infect_floor"]), float(step.get("infection", 0.0)))
	if step.has("task"):
		Game.set_task(step["task"])
