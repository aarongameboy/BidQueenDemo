class_name PersistentGridUtil
extends RefCounted
## 矩形占格：放置检测与自动整理辅助

static func new_occupancy(cols: int, rows: int) -> Array:
	var grid: Array = []
	for _y in rows:
		var row: Array = []
		row.resize(cols)
		for x in cols:
			row[x] = false
		grid.append(row)
	return grid


static func can_place(occupancy: Array, x: int, y: int, sw: int, sh: int, cols: int, rows: int) -> bool:
	if x < 0 or y < 0 or x + sw > cols or y + sh > rows:
		return false
	for dy in sh:
		for dx in sw:
			if occupancy[y + dy][x + dx]:
				return false
	return true


static func occupy(occupancy: Array, x: int, y: int, sw: int, sh: int) -> void:
	for dy in sh:
		for dx in sw:
			occupancy[y + dy][x + dx] = true


static func find_first_fit(
	occupancy: Array,
	sw: int,
	sh: int,
	cols: int,
	rows: int,
) -> Vector2i:
	for y in rows - sh + 1:
		for x in cols - sw + 1:
			if can_place(occupancy, x, y, sw, sh, cols, rows):
				return Vector2i(x, y)
	return Vector2i(-1, -1)
