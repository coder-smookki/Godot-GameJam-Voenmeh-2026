class_name CatsLogic
extends RefCounted
## Правила боя в кабинете 316: три кота Логуновой должны быть довольны одновременно.
##
## Рыжему нужно тепло, серому - много корма, чёрному - закрытое окно. Тепло в комнате всё время
## уходит, через открытое окно намного быстрее; серый кот ест корм; заражение то и дело
## распахивает окно. Отладчик добавляет тепло, досыпает корм и закрывает окно. Когда все трое
## довольны подряд нужное время, бой выигран; если время вышло, проигран. На высокой сложности
## заражение ещё и вредит: сбивает тепло или опрокидывает часть корма.
## Числа по умолчанию - средний уровень; бой подставляет числа выбранного уровня.

signal mood_changed(cat: int, happy: bool)
signal window_changed(open: bool)
signal sabotaged(cat: int)
signal won
signal lost

const GINGER := 0
const GRAY := 1
const BLACK := 2
const CATS := 3
const HEAT_OK := 0.6
const FOOD_OK := 0.55
const HEAT_START := 0.25
const FOOD_START := 0.1
const OPEN_COOL_SCALE := 2.4
const HOLD_DECAY := 2.0
const COLD_C := 12.0
const HOT_C := 30.0
const SABOTAGE_HIT := 0.25

var heat: float = HEAT_START
var food: float = FOOD_START
var window_open: bool = true
var hold: float = 0.0
var time_left: float = 100.0
var hold_sec: float = 3.0
var cool_per_sec: float = 0.045
var eat_per_sec: float = 0.06
var wind_sec: float = 10.0
var heat_step: float = 0.25
var food_step: float = 0.35
var sabotage: bool = false

var _wind_left: float = 0.0
var _sabotage_left: float = 0.0
var _happy: Array[bool] = [false, false, false]
var _result: int = 0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


## Готовит бой.
## [param seed_value] - зерно случайных чисел; тесты задают его, чтобы бой повторялся.
func _init(seed_value: int = -1) -> void:
	if seed_value >= 0:
		_rng.seed = seed_value
	else:
		_rng.randomize()


## Задаёт числа уровня сложности и начинает отсчёт заново.
## [param level] - уровень из [Difficulty]; пустая строка берёт уровень этой игры.
func configure(level: String = "") -> void:
	time_left = Difficulty.value("cats_time", level)
	hold_sec = Difficulty.value("cats_hold", level)
	cool_per_sec = Difficulty.value("cats_cool", level)
	eat_per_sec = Difficulty.value("cats_eat", level)
	wind_sec = Difficulty.value("cats_wind", level)
	heat_step = Difficulty.value("cats_heat_step", level)
	food_step = Difficulty.value("cats_food_step", level)
	sabotage = float(Difficulty.value("cats_sabotage", level)) > 0.0
	reset()


## Возвращает комнату к началу боя: холодно, миска почти пуста, окно открыто.
## Время боя при этом не меняется.
## [param seconds] - сколько времени дать на новую попытку; меньше нуля оставляет прежнее.
func reset(seconds: float = -1.0) -> void:
	heat = HEAT_START
	food = FOOD_START
	window_open = true
	hold = 0.0
	_result = 0
	if seconds >= 0.0:
		time_left = seconds
	_wind_left = _next_wind()
	_sabotage_left = _next_wind() * 1.5
	_happy = [false, false, false]


## Двигает бой на шаг: тепло уходит, кот ест, ветер открывает окно, копится время, пока все
## довольны.
## [param delta] - прошедшее время в секундах.
func advance(delta: float) -> void:
	if is_done():
		return
	time_left -= delta
	var cool := cool_per_sec * (OPEN_COOL_SCALE if window_open else 1.0)
	heat = clampf(heat - cool * delta, 0.0, 1.0)
	food = clampf(food - eat_per_sec * delta, 0.0, 1.0)
	_wind_left -= delta
	if _wind_left <= 0.0:
		_wind_left = _next_wind()
		open_window()
	if sabotage:
		_sabotage_left -= delta
		if _sabotage_left <= 0.0:
			_sabotage_left = _next_wind() * 1.5
			_sabotage()
	_update_moods()
	if happy_count() == CATS:
		hold += delta
	else:
		hold = maxf(hold - delta * HOLD_DECAY, 0.0)
	if hold >= hold_sec:
		_result = 1
		won.emit()
	elif time_left <= 0.0:
		time_left = 0.0
		_result = -1
		lost.emit()


## Добавляет тепла: отладчик поднял значение батареи.
func warm() -> void:
	if not is_done():
		heat = clampf(heat + heat_step, 0.0, 1.0)
		_update_moods()


## Досыпает корм в миску.
func feed() -> void:
	if not is_done():
		food = clampf(food + food_step, 0.0, 1.0)
		_update_moods()


## Закрывает окно.
func close_window() -> void:
	if window_open and not is_done():
		window_open = false
		window_changed.emit(false)
		_update_moods()


## Распахивает окно: так делает заражение.
func open_window() -> void:
	if not window_open:
		window_open = true
		window_changed.emit(true)
		_update_moods()


## Сообщает, доволен ли кот.
## [param cat] - [constant GINGER], [constant GRAY] или [constant BLACK].
func is_happy(cat: int) -> bool:
	match cat:
		GINGER:
			return heat >= HEAT_OK
		GRAY:
			return food >= FOOD_OK
		_:
			return not window_open


## Считает довольных котов.
func happy_count() -> int:
	var count := 0
	for cat: int in CATS:
		if is_happy(cat):
			count += 1
	return count


## Возвращает долю накопленного времени, когда все трое довольны.
func hold_ratio() -> float:
	return clampf(hold / hold_sec, 0.0, 1.0)


## Возвращает температуру в комнате в градусах для градусника.
func celsius() -> float:
	return lerpf(COLD_C, HOT_C, heat)


## Возвращает температуру, при которой рыжему коту тепло.
static func warm_celsius() -> float:
	return lerpf(COLD_C, HOT_C, HEAT_OK)


## Сообщает, выигран ли бой.
func is_won() -> bool:
	return _result > 0


## Сообщает, закончился ли бой.
func is_done() -> bool:
	return _result != 0


## Сообщает об изменениях настроения котов.
func _update_moods() -> void:
	for cat: int in CATS:
		var happy := is_happy(cat)
		if happy != _happy[cat]:
			_happy[cat] = happy
			mood_changed.emit(cat, happy)


## Вредит одному из котов: сбивает тепло у рыжего или опрокидывает корм серого.
func _sabotage() -> void:
	var cat := GINGER if _rng.randf() < 0.5 else GRAY
	if cat == GINGER:
		heat = clampf(heat - SABOTAGE_HIT, 0.0, 1.0)
	else:
		food = clampf(food - SABOTAGE_HIT, 0.0, 1.0)
	sabotaged.emit(cat)


## Выбирает, через сколько ветер снова распахнёт окно.
func _next_wind() -> float:
	return wind_sec * _rng.randf_range(0.8, 1.2)
