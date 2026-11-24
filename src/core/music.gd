extends Node
## Музыка игры: одна дорожка за раз, плавный переход между дорожками.
##
## Дорожка комнаты выбирается по коду комнаты и ходу сюжета ([method room_track]); бои,
## мини-игры, концовки и титры ставят свою дорожку через [method play] и возвращают дорожку
## комнаты через [method play_room]. Дорожки подобраны по названиям файлов от команды
## и лежат в assets/music, выровнены по громкости; они загружаются только когда нужны. Играет
## на шине Music тише голосов, а пока персонаж говорит, музыка приглушается ещё сильнее.

const DIR := "res://assets/music/"
const FADE_SEC := 1.2
const SILENT_DB := -40.0
const VOLUME_DB := -11.0
const DUCK_DB := -7.0
const DUCK_RATE := 20.0
const TRACKS: Array[String] = [
	"menu",
	"floor1_before",
	"floor1",
	"pull",
	"lift",
	"floor2",
	"boss2",
	"floor3",
	"boss3",
	"floor4",
	"boss4",
	"floor5",
	"boss5",
	"roof",
	"roof_rescue",
	"ending",
	"epilogue",
	"credits",
]

var current: String = ""

var _players: Array[AudioStreamPlayer] = []
var _active: int = 0
var _fade: Tween = null
var _duck: AudioEffectAmplify = null


## Создаёт два проигрывателя для перехода и слушает смену комнат.
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for index: int in 2:
		var player := AudioStreamPlayer.new()
		player.bus = &"Music"
		player.volume_db = SILENT_DB
		add_child(player)
		_players.append(player)
	Game.room_entered.connect(_on_room_entered)
	_duck = AudioEffectAmplify.new()
	AudioServer.add_bus_effect(AudioServer.get_bus_index(&"Music"), _duck)


## Приглушает музыку, пока звучит озвучка реплики, и плавно возвращает после.
## [param delta] - время кадра в секундах.
func _process(delta: float) -> void:
	var target := DUCK_DB if Ui.dialogue.is_speaking() else 0.0
	_duck.volume_db = move_toward(_duck.volume_db, target, DUCK_RATE * delta)


## Возвращает, на сколько децибел сейчас приглушена музыка; нужно тестам.
func duck_db() -> float:
	return _duck.volume_db


## Возвращает дорожку для комнаты по ходу сюжета.
## [param code] - код комнаты.
static func room_track(code: String) -> String:
	match code:
		"vestibule", "wardrobe":
			return "floor1" if World.is_marked("vanya_saved") else "floor1_before"
		"lift":
			return "lift"
		"corridor_2", "202":
			return "floor2"
		"corridor_3", "316":
			return "floor3"
		"corridor_4", "418":
			return "floor4"
		"corridor_5":
			return "floor5"
		"roof":
			return "roof"
	return ""


## Плавно переходит на дорожку; та же дорожка продолжает играть.
## [param track] - имя дорожки из [constant TRACKS]; пустая строка гасит музыку.
func play(track: String) -> void:
	if track == current:
		return
	current = track
	var old := _players[_active]
	_active = 1 - _active
	var next := _players[_active]
	if _fade != null and _fade.is_valid():
		_fade.kill()
	_fade = create_tween().set_parallel()
	_fade.tween_property(old, "volume_db", SILENT_DB, FADE_SEC)
	_fade.chain().tween_callback(old.stop)
	if track.is_empty() or not track in TRACKS:
		return
	var stream := load(DIR + track + ".mp3") as AudioStreamMP3
	if stream == null:
		return
	stream.loop = true
	next.stream = stream
	next.volume_db = SILENT_DB
	next.play()
	_fade.tween_property(next, "volume_db", VOLUME_DB, FADE_SEC)


## Возвращает дорожку текущей комнаты.
func play_room() -> void:
	play(room_track(Game.room_code))


## Гасит музыку.
func stop() -> void:
	play("")


## Ставит дорожку комнаты, в которую вошёл герой.
## [param code] - код комнаты.
func _on_room_entered(code: String) -> void:
	play(room_track(code))
