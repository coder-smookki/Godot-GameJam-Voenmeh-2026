class_name HiddenMessage
extends Node2D
## Послание ЛАБЫ, спрятанное в шахматке: видно только через отладчик.
##
## Пока герой держит отладчик рядом с этим местом, сквозь текстуры проступает надпись.
## В первый раз послание засчитывается: растёт счётчик посланий и ставится отметка.

const COUNTER := "messages"
const SHOW_SEC := 0.25
const COLOR := Color(1.0, 0.86, 0.3)
const OUTLINE := Color(0.05, 0.02, 0.08)

@export var text_key: String = ""
@export var mark_id: String = ""
@export var reveal_distance: float = 360.0
@export var toast_key: String = "TOAST_MESSAGE"

var _label: Label = null
var _shown: bool = false


## Готовит скрытую надпись и подписывается на включение отладчика.
func _ready() -> void:
	_label = Label.new()
	_label.text = tr(text_key)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_color_override("font_color", COLOR)
	_label.add_theme_color_override("font_outline_color", OUTLINE)
	_label.add_theme_constant_override("outline_size", 4)
	_label.reset_size()
	_label.position = Vector2(-_label.size.x * 0.5, -_label.size.y * 0.5)
	add_child(_label)
	modulate.a = 0.0
	Game.slow_motion_changed.connect(_on_slow_motion_changed)
	set_process(false)


## Сообщает, видна ли надпись сейчас.
func is_shown() -> bool:
	return _shown


## Показывает надпись, пока герой с отладчиком стоит достаточно близко.
## [param _delta] - время кадра; проверка идёт каждый кадр, пока отладчик включён.
func _process(_delta: float) -> void:
	_set_shown(_hero_near())


## Начинает или прекращает проверку расстояния, когда отладчик включают и выключают.
## [param active] - true, если герой держит отладчик.
func _on_slow_motion_changed(active: bool) -> void:
	set_process(active)
	if not active:
		_set_shown(false)


## Проявляет или прячет надпись; при первом показе засчитывает послание.
## [param shown] - true, чтобы показать надпись.
func _set_shown(shown: bool) -> void:
	if shown == _shown:
		return
	_shown = shown
	create_tween().tween_property(self, "modulate:a", 1.0 if shown else 0.0, SHOW_SEC)
	if shown and not mark_id.is_empty() and not World.is_marked(mark_id):
		World.mark(mark_id)
		World.bump(COUNTER)
		Ui.toast(tr(toast_key).format(World.f), ToastStack.KIND_LABA)
		SaveSystem.save_game()


## Проверяет, стоит ли герой рядом с посланием.
func _hero_near() -> bool:
	var room := get_tree().current_scene as Room
	if room == null or not is_instance_valid(room.player):
		return false
	return absf(room.player.global_position.x - global_position.x) <= reveal_distance
