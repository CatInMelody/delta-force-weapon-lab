extends Control
## 四个菜单按钮共用面板切换，返回信息页时保留当前装备选择。

const DataStore = preload("res://Code/data_store.gd")

const PAGES := ["Information", "Compare", "Rank", "Update"]


func _enter_tree() -> void:
	DataStore.reset_cache()


func _ready() -> void:
	for page in PAGES:
		var button: Button = get_node("Menu/" + page)
		button.toggle_mode = true
		button.pressed.connect(_show_page.bind(page))
	_show_page("Information")


func _show_page(selected: String) -> void:
	for page in PAGES:
		get_node(NodePath(page)).visible = page == selected
		var button: Button = get_node("Menu/" + page)
		button.set_pressed_no_signal(page == selected)
