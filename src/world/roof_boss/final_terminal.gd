class_name FinalTerminal
extends Interactable
## Терминал последнего выбора: поднимается из крыши перед героем и Ваней.
##
## Нарисован в коде: стойка, экран с бегущим курсором и свечение. Поднимается из крыши
## ([method rise]); у героя спрашивает, что сделать с ЛАБОЙ ([ChoiceScreen]), и сообщает
## выбор сигналом.

signal chosen(terminal: String)

const SIZE := Vector2(46.0, 70.0)
const SCREEN := Rect2(-18.0, -64.0, 36.0, 24.0)
const METAL := Color("2b3142")
const METAL_LIGHT := Color("47506a")
const GREEN := Color("2ee05a")
const RISE_SEC := 0.9

var _rise: float = 0.0
var _clock: float = 0.0


## Готовит область взаимодействия и подсказку.
func _ready() -> void:
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(80.0, 90.0)
	shape.shape = rect
	shape.position = Vector2(0.0, -45.0)
	add_child(shape)
	prompt_key = "PROMPT_CHOOSE"
	prompt_offset = Vector2(0.0, -96.0)
	super()
	monitorable = false


## Поднимается из крыши; после этого к терминалу можно подойти.
func rise() -> void:
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(self, "_rise", 1.0, RISE_SEC).set_trans(Tween.TRANS_BACK)
	await tween.finished
	monitorable = true


## Спрашивает выбор и сообщает его.
## [param _player] - герой.
func _interact(_player: Player) -> void:
	var terminal: String = await Ui.choice.ask()
	chosen.emit(terminal)


## Ведёт мигание экрана.
## [param delta] - время кадра в секундах.
func _process(delta: float) -> void:
	_clock += delta
	queue_redraw()


## Рисует свечение, стойку и экран.
func _draw() -> void:
	if _rise <= 0.01:
		return
	draw_set_transform(Vector2(0.0, SIZE.y * (1.0 - _rise)))
	var glow := 0.25 + 0.1 * sin(_clock * 4.0)
	draw_rect(
		Rect2(-SIZE.x * 0.5 - 8.0, -SIZE.y - 8.0, SIZE.x + 16.0, SIZE.y + 8.0),
		Color(GREEN, glow * 0.4)
	)
	draw_rect(Rect2(-8.0, -40.0, 16.0, 40.0), METAL)
	draw_rect(Rect2(-SIZE.x * 0.5, -SIZE.y, SIZE.x, 34.0), METAL)
	draw_rect(Rect2(-SIZE.x * 0.5, -SIZE.y, 3.0, 34.0), METAL_LIGHT)
	draw_rect(SCREEN, Color(0.01, 0.06, 0.02))
	for row: int in 3:
		var width := 12.0 + 8.0 * ((row + int(_clock * 3.0)) % 3)
		draw_rect(
			Rect2(SCREEN.position + Vector2(3.0, 4.0 + row * 6.0), Vector2(width, 2.0)), GREEN
		)
	if int(_clock * 2.0) % 2 == 0:
		draw_rect(Rect2(SCREEN.position + Vector2(26.0, 16.0), Vector2(4.0, 2.0)), GREEN)
	draw_set_transform(Vector2.ZERO)
