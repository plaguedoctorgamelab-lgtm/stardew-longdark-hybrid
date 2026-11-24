class_name MakeSheet
extends Sheet
## The Make sheet (the cozy UI plan, 0.7.15): crafting, the workbench and
## cooking, on the clipboard. Recipe cards on the left under a ribbon for
## each kind (trail and park, workshop, food, gifts, refits), each with a
## dot that says whether it can be made here and now. The chosen recipe on
## the right: its picture, where it's made, what it needs as tiles with
## have/need badges (red when short), what it makes, what it does, and the
## Make stamps. At a fire it also feeds the fire; at a workbench it opens the
## bench's box.

const TABS: Array[String] = ["all", "anywhere", "workbench", "fire"]
const GROUPS: Array[String] = ["park", "workshop", "food", "gifts", "refits"]
const GROUP_COLORS := {"park": Color8(56, 120, 70), "workshop": Color8(157, 102, 62), "food": Color8(196, 96, 60), "gifts": Color8(160, 90, 150), "refits": Color8(70, 100, 160)}
const GROUP_PICTURES := {"park": ["kind_building", "item_trail_sign"], "workshop": ["kind_tools", "item_planks"], "food": ["kind_food", "item_hot_soup"], "gifts": ["kind_decor", "item_painted_stone"], "refits": ["kind_refits", "item_lantern"]}
const STATION_PICTURES := {"all": ["ui_patch_make", "item_hammer"], "anywhere": ["station_hands", "item_backpack"], "workbench": ["station_workbench", "furniture_workbench", "item_workbench_kit"], "fire": ["station_campfire", "obj_campfire", "item_firewood"]}
const MAKE_MANY := 5

var station: String = "anywhere"   # where the sheet was opened: anywhere (the menu), workbench or fire
var tab: String = "all"
var selected: String = ""
var _cards: Dictionary = {}


func setup(s: GameSession) -> void:
	setup_sheet(s)
	set_clip(["clip_make"])


## Opens at the menu ("anywhere"), a workbench or a fire.
func open(at: String = "anywhere") -> void:
	station = at
	tab = "all" if at == "anywhere" else at
	selected = ""
	visible = true
	refresh()


func set_tab(t: String) -> void:
	tab = t
	selected = ""
	refresh()


## The recipes on the open tab, known and shown, in kind order.
func recipes() -> Array[String]:
	var out: Array[String] = []
	for g in GROUPS:
		for r: Dictionary in session.content.rows("recipes"):
			var id := str(r["id"])
			if not session.recipes_known.has(id) or group_of(id) != g:
				continue
			if r.has("refit") and session.slot_variant(id).is_empty():
				continue
			if tab != "all" and str(r["station"]) != tab:
				continue
			out.append(id)
	return out


func group_of(id: String) -> String:
	var r := session.content.row("recipes", id)
	if r.has("refit"):
		return "refits"
	if str(r["station"]) == "fire":
		return "food"
	var item := str((r["result"] as Dictionary).get("item", ""))
	var kind := str(session.content.row("items", item).get("kind", "")) if item != "" and session.content.has("items", item) else ""
	match kind:
		"food":
			return "food"
		"placeable", "park_thing":
			return "park"
		"gift":
			return "gifts"
	return "workshop"


## The picture of what a recipe makes.
func picture_of(id: String) -> String:
	var r := session.content.row("recipes", id)
	if r.has("refit"):
		var v := session.slot_variant(id)
		var res := str(v.get("result", r["refit"]))
		return _item_icon(res) if _item_icon(res) != "" else _item_icon(str(r["refit"]))
	var item := str((r["result"] as Dictionary).get("item", ""))
	if item == "":
		return pick(["item_pack_frame", "item_backpack"])
	return _item_icon(item)


func _item_icon(item: String) -> String:
	if not session.content.has("items", item):
		return ""
	var ic := str(session.content.row("items", item).get("icon", ""))
	return ic if Art.has_picture(ic) else ""


## The few words on a card: "ready", "short", "at a workbench"...
func status_of(id: String) -> Array:
	var why := session.craft_problem(id)
	var c := session.content
	match why:
		"":
			return [c.text("make_ready"), true]
		"msg_craft_need_workbench":
			return [c.text("make_at_workbench"), false]
		"msg_cook_need_fire":
			return [c.text("make_at_fire"), false]
		"msg_craft_need_tool":
			return [c.text("make_needs", {"tool": c.item_name(str(c.row("recipes", id).get("tool", ""))).to_lower()}), false]
		"msg_backpack_full":
			return [c.text("make_pack_full"), false]
	return [c.text("make_short"), false]


## What a recipe takes: [{item, need, have}], a refit's tool included.
func inputs_of(id: String) -> Array:
	var r := session.content.row("recipes", id)
	var out := []
	if r.has("refit"):
		var fam := str(r["refit"])
		out.append({"item": fam, "need": 1, "have": 1 if session.has_tool(fam) else 0})
		var v := session.slot_variant(id)
		if not v.is_empty():
			out.append({"item": str(v["ingredient"]), "need": 1, "have": session.have(str(v["ingredient"]))})
		return out
	for k: String in r["inputs"]:
		out.append({"item": k, "need": int(r["inputs"][k]), "have": session.have(k)})
	return out


## How many could be made in a row with what's at hand (up to MAKE_MANY).
func how_many(id: String) -> int:
	if session.craft_problem(id) != "":
		return 0
	var r := session.content.row("recipes", id)
	if r.has("refit") or bool(r.get("once", false)) or not (r["result"] as Dictionary).has("item"):
		return 1
	var n := MAKE_MANY
	for e: Dictionary in inputs_of(id):
		n = mini(n, int(e["have"]) / maxi(1, int(e["need"])))
	return maxi(1, n)


func refresh() -> void:
	if not visible:
		return
	var c := session.content
	var tabs := []
	for t in TABS:
		tabs.append({"id": t, "label": c.text("make_tab_" + t), "icon": pick(STATION_PICTURES[t])})
	set_index_tabs(tabs, tab, func(t: String) -> void: set_tab(t))
	var ids := recipes()
	if selected == "" or not ids.has(selected):
		selected = ids[0] if not ids.is_empty() else ""
	_fill_list(ids)
	_fill_detail()
	empty_label.visible = ids.is_empty()
	empty_label.text = c.text("make_empty_" + tab)
	var keys := []
	if station == "anywhere":
		keys.append([["Tab"], c.text("key_sheets")])
	keys.append([["Q", "E"], c.text("key_where")])
	keys.append([["W", "S"], c.text("key_list")])
	keys.append([["X"], c.text("key_make")])
	keys.append([["Esc"], c.text("key_close")])
	set_keys(keys)


func _choose(id: String) -> void:
	if id == selected:
		return
	selected = id
	refresh()


func _fill_list(ids: Array[String]) -> void:
	clear(list)
	_cards.clear()
	var c := session.content
	var last := ""
	for id in ids:
		var g := group_of(id)
		if g != last:
			last = g
			list.add_child(ribbon(c.text("make_group_" + g), pick(GROUP_PICTURES[g]), GROUP_COLORS[g]))
		var st := status_of(id)
		var k := id
		var cd := card(picture_of(id), c.text(c.row("recipes", id)["name"]), status_line(str(st[0]), bool(st[1])), id == selected, func() -> void: _choose(k), not bool(st[1]))
		_cards[id] = cd
		list.add_child(cd)


func _fill_detail() -> void:
	clear(detail)
	clear(stamps)
	var c := session.content
	if selected != "":
		var id := selected
		var r := c.row("recipes", id)
		var at := str(r["station"])
		var chips: Array[Control] = []
		var here := session.station_ok(at)
		chips.append(chip(pick(STATION_PICTURES[at]), c.text("make_where_" + at), "" if here else "bad"))
		if r.has("tool"):
			var tl := str(r["tool"])
			chips.append(chip(_item_icon(tl), c.item_name(tl), "" if session.has_tool(tl) else "bad"))
		chips.append(chip(pick(["icon_time"]), c.text("make_minutes", {"n": session.tuning.integer("crafting.minutes")})))
		detail.add_child(header(picture_of(id), c.text(r["name"]), chips))
		var item := str((r["result"] as Dictionary).get("item", ""))
		if item != "" and c.has("text", "item_desc_" + item):
			detail.add_child(voice(c.text("item_desc_" + item)))
		# You'll need: a tile for each thing, with have/need.
		detail.add_child(heading(c.text("make_need")))
		var row := tile_row()
		for e: Dictionary in inputs_of(id):
			var enough := int(e["have"]) >= int(e["need"])
			row.add_child(tile(_item_icon(str(e["item"])), "%d/%d" % [int(e["have"]), int(e["need"])], "gold" if enough else "red", c.item_name(str(e["item"]))))
		detail.add_child(row)
		# Makes, and what it does.
		var does := _does(id)
		var mk := HBoxContainer.new()
		mk.add_theme_constant_override("separation", 6)
		var left := VBoxContainer.new()
		left.add_child(heading(c.text("make_makes")))
		var count := int((r["result"] as Dictionary).get("count", 1))
		left.add_child(tile(picture_of(id), str(count) if count > 1 else "", "gold"))
		mk.add_child(left)
		if not does.is_empty():
			var right := VBoxContainer.new()
			right.add_theme_constant_override("separation", 3)
			right.add_child(heading(c.text("make_does")))
			var flow := HFlowContainer.new()
			flow.custom_minimum_size = Vector2(DETAIL_W - 70, 0)
			flow.add_theme_constant_override("h_separation", 3)
			for d: Control in does:
				flow.add_child(d)
			right.add_child(flow)
			mk.add_child(right)
		detail.add_child(mk)
		# The stamps.
		var n := how_many(id)
		add_stamp(pick(["verb_make", "item_hammer"]), c.text("make_stamp"), "X", n >= 1, func() -> void: make(1))
		if n >= 2:
			add_stamp(pick(["verb_make", "item_hammer"]), c.text("make_stamp_n", {"n": n}), "", true, func() -> void: make(n))
	if station == "fire":
		add_stamp(pick(["item_firewood"]), c.text("make_firewood", {"n": session.backpack.count("firewood")}), "", session.backpack.has("firewood"), func() -> void:
			session.choose_recipe("#firewood")
			refresh())
	elif station == "workbench" and session.bench_box() != null:
		add_stamp(pick(["furniture_workbench", "item_workbench_kit"]), c.text("make_bench_box"), "", true, func() -> void:
			close()
			session.choose_recipe("#bench_box"))


## What a recipe's result does, as chips: energy and warmth for food, or the
## recipe's use in a few words.
func _does(id: String) -> Array[Control]:
	var c := session.content
	var out: Array[Control] = []
	var item := str((c.row("recipes", id)["result"] as Dictionary).get("item", ""))
	if item != "" and c.has("foods", item):
		var f := c.row("foods", item)
		if int(f.get("energy", 0)) > 0:
			out.append(chip(pick(["icon_energy"]), c.text("fx_energy", {"n": int(f["energy"])}), "good"))
		if int(f.get("warmth", 0)) > 0:
			out.append(chip(pick(["icon_warmth"]), c.text("fx_warmth", {"n": int(f["warmth"])}), "good"))
		return out
	if c.has("text", "recipe_use_" + id):
		out.append(text(c.text("recipe_use_" + id), 6, KitStyle.TEXT_DARK, DETAIL_W - 80))
	return out


## Makes the chosen recipe n times in a row, stopping when it can't.
func make(n: int) -> int:
	var made := 0
	for i in n:
		if selected == "" or not session.craft(selected):
			break
		made += 1
	refresh()
	return made


## Keys while the sheet is open. True when the key was used.
func handle(event: InputEvent) -> bool:
	if event.is_action_pressed("cancel") or event.is_action_pressed("pause") or event.is_action_pressed("backpack") or (event.is_action_pressed("craft") and station == "anywhere"):
		close()
		return true
	# Q and E turn the tabs, as on the jobs sheet.
	if event.is_action_pressed("tab_prev") or event.is_action_pressed("tab_next"):
		var d := -1 if event.is_action_pressed("tab_prev") else 1
		set_tab(TABS[(TABS.find(tab) + TABS.size() + d) % TABS.size()])
		return true
	if event.is_action_pressed("move_up") or event.is_action_pressed("move_down"):
		var ids := recipes()
		if ids.is_empty():
			return true
		var i := ids.find(selected)
		i = clampi(i + (1 if event.is_action_pressed("move_down") else -1), 0, ids.size() - 1)
		selected = ids[i]
		refresh()
		if _cards.has(selected):
			list_scroll.ensure_control_visible.call_deferred(_cards[selected])
		return true
	if event.is_action_pressed("interact") or event.is_action_pressed("confirm"):
		make(1)
		return true
	return false
