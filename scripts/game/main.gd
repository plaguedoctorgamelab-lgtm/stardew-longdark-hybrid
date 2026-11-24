extends Node
## The running game. Builds the session and the views, reads input through the
## input map by action name, and keeps the camera on the ranger.

const TILE := 16
const VIEW := Vector2i(480, 270)

var world: SubViewport

var session: GameSession
var world_view: WorldView
var interior_view: InteriorView
var town_view: TownView
var ranger: RangerSprite
var camera: Camera2D
var effects: ScreenEffects
var hud: Hud
var menus: CanvasLayer
var ui_theme: Theme
var inventory_screen: InventoryScreen
var map_screen: MapScreen
var choice_screen: ChoiceScreen
var make_sheet: MakeSheet   # crafting, the workbench and cooking on the clipboard (0.7.15)
var shop_sheet: ShopSheet   # a shop on the clipboard (0.7.19)
var debug_panel: DebugPanel
var dialog: Panel
var dialog_label: Label
var dialog_face: TextureRect   # the speaker's portrait in the talk box (Phase 4)
var title_screen: TitleScreen
var title_note: Label
var pause_menu: Panel
var book_screen: BookScreen
var social_screen: SocialScreen
var menu_tabs: MenuTabs   # the game menu's picture tabs over the open page (0.7.9)
var scene_player: ScenePlayer     # heart events (Phase 4b)
var fortune_screen: FortuneScreen # Esme's cards (Phase 4b)
var clipboard: ClipboardScreen
var job_card: JobCardScreen
var job_note: JobNote
var _map_changes: Array = []     # changes from finished jobs, for the map's flourish
var _map_lines: PackedStringArray = []
var pinned_button: Button
var unlocks_button: Button
var music_button: Button
var fullscreen_button: Button
var music: Music
var hint_overlay: HintOverlay
var options_panel: Panel
var tips_button: Button
var _dialog_kind: String = ""
var _hover_wait: float = 0.0
var _hover_forage: Vector2i = Vector2i(-1, -1)   # forage under the mouse, in reach (tracker #8)
var _cursor: String = ""
var started: bool = false


func _ready() -> void:
	Settings.apply_window()
	ui_theme = _make_theme()
	session = GameSession.new()
	music = Music.new()
	add_child(music)
	music.setup(session.content, session.tuning)
	ranger = RangerSprite.new()
	world = _make_world_viewport()
	world_view = WorldView.new()
	world.add_child(world_view)
	world_view.setup(session, ranger)
	interior_view = InteriorView.new()
	interior_view.visible = false
	world.add_child(interior_view)
	interior_view.setup(session)
	town_view = TownView.new()
	town_view.visible = false
	world.add_child(town_view)
	town_view.setup(session)
	hint_overlay = HintOverlay.new()
	world.add_child(hint_overlay)
	hint_overlay.setup(session)
	camera = Camera2D.new()
	world.add_child(camera)
	camera.make_current()
	effects = ScreenEffects.new()
	world.add_child(effects)
	effects.setup(session)
	hud = Hud.new()
	add_child(hud)
	hud.setup(session, ui_theme)
	job_note = JobNote.new()
	hud.root.add_child(job_note)
	job_note.setup(session)
	_build_menus()
	job_note.note_clicked.connect(func(key: String) -> void:
		if not menu_open():
			clipboard.open(key))

	session.location_changed.connect(_on_location_changed)
	session.town_changed.connect(func(_in: bool) -> void: _on_location_changed(session.location))
	session.clothes_changed.connect(_dress_ranger)
	_dress_ranger()
	session.townsperson_spoke.connect(func(talk: Dictionary) -> void:
		var h := int(talk["hearts"])
		var hearts := session.content.text("town_heart_1") if h == 1 else session.content.text("town_hearts", {"n": h})
		_face(str(talk.get("person", "")), str(talk.get("mood", "neutral")))
		_show_dialog("talk", "%s  ·  %s\n\n%s" % [talk["name"], hearts, talk["text"]]))
	session.storage_opened.connect(func(title: String, inv: Inventory) -> void: inventory_screen.open(inv, title))
	session.radio_heard.connect(func(lines: PackedStringArray) -> void: _show_dialog("radio", "\n".join(lines)))
	session.confirm_requested.connect(func(kind: String, text: String) -> void: _show_dialog(kind, text))
	session.structures.changed.connect(func(id: String) -> void:
		if interior_view.visible:
			# Decorating changes the station's furniture: build the room again.
			if id == "ranger_station" and interior_view.current == "ranger_station" and session.location == "ranger_station":
				interior_view.show_room("ranger_station", ranger)
			else:
				interior_view.refresh())
	scene_player = ScenePlayer.new()
	add_child(scene_player)
	scene_player.setup(session)
	session.scene_started.connect(_start_scene)
	scene_player.line.connect(func(person: String, mood: String, text: String) -> void:
		_face(person, mood)
		var head := ""
		if person != "" and session.content.has("townsfolk", person):
			head = str(session.content.row("townsfolk", person)["name"]) + "\n\n"
		_show_dialog("scene", head + text))
	scene_player.choose.connect(func(title: String, options: Array) -> void: choice_screen.open("scene", title, options))
	session.fortune_read.connect(func(r: Dictionary) -> void: fortune_screen.open(r))
	session.collapsed.connect(func(text: String) -> void: _show_dialog("notice", text))
	session.note_read.connect(func(text: String) -> void: _show_dialog("notice", text))
	session.workbench_opened.connect(func() -> void: make_sheet.open("workbench"))
	session.cooking_opened.connect(func() -> void: make_sheet.open("fire"))
	session.choice_requested.connect(func(kind: String, title: String, options: Array) -> void: choice_screen.open(kind, title, options))
	session.list_requested.connect(func(kind: String, title: String, options: Array) -> void:
		if kind.begins_with("shop:"):
			choice_screen.visible = false
			shop_sheet.open(kind.substr(5))
		else:
			choice_screen.reopen(kind, title, options))
	choice_screen.chosen.connect(func(kind: String, option_id: String) -> void:
		if kind == "scene":
			choice_screen.visible = false
			scene_player.pick(int(option_id))
			return
		if choice_screen.STATIONS.has(kind):
			session.choose_recipe(option_id)
			choice_screen.refresh()
		elif kind in ["catalog", "staff", "books", "fstall", "home"] or kind.begins_with("assign:") or kind.begins_with("shop:") or kind.begins_with("buy:") or kind.begins_with("sell:"):
			var nxt := session.answer_list(kind, option_id)
			if nxt == "close":
				choice_screen.visible = false
			elif nxt.begins_with("shop:"):
				choice_screen.visible = false
				shop_sheet.open(nxt.substr(5))
			elif nxt != "":
				choice_screen.reopen(nxt, session.list_title(nxt), session.list_options(nxt))
			elif choice_screen.visible:
				choice_screen.reopen(kind, session.list_title(kind), session.list_options(kind))
		else:
			session.answer_choice(kind, option_id))
	session.backpack.changed.connect(func() -> void:
		choice_screen.refresh()
		make_sheet.refresh()
		shop_sheet.refresh())
	session.traveled.connect(func() -> void:
		_on_location_changed(session.location)
		world_view.reset_chunks())
	session.survey_finished.connect(func() -> void:
		if not menu_open():
			map_screen.open())
	# A tool landed: the ranger holds still a few frames (hit-stop).
	session.tool_landed.connect(func(tool: String, _t: Vector2i, kind: String) -> void:
		var frames: Dictionary = session.tuning.value("look.polish.hitstop_frames")
		ranger.freeze(int(frames.get("fell" if kind == "fell" else tool, 3))))
	ranger.bob_delay = session.tuning.num("look.polish.idle_bob_delay")
	ranger.bob_period = session.tuning.num("look.polish.idle_bob_period")
	session.backpack_grew.connect(func() -> void:
		hud.rebuild_slots()
		inventory_screen.rebuild_slots())
	_show_title()


## What X does at the thing under the mouse, for the HUD's hover hint. Looked
## at a few times a second; nothing while a screen is open.
func _update_world_hint(delta: float) -> void:
	_hover_wait -= delta
	if _hover_wait > 0.0:
		return
	_hover_wait = 0.1
	if menu_open():
		hud.world_hint = ""
		_hover_forage = Vector2i(-1, -1)
		_set_cursor("cursor_arrow")
		return
	# The HUD's layer is the 480 x 270 screen, whatever the window's size.
	var mouse := hud.root.get_local_mouse_position()
	var p := world.get_canvas_transform().affine_inverse() * mouse / TILE
	hud.world_hint = session.guide.x_hint_at(p)
	# Over forage the ranger can reach, the cursor shows a plus: a click picks it.
	_hover_forage = session.forage_at(p)
	_set_cursor("cursor_pick" if _hover_forage.x >= 0 else "cursor_arrow")


## The mouse pointer: the game's own arrow, or the plus over forage.
func _set_cursor(art_name: String) -> void:
	if art_name == _cursor or not Art.has_picture(art_name):
		return
	_cursor = art_name
	Input.set_custom_mouse_cursor(Art.texture(art_name), Input.CURSOR_ARROW, Vector2.ZERO)


## The world is drawn into its own 480 by 270 picture with nearest filtering,
## then shown scaled up by a whole number, so it stays pixel-perfect. Text and
## menus are drawn outside it at the screen's full resolution, so they stay
## sharp.
func _make_world_viewport() -> SubViewport:
	var holder := SubViewportContainer.new()
	holder.stretch = true
	holder.size = Vector2(VIEW)
	holder.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	var vp := SubViewport.new()
	vp.size = VIEW
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	vp.snap_2d_transforms_to_pixel = true
	vp.snap_2d_vertices_to_pixel = true
	vp.handle_input_locally = false
	holder.add_child(vp)
	return vp


## Every screen shares the ranger's kit theme (KitStyle).
func _make_theme() -> Theme:
	return KitStyle.theme()


func _build_menus() -> void:
	menus = CanvasLayer.new()
	menus.layer = 10
	add_child(menus)
	var root := Control.new()
	root.theme = ui_theme
	root.size = Vector2(480, 270)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menus.add_child(root)
	inventory_screen = InventoryScreen.new()
	root.add_child(inventory_screen)
	inventory_screen.setup(session)
	map_screen = MapScreen.new()
	root.add_child(map_screen)
	map_screen.setup(session)
	choice_screen = ChoiceScreen.new()
	root.add_child(choice_screen)
	choice_screen.setup(session)
	make_sheet = MakeSheet.new()
	root.add_child(make_sheet)
	make_sheet.setup(session)
	shop_sheet = ShopSheet.new()
	root.add_child(shop_sheet)
	shop_sheet.setup(session)
	shop_sheet.handed_on.connect(func(nxt: String) -> void:
		if nxt != "" and nxt != "close":
			choice_screen.reopen(nxt, session.list_title(nxt), session.list_options(nxt)))
	book_screen = BookScreen.new()
	root.add_child(book_screen)
	book_screen.setup(session)
	social_screen = SocialScreen.new()
	root.add_child(social_screen)
	social_screen.setup(session)
	clipboard = ClipboardScreen.new()
	root.add_child(clipboard)
	clipboard.setup(session)
	clipboard.show_on_map.connect(func(p: Vector2, text: String) -> void: map_screen.open_at(p, text))
	job_card = JobCardScreen.new()
	root.add_child(job_card)
	job_card.setup(session)
	job_card.finished.connect(_on_card_closed)
	menu_tabs = MenuTabs.new()
	root.add_child(menu_tabs)
	menu_tabs.setup(session.content)
	menu_tabs.chosen.connect(open_tab)
	inventory_screen.want_tab.connect(open_tab)
	fortune_screen = FortuneScreen.new()
	root.add_child(fortune_screen)
	fortune_screen.setup(session)
	social_screen.friends_asked.connect(func(person: String) -> void:
		social_screen.close()
		session.ask_just_friends(person))
	dialog = Panel.new()
	dialog.size = Vector2(320, 70)
	dialog.position = Vector2(80, 90)
	dialog.visible = false
	root.add_child(dialog)
	KitStyle.frame(dialog)
	dialog_label = Label.new()
	dialog_label.position = Vector2(8, 6)
	dialog_label.size = Vector2(304, 58)
	dialog_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	dialog.add_child(dialog_label)
	dialog_face = TextureRect.new()
	dialog_face.position = Vector2(6, 6)
	dialog_face.size = Vector2(64, 64)
	dialog_face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	dialog_face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	dialog_face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	dialog_face.visible = false
	dialog.add_child(dialog_face)
	debug_panel = DebugPanel.new()
	root.add_child(debug_panel)
	debug_panel.setup(session)
	debug_panel.on_teleport = func() -> void:
		_on_location_changed(session.location)
		world_view.reset_chunks()
	title_screen = TitleScreen.new()
	root.add_child(title_screen)
	var title_actions: Array = [["ui_new_game", _start_new], ["ui_continue", _continue]]
	# Playtest builds also offer a start with the first sites open.
	if OS.is_debug_build():
		title_actions.append(["ui_playtest_start", _start_playtest])
	title_actions.append(["ui_quit", func() -> void: get_tree().quit()])
	title_screen.setup(session.content, version_text(), title_actions)
	title_note = title_screen.note
	_build_pause_menu(root)


## The build's version, kept in project.godot (application/config/version).
static func version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "0.0.0"))


func version_text() -> String:
	return session.content.text("ui_version", {"v": version()})


## Escape opens this when no other screen is open: resume, or quit.
func _build_pause_menu(root: Control) -> void:
	pause_menu = Panel.new()
	pause_menu.visible = false
	root.add_child(pause_menu)
	var box := VBoxContainer.new()
	box.position = Vector2(8, 6)
	box.add_theme_constant_override("separation", 4)
	pause_menu.add_child(box)
	var t := Label.new()
	t.text = session.content.text("ui_paused")
	box.add_child(t)
	box.add_child(_button_column([["ui_resume", close_pause], ["ui_options", open_options], ["ui_quit_title", _quit_to_title], ["ui_quit_game", func() -> void: get_tree().quit()]]))
	var note := Label.new()
	note.text = session.content.text("ui_pause_note")
	note.custom_minimum_size = Vector2(144, 0)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD
	note.modulate = Color(1, 1, 1, 0.8)
	box.add_child(note)
	box.reset_size()
	pause_menu.size = box.get_combined_minimum_size() + Vector2(16, 12)
	pause_menu.position = ((Vector2(VIEW) - pause_menu.size) / 2.0).round()
	KitStyle.frame(pause_menu)
	_build_options(root)


## The Options screen, from the pause menu: the player's own settings, kept
## for every game (Settings). For now, when the hover tips show (tracker #7).
func _build_options(root: Control) -> void:
	options_panel = Panel.new()
	options_panel.visible = false
	root.add_child(options_panel)
	var box := VBoxContainer.new()
	box.position = Vector2(8, 6)
	box.add_theme_constant_override("separation", 5)
	options_panel.add_child(box)
	var trow := HBoxContainer.new()
	trow.add_theme_constant_override("separation", 4)
	box.add_child(trow)
	var gear := KitStyle.tab_icon("options")
	if gear != null:
		gear.custom_minimum_size = Vector2(12, 12)
		trow.add_child(gear)
	var t := Label.new()
	t.text = session.content.text("ui_options_title")
	trow.add_child(t)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	box.add_child(row)
	var l := Label.new()
	l.text = session.content.text("ui_options_hover_tips")
	row.add_child(l)
	tips_button = Button.new()
	tips_button.focus_mode = Control.FOCUS_NONE
	tips_button.custom_minimum_size = Vector2(110, 0)
	tips_button.pressed.connect(func() -> void:
		Settings.next_hover_tips()
		_show_tips_choice())
	row.add_child(tips_button)
	var note := Label.new()
	note.text = session.content.text("ui_options_hover_note", {"n": session.tuning.integer("ui.hover_tip_days")})
	note.custom_minimum_size = Vector2(220, 0)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD
	note.modulate = Color(1, 1, 1, 0.8)
	box.add_child(note)
	pinned_button = _toggle_row(box, "ui_options_pinned", "show_pinned_job")
	unlocks_button = _toggle_row(box, "ui_options_unlock_map", "show_unlocks_on_map")
	_toggle_row(box, "ui_options_motion", "motion")
	_toggle_row(box, "ui_options_weather_effects", "weather_effects")
	fullscreen_button = _toggle_row(box, "ui_options_fullscreen", "fullscreen", Settings.apply_window)
	var mrow := HBoxContainer.new()
	mrow.add_theme_constant_override("separation", 6)
	box.add_child(mrow)
	var ml := Label.new()
	ml.text = session.content.text("ui_options_music")
	ml.custom_minimum_size = Vector2(110, 0)
	mrow.add_child(ml)
	music_button = Button.new()
	music_button.focus_mode = Control.FOCUS_NONE
	music_button.custom_minimum_size = Vector2(60, 0)
	music_button.text = session.content.text("ui_music_" + Settings.music())
	music_button.pressed.connect(func() -> void:
		music_button.text = session.content.text("ui_music_" + Settings.next_music()))
	mrow.add_child(music_button)
	box.add_child(_button_column([["ui_back", close_options]]))
	_show_tips_choice()
	box.reset_size()
	options_panel.size = box.get_combined_minimum_size() + Vector2(16, 12)
	options_panel.position = ((Vector2(VIEW) - options_panel.size) / 2.0).round()
	KitStyle.frame(options_panel)


## Warm light at night (Art Request 16): outdoors, each open building's
## windows and doorstep; indoors, the room's lamps and its stove when lit.
func _night_glows() -> Array[Vector4]:
	var out: Array[Vector4] = []
	var t := session.tuning
	if not Daylight.is_night(t, session.clock.season_name(), session.clock.minute):
		return out
	var xf := world_view.get_canvas_transform()
	if session.in_town and not session.in_town_room():
		for at: Vector2 in town_view.lamps:
			var sp := xf * at
			if sp.x < -80 or sp.y < -80 or sp.x > VIEW.x + 80 or sp.y > VIEW.y + 80:
				continue
			out.append(Vector4(sp.x, sp.y, t.num("town_look.lamp_glow_tiles") * TILE, t.num("town_look.lamp_glow_strength")))
		return out
	if session.is_indoors() or session.in_town_room():
		var layout: InteriorLayout = session.room_layout(session.town_inside if session.in_town_room() else session.location)
		for f: Dictionary in layout.furniture:
			var lamp := str(f["sprite"]).begins_with("furniture_oil_lamp")
			var stove := str(f["kind"]) == "stove" and session.structures.stove_lit(session.location)
			if lamp or stove:
				var r := Rect2(Vector2(f["pos"][0], f["pos"][1]), Vector2(f["size"][0], f["size"][1]))
				var at := xf * (interior_view.position + r.get_center() * TILE)
				out.append(Vector4(at.x, at.y, t.num("light.lamp_glow_tiles" if lamp else "light.stove_glow_tiles") * TILE, 1.0))
		return out
	for id: String in session.structures.ids():
		if not session.structures.is_open(id) and id != "ranger_station":
			continue
		var at := xf * ((session.door_front(id) + Vector2(0, -1.0)) * TILE)
		if at.x < -80 or at.y < -80 or at.x > VIEW.x + 80 or at.y > VIEW.y + 80:
			continue
		out.append(Vector4(at.x, at.y, t.num("light.building_glow_tiles") * TILE, t.num("light.building_glow_strength")))
	return out


## The music follows the moment: the title, the season, night, indoors.
func _update_music(delta: float) -> void:
	var on_title := not started or title_screen.visible
	var season := session.clock.season_name() if not on_title else ""
	var night := false if on_title else Daylight.is_night(session.tuning, season, session.clock.minute)
	music.update(delta, on_title, season, night, not on_title and (session.is_indoors() or session.in_town_room()))


## An on/off setting on the Options screen.
func _toggle_row(box: VBoxContainer, label_id: String, key: String, then: Callable = Callable()) -> Button:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	box.add_child(row)
	var l := Label.new()
	l.text = session.content.text(label_id)
	l.custom_minimum_size = Vector2(110, 0)
	row.add_child(l)
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(40, 0)
	b.text = session.content.text("ui_on" if Settings.flag(key) else "ui_off")
	b.pressed.connect(func() -> void:
		b.text = session.content.text("ui_on" if Settings.toggle(key) else "ui_off")
		if then.is_valid():
			then.call())
	row.add_child(b)
	return b


## A finishing card closed: its map changes wait for the flourish.
func _on_card_closed(c: Dictionary) -> void:
	if str(c.get("kind", "")) != "done" or not Settings.flag("show_unlocks_on_map"):
		return
	for ch: Dictionary in c.get("map", []):
		_map_changes.append(ch)
		var line := session.content.text({"rumor": "jt_map_rumors", "reveal": "jt_map_reveal", "travel": "jt_map_travel"}[str(ch["kind"])])
		if not _map_lines.has(line):
			_map_lines.append(line)


func _show_tips_choice() -> void:
	tips_button.text = session.content.text("ui_hover_tips_" + Settings.hover_tips())


func open_options() -> void:
	pause_menu.visible = false
	options_panel.visible = true


func close_options() -> void:
	options_panel.visible = false
	pause_menu.visible = true


## A column of buttons, one per [text id, action], stacked so they never overlap.
func _button_column(pairs: Array) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	for pair: Array in pairs:
		var b := Button.new()
		b.text = session.content.text(pair[0])
		b.custom_minimum_size = Vector2(80, 0)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(pair[1])
		col.add_child(b)
	return col


func open_pause() -> void:
	pause_menu.visible = true


func close_pause() -> void:
	pause_menu.visible = false


func _quit_to_title() -> void:
	close_pause()
	started = false
	title_note.text = ""
	_show_title()


func _show_title() -> void:
	title_screen.visible = true
	session.clock.paused = true


## Draws what the ranger wears.
func _dress_ranger() -> void:
	var over := session.wardrobe.overlays()
	if session.festivals.overlay() != "":
		over.append(session.festivals.overlay())
	ranger.set_clothes(session.wardrobe.base_sheet(), over)


func _start_new() -> void:
	session.new_game()
	_begin()


## Playtest builds: a new game with the station shipshape and the cabin,
## outlook, pond and tower open (GameSession.debug_sites_open_start).
func _start_playtest() -> void:
	session.debug_sites_open_start()
	# Nothing from the work done for the player waits to pop up.
	job_note._waiting.clear()
	_map_changes = []
	_map_lines = PackedStringArray()
	_begin()


func _continue() -> void:
	var err := session.load_game()
	if err != "":
		title_note.text = session.content.text(err)
		return
	_begin()


func _begin() -> void:
	title_screen.visible = false
	started = true
	_on_location_changed(session.location)
	world_view.reset_chunks()


func _on_location_changed(loc: String) -> void:
	inventory_screen.close()
	town_view.visible = false
	if session.in_town_room():
		world_view.visible = false
		interior_view.visible = true
		interior_view.show_room(session.town_inside, ranger)
		camera.limit_left = -100000
		camera.limit_top = -100000
		camera.limit_right = 100000
		camera.limit_bottom = 100000
		return
	if session.in_town:
		world_view.visible = false
		interior_view.visible = false
		town_view.visible = true
		ranger.reparent(town_view.sort_root)
		camera.limit_left = 0
		camera.limit_top = 0
		camera.limit_right = session.town.size.x * TILE
		camera.limit_bottom = session.town.size.y * TILE
		return
	if loc == "":
		interior_view.visible = false
		world_view.visible = true
		ranger.reparent(world_view.sort_root)
		var b := session.world.baked_bounds()
		camera.limit_left = b.position.x * TILE
		camera.limit_top = b.position.y * TILE
		camera.limit_right = b.end.x * TILE
		camera.limit_bottom = b.end.y * TILE
		world_view.reset_chunks()
	else:
		world_view.visible = false
		interior_view.visible = true
		interior_view.show_room(loc, ranger)
		camera.limit_left = -100000
		camera.limit_top = -100000
		camera.limit_right = 100000
		camera.limit_bottom = 100000


## The name over what the ranger faces and can use: a piece of furniture
## indoors. Hidden while a screen is open.
func _update_look() -> void:
	hud.look_text = ""
	if menu_open():
		return
	if session.in_town:
		var who := session.town_person_in_reach()
		if who != "":
			hud.look_text = str(session.content.row("townsfolk", who)["name"])
			var head := interior_view.head_of(who) if session.in_town_room() else town_view.head_of(who)
			hud.look_at = world_view.get_canvas_transform() * head
			return
		if not session.in_town_room():
			return
	elif not session.is_indoors():
		return
	var f := session.furniture_in_reach()
	var label := session.furniture_label(f)
	if label == "":
		return
	var r := Rect2(Vector2(f["pos"][0], f["pos"][1]), Vector2(f["size"][0], f["size"][1]))
	var tex := Art.texture(str(f["sprite"]))
	var top := r.end.y * TILE - (tex.get_height() if tex != null else TILE)
	hud.look_text = label
	hud.look_at = world_view.get_canvas_transform() * (interior_view.position + Vector2(r.get_center().x * TILE, top))


## Turns the game menu to one of its pages, closing whichever was open.
func open_tab(id: String) -> void:
	if inventory_screen.visible:
		inventory_screen.close()
	for scr: Control in [clipboard, map_screen, social_screen, book_screen, make_sheet]:
		if scr.visible:
			scr.call("close")
	if choice_screen.visible:
		choice_screen.close()
	match id:
		"backpack":
			inventory_screen.open(null, "")
		"jobs":
			clipboard.open()
		"map":
			map_screen.open()
		"people":
			social_screen.open()
		"crafting":
			make_sheet.open("anywhere")
		"book":
			book_screen.open()


## Which game-menu page is open, and its top-left corner, for the tabs.
func _tab_page() -> Array:
	if dialog.visible or job_card.visible or pause_menu.visible or title_screen.visible:
		return []
	if inventory_screen.visible:
		return ["backpack", Sheet.FRAME.position + Vector2(24, 4)] if inventory_screen.other == null else []
	if clipboard.visible:
		return ["jobs", ClipboardScreen.FRAME.position + Vector2(24, 4)]
	if map_screen.visible:
		return ["map", Sheet.FRAME.position + Vector2(24, 4)]
	if social_screen.visible:
		return ["people", Sheet.FRAME.position + Vector2(24, 4)]
	if make_sheet.visible and make_sheet.station == "anywhere":
		return ["crafting", Sheet.FRAME.position + Vector2(24, 4)]
	if book_screen.visible:
		return ["book", Sheet.FRAME.position + Vector2(24, 4)]
	return []


func menu_open() -> bool:
	if scene_player != null and scene_player.active():
		return true
	if fortune_screen != null and fortune_screen.visible:
		return true
	return title_screen.visible or pause_menu.visible or options_panel.visible or inventory_screen.visible or map_screen.visible or dialog.visible or choice_screen.visible or make_sheet.visible or shop_sheet.visible or book_screen.visible or social_screen.visible or clipboard.visible or job_card.visible


## The speaker's portrait for the talk box: Mark's portrait in the mood
## the line calls for, or a big crop of their sprite's head until one is
## drawn. "" hides it.
func _face(person: String, mood: String) -> void:
	dialog_face.texture = null
	if person == "" or not session.content.has("townsfolk", person):
		return
	var pic := "portrait_%s_%s" % [person, mood]
	if not Art.has_picture(pic):
		pic = "portrait_%s_neutral" % person
	if Art.has_picture(pic):
		dialog_face.texture = Art.texture(pic)
		return
	var sheet := str(session.content.row("townsfolk", person).get("sprite", ""))
	if sheet != "" and Art.has_picture(sheet):
		var head := AtlasTexture.new()
		head.atlas = Art.texture(sheet)
		head.region = Rect2(0, 4, 16, 16)
		dialog_face.texture = head


func _show_dialog(kind: String, text: String) -> void:
	_dialog_kind = kind
	# A favor asked: the asker's face, pleased to ask.
	if kind.begins_with("favor:"):
		var id := kind.substr(6)
		_face(str(session.content.row("town_favors", id)["from"]) if session.content.has("town_favors", id) else "", "happy")
	elif kind == "fortune":
		_face("esme", "happy")
	elif kind != "talk" and kind != "scene":
		dialog_face.texture = null
	dialog_face.visible = dialog_face.texture != null
	var inset := 76.0 if dialog_face.visible else 8.0
	dialog_label.position.x = inset
	dialog_label.size.x = dialog.size.x - inset - 8.0
	dialog_label.text = text
	dialog.visible = true
	# Grow the box to fit the text, and keep it centred.
	var line_h := dialog_label.get_line_height() + dialog_label.get_theme_constant("line_spacing")
	var h := dialog_label.get_line_count() * line_h + 14
	dialog_label.size.y = h - 12
	dialog.size.y = maxi(76 if dialog_face.visible else 40, h)
	dialog.position.y = (VIEW.y - dialog.size.y) / 2.0


func _close_dialog(yes: bool) -> void:
	dialog.visible = false
	var kind := _dialog_kind
	_dialog_kind = ""
	if kind in ["sleep", "camp_sleep", "open_site", "rent_sign", "fortune"] or kind.begins_with("take_down:") or kind.begins_with("favor:") or kind.begins_with("friends:"):
		session.answer_confirm(yes)
	# A heart event's line was read: on to the next.
	if kind == "scene":
		scene_player.advance()
		return
	# After someone's line: a favor they'd like to ask.
	if kind == "talk" and not dialog.visible:
		session.offer_favor()
	# Esme at her caravan: a reading, once her line is read.
	if kind == "talk" and not dialog.visible:
		session.offer_reading()
	# After reading the suggestion box: pin a card that asks for something.
	if not dialog.visible and session.box_offer:
		session.offer_pins()
	# A level 5 wake-up offers the specialty once the wake-up note is read.
	if not dialog.visible and session.wake_offer:
		session.offer_specialty()


func _unhandled_input(event: InputEvent) -> void:
	# F11 switches between full screen and a window (tracker #37).
	if event.is_action_pressed("fullscreen"):
		Settings.toggle("fullscreen")
		Settings.apply_window()
		if fullscreen_button != null:
			fullscreen_button.text = session.content.text("ui_on" if Settings.flag("fullscreen") else "ui_off")
		return
	# F12 takes a picture anywhere, the title screen included.
	if event.is_action_pressed("screenshot"):
		var path := Screenshot.take(get_viewport())
		if started:
			session.message.emit(session.content.text("msg_screenshot", {"file": path.get_file()}) if path != "" else session.content.text("msg_screenshot_failed"))
		return
	if not started:
		return
	if event.is_action_pressed("debug_panel") and OS.is_debug_build():
		debug_panel.visible = not debug_panel.visible
		return
	if event.is_action_pressed("show_version"):
		session.message.emit(version_text())
		return
	if options_panel.visible:
		if event.is_action_pressed("pause"):
			close_options()
		return
	if pause_menu.visible:
		if event.is_action_pressed("pause"):
			close_pause()
		return
	# A finishing card: one key or click closes it, once the stamp has landed.
	if job_card.visible:
		if event.is_action_pressed("interact") or event.is_action_pressed("confirm") or event.is_action_pressed("cancel") or event.is_action_pressed("pause") or event.is_action_pressed("use_item"):
			job_card.try_close()
		return
	if fortune_screen.visible:
		if event.is_action_pressed("interact") or event.is_action_pressed("confirm") or event.is_action_pressed("cancel") or event.is_action_pressed("pause") or event.is_action_pressed("use_item"):
			fortune_screen.try_close()
		return
	# Tab and Shift+Tab flip between the game menu's sheets (cozy UI plan).
	if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo and (event as InputEventKey).keycode == KEY_TAB:
		var pg := _tab_page()
		if not pg.is_empty():
			var order := ["backpack", "jobs", "map", "people", "crafting", "book"]
			var d := -1 if (event as InputEventKey).shift_pressed else 1
			open_tab(order[(order.find(pg[0]) + order.size() + d) % order.size()])
			get_viewport().set_input_as_handled()
			return
	if clipboard.visible:
		clipboard.handle(event)
		return
	if make_sheet.visible and not dialog.visible:
		make_sheet.handle(event)
		return
	if shop_sheet.visible and not dialog.visible:
		shop_sheet.handle(event)
		return
	# A heart event between its lines: the scene plays on; keys wait.
	if scene_player.active() and not dialog.visible and not choice_screen.visible:
		return
	if event.is_action_pressed("pause"):
		# Escape closes whatever screen is open; with none open, it pauses.
		if dialog.visible:
			_close_dialog(false)
		elif choice_screen.visible:
			choice_screen.close()
		elif book_screen.visible:
			book_screen.close()
		elif social_screen.visible:
			social_screen.close()
		elif map_screen.visible:
			map_screen.close()
		elif inventory_screen.visible:
			inventory_screen.close()
		else:
			open_pause()
		return
	if dialog.visible:
		if _dialog_kind == "jobs" and event.is_action_pressed("jobs"):
			_close_dialog(false)
		elif event.is_action_pressed("confirm") or event.is_action_pressed("interact"):
			_close_dialog(true)
		elif event.is_action_pressed("cancel") or event.is_action_pressed("backpack"):
			_close_dialog(false)
		return
	if choice_screen.visible:
		if event.is_action_pressed("backpack") or event.is_action_pressed("cancel") or (event.is_action_pressed("craft") and choice_screen.kind == "anywhere"):
			choice_screen.close()
		return
	if book_screen.visible:
		if book_screen.handle(event):
			return
		if event.is_action_pressed("book") or event.is_action_pressed("jobs") or event.is_action_pressed("cancel") or event.is_action_pressed("backpack"):
			book_screen.close()
		return
	# The People page and calendar: Q and E turn between them.
	if social_screen.visible:
		if social_screen.handle(event):
			pass
		elif event.is_action_pressed("tab_prev") or event.is_action_pressed("tab_next"):
			social_screen.turn()
		elif event.is_action_pressed("social") or event.is_action_pressed("cancel"):
			social_screen.close()
		return
	# R: the pack, where the gear wall is (the old Ranger page's key).
	if event.is_action_pressed("character"):
		if inventory_screen.visible:
			inventory_screen.close()
		elif not menu_open():
			open_tab("backpack")
		return
	if event.is_action_pressed("social") and not menu_open():
		social_screen.open()
		return
	if event.is_action_pressed("craft") and not menu_open():
		make_sheet.open("anywhere")
		return
	if event.is_action_pressed("skills") and not menu_open():
		if not session.offer_specialty():
			_show_dialog("notice", session.content.text("ui_skills_title") + "

" + "
".join(session.skill_lines()))
		return
	if event.is_action_pressed("backpack"):
		if map_screen.visible:
			map_screen.close()
		elif inventory_screen.visible:
			inventory_screen.close()
		else:
			inventory_screen.open(null, "")
		return
	if event.is_action_pressed("jobs") and not menu_open():
		clipboard.open()
		return
	if event.is_action_pressed("book") and not menu_open():
		book_screen.open()
		return
	if event.is_action_pressed("open_map"):
		if map_screen.visible:
			map_screen.close()
		elif not inventory_screen.visible:
			map_screen.open()
		return
	if menu_open():
		return
	# A click on forage in reach picks it, whichever button (tracker #8).
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and _hover_forage.x >= 0 			and (event as InputEventMouseButton).button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		session.pick_at(_hover_forage)
		_hover_forage = Vector2i(-1, -1)
		_hover_wait = 0.0
		return
	if event.is_action_pressed("interact"):
		session.interact()
	elif event.is_action_pressed("use_item"):
		session.use_item()
	# Number keys and the wheel reach the item bar's slots.
	for i in session.bar_slots():
		if InputMap.has_action("slot_%d" % (i + 1)) and event.is_action_pressed("slot_%d" % (i + 1)):
			session.selected_slot = i
	if event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		var n := session.bar_slots()
		if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			session.selected_slot = (session.selected_slot + 1) % n
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			session.selected_slot = (session.selected_slot + n - 1) % n


## A heart event begins: its people stand beside the ranger in whichever
## view the ranger is in.
func _start_scene(id: String) -> void:
	var parent: Node2D = world_view.sort_root
	var at := session.outdoor_pos
	if session.in_town_room() or session.is_indoors():
		parent = interior_view.sort_root
		at = session.interior_pos
	elif session.in_town:
		parent = town_view.sort_root
		at = session.town_pos
	session.moving = false
	scene_player.start(id, parent, at * TILE, session.facing)


func _process(delta: float) -> void:
	# A scene's choice closed without a pick comes back: it must be answered.
	if scene_player.waiting == "choice" and not choice_screen.visible and not dialog.visible:
		var opts := []
		for i in scene_player._choice.size():
			opts.append({"id": str(i), "label": str((scene_player._choice[i] as Array)[0])})
		choice_screen.open("scene", session.content.text("scene_next"), opts)
	var page := _tab_page()
	if page.is_empty():
		menu_tabs.visible = false
	else:
		menu_tabs.show_over(page[0], page[1])
	_update_music(delta)
	if not started:
		return
	session.clock.paused = menu_open()
	# Recipes just learned: "you can make this now" (tracker #4).
	if not menu_open() and not session.recipes_new.is_empty():
		# Mark's toast card for each, top right; play goes on (cozy UI plan).
		for id: String in session.recipes_new:
			hud.show_toast(make_sheet.picture_of(id) if session.content.has("recipes", id) else "", session.content.text(session.content.row("recipes", id)["name"]))
		session.recipes_new.clear()
	# Finishing cards wait until play resumes: never over a dialog, menu,
	# sleep or a collapse. Several show one after another, then one map.
	if not menu_open() and session.pending_confirm == "":
		var c := session.jobs.take_card_to_show()
		if not c.is_empty():
			job_card.open(c)
		elif not _map_changes.is_empty():
			map_screen.open_flourish(_map_changes, " ".join(_map_lines))
			_map_changes = []
			_map_lines = PackedStringArray()
	if not menu_open():
		var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		# A hit-stop holds the ranger still; the world keeps moving.
		session.move(dir if ranger.frozen == 0 else Vector2.ZERO, delta)
		session.process(delta)
	else:
		session.moving = false
	var px := session.ranger_pos() * TILE
	ranger.motion = Settings.flag("motion")
	ranger.show_state(px, session.facing, session.moving, delta)
	_update_look()
	if session.is_indoors() or session.in_town_room():
		camera.position = interior_view.room_center_px()
	else:
		camera.position = px.round()
	camera.force_update_scroll()
	_update_world_hint(delta)
	effects.ranger_screen = ranger.get_global_transform_with_canvas().origin
	job_note.bubble_at = effects.ranger_screen
	if not session.camp.is_empty():
		var fire_px := (Vector2(session.camp["fire"]) + Vector2(0.5, 0.5)) * TILE
		effects.fire_screen = world_view.get_canvas_transform() * fire_px
	effects.glows = _night_glows()
