extends Button
## 只缩放按钮内的图片，命中区域与容器布局保持稳定。

var hovered := false
var held := false
var feedback: Tween


func _ready() -> void:
	mouse_entered.connect(func() -> void:
		hovered = true
		_animate(0.94 if held else 1.04)
	)
	mouse_exited.connect(func() -> void:
		hovered = false
		_animate(0.94 if held else 1.0)
	)
	button_down.connect(func() -> void:
		held = true
		_animate(0.94)
	)
	button_up.connect(func() -> void:
		held = false
		_animate(1.04 if hovered else 1.0)
	)
	visibility_changed.connect(func() -> void:
		if not is_visible_in_tree():
			hovered = false
			held = false
			_animate(1.0)
	)


func _animate(value: float) -> void:
	if not is_inside_tree():
		return
	if feedback != null and feedback.is_valid():
		feedback.kill()
	feedback = create_tween().set_parallel(true)
	for child in get_children():
		if child is TextureRect:
			child.pivot_offset = child.size * 0.5
			feedback.tween_property(child, "scale", Vector2.ONE * value, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
