class_name Plate
extends Label
## Табличка над объектом: тёмная плашка со светлым текстом, как на макетах.
##
## Сама подгоняет ширину под текст и остаётся по центру над объектом.


## Задаёт тёмный фон таблички.
func _ready() -> void:
	add_theme_stylebox_override("normal", Palette.frame(Palette.UI_SOLID))
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


## Показывает текст и выравнивает табличку по центру объекта.
## [param value] - готовый текст; при пустом тексте табличка прячется.
func show_text(value: String) -> void:
	text = value
	visible = not value.is_empty()
	reset_size()
	position.x = -size.x * 0.5
