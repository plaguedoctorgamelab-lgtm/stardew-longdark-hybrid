class_name Inventory
extends RefCounted
## A fixed number of slots holding stacks of items. Like items stack up to
## the item's stack size. Used for the backpack, chests and the shelf.

signal changed

var content: ContentDB
var slots: Array = []   # each slot is {} (empty) or {"item": id, "count": n}
## When set, only these items may be put in (the gift shelf). Empty: anything.
var only: Dictionary = {}


func _init(c: ContentDB, slot_count: int) -> void:
	content = c
	for i in slot_count:
		slots.append({})


func size() -> int:
	return slots.size()


## Grows (or shrinks) to n slots, keeping every stack in its slot.
func resize(n: int) -> void:
	while slots.size() < n:
		slots.append({})
	while slots.size() > n and (slots[slots.size() - 1] as Dictionary).is_empty():
		slots.pop_back()
	changed.emit()


## The first slot holding an item of this family (the item itself, or a
## refitted version of it), or -1.
func find_family(family: String) -> int:
	for i in slots.size():
		var s: Dictionary = slots[i]
		if not s.is_empty() and str(content.row("items", s["item"]).get("family", s["item"])) == family:
			return i
	return -1


## Puts another item in slot i in place of what is there (a refit).
func replace_at(i: int, item_id: String) -> void:
	slots[i] = {"item": item_id, "count": 1}
	changed.emit()


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
	if not only.is_empty() and not only.has(item_id):
		return 0
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
	if not only.is_empty() and not only.has(item_id):
		return n
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


## Whether this inventory may hold the item at all (the gift shelf only
## takes some).
func accepts(item_id: String) -> bool:
	return only.is_empty() or only.has(item_id)


## Drags slot i of this inventory onto slot j of another (or the same): onto
## an empty slot it moves, onto the same item it tops that stack up, onto a
## different item the two swap places. Returns true if anything moved.
func move_to_slot(i: int, other: Inventory, j: int) -> bool:
	if other == self and i == j:
		return false
	var a: Dictionary = slots[i]
	if a.is_empty() or not other.accepts(a["item"]):
		return false
	var b: Dictionary = other.slots[j]
	if b.is_empty():
		other.slots[j] = a
		slots[i] = {}
	elif b["item"] == a["item"]:
		var put := mini(int(a["count"]), stack_size(a["item"]) - int(b["count"]))
		if put <= 0:
			return false
		b["count"] = int(b["count"]) + put
		a["count"] = int(a["count"]) - put
		if int(a["count"]) <= 0:
			slots[i] = {}
	else:
		if not accepts(b["item"]):
			return false
		other.slots[j] = a
		slots[i] = b
	changed.emit()
	if other != self:
		other.changed.emit()
	return true


## Takes the whole stack out of slot i: {item, count}, or {} if empty.
func take_slot(i: int) -> Dictionary:
	var s: Dictionary = slots[i]
	slots[i] = {}
	if not s.is_empty():
		changed.emit()
	return s


func is_empty() -> bool:
	for s: Dictionary in slots:
		if not s.is_empty():
			return false
	return true


## Tidies the slots from `first` on (the item bar before it is left alone):
## like stacks merged, then tools, food, materials and the rest in order,
## each by name.
func sort_from(first: int) -> void:
	var counts := {}
	var order: Array[String] = []
	for i in range(first, slots.size()):
		var s: Dictionary = slots[i]
		if s.is_empty():
			continue
		var id := str(s["item"])
		if not counts.has(id):
			order.append(id)
		counts[id] = int(counts.get(id, 0)) + int(s["count"])
		slots[i] = {}
	const KINDS := ["tool", "food", "fuel", "material", "kit", "clothing", "placeable", "park_thing", "gift", "favor", "page", "keepsake", "find", "magic"]
	order.sort_custom(func(a: String, b: String) -> bool:
		var ka := KINDS.find(str(content.row("items", a).get("kind", "")))
		var kb := KINDS.find(str(content.row("items", b).get("kind", "")))
		ka = 99 if ka < 0 else ka
		kb = 99 if kb < 0 else kb
		return ka < kb if ka != kb else content.item_name(a) < content.item_name(b))
	var i := first
	for id: String in order:
		var left: int = counts[id]
		while left > 0 and i < slots.size():
			var n := mini(left, stack_size(id))
			slots[i] = {"item": id, "count": n}
			left -= n
			i += 1
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
	if arr.size() > slots.size():
		resize(arr.size())
	for i in slots.size():
		slots[i] = (arr[i] as Dictionary).duplicate() if i < arr.size() else {}
		if not (slots[i] as Dictionary).is_empty():
			slots[i]["count"] = int(slots[i]["count"])
	changed.emit()
