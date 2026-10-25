extends Node

func _find_meshes(node: Node, arr: Array) -> void:
	if node is MeshInstance3D:
		arr.append(node)
	for c in node.get_children():
		_find_meshes(c, arr)

func _ready() -> void:
	GameManager.current_mission_id = 0
	var scene = load("res://scenes/levels/level_base.tscn").instantiate()
	add_child(scene)
	
	print("=== INSPECTING ALL MESHES IN SCENE ===")
	var all_meshes: Array = []
	_find_meshes(scene, all_meshes)
	for m in all_meshes:
		var g_scale: Vector3 = m.global_transform.basis.get_scale()
		var aabb: AABB = m.get_aabb()
		var world_size: Vector3 = aabb.size * g_scale
		if world_size.length() > 2.0 or m.global_position.distance_to(Vector3(0, 1.5, 0)) < 6.0:
			print("Mesh: ", m.name, " parent=", m.get_parent().name, " pos=", m.global_position, " world_size=", world_size)
	
	for i in 30:
		await get_tree().physics_frame
	
	var img = get_viewport().get_texture().get_image()
	if img:
		img.save_png("res://screenshot_test.png")
	get_tree().quit(0)
