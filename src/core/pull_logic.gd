class_name PullLogic
extends RefCounted
## Правила мини-игры «Тяни!»: шкала растёт от нажатий нужной клавиши и всё время утекает назад.
##
## Три рывка подряд, в каждом шкала утекает быстрее, а нужная клавиша меняется чаще.
## Шкала, упавшая до нуля, даёт промах: шахматка наступает. После трёх промахов игра проиграна.

signal jerked(index: int)
signal missed(count: int)
signal key_changed(key: int)

const JERKS := 3
const MISSES := 3
const KEY_COUNT := 8
const START_LEVEL := 0.4
const FULL_LEVEL := 0.999
const EMPTY_LEVEL := 0.001
const PRESS_GAIN := 0.1
const WRONG_PENALTY := 0.05
const HOLD_GAIN_PER_SEC := 0.55
const DRAIN_PER_SEC := 0.2
const DRAIN_SCALES: Array[float] = [1.0, 1.5, 2.0]
const SWITCH_SEC: Array[float] = [0.0, 2.6, 1.8]
const NO_KEY := -1
const START_PRESSURE := 2
const MAX_PRESSURE := 4

var jerk: int = 0
var misses: int = 0
var level: float = START_LEVEL
var key: int = 0

var _since_switch: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


## Выбирает первую клавишу.
## [param seed_value] - зерно случайных чисел; тесты задают его, чтобы игра повторялась.
func _init(seed_value: int = -1) -> void:
	if seed_value >= 0:
		_rng.seed = seed_value
	else:
		_rng.randomize()
	key = _rng.randi_range(0, KEY_COUNT - 1)


## Сообщает, вытащен ли персонаж.
## Возвращает true, когда сделаны все три рывка.
func is_won() -> bool:
	return jerk >= JERKS


## Сообщает, проиграна ли игра.
## Возвращает true после трёх промахов.
func is_lost() -> bool:
	return misses >= MISSES


## Сообщает, закончилась ли игра победой или поражением.
func is_done() -> bool:
	return is_won() or is_lost()


## Считает, насколько шахматка наступила на героя.
## Возвращает число от 1 (отступила) до 4 (поглотила): рывки отодвигают её, промахи приближают.
func pressure() -> int:
	if is_lost():
		return MAX_PRESSURE
	return clampi(START_PRESSURE + misses - jerk, 1, MAX_PRESSURE - 1)


## Засчитывает нажатие клавиши: нужная клавиша растит шкалу, чужая уменьшает.
## [param pressed_key] - номер нажатой клавиши от 0 до [constant KEY_COUNT] - 1.
## Возвращает true, если нажата нужная клавиша.
func press(pressed_key: int) -> bool:
	if is_done():
		return false
	var right := pressed_key == key
	_add(PRESS_GAIN if right else -WRONG_PENALTY)
	return right


## Двигает шкалу за прошедшее время: утечка назад, рост при удержании и смена клавиши.
## [param delta] - прошедшее время в секундах.
## [param held_key] - номер зажатой клавиши в режиме «удерживать» или [constant NO_KEY].
func advance(delta: float, held_key: int = NO_KEY) -> void:
	if is_done():
		return
	var change := -DRAIN_PER_SEC * DRAIN_SCALES[jerk] * delta
	if held_key == key:
		change += HOLD_GAIN_PER_SEC * delta
	_since_switch += delta
	_add(change)
	if not is_done() and SWITCH_SEC[jerk] > 0.0 and _since_switch >= SWITCH_SEC[jerk]:
		_pick_key()


## Меняет шкалу: полная шкала засчитывает рывок, пустая даёт промах.
## [param amount] - на сколько изменить шкалу; отрицательное значение уменьшает её.
func _add(amount: float) -> void:
	level = clampf(level + amount, 0.0, 1.0)
	if level >= FULL_LEVEL:
		jerk += 1
		level = START_LEVEL
		jerked.emit(jerk)
		if not is_won():
			_pick_key()
	elif level <= EMPTY_LEVEL:
		misses += 1
		level = START_LEVEL
		missed.emit(misses)


## Назначает новую клавишу, которая не совпадает с прежней.
func _pick_key() -> void:
	key = (key + _rng.randi_range(1, KEY_COUNT - 1)) % KEY_COUNT
	_since_switch = 0.0
	key_changed.emit(key)
