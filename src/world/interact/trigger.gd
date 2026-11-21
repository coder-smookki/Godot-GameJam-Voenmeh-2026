class_name Trigger
extends Interactable
## Одноразовый объект: терминал запуска, шкаф с предметом, записка, коллекционная вещь.
##
## При взаимодействии ставит отметку в мире, при необходимости увеличивает счётчик,
## и показывает тост. После этого объект больше не срабатывает.

@export var mark_id: String = ""
@export var available_when: String = ""
@export var counter_key: String = ""
@export var toast_key: String = ""
@export var hide_when_used: bool = false

var _condition: Condition = null


## Разбирает условие доступности и прячет объект, если он уже использован.
func _ready() -> void:
	super()
	_condition = Condition.new(available_when)
	World.changed.connect(_on_world_changed)
	World.marked.connect(_on_world_marked)
	refresh()


## Сообщает, можно ли сейчас использовать объект.
## Возвращает true, если условие выполнено и объект ещё не использован.
func is_available() -> bool:
	return not World.is_marked(mark_id) and _condition.is_met()


## Включает или выключает объект по текущему состоянию мира.
func refresh() -> void:
	var available := is_available()
	set_deferred("monitorable", available)
	visible = available or not (hide_when_used and World.is_marked(mark_id))
	modulate.a = 1.0 if available else 0.45


## Ставит отметку и выполняет настроенные последствия.
## [param _player] - герой, который использовал объект.
func _interact(_player: Player) -> void:
	if mark_id.is_empty() or not is_available():
		return
	World.mark(mark_id)
	if not counter_key.is_empty():
		World.bump(counter_key)
	if not toast_key.is_empty():
		Ui.toast(tr(toast_key), ToastStack.KIND_HINT)
	SaveSystem.save_game()


## Перепроверяет доступность, когда меняется переменная мира.
## [param _key] - имя переменной; условие вычисляется целиком.
## [param _value] - новое значение переменной.
func _on_world_changed(_key: String, _value: Variant) -> void:
	refresh()


## Перепроверяет доступность, когда в мире появляется новая отметка.
## [param _id] - имя отметки; условие вычисляется целиком.
func _on_world_marked(_id: String) -> void:
	refresh()
