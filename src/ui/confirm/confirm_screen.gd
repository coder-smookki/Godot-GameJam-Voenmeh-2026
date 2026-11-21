class_name ConfirmScreen
extends Modal
## Вопрос с ответами «да» и «нет» перед действием, которое нельзя отменить.
##
## Закрытие клавишей отмены считается ответом «нет».

signal answered(accepted: bool)

var _pending: bool = false

@onready var _text: Label = $Panel/Box/Text
@onready var _yes: Button = $Panel/Box/Buttons/Yes
@onready var _no: Button = $Panel/Box/Buttons/No


## Привязывает кнопки ответа.
func _ready() -> void:
	_yes.pressed.connect(_answer.bind(true))
	_no.pressed.connect(_answer.bind(false))


## Задаёт вопрос и ждёт ответа игрока.
## [param text_key] - ключ текста вопроса.
## Возвращает true, если игрок ответил «да».
func ask(text_key: String) -> bool:
	_text.text = tr(text_key)
	_pending = true
	open()
	_no.grab_focus()
	var accepted: bool = await answered
	close()
	return accepted


## Отвечает «нет», если окно закрыли без выбора.
func _closed() -> void:
	_answer(false)


## Сообщает ответ один раз.
## [param accepted] - true для ответа «да».
func _answer(accepted: bool) -> void:
	if not _pending:
		return
	_pending = false
	answered.emit(accepted)
