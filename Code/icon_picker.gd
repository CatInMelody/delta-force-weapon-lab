extends Control

const DataStore = preload("res://Code/data_store.gd")
## 共用图标选择弹层；滚轮交给 ScrollContainer，点击空白或 Esc 关闭。

signal item_selected(kind: String, item: Dictionary)

var current_kind := ""
var items: Array[Dictionary] = []
var all_items: Array[Dictionary] = []
var category_buttons: Dictionary = {}
var current_category := "AR"
var selected_item_id := ""
var panel: PanelContainer
var title: Label
var scroll: ScrollContainer
var grid: GridContainer
var previous_focus: Control
var selected_button: Button
var opening: Tween

@onready var pointer: Node2D = $Pointer


func _ready() -> void:
	panel = $Panel
	title = $Panel/Margin/Content/Header/Title
	scroll = $Panel/Margin/Content/Scroll
	grid = $Panel/Margin/Content/Scroll/Grid
	for category in ["AR", "SMG", "LMG", "DMR", "SR"]:
		var button: Button = get_node("Panel/Margin/Content/Categories/" + category)
		category_buttons[category] = button
		button.pressed.connect(_select_category.bind(category))
	$Panel/Margin/Content/Header/Close.pressed.connect(close_picker)
	gui_input.connect(_on_backdrop_input)
	get_viewport().size_changed.connect(close_picker)
	hide()


func open_picker(kind: String, choices: Array[Dictionary], selected_id: String, anchor: Rect2) -> void:
	if visible and current_kind == kind:
		close_picker()
		return
	previous_focus = get_viewport().gui_get_focus_owner()
	current_kind = kind
	all_items = choices
	selected_item_id = selected_id
	$Panel/Margin/Content/Categories.visible = kind == "weapon"
	if kind == "weapon":
		current_category = "AR"
		for item in all_items:
			if str(item["id"]) == selected_id:
				current_category = str(item.get("category", "AR"))
				break
	title.text = {"weapon": "选择武器", "bullet": "选择弹种与等级", "helmet": "选择头盔", "armor": "选择护甲"}.get(kind, "选择")
	_rebuild_items()
	var viewport_size := get_viewport_rect().size
	grid.columns = 3 if viewport_size.x >= 540 else 2
	_place_below(anchor, viewport_size)
	show()
	if opening != null and opening.is_valid():
		opening.kill()
	modulate.a = 0.0
	opening = create_tween()
	opening.tween_property(self, "modulate:a", 1.0, 0.1)
	_focus_selection.call_deferred()


func _place_below(anchor: Rect2, viewport_size: Vector2) -> void:
	const MARGIN := 12.0
	const GAP := 10.0
	var below := viewport_size.y - MARGIN - anchor.end.y - GAP
	var above := anchor.position.y - MARGIN - GAP
	var minimum_height := 260.0 if current_kind == "weapon" else 220.0
	var use_below := below >= minimum_height or below >= above
	var room := below if use_below else above
	panel.size = Vector2(minf(536, viewport_size.x - MARGIN * 2), minf(432, maxf(minimum_height, room)))
	var x := clampf(anchor.get_center().x - panel.size.x * 0.5, MARGIN, maxf(MARGIN, viewport_size.x - panel.size.x - MARGIN))
	var y := anchor.end.y + GAP if use_below else anchor.position.y - GAP - panel.size.y
	panel.position = Vector2(x, clampf(y, MARGIN, maxf(MARGIN, viewport_size.y - panel.size.y - MARGIN)))
	pointer.position = Vector2(clampf(anchor.get_center().x, x + 20, x + panel.size.x - 20), panel.position.y if use_below else panel.position.y + panel.size.y)
	pointer.rotation = 0.0 if use_below else PI


func _select_category(category: String) -> void:
	current_category = category
	_rebuild_items()
	_focus_selection.call_deferred()


func _rebuild_items() -> void:
	items = []
	for item in all_items:
		if current_kind != "weapon" or item.get("category", "") == current_category:
			items.append(item)
	for category in category_buttons:
		category_buttons[category].set_pressed_no_signal(category == current_category)
	if current_kind == "weapon":
		title.text = "选择武器 · %s（%d）" % [category_buttons[current_category].text, items.size()]
	selected_button = null
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	for item in items:
		var card := _make_card(item, str(item["id"]) == selected_item_id)
		grid.add_child(card)
		if str(item["id"]) == selected_item_id:
			selected_button = card
	scroll.scroll_vertical = 0


func _focus_selection() -> void:
	var button := selected_button
	# Grid 和 ScrollContainer 需要跨帧完成最小尺寸、滚动范围的更新。
	await get_tree().process_frame
	await get_tree().process_frame
	if visible and is_instance_valid(button) and button == selected_button:
		button.grab_focus()


func close_picker() -> void:
	if not visible:
		return
	hide()
	if opening != null and opening.is_valid():
		opening.kill()
	modulate.a = 1.0
	if is_instance_valid(previous_focus):
		previous_focus.grab_focus()


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close_picker()
		get_viewport().set_input_as_handled()


func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close_picker()
		accept_event()


func _make_card(item: Dictionary, selected: bool) -> Button:
	var card: Button = preload("res://Scene/icon_picker_card.tscn").instantiate()
	card.tooltip_text = item.get("tooltip", item["name"] + "\n" + item.get("detail", ""))
	if selected:
		card.add_theme_stylebox_override("normal", card.get_theme_stylebox("focus"))
	card.get_node("Selected").visible = selected
	var picture: TextureRect = card.get_node("Image")
	picture.texture = DataStore.load_texture(item["icon"])
	if item.has("background"):
		var background: TextureRect = card.get_node("Background")
		background.texture = DataStore.load_texture(item["background"])
		background.show()
		picture.position = Vector2(42, 11)
		picture.size = Vector2(64, 64)
	card.get_node("Caption").text = item["name"] if current_kind == "weapon" else item["name"] + "\n" + item.get("detail", "")
	card.pressed.connect(func() -> void:
		close_picker()
		item_selected.emit(current_kind, item)
	)
	return card
