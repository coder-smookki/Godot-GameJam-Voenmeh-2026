class_name FinalPlan
extends RefCounted
## План финального боя на крыше, собранный из решений игрока.
##
## Определяет характер ЛАБЫ, длительность таймера и то, кто и как помогает.
## Бой читает этот план и ничего не решает сам.

const CONFIDENCE_START := 100
const CONFIDENCE_CUT_MOZH_OFF := 50
const MESSAGES_FOR_HINT := 3
const RAGE_FOR_STORM := 3


## Собирает план боя из текущего состояния мира.
## Возвращает словарь: line - линия ЛАБЫ, timer_sec - таймер города,
## confidence - начальная уверенность ЛАБЫ, phase_one_scale - множитель длины первой фазы,
## late_timer_speed - скорость таймера с третьей фазы, cats - число котов-защитников,
## medkits - число аптечек, fix_hint - есть ли подсказка к терминалу «ИСПРАВИТЬ»,
## helpers - коды помощников.
static func build() -> Dictionary:
	var f: Dictionary = World.f
	var confidence := CONFIDENCE_START
	if f["mozh"] == "off":
		confidence -= CONFIDENCE_CUT_MOZH_OFF
	return {
		"line": World.laba_line(),
		"timer_sec": World.final_timer_sec(),
		"confidence": confidence,
		"phase_one_scale": 0.5 if f["mozh"] == "clone" else 1.0,
		"late_timer_speed": 2.0 if f["mozh"] == "stay" else 1.0,
		"cats": int(f["cats"]) if f["logunova"] == "kind" else 0,
		"medkits": int(f["notes"]),
		"fix_hint": int(f["messages"]) >= MESSAGES_FOR_HINT,
		"helpers": helpers(),
	}


## Перечисляет помощников игрока в финале.
## Возвращает массив кодов: compiler_turret, manual_bombs, cat_shield, stamps,
## shield, storm, terminal_repair, quarantine_hold, confidence_cut.
static func helpers() -> Array[String]:
	var f: Dictionary = World.f
	var result: Array[String] = []
	match f["compiler"]:
		"fixed":
			result.append("compiler_turret")
		"deleted":
			result.append("manual_bombs")
	match f["logunova"]:
		"kind":
			result.append("cat_shield")
		"strict":
			result.append("stamps")
	if f["zeml"] != "":
		result.append("storm" if int(f["rage"]) >= RAGE_FOR_STORM else "shield")
	match f["mozh"]:
		"clone":
			result.append("terminal_repair")
		"stay":
			result.append("quarantine_hold")
		"off":
			result.append("confidence_cut")
	return result
