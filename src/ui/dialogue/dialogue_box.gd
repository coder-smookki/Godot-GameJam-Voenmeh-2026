class_name DialogueBox
extends Modal
## Окно разговора: имя, печатающийся текст и варианты ответа.
##
## Показывает уже готовые реплики. Откуда они берутся (файл диалога, сценарий комнаты),
## окну не важно, поэтому систему диалогов можно заменить, не трогая этот экран.

signal typed
signal advanced
signal picked(index: int)

const CHARS_PER_SEC := 45.0

var _typing: bool = false
var _waiting: bool = false
var _shown: float = 0.0

@onready var _name: Label = $Panel/Row/Box/Name
@onready var _text: Label = $Panel/Row/Box/Text
@onready var _choices: VBoxContainer = $Panel/Row/Box/Choices


## Выключает покадровую обработку, пока текст не печатается.
func _ready() -> void:
	set_process(false)


## Печатает текст реплики по буквам.
## [param delta] - время кадра в секундах.
func _process(delta: float) -> void:
	_shown += CHARS_PER_SEC * delta
	_text.visible_characters = int(_shown)
	if _text.visible_characters >= _text.get_total_character_count():
		_finish_typing()


## Пропускает печать или переходит к следующей реплике по клавише или клику.
## [param event] - событие ввода.
func _input(event: InputEvent) -> void:
	if not visible or not (_typing or _waiting):
		return
	var pressed := event.is_action_pressed("ui_accept") or event.is_action_pressed("interact")
	if event is InputEventMouseButton:
		pressed = event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	if not pressed:
		return
	get_viewport().set_input_as_handled()
	if _typing:
		_finish_typing()
	else:
		_waiting = false
		advanced.emit()


## Проигрывает разговор от первой реплики до последней.
## [param lines] - массив реплик; у реплики ключи speaker (ключ имени), text (ключ текста)
## и необязательный choices (массив ключей вариантов ответа).
## Возвращает номер варианта, выбранного в последней реплике с вариантами, или -1.
func play(lines: Array[Dictionary]) -> int:
	open()
	var answer := -1
	for line: Dictionary in lines:
		var choice := await _show_line(line)
		if choice >= 0:
			answer = choice
	close()
	return answer


## Показывает одну реплику и ждёт игрока.
## [param line] - словарь реплики.
## Возвращает номер выбранного варианта или -1, если вариантов не было.
func _show_line(line: Dictionary) -> int:
	_clear_choices()
	_name.text = tr(str(line.get("speaker", "")))
	_text.text = tr(str(line.get("text", "")))
	_text.visible_characters = 0
	_shown = 0.0
	_typing = true
	set_process(true)
	await typed
	var options: Array = line.get("choices", [])
	if options.is_empty():
		_waiting = true
		await advanced
		return -1
	for index: int in options.size():
		var button := Button.new()
		button.text = tr(str(options[index]))
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(picked.emit.bind(index))
		_choices.add_child(button)
	_choices.get_child(0).grab_focus()
	var choice: int = await picked
	_clear_choices()
	return choice


## Показывает реплику целиком и сообщает, что печать закончена.
func _finish_typing() -> void:
	_typing = false
	set_process(false)
	_text.visible_characters = -1
	typed.emit()


## Убирает кнопки вариантов прошлой реплики.
func _clear_choices() -> void:
	for child: Node in _choices.get_children():
		_choices.remove_child(child)
		child.queue_free()
