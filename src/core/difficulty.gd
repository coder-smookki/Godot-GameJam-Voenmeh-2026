class_name Difficulty
extends RefCounted
## Уровни сложности и все числа, которые от них зависят, в одной таблице.
##
## Сложность выбирают перед новой игрой, она хранится в мире (переменная difficulty) и
## попадает в сохранение. Мини-игры и бои берут свои числа отсюда; правила без экрана
## ([PullLogic], [DebugLogic], [DrawLogic], [CatsLogic], [QuizLogic]) по умолчанию настроены
## на средний уровень, а экраны и бои подставляют числа выбранного уровня. Каждый следующий уровень
## заметно труднее: меньше сердец, меньше времени, быстрее утечка и атаки. На ультра у героя
## одно сердце.

const KEY := "difficulty"
const EASY := "easy"
const MEDIUM := "medium"
const HARD := "hard"
const ULTRA := "ultra"
const LEVELS: Array[String] = [EASY, MEDIUM, HARD, ULTRA]
const TABLE: Dictionary = {
	"hearts": [5, 3, 2, 1],
	"pull_drain": [0.08, 0.13, 0.19, 0.26],
	"pull_switch_2": [6.0, 4.0, 2.6, 1.8],
	"pull_switch_3": [5.0, 3.0, 1.8, 1.2],
	"debug_time": [75.0, 45.0, 30.0, 20.0],
	"debug_penalty": [0.5, 1.0, 1.5, 2.0],
	"draw_time": [45.0, 30.0, 22.0, 16.0],
	"boss_integrity": [5, 3, 2, 1],
	"bomb_dodges": [3, 5, 6, 8],
	"attack_speed": [0.85, 1.0, 1.15, 1.3],
	"attack_pause": [1.25, 1.0, 0.8, 0.65],
	"attack_high": [-0.1, 0.0, 0.1, 0.2],
	"cats_time": [150.0, 100.0, 75.0, 55.0],
	"cats_hold": [1.5, 3.0, 4.0, 5.5],
	"cats_cool": [0.025, 0.045, 0.07, 0.095],
	"cats_eat": [0.035, 0.06, 0.085, 0.11],
	"cats_wind": [16.0, 10.0, 7.0, 5.0],
	"cats_heat_step": [0.3, 0.25, 0.2, 0.17],
	"cats_food_step": [0.45, 0.35, 0.3, 0.25],
	"cats_sabotage": [0.0, 0.0, 1.0, 1.0],
	"quiz_answers": [3, 4, 5, 6],
	"quiz_mistakes": [3, 2, 1, 0],
	"quiz_time": [25.0, 15.0, 10.0, 7.0],
	"code_tasks": [2, 3, 4, 5],
	"code_time": [120.0, 80.0, 55.0, 40.0],
	"code_penalty": [3.0, 6.0, 9.0, 12.0],
}


## Возвращает уровень, выбранный в этой игре.
static func current() -> String:
	var level := str(World.f.get(KEY, MEDIUM))
	return level if level in LEVELS else MEDIUM


## Возвращает число из таблицы для уровня этой игры.
## [param key] - имя строки таблицы.
## [param level] - уровень; пустая строка берёт уровень этой игры.
static func value(key: String, level: String = "") -> Variant:
	var chosen := level if level in LEVELS else current()
	return TABLE[key][LEVELS.find(chosen)]


## Возвращает, сколько сердец у героя на уровне этой игры.
static func max_hearts() -> int:
	return int(value("hearts"))


## Возвращает ключ названия уровня для интерфейса.
## [param level] - уровень.
static func name_key(level: String) -> String:
	return "DIFFICULTY_%s" % level.to_upper()


## Возвращает ключ описания уровня для интерфейса.
## [param level] - уровень.
static func hint_key(level: String) -> String:
	return "DIFFICULTY_%s_HINT" % level.to_upper()
