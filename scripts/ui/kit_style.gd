class_name KitStyle
extends RefCounted
## The ranger's kit look for every screen (docs/art/visual_direction_brief.md):
## field-book paper panels with a walnut border, wooden plank buttons, a
## routed-wood sign for the clock, a stitched patch for the wallet, wooden
## pegs for the item bar and paper tags for tooltips. Drawn from the game's
## bright palette as stand-ins (plain style boxes) until Art Request 12's
## frames arrive, when these become 9-slice textures.

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


static func _box(bg: Color, border: Color, width: int, radius: int, margin: float = 2.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(margin)
	return sb


## Field-book paper: cream, a walnut border with a lighter rule inside it.
static func paper() -> StyleBoxFlat:
	var sb := _box(CREAM, WOOD_DARK, 2, 2)
	sb.shadow_color = Color(INK, 0.35)
	sb.shadow_size = 2
	sb.shadow_offset = Vector2(1, 2)
	return sb


## A wooden plank button, in each of its states.
static func plank(state: String) -> StyleBoxFlat:
	var bg: Color = {"normal": WOOD_MID, "hover": WOOD_LIGHT, "pressed": WOOD, "disabled": Color(WOOD_LIGHT, 0.55)}.get(state, WOOD_MID)
	var sb := _box(bg, WOOD_DARK if state != "disabled" else Color(WOOD, 0.6), 1, 2)
	sb.border_width_bottom = 2
	return sb


## The routed-wood sign the clock hangs on.
static func wood_sign() -> StyleBoxFlat:
	var sb := _box(WOOD_DARK, INK, 1, 3)
	sb.border_width_bottom = 2
	return sb


## The wallet: a green patch with a stitched cream edge.
static func patch() -> StyleBoxFlat:
	var sb := _box(PINE, CREAM, 1, 5)
	sb.expand_margin_left = 1
	sb.expand_margin_right = 1
	return sb


## An item-bar peg: plain wood, or picked out in gold when held.
static func peg(held: bool) -> StyleBoxFlat:
	return _box(WOOD_LIGHT if held else WOOD_MID, GOLD if held else WOOD_DARK, 2 if held else 1, 2, 1)


## A paper luggage tag for hover hints.
static func tag() -> StyleBoxFlat:
	return _box(PAPER, WOOD, 1, 3)


## The theme every screen shares.
static func theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 8
	t.set_stylebox("panel", "Panel", paper())
	t.set_stylebox("panel", "PanelContainer", paper())
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


## Light words with a dark edge, for labels drawn over the world.
static func over_world(l: Label) -> void:
	l.add_theme_color_override("font_color", TEXT_LIGHT)
	l.add_theme_color_override("font_outline_color", INK)
	l.add_theme_constant_override("outline_size", 3)
