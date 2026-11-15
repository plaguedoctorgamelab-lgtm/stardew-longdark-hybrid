class_name ChoiceScreen
extends Panel
## A short list to pick from with the mouse: the workbench's recipes, or the
## place a sign should name. The workbench stays open so several things can
## be made; a single choice closes the list.

signal chosen(kind: String, option_id: String)

var session: GameSession
var kind: String = ""
var title_label: Label
var hint_label: Label
var list: VBoxContainer
var _stay_open: bool = false


func setup(s: GameSession) -> void:
	session = s
	size = Vector2(300, 150)
	position = (Vector2(480, 270) - size) / 2.0
	title_label = Label.new()
	title_label.position = Vector2(8, 4)
	add_child(title_label)
	hint_label = Label.new()
	hint_label.position = Vector2(8, size.y - 14)
	hint_label.text = s.content.text("ui_close_hint")
	add_child(hint_label)
	list = VBoxContainer.new()
	list.position = Vector2(8, 18)
	list.size = Vector2(size.x - 16, size.y - 36)
	list.add_theme_constant_override("separation", 2)
	add_child(list)
	visible = false


## options: [{"id", "label"}]
func open(choice_kind: String, title: String, options: Array, stay_open: bool = false) -> void:
	kind = choice_kind
	_stay_open = stay_open
	title_label.text = title
	hint_label.text = session.content.text("ui_craft_hint" if stay_open else "ui_close_hint")
	_fill(options)
	visible = true


func _fill(options: Array) -> void:
	for c in list.get_children():
		c.queue_free()
	for o: Dictionary in options:
		var b := Button.new()
		b.text = str(o["label"])
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.disabled = not bool(o.get("enabled", true))
		var id: String = o["id"]
		b.pressed.connect(func() -> void: _pick(id))
		list.add_child(b)


func _pick(option_id: String) -> void:
	chosen.emit(kind, option_id)
	if not _stay_open:
		visible = false


## Shows the workbench's recipes, greyed when the backpack lacks what they need.
func open_workbench() -> void:
	open("workbench", session.content.text("ui_workbench"), _recipe_options(), true)


func _recipe_options() -> Array:
	var out := []
	for r: Dictionary in session.recipes_at("workbench"):
		out.append({"id": r["id"], "label": session.recipe_line(r["id"]), "enabled": session.recipe_status(r["id"])["can"]})
	return out


func refresh() -> void:
	if visible and kind == "workbench":
		_fill(_recipe_options())


func close() -> void:
	if visible and not _stay_open:
		chosen.emit(kind, "")
	visible = false
