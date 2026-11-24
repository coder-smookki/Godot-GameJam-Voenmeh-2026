class_name MirrorLogic
extends RefCounted
## Правила боя на пятом этаже: поле 7x4, герой и его клон, три бомбы под клетками.
##
## Герой начинает в правом верхнем углу, клон в левом нижнем. Клон повторяет каждый шаг
## героя зеркально относительно центра поля (герой вправо - клон влево, герой вверх - клон
## вниз), поэтому всегда стоит в клетке, симметричной клетке героя. Мажайцев перед игрой
## подсвечивает бомбы, потом они скрыты. Нужно завести клона на все три бомбы и не наступить
## на бомбу самому; бомба, на которую наступил клон, взрывается и исчезает. На высокой
## сложности ходов мало: к самому короткому пути добавляется небольшой запас.
## Числа по умолчанию - средний уровень.

signal moved(hero: Vector2i, clone: Vector2i)
signal clone_hit(cell: Vector2i)
signal hero_hit(cell: Vector2i)
signal won
signal lost

const COLUMNS := 7
const ROWS := 4
const BOMBS := 3
const HERO_START := Vector2i(6, 0)
const CLONE_START := Vector2i(0, 3)
const SLACK := 10
const REVEAL_SEC := 4.0
const DIRECTIONS: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]

var hero: Vector2i = HERO_START
var clone: Vector2i = CLONE_START
var bombs: Array[Vector2i] = []
var blown: Array[Vector2i] = []
var moves: int = 0
var move_limit: int = 0
var slack: int = SLACK
var reveal_sec: float = REVEAL_SEC

var _result: int = 0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


## Готовит первую попытку.
## [param seed_value] - зерно случайных чисел; тесты задают его, чтобы поле повторялось.
func _init(seed_value: int = -1) -> void:
	if seed_value >= 0:
		_rng.seed = seed_value
	else:
		_rng.randomize()
	reset()


## Возвращает клетку, симметричную данной относительно центра поля.
## [param cell] - клетка.
static func mirror(cell: Vector2i) -> Vector2i:
	return Vector2i(COLUMNS - 1 - cell.x, ROWS - 1 - cell.y)


## Сообщает, лежит ли клетка на поле.
## [param cell] - клетка.
static func inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < COLUMNS and cell.y < ROWS


## Задаёт числа уровня сложности и начинает попытку заново.
## [param level] - уровень из [Difficulty]; пустая строка берёт уровень этой игры.
func configure(level: String = "") -> void:
	slack = Difficulty.value("mirror_slack", level)
	reveal_sec = Difficulty.value("mirror_reveal", level)
	reset()


## Новая попытка: герой и клон в углах, новые бомбы, счёт ходов с нуля.
func reset() -> void:
	hero = HERO_START
	clone = CLONE_START
	moves = 0
	blown.clear()
	_result = 0
	var best := -1
	while best < 0:
		_place_bombs()
		best = shortest_tour()
	move_limit = best + slack


## Делает шаг героя; клон шагает зеркально. Возвращает false, если шаг невозможен.
## [param direction] - направление шага: влево, вправо, вверх или вниз.
func step(direction: Vector2i) -> bool:
	if is_done() or not inside(hero + direction):
		return false
	hero += direction
	if inside(clone - direction):
		clone -= direction
	moves += 1
	moved.emit(hero, clone)
	if is_bomb(hero):
		blown.append(hero)
		hero_hit.emit(hero)
		_finish(false)
		return true
	if is_bomb(clone):
		blown.append(clone)
		clone_hit.emit(clone)
		if bombs_left() == 0:
			_finish(true)
			return true
	if moves >= move_limit:
		_finish(false)
	return true


## Сообщает, лежит ли в клетке невзорванная бомба.
## [param cell] - клетка.
func is_bomb(cell: Vector2i) -> bool:
	return cell in bombs and not cell in blown


## Возвращает, сколько бомб клону ещё нужно взорвать.
func bombs_left() -> int:
	var left := 0
	for bomb: Vector2i in bombs:
		if not bomb in blown:
			left += 1
	return left


## Считает самый короткий путь героя через все клетки, симметричные бомбам, в обход бомб.
## Возвращает число шагов или -1, если такого пути нет.
func shortest_tour() -> int:
	var targets: Array[Vector2i] = []
	for bomb: Vector2i in bombs:
		targets.append(mirror(bomb))
	var best := -1
	for order: Array in _orders(targets.size()):
		var at := HERO_START
		var total := 0
		for index: int in order:
			var leg := _distance(at, targets[index])
			if leg < 0:
				total = -1
				break
			total += leg
			at = targets[index]
		if total >= 0 and (best < 0 or total < best):
			best = total
	return best


## Возвращает ходы, которые ещё можно сделать.
func moves_left() -> int:
	return maxi(move_limit - moves, 0)


## Сообщает, выиграна ли попытка.
func is_won() -> bool:
	return _result > 0


## Сообщает, закончилась ли попытка.
func is_done() -> bool:
	return _result != 0


## Раскладывает бомбы: не в углах героя и клона, и ни одна бомба не стоит напротив другой,
## иначе привести клона на неё значило бы наступить на бомбу самому.
func _place_bombs() -> void:
	bombs.clear()
	while bombs.size() < BOMBS:
		var cell := Vector2i(_rng.randi_range(0, COLUMNS - 1), _rng.randi_range(0, ROWS - 1))
		if cell == HERO_START or cell == CLONE_START or cell in bombs:
			continue
		if mirror(cell) in bombs:
			continue
		bombs.append(cell)


## Считает самый короткий путь между клетками в обход бомб.
## [param from] - откуда.
## [param to] - куда.
## Возвращает число шагов или -1.
func _distance(from: Vector2i, to: Vector2i) -> int:
	var seen := {from: 0}
	var queue: Array[Vector2i] = [from]
	while not queue.is_empty():
		var at: Vector2i = queue.pop_front()
		if at == to:
			return seen[at]
		for direction: Vector2i in DIRECTIONS:
			var next := at + direction
			if inside(next) and not seen.has(next) and not next in bombs:
				seen[next] = seen[at] + 1
				queue.append(next)
	return -1


## Возвращает все порядки обхода целей.
## [param count] - сколько целей.
func _orders(count: int) -> Array:
	var result: Array = []
	if count == 0:
		result.append([])
		return result
	for rest: Array in _orders(count - 1):
		for place: int in rest.size() + 1:
			var order := rest.duplicate()
			order.insert(place, count - 1)
			result.append(order)
	return result


## Заканчивает попытку победой или поражением.
## [param win] - true для победы.
func _finish(win: bool) -> void:
	_result = 1 if win else -1
	if win:
		won.emit()
	else:
		lost.emit()
