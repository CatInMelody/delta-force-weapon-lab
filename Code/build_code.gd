extends Control

const DEFAULT_SAVE_PATH := "user://weapon_build_codes.json"

var save_path := DEFAULT_SAVE_PATH
var weapon_codes: Dictionary = {}
var current_weapon_id := ""
var current_weapon_name := ""
var dirty := false
var storage_readable := true
var applying_weapon := false

@onready var text_a: LineEdit = $Margin/Column/PlanA/Input/TextA
@onready var text_b: LineEdit = $Margin/Column/PlanB/Input/TextB
@onready var text_c: LineEdit = $Margin/Column/PlanC/Input/TextC
@onready var title_a: LineEdit = $Margin/Column/PlanA/Title
@onready var title_b: LineEdit = $Margin/Column/PlanB/Title
@onready var title_c: LineEdit = $Margin/Column/PlanC/Title
@onready var button_a: Button = $Margin/Column/PlanA/Input/ButtonA
@onready var button_b: Button = $Margin/Column/PlanB/Input/ButtonB
@onready var button_c: Button = $Margin/Column/PlanC/Input/ButtonC
@onready var save_timer: Timer = $SaveTimer
@onready var save_status: Label = $Margin/Column/SaveStatus
@onready var choose: Control = $"../Chosse"


func _ready() -> void:
	save_status.tooltip_text = ProjectSettings.globalize_path(save_path)
	_load_codes()
	button_a.pressed.connect(_copy_text.bind(text_a))
	button_b.pressed.connect(_copy_text.bind(text_b))
	button_c.pressed.connect(_copy_text.bind(text_c))
	text_a.text_changed.connect(_on_text_changed)
	text_b.text_changed.connect(_on_text_changed)
	text_c.text_changed.connect(_on_text_changed)
	text_a.focus_exited.connect(_save_codes)
	text_b.focus_exited.connect(_save_codes)
	text_c.focus_exited.connect(_save_codes)
	for title in [title_a, title_b, title_c]:
		title.text_changed.connect(_on_text_changed)
		title.focus_exited.connect(_save_codes)
		title.text_submitted.connect(_finish_title_edit.bind(title))
	save_timer.timeout.connect(_save_codes)
	choose.weapon_changed.connect(_on_weapon_changed)
	_on_weapon_changed(choose.selected_weapon)


func _on_weapon_changed(weapon: Dictionary) -> void:
	if weapon.is_empty():
		return
	_save_codes()
	current_weapon_id = str(weapon["weapon_id"])
	current_weapon_name = str(weapon["name"])
	$Margin/Column/CurrentWeapon.text = current_weapon_name + " 的专属方案"
	var codes: Dictionary = weapon_codes.get(current_weapon_id, {})
	applying_weapon = true
	text_a.text = str(codes.get("a", ""))
	text_b.text = str(codes.get("b", ""))
	text_c.text = str(codes.get("c", ""))
	title_a.text = str(codes.get("title_a", "方案 A"))
	title_b.text = str(codes.get("title_b", "方案 B"))
	title_c.text = str(codes.get("title_c", "方案 C"))
	applying_weapon = false
	text_a.tooltip_text = current_weapon_name + " 的方案A"
	text_b.tooltip_text = current_weapon_name + " 的方案B"
	text_c.tooltip_text = current_weapon_name + " 的方案C"
	_update_buttons()


func _copy_text(field: LineEdit) -> void:
	if not field.text.is_empty():
		DisplayServer.clipboard_set(field.text)


func _finish_title_edit(_text: String, field: LineEdit) -> void:
	field.release_focus()
	_save_codes()


func _on_text_changed(_text: String) -> void:
	_update_buttons()
	if applying_weapon or current_weapon_id.is_empty():
		return
	weapon_codes[current_weapon_id] = {"name": current_weapon_name, "a": text_a.text, "b": text_b.text, "c": text_c.text, "title_a": title_a.text, "title_b": title_b.text, "title_c": title_c.text}
	dirty = true
	if storage_readable:
		_set_status("正在保存…")
		save_timer.start()


func _update_buttons() -> void:
	button_a.disabled = text_a.text.is_empty()
	button_b.disabled = text_b.text.is_empty()
	button_c.disabled = text_c.text.is_empty()


func _load_codes() -> void:
	if not FileAccess.file_exists(save_path):
		return
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		storage_readable = false
		_set_status("方案读取失败，未覆盖原存档", true)
		return
	var parser := JSON.new()
	var parse_error := parser.parse(file.get_as_text())
	file.close()
	var data = parser.data
	if parse_error != OK or not data is Dictionary or data.get("schema_version", 0) != 1 or not data.get("weapons") is Dictionary:
		storage_readable = false
		_set_status("方案存档格式错误，未覆盖原存档", true)
		return
	for entry in data["weapons"].values():
		if not entry is Dictionary or not entry.get("a") is String or not entry.get("b") is String:
			storage_readable = false
			_set_status("方案存档格式错误，未覆盖原存档", true)
			return
		# 旧 A/B 存档没有 c 字段，按空方案 C 读取。
		if entry.has("c") and not entry["c"] is String:
			storage_readable = false
			_set_status("方案存档格式错误，未覆盖原存档", true)
			return
		# 标题为可选字段，旧方案存档仍显示默认标题。
		for key in ["title_a", "title_b", "title_c"]:
			if entry.has(key) and not entry[key] is String:
				storage_readable = false
				_set_status("方案存档格式错误，未覆盖原存档", true)
				return
	weapon_codes = data["weapons"]
	_set_status("已载入本机方案")


func _save_codes() -> void:
	if not dirty or not storage_readable:
		return
	# 先写临时文件再替换，避免写入中断留下半份存档。
	var temporary_path := save_path + ".tmp"
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		_set_status("方案保存失败，请检查存储目录", true)
		return
	file.store_string(JSON.stringify({"schema_version": 1, "weapons": weapon_codes}, "\t"))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK or DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary_path), ProjectSettings.globalize_path(save_path)) != OK:
		_set_status("方案保存失败，请检查存储目录", true)
		return
	dirty = false
	save_timer.stop()
	_set_status("已保存到本机")


func _set_status(message: String, failed: bool = false) -> void:
	if is_instance_valid(save_status):
		save_status.text = message
		save_status.add_theme_color_override("font_color", Color("ff5c5c") if failed else Color("abb9c7"))


func _exit_tree() -> void:
	_save_codes()
