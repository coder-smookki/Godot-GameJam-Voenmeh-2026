class_name Hud
extends Control
## Постоянный интерфейс комнаты: задание, плашка этажа с заражением, затемнение отладчика.
##
## Ничего не опрашивает каждый кадр: обновляется по сигналам игры и заражения.

@onready var _task_panel: PanelContainer = $TaskPanel
@onready var _task_text: Label = $TaskPanel/Box/Text
@onready var _floor_name: Label = $FloorPanel/Box/Name
@onready var _infection: Label = $FloorPanel/Box/Infection
@onready var _dim: ColorRect = $Dim
@onready var _debugger_label: Label = $DebuggerLabel


## Прячет интерфейс до входа в первую комнату и подписывается на сигналы.
func _ready() -> void:
	hide()
	_dim.hide()
	_debugger_label.hide()
	Game.room_entered.connect(_on_room_entered)
	Game.rooms_left.connect(hide)
	Game.task_changed.connect(_on_task_changed)
	Game.slow_motion_changed.connect(_on_slow_motion_changed)
	Infection.changed.connect(_on_infection_changed)


## Показывает интерфейс и обновляет плашку этажа при входе в комнату.
## [param _code] - код комнаты; этаж берётся из системы заражения.
func _on_room_entered(_code: String) -> void:
	show()
	_refresh_floor()


## Обновляет строку задания.
## [param text_key] - ключ текста задания; при пустом ключе панель прячется.
func _on_task_changed(text_key: String) -> void:
	_task_panel.visible = not text_key.is_empty()
	_task_text.text = tr(text_key)


## Затемняет мир и показывает подпись режима отладчика.
## [param active] - true, пока время замедлено.
func _on_slow_motion_changed(active: bool) -> void:
	_dim.visible = active
	_debugger_label.visible = active


## Обновляет процент заражения, если изменился текущий этаж.
## [param level] - этаж, на котором изменилось заражение.
## [param _percent] - новое значение; плашка перечитывает его сама.
func _on_infection_changed(level: int, _percent: int) -> void:
	if level == Infection.current_floor:
		_refresh_floor()


## Перечитывает название этажа и его заражение.
func _refresh_floor() -> void:
	var level := Infection.current_floor
	_floor_name.text = tr(LocationCatalog.floor_key(level))
	_infection.visible = Infection.is_active(level) or Infection.is_cured(level)
	if Infection.is_cured(level):
		_infection.text = tr("HUD_CURED")
		_infection.modulate = Palette.OK
	else:
		_infection.text = tr("HUD_INFECTION").format({"percent": Infection.percent(level)})
		_infection.modulate = Palette.VIRUS
