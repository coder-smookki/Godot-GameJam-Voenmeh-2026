extends Node
## Заражение этажей корпуса.
##
## Заражение растёт на активных этажах, где игрока сейчас нет, и падает,
## когда игрок разбивает тотемы. Вылеченный этаж больше не заражается.

signal changed(level: int, percent: int)

const GROWTH_PER_MINUTE := 1.0
const GROWTH_CAP := 85.0
const LIMIT := 100.0
const LATE_FLOOR_PENALTY := 25.0

var current_floor: int = 1

var _levels: Dictionary = {}
var _cured: Dictionary = {}


## Останавливает обработку кадров, пока нет ни одного заражённого этажа.
func _ready() -> void:
	set_process(false)


## Двигает заражение каждый кадр.
## [param delta] - время кадра в секундах; на паузе функция не вызывается.
func _process(delta: float) -> void:
	advance(delta)


## Растит заражение на активных этажах, кроме текущего.
## [param delta] - сколько игрового времени прошло, в секундах.
func advance(delta: float) -> void:
	var step := GROWTH_PER_MINUTE * delta / 60.0
	for level: int in _levels:
		if level == current_floor or float(_levels[level]) >= GROWTH_CAP:
			continue
		_set_level(level, minf(float(_levels[level]) + step, GROWTH_CAP))


## Сбрасывает заражение в начале новой игры.
func reset() -> void:
	_levels = {}
	_cured = {}
	current_floor = 1
	set_process(false)


## Включает заражение этажа.
## [param level] - номер этажа.
## [param initial] - начальный процент заражения.
func start(level: int, initial: float = 0.0) -> void:
	if _cured.has(level) or _levels.has(level):
		return
	_levels[level] = -1.0
	_set_level(level, clampf(initial, 0.0, LIMIT))
	set_process(true)


## Сообщает, идёт ли заражение на этаже.
## [param level] - номер этажа.
## Возвращает true, если этаж заражается и ещё не вылечен.
func is_active(level: int) -> bool:
	return _levels.has(level)


## Сообщает, вылечен ли этаж окончательно.
## [param level] - номер этажа.
## Возвращает true, если этаж вылечен.
func is_cured(level: int) -> bool:
	return _cured.has(level)


## Возвращает заражение этажа для интерфейса.
## [param level] - номер этажа.
## Возвращает целый процент от 0 до 100; для неактивного этажа 0.
func percent(level: int) -> int:
	return int(floor(float(_levels.get(level, 0.0))))


## Добавляет заражение за действие игрока (хак, тревога, штраф за второй этаж).
## [param level] - номер этажа.
## [param amount] - сколько процентов добавить; может поднять заражение до 100.
func add(level: int, amount: float) -> void:
	if _levels.has(level):
		_set_level(level, clampf(float(_levels[level]) + amount, 0.0, LIMIT))


## Снижает заражение этажа, например после разбитого тотема.
## [param level] - номер этажа.
## [param amount] - сколько процентов снять.
func heal(level: int, amount: float) -> void:
	add(level, -absf(amount))


## Лечит этаж окончательно: заражение обнуляется и больше не растёт.
## [param level] - номер этажа.
func cure(level: int) -> void:
	if _levels.has(level):
		_set_level(level, 0.0)
		_levels.erase(level)
	_cured[level] = true
	set_process(not _levels.is_empty())


## Упаковывает заражение для сохранения.
## Возвращает словарь с уровнями этажей, вылеченными этажами и текущим этажом.
func to_dict() -> Dictionary:
	var levels: Dictionary = {}
	for level: int in _levels:
		levels[str(level)] = _levels[level]
	var cured: Array[int] = []
	cured.assign(_cured.keys())
	return {"levels": levels, "cured": cured, "current_floor": current_floor}


## Восстанавливает заражение из сохранения, отбрасывая испорченные значения.
## [param data] - словарь из [method to_dict], возможно прочитанный из JSON.
func from_dict(data: Dictionary) -> void:
	reset()
	var cured: Variant = data.get("cured", [])
	if cured is Array:
		for level: Variant in cured:
			if _is_number(level):
				_cured[int(level)] = true
	var levels: Variant = data.get("levels", {})
	if levels is Dictionary:
		for key: Variant in levels:
			if str(key).is_valid_int() and _is_number(levels[key]):
				start(int(str(key)), float(levels[key]))
	if _is_number(data.get("current_floor", 1)):
		current_floor = int(data.get("current_floor", 1))


## Записывает уровень этажа и сообщает об изменении, только если сменился целый процент.
## [param level] - номер этажа.
## [param value] - новый уровень в процентах.
func _set_level(level: int, value: float) -> void:
	var before := int(floor(float(_levels[level])))
	_levels[level] = value
	var after := int(floor(value))
	if after != before:
		changed.emit(level, after)


## Проверяет, что значение является числом.
## [param value] - проверяемое значение.
## Возвращает true для целых и дробных чисел.
func _is_number(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT
