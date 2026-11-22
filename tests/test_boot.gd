extends Node
## Точка входа тестов: переносит запуск в корень дерева, чтобы смена сцен его не прервала.


## Создаёт [TestRunner] в корне дерева.
func _ready() -> void:
	var runner := TestRunner.new()
	get_tree().root.add_child.call_deferred(runner)
