extends CharacterBody3D
class_name PlayerController
## Third-person player controller with full movement, camera, and weapon support.
## Supports both desktop (WASD+mouse) and mobile (virtual joystick+touch) input.

signal health_changed(current: float, maximum: float)
signal armor_changed(current: float, maximum: float)
signal player_died()
signal weapon_changed(weapon_data: WeaponData)
signal ammo_changed(current: int, reserve: int)

# Movement
@export_group("Movement")
@export var walk_speed: float = 4.0
@export var run_speed: float = 7.0
@export var sprint_speed: float = 10.0
@export var crouch_speed: float = 2.0
@export var acceleration: float = 8.0
@export var deceleration: float = 10.0
@export var jump_velocity: float = 5.0
@export var gravity_multiplier: float = 1.0
@export var rotation_speed: float = 10.0

# Health
@export_group("Health")
@export var max_health: float = 100.0
@export var max_armor: float = 50.0

# Camera
@export_group("Camera")
@export var camera_sensitivity_x: float = 0.3
@export var camera_sensitivity_y: float = 0.2
@export var camera_min_pitch: float = -60.0
@export var camera_max_pitch: float = 40.0
@export var camera_distance: float = 3.5
@export var camera_aim_distance: float = 1.5
@export var camera_offset: Vector3 = Vector3(0.5, 0.5, 0.0)

# Node references
var camera_pivot: Node3D
var spring_arm: SpringArm3D
var camera: Camera3D
var collision_shape: CollisionShape3D
var weapon_holder: Node3D
var mesh_root: Node3D
var anim_player: AnimationPlayer

# 3D Skeletal character & animation
const CharacterAnimatorClass = preload("res://scripts/player/character_animator.gd")
var character_animator: Node = null
var skeleton: Skeleton3D = null
var is_using_skeletal_mesh: bool = false
var _right_hand_attach: BoneAttachment3D = null
var _backpack_attach: BoneAttachment3D = null
var _model_instance: Node3D = null

# Limb pivots for procedural animation (fallback)
var _left_leg: Node3D
var _right_leg: Node3D
var _left_arm: Node3D
var _right_arm: Node3D
var _walk_cycle: float = 0.0
var _recoil_offset: float = 0.0

# State
var current_health: float
var current_armor: float
var is_dead: bool = false
var is_crouching: bool = false
var is_sprinting: bool = false
var is_aiming: bool = false
var current_speed: float = 0.0

# Camera state
var _camera_rotation_x: float = 0.0
var _camera_rotation_y: float = 0.0

# Weapon state
var current_weapon: Node = null
var _weapon_manager: Node = null

# Mobile input state (set by touch controls)
var mobile_move_input: Vector2 = Vector2.ZERO
var mobile_camera_input: Vector2 = Vector2.ZERO
var mobile_fire_pressed: bool = false
var mobile_aim_pressed: bool = false

# Standing collision height
var _stand_height: float = 1.8
var _crouch_height: float = 1.0

# Gravity
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)


func _ready() -> void:
	current_health = max_health
	current_armor = max_armor
	
	_setup_character()
	
	health_changed.emit(current_health, max_health)
	armor_changed.emit(current_armor, max_armor)


func _setup_character() -> void:
	# Collision shape (preserves exact physics capsule)
	collision_shape = CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = _stand_height
	collision_shape.shape = capsule
	collision_shape.position = Vector3(0, _stand_height / 2.0, 0)
	add_child(collision_shape)
	
	# Visual mesh root
	mesh_root = Node3D.new()
	mesh_root.name = "MeshRoot"
	add_child(mesh_root)
	_setup_character_model()
	
	# Camera pivot (tactical over-the-shoulder positioning)
	camera_pivot = Node3D.new()
	camera_pivot.name = "CameraPivot"
	camera_pivot.position = Vector3(0, 1.45, 0)
	add_child(camera_pivot)
	
	# Spring arm for camera collision avoidance
	spring_arm = SpringArm3D.new()
	spring_arm.name = "SpringArm"
	spring_arm.spring_length = camera_distance
	spring_arm.position = camera_offset
	spring_arm.add_excluded_object(self)
	camera_pivot.add_child(spring_arm)
	
	# Camera
	camera = Camera3D.new()
	camera.name = "PlayerCamera"
	camera.current = true
	camera.fov = 70.0
	spring_arm.add_child(camera)
	
	# Weapon holder (attached to right hand bone if available, else character root)
	weapon_holder = Node3D.new()
	weapon_holder.name = "WeaponHolder"
	if _right_hand_attach:
		_right_hand_attach.add_child(weapon_holder)
		weapon_holder.position = Vector3(0.0, 0.0, 0.0)
		weapon_holder.scale = Vector3(0.01, 0.01, 0.01)
		weapon_holder.rotation_degrees = Vector3(0, 90, 0)
	else:
		weapon_holder.position = Vector3(0.3, 1.2, -0.5)
		add_child(weapon_holder)
	
	# Setup collision layers
	collision_layer = 2  # Player layer
	collision_mask = 1 | 4  # Environment + Enemy
	
	# Weapon manager
	_weapon_manager = preload("res://scripts/weapons/weapon_manager.gd").new()
	_weapon_manager.name = "WeaponManager"
	add_child(_weapon_manager)
	_weapon_manager.setup(self)


func _setup_character_model() -> void:
	var char_path := "res://assets/models/characters/Swat.glb"
	if GameManager.selected_character == "female_infiltrator":
		char_path = "res://assets/models/characters/Soldier_Female.glb"
	
	if ResourceLoader.exists(char_path):
		var scene: PackedScene = load(char_path)
		if scene:
			_model_instance = scene.instantiate()
			mesh_root.add_child(_model_instance)
			
			skeleton = _find_skeleton(_model_instance)
			if skeleton:
				var AnimatorClass = preload("res://scripts/player/character_animator.gd")
				character_animator = AnimatorClass.new()
				anim_player = character_animator.setup(_model_instance, skeleton)
				
				# Setup backpack on Chest bone (scale calibrated for 100x armature)
				var chest_idx := skeleton.find_bone("Chest")
				if chest_idx != -1:
					_backpack_attach = BoneAttachment3D.new()
					_backpack_attach.bone_name = "Chest"
					skeleton.add_child(_backpack_attach)
					if ResourceLoader.exists("res://assets/models/props/Backpack.glb"):
						var bp_scene: PackedScene = load("res://assets/models/props/Backpack.glb")
						if bp_scene:
							var bp = bp_scene.instantiate()
							bp.scale = Vector3(0.0016, 0.0016, 0.0016)
							bp.position = Vector3(0, -0.0004, -0.0012)
							bp.rotation_degrees = Vector3(0, 180, 0)
							_backpack_attach.add_child(bp)
				
				# Setup right hand bone attachment for weapon
				var hand_idx := skeleton.find_bone("Hand.R")
				if hand_idx != -1:
					_right_hand_attach = BoneAttachment3D.new()
					_right_hand_attach.bone_name = "Hand.R"
					skeleton.add_child(_right_hand_attach)
				
				is_using_skeletal_mesh = true
				return
	
	# Fallback if model not available
	_create_procedural_character()


func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found:
			return found
	return null


func _create_procedural_character() -> void:
	# Body (capsule mesh)
	var body_mesh := MeshInstance3D.new()
	var body := CapsuleMesh.new()
	body.radius = 0.3
	body.height = 1.2
	body_mesh.mesh = body
	body_mesh.position = Vector3(0, 1.0, 0)
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.2, 0.25, 0.18)  # Military green
	body_mesh.material_override = body_mat
	mesh_root.add_child(body_mesh)
	
	# Head (sphere)
	var head_mesh := MeshInstance3D.new()
	var head := SphereMesh.new()
	head.radius = 0.18
	head.height = 0.36
	head_mesh.mesh = head
	head_mesh.position = Vector3(0, 1.75, 0)
	var head_mat := StandardMaterial3D.new()
	head_mat.albedo_color = Color(0.7, 0.55, 0.45)  # Skin color
	head_mesh.material_override = head_mat
	mesh_root.add_child(head_mesh)
	
	# Helmet (slightly larger sphere on top)
	var helmet_mesh := MeshInstance3D.new()
	var helmet := SphereMesh.new()
	helmet.radius = 0.2
	helmet.height = 0.3
	helmet_mesh.mesh = helmet
	helmet_mesh.position = Vector3(0, 1.82, 0)
	var helmet_mat := StandardMaterial3D.new()
	helmet_mat.albedo_color = Color(0.15, 0.2, 0.15)  # Dark green
	helmet_mesh.material_override = helmet_mat
	mesh_root.add_child(helmet_mesh)
	
	# Left Leg (hinged at hip)
	_left_leg = Node3D.new()
	_left_leg.name = "LeftLeg"
	_left_leg.position = Vector3(-0.16, 0.8, 0)
	mesh_root.add_child(_left_leg)
	var l_leg_mesh := MeshInstance3D.new()
	var leg_geom := CylinderMesh.new()
	leg_geom.top_radius = 0.1
	leg_geom.bottom_radius = 0.12
	leg_geom.height = 0.8
	l_leg_mesh.mesh = leg_geom
	l_leg_mesh.position = Vector3(0, -0.4, 0)
	var leg_mat := StandardMaterial3D.new()
	leg_mat.albedo_color = Color(0.18, 0.2, 0.15)
	l_leg_mesh.material_override = leg_mat
	_left_leg.add_child(l_leg_mesh)

	# Right Leg (hinged at hip)
	_right_leg = Node3D.new()
	_right_leg.name = "RightLeg"
	_right_leg.position = Vector3(0.16, 0.8, 0)
	mesh_root.add_child(_right_leg)
	var r_leg_mesh := MeshInstance3D.new()
	r_leg_mesh.mesh = leg_geom
	r_leg_mesh.position = Vector3(0, -0.4, 0)
	r_leg_mesh.material_override = leg_mat
	_right_leg.add_child(r_leg_mesh)

	# Left Arm (hinged at shoulder)
	_left_arm = Node3D.new()
	_left_arm.name = "LeftArm"
	_left_arm.position = Vector3(-0.35, 1.35, 0)
	mesh_root.add_child(_left_arm)
	var l_arm_mesh := MeshInstance3D.new()
	var arm_geom := CylinderMesh.new()
	arm_geom.top_radius = 0.07
	arm_geom.bottom_radius = 0.08
	arm_geom.height = 0.6
	l_arm_mesh.mesh = arm_geom
	l_arm_mesh.position = Vector3(0, -0.3, 0)
	var arm_mat := StandardMaterial3D.new()
	arm_mat.albedo_color = Color(0.2, 0.25, 0.18)
	l_arm_mesh.material_override = arm_mat
	_left_arm.add_child(l_arm_mesh)

	# Right Arm (hinged at shoulder)
	_right_arm = Node3D.new()
	_right_arm.name = "RightArm"
	_right_arm.position = Vector3(0.35, 1.35, 0)
	mesh_root.add_child(_right_arm)
	var r_arm_mesh := MeshInstance3D.new()
	r_arm_mesh.mesh = arm_geom
	r_arm_mesh.position = Vector3(0, -0.3, 0)
	r_arm_mesh.material_override = arm_mat
	_right_arm.add_child(r_arm_mesh)


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	
	_handle_gravity(delta)
	_handle_movement(delta)
	_handle_actions()
	if is_using_skeletal_mesh and character_animator:
		_update_skeletal_animation(delta)
	else:
		_update_procedural_animation(delta)
	
	move_and_slide()


func _unhandled_input(event: InputEvent) -> void:
	if is_dead or GameManager.current_state != GameManager.GameState.PLAYING:
		return
	
	# Mouse look (desktop)
	if event is InputEventMouseMotion and not GameManager.is_mobile:
		_camera_rotation_x -= event.relative.x * camera_sensitivity_x * 0.01
		_camera_rotation_y -= event.relative.y * camera_sensitivity_y * 0.01
		_camera_rotation_y = clampf(_camera_rotation_y, deg_to_rad(camera_min_pitch), deg_to_rad(camera_max_pitch))
		
		camera_pivot.rotation = Vector3(_camera_rotation_y, _camera_rotation_x, 0)


func _handle_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * gravity_multiplier * delta


func _handle_movement(delta: float) -> void:
	# Get input direction
	var input_dir := Vector2.ZERO
	
	if GameManager.is_mobile:
		input_dir = mobile_move_input
		# Mobile camera from touch
		if mobile_camera_input.length() > 0.01:
			_camera_rotation_x -= mobile_camera_input.x * camera_sensitivity_x * 0.01
			_camera_rotation_y -= mobile_camera_input.y * camera_sensitivity_y * 0.01
			_camera_rotation_y = clampf(_camera_rotation_y, deg_to_rad(camera_min_pitch), deg_to_rad(camera_max_pitch))
			camera_pivot.rotation = Vector3(_camera_rotation_y, _camera_rotation_x, 0)
	else:
		input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	
	# Determine target speed
	var target_speed := walk_speed
	if is_crouching:
		target_speed = crouch_speed
	elif is_sprinting and input_dir.y < -0.5:
		target_speed = sprint_speed
	elif input_dir.length() > 0.8:
		target_speed = run_speed
	
	# Camera-relative movement direction
	var cam_basis := camera_pivot.global_transform.basis
	var forward := -cam_basis.z
	forward.y = 0
	forward = forward.normalized()
	var right := cam_basis.x
	right.y = 0
	right = right.normalized()
	
	var direction := (forward * -input_dir.y + right * input_dir.x).normalized()
	
	if direction.length() > 0.1:
		# Accelerate
		velocity.x = move_toward(velocity.x, direction.x * target_speed, acceleration * delta)
		velocity.z = move_toward(velocity.z, direction.z * target_speed, acceleration * delta)
		
		# Rotate character to face movement direction (unless aiming)
		if not is_aiming:
			var target_angle := atan2(direction.x, direction.z)
			mesh_root.rotation.y = lerp_angle(mesh_root.rotation.y, target_angle, rotation_speed * delta)
		current_speed = Vector2(velocity.x, velocity.z).length()
	else:
		# Decelerate
		velocity.x = move_toward(velocity.x, 0.0, deceleration * delta)
		velocity.z = move_toward(velocity.z, 0.0, deceleration * delta)
		current_speed = 0.0
	
	# Face camera direction when aiming
	if is_aiming:
		mesh_root.rotation.y = lerp_angle(mesh_root.rotation.y, _camera_rotation_x, rotation_speed * 2.0 * delta)


func _handle_actions() -> void:
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return
	
	# Jump
	if Input.is_action_just_pressed("jump") and is_on_floor() and not is_crouching:
		velocity.y = jump_velocity
	
	# Crouch
	if Input.is_action_just_pressed("crouch"):
		_toggle_crouch()
	
	# Sprint
	is_sprinting = Input.is_action_pressed("sprint") and not is_crouching
	
	# Aim
	var was_aiming := is_aiming
	is_aiming = Input.is_action_pressed("aim") or mobile_aim_pressed
	if is_aiming != was_aiming:
		_update_aim_state()
	
	# Fire
	if Input.is_action_pressed("fire") or mobile_fire_pressed:
		if _weapon_manager:
			_weapon_manager.try_fire()
			_recoil_offset = 0.08
			if character_animator and is_using_skeletal_mesh:
				character_animator.play_one_shot("fire")
	
	# Reload
	if Input.is_action_just_pressed("reload"):
		if _weapon_manager:
			_weapon_manager.try_reload()
			if character_animator and is_using_skeletal_mesh:
				character_animator.play_one_shot("reload")


func _toggle_crouch() -> void:
	is_crouching = !is_crouching
	var capsule: CapsuleShape3D = collision_shape.shape
	if is_crouching:
		capsule.height = _crouch_height
		collision_shape.position.y = _crouch_height / 2.0
		camera_pivot.position.y = 1.0
	else:
		capsule.height = _stand_height
		collision_shape.position.y = _stand_height / 2.0
		camera_pivot.position.y = 1.45


func _update_aim_state() -> void:
	if spring_arm:
		var target_dist := camera_aim_distance if is_aiming else camera_distance
		var target_offset := Vector3(0.65, 0.28, 0.0) if is_aiming else camera_offset
		var target_fov := 52.0 if is_aiming else 70.0
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(spring_arm, "spring_length", target_dist, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(spring_arm, "position", target_offset, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		if camera:
			tween.tween_property(camera, "fov", target_fov, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _update_skeletal_animation(_delta: float) -> void:
	if not character_animator:
		return
	
	var target_anim := "idle"
	if not is_on_floor():
		target_anim = "jump"
	elif is_crouching:
		target_anim = "crouch"
	elif is_aiming and current_speed < 0.2:
		target_anim = "aim"
	elif current_speed > 7.5:
		target_anim = "sprint"
	elif current_speed > 4.5:
		target_anim = "run"
	elif current_speed > 0.2:
		target_anim = "walk"
	else:
		target_anim = "idle"
	
	character_animator.play_anim(target_anim)


func _update_procedural_animation(delta: float) -> void:
	if not _left_leg or not _right_leg or not _left_arm or not _right_arm or not mesh_root:
		return
	
	var h_velocity := Vector2(velocity.x, velocity.z).length()
	
	if h_velocity > 0.1 and is_on_floor():
		var stride_speed := 12.0 if is_sprinting else 8.0
		_walk_cycle += delta * stride_speed
		var leg_swing := sin(_walk_cycle) * (0.6 if is_sprinting else 0.4)
		_left_leg.rotation.x = leg_swing
		_right_leg.rotation.x = -leg_swing
		
		if not is_aiming:
			_left_arm.rotation.x = -leg_swing * 0.7
			_right_arm.rotation.x = leg_swing * 0.7
		
		# Torso vertical bobbing
		mesh_root.position.y = absf(sin(_walk_cycle * 2.0)) * 0.04
	else:
		_left_leg.rotation.x = lerpf(_left_leg.rotation.x, 0.0, 10.0 * delta)
		_right_leg.rotation.x = lerpf(_right_leg.rotation.x, 0.0, 10.0 * delta)
		
		if not is_aiming:
			_left_arm.rotation.x = lerpf(_left_arm.rotation.x, 0.0, 10.0 * delta)
			_right_arm.rotation.x = lerpf(_right_arm.rotation.x, 0.0, 10.0 * delta)
		
		# Breathing idle bobbing
		mesh_root.position.y = sin(Time.get_ticks_msec() * 0.003) * 0.015
	
	if is_aiming:
		# Weapon raised pose
		_left_arm.rotation.x = lerpf(_left_arm.rotation.x, deg_to_rad(-70.0), 12.0 * delta)
		_right_arm.rotation.x = lerpf(_right_arm.rotation.x, deg_to_rad(-80.0), 12.0 * delta)
	
	# Recoil recovery on weapon holder
	if weapon_holder:
		_recoil_offset = move_toward(_recoil_offset, 0.0, 0.5 * delta)
		weapon_holder.position.z = -0.5 + _recoil_offset


func take_damage(amount: float, from_position: Vector3 = Vector3.ZERO) -> void:
	if is_dead:
		return
	
	var remaining := amount
	
	# Armor absorbs damage first
	if current_armor > 0:
		var armor_absorbed := minf(remaining * 0.6, current_armor)
		current_armor -= armor_absorbed
		remaining -= armor_absorbed
		armor_changed.emit(current_armor, max_armor)
	
	current_health -= remaining
	health_changed.emit(current_health, max_health)
	
	if current_health <= 0:
		_die()
	elif character_animator and is_using_skeletal_mesh:
		character_animator.play_one_shot("hit")


func heal(amount: float) -> void:
	current_health = minf(current_health + amount, max_health)
	health_changed.emit(current_health, max_health)


func add_armor(amount: float) -> void:
	current_armor = minf(current_armor + amount, max_armor)
	armor_changed.emit(current_armor, max_armor)


func _die() -> void:
	is_dead = true
	current_health = 0
	health_changed.emit(0, max_health)
	
	# Death visual
	if character_animator and is_using_skeletal_mesh:
		character_animator.play_anim("death", 0.15)
	elif is_inside_tree() and mesh_root:
		var tween := create_tween()
		if tween:
			tween.tween_property(mesh_root, "rotation_degrees:x", -90, 0.5)
	
	player_died.emit()
	
	# Notify game manager after a short delay
	if is_inside_tree():
		await get_tree().create_timer(2.0).timeout
		GameManager.fail_mission("Player eliminated")
	else:
		GameManager.fail_mission("Player eliminated")


func get_aim_origin() -> Vector3:
	if camera:
		return camera.global_position
	return global_position + Vector3.UP * 1.5


func get_aim_direction() -> Vector3:
	if camera:
		return -camera.global_transform.basis.z
	return -global_transform.basis.z
