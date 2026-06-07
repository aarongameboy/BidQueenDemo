class_name ShopCatalog
extends RefCounted

const CONFIG_PATH := "res://config/shop_config.json"

var _categories: Array[Dictionary] = []
var _products: Array[Dictionary] = []
var _loaded: bool = false


func load_all() -> bool:
	_categories.clear()
	_products.clear()
	if not FileAccess.file_exists(CONFIG_PATH):
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	for row in parsed.get("categories", []):
		if typeof(row) == TYPE_DICTIONARY:
			_categories.append(row)
	for row in parsed.get("products", []):
		if typeof(row) == TYPE_DICTIONARY:
			_products.append(row)
	_loaded = true
	return true


func is_loaded() -> bool:
	return _loaded


func get_categories(enabled_only: bool = true) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for row in _categories:
		if enabled_only and not bool(row.get("enabled", true)):
			continue
		out.append(row)
	return out


func get_products_for_category(category_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for row in _products:
		if str(row.get("category", "")) == category_id:
			out.append(row)
	return out


func get_product(product_id: String) -> Dictionary:
	for row in _products:
		if str(row.get("product_id", "")) == product_id:
			return row
	return {}


func get_product_by_tactical_id(tactical_id: String) -> Dictionary:
	for row in _products:
		var effect: Dictionary = row.get("effect", {})
		if str(effect.get("type", "")) == "tactical_item" and str(effect.get("tactical_id", "")) == tactical_id:
			return row
	return {}
