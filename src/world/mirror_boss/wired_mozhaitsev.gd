class_name WiredMozhaitsev
extends Node2D
## Мажайцев в проводах в коридоре пятого этажа: живой рисунок из двух циклов кадров.
##
## Когда он молчит, по кругу идут кадры с закрытым ртом (1, 2), когда говорит его реплика -
## кадры с открытым ртом (3, 4), чуть быстрее. Узел живёт и на паузе, потому что разговоры
## ставят мир на паузу. Начало координат - низ рисунка на полу.

const SPEAKER := "mozhaitsev"
const IDLE: Array[Texture2D] = [
	preload("res://assets/characters/mozhaitsev/wired_1.png"),
	preload("res://assets/characters/mozhaitsev/wired_2.png"),
]
const TALK: Array[Texture2D] = [
	preload("res://assets/characters/mozhaitsev/wired_3.png"),
	preload("res://assets/characters/mozhaitsev/wired_4.png"),
]
const IDLE_FPS := 2.5
const TALK_FPS := 6.0

var talking: bool = false

var _clock: float = 0.0
var _sprite: Sprite2D = null


## Создаёт рисунок и слушает разговоры.
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_sprite = Sprite2D.new()
	_sprite.centered = false
	_sprite.texture = IDLE[0]
	_sprite.offset = Vector2(-IDLE[0].get_width() * 0.5, -IDLE[0].get_height())
	add_child(_sprite)
	Ui.dialogue.line_shown.connect(_on_line_shown)
	Ui.dialogue.visibility_changed.connect(_on_dialogue_toggled)


## Сменяет кадры нужного цикла.
## [param delta] - время кадра в секундах.
func _process(delta: float) -> void:
	_clock += delta
	var frames := TALK if talking else IDLE
	var fps := TALK_FPS if talking else IDLE_FPS
	_sprite.texture = frames[int(_clock * fps) % frames.size()]


## Возвращает показанный кадр; нужно тестам.
func current_texture() -> Texture2D:
	return _sprite.texture


## Открывает рот на своих репликах и закрывает на чужих.
## [param line] - показанная реплика.
func _on_line_shown(line: Dictionary) -> void:
	talking = str(line.get("speaker", "")) == SPEAKER


## Закрывает рот, когда разговор кончился.
func _on_dialogue_toggled() -> void:
	if not Ui.dialogue.visible:
		talking = false
