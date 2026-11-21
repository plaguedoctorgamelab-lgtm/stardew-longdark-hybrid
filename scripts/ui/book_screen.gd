class_name BookScreen
extends Panel
## The ranger's book, on B: the park today, the
## ledger, the suggestion cards read, the Chief's letters, the notebook and
## the badges earned.
## One page at a time, picked with the buttons along the top.

var session: GameSession
var page: String = "park"
var _tabs: HBoxContainer
var _text: Label
var _scroll: ScrollContainer
const PAGES: Array[String] = ["park", "ledger", "cards", "letters", "notes", "badges"]
var _badges: BadgesView


func setup(s: GameSession) -> void:
	session = s
	size = Vector2(380, 236)
	position = ((Vector2(480, 270) - size) / 2.0).round()
	KitStyle.frame(self)
	_tabs = HBoxContainer.new()
	_tabs.position = Vector2(6, 4)
	_tabs.add_theme_constant_override("separation", 2)
	add_child(_tabs)
	for pg in PAGES:
		var b := Button.new()
		b.text = s.content.text("book_" + pg)
		b.focus_mode = Control.FOCUS_NONE
		# Mark's tab pictures (Art Request 16) where there is one.
		var icon_kind: String = {"park": "book", "ledger": "ledger"}.get(pg, "")
		if icon_kind != "" and Art.has_picture("ui_tab_" + icon_kind):
			b.icon = Art.texture("ui_tab_" + icon_kind)
			b.expand_icon = false
		b.pressed.connect(func() -> void: show_page(pg))
		_tabs.add_child(b)
	_scroll = ScrollContainer.new()
	_scroll.position = Vector2(6, 22)
	_scroll.size = Vector2(size.x - 12, size.y - 38)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	var col := VBoxContainer.new()
	_scroll.add_child(col)
	_text = Label.new()
	_text.custom_minimum_size = Vector2(size.x - 24, 0)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD
	col.add_child(_text)
	_badges = BadgesView.new()
	col.add_child(_badges)
	_badges.setup(s, size.x - 24)
	var hint := Label.new()
	hint.text = s.content.text("book_hint")
	hint.position = Vector2(6, size.y - 14)
	hint.modulate = Color(1, 1, 1, 0.7)
	add_child(hint)
	visible = false


func open(pg: String = "") -> void:
	visible = true
	show_page(pg if pg != "" else page)


func close() -> void:
	visible = false


func lines_for(pg: String) -> PackedStringArray:
	var c := session.content
	match pg:
		"park":
			return session.park.park_lines()
		"ledger":
			return session.park.ledger_lines()
		"cards":
			return session.park.card_lines()
		"letters":
			return session.park.letter_lines()
		"notes":
			return session.park.note_lines()
	return PackedStringArray()


func show_page(pg: String) -> void:
	page = pg
	_text.text = "\n".join(lines_for(pg))
	_text.visible = pg != "badges"
	_badges.visible = pg == "badges"
	if _badges.visible:
		_badges.refresh()
	_scroll.scroll_vertical = 0
	for i in PAGES.size():
		var b := _tabs.get_child(i) as Button
		var open := PAGES[i] == pg
		for state in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(state, KitStyle.tab(open))
		for k in ["font_color", "font_hover_color", "font_pressed_color"]:
			b.add_theme_color_override(k, KitStyle.TEXT_LIGHT)
		b.add_theme_color_override("font_outline_color", KitStyle.INK)
		b.add_theme_constant_override("outline_size", 2)
		b.modulate = Color.WHITE if open else Color(0.88, 0.88, 0.88)
