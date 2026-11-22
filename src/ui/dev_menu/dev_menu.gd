class_name DevMenu
extends Modal
## Меню разработчика (F1): страница «Развилки» для проверки логики без прохождения игры.
##
## Позволяет выставить любую переменную мира, открыть экран развилки, открыть все этажи
## лифта, перейти к терминалам на крыше, посмотреть любую концовку и сводку финального боя.

const ROOF := "roof"
const FLOOR_MARKS: Array[String] = ["vanya_saved", "boss_2", "boss_3", "boss_4", "boss_5"]

var _controls: Dictionary = {}

@onready var _grid: GridContainer = $Panel/Box/Scroll/Grid
@onready var _fork_select: OptionButton = $Panel/Box/Forks/Select
@onready var _fork_open: Button = $Panel/Box/Forks/Open
@onready var _ending_select: OptionButton = $Panel/Box/Endings/Select
@onready var _ending_open: Button = $Panel/Box/Endings/Open
@onready var _to_roof: Button = $Panel/Box/Jumps/ToRoof
@onready var _open_floors: Button = $Panel/Box/Jumps/OpenFloors
@onready var _plan_button: Button = $Panel/Box/Jumps/Plan
@onready var _plan: Label = $Panel/Box/PlanText


## Строит поля для всех переменных мира и привязывает кнопки.
func _ready() -> void:
	for key: String in World.SCHEMA:
		_add_variable(key)
	for fork_id: String in ForkCatalog.ids():
		_fork_select.add_item(fork_id)
	for ending_id: String in EndingCatalog.ids():
		_ending_select.add_item("%d %s" % [EndingCatalog.number(ending_id), ending_id])
	_fork_open.pressed.connect(_on_fork_open_pressed)
	_ending_open.pressed.connect(_on_ending_open_pressed)
	_to_roof.pressed.connect(_on_to_roof_pressed)
	_open_floors.pressed.connect(_on_open_floors_pressed)
	_plan_button.pressed.connect(_show_plan)


## Перечитывает значения переменных при открытии меню.
func _opened() -> void:
	for key: String in _controls:
		_sync_control(key)
	_show_plan()
	_fork_select.grab_focus()


## Добавляет строку с названием переменной и полем для её значения.
## [param key] - имя переменной из схемы мира.
func _add_variable(key: String) -> void:
	var spec: Dictionary = World.SCHEMA[key]
	var label := Label.new()
	label.text = key
	_grid.add_child(label)
	var control: Control
	if spec.has("values"):
		var select := OptionButton.new()
		for value: Variant in spec["values"]:
			select.add_item(str(value) if str(value) != "" else "-")
		select.item_selected.connect(_on_option_selected.bind(key))
		control = select
	elif spec.has("max"):
		var spin := SpinBox.new()
		spin.max_value = spec["max"]
		spin.value_changed.connect(_on_number_changed.bind(key))
		control = spin
	else:
		var check := CheckBox.new()
		check.toggled.connect(_on_flag_toggled.bind(key))
		control = check
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_child(control)
	_controls[key] = control


## Показывает в поле текущее значение переменной, не вызывая её изменения.
## [param key] - имя переменной.
func _sync_control(key: String) -> void:
	var control: Control = _controls[key]
	var value: Variant = World.f[key]
	if control is OptionButton:
		control.select(World.SCHEMA[key]["values"].find(value))
	elif control is SpinBox:
		control.set_value_no_signal(float(value))
	elif control is CheckBox:
		control.set_pressed_no_signal(bool(value))


## Записывает в мир значение, выбранное из списка.
## [param index] - номер пункта списка.
## [param key] - имя переменной.
func _on_option_selected(index: int, key: String) -> void:
	World.set_value(key, World.SCHEMA[key]["values"][index])
	_show_plan()


## Записывает в мир число из поля счётчика.
## [param value] - новое значение поля.
## [param key] - имя переменной.
func _on_number_changed(value: float, key: String) -> void:
	World.set_value(key, int(value))
	_show_plan()


## Записывает в мир значение флажка.
## [param pressed] - новое состояние флажка.
## [param key] - имя переменной.
func _on_flag_toggled(pressed: bool, key: String) -> void:
	World.set_value(key, pressed)
	_show_plan()


## Открывает экран выбранной развилки.
func _on_fork_open_pressed() -> void:
	var fork_id := _fork_select.get_item_text(_fork_select.selected)
	close()
	Ui.fork.ask(fork_id)


## Показывает выбранную концовку.
func _on_ending_open_pressed() -> void:
	var ending_id := EndingCatalog.ids()[_ending_select.selected]
	close()
	Game.show_ending(ending_id)


## Переносит героя к терминалам на крыше.
func _on_to_roof_pressed() -> void:
	close()
	Game.goto_room(ROOF)


## Ставит отметки спасения Вани и побед над боссами: лифт открывает все этажи.
func _on_open_floors_pressed() -> void:
	for mark: String in FLOOR_MARKS:
		World.mark(mark)
	Ui.toast(tr("DEV_FLOORS_OPENED"), ToastStack.KIND_HINT)


## Показывает сводку финального боя и концовки для каждого терминала.
func _show_plan() -> void:
	var plan := FinalPlan.build()
	var lines: Array[String] = [
		"timer %d s" % int(plan["timer_sec"]),
		"capi %s · mozhaitsev %s" % [plan["capi_present"], plan["mozhaitsev_present"]],
	]
	for terminal: String in ["delete", "fix"]:
		var ending_id := World.ending(terminal)
		lines.append("%s -> %s" % [terminal, ending_id if ending_id != "" else "???"])
	_plan.text = "\n".join(lines)
