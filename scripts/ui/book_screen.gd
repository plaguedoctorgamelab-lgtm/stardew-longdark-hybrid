class_name BookScreen
extends Panel
## The ranger's book, on J: the job list and sites, the park today, the
## ledger, the suggestion cards read, the Chief's letters, the notebook and
## the badges earned.
## One page at a time, picked with the buttons along the top.

var session: GameSession
var page: String = "jobs"
var _tabs: HBoxContainer
var _text: Label
var _scroll: ScrollContainer
const PAGES: Array[String] = ["jobs", "park", "ledger", "cards", "letters", "notes", "badges"]
var _badges: BadgesView


func setup(s: GameSession) -> void:
	session = s
	size = Vector2(380, 236)
	position = ((Vector2(480, 270) - size) / 2.0).round()
	_tabs = HBoxContainer.new()
	_tabs.position = Vector2(6, 4)
	_tabs.add_theme_constant_override("separation", 2)
	add_child(_tabs)
	for pg in PAGES:
		var b := Button.new()
		b.text = s.content.text("book_" + pg)
		b.focus_mode = Control.FOCUS_NONE
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
		"jobs":
			var out := PackedStringArray([c.text("next_title")])
			var nxt := session.guide.next_steps()
			out.append_array(nxt if not nxt.is_empty() else PackedStringArray([c.text("next_none")]))
			out.append_array(PackedStringArray(["", c.text("job_list_title"), ""]))
			out.append_array(session.job_lines())
			out.append("")
			out.append_array(session.site_lines())
			return out
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
		(_tabs.get_child(i) as Button).modulate = Color(1.4, 1.3, 0.8) if PAGES[i] == pg else Color.WHITE
