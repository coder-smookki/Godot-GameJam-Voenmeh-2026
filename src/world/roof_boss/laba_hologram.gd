class_name LabaHologram
extends Node2D
## ЛАБА на крыше: огромная голограмма папки «Лаба5.zip» с красными глазами.
##
## Голограмма рисуется полосами: в помехах полосы разъезжаются, по ней бегут строки
## развёртки, вокруг дышит голубое свечение, снизу бьёт луч проектора. Она парит и
## покачивается. Появляется из пикселей ([method materialize]), рычит при атаке
## ([method roar]), корёжится от отключённого правила ([method hurt]) и сжимается в шоке
## ([method shock]). Живёт и на паузе, чтобы двигаться во время разговоров.
## Начало координат - середина голограммы.

const ART: Texture2D = preload("res://assets/boss/roof/laba.png")
const STRIPS := 23
const GLOW := Color(0.45, 0.85, 1.0)
const SCAN := Color(0.0, 0.0, 0.0, 0.18)
const BOB := 6.0
const BOB_RATE := 1.3
const HURT_SEC := 0.8
const ROAR_SEC := 0.5

var power: float = 0.0
var size: float = 1.0
var shocked: bool = false

var _clock: float = 0.0
var _glitch: float = 0.0
var _hurt: float = 0.0
var _roar: float = 0.0
var _seed: int = 0


## Живёт и на паузе.
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = -15


## Собирает голограмму из пикселей: она мерцает и проявляется.
## [param sec] - сколько длится появление.
func materialize(sec: float = 1.6) -> void:
	_glitch = sec
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(self, "power", 1.0, sec).set_trans(Tween.TRANS_EXPO)
	await tween.finished


## Рычит: голограмма раздувается и краснеет.
func roar() -> void:
	_roar = ROAR_SEC
	_glitch = maxf(_glitch, 0.3)


## Корёжится от отключённого правила: сильные помехи и красная вспышка.
func hurt() -> void:
	_hurt = HURT_SEC
	_glitch = HURT_SEC


## Сжимается в шоке и перестаёт атаковать.
func shock() -> void:
	shocked = true
	_glitch = 1.0
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(self, "size", 0.45, 0.9).set_trans(Tween.TRANS_ELASTIC)


## Даёт помехи на время.
## [param sec] - сколько секунд.
func glitch(sec: float) -> void:
	_glitch = maxf(_glitch, sec)


## Ведёт часы, помехи и вспышки.
## [param delta] - время кадра в секундах.
func _process(delta: float) -> void:
	_clock += delta
	_glitch = maxf(_glitch - delta, 0.0)
	_hurt = maxf(_hurt - delta, 0.0)
	_roar = maxf(_roar - delta, 0.0)
	_seed = int(_clock * 24.0)
	queue_redraw()


## Рисует луч проектора, свечение, полосы голограммы и развёртку.
func _draw() -> void:
	if power <= 0.01:
		return
	var bob := sin(_clock * BOB_RATE) * BOB
	var swell := 1.0 + 0.12 * sin(_roar / ROAR_SEC * PI)
	var grow := size * swell
	var art_size := ART.get_size() * grow
	var top_left := Vector2(-art_size.x * 0.5, -art_size.y * 0.5 + bob)
	var flicker := 0.85 + 0.15 * sin(_clock * 17.0) * sin(_clock * 5.3)
	var alpha := power * flicker * (0.9 if not shocked else 0.7)
	var beam := PackedVector2Array(
		[
			Vector2(-art_size.x * 0.35, top_left.y + art_size.y),
			Vector2(art_size.x * 0.35, top_left.y + art_size.y),
			Vector2(18.0, 120.0),
			Vector2(-18.0, 120.0),
		]
	)
	draw_colored_polygon(beam, Color(GLOW, 0.12 * power))
	for ring: int in 4:
		var glow := Rect2(top_left, art_size).grow(6.0 + ring * 7.0)
		draw_rect(glow, Color(GLOW, 0.05 * power * (4 - ring)))
	var tint := (
		Color(1.0, 0.75, 0.75) if _hurt > 0.0 and int(_clock * 20.0) % 2 == 0 else Color.WHITE
	)
	if _roar > 0.0:
		tint = tint.lerp(Color(1.0, 0.5, 0.5), _roar / ROAR_SEC)
	var strip_height := art_size.y / STRIPS
	var source_height := ART.get_height() / float(STRIPS)
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed
	for index: int in STRIPS:
		var shift := 0.0
		if _glitch > 0.0 and rng.randf() < 0.35:
			shift = rng.randf_range(-14.0, 14.0) * minf(_glitch * 2.0, 1.0)
		var dest := Rect2(
			top_left + Vector2(shift, strip_height * index), Vector2(art_size.x, strip_height + 0.5)
		)
		var source := Rect2(0.0, source_height * index, ART.get_width(), source_height)
		draw_texture_rect_region(ART, dest, source, Color(tint, alpha))
	for row: int in range(int(top_left.y), int(top_left.y + art_size.y), 3):
		draw_line(
			Vector2(top_left.x, row),
			Vector2(top_left.x + art_size.x, row),
			Color(SCAN, SCAN.a * power)
		)
	if shocked:
		var font := Palette.font()
		var mark := "?!"
		var at := Vector2(art_size.x * 0.3, top_left.y - 6.0 + sin(_clock * 6.0) * 3.0)
		draw_string_outline(font, at, mark, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 32, 6, Color.BLACK)
		draw_string(font, at, mark, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 32, Color("ffc62e"))
