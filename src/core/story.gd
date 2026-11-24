extends Node
## Ход сюжета: какое задание показать и что меняется в мире после ключевых событий.
##
## Реагирует на отметки мира. Комнаты и объекты только ставят отметки,
## а что из этого следует, описано здесь в одной таблице. Здесь же разговоры,
## которые начинаются сами, когда герой входит в комнату, и плашки над головой героя.

const SEEN_PREFIX := "seen_"
const ARRIVALS: Dictionary = {
	"vestibule": ["vestibule_arrival"],
	"corridor_2": ["corridor_2_arrival"],
	"lift": ["elevator_first", "lestenko"],
}
const ENTRY_MARKS: Dictionary = {"316": "cat_joined", "corridor_4": "reached_floor_4"}
const ARRIVAL_CONDITIONS: Dictionary = {
	"lestenko": "is_marked('boss_2')",
}
const STEPS: Dictionary = {
	"heard_scream": {"task": "TASK_FIND_SCREAM"},
	"vanya_saved": {"task": "TASK_GO_FLOOR_2"},
	"seen_corridor_2_arrival": {"task": "TASK_FIND_HELP", "infect_floor": 2, "infection": 10.0},
	"ability_debugger": {"task": "TASK_DEBUG_CODE", "announce": "ANNOUNCE_DEBUGGER"},
	"first_totem": {"task": "TASK_TALK_VALSHTEIN"},
	"seen_valshtein": {"task": "TASK_FIGHT_COMPILER"},
	"ability_2": {"announce": "ANNOUNCE_ABILITY_2"},
	"boss_2": {"task": "TASK_GO_FLOOR_3", "announce": "ANNOUNCE_BUTTON_3"},
	"boss_3": {"task": "TASK_GO_FLOOR_4", "announce": "ANNOUNCE_BUTTON_4"},
	"reached_floor_4": {"task": "TASK_PASS_BLOB"},
	"blob_corridor_4": {"task": "TASK_ROOM_418"},
	"boss_4": {"task": "TASK_GO_FLOOR_5", "announce": "ANNOUNCE_BUTTON_5"},
	"boss_5": {"task": "TASK_GO_ROOF", "announce": "ANNOUNCE_ROOF"},
	"seen_lestenko": {"announce": "ANNOUNCE_RAM"},
}


## Подписывается на вход в комнату и отметки мира.
## Первое задание появляется не сразу, а когда герой слышит крик из гардероба.
func _ready() -> void:
	Game.room_entered.connect(_on_room_entered)
	World.marked.connect(_on_world_marked)


## Проигрывает разговор, если игрок его ещё не видел, и запоминает это отметкой.
## Прерванный разговор не считается увиденным и начнётся снова.
## [param talk_id] - код разговора из [DialogueCatalog].
## Возвращает true, если разговор был доигран до конца сейчас.
func play_once(talk_id: String) -> bool:
	var mark := SEEN_PREFIX + talk_id
	if World.is_marked(mark) or not DialogueCatalog.has(talk_id):
		return false
	if not await Ui.dialogue.play(DialogueCatalog.talk(talk_id)):
		return false
	World.mark(mark)
	SaveSystem.save_game()
	return true


## Показывает над головой героя плашку с текстом, если герой сейчас в комнате.
## [param text_key] - ключ текста плашки.
func announce(text_key: String) -> void:
	var room := get_tree().current_scene as Room
	if room != null and is_instance_valid(room.player):
		room.player.announce(tr(text_key))


## По очереди начинает разговоры, которыми герой встречает комнату.
## Разговор с условием начинается, только когда условие выполнено.
## [param code] - код комнаты, в которую вошёл герой.
func _on_room_entered(code: String) -> void:
	if ENTRY_MARKS.has(code):
		World.mark(ENTRY_MARKS[code])
	for talk_id: String in ARRIVALS.get(code, []):
		if not Condition.new(ARRIVAL_CONDITIONS.get(talk_id, "")).is_met():
			continue
		if Game.room_code != code:
			return
		await play_once(talk_id)


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
	if step.has("announce"):
		announce(step["announce"])


## Выдаёт послание ЛАБЫ один раз: отметка, счётчик посланий и тост с текстом послания.
## [param mark] - отметка послания, например "message_2".
## [param text_key] - ключ текста послания.
func give_message(mark: String, text_key: String) -> void:
	if not World.mark(mark):
		return
	World.bump("messages")
	Ui.toast(tr("TOAST_MESSAGE").format(World.f), ToastStack.KIND_LABA)
	Ui.toast(tr(text_key), ToastStack.KIND_LABA)
