extends Node
## Ход сюжета: какое задание показать и что меняется в мире после ключевых событий.
##
## Реагирует на отметки мира. Комнаты и объекты только ставят отметки,
## а что из этого следует, описано здесь в одной таблице. Здесь же разговоры,
## которые начинаются сами, когда герой впервые входит в комнату.

const START_TASK := "TASK_FIND_SCREAM"
const SEEN_PREFIX := "seen_"
const ARRIVALS: Dictionary = {
	"vestibule": "vestibule_arrival",
	"corridor_2": "corridor_2_arrival",
}
const STEPS: Dictionary = {
	"vanya_saved": {"task": "TASK_GO_FLOOR_2"},
	"seen_corridor_2_arrival": {"task": "TASK_GO_KAFEDRA", "infect_floor": 2, "infection": 10.0},
	"laba_seen": {"task": "TASK_GET_DEBUGGER"},
	"ability_debugger": {"task": "TASK_BREAK_TOTEM"},
	"first_totem": {"task": "TASK_TALK_VALSHTEIN"},
}


## Подписывается на начало игры, вход в комнату и отметки мира.
func _ready() -> void:
	Game.game_started.connect(_on_game_started)
	Game.room_entered.connect(_on_room_entered)
	World.marked.connect(_on_world_marked)


## Проигрывает разговор, если игрок его ещё не видел, и запоминает это отметкой.
## Прерванный разговор не считается увиденным и начнётся снова.
## [param talk_id] - код разговора из [DialogueCatalog].
func play_once(talk_id: String) -> void:
	var mark := SEEN_PREFIX + talk_id
	if World.is_marked(mark) or not DialogueCatalog.has(talk_id):
		return
	if await Ui.dialogue.play(DialogueCatalog.talk(talk_id)):
		World.mark(mark)
		SaveSystem.save_game()


## Ставит первое задание в начале новой игры.
func _on_game_started() -> void:
	Game.set_task(START_TASK)


## Начинает разговор, которым герой встречает новую комнату.
## [param code] - код комнаты, в которую вошёл герой.
func _on_room_entered(code: String) -> void:
	if ARRIVALS.has(code):
		play_once(ARRIVALS[code])


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
