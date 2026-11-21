class_name Npc
extends Interactable
## Персонаж, с которым можно поговорить.
##
## Реплики задаются ключами текста в инспекторе и показываются в окне разговора.

@export var speaker_key: String = ""
@export var line_keys: PackedStringArray = PackedStringArray()


## Ставит подсказку «говорить», если она не задана в инспекторе.
func _ready() -> void:
	super()
	if prompt_key.is_empty():
		prompt_key = "PROMPT_TALK"


## Проигрывает реплики персонажа по порядку.
## [param _player] - герой, который начал разговор.
func _interact(_player: Player) -> void:
	var lines: Array[Dictionary] = []
	for key: String in line_keys:
		lines.append({"speaker": speaker_key, "text": key})
	if not lines.is_empty():
		Ui.dialogue.play(lines)
