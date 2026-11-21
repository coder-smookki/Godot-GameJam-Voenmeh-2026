class_name StuckVanya
extends Interactable
## Ваня в гардеробе: сначала застрял в шахматке, после мини-игры «Тяни!» свободен.
##
## Сцену спасения показывают кадры художниц: ком шахматки и герой, который тянет.
## С каждым рывком шахматка отступает на кадр. Слои нарисованы на холсте всей комнаты,
## поэтому лежат в координатах комнаты и не двигаются вместе с этим узлом.

const SAVED_MARK := "vanya_saved"
const RESCUE_TALK := "vanya_rescue"
const AFTER_TALK := "vanya_after"
const FREE_X := 660.0
const HERO_PULL_X := 500.0
const HERO_FREE_X := 560.0
const REMNANT_SCALE := 0.55
const SHRINK_SEC := 0.5
const FRAMES: Array[Texture2D] = [
	preload("res://assets/minigames/pull/pull_3.png"),
	preload("res://assets/minigames/pull/pull_2.png"),
	preload("res://assets/minigames/pull/pull_1.png"),
]

@onready var _body: Node2D = $Body
@onready var _shadow: Node2D = $Shadow
@onready var _cry: SpeechBubble = $Cry
@onready var _mass: Sprite2D = $Art/Mass
@onready var _pull: Sprite2D = $Art/Pull
@onready var _remnant: Sprite2D = $Art/Remnant
@onready var _barrier: CollisionShape2D = $Barrier/Shape


## Показывает Ваню застрявшим или свободным по состоянию мира.
func _ready() -> void:
	super()
	_show_state(World.is_marked(SAVED_MARK))


## Собирает текст подсказки: схватить за руку или поговорить.
## Возвращает строку подсказки с клавишей.
func prompt_text() -> String:
	prompt_key = "PROMPT_TALK" if World.is_marked(SAVED_MARK) else "PROMPT_GRAB_HAND"
	return super()


## Запускает мини-игру спасения, а после неё разговор; спасённый Ваня просто разговаривает.
## Разговор начинается, когда остаток шахматки сжался и больше не закрывает Ваню.
## [param player] - герой, который подошёл к Ване.
func _interact(player: Player) -> void:
	if World.is_marked(SAVED_MARK):
		Ui.dialogue.play(DialogueCatalog.talk(AFTER_TALK))
		return
	set_focused(false)
	_cry.hide()
	_mass.hide()
	player.hide()
	player.global_position.x = HERO_PULL_X
	_show_jerk(0)
	Ui.pull.jerk_done.connect(_show_jerk)
	await Ui.pull.play()
	Ui.pull.jerk_done.disconnect(_show_jerk)
	player.global_position.x = HERO_FREE_X
	player.show()
	World.mark(SAVED_MARK)
	_show_state(true)
	_remnant.scale = Vector2.ONE
	SaveSystem.save_game()
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(_remnant, "scale", Vector2(REMNANT_SCALE, REMNANT_SCALE), SHRINK_SEC)
	await tween.finished
	Ui.dialogue.play(DialogueCatalog.talk(RESCUE_TALK))


## Показывает кадр мини-игры: чем больше рывков сделано, тем дальше отступила шахматка.
## [param index] - сколько рывков уже сделано.
func _show_jerk(index: int) -> void:
	_pull.texture = FRAMES[mini(index, FRAMES.size() - 1)]
	_pull.show()


## Расставляет сцену: ком шахматки и преграда до спасения, Ваня и остаток шахматки после.
## [param saved] - true, если Ваня уже свободен.
func _show_state(saved: bool) -> void:
	_mass.visible = not saved
	_pull.hide()
	_remnant.visible = saved
	_remnant.scale = Vector2(REMNANT_SCALE, REMNANT_SCALE)
	_body.visible = saved
	_shadow.visible = saved
	_cry.visible = not saved
	_barrier.set_deferred("disabled", saved)
	if saved:
		position.x = FREE_X
