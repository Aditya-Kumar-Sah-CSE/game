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
	# Collision shape
	collision_shape = CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = _stand_height
	collision_shape.shape = capsule
	collision_shape.position = Vector3(0, _stand_height / 2.0, 0)
	add_child(collision_shape)
	
	# Visual mesh (procedural soldier)
	mesh_root = Node3D.new()
	mesh_root.name = "MeshRoot"
	add_child(mesh_root)
	_create_procedural_character()
	
	# Camera pivot
	camera_pivot = Node3D.new()
	camera_pivot.name = "CameraPivot"
	camera_pivot.position = Vector3(0, 1.5, 0)
	add_child(camera_pivot)
	
	# Spring arm for camera collision
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
	
	# Weapon holder (attached to character)
	weapon_holder = Node3D.new()
	weapon_holder.name = "WeaponHolder"
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
	
	# Legs (two cylinders)
	for side in [-1, 1]:
		var leg_mesh := MeshInstance3D.new()
		var leg := CylinderMesh.new()
		leg.top_radius = 0.1
		leg.bottom_radius = 0.12
		leg.height = 0.8
		leg_mesh.mesh = leg
		leg_mesh.position = Vector3(side * 0.15, 0.4, 0)
		var leg_mat := StandardMaterial3D.new()
		leg_mat.albedo_color = Color(0.18, 0.2, 0.15)
		leg_mesh.material_override = leg_mat
		mesh_root.add_child(leg_mesh)
	
	# Arms (two cylinders)
	for side in [-1, 1]:
		var arm_mesh := MeshInstance3D.new()
		var arm := CylinderMesh.new()
		arm.top_radius = 0.07
		arm.bottom_radius = 0.08
		arm.height = 0.6
		arm_mesh.mesh = arm
		arm_mesh.position = Vector3(side * 0.4, 1.1, 0)
		arm_mesh.rotation_degrees = Vector3(0, 0, side * 10)
		var arm_mat := StandardMaterial3D.new()
		arm_mat.albedo_color = Color(0.2, 0.25, 0.18)
		arm_mesh.material_override = arm_mat
		mesh_root.add_child(arm_mesh)


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	
	_handle_gravity(delta)
	_handle_movement(delta)
	_handle_actions()
	
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
	
	# Reload
	if Input.is_action_just_pressed("reload"):
		if _weapon_manager:
			_weapon_manager.try_reload()


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
		camera_pivot.position.y = 1.5


func _update_aim_state() -> void:
	if spring_arm:
		var target_dist := camera_aim_distance if is_aiming else camera_distance
		var tween := create_tween()
		tween.tween_property(spring_arm, "spring_length", target_dist, 0.2)


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
	
	# Simple death visual
	if is_inside_tree() and mesh_root:
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
