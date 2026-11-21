class_name Interactable
extends Area2D
## Основа для всего, с чем герой взаимодействует: двери, персонажи, терминалы, предметы.
##
## Когда герой рядом, над объектом появляется подсказка с клавишей.
## Наследники переопределяют [method _interact] и при необходимости [method prompt_text].

const ACTION_INTERACT := "interact"
const ACTION_ENTER := "enter"
const KEY_HINTS: Dictionary = {ACTION_INTERACT: "E", ACTION_ENTER: "W"}
const PROMPT_WIDTH := 200.0
const LAYER_INTERACTABLE := 4

@export_enum("interact", "enter") var action: String = ACTION_INTERACT
@export var prompt_key: String = ""
@export var prompt_offset: Vector2 = Vector2(0.0, -106.0)

var _prompt: Label = null


## Настраивает слой столкновений и создаёт скрытую подсказку.
func _ready() -> void:
	collision_layer = LAYER_INTERACTABLE
	collision_mask = 0
	monitoring = false
	_prompt = Label.new()
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.size = Vector2(PROMPT_WIDTH, 10.0)
	_prompt.position = prompt_offset - Vector2(PROMPT_WIDTH * 0.5, 0.0)
	_prompt.z_index = 50
	_prompt.add_theme_color_override("font_color", Palette.TEXT)
	_prompt.add_theme_color_override("font_outline_color", Palette.UI_SOLID)
	_prompt.add_theme_constant_override("outline_size", 4)
	_prompt.hide()
	add_child(_prompt)


## Показывает или прячет подсказку, когда герой подходит или уходит.
## [param focused] - true, если герой стоит рядом и выбрал этот объект.
func set_focused(focused: bool) -> void:
	_prompt.visible = focused
	if focused:
		_prompt.text = prompt_text()


## Запускает взаимодействие, если оно сейчас доступно.
## [param player] - герой, который нажал клавишу.
func interact(player: Player) -> void:
	if not Game.is_busy() and not Ui.is_modal_open():
		_interact(player)
		if _prompt.visible:
			_prompt.text = prompt_text()


## Собирает текст подсказки.
## Возвращает строку вида «[E] Говорить».
func prompt_text() -> String:
	return "[%s] %s" % [KEY_HINTS[action], tr(prompt_key)]


## Действие объекта; наследники переопределяют эту функцию.
## [param _player] - герой, который взаимодействует с объектом.
func _interact(_player: Player) -> void:
	pass
