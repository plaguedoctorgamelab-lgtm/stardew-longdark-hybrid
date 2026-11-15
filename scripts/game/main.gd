extends Node
## The running game. Builds the session and the views, reads input through the
## input map by action name, and keeps the camera on the ranger.

const TILE := 16

var session: GameSession
var world_view: WorldView
var interior_view: InteriorView
var ranger: RangerSprite
var camera: Camera2D
var effects: ScreenEffects
var hud: Hud
var menus: CanvasLayer
var ui_theme: Theme
var inventory_screen: InventoryScreen
var map_screen: MapScreen
var debug_panel: DebugPanel
var dialog: Panel
var dialog_label: Label
var title_screen: Panel
var title_note: Label
var _dialog_kind: String = ""
var started: bool = false


func _ready() -> void:
	ui_theme = _make_theme()
	session = GameSession.new()
	ranger = RangerSprite.new()
	world_view = WorldView.new()
	add_child(world_view)
	world_view.setup(session, ranger)
	interior_view = InteriorView.new()
	interior_view.visible = false
	add_child(interior_view)
	interior_view.setup(session)
	camera = Camera2D.new()
	add_child(camera)
	camera.make_current()
	effects = ScreenEffects.new()
	add_child(effects)
	effects.setup(session)
	hud = Hud.new()
	add_child(hud)
	hud.setup(session, ui_theme)
	_build_menus()

	session.location_changed.connect(_on_location_changed)
	session.storage_opened.connect(func(title: String, inv: Inventory) -> void: inventory_screen.open(inv, title))
	session.radio_heard.connect(func(lines: PackedStringArray) -> void: _show_dialog("radio", "\n".join(lines)))
	session.confirm_requested.connect(func(kind: String, text: String) -> void: _show_dialog(kind, text))
	session.structures.changed.connect(func(_id: String) -> void:
		if interior_view.visible:
			interior_view.refresh())
	session.collapsed.connect(func(text: String) -> void: _show_dialog("notice", text))
	_show_title()


func _make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 8
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.16, 0.12, 0.1, 0.92)
	panel.border_color = Color(0.55, 0.4, 0.25)
	panel.set_border_width_all(1)
	t.set_stylebox("panel", "Panel", panel)
	var btn := StyleBoxFlat.new()
	btn.bg_color = Color(0.3, 0.22, 0.16)
	btn.set_content_margin_all(2)
	t.set_stylebox("normal", "Button", btn)
	var hov := btn.duplicate()
	hov.bg_color = Color(0.42, 0.32, 0.22)
	t.set_stylebox("hover", "Button", hov)
	t.set_stylebox("pressed", "Button", hov)
	return t


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
	dialog = Panel.new()
	dialog.size = Vector2(260, 70)
	dialog.position = Vector2(110, 90)
	dialog.visible = false
	root.add_child(dialog)
	dialog_label = Label.new()
	dialog_label.position = Vector2(8, 6)
	dialog_label.size = Vector2(244, 58)
	dialog_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	dialog.add_child(dialog_label)
	debug_panel = DebugPanel.new()
	root.add_child(debug_panel)
	debug_panel.setup(session)
	debug_panel.on_teleport = func() -> void:
		_on_location_changed(session.location)
		world_view.reset_chunks()
	title_screen = Panel.new()
	title_screen.size = Vector2(480, 270)
	root.add_child(title_screen)
	var tl := Label.new()
	tl.text = session.content.text("ui_title")
	tl.position = Vector2(200, 80)
	title_screen.add_child(tl)
	var y := 110
	for pair in [["ui_new_game", _start_new], ["ui_continue", _continue], ["ui_quit", func() -> void: get_tree().quit()]]:
		var b := Button.new()
		b.text = session.content.text(pair[0])
		b.position = Vector2(200, y)
		b.size = Vector2(80, 14)
		b.pressed.connect(pair[1])
		title_screen.add_child(b)
		y += 18
	title_note = Label.new()
	title_note.position = Vector2(120, 170)
	title_note.size = Vector2(240, 40)
	title_note.autowrap_mode = TextServer.AUTOWRAP_WORD
	title_screen.add_child(title_note)


func _show_title() -> void:
	title_screen.visible = true
	session.clock.paused = true


func _start_new() -> void:
	session.new_game()
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
	if loc == "":
		interior_view.visible = false
		world_view.visible = true
		ranger.reparent(world_view.sort_root)
		var limit := Vector2i(session.world.width, session.world.height) * TILE
		camera.limit_left = 0
		camera.limit_top = 0
		camera.limit_right = limit.x
		camera.limit_bottom = limit.y
		world_view.reset_chunks()
	else:
		world_view.visible = false
		interior_view.visible = true
		interior_view.show_room(loc, ranger)
		camera.limit_left = -100000
		camera.limit_top = -100000
		camera.limit_right = 100000
		camera.limit_bottom = 100000


func menu_open() -> bool:
	return title_screen.visible or inventory_screen.visible or map_screen.visible or dialog.visible


func _show_dialog(kind: String, text: String) -> void:
	_dialog_kind = kind
	dialog_label.text = text
	dialog.visible = true


func _close_dialog(yes: bool) -> void:
	dialog.visible = false
	if _dialog_kind == "sleep":
		session.answer_confirm(yes)
	_dialog_kind = ""


func _unhandled_input(event: InputEvent) -> void:
	if not started:
		return
	if event.is_action_pressed("debug_panel") and OS.is_debug_build():
		debug_panel.visible = not debug_panel.visible
		return
	if dialog.visible:
		if event.is_action_pressed("confirm") or event.is_action_pressed("interact"):
			_close_dialog(true)
		elif event.is_action_pressed("cancel") or event.is_action_pressed("backpack"):
			_close_dialog(false)
		return
	if event.is_action_pressed("backpack"):
		if map_screen.visible:
			map_screen.close()
		elif inventory_screen.visible:
			inventory_screen.close()
		else:
			inventory_screen.open(null, "")
		return
	if event.is_action_pressed("open_map"):
		if map_screen.visible:
			map_screen.close()
		elif not inventory_screen.visible:
			map_screen.open()
		return
	if menu_open():
		return
	if event.is_action_pressed("interact"):
		session.interact()
	elif event.is_action_pressed("use_item"):
		session.use_item()
	for i in session.backpack.size():
		if event.is_action_pressed("slot_%d" % (i + 1)):
			session.selected_slot = i
	if event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		var n := session.backpack.size()
		if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			session.selected_slot = (session.selected_slot + 1) % n
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			session.selected_slot = (session.selected_slot + n - 1) % n


func _process(delta: float) -> void:
	if not started:
		return
	session.clock.paused = menu_open()
	if not menu_open():
		var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		session.move(dir, delta)
		session.process(delta)
	else:
		session.moving = false
	var px := session.ranger_pos() * TILE
	ranger.show_state(px, session.facing, session.moving, delta)
	if session.is_indoors():
		camera.position = interior_view.room_center_px()
	else:
		camera.position = px.round()
	camera.force_update_scroll()
	effects.ranger_screen = ranger.get_global_transform_with_canvas().origin
