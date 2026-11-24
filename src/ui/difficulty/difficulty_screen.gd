class_name DifficultyScreen
extends Modal
## Выбор сложности перед новой игрой: четыре уровня из [Difficulty].
##
## У каждого уровня своя кнопка с цветом и рядом сердец, которые будут у героя; под кнопками
## описание выбранного уровня. Закрытие клавишей отмены отменяет новую игру.

signal chosen(level: String)

const COLORS: Array[Color] = [Color("2ea043"), Color("ffc62e"), Color("ff8a1c"), Color("d81e1e")]
const BUTTON_SIZE := Vector2(280.0, 20.0)
const HEART_STEP := 11.0
const POP_SEC := 0.12

var _pending: bool = false
var _buttons: Array[Button] = []

@onready var _levels: VBoxContainer = $Panel/Box/Levels
@onready var _hint: Label = $Panel/Box/Hint


## Создаёт кнопки уровней: название слева, сердца справа.
func _ready() -> void:
	for index: int in Difficulty.LEVELS.size():
		var level := Difficulty.LEVELS[index]
		var button := Button.new()
		button.custom_minimum_size = BUTTON_SIZE
		button.text = tr(Difficulty.name_key(level))
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_color_override("font_color", COLORS[index])
		button.add_theme_color_override("font_focus_color", Color.WHITE)
		button.add_theme_color_override("font_hover_color", Color.WHITE)
		button.pressed.connect(_answer.bind(level))
		button.focus_entered.connect(_on_focused.bind(index))
		button.mouse_entered.connect(button.grab_focus)
		var hearts := Control.new()
		hearts.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hearts.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		hearts.draw.connect(_draw_hearts.bind(hearts, int(Difficulty.value("hearts", level))))
		button.add_child(hearts)
		_levels.add_child(button)
		_buttons.append(button)


## Показывает уровни и ждёт выбора; по умолчанию выбран средний.
## Возвращает выбранный уровень или пустую строку, если выбор отменён.
func choose() -> String:
	_pending = true
	open()
	_buttons[Difficulty.LEVELS.find(Difficulty.MEDIUM)].grab_focus()
	var level: String = await chosen
	close()
	return level


## Отменяет выбор, если окно закрыли без ответа.
func _closed() -> void:
	_answer("")


## Сообщает выбор один раз.
## [param level] - уровень или пустая строка.
func _answer(level: String) -> void:
	if not _pending:
		return
	_pending = false
	chosen.emit(level)


## Рисует сердца уровня у правого края кнопки.
## [param item] - узел поверх кнопки.
## [param count] - сколько сердец.
func _draw_hearts(item: Control, count: int) -> void:
	var y := (item.size.y - Hearts.HEIGHT) * 0.5
	for index: int in count:
		var at := Vector2(item.size.x - 8.0 - (index + 1) * HEART_STEP, y).round()
		Hearts.draw_heart(item, at, Hearts.FULL)


## Показывает описание уровня под кнопками и слегка подбрасывает выбранную кнопку.
## [param index] - номер уровня.
func _on_focused(index: int) -> void:
	_hint.text = tr(Difficulty.hint_key(Difficulty.LEVELS[index]))
	_hint.add_theme_color_override("font_color", COLORS[index])
	var button := _buttons[index]
	button.pivot_offset = button.size * 0.5
	button.scale = Vector2(1.04, 1.04)
	create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).tween_property(
		button, "scale", Vector2.ONE, POP_SEC
	)
