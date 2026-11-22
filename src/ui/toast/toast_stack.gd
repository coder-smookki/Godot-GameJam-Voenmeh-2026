class_name ToastStack
extends VBoxContainer
## Стопка тостов в верхней части экрана.
##
## Тост показывает, что мир запомнил действие игрока, и сам исчезает через несколько секунд.

const KIND_LABA := "laba"
const KIND_TEACHER := "teacher"
const KIND_GROUP := "group"
const KIND_HINT := "hint"
const MAX_VISIBLE := 3
const SHOW_SEC := 3.5
const FADE_SEC := 0.4
const WIDTH := 216.0

var _styles: Dictionary = {}


## Показывает новый тост; самый старый убирается, если тостов слишком много.
## [param text] - готовый текст тоста.
## [param kind] - вид тоста: KIND_LABA, KIND_TEACHER, KIND_GROUP или KIND_HINT.
func show_toast(text: String, kind: String = KIND_LABA) -> void:
	while get_child_count() >= MAX_VISIBLE:
		var oldest := get_child(0)
		remove_child(oldest)
		oldest.queue_free()
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(kind))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := Label.new()
	label.text = text
	label.custom_minimum_size.x = WIDTH
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)
	add_child(panel)
	var tween := panel.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_ignore_time_scale(true)
	tween.tween_interval(SHOW_SEC)
	tween.tween_property(panel, "modulate:a", 0.0, FADE_SEC)
	tween.tween_callback(panel.queue_free)


## Возвращает рамку для вида тоста, создавая её один раз.
## [param kind] - вид тоста.
## Возвращает стиль панели с цветом рамки этого вида.
func _style(kind: String) -> StyleBoxFlat:
	if not _styles.has(kind):
		var color := Palette.VIRUS
		match kind:
			KIND_TEACHER:
				color = Palette.GOAL
			KIND_GROUP:
				color = Palette.OK
			KIND_HINT:
				color = Palette.DEBUGGER
		_styles[kind] = Palette.frame(color)
	return _styles[kind]
