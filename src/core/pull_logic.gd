class_name PullLogic
extends RefCounted
## Правила мини-игры «Тяни!»: шкала растёт от нажатий и всё время утекает назад.
##
## Три рывка подряд, в каждом шкала утекает быстрее. Упавшая до нуля шкала не наказывает:
## рывок просто начинается заново.

const JERKS := 3
const PRESS_GAIN := 0.12
const HOLD_GAIN_PER_SEC := 0.6
const DRAIN_PER_SEC := 0.2
const DRAIN_SCALES: Array[float] = [1.0, 1.6, 2.3]

var jerk: int = 0
var level: float = 0.0


## Сообщает, вытащен ли персонаж.
## Возвращает true, когда сделаны все три рывка.
func is_done() -> bool:
	return jerk >= JERKS


## Засчитывает одно нажатие клавиши.
## Возвращает true, если нажатие завершило рывок.
func press() -> bool:
	return _add(PRESS_GAIN)


## Двигает шкалу за прошедшее время: утечка назад и рост, если клавишу держат.
## [param delta] - прошедшее время в секундах.
## [param holding] - true, если включён режим «удерживать» и клавиша зажата.
## Возвращает true, если за это время рывок завершился.
func advance(delta: float, holding: bool) -> bool:
	if is_done():
		return false
	var change := -DRAIN_PER_SEC * DRAIN_SCALES[jerk] * delta
	if holding:
		change += HOLD_GAIN_PER_SEC * delta
	return _add(change)


## Меняет шкалу и переходит к следующему рывку, когда она заполнена.
## [param amount] - на сколько изменить шкалу; отрицательное значение уменьшает её.
## Возвращает true, если шкала заполнилась и рывок засчитан.
func _add(amount: float) -> bool:
	if is_done():
		return false
	level = clampf(level + amount, 0.0, 1.0)
	if level < 1.0:
		return false
	jerk += 1
	level = 0.0
	return true
