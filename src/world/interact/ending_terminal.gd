class_name EndingTerminal
extends Interactable
## Терминал на крыше: развилка P3 «Два терминала».
##
## Концовку определяет мир по выбранному терминалу. Закрытый терминал
## объясняет, чего не хватило.

@export_enum("delete", "fix") var terminal: String = "delete"

@onready var _plate: Plate = $Plate
@onready var _status: Plate = $Status


## Подписывает терминал и показывает условие его доступности.
func _ready() -> void:
	super()
	prompt_key = "PROMPT_CHOOSE"
	World.changed.connect(_on_world_changed)
	refresh()


## Обновляет название и строку условия на терминале.
func refresh() -> void:
	var available := not World.ending(terminal).is_empty()
	_plate.show_text(tr("TERMINAL_%s" % terminal.to_upper()) if available else "???")
	var counts: Dictionary = {
		"messages": World.f["messages"],
		"needed": World.MESSAGES_FOR_FIX,
	}
	_status.show_text(tr("TERMINAL_%s_STATUS" % terminal.to_upper()).format(counts))


## Запускает концовку терминала или объясняет, почему он закрыт.
## [param _player] - герой, который выбрал терминал.
func _interact(_player: Player) -> void:
	var ending_id := World.ending(terminal)
	if ending_id.is_empty():
		Ui.toast(tr("TERMINAL_LOCKED"), ToastStack.KIND_HINT)
	else:
		Game.show_ending(ending_id)


## Обновляет терминал, когда меняется число посланий или капибар.
## [param _key] - имя переменной; терминал перечитывает всё сам.
## [param _value] - новое значение переменной.
func _on_world_changed(_key: String, _value: Variant) -> void:
	refresh()
