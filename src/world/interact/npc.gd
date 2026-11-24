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
## idle_pose. Кадры смотрят влево, если не включён faces_right.
## Персонаж с кодом speaker слушает и чужие разговоры (например, тот, что начинается сам при
## входе в комнату): на своих репликах он поворачивается к герою и встаёт в позу talk_pose,
## на остальных - в idle_pose. Когда в мире появляется отметка leave_mark, персонаж уходит
## к точке leave_to_x и тает.

const DEFAULT_POSE := "neutral"
const LEAVE_SPEED := 70.0
const LEAVE_FADE_SEC := 0.4
const LEAVE_BOB := 2.0

@export var talk_id: String = ""
@export var mark_id: String = ""
@export var counter_key: String = ""
@export var toast_key: String = ""
@export var drawn: bool = true
@export var present_when: String = ""
@export var poses: Dictionary = {}
@export var idle_pose: String = DEFAULT_POSE
@export var faces_right: bool = false
@export var speaker: String = ""
@export var talk_pose: String = ""
@export var leave_mark: String = ""
@export var leave_to_x: float = 0.0

var _talking: bool = false

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
	if not speaker.is_empty():
		Ui.dialogue.line_shown.connect(_on_any_line)
		Ui.dialogue.visibility_changed.connect(_on_dialogue_toggled)
	if not leave_mark.is_empty():
		World.marked.connect(_on_world_marked)


## Меняет кадр персонажа; неизвестная поза ничего не меняет.
## [param pose_name] - имя позы из poses.
func set_pose(pose_name: String) -> void:
	var texture: Texture2D = poses.get(pose_name)
	if texture == null:
		return
	_sprite.texture = texture
	_sprite.offset = Vector2(-texture.get_width() * 0.5, -texture.get_height())


## Поворачивает персонажа вправо или влево.
## [param right] - true, чтобы персонаж смотрел вправо.
func face_right(right: bool) -> void:
	_sprite.flip_h = right != faces_right


## Возвращает текстуру позы, которая показана сейчас; нужно тестам.
func current_texture() -> Texture2D:
	return _sprite.texture


## Проигрывает разговор и после первого раза выдаёт то, что настроено в инспекторе.
## [param player] - герой, который начал разговор.
func _interact(player: Player) -> void:
	face_right(player.global_position.x > global_position.x)
	_talking = true
	Ui.dialogue.line_shown.connect(_on_line_shown)
	var finished: bool = await Ui.dialogue.play(DialogueCatalog.talk(talk_id))
	Ui.dialogue.line_shown.disconnect(_on_line_shown)
	_talking = false
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


## Ставит позу по реплике любого разговора: свою реплику персонаж говорит лицом к герою.
## [param line] - реплика, которая сейчас показана.
func _on_any_line(line: Dictionary) -> void:
	if _talking:
		return
	if str(line.get("speaker", "")) != speaker:
		set_pose(idle_pose)
		return
	var room := get_tree().current_scene as Room
	if room != null and is_instance_valid(room.player):
		face_right(room.player.global_position.x > global_position.x)
	set_pose(str(line.get("pose", talk_pose)))


## Возвращает спокойную позу, когда окно разговора закрылось.
func _on_dialogue_toggled() -> void:
	if not Ui.dialogue.visible and not _talking:
		set_pose(idle_pose)


## Уходит, когда в мире появилась отметка ухода: идёт к точке ухода, покачиваясь, и тает.
## [param id] - имя новой отметки.
func _on_world_marked(id: String) -> void:
	if id != leave_mark:
		return
	set_focused(false)
	set_deferred("monitorable", false)
	set_pose(idle_pose)
	face_right(leave_to_x > global_position.x)
	var sec := absf(leave_to_x - global_position.x) / LEAVE_SPEED
	var walk := create_tween()
	walk.tween_property(self, "position:x", leave_to_x, sec)
	walk.tween_property(self, "modulate:a", 0.0, LEAVE_FADE_SEC)
	walk.tween_callback(queue_free)
	var bob := create_tween().set_loops(maxi(ceili(sec / 0.3), 1))
	bob.tween_property(_sprite, "position:y", -LEAVE_BOB, 0.15)
	bob.tween_property(_sprite, "position:y", 0.0, 0.15)
