extends Node
## 玩家持久化仓库（多分页）

const SAVE_PATH := "user://player_warehouse.json"
const WarehouseConfigScript = preload("res://scripts/data/warehouse_config.gd")
const PersistentGridUtilScript = preload("res://scripts/util/persistent_grid_util.gd")

signal warehouse_changed

var _pages: Array[Dictionary] = []
var _next_uid: int = 1


func _ready() -> void:
	load_data()
	if _pages.is_empty():
		_init_default_page()
	else:
		_migrate_page_sizes()


func _exit_tree() -> void:
	save_data()


func get_page_count() -> int:
	return _pages.size()


func get_pages() -> Array[Dictionary]:
	return _pages


func get_page(index: int) -> Dictionary:
	if index < 0 or index >= _pages.size():
		return {}
	return _pages[index]


func unlock_expansion_page(page_name: String, grid_w: int, grid_h: int, is_collection_box: bool = false) -> bool:
	var page_id: String = "page_%d" % _pages.size()
	var page: Dictionary = {
		"id": page_id,
		"name": page_name,
		"grid_w": maxi(grid_w, 4),
		"grid_h": maxi(grid_h, 4),
		"items": [],
	}
	if is_collection_box:
		page["is_collection_box"] = true
	_pages.append(page)
	save_data()
	warehouse_changed.emit()
	return true


func try_add_from_catalog(item_id: String, catalog, preferred_page: int = -1) -> bool:
	if catalog == null or not catalog.is_loaded():
		return false
	var row: Dictionary = catalog.get_item(item_id)
	if row.is_empty():
		return false
	var sw: int = clampi(int(row.get("size_w", 1)), 1, 32)
	var sh: int = clampi(int(row.get("size_h", 1)), 1, 32)
	var page_order: Array[int] = []
	if preferred_page >= 0 and preferred_page < _pages.size():
		page_order.append(preferred_page)
	for i in _pages.size():
		if i not in page_order:
			page_order.append(i)
	for page_i in page_order:
		var page: Dictionary = _pages[page_i]
		var cols: int = int(page.get("grid_w", 8))
		var rows: int = int(page.get("grid_h", 8))
		var occupancy: Array = PersistentGridUtilScript.new_occupancy(cols, rows)
		_fill_occupancy(occupancy, page, catalog)
		var pos: Vector2i = PersistentGridUtilScript.find_first_fit(occupancy, sw, sh, cols, rows)
		if pos.x < 0:
			continue
		var items: Array = page.get("items", [])
		items.append({
			"uid": _alloc_uid(),
			"item_id": item_id,
			"x": pos.x,
			"y": pos.y,
		})
		page["items"] = items
		save_data()
		warehouse_changed.emit()
		return true
	return false


func try_add_match_warehouse_item(wh_item, catalog) -> bool:
	if wh_item == null:
		return false
	var preferred: int = -1
	if wh_item.quality == GameConstants.Quality.RED:
		preferred = _first_collection_box_page()
	return try_add_from_catalog(str(wh_item.item_id), catalog, preferred)


func deposit_match_warehouse(warehouse, catalog) -> int:
	if warehouse == null or catalog == null:
		return 0
	var red_items: Array = []
	var other_items: Array = []
	for wh_item in warehouse.items:
		if wh_item.quality == GameConstants.Quality.RED:
			red_items.append(wh_item)
		else:
			other_items.append(wh_item)
	var added: int = 0
	for wh_item in red_items:
		if try_add_match_warehouse_item(wh_item, catalog):
			added += 1
	for wh_item in other_items:
		if try_add_match_warehouse_item(wh_item, catalog):
			added += 1
	save_data()
	return added


func _first_collection_box_page() -> int:
	for i in _pages.size():
		if _pages[i].get("is_collection_box", false):
			return i
	return -1


func get_collection_box_pages() -> Array[int]:
	var out: Array[int] = []
	for i in _pages.size():
		if _pages[i].get("is_collection_box", false):
			out.append(i)
	return out


func clear_all_items() -> void:
	for page in _pages:
		page["items"] = []
	save_data()
	warehouse_changed.emit()


func remove_items_by_uid(uids: Array[String]) -> Array[Dictionary]:
	var removed: Array[Dictionary] = []
	if uids.is_empty():
		return removed
	var uid_set: Dictionary = {}
	for uid in uids:
		uid_set[uid] = true
	for page in _pages:
		var items: Array = page.get("items", [])
		var kept: Array = []
		for entry in items:
			if typeof(entry) != TYPE_DICTIONARY:
				continue
			var uid: String = str(entry.get("uid", ""))
			if uid_set.has(uid):
				removed.append(entry)
			else:
				kept.append(entry)
		page["items"] = kept
	if not removed.is_empty():
		save_data()
		warehouse_changed.emit()
	return removed


func auto_organize_page(page_index: int, catalog) -> void:
	if page_index < 0 or page_index >= _pages.size() or catalog == null:
		return
	var page: Dictionary = _pages[page_index]
	var cols: int = int(page.get("grid_w", 8))
	var rows: int = int(page.get("grid_h", 8))
	var raw_items: Array = page.get("items", [])
	var sorted: Array[Dictionary] = []
	for entry in raw_items:
		if typeof(entry) == TYPE_DICTIONARY:
			sorted.append(entry)
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ca: Dictionary = catalog.get_item(str(a.get("item_id", "")))
		var cb: Dictionary = catalog.get_item(str(b.get("item_id", "")))
		var area_a: int = int(ca.get("size_w", 1)) * int(ca.get("size_h", 1))
		var area_b: int = int(cb.get("size_w", 1)) * int(cb.get("size_h", 1))
		if area_a != area_b:
			return area_a > area_b
		return int(ca.get("base_price", 0)) > int(cb.get("base_price", 0))
	)
	var occupancy: Array = PersistentGridUtilScript.new_occupancy(cols, rows)
	var placed: Array = []
	for entry in sorted:
		var row: Dictionary = catalog.get_item(str(entry.get("item_id", "")))
		if row.is_empty():
			continue
		var sw: int = clampi(int(row.get("size_w", 1)), 1, cols)
		var sh: int = clampi(int(row.get("size_h", 1)), 1, rows)
		var pos: Vector2i = PersistentGridUtilScript.find_first_fit(occupancy, sw, sh, cols, rows)
		if pos.x < 0:
			placed.append(entry)
			continue
		PersistentGridUtilScript.occupy(occupancy, pos.x, pos.y, sw, sh)
		var copy: Dictionary = entry.duplicate()
		copy["x"] = pos.x
		copy["y"] = pos.y
		placed.append(copy)
	page["items"] = placed
	save_data()
	warehouse_changed.emit()


## 跨页整理：红色品质道具优先放入高级藏品箱，其他品质正常分配
func auto_organize_all(catalog) -> void:
	if catalog == null or _pages.is_empty():
		return
	var all_items: Array[Dictionary] = []
	for page in _pages:
		for entry in page.get("items", []):
			if typeof(entry) == TYPE_DICTIONARY:
				all_items.append(entry)
		page["items"] = []
	var red_items: Array[Dictionary] = []
	var other_items: Array[Dictionary] = []
	for entry in all_items:
		var row: Dictionary = catalog.get_item(str(entry.get("item_id", "")))
		if int(row.get("quality_enum", 0)) == GameConstants.Quality.RED:
			red_items.append(entry)
		else:
			other_items.append(entry)
	var sort_fn := func(a: Dictionary, b: Dictionary) -> bool:
		var ca: Dictionary = catalog.get_item(str(a.get("item_id", "")))
		var cb: Dictionary = catalog.get_item(str(b.get("item_id", "")))
		var area_a: int = int(ca.get("size_w", 1)) * int(ca.get("size_h", 1))
		var area_b: int = int(cb.get("size_w", 1)) * int(cb.get("size_h", 1))
		if area_a != area_b:
			return area_a > area_b
		return int(ca.get("base_price", 0)) > int(cb.get("base_price", 0))
	red_items.sort_custom(sort_fn)
	other_items.sort_custom(sort_fn)
	var collection_pages: Array[int] = get_collection_box_pages()
	var normal_pages: Array[int] = []
	for i in _pages.size():
		if i not in collection_pages:
			normal_pages.append(i)
	var red_order: Array[int] = collection_pages.duplicate()
	for i in normal_pages:
		red_order.append(i)
	var other_order: Array[int] = normal_pages.duplicate()
	for i in collection_pages:
		other_order.append(i)
	var occupancies: Dictionary = {}
	for i in _pages.size():
		var p: Dictionary = _pages[i]
		occupancies[i] = PersistentGridUtilScript.new_occupancy(
			int(p.get("grid_w", 8)), int(p.get("grid_h", 8)))
	_place_items_into_pages(red_items, red_order, occupancies, catalog)
	_place_items_into_pages(other_items, other_order, occupancies, catalog)
	save_data()
	warehouse_changed.emit()


func _place_items_into_pages(items: Array[Dictionary], page_order: Array[int],
		occupancies: Dictionary, catalog) -> void:
	for entry in items:
		var row: Dictionary = catalog.get_item(str(entry.get("item_id", "")))
		if row.is_empty():
			continue
		var sw: int = clampi(int(row.get("size_w", 1)), 1, 32)
		var sh: int = clampi(int(row.get("size_h", 1)), 1, 32)
		var placed_ok: bool = false
		for page_i in page_order:
			var page: Dictionary = _pages[page_i]
			var cols: int = int(page.get("grid_w", 8))
			var rows: int = int(page.get("grid_h", 8))
			if sw > cols or sh > rows:
				continue
			var occ: Array = occupancies[page_i]
			var pos: Vector2i = PersistentGridUtilScript.find_first_fit(occ, sw, sh, cols, rows)
			if pos.x < 0:
				continue
			PersistentGridUtilScript.occupy(occ, pos.x, pos.y, sw, sh)
			var copy: Dictionary = entry.duplicate()
			copy["x"] = pos.x
			copy["y"] = pos.y
			page["items"].append(copy)
			placed_ok = true
			break
		if not placed_ok:
			_pages[page_order[0]]["items"].append(entry)


func get_used_cells(page_index: int, catalog) -> int:
	var page: Dictionary = get_page(page_index)
	if page.is_empty():
		return 0
	var total: int = 0
	for entry in page.get("items", []):
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = catalog.get_item(str(entry.get("item_id", "")))
		total += int(row.get("size_w", 1)) * int(row.get("size_h", 1))
	return total


func get_capacity_cells(page_index: int) -> int:
	var page: Dictionary = get_page(page_index)
	if page.is_empty():
		return 0
	return int(page.get("grid_w", 8)) * int(page.get("grid_h", 8))


func load_data() -> void:
	_pages.clear()
	_next_uid = 1
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	_next_uid = maxi(1, int(parsed.get("next_uid", 1)))
	for page_v in parsed.get("pages", []):
		if typeof(page_v) != TYPE_DICTIONARY:
			continue
		_pages.append(page_v)


func save_data() -> void:
	if _pages.is_empty():
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({
			"next_uid": _next_uid,
			"pages": _pages.duplicate(true),
		}))
	else:
		push_error("PlayerWarehouse: 无法写入 %s (err=%d)" % [SAVE_PATH, FileAccess.get_open_error()])


func _migrate_page_sizes() -> void:
	var changed: bool = false
	for i in _pages.size():
		var page: Dictionary = _pages[i]
		var page_name: String = str(page.get("name", ""))
		var expected: Vector2i
		if i == 0:
			var dp: Dictionary = WarehouseConfigScript.get_default_page()
			expected = Vector2i(int(dp.get("grid_w", 10)), int(dp.get("grid_h", 20)))
		else:
			expected = WarehouseConfigScript.get_expected_page_size(page_name)
		if expected == Vector2i.ZERO:
			continue
		var old_w: int = int(page.get("grid_w", 8))
		var old_h: int = int(page.get("grid_h", 8))
		if old_w == expected.x and old_h == expected.y:
			continue
		page["grid_w"] = expected.x
		page["grid_h"] = expected.y
		_clamp_out_of_bounds(page, old_w, old_h)
		changed = true
	if changed:
		save_data()


func _clamp_out_of_bounds(page: Dictionary, _old_w: int, _old_h: int) -> void:
	var cols: int = int(page.get("grid_w", 8))
	var rows: int = int(page.get("grid_h", 8))
	var items: Array = page.get("items", [])
	for entry in items:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var x: int = int(entry.get("x", 0))
		var y: int = int(entry.get("y", 0))
		if x >= cols:
			entry["x"] = 0
		if y >= rows:
			entry["y"] = 0


func _init_default_page() -> void:
	var cfg: Dictionary = WarehouseConfigScript.get_default_page()
	_pages.append({
		"id": "page_0",
		"name": str(cfg.get("name", "主仓库")),
		"grid_w": int(cfg.get("grid_w", 8)),
		"grid_h": int(cfg.get("grid_h", 8)),
		"items": [],
	})
	save_data()


func _alloc_uid() -> String:
	var uid: String = "wh_%d" % _next_uid
	_next_uid += 1
	return uid


func _fill_occupancy(occupancy: Array, page: Dictionary, catalog) -> void:
	var cols: int = int(page.get("grid_w", 8))
	var rows: int = int(page.get("grid_h", 8))
	for entry in page.get("items", []):
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = catalog.get_item(str(entry.get("item_id", "")))
		if row.is_empty():
			continue
		var sw: int = clampi(int(row.get("size_w", 1)), 1, cols)
		var sh: int = clampi(int(row.get("size_h", 1)), 1, rows)
		var x: int = int(entry.get("x", 0))
		var y: int = int(entry.get("y", 0))
		if PersistentGridUtilScript.can_place(occupancy, x, y, sw, sh, cols, rows):
			PersistentGridUtilScript.occupy(occupancy, x, y, sw, sh)
