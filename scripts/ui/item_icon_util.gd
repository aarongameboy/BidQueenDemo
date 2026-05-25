class_name ItemIconUtil
extends RefCounted
## 道具图标：优先 icon_path，缺失时按品质回退 placeholder

const PLACEHOLDER_TMPL: String = "res://assets/icons/items/placeholder_q%d.png"

static var _cache: Dictionary = {}


static func get_texture(row: Dictionary) -> Texture2D:
	var icon_path: String = str(row.get("icon_path", ""))
	var q_enum: int = int(row.get("quality_enum", GameConstants.Quality.WHITE))
	return resolve(icon_path, q_enum)


static func resolve(icon_path: String, quality_enum: int) -> Texture2D:
	if not icon_path.is_empty():
		var path_key: String = "path:%s" % icon_path
		if _cache.has(path_key):
			return _cache[path_key] as Texture2D
		if ResourceLoader.exists(icon_path):
			var loaded: Texture2D = load(icon_path) as Texture2D
			if loaded:
				_cache[path_key] = loaded
				return loaded
	var q_idx: int = clampi(quality_enum, 0, 5)
	var q_key: String = "q:%d" % q_idx
	if _cache.has(q_key):
		return _cache[q_key] as Texture2D
	var ph_path: String = PLACEHOLDER_TMPL % q_idx
	if ResourceLoader.exists(ph_path):
		var ph: Texture2D = load(ph_path) as Texture2D
		_cache[q_key] = ph
		return ph
	return null
