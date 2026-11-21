extends Control
## Слайд концовки: номер, название и две строки текста под картинкой.
##
## Шуточная и плохая концовки сами возвращают в игру через 10 секунд,
## основные и секретная ведут в главное меню.

const AUTO_RETURN_SEC := 10.0

var _done: bool = false

@onready var _header: Label = $Header
@onready var _text: Label = $Text
@onready var _timer: Timer = $AutoReturn


## Показывает концовку, которую подготовила игра.
func _ready() -> void:
	var ending_id := Game.pending_ending
	var header: Dictionary = {
		"number": EndingCatalog.number(ending_id),
		"total": EndingCatalog.total(),
		"title": tr(EndingCatalog.title_key(ending_id)),
	}
	_header.text = tr("ENDING_HEADER").format(header)
	_text.text = tr(EndingCatalog.text_key(ending_id))
	_timer.timeout.connect(_finish)
	if not EndingCatalog.is_final(ending_id):
		_timer.start(AUTO_RETURN_SEC)


## Закрывает слайд по клавише подтверждения или клику.
## [param event] - событие ввода.
func _unhandled_input(event: InputEvent) -> void:
	var pressed := event.is_action_pressed("ui_accept") or event.is_action_pressed("interact")
	if event is InputEventMouseButton:
		pressed = event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	if not pressed or Game.is_busy():
		return
	get_viewport().set_input_as_handled()
	_finish()


## Завершает показ один раз, даже если таймер и клавиша сработали одновременно.
func _finish() -> void:
	if _done:
		return
	_done = true
	_timer.stop()
	Game.finish_ending()
