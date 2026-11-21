extends Control
## Экран концовки и эпилога: слайд концовки, затем слайды последствий по каждому персонажу.
##
## Шуточные и плохая концовки показывают один слайд и сами возвращают в игру через 10 секунд.

const AUTO_RETURN_SEC := 10.0

var _pages: Array[Dictionary] = []
var _index: int = 0
var _done: bool = false

@onready var _header: Label = $Box/Header
@onready var _title: Label = $Box/Title
@onready var _text: Label = $Box/Text
@onready var _why_panel: PanelContainer = $Box/WhyPanel
@onready var _why: Label = $Box/WhyPanel/Why
@onready var _counter: Label = $Box/Counter
@onready var _timer: Timer = $AutoReturn


## Собирает страницы для концовки, которую готовит игра, и показывает первую.
func _ready() -> void:
	var ending_id := Game.pending_ending
	var header: Dictionary = {
		"number": EndingCatalog.number(ending_id),
		"title": tr(EndingCatalog.title_key(ending_id)),
	}
	_header.text = tr("EPILOGUE_HEADER").format(header)
	_pages = [{"title": "", "text": EndingCatalog.text_key(ending_id), "why": ""}]
	for slide: Dictionary in Epilogue.slides(ending_id):
		var page: Dictionary = {
			"title": Epilogue.title_key(slide["who"]),
			"text": Epilogue.text_key(slide),
			"why": Epilogue.why_key(slide),
		}
		_pages.append(page)
	_timer.timeout.connect(_finish)
	if not EndingCatalog.is_final(ending_id):
		_timer.start(AUTO_RETURN_SEC)
	_show_page()


## Листает слайды по клавише подтверждения или клику.
## [param event] - событие ввода.
func _unhandled_input(event: InputEvent) -> void:
	var pressed := event.is_action_pressed("ui_accept") or event.is_action_pressed("interact")
	if event is InputEventMouseButton:
		pressed = event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	if not pressed or Game.is_busy():
		return
	get_viewport().set_input_as_handled()
	_index += 1
	if _index >= _pages.size():
		_finish()
	else:
		_show_page()


## Показывает текущий слайд.
func _show_page() -> void:
	var page: Dictionary = _pages[_index]
	_title.text = tr(page["title"])
	_text.text = tr(page["text"])
	_why_panel.visible = page["why"] != ""
	_why.text = "%s\n%s" % [tr("EPILOGUE_BECAUSE"), tr(page["why"])]
	_counter.text = "%d/%d" % [_index + 1, _pages.size()]


## Завершает показ один раз, даже если таймер и клавиша сработали одновременно.
func _finish() -> void:
	if _done:
		return
	_done = true
	_timer.stop()
	Game.finish_ending()
