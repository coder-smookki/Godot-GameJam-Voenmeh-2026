extends Node
## Журнал решений игрока.
##
## Записывает каждое решение в порядке принятия. Хранит только переменную и значение:
## текст строки собирает интерфейс телефона, поэтому правка текстов не ломает сохранения.

signal added(entry: Dictionary)
signal cleared

var _entries: Array[Dictionary] = []


## Подписывается на решения мира, чтобы записывать их автоматически.
func _ready() -> void:
	World.decided.connect(_on_world_decided)


## Добавляет запись о решении.
## [param key] - имя переменной мира.
## [param value] - выбранное значение.
func add(key: String, value: Variant) -> void:
	var entry: Dictionary = {"key": key, "value": value}
	_entries.append(entry)
	added.emit(entry)


## Возвращает все записи журнала.
## Возвращает копию массива словарей {key, value} от первой записи к последней.
func entries() -> Array[Dictionary]:
	return _entries.duplicate(true)


## Очищает журнал в начале новой игры.
func clear() -> void:
	_entries.clear()
	cleared.emit()


## Упаковывает журнал для сохранения.
## Возвращает массив записей, пригодный для записи в JSON.
func to_array() -> Array:
	return _entries.duplicate(true)


## Восстанавливает журнал из сохранения, пропуская испорченные записи.
## [param data] - массив из [method to_array], возможно прочитанный из JSON.
func from_array(data: Array) -> void:
	_entries.clear()
	for item: Variant in data:
		if item is Dictionary and item.get("key") is String and World.SCHEMA.has(item["key"]):
			if World.is_valid(item["key"], item.get("value")):
				var value: Variant = item["value"]
				if typeof(World.SCHEMA[item["key"]]["default"]) == TYPE_INT:
					value = int(value)
				_entries.append({"key": item["key"], "value": value})
	cleared.emit()


## Записывает решение, о котором сообщил мир.
## [param key] - имя переменной.
## [param value] - выбранное значение.
## [param _toast_key] - ключ тоста, журналу не нужен.
func _on_world_decided(key: String, value: Variant, _toast_key: String) -> void:
	add(key, value)
