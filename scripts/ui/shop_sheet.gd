class_name ShopSheet
extends Sheet
## A shop on the clipboard (the cozy UI plan, 0.7.19): the shop's sign on
## the clip, Buy and Sell tabs, the goods as cards with their price, and
## the chosen one in full: its picture, what it does as chips, the price,
## and stamps to buy it (to eat here or take away, at the cafés). Sell lists
## what's in the pack that the shop would buy, and what it pays. Talking to
## the keeper, the catalog and Gus's upgrades are stamps too, and hand on
## to what they did before.

signal handed_on(kind: String)   # "close" or a list kind (catalog, home) to show instead

const CLIPS := {"percolator": "clip_percolator", "casa_luna": "clip_casa_luna", "outfitters": "clip_outfitters", "gifts": "clip_gifts", "carpentry": "clip_carpentry", "library": "clip_library"}

var place: String = ""
var tab: String = "buy"
var selected: String = ""
var _title: Label


func setup(s: GameSession) -> void:
	setup_sheet(s)
	_title = Label.new()
	_title.position = PAPER.position + Vector2(90, 0)
	_title.add_theme_font_size_override("font_size", 8)
	_title.add_theme_color_override("font_color", KitStyle.TEXT_DARK)
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title)


func open(at: String) -> void:
	place = at
	var r := session.shops.shop(place)
	tab = "buy" if not (r.get("sells", []) as Array).is_empty() else "sell"
	selected = ""
	set_clip([CLIPS.get(place, ""), "clip_make"])
	visible = true
	refresh()


func _keeper_here() -> bool:
	return session.shops.people_in(place).has(session.shops.keeper(place))


## The goods on sale now: [{item, price, count, here, late}].
func goods() -> Array:
	var out := []
	var r := session.shops.shop(place)
	var minute := session.clock.minute
	for it: Dictionary in r.get("sells", []):
		if it.has("season") and str(it["season"]) != session.clock.season_name():
			continue
		out.append({"item": str(it["item"]), "price": int(it["price"]), "count": int(it.get("count", 1)), "here": bool(it.get("here", false)), "late": it.has("before") and minute >= int(it["before"]), "away": int(it["price"]) + int(r.get("takeaway_extra", 0))})
	return out


## What the pack holds that the shop would buy: [{item, n, price}].
func sellable() -> Array:
	var out := []
	var seen := {}
	var bp := session.backpack
	for i in bp.slots.size():
		var item := bp.item_at(i)
		if item == "" or seen.has(item):
			continue
		seen[item] = true
		var p := session.shops.sell_price(place, item)
		if p > 0:
			out.append({"item": item, "n": bp.count(item), "price": p})
	return out


func _icon(item: String) -> String:
	if not session.content.has("items", item):
		return ""
	var ic := str(session.content.row("items", item).get("icon", ""))
	return ic if Art.has_picture(ic) else ""


func refresh() -> void:
	if not visible:
		return
	var c := session.content
	var r := session.shops.shop(place)
	var tabs := []
	if not (r.get("sells", []) as Array).is_empty():
		tabs.append({"id": "buy", "label": c.text("shop_tab_buy"), "icon": pick(["verb_buy", "icon_coin"])})
	if r.has("buys"):
		tabs.append({"id": "sell", "label": c.text("shop_tab_sell"), "icon": pick(["icon_coins_up", "icon_coin"])})
	set_index_tabs(tabs, tab, func(t: String) -> void:
		tab = t
		selected = ""
		refresh())
	_title.text = str(session.content.row("town_places", place)["name"]) if session.content.has("town_places", place) else place.capitalize()
	_title.position = PAPER.position + Vector2(tabs.size() * 42 + 6, 1)
	clear(list)
	clear(detail)
	clear(stamps)
	if tab == "buy":
		_buy()
	else:
		_sell()
	_extras()
	set_keys([[["Q", "E"], c.text("shop_key_tabs")], [["W", "S"], c.text("key_list")], [["X"], c.text("shop_key_buy" if tab == "buy" else "shop_key_sell")], [["Esc"], c.text("shop_key_leave")]])


func _choose(item: String) -> void:
	if item == selected:
		return
	selected = item
	refresh()


func _price_chip(n: int, wallet_ok: bool) -> Control:
	return Sheet.chip(pick(["icon_coin"]), str(n), "" if wallet_ok else "bad")


func _buy() -> void:
	var c := session.content
	var wallet := session.park.money.wallet
	var gs := goods()
	empty_label.visible = gs.is_empty()
	empty_label.text = c.text("shop_none_today")
	if gs.is_empty():
		return
	if selected == "" or not gs.any(func(g: Dictionary) -> bool: return str(g["item"]) == selected):
		selected = str(gs[0]["item"])
	var chosen := {}
	for g: Dictionary in gs:
		var item := str(g["item"])
		var name := c.item_name(item) + (" ×%d" % int(g["count"]) if int(g["count"]) > 1 else "")
		var ok := int(g["price"]) <= wallet and not bool(g["late"])
		var cd := card(_icon(item), name, _price_chip(int(g["price"]), int(g["price"]) <= wallet), item == selected, func() -> void: _choose(item), not ok)
		if bool(g["late"]) and Art.has_picture("shop_sold_out"):
			cd.add_child(Sheet._pic("shop_sold_out", Vector2(LIST_W - 38, 2), Vector2(22, 22)))
		list.add_child(cd)
		if item == selected:
			chosen = g
	var item := str(chosen["item"])
	var chips: Array[Control] = []
	chips.append(_price_chip(int(chosen["price"]), int(chosen["price"]) <= wallet))
	for ch in InventoryScreen.item_chips(session, item, false):
		chips.append(ch)
	detail.add_child(header(_icon(item), c.item_name(item) + (" ×%d" % int(chosen["count"]) if int(chosen["count"]) > 1 else ""), chips))
	for key: String in ["item_desc_" + item, "item_use_" + item]:
		if c.has("text", key):
			detail.add_child(voice(c.text(key)))
			break
	if bool(chosen["late"]):
		detail.add_child(Sheet.chip(pick(["icon_time"]), c.text("shop_sold_out_today"), "bad"))
	detail.add_child(Sheet.chip(pick(["icon_coin"]), c.text("shop_you_have", {"n": wallet})))
	var late := bool(chosen["late"])
	if bool(chosen["here"]):
		add_stamp(pick(["verb_cook", "verb_buy"]), c.text("shop_eat_here", {"n": int(chosen["price"])}), "X", not late and int(chosen["price"]) <= wallet, func() -> void: _do_buy("here", item))
		add_stamp(pick(["verb_buy"]), c.text("shop_take_away", {"n": int(chosen["away"])}), "", not late and int(chosen["away"]) <= wallet, func() -> void: _do_buy("away", item))
	else:
		add_stamp(pick(["verb_buy"]), c.text("shop_buy_for", {"n": int(chosen["price"])}), "X", int(chosen["price"]) <= wallet, func() -> void: _do_buy("buy", item))


func _do_buy(kind: String, item: String) -> void:
	session.shops.buy(place, kind, item)
	refresh()


func _sell() -> void:
	var c := session.content
	var here := _keeper_here()
	var ss := sellable()
	empty_label.visible = ss.is_empty()
	empty_label.text = c.text("shop_sell_none", {"name": session.shops.first_name(session.shops.keeper(place))})
	if ss.is_empty():
		return
	if selected == "" or not ss.any(func(g: Dictionary) -> bool: return str(g["item"]) == selected):
		selected = str(ss[0]["item"])
	var chosen := {}
	for g: Dictionary in ss:
		var item := str(g["item"])
		list.add_child(card(_icon(item), "%s ×%d" % [c.item_name(item), int(g["n"])], _price_chip(int(g["price"]), true), item == selected, func() -> void: _choose(item)))
		if item == selected:
			chosen = g
	var item := str(chosen["item"])
	var chips: Array[Control] = [Sheet.chip(pick(["icon_coins_up", "icon_coin"]), c.text("shop_pays", {"n": int(chosen["price"])}), "good")]
	chips.append(Sheet.chip(pick(["icon_carry"]), c.text("shop_in_pack", {"n": int(chosen["n"])})))
	detail.add_child(header(_icon(item), c.item_name(item), chips))
	if not here:
		detail.add_child(Sheet.chip(pick(["icon_time"]), c.text("shop_keeper_out", {"name": session.shops.first_name(session.shops.keeper(place))}), "bad"))
	add_stamp(pick(["icon_coins_up", "icon_coin"]), c.text("shop_sell_one", {"n": int(chosen["price"])}), "X", here, func() -> void: _do_sell(item, 1))
	if int(chosen["n"]) > 1:
		add_stamp(pick(["icon_coins_up", "icon_coin"]), c.text("shop_sell_all", {"n": int(chosen["n"]) * int(chosen["price"])}), "", here, func() -> void: _do_sell(item, int(chosen["n"])))


func _do_sell(item: String, n: int) -> void:
	for i in n:
		if session.shops.sell(place, item) != "":
			break
	refresh()


## Talk, the catalog and Gus's upgrades: stamps that hand on.
func _extras() -> void:
	var c := session.content
	for o: Dictionary in session.shops.menu_options(place):
		var id := str(o["id"])
		if id in ["buy", "sell"]:
			continue
		var icon: String = {"talk": "verb_talk", "catalog": "verb_read", "home": "station_workbench"}.get(id, "")
		var label := c.text({"talk": "shop_stamp_talk", "catalog": "shop_stamp_catalog", "home": "shop_stamp_home"}.get(id, "shop_back"))
		add_stamp(pick([icon]), label, "", bool(o.get("enabled", true)), func() -> void: _hand_on(id))


func _hand_on(option: String) -> void:
	var nxt := session.answer_list("shop:" + place, option)
	close()
	handed_on.emit(nxt)


## Keys while the shop is open. True when the key was used.
func handle(event: InputEvent) -> bool:
	if event.is_action_pressed("cancel") or event.is_action_pressed("pause") or event.is_action_pressed("backpack"):
		close()
		return true
	if event.is_action_pressed("tab_prev") or event.is_action_pressed("tab_next"):
		var r := session.shops.shop(place)
		if tab == "buy" and r.has("buys"):
			tab = "sell"
		elif tab == "sell" and not (r.get("sells", []) as Array).is_empty():
			tab = "buy"
		selected = ""
		refresh()
		return true
	if event.is_action_pressed("move_up") or event.is_action_pressed("move_down"):
		var ids: Array = (goods() if tab == "buy" else sellable()).map(func(g: Dictionary) -> String: return str(g["item"]))
		if ids.is_empty():
			return true
		var i := ids.find(selected)
		i = clampi(i + (1 if event.is_action_pressed("move_down") else -1), 0, ids.size() - 1)
		selected = str(ids[i])
		refresh()
		return true
	if event.is_action_pressed("interact") or event.is_action_pressed("confirm"):
		if tab == "buy":
			for g: Dictionary in goods():
				if str(g["item"]) == selected:
					_do_buy("here" if bool(g["here"]) else "buy", selected)
		elif _keeper_here():
			_do_sell(selected, 1)
		return true
	return false
