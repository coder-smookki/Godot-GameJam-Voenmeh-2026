class_name Interactable
extends Area2D
## Основа для всего, с чем герой взаимодействует: двери, персонажи, терминалы, предметы.
##
## Когда герой рядом, над объектом всплывает плашка-подсказка с клавишей и слегка покачивается.
## Наследники переопределяют [method _interact] и при необходимости [method prompt_text].

const ACTION_INTERACT := "interact"
const ACTION_ENTER := "enter"
const KEY_HINTS: Dictionary = {ACTION_INTERACT: "E", ACTION_ENTER: "W"}
const PROMPT_BORDER := Color(0.33, 0.39, 0.56)
const LAYER_INTERACTABLE := 4
const PROMPT_RISE := 4.0
const PROMPT_RISE_SEC := 0.12
const PROMPT_BOB := 2.0
const PROMPT_BOB_SEC := 0.5

@export_enum("interact", "enter") var action: String = ACTION_INTERACT
@export var prompt_key: String = ""
@export var prompt_offset: Vector2 = Vector2(0.0, -188.0)

var _prompt: Label = null
var _prompt_motion: Tween = null


## Настраивает слой столкновений и создаёт скрытую подсказку.
func _ready() -> void:
	collision_layer = LAYER_INTERACTABLE
	collision_mask = 0
	monitoring = false
	_prompt = Label.new()
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.position = prompt_offset
	_prompt.z_index = 50
	_prompt.add_theme_color_override("font_color", Palette.TEXT)
	_prompt.add_theme_stylebox_override("normal", Palette.frame(PROMPT_BORDER))
	_prompt.hide()
	add_child(_prompt)


## Показывает или прячет подсказку, когда герой подходит или уходит.
## [param focused] - true, если герой стоит рядом и выбрал этот объект.
func set_focused(focused: bool) -> void:
	_prompt.visible = focused
	if _prompt_motion != null and _prompt_motion.is_valid():
		_prompt_motion.kill()
	if not focused:
		return
	_show_prompt_text()
	_prompt.position.y = prompt_offset.y + PROMPT_RISE
	_prompt.modulate.a = 0.0
	_prompt_motion = create_tween()
	_prompt_motion.tween_property(_prompt, "position:y", prompt_offset.y, PROMPT_RISE_SEC)
	_prompt_motion.parallel().tween_property(_prompt, "modulate:a", 1.0, PROMPT_RISE_SEC)
	_prompt_motion.tween_callback(_bob_prompt)


## Запускает медленное покачивание подсказки вверх-вниз, пока герой стоит рядом.
func _bob_prompt() -> void:
	var top := prompt_offset.y - PROMPT_BOB
	_prompt_motion = create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	_prompt_motion.tween_property(_prompt, "position:y", top, PROMPT_BOB_SEC)
	_prompt_motion.tween_property(_prompt, "position:y", prompt_offset.y, PROMPT_BOB_SEC)


## Запускает взаимодействие, если оно сейчас доступно.
## [param player] - герой, который нажал клавишу.
func interact(player: Player) -> void:
	if not Game.is_busy() and not Ui.is_modal_open():
		_interact(player)
		if _prompt.visible:
			_show_prompt_text()


## Пишет текст на плашке подсказки и держит её по центру над объектом.
func _show_prompt_text() -> void:
	_prompt.text = prompt_text()
	_prompt.reset_size()
	_prompt.position.x = prompt_offset.x - _prompt.size.x * 0.5


## Собирает текст подсказки.
## Возвращает строку вида «[E] Говорить».
func prompt_text() -> String:
	return "[%s] %s" % [KEY_HINTS[action], tr(prompt_key)]


## Действие объекта; наследники переопределяют эту функцию.
## [param _player] - герой, который взаимодействует с объектом.
func _interact(_player: Player) -> void:
	pass
