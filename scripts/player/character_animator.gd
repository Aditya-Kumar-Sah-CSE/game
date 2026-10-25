extends Node
class_name CharacterAnimator
## Procedural & Skeletal Animation Controller for Humanoid Characters (Godot 4)
## Generates and manages skeletal animations on Skeleton3D with smooth cross-fade blending.

var _anim_player: AnimationPlayer
var _skeleton: Skeleton3D
var _skeleton_path_string: String = ""
var _current_anim: String = ""
var _is_one_shot: bool = false
var _blend_time: float = 0.25
var _base_pose_rot: Dictionary = {}
var _base_pose_pos: Dictionary = {}


func setup(root_node: Node, skeleton: Skeleton3D) -> AnimationPlayer:
	_skeleton = skeleton
	
	for i in skeleton.get_bone_count():
		var bname := skeleton.get_bone_name(i)
		_base_pose_rot[bname] = skeleton.get_bone_pose_rotation(i)
		_base_pose_pos[bname] = skeleton.get_bone_pose_position(i)
	
	# Compute hierarchy path string from root_node to skeleton
	var path_parts: Array[String] = []
	var curr: Node = skeleton
	while curr != null and curr != root_node:
		path_parts.push_front(curr.name)
		curr = curr.get_parent()
	_skeleton_path_string = "/".join(path_parts)
	
	_anim_player = AnimationPlayer.new()
	_anim_player.name = "CharacterAnimationPlayer"
	root_node.add_child(_anim_player)
	_anim_player.root_node = NodePath("..")
	
	var lib := AnimationLibrary.new()
	lib.add_animation("idle", _create_idle_anim())
	lib.add_animation("walk", _create_walk_anim())
	lib.add_animation("run", _create_run_anim())
	lib.add_animation("sprint", _create_sprint_anim())
	lib.add_animation("aim", _create_aim_anim())
	lib.add_animation("fire", _create_fire_anim())
	lib.add_animation("reload", _create_reload_anim())
	lib.add_animation("crouch", _create_crouch_anim())
	lib.add_animation("jump", _create_jump_anim())
	lib.add_animation("hit", _create_hit_anim())
	lib.add_animation("death", _create_death_anim())
	
	_anim_player.add_animation_library("", lib)
	play_anim("idle")
	return _anim_player


func play_anim(anim_name: String, custom_blend: float = -1.0) -> void:
	if _anim_player == null:
		return
	if _is_one_shot and _anim_player.is_playing() and _current_anim in ["fire", "reload", "hit", "death"]:
		return
	if _current_anim == anim_name and _anim_player.is_playing():
		return
	
	var blend := _blend_time if custom_blend < 0 else custom_blend
	_current_anim = anim_name
	_is_one_shot = anim_name in ["fire", "reload", "hit", "death"]
	_anim_player.play(anim_name, blend)


func play_one_shot(anim_name: String, return_anim: String = "idle") -> void:
	if _anim_player == null:
		return
	_current_anim = anim_name
	_is_one_shot = true
	_anim_player.play(anim_name, 0.1)
	
	# When finished, return to baseline animation
	var duration: float = _anim_player.get_animation(anim_name).length
	if not _anim_player.is_inside_tree():
		_is_one_shot = false
		return
	var tree := _anim_player.get_tree()
	if tree:
		await tree.create_timer(duration).timeout
		_is_one_shot = false
		play_anim(return_anim, 0.2)


func _get_bone_track_path(bone_name: String) -> String:
	return "%s:%s" % [_skeleton_path_string, bone_name]


# -------------------------------------------------------------
# ANIMATION BUILDERS
# -------------------------------------------------------------

func _create_idle_anim() -> Animation:
	var a := Animation.new()
	a.length = 2.4
	a.loop_mode = Animation.LOOP_LINEAR
	
	# Breathing on Chest & Torso
	_add_rotation_track(a, "Chest", [
		[0.0, Vector3(0.02, 0, 0)],
		[1.2, Vector3(-0.03, 0, 0)],
		[2.4, Vector3(0.02, 0, 0)]
	])
	_add_position_track(a, "Hips", [
		[0.0, Vector3(0, 0, 0)],
		[1.2, Vector3(0, -0.015, 0)],
		[2.4, Vector3(0, 0, 0)]
	])
	
	# Tactical weapon resting pose (arms bent holding rifle at low ready)
	_add_rotation_track(a, "UpperArm.R", [
		[0.0, Vector3(deg_to_rad(-45.0), deg_to_rad(-15.0), deg_to_rad(10.0))],
		[1.2, Vector3(deg_to_rad(-43.0), deg_to_rad(-15.0), deg_to_rad(10.0))],
		[2.4, Vector3(deg_to_rad(-45.0), deg_to_rad(-15.0), deg_to_rad(10.0))]
	])
	_add_rotation_track(a, "LowerArm.R", [
		[0.0, Vector3(deg_to_rad(50.0), deg_to_rad(20.0), 0)],
		[1.2, Vector3(deg_to_rad(52.0), deg_to_rad(20.0), 0)],
		[2.4, Vector3(deg_to_rad(50.0), deg_to_rad(20.0), 0)]
	])
	_add_rotation_track(a, "UpperArm.L", [
		[0.0, Vector3(deg_to_rad(-30.0), deg_to_rad(25.0), deg_to_rad(-20.0))],
		[1.2, Vector3(deg_to_rad(-28.0), deg_to_rad(25.0), deg_to_rad(-20.0))],
		[2.4, Vector3(deg_to_rad(-30.0), deg_to_rad(25.0), deg_to_rad(-20.0))]
	])
	_add_rotation_track(a, "LowerArm.L", [
		[0.0, Vector3(deg_to_rad(65.0), deg_to_rad(-15.0), 0)],
		[1.2, Vector3(deg_to_rad(67.0), deg_to_rad(-15.0), 0)],
		[2.4, Vector3(deg_to_rad(65.0), deg_to_rad(-15.0), 0)]
	])
	return a


func _create_walk_anim() -> Animation:
	var a := Animation.new()
	a.length = 1.0
	a.loop_mode = Animation.LOOP_LINEAR
	
	# Alternating Legs
	_add_rotation_track(a, "UpperLeg.L", [
		[0.0, Vector3(deg_to_rad(25.0), 0, 0)],
		[0.25, Vector3(0, 0, 0)],
		[0.5, Vector3(deg_to_rad(-25.0), 0, 0)],
		[0.75, Vector3(0, 0, 0)],
		[1.0, Vector3(deg_to_rad(25.0), 0, 0)]
	])
	_add_rotation_track(a, "LowerLeg.L", [
		[0.0, Vector3(0, 0, 0)],
		[0.25, Vector3(deg_to_rad(35.0), 0, 0)],
		[0.5, Vector3(0, 0, 0)],
		[0.75, Vector3(deg_to_rad(10.0), 0, 0)],
		[1.0, Vector3(0, 0, 0)]
	])
	_add_rotation_track(a, "UpperLeg.R", [
		[0.0, Vector3(deg_to_rad(-25.0), 0, 0)],
		[0.25, Vector3(0, 0, 0)],
		[0.5, Vector3(deg_to_rad(25.0), 0, 0)],
		[0.75, Vector3(0, 0, 0)],
		[1.0, Vector3(deg_to_rad(-25.0), 0, 0)]
	])
	_add_rotation_track(a, "LowerLeg.R", [
		[0.0, Vector3(0, 0, 0)],
		[0.25, Vector3(deg_to_rad(10.0), 0, 0)],
		[0.5, Vector3(0, 0, 0)],
		[0.75, Vector3(deg_to_rad(35.0), 0, 0)],
		[1.0, Vector3(0, 0, 0)]
	])
	
	# Hip bobbing
	_add_position_track(a, "Hips", [
		[0.0, Vector3(0, 0, 0)],
		[0.25, Vector3(0, 0.03, 0)],
		[0.5, Vector3(0, 0, 0)],
		[0.75, Vector3(0, 0.03, 0)],
		[1.0, Vector3(0, 0, 0)]
	])
	
	# Arm counter-sway holding weapon steady
	_add_rotation_track(a, "UpperArm.R", [
		[0.0, Vector3(deg_to_rad(-48.0), deg_to_rad(-12.0), deg_to_rad(8.0))],
		[0.5, Vector3(deg_to_rad(-42.0), deg_to_rad(-16.0), deg_to_rad(12.0))],
		[1.0, Vector3(deg_to_rad(-48.0), deg_to_rad(-12.0), deg_to_rad(8.0))]
	])
	return a


func _create_run_anim() -> Animation:
	var a := Animation.new()
	a.length = 0.7
	a.loop_mode = Animation.LOOP_LINEAR
	
	# Dynamic Run stride
	_add_rotation_track(a, "UpperLeg.L", [
		[0.0, Vector3(deg_to_rad(45.0), 0, 0)],
		[0.35, Vector3(deg_to_rad(-40.0), 0, 0)],
		[0.7, Vector3(deg_to_rad(45.0), 0, 0)]
	])
	_add_rotation_track(a, "LowerLeg.L", [
		[0.0, Vector3(deg_to_rad(10.0), 0, 0)],
		[0.35, Vector3(deg_to_rad(65.0), 0, 0)],
		[0.7, Vector3(deg_to_rad(10.0), 0, 0)]
	])
	_add_rotation_track(a, "UpperLeg.R", [
		[0.0, Vector3(deg_to_rad(-40.0), 0, 0)],
		[0.35, Vector3(deg_to_rad(45.0), 0, 0)],
		[0.7, Vector3(deg_to_rad(-40.0), 0, 0)]
	])
	_add_rotation_track(a, "LowerLeg.R", [
		[0.0, Vector3(deg_to_rad(65.0), 0, 0)],
		[0.35, Vector3(deg_to_rad(10.0), 0, 0)],
		[0.7, Vector3(deg_to_rad(65.0), 0, 0)]
	])
	
	# Forward torso lean
	_add_rotation_track(a, "Torso", [
		[0.0, Vector3(deg_to_rad(12.0), 0, 0)],
		[0.35, Vector3(deg_to_rad(10.0), 0, 0)],
		[0.7, Vector3(deg_to_rad(12.0), 0, 0)]
	])
	return a


func _create_sprint_anim() -> Animation:
	var a := Animation.new()
	a.length = 0.55
	a.loop_mode = Animation.LOOP_LINEAR
	
	_add_rotation_track(a, "UpperLeg.L", [
		[0.0, Vector3(deg_to_rad(55.0), 0, 0)],
		[0.27, Vector3(deg_to_rad(-50.0), 0, 0)],
		[0.55, Vector3(deg_to_rad(55.0), 0, 0)]
	])
	_add_rotation_track(a, "UpperLeg.R", [
		[0.0, Vector3(deg_to_rad(-50.0), 0, 0)],
		[0.27, Vector3(deg_to_rad(55.0), 0, 0)],
		[0.55, Vector3(deg_to_rad(-50.0), 0, 0)]
	])
	_add_rotation_track(a, "Torso", [
		[0.0, Vector3(deg_to_rad(18.0), 0, 0)],
		[0.55, Vector3(deg_to_rad(18.0), 0, 0)]
	])
	return a


func _create_aim_anim() -> Animation:
	var a := Animation.new()
	a.length = 1.0
	a.loop_mode = Animation.LOOP_LINEAR
	
	# Aim Down Sights (ADS) Weapon High Ready
	_add_rotation_track(a, "UpperArm.R", [
		[0.0, Vector3(deg_to_rad(-78.0), deg_to_rad(-8.0), deg_to_rad(18.0))],
		[0.5, Vector3(deg_to_rad(-77.0), deg_to_rad(-8.0), deg_to_rad(18.0))],
		[1.0, Vector3(deg_to_rad(-78.0), deg_to_rad(-8.0), deg_to_rad(18.0))]
	])
	_add_rotation_track(a, "LowerArm.R", [
		[0.0, Vector3(deg_to_rad(85.0), deg_to_rad(15.0), 0)],
		[1.0, Vector3(deg_to_rad(85.0), deg_to_rad(15.0), 0)]
	])
	_add_rotation_track(a, "UpperArm.L", [
		[0.0, Vector3(deg_to_rad(-55.0), deg_to_rad(35.0), deg_to_rad(-10.0))],
		[1.0, Vector3(deg_to_rad(-55.0), deg_to_rad(35.0), deg_to_rad(-10.0))]
	])
	_add_rotation_track(a, "LowerArm.L", [
		[0.0, Vector3(deg_to_rad(95.0), deg_to_rad(-20.0), 0)],
		[1.0, Vector3(deg_to_rad(95.0), deg_to_rad(-20.0), 0)]
	])
	_add_rotation_track(a, "Head", [
		[0.0, Vector3(deg_to_rad(-5.0), deg_to_rad(-6.0), deg_to_rad(3.0))],
		[1.0, Vector3(deg_to_rad(-5.0), deg_to_rad(-6.0), deg_to_rad(3.0))]
	])
	return a


func _create_fire_anim() -> Animation:
	var a := Animation.new()
	a.length = 0.18
	
	# Recoil kick back and recovery
	_add_rotation_track(a, "UpperArm.R", [
		[0.0, Vector3(deg_to_rad(-85.0), deg_to_rad(-8.0), deg_to_rad(18.0))],
		[0.04, Vector3(deg_to_rad(-95.0), deg_to_rad(-10.0), deg_to_rad(22.0))],
		[0.18, Vector3(deg_to_rad(-85.0), deg_to_rad(-8.0), deg_to_rad(18.0))]
	])
	_add_rotation_track(a, "Chest", [
		[0.0, Vector3(0, 0, 0)],
		[0.04, Vector3(deg_to_rad(-4.0), 0, deg_to_rad(-2.0))],
		[0.18, Vector3(0, 0, 0)]
	])
	return a


func _create_reload_anim() -> Animation:
	var a := Animation.new()
	a.length = 1.75
	
	# Lower left hand to pouch and reload magazine
	_add_rotation_track(a, "UpperArm.L", [
		[0.0, Vector3(deg_to_rad(-55.0), deg_to_rad(35.0), deg_to_rad(-10.0))],
		[0.4, Vector3(deg_to_rad(-10.0), deg_to_rad(10.0), deg_to_rad(-5.0))],
		[0.85, Vector3(deg_to_rad(-65.0), deg_to_rad(25.0), deg_to_rad(-12.0))],
		[1.3, Vector3(deg_to_rad(-70.0), deg_to_rad(30.0), deg_to_rad(-8.0))],
		[1.75, Vector3(deg_to_rad(-55.0), deg_to_rad(35.0), deg_to_rad(-10.0))]
	])
	_add_rotation_track(a, "LowerArm.L", [
		[0.0, Vector3(deg_to_rad(95.0), 0, 0)],
		[0.4, Vector3(deg_to_rad(30.0), 0, 0)],
		[0.85, Vector3(deg_to_rad(105.0), 0, 0)],
		[1.75, Vector3(deg_to_rad(95.0), 0, 0)]
	])
	return a


func _create_crouch_anim() -> Animation:
	var a := Animation.new()
	a.length = 1.0
	a.loop_mode = Animation.LOOP_LINEAR
	
	_add_position_track(a, "Hips", [
		[0.0, Vector3(0, -0.45, 0)],
		[1.0, Vector3(0, -0.45, 0)]
	])
	_add_rotation_track(a, "UpperLeg.L", [
		[0.0, Vector3(deg_to_rad(75.0), deg_to_rad(-10.0), 0)],
		[1.0, Vector3(deg_to_rad(75.0), deg_to_rad(-10.0), 0)]
	])
	_add_rotation_track(a, "LowerLeg.L", [
		[0.0, Vector3(deg_to_rad(-90.0), 0, 0)],
		[1.0, Vector3(deg_to_rad(-90.0), 0, 0)]
	])
	_add_rotation_track(a, "UpperLeg.R", [
		[0.0, Vector3(deg_to_rad(75.0), deg_to_rad(10.0), 0)],
		[1.0, Vector3(deg_to_rad(75.0), deg_to_rad(10.0), 0)]
	])
	_add_rotation_track(a, "LowerLeg.R", [
		[0.0, Vector3(deg_to_rad(-90.0), 0, 0)],
		[1.0, Vector3(deg_to_rad(-90.0), 0, 0)]
	])
	return a


func _create_jump_anim() -> Animation:
	var a := Animation.new()
	a.length = 0.6
	
	_add_rotation_track(a, "UpperLeg.L", [
		[0.0, Vector3(deg_to_rad(30.0), 0, 0)],
		[0.3, Vector3(deg_to_rad(45.0), 0, 0)],
		[0.6, Vector3(0, 0, 0)]
	])
	_add_rotation_track(a, "UpperLeg.R", [
		[0.0, Vector3(deg_to_rad(20.0), 0, 0)],
		[0.3, Vector3(deg_to_rad(45.0), 0, 0)],
		[0.6, Vector3(0, 0, 0)]
	])
	return a


func _create_hit_anim() -> Animation:
	var a := Animation.new()
	a.length = 0.25
	
	_add_rotation_track(a, "Chest", [
		[0.0, Vector3(0, 0, 0)],
		[0.08, Vector3(deg_to_rad(-12.0), deg_to_rad(15.0), 0)],
		[0.25, Vector3(0, 0, 0)]
	])
	_add_rotation_track(a, "Head", [
		[0.0, Vector3(0, 0, 0)],
		[0.08, Vector3(deg_to_rad(8.0), deg_to_rad(-10.0), 0)],
		[0.25, Vector3(0, 0, 0)]
	])
	return a


func _create_death_anim() -> Animation:
	var a := Animation.new()
	a.length = 1.2
	
	_add_position_track(a, "Hips", [
		[0.0, Vector3(0, 0, 0)],
		[0.4, Vector3(0, -0.4, -0.3)],
		[0.8, Vector3(0, -0.8, -0.7)],
		[1.2, Vector3(0, -0.85, -0.8)]
	])
	_add_rotation_track(a, "Torso", [
		[0.0, Vector3(0, 0, 0)],
		[0.4, Vector3(deg_to_rad(-30.0), 0, 0)],
		[0.8, Vector3(deg_to_rad(-70.0), 0, 0)],
		[1.2, Vector3(deg_to_rad(-85.0), 0, 0)]
	])
	return a


# -------------------------------------------------------------
# HELPER TRACK GENERATORS
# -------------------------------------------------------------

func _add_rotation_track(anim: Animation, bone_name: String, keyframes: Array) -> void:
	var bone_idx := _skeleton.find_bone(bone_name)
	if bone_idx == -1:
		return
	
	var track := anim.add_track(Animation.TYPE_ROTATION_3D)
	var track_path := _get_bone_track_path(bone_name)
	anim.track_set_path(track, track_path)
	
	var base_quat: Quaternion = _base_pose_rot.get(bone_name, Quaternion.IDENTITY)
	for k in keyframes:
		var time: float = k[0]
		var euler: Vector3 = k[1]
		var q := base_quat * Quaternion.from_euler(euler)
		anim.rotation_track_insert_key(track, time, q)


func _add_position_track(anim: Animation, bone_name: String, keyframes: Array) -> void:
	var bone_idx := _skeleton.find_bone(bone_name)
	if bone_idx == -1:
		return
	
	var track := anim.add_track(Animation.TYPE_POSITION_3D)
	var track_path := _get_bone_track_path(bone_name)
	anim.track_set_path(track, track_path)
	
	var base_pos: Vector3 = _base_pose_pos.get(bone_name, Vector3.ZERO)
	for k in keyframes:
		var time: float = k[0]
		var offset: Vector3 = k[1]
		anim.position_track_insert_key(track, time, base_pos + offset)
