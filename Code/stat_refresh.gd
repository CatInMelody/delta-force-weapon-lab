extends Control
## 每个发生数字变化的 Label 各有一条光带和独立的 0.3 秒动画。

const MASK_SHADER = preload("res://assets/UI/stat_refresh_mask.gdshader")

@export_range(0.1, 1.0, 0.05) var duration := 0.3

var running := false
var progress := 0.0
var initialized := false
var active: Array[Dictionary] = []

@onready var shine: ColorRect = $Shine


func _ready() -> void:
	shine.hide()
	get_viewport().size_changed.connect(_clear)


func apply_updates(updates: Array) -> void:
	var animate := initialized
	initialized = true
	for update in updates:
		var label: Label = update["label"]
		var current := _entry_for(label)
		if label.text != update["text"]:
			if not current.is_empty():
				_finish_entry(current)
			if animate and label.is_visible_in_tree():
				_start_entry(label)
			label.text = update["text"]
		elif update.has("color") and not current.is_empty():
			# 仅颜色变化不播放、也不重启扫光。
			current["ghost"].add_theme_color_override("font_color", update["color"])
		if update.has("color"):
			label.add_theme_color_override("font_color", update["color"])


func _entry_for(label: Label) -> Dictionary:
	for entry in active:
		if entry["label"] == label:
			return entry
	return {}


func _start_entry(label: Label) -> void:
	var bounds := label.get_global_rect().grow_individual(4, 0, 4, 0)
	var region := Vector4(bounds.position.x, bounds.position.y, bounds.size.x, bounds.size.y)
	var ghost := label.duplicate(0) as Label
	ghost.name = "RefreshOldText"
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	ghost.position = Vector2.ZERO
	ghost.size = label.size
	ghost.add_theme_color_override("font_color", label.get_theme_color("font_color"))
	label.add_child(ghost)
	var new_mask := _mask(region, false)
	var old_mask := _mask(region, true)
	var beam := shine.duplicate(0) as ColorRect
	beam.name = "Light_" + str(label.name)
	beam.material = shine.material.duplicate()
	beam.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	beam.position = bounds.position
	beam.size = bounds.size
	beam.material.set_shader_parameter("bounds", region)
	add_child(beam)
	beam.show()
	var entry: Dictionary = {"label": label, "ghost": ghost, "beam": beam, "original_material": label.material, "new_mask": new_mask, "old_mask": old_mask}
	label.material = new_mask
	ghost.material = old_mask
	active.append(entry)
	if not label.visibility_changed.is_connected(_on_target_visibility_changed):
		label.visibility_changed.connect(_on_target_visibility_changed)
	running = true
	show()
	_set_entry_progress(0.0, entry)
	var animation := create_tween()
	entry["tween"] = animation
	animation.tween_method(_set_entry_progress.bind(entry), 0.0, 1.0, duration)
	animation.finished.connect(_finish_entry.bind(entry))


func _mask(bounds: Vector4, old_text: bool) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = MASK_SHADER
	material.set_shader_parameter("bounds", bounds)
	material.set_shader_parameter("old_text", old_text)
	material.set_shader_parameter("viewport_size", get_viewport_rect().size)
	material.set_shader_parameter("progress", 0.0)
	return material


func _set_entry_progress(value: float, entry: Dictionary) -> void:
	entry["progress"] = value
	entry["beam"].material.set_shader_parameter("progress", value)
	entry["new_mask"].set_shader_parameter("progress", value)
	entry["old_mask"].set_shader_parameter("progress", value)


func _set_progress(value: float) -> void:
	progress = value
	for entry in active:
		_set_entry_progress(value, entry)


func _on_target_visibility_changed() -> void:
	for entry in active.duplicate():
		if not is_instance_valid(entry["label"]) or not entry["label"].is_visible_in_tree():
			_finish_entry(entry)


func _finish_entry(entry: Dictionary) -> void:
	if not active.has(entry):
		return
	var animation: Tween = entry.get("tween")
	if animation != null and animation.is_valid():
		animation.kill()
	if is_instance_valid(entry["label"]):
		entry["label"].material = entry["original_material"]
	for key in ["ghost", "beam"]:
		var node: Control = entry[key]
		if is_instance_valid(node):
			node.hide()
			if node.get_parent() != null:
				node.get_parent().remove_child(node)
			node.queue_free()
	active.erase(entry)
	running = not active.is_empty()
	if not running:
		hide()


func _clear() -> void:
	for entry in active.duplicate():
		_finish_entry(entry)


func _exit_tree() -> void:
	_clear()
