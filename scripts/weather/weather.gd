class_name WeatherSystem
extends RefCounted
## Weather in three blocks a day: morning, afternoon, evening into night.
## Each block is drawn from the season's odds with a leaning toward keeping the
## block before. Days are drawn from the save's seed, so a day's weather is
## fixed once made. The radio gives a forecast that is usually right.

signal weather_changed(weather_id: String)

const DAYS_PER_YEAR_SEASONS := 4

var tuning: Tuning
var content: ContentDB
var seed_value: int = 0
var today: Array[String] = ["clear", "clear", "clear"]
var tomorrow: Array[String] = ["clear", "clear", "clear"]
var _last_reported: String = ""


func _init(t: Tuning, c: ContentDB) -> void:
	tuning = t
	content = c


func types() -> Array[String]:
	return content.ids("weather_types")


func row(id: String) -> Dictionary:
	return content.row("weather_types", id)


func odds(season_name: String) -> Dictionary:
	return content.row("weather_odds", season_name)["odds"]


func _season_of(abs_day: int) -> String:
	var dps := tuning.integer("time.days_per_season")
	return GameClock.SEASONS[(abs_day / dps) % 4]


func _day_in_season(abs_day: int) -> int:
	return abs_day % tuning.integer("time.days_per_season") + 1


## True in the last week of autumn and the first week of spring.
func is_shoulder(season_name: String, day_in_season: int) -> bool:
	var n := tuning.integer("weather.shoulder_days")
	var dps := tuning.integer("time.days_per_season")
	return (season_name == "autumn" and day_in_season > dps - n) or (season_name == "spring" and day_in_season <= n)


func _allowed(id: String, season_name: String, day_in_season: int) -> bool:
	var o := odds(season_name)
	if float(o.get(id, 0)) > 0.0:
		return true
	return id == "snow" and is_shoulder(season_name, day_in_season) and float(o.get("rain", 0)) > 0.0


## Draws one block from the season's odds.
func draw(season_name: String, day_in_season: int, rng: RandomNumberGenerator) -> String:
	var o := odds(season_name)
	var total := 0.0
	for k: String in o:
		total += float(o[k])
	var r := rng.randf() * total
	var picked := "clear"
	for id in types():
		var w := float(o.get(id, 0))
		if w <= 0.0:
			continue
		if r < w:
			picked = id
			break
		r -= w
	if picked == "rain" and is_shoulder(season_name, day_in_season):
		if rng.randf() < tuning.num("weather.shoulder_snow_share"):
			picked = "snow"
	return picked


## The next block after `prev`, leaning toward keeping it.
func next_block(prev: String, season_name: String, day_in_season: int, rng: RandomNumberGenerator) -> String:
	if prev != "" and rng.randf() < tuning.num("weather.keep_chance") and _allowed(prev, season_name, day_in_season):
		return prev
	return draw(season_name, day_in_season, rng)


func _rng_for(abs_day: int, salt: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, abs_day, salt])
	return rng


func generate_day(abs_day: int, prev: String) -> Array[String]:
	var rng := _rng_for(abs_day, "weather")
	var s := _season_of(abs_day)
	var d := _day_in_season(abs_day)
	var out: Array[String] = []
	var last := prev
	for i in 3:
		last = next_block(last, s, d, rng)
		out.append(last)
	return out


func new_game(new_seed: int, abs_day: int) -> void:
	seed_value = new_seed
	today = generate_day(abs_day, "")
	tomorrow = generate_day(abs_day + 1, today[2])
	_last_reported = ""


## Called when a new day begins.
func roll_day(abs_day: int) -> void:
	today = tomorrow.duplicate()
	tomorrow = generate_day(abs_day + 1, today[2])
	_last_reported = ""


func block_index(minute: int) -> int:
	var starts: Array = tuning.value("weather.blocks")
	var idx := 0
	for i in starts.size():
		if minute >= int(starts[i]):
			idx = i
	return idx


func current(minute: int) -> String:
	return today[block_index(minute)]


func current_row(minute: int) -> Dictionary:
	return row(current(minute))


## Emits weather_changed when the block's weather differs from last report.
func check_change(minute: int) -> void:
	var w := current(minute)
	if w != _last_reported:
		_last_reported = w
		weather_changed.emit(w)


## The weather coming at the next block today, or "" if none today.
func next_weather(minute: int) -> String:
	var b := block_index(minute)
	if b >= 2:
		return ""
	return today[b + 1]


## 0 when no change is coming; rises to 1 over the warning hour before a change.
func warning_amount(minute: int) -> float:
	var b := block_index(minute)
	if b >= 2 or today[b + 1] == today[b]:
		return 0.0
	var starts: Array = tuning.value("weather.blocks")
	var change_at := float(starts[b + 1])
	var warn := tuning.num("weather.warning_minutes")
	var t := float(minute) - (change_at - warn)
	if t < 0.0:
		return 0.0
	return clampf(t / warn, 0.0, 1.0)


## The radio forecast for a day. Each block is right with the tuned accuracy.
func forecast(abs_day: int) -> Dictionary:
	var rng := _rng_for(abs_day, "forecast")
	var s := _season_of(abs_day)
	var d := _day_in_season(abs_day)
	var blocks: Array[String] = []
	for i in 3:
		blocks.append(_forecast_one(today[i], s, d, rng))
	var main := _main_weather(tomorrow)
	var tom := _forecast_one(main, _season_of(abs_day + 1), _day_in_season(abs_day + 1), rng)
	return {"blocks": blocks, "tomorrow": tom}


func _main_weather(blocks: Array[String]) -> String:
	var best := blocks[0]
	var best_n := 0
	for w in blocks:
		var n := blocks.count(w)
		if n > best_n:
			best = w
			best_n = n
	return best


func _forecast_one(actual: String, season_name: String, day_in_season: int, rng: RandomNumberGenerator) -> String:
	if rng.randf() < tuning.num("weather.forecast_accuracy"):
		return actual
	# A wrong forecast names some other weather that could happen this season.
	var options: Array[String] = []
	for id in types():
		if id != actual and _allowed(id, season_name, day_in_season):
			options.append(id)
	if options.is_empty():
		for id in types():
			if id != actual:
				options.append(id)
	return options[rng.randi_range(0, options.size() - 1)]


# --- debug -------------------------------------------------------------

func force_now(minute: int, id: String) -> void:
	today[block_index(minute)] = id


func set_next_block(minute: int, id: String) -> void:
	var b := block_index(minute)
	if b < 2:
		today[b + 1] = id
	else:
		tomorrow[0] = id


func to_dict() -> Dictionary:
	return {"seed": seed_value, "today": today.duplicate(), "tomorrow": tomorrow.duplicate()}


func from_dict(d: Dictionary) -> void:
	seed_value = int(d["seed"])
	today.assign(d["today"])
	tomorrow.assign(d["tomorrow"])
	_last_reported = ""
