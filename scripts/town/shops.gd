class_name Shops
extends RefCounted
## Humdrum's shops (Phase 4 Spec, 4a step 5): the rooms inside them, who is
## in each, the counter's menu, buying and selling, the coffee's speed boost
## and the library's books. What each shop sells and buys is content data
## (shops, town_interiors, books); the numbers are in tuning "shops".
##
## The ranger walks into a shop through its door during its hours. Inside,
## X at the counter opens the shop's menu (talk to the keeper, buy, sell,
## or the post office's catalog); X at a bookshelf lists the books. At
## closing time the keeper sees the ranger out.

var _s: WeakRef
var content: ContentDB
var tuning: Tuning
var rooms: Dictionary = {}        # place id -> InteriorLayout
var boost_until: int = -1         # absolute minute the coffee wears off
var books_read: Dictionary = {}   # book id -> true
var rng := RandomNumberGenerator.new()


func _init(session: GameSession) -> void:
	_s = weakref(session)
	content = session.content
	tuning = session.tuning
	for r: Dictionary in content.rows("town_interiors"):
		rooms[str(r["id"])] = InteriorLayout.new(r)


func session() -> GameSession:
	return _s.get_ref()


func has_room(place: String) -> bool:
	return rooms.has(place)


func inside_row(place: String) -> Dictionary:
	return content.row("town_interiors", place)["interior"]


func shop(place: String) -> Dictionary:
	return content.row("shops", place) if content.has("shops", place) else {}


func keeper(place: String) -> String:
	return str(content.row("town_places", place).get("keeper", ""))


func first_name(person: String) -> String:
	return str(content.row("townsfolk", person)["name"]).get_slice(" ", 0) if person != "lyle" else str(content.row("townsfolk", person)["name"])


# --- who is in a room ---------------------------------------------------------

## Everyone in a room now, {person: tile position (centre)}: the keeper
## behind the counter while the shop is open, and anyone else whose routine
## has them here, at the room's guest spots in turn.
func people_in(place: String) -> Dictionary:
	var out := {}
	if not rooms.has(place):
		return out
	var town := session().town
	var inside := inside_row(place)
	var k := keeper(place)
	var guests: Array = inside.get("guest_spots", [])
	var gi := 0
	var ids := town.people.keys()
	ids.sort()
	for id: String in ids:
		var p: Dictionary = town.people[id]
		if str(p["goal"]) != place or not (p["path"] as Array).is_empty():
			continue
		if id == k:
			if town.is_open(place):
				var ka: Array = inside["keeper_at"]
				out[id] = Vector2(float(ka[0]) + 0.5, float(ka[1]) + 0.5)
		elif gi < guests.size():
			out[id] = Vector2(float(guests[gi][0]) + 0.5, float(guests[gi][1]) + 0.5)
			gi += 1
	return out


## The person within reach in the room, or "".
func person_near(place: String, pos: Vector2, reach: float) -> String:
	var best := ""
	var best_d := reach
	var here := people_in(place)
	for id: String in here:
		var d := (here[id] as Vector2).distance_to(pos)
		if d <= best_d:
			best_d = d
			best = id
	return best


# --- the counter's menu -------------------------------------------------------

## The menu at a shop's counter: [{id, label, enabled}].
func menu_options(place: String) -> Array:
	var out := []
	var k := keeper(place)
	var r := shop(place)
	var here := people_in(place).has(k)
	if here:
		out.append({"id": "talk", "label": content.text("shop_talk", {"name": first_name(k)})})
	# With the keeper out (Wren walks to the creek at 15:00), the honour jar
	# on the counter still takes money for what's on sale.
	if not (r.get("sells", []) as Array).is_empty():
		out.append({"id": "buy", "label": content.text("shop_buy")})
	if r.has("buys"):
		out.append({"id": "sell", "label": content.text("shop_sell"), "enabled": here})
	if bool(r.get("catalog", false)):
		out.append({"id": "catalog", "label": content.text("shop_catalog"), "enabled": here})
	return out


func _effect_text(food: String) -> String:
	var f := content.row("foods", food)
	var parts := PackedStringArray()
	if int(f.get("energy", 0)) > 0:
		parts.append(content.text("fx_energy", {"n": int(f["energy"])}))
	if int(f.get("warmth", 0)) > 0:
		parts.append(content.text("fx_warmth", {"n": int(f["warmth"])}))
	if str(f.get("boost", "")) == "coffee":
		parts.append(content.text("fx_speed", {"hours": tuning.integer("shops.coffee_minutes") / 60}))
	return ", ".join(parts)


## What a shop sells: [{id, label, enabled}]. A dish eaten here or taken
## away is two lines.
func buy_options(place: String) -> Array:
	var out := []
	var r := shop(place)
	var wallet := session().park.money.wallet
	var minute := session().clock.minute
	for it: Dictionary in r.get("sells", []):
		var item := str(it["item"])
		var name := content.item_name(item)
		var count := int(it.get("count", 1))
		if count > 1:
			name = "%s ×%d" % [name, count]
		var price := int(it["price"])
		var what := _effect_text(item) if content.has("foods", item) else ""
		var late := it.has("before") and minute >= int(it["before"])
		if late:
			what = content.text("fx_before", {"time": GameClock.time_of(int(it["before"]))})
		if bool(it.get("here", false)):
			out.append({"id": "here:" + item, "label": content.text("shop_buy_here", {"name": name, "what": what, "price": price}), "enabled": price <= wallet and not late})
			var away := price + int(r.get("takeaway_extra", 0))
			out.append({"id": "away:" + item, "label": content.text("shop_buy_away", {"name": name, "price": away}), "enabled": away <= wallet and not late})
		else:
			out.append({"id": "buy:" + item, "label": content.text("shop_buy_line", {"name": name, "what": content.text("item_use_" + item) if content.has("text", "item_use_" + item) else "", "price": price}).replace("  ·    ·  ", "  ·  "), "enabled": price <= wallet})
	out.append({"id": "back", "label": content.text("shop_back")})
	return out


## What a shop would pay for one of an item, or 0 if it doesn't buy it.
func sell_price(place: String, item: String) -> int:
	var r := shop(place)
	if not r.has("buys"):
		return 0
	var share := tuning.num("shops.buy_share")
	var prices: Dictionary = r["buys"].get("prices", {})
	if prices.has(item):
		return maxi(1, roundi(float(prices[item]) * share))
	var row := content.row("items", item) if content.has("items", item) else {}
	if row.has("sell"):
		return maxi(1, roundi(float(row["sell"]) * share))
	return 0


func sell_options(place: String) -> Array:
	var out := []
	var bp := session().backpack
	var seen := {}
	for slot: int in bp.slots.size():
		var item := bp.item_at(slot)
		if item == "" or seen.has(item):
			continue
		seen[item] = true
		var p := sell_price(place, item)
		if p > 0:
			out.append({"id": "sell:" + item, "label": content.text("shop_sell_line", {"name": content.item_name(item), "n": bp.count(item), "price": p})})
	if out.is_empty():
		out.append({"id": "back", "label": content.text("shop_sell_none", {"name": first_name(keeper(place))})})
	else:
		out.append({"id": "back", "label": content.text("shop_back")})
	return out


## Buys one line. kind is "here", "away" or "buy". Returns "" or the text
## id of why not; the message for the ranger is emitted here.
func buy(place: String, kind: String, item: String) -> String:
	var s := session()
	var r := shop(place)
	var it := {}
	for x: Dictionary in r.get("sells", []):
		if str(x["item"]) == item:
			it = x
	if it.is_empty():
		return "shop_away"
	if it.has("before") and s.clock.minute >= int(it["before"]):
		s.message.emit(content.text("shop_too_late", {"item": content.item_name(item), "time": GameClock.time_of(int(it["before"]))}))
		return "shop_too_late"
	var price := int(it["price"])
	if kind == "away":
		price += int(r.get("takeaway_extra", 0))
	if not s.park.money.can_afford(price):
		s.message.emit(content.text("shop_cant_afford"))
		return "shop_cant_afford"
	var count := int(it.get("count", 1))
	if kind != "here" and s.backpack.room_for(item) < count:
		s.message.emit(content.text("shop_no_room"))
		return "shop_no_room"
	s.park.money.spend(s.clock.absolute_day(), "shops", price)
	if kind == "here":
		var food := content.row("foods", item)
		s.needs.eat(food)
		if str(food.get("boost", "")) == "coffee":
			start_boost()
		var line := content.text("shop_ate_here", {"item": content.item_name(item).to_lower(), "effect": _effect_text(item)})
		if item == "muffin":
			line += " " + content.text("shop_muffin_" + s.clock.season_name())
		s.message.emit(line)
		var fp: Dictionary = r.get("free_plate", {})
		if str(fp.get("item", "")) == item and rng.randf() < float(fp["chance"]):
			s.needs.eat(food)
			s.message.emit(content.text("shop_free_plate"))
		s.pass_minutes(int(r.get("here_minutes", 0)))
	else:
		s.backpack.add(item, count)
		s.message.emit(content.text("shop_bought", {"item": content.item_name(item).to_lower(), "price": price}))
	return ""


## Sells one of an item. Returns "" or why not.
func sell(place: String, item: String) -> String:
	var s := session()
	var p := sell_price(place, item)
	if not people_in(place).has(keeper(place)):
		return "shop_away"
	if p <= 0 or not s.backpack.remove(item, 1):
		return "shop_sell_none"
	s.park.money.earn(s.clock.absolute_day(), "shop_sales", p)
	s.message.emit(content.text("shop_sold", {"item": content.item_name(item).to_lower(), "price": p}))
	return ""


# --- coffee -------------------------------------------------------------------

func now() -> int:
	return session().clock.absolute_day() * 1440 + session().clock.minute


func start_boost() -> void:
	boost_until = now() + tuning.integer("shops.coffee_minutes")
	session().message.emit(content.text("shop_coffee_on"))


## The extra share of walking speed from coffee now (0 when none).
func speed_boost() -> float:
	return tuning.num("shops.coffee_boost") if boost_until > now() else 0.0


## Each frame: the coffee wearing off.
func process() -> void:
	if boost_until >= 0 and boost_until <= now():
		boost_until = -1
		session().message.emit(content.text("shop_coffee_off"))


# --- the library ----------------------------------------------------------------

func book_options() -> Array:
	var out := []
	for b: Dictionary in content.rows("books"):
		out.append({"id": str(b["id"]), "label": content.text("book_line_read" if books_read.has(b["id"]) else "book_line", {"title": b["title"]})})
	return out


## Reads a book: its pages, and a recipe the first time if it teaches one.
func read_book(id: String) -> String:
	if not content.has("books", id):
		return ""
	var b := content.row("books", id)
	var first := not books_read.has(id)
	books_read[id] = true
	var text := str(b["title"]) + "\n\n" + "\n\n".join(PackedStringArray(b["pages"]))
	if first and str(b.get("teaches", "")) != "" and session().learn_recipe(str(b["teaches"])):
		text += "\n\n" + content.text("book_teaches", {"name": content.text(str(content.row("recipes", b["teaches"])["name"]))})
	return text


# --- saving -------------------------------------------------------------------

func to_dict() -> Dictionary:
	return {"boost_until": boost_until, "books_read": books_read.keys()}


func from_dict(d: Dictionary) -> void:
	boost_until = int(d.get("boost_until", -1))
	books_read = {}
	for id: Variant in d.get("books_read", []):
		books_read[str(id)] = true


func new_game() -> void:
	boost_until = -1
	books_read = {}
