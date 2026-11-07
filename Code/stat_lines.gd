extends VBoxContainer
## 每行是可编辑的独立 Label；保留整段只读文本供检查与工具使用。

var text: String:
	get:
		var lines := PackedStringArray()
		for child in get_children():
			if child is Label:
				lines.append(child.text)
		return "\n".join(lines)
