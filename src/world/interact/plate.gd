class_name Plate
extends Label
## Табличка на двери: светлая пластина на двух винтах с тёмной надписью.
##
## Сама подгоняет ширину под текст и остаётся по центру двери.
## Постоянную подпись можно задать ключом текста прямо в сцене.

const PAPER := Color("e9e2cb")
const EDGE := Color("4e4029")
const INK := Color("1b2230")
const SCREW := Color("85724a")
const MARGINS := Vector4(9.0, 4.0, 9.0, 3.0)
const SCREW_INSET := 3.0

@export var text_key: String = ""


## Собирает пластину с утолщённым нижним краем и показывает постоянную подпись, если она задана.
func _ready() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = PAPER
	style.border_color = EDGE
	style.set_border_width_all(1)
	style.border_width_bottom = 2
	style.content_margin_left = MARGINS.x
	style.content_margin_top = MARGINS.y
	style.content_margin_right = MARGINS.z
	style.content_margin_bottom = MARGINS.w
	add_theme_stylebox_override("normal", style)
	add_theme_color_override("font_color", INK)
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if not text_key.is_empty():
		show_text(tr(text_key))


## Рисует два винта по краям пластины.
func _draw() -> void:
	var middle := floorf(size.y * 0.5) - 1.0
	draw_rect(Rect2(SCREW_INSET, middle, 2.0, 2.0), SCREW)
	draw_rect(Rect2(size.x - SCREW_INSET - 2.0, middle, 2.0, 2.0), SCREW)


## Показывает надпись заглавными буквами и выравнивает табличку по центру двери.
## [param value] - готовый текст; при пустом тексте табличка прячется.
func show_text(value: String) -> void:
	text = value.to_upper()
	visible = not value.is_empty()
	reset_size()
	position.x = -size.x * 0.5
