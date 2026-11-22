class_name SpeechBubble
extends Node2D
## Облачко с репликой: светлый пузырь с хвостиком, как в комиксе.
##
## Начало координат - кончик хвостика: его ставят туда, откуда доносится голос.
## Несколько реплик сменяют друг друга по кругу, а крик слегка трясёт облачко.

const PAPER := Color("f7f3e8")
const INK := Color("14161d")
const PADDING := Vector2(7.0, 5.0)
const TAIL_SIZE := Vector2(8.0, 9.0)
const CORNER := 4
const LINE_GAP := 3.0
const POP_SEC := 0.12
const POP_FROM := 0.6
const TICK_SEC := 0.09
const JITTER: Array[Vector2] = [
	Vector2.ZERO, Vector2(1.0, 0.0), Vector2(0.0, -1.0), Vector2(-1.0, 0.0)
]

@export var text_keys: PackedStringArray = PackedStringArray()
@export var period_sec: float = 2.2
@export var box_shift: float = 0.0
@export var shout: bool = false

var _lines: PackedStringArray = PackedStringArray()
var _index: int = 0
var _ticks: int = 0
var _style: StyleBoxFlat = null


## Собирает рамку пузыря, показывает первую реплику и запускает смену реплик и дрожание.
func _ready() -> void:
	_style = StyleBoxFlat.new()
	_style.bg_color = PAPER
	_style.border_color = INK
	_style.set_border_width_all(1)
	_style.set_corner_radius_all(CORNER)
	_style.anti_aliasing = false
	_show_line(0)
	if text_keys.size() < 2 and not shout:
		return
	var timer := Timer.new()
	timer.wait_time = TICK_SEC
	timer.timeout.connect(_on_tick)
	add_child(timer)
	timer.start()


## Рисует пузырь, хвостик и строки текста.
func _draw() -> void:
	if _lines.is_empty():
		return
	var font := Palette.font()
	var line_height := font.get_height(Palette.FONT_SIZE) + LINE_GAP
	var width := 0.0
	for line: String in _lines:
		width = maxf(width, _line_width(font, line))
	var box_size := Vector2(width, line_height * _lines.size() - LINE_GAP) + PADDING * 2.0
	var shake := JITTER[_ticks % JITTER.size()] if shout else Vector2.ZERO
	var corner := Vector2(box_shift - box_size.x * 0.5, -TAIL_SIZE.y - box_size.y) + shake
	var box := Rect2(corner.round(), box_size.round())
	draw_style_box(_style, box)
	var limit := CORNER + TAIL_SIZE.x
	var tail_x := clampf(box_shift * 0.3, box.position.x + limit, box.end.x - limit)
	var left := Vector2(tail_x - TAIL_SIZE.x * 0.5, box.end.y - 1.0)
	var right := Vector2(tail_x + TAIL_SIZE.x * 0.5, box.end.y - 1.0)
	draw_colored_polygon(PackedVector2Array([left, right, Vector2.ZERO]), PAPER)
	draw_line(left, Vector2.ZERO, INK, 1.0)
	draw_line(right, Vector2.ZERO, INK, 1.0)
	var baseline := box.position.y + PADDING.y + font.get_ascent(Palette.FONT_SIZE)
	for index: int in _lines.size():
		var start := Vector2(box.get_center().x - _line_width(font, _lines[index]) * 0.5, baseline)
		start.y += line_height * index
		draw_string(
			font,
			start.round(),
			_lines[index],
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			Palette.FONT_SIZE,
			INK
		)


## Считает ширину строки текста.
## [param font] - шрифт облачка.
## [param line] - строка текста.
## Возвращает ширину в пикселях.
func _line_width(font: Font, line: String) -> float:
	return font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1.0, Palette.FONT_SIZE).x


## Показывает реплику с коротким появлением от хвостика.
## [param index] - номер реплики в списке.
func _show_line(index: int) -> void:
	_index = index
	_lines = PackedStringArray()
	if index < text_keys.size():
		_lines = tr(text_keys[index]).split("\n")
	scale = Vector2(POP_FROM, POP_FROM)
	create_tween().tween_property(self, "scale", Vector2.ONE, POP_SEC)
	queue_redraw()


## Показывает готовую строку вместо реплик из ключей, например битые символы надписи ERROR.
## [param value] - текст реплики.
func say(value: String) -> void:
	_lines = PackedStringArray([value])
	scale = Vector2(POP_FROM, POP_FROM)
	create_tween().tween_property(self, "scale", Vector2.ONE, POP_SEC)
	show()
	queue_redraw()


## Двигает дрожание и по истечении срока показывает следующую реплику.
func _on_tick() -> void:
	_ticks += 1
	if text_keys.size() > 1 and _ticks * TICK_SEC >= period_sec:
		_ticks = 0
		_show_line((_index + 1) % text_keys.size())
	elif shout:
		queue_redraw()
