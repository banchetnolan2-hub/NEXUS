class_name NxFormat
extends RefCounted
## Text formatting helpers (French locale) shared by the interface.

const MONTHS := ["janv.", "févr.", "mars", "avr.", "mai", "juin",
	"juil.", "août", "sept.", "oct.", "nov.", "déc."]


## "à l'instant", "il y a 5 min", "il y a 3 h", "hier", or a date.
static func relative_time(unix_time: int, now: int = -1) -> String:
	if now < 0:
		now = int(Time.get_unix_time_from_system())
	var delta := now - unix_time
	if delta < 60:
		return "à l'instant"
	if delta < 3600:
		return "il y a %d min" % (delta / 60)
	if delta < 86400:
		return "il y a %d h" % (delta / 3600)
	if delta < 172800:
		return "hier"
	return date(unix_time)


## "9 oct. 2026, 14:05" (local time).
static func date(unix_time: int) -> String:
	var bias := int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	var d := Time.get_datetime_dict_from_unix_time(unix_time + bias)
	return "%d %s %d, %02d:%02d" % [d.day, MONTHS[d.month - 1], d.year, d.hour, d.minute]


## 0.75 -> "75 %"
static func percent(value: float) -> String:
	return "%d %%" % roundi(value * 100.0)
