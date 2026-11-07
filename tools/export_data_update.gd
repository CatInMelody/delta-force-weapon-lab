extends SceneTree
## Godot --headless --path . --script res://tools/export_data_update.gd -- --version 2 --name 1.0.1

const DataStore = preload("res://Code/data_store.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var options := {"--version": "3", "--name": "1.1.0", "--season": "S12", "--notes": "S12武器与特殊弹药更新，需要1.1.0程序", "--out": "res://publish"}
	var image_paths: Array[String] = []
	var index := 0
	while index < args.size():
		var key := args[index]
		if index + 1 >= args.size() or (not options.has(key) and key != "--image"):
			push_error("参数无效：" + key)
			quit(1)
			return
		if key == "--image":
			image_paths.append(args[index + 1].trim_prefix("res://"))
		else:
			options[key] = args[index + 1]
		index += 2
	var bundle := {"schema_version": 1, "min_data_api": DataStore.API_VERSION, "data_version": int(options["--version"]), "version_name": options["--name"], "season": options["--season"], "files": {}, "images": {}}
	for path in DataStore.FILES:
		bundle["files"][path] = DataStore.builtin_json("res://" + path)
	for path in image_paths:
		if not DataStore._image_path(path) or not FileAccess.file_exists("res://" + path):
			push_error("图片路径无效：" + path)
			quit(1)
			return
		bundle["images"][path] = Marshalls.raw_to_base64(FileAccess.get_file_as_bytes("res://" + path))
	var error := DataStore.validate_bundle(bundle)
	var bytes := JSON.stringify(bundle).to_utf8_buffer()
	if not error.is_empty() or bytes.size() > DataStore.MAX_PACKAGE_BYTES:
		push_error("无法生成数据包：" + error + "；大小 %d 字节" % bytes.size())
		quit(1)
		return
	var output: String = options["--out"]
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output)) != OK:
		push_error("无法创建发布目录")
		quit(1)
		return
	var filename := "data-%d.json" % int(bundle["data_version"])
	var package := FileAccess.open(output.path_join(filename), FileAccess.WRITE)
	if package == null:
		quit(1)
		return
	package.store_buffer(bytes)
	package.close()
	var manifest := {"schema_version": 1, "data_version": bundle["data_version"], "version_name": bundle["version_name"], "season": bundle["season"], "min_data_api": DataStore.API_VERSION, "package_url": filename, "size": bytes.size(), "sha256": DataStore.sha256(bytes), "notes": options["--notes"]}
	var version := FileAccess.open(output.path_join("data-version.json"), FileAccess.WRITE)
	version.store_string(JSON.stringify(manifest, "\t"))
	version.close()
	var headers := FileAccess.open(output.path_join("_headers"), FileAccess.WRITE)
	headers.store_string("/data-version.json\n  Cache-Control: no-store\n")
	headers.close()
	print("DATA_PACKAGE: %s; %.1f KiB; SHA256 %s" % [output.path_join(filename), bytes.size() / 1024.0, manifest["sha256"]])
	quit()
