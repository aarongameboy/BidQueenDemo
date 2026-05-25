extends Node
## 玩家已搜出的红色品质藏品（持久化）

const SAVE_PATH := "user://player_collection.json"

var collected_red_ids: Array[String] = []


func _ready() -> void:
    load_data()


func _exit_tree() -> void:
    save_data()


func has_collected(item_id: String) -> bool:
    return collected_red_ids.has(item_id)


func collected_count() -> int:
    return collected_red_ids.size()


func record_red_item(item_id: String) -> bool:
    if item_id.is_empty() or collected_red_ids.has(item_id):
        return false
    collected_red_ids.append(item_id)
    save_data()
    return true


func load_data() -> void:
    collected_red_ids.clear()
    if not FileAccess.file_exists(SAVE_PATH):
        return
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
    if typeof(parsed) != TYPE_DICTIONARY:
        return
    for id_v in parsed.get("collected_red_ids", []):
        var id_str: String = str(id_v)
        if not id_str.is_empty() and not collected_red_ids.has(id_str):
            collected_red_ids.append(id_str)


func save_data() -> void:
    var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if file:
        file.store_string(JSON.stringify({
            "collected_red_ids": collected_red_ids.duplicate(),
        }))
