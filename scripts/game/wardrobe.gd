class_name Wardrobe
extends RefCounted
## What the ranger wears (Phase 4, 4a step 6): a hat, a coat and boots. Each
## piece is a row of the `clothing` table: its slot, the warmth it adds every
## ten minutes outdoors, an effect if it has one, and the overlay drawn over
## the ranger. The starting three add up to the old single clothing value,
## so nothing changes until new clothes are bought.

const SLOTS: Array[String] = ["hat", "coat", "boots"]

var content: ContentDB
var worn: Dictionary = {}   # slot -> clothing id


func _init(c: ContentDB) -> void:
	content = c
	new_game()


func new_game() -> void:
	worn = {}
	for r: Dictionary in content.rows("clothing"):
		if bool(r.get("start", false)):
			worn[str(r["slot"])] = str(r["id"])


func is_clothing(item: String) -> bool:
	return content.has("clothing", item)


func row(id: String) -> Dictionary:
	return content.row("clothing", id)


## Warmth every ten minutes outdoors from everything worn.
func warmth() -> float:
	var w := 0.0
	for slot: String in worn:
		w += float(row(worn[slot]).get("warmth", 0))
	return w


## True when something worn has this effect: "rain_half" (rain and storms
## take half as much warmth), "slow" (walk a little slower), "wade" (no
## slowdown in shallows and bog).
func has_effect(effect: String) -> bool:
	for slot: String in worn:
		if str(row(worn[slot]).get("effect", "")) == effect:
			return true
	return false


## How much walking speed is kept: the down parka's 5% slower.
func speed_factor() -> float:
	var f := 1.0
	for slot: String in worn:
		f *= float(row(worn[slot]).get("speed", 1.0))
	return f


## Puts a piece on. Returns the piece taken off ("" if none).
func put_on(id: String) -> String:
	var slot := str(row(id)["slot"])
	var off := str(worn.get(slot, ""))
	worn[slot] = id
	return off


## The ranger's picture: without the hat when another hat is worn, and an
## overlay for every piece that isn't the starting one, hat last.
func base_sheet() -> String:
	var hat := str(worn.get("hat", ""))
	return "ranger_nohat" if hat != "" and not bool(row(hat).get("start", false)) else "ranger"


func overlays() -> Array[String]:
	var out: Array[String] = []
	for slot: String in ["boots", "coat", "hat"]:
		var id := str(worn.get(slot, ""))
		if id != "" and str(row(id).get("overlay", "")) != "":
			out.append(str(row(id)["overlay"]))
	return out


func to_dict() -> Dictionary:
	return {"worn": worn.duplicate()}


func from_dict(d: Dictionary) -> void:
	new_game()
	for slot: String in (d.get("worn", {}) as Dictionary):
		var id := str(d["worn"][slot])
		if is_clothing(id) and str(row(id)["slot"]) == slot:
			worn[slot] = id
