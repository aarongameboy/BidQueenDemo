extends Node
## 战术道具库存与出战配置（持久化）

signal inventory_changed

const SAVE_PATH := "user://player_tactical_items.json"
const TacticalCatalogScript = preload("res://scripts/data/tactical_item_catalog.gd")

var _catalog: TacticalItemCatalog = null
var inventory: Dictionary = {}
var loadout: Array[String] = []


func _ready() -> void:
	_catalog = TacticalCatalogScript.new()
	_catalog.load_all()
	_reset_loadout_slots()
	load_data()


func get_catalog() -> TacticalItemCatalog:
	if _catalog == null:
		_catalog = TacticalCatalogScript.new()
		_catalog.load_all()
	return _catalog


func get_count(item_id: String) -> int:
	return int(inventory.get(item_id, 0))


func add_items(item_id: String, count: int = 1) -> void:
	if item_id.is_empty() or count <= 0:
		return
	inventory[item_id] = get_count(item_id) + count
	save_data()


func consume_items(item_id: String, count: int = 1) -> bool:
	if item_id.is_empty() or count <= 0:
		return false
	var have: int = get_count(item_id)
	if have < count:
		return false
	var left: int = have - count
	if left <= 0:
		inventory.erase(item_id)
	else:
		inventory[item_id] = left
	save_data()
	return true


func sell_items(item_id: String, count: int = 1) -> bool:
	if not consume_items(item_id, count):
		return false
	sanitize_loadout_for_match()
	return true


func get_loadout() -> Array[String]:
	var out: Array[String] = []
	for slot in loadout:
		out.append(str(slot))
	return out


func set_loadout_slot(slot_index: int, item_id: String) -> bool:
	var max_slots: int = get_catalog().get_max_loadout_slots()
	if slot_index < 0 or slot_index >= max_slots:
		return false
	_ensure_loadout_size(max_slots)
	loadout[slot_index] = item_id.strip_edges()
	save_data()
	return true


func clear_loadout_slot(slot_index: int) -> void:
	set_loadout_slot(slot_index, "")


func get_equipped_count() -> int:
	var n: int = 0
	for slot in loadout:
		if not str(slot).is_empty():
			n += 1
	return n


## 移除口袋中库存不足或无效的道具，返回被移除的显示名
func sanitize_loadout_for_match() -> Array[String]:
	var max_slots: int = get_catalog().get_max_loadout_slots()
	var remaining: Dictionary = inventory.duplicate()
	var removed_names: Array[String] = []
	var changed: bool = false
	for i in mini(loadout.size(), max_slots):
		var item_id: String = str(loadout[i]).strip_edges()
		if item_id.is_empty():
			continue
		var item_def: Dictionary = get_catalog().get_item(item_id)
		if item_def.is_empty():
			loadout[i] = ""
			changed = true
			removed_names.append(item_id)
			continue
		var have: int = int(remaining.get(item_id, 0))
		if have <= 0:
			loadout[i] = ""
			changed = true
			removed_names.append(str(item_def.get("name", item_id)))
			continue
		remaining[item_id] = have - 1
	if changed:
		save_data()
	return removed_names


func validate_loadout_for_match() -> Dictionary:
	sanitize_loadout_for_match()
	var max_slots: int = get_catalog().get_max_loadout_slots()
	var equipped: Array[String] = []
	var needed: Dictionary = {}
	for i in mini(loadout.size(), max_slots):
		var item_id: String = str(loadout[i]).strip_edges()
		if item_id.is_empty():
			continue
		if get_catalog().get_item(item_id).is_empty():
			return {"ok": false, "reason": "出战配置含无效道具"}
		needed[item_id] = int(needed.get(item_id, 0)) + 1
	for item_id in needed.keys():
		if get_count(item_id) < int(needed[item_id]):
			var item_def: Dictionary = get_catalog().get_item(item_id)
			var label: String = str(item_def.get("name", item_id))
			return {"ok": false, "reason": "道具「%s」数量不足" % label}
	for i in mini(loadout.size(), max_slots):
		var slot_id: String = str(loadout[i]).strip_edges()
		if not slot_id.is_empty():
			equipped.append(slot_id)
	return {"ok": true, "equipped": equipped}


## 对局内实际使用道具时扣库存，并清空对应口袋位
func consume_on_use(item_id: String, loadout_index: int = -1) -> bool:
	if item_id.is_empty():
		return false
	if not consume_items(item_id, 1):
		return false
	if loadout_index >= 0 and loadout_index < loadout.size():
		if str(loadout[loadout_index]).strip_edges() == item_id:
			loadout[loadout_index] = ""
			save_data()
			return true
	for i in loadout.size():
		if str(loadout[i]).strip_edges() == item_id:
			loadout[i] = ""
			save_data()
			return true
	save_data()
	return true


func _ensure_loadout_size(size: int) -> void:
	while loadout.size() < size:
		loadout.append("")


func _reset_loadout_slots() -> void:
	loadout.clear()
	_ensure_loadout_size(get_catalog().get_max_loadout_slots())


func load_data() -> void:
	inventory.clear()
	if not FileAccess.file_exists(SAVE_PATH):
		_reset_loadout_slots()
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		_reset_loadout_slots()
		return
	var raw_inv: Variant = parsed.get("inventory", {})
	if typeof(raw_inv) == TYPE_DICTIONARY:
		for key in raw_inv.keys():
			var count: int = int(raw_inv[key])
			if count > 0:
				inventory[str(key)] = count
	var raw_loadout: Variant = parsed.get("loadout", [])
	loadout.clear()
	if typeof(raw_loadout) == TYPE_ARRAY:
		for slot in raw_loadout:
			loadout.append(str(slot))
	_ensure_loadout_size(get_catalog().get_max_loadout_slots())


func save_data() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		var loadout_arr: Array = []
		for slot in loadout:
			loadout_arr.append(str(slot))
		file.store_string(JSON.stringify({
			"inventory": inventory.duplicate(),
			"loadout": loadout_arr,
		}))
	inventory_changed.emit()
