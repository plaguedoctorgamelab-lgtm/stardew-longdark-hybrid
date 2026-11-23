class_name MenuTabs
extends Control
## The game menu's tabs (0.7.9): a row of picture tabs along the top edge of
## whichever menu page is open (backpack, ranger, jobs, map, people,
## crafting, book). Click one to turn to that page; each tab also has its
## key. The open page's tab stands up a little, as a folder tab does.

signal chosen(id: String)

## [id, picture, text id]. The picture is the first of a list found.
const TABS := [
	["backpack", ["ui_tab_backpack", "item_backpack"], "menu_tab_backpack"],
	["ranger", ["ui_tab_ranger", "item_ranger_hat"], "menu_tab_ranger"],
	["jobs", ["ui_tab_jobs", "ui_tab_ledger"], "menu_tab_jobs"],
	["map", ["ui_tab_map", "item_map"], "menu_tab_map"],
	["people", ["ui_tab_people", "ui_heart_full"], "menu_tab_people"],
	["crafting", ["ui_tab_crafting", "item_hammer"], "menu_tab_crafting"],
	["book", ["ui_tab_book"], "menu_tab_book"],
]
const TAB := Vector2(26, 20)
const GAP := 2.0

var current: String = ""
var _buttons: Dictionary = {}   # id -> Button


func setup(c: ContentDB) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(TABS.size() * (TAB.x + GAP), TAB.y + 3)
	var x := 0.0
	for t: Array in TABS:
		var b := Button.new()
		b.size = TAB
		b.position = Vector2(x, 3)
		b.focus_mode = Control.FOCUS_NONE
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.tooltip_text = c.text(t[2])
		for pic: String in t[1]:
			if Art.has_picture(pic):
				b.icon = Art.texture(pic)
				break
		b.add_theme_constant_override("icon_max_width", 14)
		b.pressed.connect(func() -> void: chosen.emit(str(t[0])))
		add_child(b)
		_buttons[t[0]] = b
		x += TAB.x + GAP
	visible = false


static func _tab_style(open: bool) -> StyleBox:
	var sb: StyleBox = KitStyle._art("ui_tab_open" if open else "ui_tab", 5, 3)
	if sb == null:
		sb = KitStyle._box(KitStyle.CREAM if open else KitStyle.WOOD_LIGHT, KitStyle.WOOD_DARK, 2, 2)
	return sb


## Shows the tabs over a page whose top-left corner is `at`.
func show_over(id: String, at: Vector2) -> void:
	position = (at - Vector2(-6, size.y - 2)).round()
	position.y = maxf(0.0, position.y)
	position.x = clampf(position.x, 0.0, 480.0 - size.x)
	if id != current:
		current = id
		for k: String in _buttons:
			var b: Button = _buttons[k]
			var open := k == id
			b.position.y = 0.0 if open else 3.0
			for st in ["normal", "hover", "pressed", "focus", "disabled"]:
				b.add_theme_stylebox_override(st, _tab_style(open or st == "hover"))
	visible = true
