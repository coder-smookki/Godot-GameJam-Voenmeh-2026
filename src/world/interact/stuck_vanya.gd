class_name StuckVanya
extends Interactable
## Ваня в гардеробе: сначала застрял в шахматке, после мини-игры «Тяни!» свободен.
##
## С каждым рывком Ваня выходит из шахматки на треть, а ком шахматки сжимается.

const SAVED_MARK := "vanya_saved"
const SPEAKER := "NAME_VANYA"
const STUCK_SHIFT := 54.0
const BLOB_SMALL := 0.35
const RESCUE_LINES: Array[String] = ["VANYA_RESCUE_1", "VANYA_RESCUE_2"]
const AFTER_LINES: Array[String] = ["VANYA_AFTER"]

@onready var _body: Node2D = $Body
@onready var _blob: ColorRect = $Blob
@onready var _cry: Plate = $Cry


## Показывает Ваню застрявшим или свободным по состоянию мира.
func _ready() -> void:
	super()
	_show_progress(1.0 if World.is_marked(SAVED_MARK) else 0.0)


## Собирает текст подсказки: схватить за руку или поговорить.
## Возвращает строку подсказки с клавишей.
func prompt_text() -> String:
	prompt_key = "PROMPT_TALK" if World.is_marked(SAVED_MARK) else "PROMPT_GRAB_HAND"
	return super()


## Запускает мини-игру спасения, а после неё разговор; спасённый Ваня просто разговаривает.
## [param _player] - герой, который подошёл к Ване.
func _interact(_player: Player) -> void:
	if World.is_marked(SAVED_MARK):
		Ui.dialogue.play(_lines(AFTER_LINES))
		return
	set_focused(false)
	_cry.hide()
	Ui.pull.jerk_done.connect(_on_jerk_done)
	await Ui.pull.play()
	Ui.pull.jerk_done.disconnect(_on_jerk_done)
	World.mark(SAVED_MARK)
	SaveSystem.save_game()
	set_focused(true)
	Ui.dialogue.play(_lines(RESCUE_LINES))


## Собирает реплики Вани для окна разговора.
## [param keys] - ключи текста реплик по порядку.
## Возвращает массив реплик в формате окна разговора.
func _lines(keys: Array[String]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for key: String in keys:
		result.append({"speaker": SPEAKER, "text": key})
	return result


## Двигает Ваню и ком шахматки после рывка.
## [param index] - сколько рывков уже сделано.
func _on_jerk_done(index: int) -> void:
	_show_progress(float(index) / float(PullLogic.JERKS))


## Показывает, насколько Ваня вышел из шахматки.
## [param progress] - от 0 (застрял) до 1 (свободен).
func _show_progress(progress: float) -> void:
	_body.position.x = STUCK_SHIFT * (1.0 - progress)
	var blob_scale := lerpf(1.0, BLOB_SMALL, progress)
	_blob.scale = Vector2(blob_scale, blob_scale)
	_cry.visible = progress <= 0.0
