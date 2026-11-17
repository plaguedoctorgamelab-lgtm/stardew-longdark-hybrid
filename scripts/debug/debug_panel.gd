class_name DebugPanel
extends Panel
## F1 debug panel, test builds only. Every button calls a debug method on the
## game session, and the automated tests call the same methods.

var session: GameSession
var _vbox: VBoxContainer
var _weather_pick: OptionButton
var _next_pick: OptionButton
var _item_pick: OptionButton
var _hour: SpinBox
var _energy: SpinBox
var _warmth: SpinBox
var _fast: CheckBox
var _drain: CheckBox
var _overlay: CheckBox
var _forage_pick: OptionButton
var _skill_pick: OptionButton
var _skill_level: SpinBox
var _spoilers: CheckBox
var _magic_pick: OptionButton
var _spec_pick: OptionButton
var on_teleport: Callable = func() -> void: pass


func setup(s: GameSession) -> void:
	session = s
	position = Vector2(2, 2)
	size = Vector2(250, 266)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(2, 2)
	scroll.size = size - Vector2(4, 4)
	add_child(scroll)
	_vbox = VBoxContainer.new()
	_vbox.add_theme_constant_override("separation", 1)
	scroll.add_child(_vbox)
	var title := Label.new()
	title.text = s.content.text("ui_debug_title") + " (F1)  ·  " + s.content.text("ui_version", {"v": str(ProjectSettings.get_setting("application/config/version", "0.0.0"))})
	_vbox.add_child(title)

	var r := _row()
	_hour = _spin(r, 6, 26, 6)
	_btn(r, "Set hour", func() -> void: session.debug_set_time(int(_hour.value) * 60))
	_btn(r, "+block", session.debug_skip_block)
	_btn(r, "+day", session.debug_skip_day)
	_btn(r, "+season", session.debug_skip_season)
	r = _row()
	_fast = CheckBox.new()
	_fast.text = "Clock x10"
	_fast.toggled.connect(session.debug_fast)
	r.add_child(_fast)
	_overlay = CheckBox.new()
	_overlay.text = "Tile/chunk info"
	_overlay.toggled.connect(func(on: bool) -> void: session.debug_overlay = on)
	r.add_child(_overlay)

	r = _row()
	_weather_pick = _pick(r, session.content.ids("weather_types"))
	_btn(r, "Force now", func() -> void: session.debug_force_weather(_weather_pick.get_item_text(_weather_pick.selected)))
	_next_pick = _pick(r, session.content.ids("weather_types"))
	_btn(r, "Set next", func() -> void: session.debug_set_next_weather(_next_pick.get_item_text(_next_pick.selected)))

	r = _row()
	_energy = _spin(r, 0, 270, 270)
	_warmth = _spin(r, 0, 100, 100)
	_btn(r, "Set E/W", func() -> void: session.debug_set_needs(_energy.value, _warmth.value))
	_drain = CheckBox.new()
	_drain.text = "Drain"
	_drain.button_pressed = true
	_drain.toggled.connect(func(on: bool) -> void: session.debug_drain(on, on))
	r.add_child(_drain)

	r = _row()
	for spot: String in ["station", "fork", "outlook", "cabin", "pond", "tower", "bridge"]:
		_btn(r, spot.capitalize(), func() -> void:
			session.debug_teleport(spot)
			on_teleport.call())

	r = _row()
	_btn(r, "Clear in front", func() -> void: session.debug_clear_obstacle(session.ranger_tile() + session.facing_vector()))
	_btn(r, "Restore", func() -> void: session.debug_clear_obstacle(session.ranger_tile() + session.facing_vector(), false))
	_btn(r, "Dig in front", func() -> void: session.debug_dig(session.ranger_tile() + session.facing_vector()))
	_btn(r, "Undig", func() -> void: session.debug_dig(session.ranger_tile() + session.facing_vector(), false))
	_btn(r, "Sign in front", func() -> void: session.debug_put_up(session.ranger_tile() + session.facing_vector(), "trail_sign", "ranger_station"))

	r = _row()
	for step: String in GameSession.SITE_STEPS:
		_btn(r, step.capitalize(), func() -> void: session.debug_site_step("static_tower", step, not session.site_step_done("static_tower", step)))
	_btn(r, "Open site", func() -> void: session.debug_open_site("static_tower"))
	_btn(r, "Site status", func() -> void: session.message.emit(" | ".join(session.site_lines())))
	_btn(r, "Spoilers: finds", func() -> void: session.message.emit(session.debug_finds_text()))

	r = _row()
	_item_pick = _pick(r, session.content.ids("items"))
	_btn(r, "Add item", func() -> void: session.debug_add_item(_item_pick.get_item_text(_item_pick.selected), 1))
	_btn(r, "Add x5", func() -> void: session.debug_add_item(_item_pick.get_item_text(_item_pick.selected), 5))

	for step: Dictionary in session.content.row("structures", "test_cabin")["repair_steps"]:
		r = _row()
		var sid: String = step["id"]
		var l := Label.new()
		l.text = "Cabin " + sid
		l.custom_minimum_size = Vector2(70, 0)
		r.add_child(l)
		_btn(r, "Done", func() -> void: session.debug_cabin_step(sid, true))
		_btn(r, "Undo", func() -> void: session.debug_cabin_step(sid, false))

	r = _row()
	var tl := Label.new()
	tl.text = "Fire tower"
	tl.custom_minimum_size = Vector2(70, 0)
	r.add_child(tl)
	_btn(r, "Repair all", func() -> void: session.debug_repair_all("static_tower", true))
	_btn(r, "Undo all", func() -> void: session.debug_repair_all("static_tower", false))

	r = _row()
	_forage_pick = _pick(r, session.content.ids("forage"))
	_btn(r, "Forage in front", func() -> void:
		session.debug_spawn_forage(session.ranger_tile() + session.facing_vector(), _forage_pick.get_item_text(_forage_pick.selected)))
	_btn(r, "Regrow forage", session.debug_regrow_forage)
	_btn(r, "Unlock recipes", session.debug_unlock_recipes)

	# Magical ingredients: counts only, unless spoilers are ticked.
	r = _row()
	_spoilers = CheckBox.new()
	_spoilers.text = "Show spoilers"
	_spoilers.focus_mode = Control.FOCUS_NONE
	r.add_child(_spoilers)
	_btn(r, "Magic info", func() -> void: session.note_read.emit(session.debug_magic_text(_spoilers.button_pressed)))
	var magic_ids: Array[String] = []
	for id: String in session.forage.magic_places:
		magic_ids.append(id)
	_magic_pick = _pick(r, magic_ids)
	_btn(r, "Go to it", func() -> void:
		if _spoilers.button_pressed and session.debug_go_to_magic(_magic_pick.get_item_text(_magic_pick.selected)):
			on_teleport.call())

	r = _row()
	_skill_pick = _pick(r, session.content.ids("skills"))
	_skill_level = _spin(r, 0, 10, 5)
	_btn(r, "Set level", func() -> void: session.debug_set_skill(_skill_pick.get_item_text(_skill_pick.selected), int(_skill_level.value)))
	_spec_pick = _pick(r, session.content.ids("specialties"))
	_btn(r, "Give", func() -> void: session.debug_choose_specialty(_spec_pick.get_item_text(_spec_pick.selected)))

	r = _row()
	_btn(r, "Reveal map", session.debug_reveal_map)
	_btn(r, "Wipe map", session.debug_wipe_map)
	_btn(r, "Reload tuning", func() -> void:
		var ok := session.debug_reload_tuning()
		session.message.emit("Tuning reloaded" if ok else "Tuning reload FAILED"))
	visible = false


func _row() -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 2)
	_vbox.add_child(h)
	return h


func _btn(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _spin(parent: Control, lo: float, hi: float, v: float) -> SpinBox:
	var s := SpinBox.new()
	s.min_value = lo
	s.max_value = hi
	s.value = v
	s.custom_minimum_size = Vector2(44, 0)
	parent.add_child(s)
	return s


func _pick(parent: Control, options: Array[String]) -> OptionButton:
	var o := OptionButton.new()
	for x in options:
		o.add_item(x)
	o.focus_mode = Control.FOCUS_NONE
	parent.add_child(o)
	return o
