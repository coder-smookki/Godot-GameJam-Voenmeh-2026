class_name PullGame
extends Modal
## Мини-игра «Тяни!»: три рывка, шкала растёт от нужной клавиши и утекает назад.
##
## Правила считает [PullLogic], экран показывает шкалу, клавишу, рывки и промахи и принимает
## нажатия. Клавиша назначается случайно и меняется по ходу игры. В настройках есть режим
## «удерживать» для тех, кому тяжело часто жать.

signal pulled
signal jerk_done(index: int)
signal missed(count: int)
signal finished

const KEY_CODES: Array[Key] = [KEY_SPACE, KEY_A, KEY_S, KEY_D, KEY_W, KEY_Q, KEY_E, KEY_F]
const KEY_LABELS: Array[String] = ["PULL_KEY", "A", "S", "D", "W", "Q", "E", "F"]
const HOLD_SETTING := "hold_to_pull"
const BLINK_SEC := 0.3
const BARS_SEC := 0.2
const BAR_HEIGHT := 20.0
const SLAM_SEC := 0.22
const SLAM_FROM := 2.4
const POP_SEC := 0.18
const POP_FROM := 1.35
const FLASH_SEC := 0.25
const LOW_LEVEL := 0.25
const DOT_DONE := Palette.OK
const DOT_CURRENT := Palette.GOAL
const DOT_AHEAD := Color("1c2540")
const FILL_OK := Palette.OK
const FILL_LOW := Palette.DANGER

var _logic: PullLogic = null
var _fill: StyleBoxFlat = null

@onready var _top: ColorRect = $Top
@onready var _bottom: ColorRect = $Bottom
@onready var _flash: ColorRect = $Flash
@onready var _title: Label = $Title
@onready var _bar: ProgressBar = $Bar
@onready var _jerks: Label = $Jerks
@onready var _dots: HBoxContainer = $Dots
@onready var _lamps: HBoxContainer = $Lamps
@onready var _hint: Label = $Hint
@onready var _key: PanelContainer = $Key
@onready var _key_text: Label = $Key/Text


## Выключает покадровую обработку до начала игры и запускает мигание клавиши.
func _ready() -> void:
	set_process(false)
	_fill = _bar.get_theme_stylebox("fill").duplicate()
	_bar.add_theme_stylebox_override("fill", _fill)
	var tween := create_tween().set_loops()
	tween.tween_property(_key_text, "modulate:a", 0.55, BLINK_SEC)
	tween.tween_property(_key_text, "modulate:a", 1.0, BLINK_SEC)


## Двигает шкалу каждый кадр, пока идёт игра.
## [param delta] - время кадра в секундах.
func _process(delta: float) -> void:
	var held := PullLogic.NO_KEY
	if Settings.value(HOLD_SETTING) and Input.is_physical_key_pressed(KEY_CODES[_logic.key]):
		held = _logic.key
	_logic.advance(delta, held)
	_after_step()


## Засчитывает нажатие одной из клавиш мини-игры.
## [param event] - событие ввода.
func _input(event: InputEvent) -> void:
	if not visible or _logic == null or _logic.is_done():
		return
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	var index := KEY_CODES.find(key_event.physical_keycode)
	if index >= 0:
		get_viewport().set_input_as_handled()
		press_key(index)


## Проводит мини-игру до победы или поражения.
## [param seed_value] - зерно случайных клавиш; тесты задают его, чтобы игра повторялась.
## Возвращает true, если сделаны все три рывка, и false после трёх промахов.
func play(seed_value: int = -1) -> bool:
	_logic = PullLogic.new(seed_value)
	_logic.drain_per_sec = Difficulty.value("pull_drain")
	_logic.switch_sec = [0.0, Difficulty.value("pull_switch_2"), Difficulty.value("pull_switch_3")]
	_logic.jerked.connect(_on_jerked)
	_logic.missed.connect(_on_missed)
	_logic.key_changed.connect(_on_key_changed)
	var hold: bool = Settings.value(HOLD_SETTING)
	_hint.text = tr("PULL_HOLD" if hold else "PULL_PRESS")
	open()
	_refresh()
	_show_key()
	set_process(true)
	await finished
	set_process(false)
	var won := _logic.is_won()
	close()
	return won


## Сообщает, какую клавишу игра ждёт сейчас.
## Возвращает номер клавиши или [constant PullLogic.NO_KEY] вне игры.
func current_key() -> int:
	return _logic.key if _is_running() else PullLogic.NO_KEY


## Сообщает, насколько шахматка наступила на героя.
## Возвращает число от 1 до 4 из [method PullLogic.pressure].
func pressure() -> int:
	return _logic.pressure() if _logic != null else 1


## Засчитывает нажатие нужной клавиши; вне игры ничего не делает.
func press() -> void:
	press_key(current_key())


## Засчитывает нажатие клавиши по её номеру; вне игры ничего не делает.
## [param index] - номер клавиши в [constant KEY_CODES].
func press_key(index: int) -> void:
	if not _is_running():
		return
	if _logic.press(index):
		pulled.emit()
	_after_step()


## Прячет задание и тосты, задвигает чёрные полосы и роняет заголовок на экран.
func _opened() -> void:
	Ui.hud.hide()
	Ui.toasts.hide()
	_top.position.y = -BAR_HEIGHT
	_bottom.position.y = size.y
	var bars := create_tween().set_parallel()
	bars.tween_property(_top, "position:y", 0.0, BARS_SEC)
	bars.tween_property(_bottom, "position:y", size.y - BAR_HEIGHT, BARS_SEC)
	_title.pivot_offset = _title.size * 0.5
	_title.scale = Vector2(SLAM_FROM, SLAM_FROM)
	var slam := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	slam.tween_property(_title, "scale", Vector2.ONE, SLAM_SEC)
	_flash_screen(Color.WHITE)


## Возвращает задание и тосты на экран.
func _closed() -> void:
	Ui.hud.show()
	Ui.toasts.show()


## Сообщает, идёт ли игра прямо сейчас.
func _is_running() -> bool:
	return visible and _logic != null and not _logic.is_done()


## Обновляет экран после шага и сообщает о конце игры.
func _after_step() -> void:
	_refresh()
	if _logic.is_done():
		finished.emit()


## Показывает шкалу, номер рывка, кружки рывков и лампочки промахов.
func _refresh() -> void:
	_bar.value = _logic.level
	_fill.bg_color = FILL_LOW if _logic.level < LOW_LEVEL else FILL_OK
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
	for index: int in _lamps.get_child_count():
		var lamp: Lamp = _lamps.get_child(index)
		lamp.lit = index < _logic.misses


## Пишет на клавише, что нажимать, и коротко увеличивает её, чтобы смену было видно.
func _show_key() -> void:
	_key_text.text = tr(KEY_LABELS[_logic.key])
	_key.reset_size()
	_key.position.x = (size.x - _key.size.x) * 0.5
	_key.pivot_offset = _key.size * 0.5
	_key.scale = Vector2(POP_FROM, POP_FROM)
	_key.modulate = Palette.GOAL
	var pop := create_tween().set_parallel()
	pop.tween_property(_key, "scale", Vector2.ONE, POP_SEC)
	pop.tween_property(_key, "modulate", Color.WHITE, POP_SEC * 2.0)


## Заливает экран цветом, который быстро гаснет.
## [param color] - цвет вспышки.
func _flash_screen(color: Color) -> void:
	_flash.color = Color(color, 0.6)
	create_tween().tween_property(_flash, "color:a", 0.0, FLASH_SEC)


## Отмечает сделанный рывок вспышкой и сообщает о нём сцене.
## [param index] - сколько рывков уже сделано.
func _on_jerked(index: int) -> void:
	_flash_screen(Color.WHITE)
	jerk_done.emit(index)


## Отмечает промах красной вспышкой и сообщает о нём сцене.
## [param count] - сколько промахов уже было.
func _on_missed(count: int) -> void:
	_flash_screen(Palette.DANGER)
	missed.emit(count)


## Показывает новую клавишу.
## [param _key_index] - номер клавиши; экран читает его из правил.
func _on_key_changed(_key_index: int) -> void:
	_show_key()
