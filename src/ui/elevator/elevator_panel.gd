class_name ElevatorPanel
extends Modal
## Панель кнопок лифта крупным планом, как её нарисовала художница.
##
## Кнопки идут сверху вниз с первого этажа по пятый. Сколько кнопок горит, зависит от того,
## сколько этажей уже открыто: художница нарисовала четыре таких панели. Погасшие кнопки
## вирус стёр, они возвращаются после победы над боссом этажом ниже. Правила лежат в [Elevator].

const ART: Array[Texture2D] = [
	preload("res://assets/ui/lift/panel_1.png"),
	preload("res://assets/ui/lift/panel_2.png"),
	preload("res://assets/ui/lift/panel_3.png"),
	preload("res://assets/ui/lift/panel_4.png"),
]
const CIRCLE_X := 91.0
const CIRCLE_Y: Array[float] = [40.0, 81.0, 122.0, 164.0, 205.0]
const BUTTON_SIZE := Vector2(64.0, 32.0)
const LABEL_SHIFT := 26.0

var _buttons: Dictionary = {}

@onready var _art: TextureRect = $Art
@onready var _keys: Control = $Art/Keys
@onready var _info: Label = $Right/Box/Info
@onready var _back: Button = $Right/Box/Back


## Создаёт кнопки этажей поверх нарисованных кругов.
func _ready() -> void:
	for level: int in range(1, CIRCLE_Y.size() + 1):
		var button := Button.new()
		button.text = str(level)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.size = BUTTON_SIZE
		button.position = Vector2(
			CIRCLE_X - LABEL_SHIFT - BUTTON_SIZE.x * 0.5 + 6.0,
			CIRCLE_Y[level - 1] - BUTTON_SIZE.y * 0.5
		)
		for state: String in ["normal", "hover", "pressed", "disabled"]:
			button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		var focus := Palette.frame(Palette.GOAL, 2)
		focus.bg_color = Color(0.0, 0.0, 0.0, 0.0)
		button.add_theme_stylebox_override("focus", focus)
		button.add_theme_color_override("font_color", Palette.UI_SOLID)
		button.add_theme_color_override("font_focus_color", Palette.UI_SOLID)
		button.add_theme_color_override("font_disabled_color", Color(0.3, 0.3, 0.33))
		button.pressed.connect(ride.bind(level))
		button.focus_entered.connect(_describe.bind(level))
		button.mouse_entered.connect(button.grab_focus)
		_keys.add_child(button)
		_buttons[level] = button
	_back.pressed.connect(close)
	_back.focus_entered.connect(_describe.bind(0))


## Показывает панель с нужным числом горящих кнопок и ставит фокус на этаж, куда ведёт сюжет.
func _opened() -> void:
	_art.texture = ART[Elevator.stage() - 1]
	var current := Game.current_floor()
	var focused: Button = _back
	for level: int in _buttons:
		var button: Button = _buttons[level]
		var state := Elevator.state(level, current)
		button.disabled = state == Elevator.STATE_HERE or state == Elevator.STATE_LOCKED
		button.focus_mode = Control.FOCUS_NONE if button.disabled else Control.FOCUS_ALL
		if state == Elevator.STATE_GOAL:
			focused = button
	focused.grab_focus()
	_describe(0 if focused == _back else Elevator.goal_floor())


## Пишет справа, куда ведёт выбранная кнопка и можно ли туда ехать.
## [param level] - номер этажа; ноль для кнопки «назад».
func _describe(level: int) -> void:
	if level == 0:
		_info.text = tr("ELEVATOR_HINT")
		return
	var state := Elevator.state(level, Game.current_floor())
	_info.text = "%s\n%s" % [tr(Elevator.title_key(level)), _status_text(level, state)]


## Собирает строку состояния этажа.
## [param level] - номер этажа.
## [param state] - состояние кнопки из [Elevator].
## Возвращает готовый текст: «вы здесь», «доступен» или «кнопка пропала».
func _status_text(level: int, state: String) -> String:
	if state == Elevator.STATE_LOCKED:
		return tr(Elevator.lock_key(level))
	return tr("ELEVATOR_%s" % state.to_upper())


## Везёт героя на выбранный этаж; на закрытый этаж и на свой же этаж лифт не едет.
## [param level] - номер этажа.
func ride(level: int) -> void:
	if Elevator.state(level, Game.current_floor()) in [Elevator.STATE_HERE, Elevator.STATE_LOCKED]:
		return
	var target := Elevator.room(level)
	close()
	if not LocationCatalog.is_built(target):
		Ui.toast(tr("LOCK_NOT_BUILT"), ToastStack.KIND_HINT)
		return
	World.mark(Elevator.USED_MARK)
	Game.lift_floor = level
	Game.goto_room(target, Elevator.SPAWN)
