class_name Door
extends Interactable
## Дверь между комнатами с условием открытия.
##
## Условие записывается одной строкой в инспекторе. Закрытая дверь всегда объясняет,
## что нужно сделать, чтобы она открылась. Если дверь уже нарисована на фоне комнаты,
## заглушка двери отключается флажком drawn.

const COLOR_OPEN := Color("5a3a22")
const COLOR_LOCKED := Color("33261c")

@export var target_room: String = ""
@export var target_spawn: String = "start"
@export var open_when: String = ""
@export var locked_text_key: String = "LOCK_DEFAULT"
@export var drawn: bool = true

var _condition: Condition = null

@onready var _body: ColorRect = $Body
@onready var _plate: Plate = $Plate


## Разбирает условие открытия и подписывается на изменения мира.
func _ready() -> void:
	super()
	action = ACTION_ENTER
	if prompt_key.is_empty():
		prompt_key = "PROMPT_ENTER"
	_body.visible = drawn
	_condition = Condition.new(open_when)
	World.changed.connect(_on_world_changed)
	World.marked.connect(_on_world_marked)
	refresh()


## Сообщает, открыта ли дверь сейчас.
## Возвращает true, если условие открытия выполнено.
func is_open() -> bool:
	return _condition.is_met()


## Обновляет вид двери и подпись на табличке.
func refresh() -> void:
	_body.color = COLOR_OPEN if is_open() else COLOR_LOCKED
	_plate.show_text(plate_text())
	_plate.modulate = Palette.TEXT if is_open() else Palette.NEUTRAL


## Собирает подпись таблички.
## Возвращает название комнаты за дверью, например «214 · Вальштейн», или пустую строку.
func plate_text() -> String:
	if not LocationCatalog.has(target_room):
		return ""
	return tr(LocationCatalog.title_key(target_room))


## Переводит героя в комнату за дверью или объясняет, почему дверь закрыта.
## [param _player] - герой, который открывает дверь.
func _interact(_player: Player) -> void:
	if not is_open():
		Ui.toast(tr(locked_text_key), ToastStack.KIND_HINT)
	elif not LocationCatalog.is_built(target_room):
		Ui.toast(tr("LOCK_NOT_BUILT"), ToastStack.KIND_HINT)
	else:
		Game.goto_room(target_room, target_spawn)


## Перепроверяет условие, когда меняется переменная мира.
## [param _key] - имя переменной; условие вычисляется целиком.
## [param _value] - новое значение переменной.
func _on_world_changed(_key: String, _value: Variant) -> void:
	refresh()


## Перепроверяет условие, когда в мире появляется новая отметка.
## [param _id] - имя отметки; условие вычисляется целиком.
func _on_world_marked(_id: String) -> void:
	refresh()
