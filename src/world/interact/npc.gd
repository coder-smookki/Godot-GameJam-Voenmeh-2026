class_name Npc
extends Interactable
## Персонаж или предмет, с которым можно поговорить: преподаватель, доска объявлений.
##
## Разговор берётся из [DialogueCatalog] по коду. После первого разговора можно поставить
## отметку, увеличить счётчик и показать тост: так выдаются предметы и находки.
## Если персонаж или предмет уже нарисован на фоне комнаты, заглушка отключается флажком drawn.
## Условие present_when проверяется при входе в комнату: так персонаж уходит между визитами.
## Персонаж с кадрами художниц (poses) рисуется ими вместо заглушки: в разговоре он
## поворачивается к герою, а реплика с полем pose меняет его позу; в покое показана поза
## idle_pose.

const DEFAULT_POSE := "neutral"

@export var talk_id: String = ""
@export var mark_id: String = ""
@export var counter_key: String = ""
@export var toast_key: String = ""
@export var drawn: bool = true
@export var present_when: String = ""
@export var poses: Dictionary = {}
@export var idle_pose: String = DEFAULT_POSE

@onready var _body: Node2D = $Body
@onready var _shadow: Node2D = $Shadow
@onready var _sprite: Sprite2D = $Sprite


## Убирает персонажа, которого сейчас здесь нет; ставит подсказку «говорить», если она
## не задана в инспекторе, и прячет заглушку.
func _ready() -> void:
	if not Condition.new(present_when).is_met():
		queue_free()
		return
	super()
	if prompt_key.is_empty():
		prompt_key = "PROMPT_TALK"
	_body.visible = drawn and poses.is_empty()
	_shadow.visible = drawn
	_sprite.visible = not poses.is_empty()
	set_pose(idle_pose)


## Меняет кадр персонажа; неизвестная поза ничего не меняет.
## [param pose_name] - имя позы из poses.
func set_pose(pose_name: String) -> void:
	var texture: Texture2D = poses.get(pose_name)
	if texture == null:
		return
	_sprite.texture = texture
	_sprite.offset = Vector2(-texture.get_width() * 0.5, -texture.get_height())


## Поворачивает персонажа вправо или влево; кадры художниц смотрят влево.
## [param right] - true, чтобы персонаж смотрел вправо.
func face_right(right: bool) -> void:
	_sprite.flip_h = right


## Возвращает текстуру позы, которая показана сейчас; нужно тестам.
func current_texture() -> Texture2D:
	return _sprite.texture


## Проигрывает разговор и после первого раза выдаёт то, что настроено в инспекторе.
## [param player] - герой, который начал разговор.
func _interact(player: Player) -> void:
	_sprite.flip_h = player.global_position.x > global_position.x
	Ui.dialogue.line_shown.connect(_on_line_shown)
	var finished: bool = await Ui.dialogue.play(DialogueCatalog.talk(talk_id))
	Ui.dialogue.line_shown.disconnect(_on_line_shown)
	if not is_inside_tree():
		return
	_sprite.flip_h = false
	set_pose(idle_pose)
	if not finished or mark_id.is_empty() or World.is_marked(mark_id):
		return
	World.mark(mark_id)
	if not counter_key.is_empty():
		World.bump(counter_key)
	if not toast_key.is_empty():
		Ui.toast(tr(toast_key).format(World.f), ToastStack.KIND_HINT)
	SaveSystem.save_game()


## Ставит позу, которую просит реплика.
## [param line] - реплика, которая сейчас показана.
func _on_line_shown(line: Dictionary) -> void:
	set_pose(str(line.get("pose", "")))
