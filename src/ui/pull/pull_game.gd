class_name PullGame
extends Modal
## Мини-игра «Тяни!»: три рывка, шкала растёт от пробела и утекает назад.
##
## Правила считает [PullLogic], экран только показывает шкалу и принимает нажатия.
## В настройках есть режим «удерживать» для тех, кому тяжело часто жать.

signal jerk_done(index: int)
signal finished

const ACTION := "jump"
const HOLD_SETTING := "hold_to_pull"
const BLINK_SEC := 0.3
const DOT_DONE := Palette.OK
const DOT_CURRENT := Palette.GOAL
const DOT_AHEAD := Color("1c2540")

var _logic: PullLogic = null

@onready var _title: Label = $Title
@onready var _bar: ProgressBar = $Bar
@onready var _jerks: Label = $Jerks
@onready var _dots: HBoxContainer = $Dots
@onready var _key: PanelContainer = $Key


## Выключает покадровую обработку до начала игры и запускает мигание клавиши.
func _ready() -> void:
	set_process(false)
	var tween := create_tween().set_loops()
	tween.tween_property(_key, "modulate:a", 0.45, BLINK_SEC)
	tween.tween_property(_key, "modulate:a", 1.0, BLINK_SEC)


## Двигает шкалу каждый кадр, пока идёт игра.
## [param delta] - время кадра в секундах.
func _process(delta: float) -> void:
	var holding: bool = Settings.value(HOLD_SETTING) and Input.is_action_pressed(ACTION)
	_after_step(_logic.advance(delta, holding))


## Засчитывает нажатие пробела.
## [param event] - событие ввода.
func _input(event: InputEvent) -> void:
	if not visible or _logic == null or _logic.is_done():
		return
	if event.is_action_pressed(ACTION):
		get_viewport().set_input_as_handled()
		press()


## Проводит мини-игру от первого рывка до последнего.
func play() -> void:
	_logic = PullLogic.new()
	var title_key := "PULL_TITLE_HOLD" if Settings.value(HOLD_SETTING) else "PULL_TITLE"
	_title.text = tr(title_key)
	open()
	_refresh()
	set_process(true)
	await finished
	set_process(false)
	close()


## Засчитывает одно нажатие; вне игры ничего не делает.
func press() -> void:
	if visible and _logic != null and not _logic.is_done():
		_after_step(_logic.press())


## Обновляет экран после шага и сообщает о рывке и о конце игры.
## [param jerked] - true, если шаг завершил рывок.
func _after_step(jerked: bool) -> void:
	_refresh()
	if jerked:
		jerk_done.emit(_logic.jerk)
	if _logic.is_done():
		finished.emit()


## Показывает шкалу, номер рывка и кружки сделанных рывков.
func _refresh() -> void:
	_bar.value = _logic.level
	var counts: Dictionary = {
		"current": mini(_logic.jerk + 1, PullLogic.JERKS),
		"total": PullLogic.JERKS,
	}
	_jerks.text = tr("PULL_JERK").format(counts)
	for index: int in _dots.get_child_count():
		var dot: ColorRect = _dots.get_child(index)
		if index < _logic.jerk:
			dot.color = DOT_DONE
		elif index == _logic.jerk:
			dot.color = DOT_CURRENT
		else:
			dot.color = DOT_AHEAD
