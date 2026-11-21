class_name Condition
extends RefCounted
## Условие, записанное одной строкой, например "logunova != '' and zeml != ''".
##
## Двери и объекты задают условия текстом в инспекторе. В выражении доступны
## все переменные мира по именам и функции мира: is_marked('id'), method(), laba_line().

var _expression: Expression = null
var _source: String = ""


## Разбирает текст условия один раз, чтобы потом проверять его без повторного разбора.
## [param source] - текст выражения; пустая строка означает «всегда верно».
func _init(source: String = "") -> void:
	_source = source.strip_edges()
	if _source.is_empty():
		return
	_expression = Expression.new()
	if _expression.parse(_source, PackedStringArray(World.SCHEMA.keys())) != OK:
		push_error("Condition: ошибка в условии «%s»: %s" % [_source, _expression.get_error_text()])
		_expression = null


## Проверяет условие на текущем состоянии мира.
## Возвращает true, если условие пустое или выполнено; false при невыполнении и при ошибке.
func is_met() -> bool:
	if _source.is_empty():
		return true
	if _expression == null:
		return false
	var inputs: Array = []
	for key: String in World.SCHEMA:
		inputs.append(World.f[key])
	var result: Variant = _expression.execute(inputs, World, false)
	if _expression.has_execute_failed():
		push_error("Condition: не удалось вычислить «%s»" % _source)
		return false
	return result == true
