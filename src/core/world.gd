extends Node
## Сюжетное состояние игры: все переменные развилок, счётчики манеры игры и разовые отметки.
##
## Единственное место, где хранятся сюжетные флаги. Сцены читают состояние отсюда
## и меняют его только через [method choose], [method bump] и [method mark].
## Узел ни от кого не зависит: журнал, сохранение и интерфейс подписываются на его сигналы.

signal changed(key: String, value: Variant)
signal deciding(fork_id: String)
signal decided(key: String, value: Variant, toast_key: String)
signal marked(id: String)
signal reloaded

const SCHEMA: Dictionary = {
	"escape_tried": {"default": false},
	"gosha": {"default": "", "values": ["", "saved", "lost"]},
	"unsafe": {"default": 0, "max": 3},
	"compiler": {"default": "", "values": ["", "fixed", "deleted"]},
	"naurusova": {"default": "", "values": ["", "error", "student", "unknown"]},
	"first_floor": {"default": 0, "values": [0, 3, 4]},
	"cats": {"default": 0, "max": 5},
	"alarms": {"default": 0, "max": 99},
	"logunova": {"default": "", "values": ["", "kind", "strict"]},
	"rage": {"default": 0, "max": 99},
	"zeml": {"default": "", "values": ["", "calm", "storm"]},
	"mozh": {"default": "", "values": ["", "clone", "stay", "off"]},
	"messages": {"default": 0, "max": 5},
	"students": {"default": 0, "max": 6},
	"capy": {"default": 0, "max": 44},
	"notes": {"default": 0, "max": 6},
}
const METHOD_WEIGHTS: Dictionary = {
	"compiler": {"fixed": 1, "deleted": -1},
	"naurusova": {"student": 1, "error": -1},
	"logunova": {"kind": 1, "strict": -1},
	"zeml": {"calm": 1, "storm": -1},
	"mozh": {"clone": 1, "off": -1},
}
const UNSAFE_PENALTY_FROM := 3
const LINE_STUDENT_FROM := 2
const LINE_AUDITOR_FROM := -2
const MESSAGES_FOR_FIX := 3
const CAPY_TOTAL := 44
const FINAL_TIMER_SEC := 600.0
const FINAL_TIMER_OFF_SEC := 300.0
const STUDENT_BONUS_SEC := 20.0
const STUDENTS_COUNTED := 6

var f: Dictionary = {}
var clock: float = 0.0

var _marks: Dictionary = {}


## Заполняет состояние значениями по умолчанию при запуске игры.
func _ready() -> void:
	reset()


## Ведёт игровые часы, по которым считается давность отметок.
## [param delta] - время кадра в секундах; на паузе функция не вызывается.
func _process(delta: float) -> void:
	clock += delta


## Сбрасывает все переменные, отметки и часы к началу новой игры.
func reset() -> void:
	f = defaults()
	_marks = {}
	clock = 0.0
	reloaded.emit()


## Собирает словарь значений по умолчанию из схемы.
## Возвращает новый словарь «переменная -> значение» для начала игры.
func defaults() -> Dictionary:
	var result: Dictionary = {}
	for key: String in SCHEMA:
		result[key] = SCHEMA[key]["default"]
	return result


## Записывает решение игрока и сообщает о нём подписчикам (журналу, сохранению, интерфейсу).
## [param key] - имя переменной из схемы.
## [param value] - новое значение; недопустимое значение отклоняется.
## [param toast_key] - ключ текста для тоста «ЛАБА запомнила», пустая строка - без тоста.
## Возвращает true, если значение принято.
func choose(key: String, value: Variant, toast_key: String = "") -> bool:
	if not is_valid(key, value):
		push_error("World.choose: недопустимое значение %s для %s" % [value, key])
		return false
	f[key] = _normalize(key, value)
	changed.emit(key, f[key])
	decided.emit(key, f[key], toast_key)
	return true


## Проводит решение развилки из каталога: сначала даёт сделать снимок, потом записывает выбор.
## [param fork_id] - код развилки, например "P4".
## [param value] - выбранное значение из вариантов этой развилки.
## Возвращает true, если развилка найдена и значение принято.
func decide(fork_id: String, value: Variant) -> bool:
	var fork: Dictionary = ForkCatalog.get_fork(fork_id)
	if fork.is_empty():
		push_error("World.decide: развилки %s нет в каталоге" % fork_id)
		return false
	deciding.emit(fork_id)
	return choose(fork["key"], value, ForkCatalog.toast_key(fork_id, value))


## Тихо записывает значение переменной: без журнала, тоста и автосохранения.
## Нужна меню разработчика и тестам; решения игрока проходят через [method choose].
## [param key] - имя переменной из схемы.
## [param value] - новое значение; недопустимое значение отклоняется.
## Возвращает true, если значение принято.
func set_value(key: String, value: Variant) -> bool:
	if not is_valid(key, value):
		return false
	f[key] = _normalize(key, value)
	changed.emit(key, f[key])
	return true


## Меняет числовой счётчик манеры игры и удерживает его в границах схемы.
## [param key] - имя числовой переменной.
## [param amount] - на сколько изменить, по умолчанию +1.
## Возвращает новое значение счётчика (или 0, если переменная не числовая).
func bump(key: String, amount: int = 1) -> int:
	if not SCHEMA.has(key) or not SCHEMA[key].has("max"):
		push_error("World.bump: %s не является счётчиком" % key)
		return 0
	var limit: int = SCHEMA[key]["max"]
	var value: int = clampi(int(f[key]) + amount, 0, limit)
	if value != int(f[key]):
		f[key] = value
		changed.emit(key, value)
	return value


## Проверяет, подходит ли значение переменной по схеме.
## [param key] - имя переменной.
## [param value] - проверяемое значение.
## Возвращает true, если переменная существует и значение входит в допустимые.
func is_valid(key: String, value: Variant) -> bool:
	if not SCHEMA.has(key):
		return false
	var spec: Dictionary = SCHEMA[key]
	if spec.has("values"):
		var candidate: Variant = _normalize(key, value)
		return typeof(candidate) == typeof(spec["default"]) and candidate in spec["values"]
	if spec.has("max"):
		if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
			return false
		return int(value) >= 0 and int(value) <= int(spec["max"])
	return typeof(value) == TYPE_BOOL


## Считает «метод» игрока: чинил он (+) или удалял (-).
## Возвращает целое от -6 до +5, от него зависит характер ЛАБЫ.
func method() -> int:
	var total := 0
	for key: String in METHOD_WEIGHTS:
		total += int(METHOD_WEIGHTS[key].get(f[key], 0))
	if int(f["unsafe"]) >= UNSAFE_PENALTY_FROM:
		total -= 1
	return total


## Определяет линию ЛАБЫ по методу игрока.
## Возвращает "student" (ученица), "auditor" (ревизор) или "system" (система).
func laba_line() -> String:
	var value := method()
	if value >= LINE_STUDENT_FROM:
		return "student"
	if value <= LINE_AUDITOR_FROM:
		return "auditor"
	return "system"


## Определяет концовку по выбранному терминалу на крыше.
## [param terminal] - "delete", "reset" или "fix".
## Возвращает код концовки из каталога или пустую строку, если терминал закрыт.
func ending(terminal: String) -> String:
	match terminal:
		"delete":
			return "rm_rf"
		"reset":
			return "loop"
		"fix":
			if int(f["messages"]) < MESSAGES_FOR_FIX:
				return ""
			return "capybara" if int(f["capy"]) >= CAPY_TOTAL else "retake"
	return ""


## Считает длительность таймера города в финальном бою.
## Возвращает секунды: 5 или 10 минут плюс 20 секунд за каждого спасённого одногруппника.
func final_timer_sec() -> float:
	var base := FINAL_TIMER_OFF_SEC if f["mozh"] == "off" else FINAL_TIMER_SEC
	return base + minf(float(f["students"]), float(STUDENTS_COUNTED)) * STUDENT_BONUS_SEC


## Ставит разовую отметку (разбит тотем, взят предмет, запущена ЛАБА) и запоминает её время.
## [param id] - уникальное имя отметки.
## Возвращает true, если отметка поставлена сейчас, и false, если она уже была.
func mark(id: String) -> bool:
	if _marks.has(id):
		return false
	_marks[id] = clock
	marked.emit(id)
	return true


## Проверяет, стоит ли отметка.
## [param id] - имя отметки.
## Возвращает true, если отметка уже поставлена.
func is_marked(id: String) -> bool:
	return _marks.has(id)


## Сообщает, сколько игрового времени прошло с момента отметки.
## [param id] - имя отметки.
## Возвращает секунды с момента отметки или INF, если отметки нет.
func marked_ago(id: String) -> float:
	if not _marks.has(id):
		return INF
	return clock - float(_marks[id])


## Упаковывает состояние для сохранения.
## Возвращает словарь с переменными, отметками и часами.
func to_dict() -> Dictionary:
	return {"f": f.duplicate(true), "marks": _marks.duplicate(), "clock": clock}


## Восстанавливает состояние из сохранения, отбрасывая неизвестные и испорченные значения.
## [param data] - словарь из [method to_dict], возможно прочитанный из JSON.
func from_dict(data: Dictionary) -> void:
	f = defaults()
	_marks = {}
	clock = 0.0
	var saved: Variant = data.get("f", {})
	if saved is Dictionary:
		for key: String in SCHEMA:
			if saved.has(key) and is_valid(key, saved[key]):
				f[key] = _normalize(key, saved[key])
	var marks: Variant = data.get("marks", {})
	if marks is Dictionary:
		for id: Variant in marks:
			if _is_number(marks[id]):
				_marks[str(id)] = float(marks[id])
	if _is_number(data.get("clock", 0.0)):
		clock = maxf(float(data.get("clock", 0.0)), 0.0)
	reloaded.emit()


## Приводит значение к типу переменной: числа из JSON приходят дробными.
## [param key] - имя переменной из схемы.
## [param value] - исходное значение.
## Возвращает значение в типе, который задан схемой.
func _normalize(key: String, value: Variant) -> Variant:
	if typeof(SCHEMA[key]["default"]) == TYPE_INT and typeof(value) == TYPE_FLOAT:
		return int(value)
	return value


## Проверяет, что значение является числом.
## [param value] - проверяемое значение.
## Возвращает true для целых и дробных чисел.
func _is_number(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT
