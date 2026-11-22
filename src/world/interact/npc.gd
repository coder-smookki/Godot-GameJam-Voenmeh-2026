class_name Npc
extends Interactable
## Персонаж или предмет, с которым можно поговорить: преподаватель, доска объявлений.
##
## Разговор берётся из [DialogueCatalog] по коду. После первого разговора можно поставить
## отметку, увеличить счётчик и показать тост: так выдаются предметы и находки.
## Если персонаж или предмет уже нарисован на фоне комнаты, заглушка отключается флажком drawn.
## Условие present_when проверяется при входе в комнату: так персонаж уходит между визитами.

@export var talk_id: String = ""
@export var mark_id: String = ""
@export var counter_key: String = ""
@export var toast_key: String = ""
@export var drawn: bool = true
@export var present_when: String = ""

@onready var _body: Node2D = $Body
@onready var _shadow: Node2D = $Shadow


## Убирает персонажа, которого сейчас здесь нет; ставит подсказку «говорить», если она
## не задана в инспекторе, и прячет заглушку.
func _ready() -> void:
	if not Condition.new(present_when).is_met():
		queue_free()
		return
	super()
	if prompt_key.is_empty():
		prompt_key = "PROMPT_TALK"
	_body.visible = drawn
	_shadow.visible = drawn


## Проигрывает разговор и после первого раза выдаёт то, что настроено в инспекторе.
## [param _player] - герой, который начал разговор.
func _interact(_player: Player) -> void:
	if not await Ui.dialogue.play(DialogueCatalog.talk(talk_id)):
		return
	if mark_id.is_empty() or World.is_marked(mark_id):
		return
	World.mark(mark_id)
	if not counter_key.is_empty():
		World.bump(counter_key)
	if not toast_key.is_empty():
		Ui.toast(tr(toast_key).format(World.f), ToastStack.KIND_HINT)
	SaveSystem.save_game()
