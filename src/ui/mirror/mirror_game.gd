class_name MirrorGame
extends Modal
## Поле боя с клоном на пятом этаже: вид сверху на рисунке художниц.
##
## Сетка 7x4 нарисована на фоне от руки, поэтому границы клеток измерены по рисунку. Герой
## и клон - головы сверху; при шаге они плавно переезжают в новую клетку и поворачиваются
## лицом по ходу. Пока Мажайцев подсказывает, клетки с бомбами пульсируют красным, потом
## гаснут. Взрыв - вспышка, кольца и осколки; на месте взорванной бомбы остаётся подпалина.
## Сверху счёт бомб клона и оставшиеся ходы. Ходят стрелками или WASD. Экран стоит в дереве
## интерфейса ниже окна разговора, чтобы подсказки Мажайцева были видны поверх поля.
## Правила - [MirrorLogic]; бой управляет показом бомб и попытками.

signal finished

const BOARD: Texture2D = preload("res://assets/minigames/mirror/board.png")
const HERO: Texture2D = preload("res://assets/minigames/mirror/hero_top.png")
const CLONE: Texture2D = preload("res://assets/minigames/mirror/clone_top.png")
const COLUMN_X: Array[float] = [76.0, 124.6, 177.9, 229.4, 277.4, 325.4, 368.9, 410.0]
const ROW_Y: Array[float] = [15.0, 73.0, 135.0, 200.0, 255.0]
const SLIDE_SEC := 0.14
const BLAST_SEC := 0.8
const END_SEC := 1.2
const BOMB := Color(1.0, 0.1, 0.15)
const SCORCH := Color(0.05, 0.03, 0.03, 0.7)
const KEYS: Dictionary = {
	KEY_LEFT: Vector2i.LEFT,
	KEY_A: Vector2i.LEFT,
	KEY_RIGHT: Vector2i.RIGHT,
	KEY_D: Vector2i.RIGHT,
	KEY_UP: Vector2i.UP,
	KEY_W: Vector2i.UP,
	KEY_DOWN: Vector2i.DOWN,
	KEY_S: Vector2i.DOWN,
}

var _logic: MirrorLogic = null
var _reveal: bool = false
var _active: bool = false
var _clock: float = 0.0
var _hero_from: Vector2 = Vector2.ZERO
var _clone_from: Vector2 = Vector2.ZERO
var _slide: float = 1.0
var _hero_angle: float = 0.0
var _clone_angle: float = PI
var _blasts: Array[Dictionary] = []
var _flash: Color = Color.TRANSPARENT


## Готовит экран: закрыть его клавишей отмены нельзя.
func _ready() -> void:
	closable = false
	set_process(false)


## Открывает поле с новой раскладкой; ходить пока нельзя.
## [param seed_value] - зерно случайных чисел; тесты задают его, чтобы поле повторялось.
func prepare(seed_value: int = -1) -> void:
	_logic = MirrorLogic.new(seed_value)
	_logic.configure()
	_connect_logic()
	_restart_view()
	open()
	set_process(true)


## Раскладывает поле заново для новой попытки, не закрывая экран.
func retry() -> void:
	_logic.reset()
	_restart_view()


## Показывает или прячет бомбы.
## [param shown] - true, пока Мажайцев подсвечивает бомбы.
func set_reveal(shown: bool) -> void:
	_reveal = shown


## Даёт ходить, пока попытка не кончится.
## Возвращает true, если клон взорвал все три бомбы.
func play() -> bool:
	_active = true
	await finished
	_active = false
	return _logic.is_won()


## Закрывает поле.
func close_board() -> void:
	set_process(false)
	close()


## Возвращает правила текущей попытки; нужно тестам.
func logic() -> MirrorLogic:
	return _logic


## Делает шаг героя.
## [param direction] - направление шага.
func step(direction: Vector2i) -> void:
	if not _active or _logic.is_done():
		return
	_hero_from = _hero_pos()
	_clone_from = _clone_pos()
	if _logic.step(direction):
		_slide = 0.0
		_hero_angle = Vector2(direction).angle() + PI
		_clone_angle = Vector2(-direction).angle()


## Ходит стрелками или WASD, пока не открыт разговор.
## [param event] - событие ввода.
func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or not _active or Ui.dialogue.visible:
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or not KEYS.has(key.physical_keycode):
		return
	step(KEYS[key.physical_keycode])
	get_viewport().set_input_as_handled()


## Ведёт перемещение голов, взрывы и вспышку.
## [param delta] - время кадра в секундах.
func _process(delta: float) -> void:
	_clock += delta
	_slide = minf(_slide + delta / SLIDE_SEC, 1.0)
	_flash.a = maxf(_flash.a - delta * 2.0, 0.0)
	for blast: Dictionary in _blasts:
		blast["t"] += delta
	_blasts = _blasts.filter(func(blast: Dictionary) -> bool: return blast["t"] < BLAST_SEC)
	queue_redraw()


## Рисует поле, бомбы, подпалины, героя, клона, взрывы и счёт.
func _draw() -> void:
	draw_texture(BOARD, Vector2.ZERO)
	if _logic == null:
		return
	for bomb: Vector2i in _logic.blown:
		draw_circle(_cell_rect(bomb).get_center(), 14.0, SCORCH)
	if _reveal:
		var pulse := 0.35 + 0.25 * sin(_clock * 8.0)
		for bomb: Vector2i in _logic.bombs:
			if _logic.is_bomb(bomb):
				var box := _cell_rect(bomb).grow(-3.0)
				draw_rect(box, Color(BOMB, pulse))
				draw_rect(box, BOMB, false, 2.0)
	var eased := 1.0 - pow(1.0 - _slide, 3.0)
	var clone_at := _clone_from.lerp(_clone_pos(), eased)
	var hero_at := _hero_from.lerp(_hero_pos(), eased)
	_draw_head(CLONE, clone_at, _clone_angle, Color(1.0, 0.75, 1.0))
	_draw_head(HERO, hero_at, _hero_angle, Color.WHITE)
	for blast: Dictionary in _blasts:
		_draw_blast(blast["at"], blast["t"] / BLAST_SEC)
	var font := Palette.font()
	var left := tr("MIRROR_BOMBS").format({"done": MirrorLogic.BOMBS - _logic.bombs_left()})
	_label(font, Vector2(8.0, 12.0), left, Palette.GOAL)
	var moves := tr("MIRROR_MOVES").format({"left": _logic.moves_left()})
	var width := font.get_string_size(moves, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8).x
	_label(font, Vector2(size.x - 8.0 - width, 12.0), moves, Palette.TEXT)
	_label(font, Vector2(8.0, size.y - 6.0), tr("MIRROR_HINT"), Palette.NEUTRAL)
	if _flash.a > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), _flash)


## Ставит головы по местам и сбрасывает взрывы.
func _restart_view() -> void:
	_hero_from = _hero_pos()
	_clone_from = _clone_pos()
	_slide = 1.0
	_hero_angle = 0.0
	_clone_angle = 0.0
	_blasts.clear()
	_reveal = false


## Подписывается на события правил.
func _connect_logic() -> void:
	_logic.clone_hit.connect(_on_clone_hit)
	_logic.hero_hit.connect(_on_hero_hit)
	_logic.won.connect(_on_done)
	_logic.lost.connect(_on_done)


## Возвращает прямоугольник клетки на экране.
## [param cell] - клетка.
func _cell_rect(cell: Vector2i) -> Rect2:
	var top_left := Vector2(COLUMN_X[cell.x], ROW_Y[cell.y])
	return Rect2(top_left, Vector2(COLUMN_X[cell.x + 1], ROW_Y[cell.y + 1]) - top_left)


## Возвращает середину клетки героя.
func _hero_pos() -> Vector2:
	return _cell_rect(_logic.hero).get_center()


## Возвращает середину клетки клона.
func _clone_pos() -> Vector2:
	return _cell_rect(_logic.clone).get_center()


## Рисует голову сверху, повёрнутую по ходу, с тенью.
## [param texture] - рисунок головы.
## [param at] - середина.
## [param angle] - поворот.
## [param tint] - оттенок.
func _draw_head(texture: Texture2D, at: Vector2, angle: float, tint: Color) -> void:
	var bob := sin(_clock * 6.0) * 0.5 if _slide >= 1.0 else 0.0
	draw_circle(at + Vector2(2.0, 4.0), 18.0, Color(0.0, 0.0, 0.0, 0.3))
	draw_set_transform(at + Vector2(0.0, bob), angle)
	draw_texture(texture, -texture.get_size() * 0.5, tint)
	draw_set_transform(Vector2.ZERO)


## Рисует взрыв: вспышку, два кольца и разлёт клеток шахматки.
## [param at] - середина взрыва.
## [param share] - доля прошедшего времени от 0 до 1.
func _draw_blast(at: Vector2, share: float) -> void:
	var fade := 1.0 - share
	draw_circle(at, 24.0 * (1.0 - share * 0.5), Color(1.0, 0.85, 0.4, 0.8 * fade))
	draw_arc(at, 10.0 + share * 40.0, 0.0, TAU, 24, Color(1.0, 0.4, 0.1, fade), 3.0)
	draw_arc(at, 4.0 + share * 26.0, 0.0, TAU, 20, Color(1.0, 0.0, 1.0, fade), 2.0)
	for piece: int in 10:
		var angle := TAU * piece / 10.0 + piece
		var reach := share * (30.0 + piece * 3.0)
		var color := Color(1.0, 0.0, 1.0, fade) if piece % 2 == 0 else Color(0.0, 0.07, 0.0, fade)
		draw_rect(Rect2(at + Vector2(cos(angle), sin(angle)) * reach, Vector2(4.0, 4.0)), color)


## Рисует строку с тёмной обводкой.
## [param font] - шрифт.
## [param at] - начало базовой линии.
## [param text] - строка.
## [param color] - цвет.
func _label(font: Font, at: Vector2, text: String, color: Color) -> void:
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8, 4, Palette.UI_SOLID)
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8, color)


## Клон наступил на бомбу: взрыв на его клетке.
## [param cell] - клетка бомбы.
func _on_clone_hit(cell: Vector2i) -> void:
	_blasts.append({"at": _cell_rect(cell).get_center(), "t": 0.0})
	_flash = Color(1.0, 0.9, 0.6, 0.4)


## Герой наступил на бомбу: взрыв на его клетке и красная вспышка.
## [param cell] - клетка бомбы.
func _on_hero_hit(cell: Vector2i) -> void:
	_blasts.append({"at": _cell_rect(cell).get_center(), "t": 0.0})
	_flash = Color(1.0, 0.0, 0.0, 0.55)
	_reveal = true


## Попытка кончилась: показывает её конец и сообщает бою.
func _on_done() -> void:
	await get_tree().create_timer(END_SEC, true, false, true).timeout
	finished.emit()
