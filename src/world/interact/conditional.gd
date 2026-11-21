class_name Conditional
extends Node2D
## Узел, который виден только пока выполняется условие мира.
##
## Нужен для подсказок и декораций, которые появляются и исчезают по ходу сюжета:
## крик из-за двери, пятна шахматки, подсветка цели.

@export var visible_when: String = ""

var _condition: Condition = null


## Разбирает условие и подписывается на изменения мира.
func _ready() -> void:
	_condition = Condition.new(visible_when)
	World.changed.connect(_on_world_changed)
	World.marked.connect(_on_world_marked)
	World.reloaded.connect(refresh)
	refresh()


## Показывает или прячет узел по текущему состоянию мира.
func refresh() -> void:
	visible = _condition.is_met()


## Перепроверяет условие, когда меняется переменная мира.
## [param _key] - имя переменной; условие вычисляется целиком.
## [param _value] - новое значение переменной.
func _on_world_changed(_key: String, _value: Variant) -> void:
	refresh()


## Перепроверяет условие, когда в мире появляется новая отметка.
## [param _id] - имя отметки; условие вычисляется целиком.
func _on_world_marked(_id: String) -> void:
	refresh()
