class_name Modal
extends Control
## Основа для экранов поверх игры: диалог, развилка, телефон, пауза, меню разработчика.
##
## Пока открыт хотя бы один такой экран, мир стоит на паузе.

@export var closable: bool = true


## Открывает экран и ставит мир на паузу.
func open() -> void:
	if visible:
		return
	Ui.open_modal(self)
	_opened()


## Закрывает экран; пауза снимается, когда закрыт последний экран.
func close() -> void:
	if not visible:
		return
	Ui.close_modal(self)
	_closed()


## Вызывается после открытия; наследники заполняют здесь содержимое.
func _opened() -> void:
	pass


## Вызывается после закрытия; наследники освобождают здесь содержимое.
func _closed() -> void:
	pass
