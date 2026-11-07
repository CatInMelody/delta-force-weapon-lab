extends RefCounted
## 下载数据只包含 JSON 和图片；安装完成后重新加载界面统一切换数据快照。

const API_VERSION := 2
const BUILTIN_VERSION := 3
const MAX_PACKAGE_BYTES := 8 * 1024 * 1024
const FILES := [
	"data/GunsTool_烽火地带_枪械基础数据.json", "data/weapon_variants.json",
	"data/weapon_ammo.json", "data/weapon_multipliers.json", "data/ammo_armor_factors.json",
	"data/ammo_base_damage_ratios.json", "data/ammo_special_effects.json", "data/removed_ammo.json",
	"data/defense_stats.json", "assets/defense-sources.json", "assets/Bullet/bullet-sources.json",
	"assets/Bullet/Special/special-ammo-icons.json",
]
static var storage_root := "user://data_updates"
static var generation := 0
static var loaded := false
static var active: Dictionary = {}
static var textures: Dictionary = {}
static var last_error := ""


static func reset_cache() -> void:
	loaded = false
	active = {}
	textures.clear()
	last_error = ""
	generation += 1


static func builtin_json(path: String) -> Dictionary:
	var value = parse_json(FileAccess.get_file_as_string(path))
	return value if value is Dictionary else {}


static func parse_json(value: String) -> Variant:
	var parser := JSON.new()
	return parser.data if parser.parse(value) == OK else null


static func _ensure_loaded() -> void:
	if loaded:
		return
	loaded = true
	var path := storage_root.path_join("active.json")
	if not FileAccess.file_exists(path):
		return
	var candidate = parse_json(FileAccess.get_file_as_string(path))
	var error := validate_bundle(candidate)
	if error.is_empty():
		if int(candidate["data_version"]) > BUILTIN_VERSION:
			active = candidate
	else:
		last_error = "本机更新数据不可用，已使用内置数据：" + error


static func read_json(path: String) -> Dictionary:
	_ensure_loaded()
	var key := path.trim_prefix("res://")
	if active.get("files", {}).has(key):
		return active["files"][key].duplicate(true)
	return builtin_json(path)


static func metadata() -> Dictionary:
	_ensure_loaded()
	return {"data_version": active.get("data_version", BUILTIN_VERSION), "version_name": active.get("version_name", "1.1.0"), "season": active.get("season", "S12")}


static func sha256(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()


static func load_texture(path: String) -> Texture2D:
	_ensure_loaded()
	var key := path.trim_prefix("res://")
	if active.get("images", {}).has(key):
		if not textures.has(key):
			var picture := decode_image(key, Marshalls.base64_to_raw(active["images"][key]))
			textures[key] = ImageTexture.create_from_image(picture)
		return textures[key]
	return load(path) as Texture2D


static func decode_image(path: String, bytes: PackedByteArray) -> Image:
	var picture := Image.new()
	var error := ERR_FILE_UNRECOGNIZED
	match path.get_extension().to_lower():
		"png": error = picture.load_png_from_buffer(bytes)
		"webp": error = picture.load_webp_from_buffer(bytes)
		"jpg", "jpeg": error = picture.load_jpg_from_buffer(bytes)
	return picture if error == OK else null


static func _image_path(path: String) -> bool:
	return path.begins_with("assets/") and not path.contains("..") and not path.contains(":") and not path.contains("\\") and path.get_extension().to_lower() in ["png", "webp", "jpg", "jpeg"]


static func _has_image(path: String, images: Dictionary) -> bool:
	var key := path.trim_prefix("res://")
	return _image_path(key) and (images.has(key) or ResourceLoader.exists("res://" + key))


static func _number(value: Variant, minimum: float = 0.0, maximum: float = 100000.0) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= minimum and float(value) <= maximum


static func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	return _number(value, minimum, maximum) and float(value) == floor(float(value))


static func _multipliers(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	for key in value:
		if key not in ["head", "chest", "abdomen", "limbs"] or not _number(value[key], 0, 100):
			return false
	return true


static func validate_bundle(bundle: Variant) -> String:
	if not bundle is Dictionary or bundle.get("schema_version") != 1 or not _integer(bundle.get("data_version"), 1, 2147483647):
		return "数据包版本格式无效"
	if not _integer(bundle.get("min_data_api", 1), 1, API_VERSION):
		return "此数据包需要新版程序"
	for key in ["version_name", "season"]:
		if not bundle.get(key) is String or bundle[key].is_empty() or bundle[key].length() > 64:
			return "缺少数据版本或赛季"
	if not bundle.get("files") is Dictionary or not bundle.get("images", {}) is Dictionary:
		return "数据文件列表无效"
	var files: Dictionary = bundle["files"]
	var images: Dictionary = bundle.get("images", {})
	for key in files:
		if key not in FILES or not files[key] is Dictionary:
			return "不支持的数据文件：" + str(key)
	for key in FILES:
		if not files.has(key):
			return "数据包缺少：" + key
	for path in images:
		if not path is String or not _image_path(path) or not images[path] is String or images[path].length() > 5 * 1024 * 1024:
			return "图片路径或大小无效"
		var picture := decode_image(path, Marshalls.base64_to_raw(images[path]))
		if picture == null or picture.get_width() > 4096 or picture.get_height() > 4096:
			return "图片无法读取或尺寸超过4096：" + path
	var guns = files[FILES[0]].get("weapons")
	var variants = files[FILES[1]].get("weapons")
	var links = files[FILES[2]].get("weapons")
	if not guns is Array or guns.is_empty() or guns.size() > 2000 or not variants is Array or variants.size() > 2000 or not links is Dictionary:
		return "枪械列表格式无效"
	var ids := {}
	var names := {}
	for weapon in guns:
		if not weapon is Dictionary:
			return "枪械记录无效"
		var id: String = str(weapon.get("weapon_id", ""))
		if not weapon.get("weapon_id") is String or id.is_empty() or ids.has(id) or not weapon.get("name") is String or weapon["name"].is_empty() or weapon.get("category") not in ["AR", "SMG", "LMG", "DMR", "SR"] or not weapon.get("category_name") is String:
			return "枪械名称、ID或分类无效"
		for key in ["range_m", "fire_rate_rpm", "flesh_damage", "armor_damage"]:
			if not _number(weapon.get(key), 0.001 if key in ["fire_rate_rpm", "flesh_damage"] else 0):
				return "枪械数值无效：" + weapon["name"] + "/" + key
		for key in ["initial_fire_rate_rpm", "arms_multiplier", "reference_ttk_seconds"]:
			if weapon.has(key) and not _number(weapon[key], 0.001):
				return "枪械专属参数无效：" + key
		if weapon.has("initial_burst_shots") and not _integer(weapon["initial_burst_shots"], 1, 100):
			return "首段射速发数无效"
		if not weapon.get("special_description", "") is String:
			return "枪械特殊说明无效"
		if not weapon.get("icon_relative_path") is String or not _has_image("assets/" + weapon["icon_relative_path"], images):
			return "缺少枪械图片：" + weapon["name"]
		var link = links.get(id)
		if not link is Dictionary or not link.get("ammo_type_id") is String or not link.get("caliber") is String or not link.get("icon_file") is String:
			return "缺少枪械弹药映射：" + weapon["name"]
		ids[id] = weapon
		names[weapon["name"]] = true
	if not names.has("M7") or not names.has("M4A1"):
		return "缺少初始枪械M7或M4A1"
	var all_ids := ids.duplicate()
	for variant in variants:
		if not variant is Dictionary or not variant.get("weapon_id") is String or all_ids.has(variant["weapon_id"]) or variant["weapon_id"].is_empty() or not ids.has(variant.get("base_weapon_id")) or not variant.get("name") is String:
			return "特殊枪械ID或原枪无效"
		if not variant.get("overrides", {}) is Dictionary or not _multipliers(variant.get("multipliers", {})):
			return "特殊枪械覆盖值无效"
		for key in variant.get("overrides", {}):
			if key == "icon_relative_path":
				if not variant["overrides"][key] is String or not _has_image("assets/" + variant["overrides"][key], images):
					return "特殊枪械缺少图片"
			elif key not in ["range_m", "fire_rate_rpm", "flesh_damage", "armor_damage"] or not _number(variant["overrides"][key], 0.001 if key in ["fire_rate_rpm", "flesh_damage"] else 0):
				return "特殊枪械数值无效"
		all_ids[variant["weapon_id"]] = true
	var overrides = files[FILES[3]].get("weapons")
	if not overrides is Dictionary:
		return "枪械倍率列表无效"
	for entry in overrides.values():
		if not entry is Dictionary or not _multipliers(entry.get("multipliers", {})):
			return "枪械倍率无效"
	var ammo_file: Dictionary = files[FILES[4]]
	if not ammo_file.get("ammo") is Dictionary or not ammo_file.get("by_ammo_type_and_level") is Dictionary:
		return "弹药目录无效"
	var ammo: Dictionary = ammo_file["ammo"]
	for ammo_id in ammo:
		var entry = ammo[ammo_id]
		if not entry is Dictionary:
			return "弹药记录无效"
		for key in ["item_id", "ammo_type_id", "name", "display_name", "caliber", "godot_icon_path"]:
			if not entry.get(key) is String:
				return "弹药字段无效"
		if entry["item_id"] != ammo_id or not _integer(entry.get("penetration_level"), 0, 7) or not _has_image(entry["godot_icon_path"], images):
			return "弹药等级或图片无效"
		for key in ["armor_damage_factors", "helmet_damage_factors"]:
			if not entry.get(key) is Array or entry[key].size() != 6:
				return "弹药甲伤系数必须包含6项"
			for factor in entry[key]:
				if not _number(factor, 0, 100):
					return "弹药甲伤系数无效"
	var removed = files[FILES[7]].get("ammo")
	if not removed is Dictionary:
		return "移除弹药列表无效"
	var ammo_index: Dictionary = ammo_file["by_ammo_type_and_level"]
	for type_id in ammo_index:
		if not ammo_index[type_id] is Dictionary:
			return "弹药索引无效"
		for level in ammo_index[type_id]:
			if not str(level).is_valid_int() or int(level) < 0 or int(level) > 7 or not ammo_index[type_id][level] is Array:
				return "弹药索引等级无效"
			for id in ammo_index[type_id][level]:
				if not ammo.has(id) or str(ammo[id]["ammo_type_id"]) != str(type_id) or int(ammo[id]["penetration_level"]) != int(level):
					return "弹药索引指向错误记录"
	for id in ids:
		var type_id: String = links[id]["ammo_type_id"]
		var available := false
		for entries in ammo_index.get(type_id, {}).values():
			for ammo_id in entries:
				available = available or not removed.has(ammo_id)
		if not available:
			return "枪械没有可用子弹：" + ids[id]["name"]
	var ratios: Dictionary = files[FILES[5]]
	if not ratios.get("by_level") is Dictionary or not ratios.get("by_caliber_and_level") is Dictionary:
		return "基础肉伤比例无效"
	var ratio_maps: Array = [ratios["by_level"]]
	ratio_maps.append_array(ratios["by_caliber_and_level"].values())
	for entries in ratio_maps:
		if not entries is Dictionary:
			return "口径肉伤比例无效"
		for value in entries.values():
			if not _number(value, 0, 100):
				return "基础肉伤比例数值无效"
	for effect in files[FILES[6]].values():
		if not effect is Dictionary or not effect.get("description", "") is String or not _multipliers(effect.get("body_multipliers", {})) or not _multipliers(effect.get("fixed_body_multipliers", {})):
			return "特殊子弹描述或部位倍率无效"
		for key in ["dot_ticks", "proc_hits"]:
			if effect.has(key) and not _integer(effect[key], 1, 100):
				return "特殊弹药命中次数或跳伤次数无效"
		for key in ["dot_duration", "dot_tick_damage", "proc_true_damage", "proc_armor_damage"]:
			if effect.has(key) and not _number(effect[key], 0.001, 100):
				return "特殊弹药额外伤害参数无效"
		for key in ["base_damage_ratio", "fire_rate_multiplier", "projectiles_per_round", "fixed_armor_damage"]:
			if effect.has(key) and not _number(effect[key], 0.001 if key != "fixed_armor_damage" else 0, 16 if key == "projectiles_per_round" else 100):
				return "特殊子弹数值无效"
		if effect.has("projectiles_per_round") and not _integer(effect["projectiles_per_round"], 1, 16):
			return "弹头数量无效"
		if effect.has("background_level") and not _integer(effect["background_level"], 0, 7):
			return "特殊子弹背景等级无效"
		if effect.has("health_rates"):
			if not effect["health_rates"] is Array or effect["health_rates"].size() != 6:
				return "特殊穿血表无效"
			for value in effect["health_rates"]:
				if not _number(value, 0, 1):
					return "特殊穿血比例无效"
		if effect.has("fixed_chest_damage"):
			if not effect["fixed_chest_damage"] is Dictionary or not effect.has("fixed_armor_damage") or not effect.has("fixed_body_multipliers") or effect["fixed_body_multipliers"].size() != 4:
				return "固定伤害弹药字段不完整"
			for level in range(7):
				if not _number(effect["fixed_chest_damage"].get(str(level)), 0.001):
					return "固定胸伤表无效"
	var defense: Dictionary = files[FILES[8]]
	for section in ["helmets", "armors"]:
		if not defense.get(section) is Dictionary:
			return "防具数据无效"
		for entry in defense[section].values():
			if not entry is Dictionary or not entry.get("name") is String or not _integer(entry.get("level"), 1, 6) or not _number(entry.get("max_durability"), 0.001):
				return "防具等级或耐久无效"
	var defense_icons = files[FILES[9]].get("items")
	if not defense_icons is Array:
		return "防具图片目录无效"
	var defense_names := {}
	for entry in defense_icons:
		if not entry is Dictionary or not entry.get("name") is String or not entry.get("item_id") is String or entry.get("category") not in ["Helmet", "Armor"] or not entry.get("relative_path") is String or not _has_image("assets/" + entry["relative_path"], images):
			return "防具图片无效"
		var section := "helmets" if entry["category"] == "Helmet" else "armors"
		if not defense[section].has(entry.get("item_id")):
			return "防具图片缺少对应耐久记录"
		defense_names[entry.get("name", "")] = true
	for name in ["重型突击背心", "GN重型头盔", "DICH训练头盔"]:
		if not defense_names.has(name):
			return "缺少参考防具：" + name
	var bullets: Dictionary = files[FILES[10]]
	if not bullets.get("icons") is Array or not bullets.get("background_level_mapping") is Dictionary:
		return "弹药图片配置无效"
	var icon_names := {}
	for entry in bullets["icons"]:
		if not entry is Dictionary or not entry.get("filename") is String:
			return "口径图片条目无效"
		icon_names[entry["filename"]] = true
	for id in ids:
		if not icon_names.has(links[id]["icon_file"]):
			return "枪械引用的口径图片不存在"
	for level in range(8):
		var path = bullets["background_level_mapping"].get(str(level))
		if not path is String or not _has_image("assets/Bullet/" + path, images):
			return "缺少子弹等级背景"
	var special_icons = files[FILES[11]].get("icons")
	if not special_icons is Dictionary:
		return "特殊子弹图片配置无效"
	for entry in special_icons.values():
		if not entry is Dictionary or not entry.get("godot_icon_path") is String or not _has_image(entry["godot_icon_path"], images):
			return "特殊子弹图片不存在"
	return ""


static func install(bytes: PackedByteArray) -> String:
	if bytes.size() > MAX_PACKAGE_BYTES:
		return "数据包超过8 MiB"
	var bundle = parse_json(bytes.get_string_from_utf8())
	var error := validate_bundle(bundle)
	if not error.is_empty():
		return error
	if int(bundle["data_version"]) <= int(metadata()["data_version"]):
		return "数据版本未高于当前版本"
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(storage_root)) != OK:
		return "无法创建本机数据目录"
	var target := storage_root.path_join("active.json")
	var temporary := target + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return "无法写入数据包"
	file.store_buffer(bytes)
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		return "数据包写入失败"
	if FileAccess.file_exists(target):
		if DirAccess.copy_absolute(ProjectSettings.globalize_path(target), ProjectSettings.globalize_path(storage_root.path_join("previous.json"))) != OK:
			return "无法备份原数据，未更新"
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(target)) != OK:
		return "无法替换数据，未更新"
	return ""


