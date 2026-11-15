class_name Inventory
extends RefCounted
## A fixed number of slots holding stacks of items. Like items stack up to
## the item's stack size. Used for the backpack, chests and the shelf.

signal changed

var content: ContentDB
var slots: Array = []   # each slot is {} (empty) or {"item": id, "count": n}


func _init(c: ContentDB, slot_count: int) -> void:
	content = c
	for i in slot_count:
		slots.append({})


func size() -> int:
	return slots.size()


func stack_size(item_id: String) -> int:
	return int(content.row("items", item_id).get("stack", 1))


func count(item_id: String) -> int:
	var n := 0
	for s: Dictionary in slots:
		if s.get("item", "") == item_id:
			n += int(s["count"])
	return n


func has(item_id: String, n: int = 1) -> bool:
	return count(item_id) >= n


func has_all(materials: Dictionary) -> bool:
	for k: String in materials:
		if count(k) < int(materials[k]):
			return false
	return true


## How many of n would fit.
func room_for(item_id: String) -> int:
	var cap := stack_size(item_id)
	var room := 0
	for s: Dictionary in slots:
		if s.is_empty():
			room += cap
		elif s["item"] == item_id:
			room += cap - int(s["count"])
	return room


## Adds up to n items. Returns how many did not fit.
func add(item_id: String, n: int = 1) -> int:
	var cap := stack_size(item_id)
	var left := n
	for s: Dictionary in slots:
		if left <= 0:
			break
		if not s.is_empty() and s["item"] == item_id and int(s["count"]) < cap:
			var put := mini(left, cap - int(s["count"]))
			s["count"] = int(s["count"]) + put
			left -= put
	for i in slots.size():
		if left <= 0:
			break
		if (slots[i] as Dictionary).is_empty():
			var put := mini(left, cap)
			slots[i] = {"item": item_id, "count": put}
			left -= put
	changed.emit()
	return left


## Removes n items if there are enough. Returns true on success.
func remove(item_id: String, n: int = 1) -> bool:
	if count(item_id) < n:
		return false
	var left := n
	for i in range(slots.size() - 1, -1, -1):
		var s: Dictionary = slots[i]
		if left <= 0:
			break
		if not s.is_empty() and s["item"] == item_id:
			var take := mini(left, int(s["count"]))
			s["count"] = int(s["count"]) - take
			left -= take
			if int(s["count"]) <= 0:
				slots[i] = {}
	changed.emit()
	return true


## The kits in the backpack that can stand in for loose materials, and how
## many of them would be used to pay for these materials: {item: count}, or
## null when the materials cannot be paid for.
func _kits_needed(materials: Dictionary) -> Variant:
	var short := {}
	for k: String in materials:
		var gap := int(materials[k]) - count(k)
		if gap > 0:
			short[k] = gap
	var use := {}
	if short.is_empty():
		return use
	for r: Dictionary in content.rows("items"):
		if not r.has("covers") or count(r["id"]) == 0:
			continue
		var covers: Dictionary = r["covers"]
		var n := 0
		for k: String in short:
			if covers.has(k):
				n = maxi(n, ceili(float(short[k]) / float(covers[k])))
		n = mini(n, count(r["id"]))
		if n == 0:
			continue
		use[r["id"]] = n
		for k: String in short.keys():
			if covers.has(k):
				short[k] = int(short[k]) - n * int(covers[k])
				if int(short[k]) <= 0:
					short.erase(k)
	if not short.is_empty():
		return null
	return use


## Whether the materials can be paid for, counting repair kits.
func can_pay(materials: Dictionary) -> bool:
	return _kits_needed(materials) != null


## Pays for the materials: loose items first, kits for any shortfall.
func pay(materials: Dictionary) -> bool:
	var kits: Variant = _kits_needed(materials)
	if kits == null:
		return false
	for k: String in materials:
		remove(k, mini(count(k), int(materials[k])))
	for kit: String in kits:
		remove(kit, int(kits[kit]))
	return true


func remove_all(materials: Dictionary) -> bool:
	if not has_all(materials):
		return false
	for k: String in materials:
		remove(k, int(materials[k]))
	return true


func slot(i: int) -> Dictionary:
	return slots[i]


func item_at(i: int) -> String:
	if i < 0 or i >= slots.size():
		return ""
	return (slots[i] as Dictionary).get("item", "")


func clear() -> void:
	for i in slots.size():
		slots[i] = {}
	changed.emit()


## Moves slot i of this inventory into another, as far as it fits.
func move_slot_to(i: int, other: Inventory) -> void:
	var s: Dictionary = slots[i]
	if s.is_empty():
		return
	var id: String = s["item"]
	var n: int = s["count"]
	var left := other.add(id, n)
	var moved := n - left
	if moved > 0:
		s["count"] = n - moved
		if int(s["count"]) <= 0:
			slots[i] = {}
		changed.emit()


func swap(a: int, b: int) -> void:
	var t: Dictionary = slots[a]
	slots[a] = slots[b]
	slots[b] = t
	changed.emit()


func to_array() -> Array:
	var out := []
	for s: Dictionary in slots:
		out.append(s.duplicate())
	return out


func from_array(arr: Array) -> void:
	for i in slots.size():
		slots[i] = (arr[i] as Dictionary).duplicate() if i < arr.size() else {}
		if not (slots[i] as Dictionary).is_empty():
			slots[i]["count"] = int(slots[i]["count"])
	changed.emit()
