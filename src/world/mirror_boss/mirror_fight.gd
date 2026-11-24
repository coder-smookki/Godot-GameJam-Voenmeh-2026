class_name MirrorFight
extends BossFight
## Коридор пятого этажа: Мажайцев в проводах и клон героя из пикселей.
##
## Герой идёт от лифта и вдали видит Мажайцева: камера переходит на него, герой зовёт его,
## Мажайцев велит стоять. Камера возвращается, и перед героем из клеток собирается его клон.
## Открывается поле ([MirrorGame]): Мажайцев подсказывает, клетки с бомбами горят красным,
## потом гаснут, и герой ходит так, чтобы клон, который шагает зеркально, наступил на все
## три бомбы, а сам герой - ни на одну. Неудача отнимает сердце, раскладка новая, Мажайцев
## подсвечивает бомбы снова. После победы клон рассыпается, Мажайцев отдаёт кнопку крыши
## и прощается.

signal finished

enum Phase { WAIT, INTRO, BOARD, OUTRO, DONE }

const BOSS_MARK := "boss_5"
const TRIGGER_X := 1300.0
const CLONE_GAP := 110.0
const FLOOR_Y := 254.0
const CLONE_TEXTURE: Texture2D = preload("res://assets/characters/clone/stand.png")
const BUILD_SEC := 0.8

@export var mozhaitsev: Node2D = null

var phase: Phase = Phase.WAIT

var _clone: Sprite2D = null


## Собирает камеру и прячет клона; после победы ничего не ждёт.
func _ready() -> void:
	_build_director(Vector2(TRIGGER_X, VIEW_Y))
	_build_bars()
	_build_hud()
	_clone = Sprite2D.new()
	_clone.texture = CLONE_TEXTURE
	_clone.centered = false
	_clone.offset = Vector2(-CLONE_TEXTURE.get_width() * 0.5, -CLONE_TEXTURE.get_height())
	_clone.hide()
	add_child(_clone)
	if World.is_marked(BOSS_MARK):
		phase = Phase.DONE


## Ждёт, когда герой подойдёт достаточно близко, чтобы увидеть Мажайцева вдали.
## [param _delta] - время кадра в секундах.
func _process(_delta: float) -> void:
	if phase != Phase.WAIT or Ui.is_modal_open() or Game.is_busy():
		return
	var room := get_tree().current_scene as Room
	if room != null and room.player != null and room.player.global_position.x < TRIGGER_X:
		start()


## Сообщает, идёт ли бой прямо сейчас.
func is_running() -> bool:
	return phase != Phase.WAIT and phase != Phase.DONE


## Начинает бой: Мажайцев вдали, клон перед героем, поле с бомбами.
func start() -> void:
	if phase != Phase.WAIT:
		return
	var room := get_tree().current_scene as Room
	if room == null or room.player == null:
		return
	phase = Phase.INTRO
	_player = room.player
	Music.play("boss5")
	_freeze(true)
	Ui.hud.hide_task(true)
	_director.global_position = _hero_view()
	_director.zoom = Vector2.ONE
	_take_view()
	if mozhaitsev != null:
		await _pan(Vector2(mozhaitsev.global_position.x + 60.0, VIEW_Y), 1.2)
	await Ui.dialogue.play(DialogueCatalog.talk("mozhaitsev_far"))
	if not is_inside_tree():
		return
	await _pan(_hero_view(), 0.9)
	_give_view()
	await _build_clone()
	await Ui.dialogue.play(DialogueCatalog.talk("mozhaitsev_clone"))
	if not is_inside_tree():
		return
	phase = Phase.BOARD
	await _board()


## Проводит попытки на поле до победы; неудача отнимает сердце.
func _board() -> void:
	Ui.mirror.prepare()
	var talk := "mozhaitsev_hint"
	while true:
		Ui.mirror.set_reveal(true)
		await Ui.dialogue.play(DialogueCatalog.talk(talk))
		if not is_inside_tree():
			return
		await get_tree().create_timer(Ui.mirror.logic().reveal_sec, true, false, true).timeout
		Ui.mirror.set_reveal(false)
		var won: bool = await Ui.mirror.play()
		if not is_inside_tree():
			return
		if won:
			break
		if int(World.f[Game.HEARTS]) <= 1:
			Ui.mirror.close_board()
			Game.lose_heart()
			return
		Game.lose_heart()
		talk = "mozhaitsev_retry"
		Ui.mirror.retry()
	Ui.mirror.close_board()
	await _outro()


## Победа: клон рассыпается, Мажайцев отдаёт кнопку крыши и прощается.
func _outro() -> void:
	phase = Phase.OUTRO
	_cure_burst(_clone.global_position + Vector2(0.0, -90.0))
	_shake_camera(5.0, 0.5)
	var crumble := create_tween().set_parallel()
	crumble.tween_property(_clone, "scale", Vector2(1.3, 0.1), 0.5).set_ease(Tween.EASE_IN)
	crumble.tween_property(_clone, "modulate:a", 0.0, 0.5)
	await crumble.finished
	_clone.hide()
	await _wait(0.4)
	_director.global_position = _hero_view()
	_take_view()
	if mozhaitsev != null:
		await _pan(Vector2(mozhaitsev.global_position.x + 60.0, VIEW_Y), 1.0)
	await Ui.dialogue.play(DialogueCatalog.talk("mozhaitsev_free"))
	if not is_inside_tree():
		return
	await _step_out()
	await _pan(_hero_view(), 0.9)
	_give_view()
	Story.give_message("message_3", "LABA_MESSAGE_3")
	Music.play_room()
	_freeze(false)
	Ui.hud.hide_task(false)
	phase = Phase.DONE
	World.mark(BOSS_MARK)
	SaveSystem.save_game()
	finished.emit()


## Мажайцев выбирается из проводов и подходит к герою: провода осыпаются клетками.
func _step_out() -> void:
	if mozhaitsev == null:
		return
	_cure_burst(mozhaitsev.global_position + Vector2(0.0, -90.0))
	_burst(mozhaitsev.global_position + Vector2(0.0, -40.0), Color("6a4fd8"), 30, 160.0, 2.0, 4.0)
	_shake_camera(4.0, 0.4)
	mozhaitsev.hide()
	var walker := Walker.mozhaitsev()
	walker.name = "MozhaitsevFree"
	walker.position = mozhaitsev.position
	mozhaitsev.get_parent().add_child(walker)
	await _pan(Vector2(_player.global_position.x - 80.0, VIEW_Y), 1.4)
	await walker.walk_to(_player.global_position.x - 70.0)
	walker.face(1.0)
	await Ui.dialogue.play(DialogueCatalog.talk("mozhaitsev_join"))


## Собирает клона перед героем из клеток шахматки: он мерцает и проявляется.
func _build_clone() -> void:
	_clone.global_position = Vector2(_player.global_position.x - CLONE_GAP, FLOOR_Y)
	_clone.modulate = Color(1.0, 0.3, 1.0, 0.0)
	_clone.show()
	_burst(_clone.global_position + Vector2(0.0, -90.0), Color(1.0, 0.0, 1.0), 30, 120.0, 2.0, 5.0)
	_burst(_clone.global_position + Vector2(0.0, -60.0), Color(0.0, 0.07, 0.0), 20, 100.0, 2.0, 5.0)
	_shake_camera(4.0, 0.4)
	var appear := create_tween()
	for flick: int in 3:
		appear.tween_property(_clone, "modulate:a", 0.8, BUILD_SEC / 8.0)
		appear.tween_property(_clone, "modulate:a", 0.2, BUILD_SEC / 8.0)
	appear.tween_property(_clone, "modulate", Color.WHITE, BUILD_SEC / 4.0)
	await appear.finished
