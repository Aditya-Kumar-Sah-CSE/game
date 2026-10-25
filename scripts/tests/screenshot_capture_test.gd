extends Node

func _ready() -> void:
	print("Testing screenshot capture...")
	var scene = load("res://scenes/levels/level_base.tscn").instantiate()
	add_child(scene)
	
	for i in 5:
		await get_tree().process_frame
	
	var img = get_viewport().get_texture().get_image()
	if img:
		var err = img.save_png("res://screenshot_test.png")
		print("Screenshot save result:", err, "size:", img.get_size())
	else:
		print("Image is null (headless dummy display)")
	get_tree().quit(0)
