extends SceneTree

func _init() -> void:
	print("Testing CharacterAnimator setup...")
	var scene: PackedScene = load("res://assets/models/characters/Swat.glb")
	if not scene:
		print("FAIL: Could not load Swat.glb")
		quit(1)
		return
	
	var inst = scene.instantiate()
	var skel: Skeleton3D = null
	for child in inst.get_node("RootNode/CharacterArmature").get_children():
		if child is Skeleton3D:
			skel = child
			break
	
	print("Bone count = ", skel.get_bone_count())
	var b_names = []
	for b in skel.get_bone_count():
		b_names.append(skel.get_bone_name(b))
	print("Bones: ", ", ".join(b_names))
	
	var CharacterAnimator = preload("res://scripts/player/character_animator.gd")
	var animator = CharacterAnimator.new()
	var anim_player: AnimationPlayer = animator.setup(inst, skel)
	
	if not anim_player:
		print("FAIL: AnimationPlayer was not created")
		quit(1)
		return
	
	var list := anim_player.get_animation_list()
	print("SUCCESS: AnimationPlayer created with %d animations:" % list.size())
	for a in list:
		print("  - ", a, " (length: %.2fs)" % anim_player.get_animation(a).length)
	
	inst.free()
	animator.free()
	print("CharacterAnimator test passed!")
	quit(0)
