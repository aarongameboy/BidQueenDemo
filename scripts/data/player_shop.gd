extends Node
## 商店购买记录（永久限购等）

const SAVE_PATH := "user://player_shop.json"

var purchased_counts: Dictionary = {}


func _ready() -> void:
	load_data()


func get_purchase_count(product_id: String) -> int:
	return int(purchased_counts.get(product_id, 0))


func can_purchase(product: Dictionary) -> bool:
	var product_id: String = str(product.get("product_id", ""))
	if product_id.is_empty():
		return false
	var limit: int = int(product.get("purchase_limit", 0))
	if limit <= 0:
		return true
	return get_purchase_count(product_id) < limit


func record_purchase(product_id: String, count: int = 1) -> void:
	if product_id.is_empty():
		return
	purchased_counts[product_id] = get_purchase_count(product_id) + count
	save_data()


func load_data() -> void:
	purchased_counts.clear()
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var raw: Variant = parsed.get("purchased_counts", {})
	if typeof(raw) != TYPE_DICTIONARY:
		return
	for key in raw.keys():
		purchased_counts[str(key)] = int(raw[key])


func save_data() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({
			"purchased_counts": purchased_counts.duplicate(),
		}))
