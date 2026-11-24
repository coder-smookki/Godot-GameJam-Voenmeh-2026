class_name StuckVanya
extends Interactable
## Ваня в гардеробе: сначала застрял в шахматке, после мини-игры «Тяни!» свободен.
##
## Сцену спасения показывают кадры художниц. До игры Ваня один упирается в ком шахматки,
## с началом игры его тянет герой. Каждый промах показывает следующий кадр, на третьем шахматка
## поглощает обоих, а через полсекунды отбрасывает героя назад, и он теряет сердце.
## Слои нарисованы на холсте всей комнаты, поэтому лежат в координатах комнаты и не двигаются
## вместе с этим узлом. Освобождённый Ваня вылетает из шахматки по дуге и встаёт лицом к герою.

const SAVED_MARK := "vanya_saved"
const RESCUE_TALK := "vanya_rescue"
const AFTER_TALK := "vanya_after"
const FREE_X := 470.0
const HERO_PULL_X := 500.0
const HERO_FREE_X := 380.0
const HERO_THROWN_FROM := 380.0
const THROW := Vector2(-320.0, -260.0)
const REMNANT_SCALE := 0.55
const SHRINK_SEC := 0.5
const SWALLOW_SEC := 0.5
const ZOOM := 1.2
const ZOOM_SEC := 0.25
const PULL_JOLT := 3.0
const JERK_JOLT := 9.0
const JOLT_SEC := 0.12
const SPARKS_SEC := 0.2
const MISS_TINT := Color(1.6, 0.5, 0.5)
const FLY_FROM := Vector2(40.0, -8.0)
const FLY_HEIGHT := 30.0
const FLY_SEC := 0.42
const FLY_SHADOW_SCALE := 0.5
const STUCK_TINT := Color(1.0, 0.35, 1.0)
const FLY_Z := 3
const FRAMES: Array[Texture2D] = [
	preload("res://assets/minigames/pull/pull_1.png"),
	preload("res://assets/minigames/pull/pull_2.png"),
	preload("res://assets/minigames/pull/pull_3.png"),
	preload("res://assets/minigames/pull/pull_4.png"),
]

var _player: Player = null
var _jolt: Tween = null
var _sparks_off: Tween = null

@onready var _body: Sprite2D = $Body
@onready var _shadow: Node2D = $Shadow
@onready var _cry: SpeechBubble = $Cry
@onready var _stuck: Sprite2D = $Art/Stuck
@onready var _pull: Sprite2D = $Art/Pull
@onready var _remnant: Sprite2D = $Art/Remnant
@onready var _sparks: CPUParticles2D = $Art/Sparks
@onready var _burst: CPUParticles2D = $Art/Burst
@onready var _barrier: CollisionShape2D = $Barrier/Shape


## Показывает Ваню застрявшим или свободным по состоянию мира.
func _ready() -> void:
	super()
	_show_state(World.is_marked(SAVED_MARK))


## Собирает текст подсказки: схватить за руку или поговорить.
## Возвращает строку подсказки с клавишей.
func prompt_text() -> String:
	prompt_key = "PROMPT_TALK" if World.is_marked(SAVED_MARK) else "PROMPT_GRAB_HAND"
	return super()


## Запускает мини-игру спасения, а после победы разговор; спасённый Ваня просто разговаривает.
## Камера приближается к герою на время игры. Проигравшего героя шахматка отбрасывает назад.
## [param player] - герой, который подошёл к Ване.
func _interact(player: Player) -> void:
	if World.is_marked(SAVED_MARK):
		_face(player)
		Ui.dialogue.play(DialogueCatalog.talk(AFTER_TALK))
		return
	_player = player
	set_focused(false)
	_cry.hide()
	_stuck.hide()
	player.hide()
	player.global_position.x = HERO_PULL_X
	player.zoom_camera(ZOOM, ZOOM_SEC)
	_show_pressure()
	Ui.pull.pulled.connect(_on_pulled)
	Ui.pull.jerk_done.connect(_on_jerk_done)
	Ui.pull.missed.connect(_on_missed)
	Music.play("pull")
	var won := await Ui.pull.play()
	Music.play("floor1" if won else Music.room_track(Game.room_code))
	Ui.pull.pulled.disconnect(_on_pulled)
	Ui.pull.jerk_done.disconnect(_on_jerk_done)
	Ui.pull.missed.disconnect(_on_missed)
	_sparks.emitting = false
	player.zoom_camera(1.0, ZOOM_SEC)
	if won:
		await _finish_rescue(player)
	else:
		await _throw_back(player)


## Освобождает Ваню: он вылетает из шахматки, её остаток сжимается, потом начинается разговор.
## [param player] - герой, который вытащил Ваню.
func _finish_rescue(player: Player) -> void:
	player.global_position.x = HERO_FREE_X
	player.show()
	World.mark(SAVED_MARK)
	_show_state(true)
	_face(player)
	_remnant.scale = Vector2.ONE
	SaveSystem.save_game()
	_fly_out(0.0)
	_body.modulate = STUCK_TINT
	_body.z_index = FLY_Z
	var small := Vector2(REMNANT_SCALE, REMNANT_SCALE)
	var tween := create_tween().set_parallel()
	tween.tween_property(_remnant, "scale", small, SHRINK_SEC).set_trans(Tween.TRANS_BACK).set_ease(
		Tween.EASE_IN
	)
	tween.tween_method(_fly_out, 0.0, 1.0, FLY_SEC)
	tween.tween_property(_body, "modulate", Color.WHITE, FLY_SEC)
	tween.tween_callback(_land).set_delay(FLY_SEC)
	await tween.finished
	Ui.dialogue.play(DialogueCatalog.talk(RESCUE_TALK))


## Ведёт Ваню по дуге из шахматки к месту, где он встанет; тень растёт по мере приземления.
## В полёте Ваня рисуется поверх шахматки и ещё окрашен в её цвет.
## [param progress] - доля полёта от 0 до 1.
func _fly_out(progress: float) -> void:
	_body.position = FLY_FROM.lerp(Vector2.ZERO, progress)
	_body.position.y -= FLY_HEIGHT * 4.0 * progress * (1.0 - progress)
	var grow := lerpf(FLY_SHADOW_SCALE, 1.0, progress)
	_shadow.scale = Vector2(grow, grow)


## Отмечает приземление Вани пылью из-под ног и коротким толчком камеры.
func _land() -> void:
	_body.z_index = 0
	Puff.spawn(get_parent(), global_position)
	_player.shake_camera(2.0, JOLT_SEC)


## Поворачивает Ваню лицом к герою; на кадре художниц он смотрит вправо.
## [param player] - герой, на которого смотрит Ваня.
func _face(player: Player) -> void:
	_body.flip_h = player.global_position.x < global_position.x


## Показывает, как шахматка накрыла обоих, и отбрасывает героя от кома назад; он теряет сердце.
## [param player] - герой, который проиграл мини-игру.
func _throw_back(player: Player) -> void:
	_show_pressure()
	await get_tree().create_timer(SWALLOW_SEC).timeout
	_show_state(false)
	player.global_position.x = HERO_THROWN_FROM
	player.show()
	player.knock_back(THROW)
	_burst.restart()
	_burst.emitting = true
	Ui.toast(tr("PULL_LOST"), ToastStack.KIND_LABA)
	Game.lose_heart()


## Показывает кадр мини-игры по тому, насколько шахматка наступила на героя.
func _show_pressure() -> void:
	_pull.texture = FRAMES[Ui.pull.pressure() - 1]
	_pull.show()


## Дёргает кадр назад, как будто герой рванул на себя, и возвращает его на место.
## [param distance] - на сколько пикселей отъезжает кадр.
func _jolt_frame(distance: float) -> void:
	if _jolt != null and _jolt.is_valid():
		_jolt.kill()
	_pull.position.x = -distance
	_jolt = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_jolt.tween_property(_pull, "position:x", 0.0, JOLT_SEC)


## Отвечает на нажатие нужной клавиши: рывок кадра, дрожь камеры и клетки из-под рук.
func _on_pulled() -> void:
	_jolt_frame(PULL_JOLT)
	_player.shake_camera(1.0, JOLT_SEC)
	_sparks.emitting = true
	if _sparks_off != null and _sparks_off.is_valid():
		_sparks_off.kill()
	_sparks_off = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_sparks_off.tween_interval(SPARKS_SEC)
	_sparks_off.tween_callback(_sparks.set_emitting.bind(false))


## Отмечает сделанный рывок: кадр дёргается, из шахматки вылетает сноп клеток.
## [param _index] - сколько рывков уже сделано.
func _on_jerk_done(_index: int) -> void:
	_jolt_frame(JERK_JOLT)
	_player.shake_camera(3.0, JOLT_SEC * 2.0)
	_burst.restart()
	_burst.emitting = true


## Отмечает промах: шахматка наступает, кадр краснеет, камеру встряхивает.
## [param _count] - сколько промахов уже было; кадр берётся из мини-игры.
func _on_missed(_count: int) -> void:
	_show_pressure()
	_player.shake_camera(4.0, JOLT_SEC * 2.0)
	_pull.modulate = MISS_TINT
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(_pull, "modulate", Color.WHITE, JOLT_SEC * 3.0)


## Расставляет сцену: Ваня в коме шахматки и преграда до спасения, свободный Ваня и остаток
## шахматки после.
## [param saved] - true, если Ваня уже свободен.
func _show_state(saved: bool) -> void:
	_stuck.visible = not saved
	_pull.hide()
	_remnant.visible = saved
	_remnant.scale = Vector2(REMNANT_SCALE, REMNANT_SCALE)
	_body.visible = saved
	_shadow.visible = saved
	_cry.visible = not saved
	_barrier.set_deferred("disabled", saved)
	if saved:
		position.x = FREE_X
