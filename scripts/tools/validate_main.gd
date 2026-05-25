extends SceneTree

func _initialize() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn") as PackedScene
	if packed == null:
		push_error("main.tscn failed to load")
		quit(1)
		return
	var inst: Node = packed.instantiate()
	if inst == null:
		push_error("main.tscn failed to instantiate")
		quit(1)
		return
	print("main.tscn: instantiate OK")
	inst.free()
	quit()
