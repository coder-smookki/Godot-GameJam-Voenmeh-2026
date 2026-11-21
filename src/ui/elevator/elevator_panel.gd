class_name ElevatorPanel
extends Modal
## Панель лифта: пять кнопок этажей.
##
## Панель одна на всю игру, меняется только состояние кнопок. Закрытая кнопка
## всегда говорит, что нужно сделать, чтобы этаж открылся. Правила лежат в [Elevator].

const LINE_SPACING := 3

var _buttons: Dictionary = {}

@onready var _list: VBoxContainer = $Panel/Box/List
@onready var _back: Button = $Panel/Box/Back


## Создаёт кнопки этажей сверху вниз.
func _ready() -> void:
	for level: int in Elevator.FLOORS:
		var button := Button.new()
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_constant_override("line_spacing", LINE_SPACING)
		button.pressed.connect(ride.bind(level))
		_list.add_child(button)
		_buttons[level] = button
	_back.pressed.connect(close)


## Обновляет состояние кнопок и ставит фокус на этаж, куда ведёт сюжет.
func _opened() -> void:
	var current := LocationCatalog.floor_of(Game.room_code)
	var focused: Button = _back
	for level: int in Elevator.FLOORS:
		var button: Button = _buttons[level]
		var state := Elevator.state(level, current)
		button.text = "%s\n%s" % [tr(Elevator.title_key(level)), _status_text(level, state)]
		button.disabled = state == Elevator.STATE_HERE or state == Elevator.STATE_LOCKED
		button.remove_theme_stylebox_override("normal")
		if state == Elevator.STATE_GOAL:
			button.add_theme_stylebox_override("normal", Palette.frame(Palette.GOAL))
			focused = button
	focused.grab_focus()


## Собирает вторую строку кнопки этажа.
## [param level] - номер этажа.
## [param state] - состояние кнопки из [Elevator].
## Возвращает готовый текст: «вы здесь», «доступен» или причину, почему этаж закрыт.
func _status_text(level: int, state: String) -> String:
	if state == Elevator.STATE_LOCKED:
		return tr(Elevator.lock_key(level))
	return tr("ELEVATOR_%s" % state.to_upper())


## Везёт героя на выбранный этаж; на закрытый этаж и на свой же этаж лифт не едет.
## [param level] - номер этажа.
func ride(level: int) -> void:
	var current := LocationCatalog.floor_of(Game.room_code)
	if Elevator.state(level, current) in [Elevator.STATE_HERE, Elevator.STATE_LOCKED]:
		return
	var target := Elevator.room(level)
	close()
	if not LocationCatalog.is_built(target):
		Ui.toast(tr("LOCK_NOT_BUILT"), ToastStack.KIND_HINT)
		return
	World.mark(Elevator.USED_MARK)
	Game.goto_room(target, Elevator.SPAWN)
