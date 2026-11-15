class_name GameClock
extends RefCounted
## Time and calendar. A day runs in ten-minute steps from the tuned start to
## the tuned end. Other systems learn of each step, hour, day and season
## through signals.

signal step_passed(minute: int)
signal hour_passed(hour: int)
signal day_started(day: int, season: int, year: int)
signal season_changed(season: int)
signal day_end_reached

const SEASONS: Array[String] = ["spring", "summer", "autumn", "winter"]

var tuning: Tuning
var day: int = 1          # 1..days_per_season
var season: int = 0       # 0..3
var year: int = 1
var minute: int = 360     # minutes since midnight of the current day; may pass 1440
var paused: bool = false
var speed_multiplier: float = 1.0
var _accum: float = 0.0


func _init(t: Tuning) -> void:
	tuning = t
	minute = tuning.integer("time.day_start_minute")


func season_name() -> String:
	return SEASONS[season]


func days_per_season() -> int:
	return tuning.integer("time.days_per_season")


## Days since spring 1 of year 1, starting at 0.
func absolute_day() -> int:
	return (year - 1) * 4 * days_per_season() + season * days_per_season() + (day - 1)


func step_minutes() -> int:
	return tuning.integer("time.minutes_per_step")


func steps_per_day() -> int:
	return (tuning.integer("time.day_end_minute") - tuning.integer("time.day_start_minute")) / step_minutes()


## Called every frame with real seconds. Returns the number of steps taken.
func process(real_delta: float) -> int:
	if paused:
		return 0
	_accum += real_delta * speed_multiplier
	var per_step := tuning.num("time.real_seconds_per_step")
	var steps := 0
	while _accum >= per_step and not is_day_over():
		_accum -= per_step
		advance_step()
		steps += 1
	return steps


func is_day_over() -> bool:
	return minute >= tuning.integer("time.day_end_minute")


func advance_step() -> void:
	if is_day_over():
		return
	minute += step_minutes()
	step_passed.emit(minute)
	if minute % 60 == 0:
		hour_passed.emit((minute / 60) % 24)
	if is_day_over():
		day_end_reached.emit()


## Moves the calendar to the next day and sets the clock.
func start_next_day(start_minute: int = -1) -> void:
	day += 1
	if day > days_per_season():
		day = 1
		season += 1
		if season > 3:
			season = 0
			year += 1
		season_changed.emit(season)
	minute = start_minute if start_minute >= 0 else tuning.integer("time.day_start_minute")
	_accum = 0.0
	day_started.emit(day, season, year)


func set_minute(m: int) -> void:
	minute = clampi(m, 0, tuning.integer("time.day_end_minute"))
	_accum = 0.0


## Time as shown to the player, in ten-minute steps, 12-hour style like Stardew.
func time_text() -> String:
	var m := minute % 1440
	var h := m / 60
	var mm := (m % 60) / 10 * 10
	var suffix := "am" if h < 12 else "pm"
	var h12 := h % 12
	if h12 == 0:
		h12 = 12
	return "%d:%02d %s" % [h12, mm, suffix]


func to_dict() -> Dictionary:
	return {"day": day, "season": season, "year": year, "minute": minute}


func from_dict(d: Dictionary) -> void:
	day = int(d["day"])
	season = int(d["season"])
	year = int(d["year"])
	minute = int(d["minute"])
	_accum = 0.0
