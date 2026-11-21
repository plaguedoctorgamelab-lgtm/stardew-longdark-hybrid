class_name KitStyle
extends RefCounted
## The ranger's kit look for every screen (docs/art/visual_direction_brief.md):
## field-book paper panels with a walnut border, wooden plank buttons, a
## routed-wood sign for the clock, a stitched patch for the wallet, wooden
## pegs for the item bar and paper tags for tooltips. Mark's Art Request 12
## pictures (ui_*) are used as 9-slice frames when they are there; plain style
## boxes in the bright palette stand in for any that are missing.

const INK := Color8(26, 22, 32)
const WOOD_DARK := Color8(93, 62, 48)
const WOOD := Color8(157, 102, 62)
const WOOD_MID := Color8(199, 144, 95)
const WOOD_LIGHT := Color8(225, 189, 142)
const CREAM := Color8(246, 224, 180)
const PAPER := Color8(252, 248, 237)
const GOLD := Color8(255, 224, 102)
const LEAF := Color8(56, 142, 76)
const PINE := Color8(40, 97, 67)
const CORAL := Color8(232, 115, 95)
## Text on paper, and text on wood or out in the world.
const TEXT_DARK := Color8(66, 44, 34)
const TEXT_LIGHT := Color8(252, 248, 237)


## A 9-slice frame from one of Mark's pictures, or null if it is not there.
## tile: repeat the middle instead of stretching it (the paper's ruled lines).
static func _art(name: String, margin: int, content: float, tile: bool = false, mod: Color = Color.WHITE) -> StyleBoxTexture:
	if not Art.has_picture(name):
		return null
	var sb := StyleBoxTexture.new()
	sb.texture = Art.texture(name)
	sb.set_texture_margin_all(margin)
	sb.set_content_margin_all(content)
	sb.modulate_color = mod
	if tile:
		sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
		sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	return sb


static func _box(bg: Color, border: Color, width: int, radius: int, margin: float = 2.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(margin)
	return sb


## Field-book paper: cream, a walnut border with a lighter rule inside it.
static func paper() -> StyleBox:
	var art := _art("ui_paper", 8, 6, true)
	if art != null:
		return art
	var sb := _box(CREAM, WOOD_DARK, 2, 2)
	sb.shadow_color = Color(INK, 0.35)
	sb.shadow_size = 2
	sb.shadow_offset = Vector2(1, 2)
	return sb


## A wooden plank button, in each of its states.
static func plank(state: String) -> StyleBox:
	# Mark's sheet has normal, hover and pressed; disabled fades the normal one.
	var art := _art("ui_button_" + ("normal" if state == "disabled" else state), 4, 2, false, Color(1, 1, 1, 0.5) if state == "disabled" else Color.WHITE)
	if art != null:
		return art
	var bg: Color = {"normal": WOOD_MID, "hover": WOOD_LIGHT, "pressed": WOOD, "disabled": Color(WOOD_LIGHT, 0.55)}.get(state, WOOD_MID)
	var sb := _box(bg, WOOD_DARK if state != "disabled" else Color(WOOD, 0.6), 1, 2)
	sb.border_width_bottom = 2
	return sb


## The routed-wood sign the clock hangs on.
static func wood_sign() -> StyleBox:
	var art := _art("ui_clock_sign", 6, 2)
	if art != null:
		return art
	var sb := _box(WOOD_DARK, INK, 1, 3)
	sb.border_width_bottom = 2
	return sb


## The wallet: a green patch with a stitched cream edge.
static func patch() -> StyleBox:
	var art := _art("ui_wallet", 4, 1)
	if art != null:
		return art
	var sb := _box(PINE, CREAM, 1, 5)
	sb.expand_margin_left = 1
	sb.expand_margin_right = 1
	return sb


## An item-bar peg: plain wood, or picked out in gold when held.
static func peg(held: bool) -> StyleBox:
	var art := _art("ui_peg_held" if held else "ui_peg", 4, 1)
	if art != null:
		return art
	return _box(WOOD_LIGHT if held else WOOD_MID, GOLD if held else WOOD_DARK, 2 if held else 1, 2, 1)


## A paper luggage tag for hover hints.
static func tag() -> StyleBox:
	var art := _art("ui_tag", 4, 2)
	if art != null:
		# The string hole is on the left: keep the words clear of it.
		art.texture_margin_left = 8
		art.content_margin_left = 9
		art.content_margin_right = 6
		return art
	return _box(PAPER, WOOD, 1, 3)


## A book tab: the open page's, or the others'.
static func tab(open: bool) -> StyleBox:
	var art := _art("ui_tab_open" if open else "ui_tab", 4, 2)
	if art != null:
		return art
	return plank("hover" if open else "normal")


## The theme every screen shares.
static func theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 8
	t.set_stylebox("panel", "Panel", paper())
	t.set_stylebox("panel", "PanelContainer", paper())
	t.set_stylebox("panel", "PopupPanel", paper())
	t.set_stylebox("panel", "TooltipPanel", tag())
	t.set_color("font_color", "TooltipLabel", TEXT_DARK)
	t.set_color("font_color", "Label", TEXT_DARK)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		t.set_stylebox(state, "Button", plank("normal" if state == "focus" else state))
		t.set_stylebox(state, "OptionButton", plank("normal" if state == "focus" else state))
	for k in ["font_color", "font_focus_color"]:
		t.set_color(k, "Button", TEXT_DARK)
		t.set_color(k, "OptionButton", TEXT_DARK)
	for k in ["font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		t.set_color(k, "Button", INK)
		t.set_color(k, "OptionButton", INK)
	t.set_color("font_disabled_color", "Button", Color(TEXT_DARK, 0.5))
	t.set_color("font_color", "CheckBox", TEXT_DARK)
	t.set_stylebox("normal", "LineEdit", _box(PAPER, WOOD, 1, 1))
	t.set_color("font_color", "LineEdit", TEXT_DARK)
	return t


## Mark's wooden frame (Art Request 16) round a panel, as the jobs
## clipboard has: drawn behind the panel's paper and a little outside it.
## Nothing is added if the picture is missing.
static func frame(panel: Control, out: float = 7.0) -> void:
	if not Art.has_picture("ui_wood_frame") or panel.has_node("WoodFrame"):
		return
	var f := NinePatchRect.new()
	f.name = "WoodFrame"
	f.texture = Art.texture("ui_wood_frame")
	f.patch_margin_left = 10
	f.patch_margin_right = 10
	f.patch_margin_top = 10
	f.patch_margin_bottom = 10
	f.draw_center = false
	f.show_behind_parent = true
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	f.set_anchors_preset(Control.PRESET_FULL_RECT)
	f.offset_left = -out
	f.offset_top = -out
	f.offset_right = out
	f.offset_bottom = out
	panel.add_child(f)


## A small tab icon (Art Request 16: backpack, chest, shelf, book, ledger,
## options) to sit before a title, or null if the picture is missing.
static func tab_icon(kind: String) -> TextureRect:
	if not Art.has_picture("ui_tab_" + kind):
		return null
	var r := TextureRect.new()
	r.texture = Art.texture("ui_tab_" + kind)
	r.size = Vector2(12, 12)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## Light words with a dark edge, for labels drawn over the world.
static func over_world(l: Label) -> void:
	l.add_theme_color_override("font_color", TEXT_LIGHT)
	l.add_theme_color_override("font_outline_color", INK)
	l.add_theme_constant_override("outline_size", 3)
