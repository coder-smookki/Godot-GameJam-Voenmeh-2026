class_name CapyPickup
extends Area2D
## Спрятанная капибара: парит высоко над полом, достать её можно только прыжком.
##
## Вокруг неё мерцают искры и дышит тёплое свечение, чтобы её было видно издалека. Когда герой
## её касается, капибара подпрыгивает, крутится и рассыпается золотыми клетками; счётчик
## капибар растёт ([method Story.find_capybara]). Найденная капибара больше не появляется.

const LAYER_PLAYER := 2
const RADIUS := 14.0
const GOLD := Color("ffc62e")
const BOB := 4.0
const SPARKS := 5

@export var mark_id: String = ""

var _capy: CapyPixel = null
var _clock: float = 0.0
var _taken: bool = false


## Убирает найденную капибару; иначе готовит фигурку и область касания.
func _ready() -> void:
	if mark_id.is_empty() or World.is_marked(mark_id):
		queue_free()
		return
	collision_layer = 0
	collision_mask = LAYER_PLAYER
	monitorable = false
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = RADIUS
	shape.shape = circle
	add_child(shape)
	_capy = CapyPixel.new()
	_capy.pixel = 1.5
	_capy.position = Vector2(0.0, 9.0)
	add_child(_capy)
	body_entered.connect(_on_body_entered)


## Покачивает капибару и перерисовывает искры.
## [param delta] - время кадра в секундах.
func _process(delta: float) -> void:
	_clock += delta
	if not _taken:
		_capy.position.y = 9.0 + sin(_clock * 2.4) * BOB
	queue_redraw()


## Рисует свечение и искры вокруг капибары.
func _draw() -> void:
	if _taken:
		return
	var breathe := 0.5 + 0.5 * sin(_clock * 3.0)
	for ring: int in 3:
		draw_circle(Vector2.ZERO, 14.0 + ring * 6.0, Color(GOLD, 0.06 + 0.05 * breathe))
	for index: int in SPARKS:
		var angle := _clock * 1.3 + TAU * index / SPARKS
		var at := Vector2(cos(angle), sin(angle) * 0.6) * 24.0
		var flash := absf(sin(_clock * 4.0 + index))
		var size := 1.0 + 2.0 * flash
		draw_rect(Rect2(at - Vector2(size, size) * 0.5, Vector2(size, size)), Color(GOLD, flash))


## Находит капибару, когда её коснулся герой.
## [param body] - тело в области.
func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		collect()


## Засчитывает находку и проигрывает радостный прыжок с золотыми клетками.
func collect() -> void:
	if _taken:
		return
	_taken = true
	set_deferred("monitoring", false)
	Story.find_capybara(mark_id)
	_burst()
	var hop := create_tween().set_parallel()
	hop.tween_property(_capy, "position:y", -40.0, 0.5).set_trans(Tween.TRANS_BACK)
	hop.tween_property(_capy, "scale", Vector2(1.6, 1.6), 0.5)
	hop.tween_property(_capy, "rotation", TAU, 0.6)
	hop.chain().tween_property(_capy, "modulate:a", 0.0, 0.3)
	hop.chain().tween_callback(queue_free)


## Выпускает золотые и розовые клетки.
func _burst() -> void:
	for color: Color in [GOLD, Color(1.0, 0.0, 1.0), Color.WHITE]:
		var cells := CPUParticles2D.new()
		cells.amount = 14
		cells.lifetime = 0.8
		cells.one_shot = true
		cells.explosiveness = 0.9
		cells.direction = Vector2.UP
		cells.spread = 180.0
		cells.initial_velocity_min = 60.0
		cells.initial_velocity_max = 160.0
		cells.gravity = Vector2(0.0, 220.0)
		cells.scale_amount_min = 2.0
		cells.scale_amount_max = 4.0
		cells.color = color
		cells.finished.connect(cells.queue_free)
		get_parent().add_child(cells)
		cells.global_position = global_position
		cells.emitting = true
