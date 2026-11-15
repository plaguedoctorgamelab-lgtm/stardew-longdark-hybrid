class_name TestCase
extends RefCounted
## Collects the results of one test.

var name: String
var failures: Array[String] = []


func _init(test_name: String) -> void:
	name = test_name


func check(condition: bool, what: String) -> bool:
	if not condition:
		failures.append(what)
	return condition


func equal(actual: Variant, expected: Variant, what: String) -> bool:
	if typeof(actual) in [TYPE_FLOAT, TYPE_INT] and typeof(expected) in [TYPE_FLOAT, TYPE_INT]:
		if absf(float(actual) - float(expected)) > 0.0001:
			failures.append("%s: expected %s, got %s" % [what, expected, actual])
			return false
		return true
	if actual != expected:
		failures.append("%s: expected %s, got %s" % [what, expected, actual])
		return false
	return true


func near(actual: float, expected: float, tolerance: float, what: String) -> bool:
	if absf(actual - expected) > tolerance:
		failures.append("%s: expected %.3f within %.3f, got %.3f" % [what, expected, tolerance, actual])
		return false
	return true


## A fresh game with a fixed seed, saving to a test folder.
static func new_session(seed_value: int = 12345) -> GameSession:
	var s := GameSession.new()
	s.save_path = "user://test_saves/slot_test.json"
	s.new_game(seed_value)
	return s
