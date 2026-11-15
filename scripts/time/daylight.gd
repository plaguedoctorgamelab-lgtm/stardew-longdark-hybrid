class_name Daylight
extends RefCounted
## Works out the light for a time of day and season: warm at sunrise and
## sunset, plain at midday, deep blue at night.


## 0 = full day, 1 = full night.
static func night_amount(tuning: Tuning, season_name: String, minute: int) -> float:
	var sun: Array = tuning.value("light.sun." + season_name)
	var rise := float(sun[0])
	var set_m := float(sun[1])
	var half := tuning.num("light.twilight_minutes") / 2.0
	var m := float(minute % 1440)
	# Treat after-midnight minutes as night.
	if minute >= 1440:
		return 1.0
	if m <= rise - half or m >= set_m + half:
		return 1.0
	if m >= rise + half and m <= set_m - half:
		return 0.0
	if m < rise + half:
		return 1.0 - (m - (rise - half)) / (2.0 * half)
	return (m - (set_m - half)) / (2.0 * half)


static func is_night(tuning: Tuning, season_name: String, minute: int) -> bool:
	return night_amount(tuning, season_name, minute) >= 0.5


static func _c(arr: Variant) -> Color:
	var a: Array = arr
	return Color(float(a[0]), float(a[1]), float(a[2]))


## Screen tint for the time of day alone.
static func tint(tuning: Tuning, season_name: String, minute: int) -> Color:
	var n := night_amount(tuning, season_name, minute)
	var day_c := _c(tuning.value("light.day_tint"))
	var dusk_c := _c(tuning.value("light.twilight_tint"))
	var night_c := _c(tuning.value("light.night_tint"))
	if n <= 0.0:
		return day_c
	if n >= 1.0:
		return night_c
	# Warm in the middle of the twilight, blending day -> warm -> night.
	if n < 0.5:
		return day_c.lerp(dusk_c, n * 2.0)
	return dusk_c.lerp(night_c, (n - 0.5) * 2.0)
