extends CharacterBody3D
class_name EnemyController
## Enemy AI with state machine, navigation, health, and combat behavior.

signal enemy_died(enemy: EnemyController)
signal health_changed(current: float, maximum: float)

enum AIState { IDLE, PATROL, INVESTIGATE, ALERT, CHASE, SEEK_COVER, ATTACK, RELOAD, RETREAT, HURT, DEAD }

@export_group("Stats")
@export var enemy_type: String = "soldier_basic"
@export var max_health: float = 100.0
@export var move_speed: float = 3.0
@export var run_speed: float = 5.0
@export var damage: float = 10.0
@export var attack_range: float = 20.0
@export var attack_rate: float = 1.0  # Attacks per second
@export var detection_range: float = 25.0
@export var detection_angle: float = 120.0  # degrees
@export var lose_sight_time: float = 5.0

@export_group("Patrol")
@export var patrol_points: Array[Vector3] = []
@export var patrol_wait_time: float = 2.0

var current_health: float
var current_state: AIState = AIState.IDLE
var _previous_state: AIState = AIState.IDLE

# Navigation
var _nav_agent: NavigationAgent3D
var _target: Node3D = null
var _last_known_position: Vector3 = Vector3.ZERO
var _lose_sight_timer: float = 0.0

# Patrol
var _patrol_index: int = 0
var _patrol_timer: float = 0.0

# Attack
var _attack_cooldown: float = 0.0
var _current_ammo: int = 30
var _max_ammo: int = 30

# Visual
var _mesh_root: Node3D
var _health_bar: MeshInstance3D
const CharacterAnimatorClass = preload("res://scripts/player/character_animator.gd")
var _animator: Node = null
var _skeleton: Skeleton3D = null
var _is_using_skeletal_mesh: bool = false

# Gravity
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)


func _ready() -> void:
	current_health = max_health
	add_to_group("enemy")
	
	collision_layer = 4  # Enemy layer
	collision_mask = 1 | 2  # Environment + Player
	
	_setup_enemy()
	_setup_navigation()


func _setup_enemy() -> void:
	# Collision shape
	var col := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	col.shape = capsule
	col.position = Vector3(0, 0.9, 0)
	add_child(col)
	
	# Visual mesh
	_mesh_root = Node3D.new()
	_mesh_root.name = "MeshRoot"
	add_child(_mesh_root)
	_create_enemy_mesh()


func _create_enemy_mesh() -> void:
	var is_dummy := enemy_type == "training_dummy"
	
	if is_dummy:
		_create_training_dummy_mesh()
		return
	
	# Real 3D Soldier Model
	var model_path := "res://assets/models/characters/Swat.glb"
	if ResourceLoader.exists(model_path):
		var scene: PackedScene = load(model_path)
		if scene:
			var model: Node3D = scene.instantiate()
			_mesh_root.add_child(model)
			
			_skeleton = _find_skeleton(model)
			if _skeleton:
				_animator = CharacterAnimatorClass.new()
				_animator.setup(model, _skeleton)
				_apply_enemy_tint(model)
				
				# Weapon attachment on right hand
				var hand_idx := _skeleton.find_bone("Hand.R")
				if hand_idx != -1:
					var hand_attach := BoneAttachment3D.new()
					hand_attach.bone_name = "Hand.R"
					_skeleton.add_child(hand_attach)
					
					var wpn_path := "res://assets/models/weapons/AssaultRifle.glb"
					if ResourceLoader.exists(wpn_path):
						var wpn_scene: PackedScene = load(wpn_path)
						if wpn_scene:
							var wpn_inst = wpn_scene.instantiate()
							wpn_inst.scale = Vector3(0.0085, 0.0085, 0.0085)
							wpn_inst.rotation_degrees = Vector3(0, 90, 0)
							wpn_inst.position = Vector3(0, -0.0004, -0.001)
							hand_attach.add_child(wpn_inst)
				
				_is_using_skeletal_mesh = true
				return
	
	# Procedural fallback
	_create_procedural_enemy_mesh()


func _create_training_dummy_mesh() -> void:
	# Wooden Stand
	var stand := MeshInstance3D.new()
	var stand_mesh := BoxMesh.new()
	stand_mesh.size = Vector3(0.8, 0.1, 0.8)
	stand.mesh = stand_mesh
	stand.position = Vector3(0, 0.05, 0)
	var wood_mat := StandardMaterial3D.new()
	wood_mat.albedo_color = Color(0.45, 0.32, 0.18)
	wood_mat.roughness = 0.85
	stand.material_override = wood_mat
	_mesh_root.add_child(stand)
	
	# Upright post
	var post := MeshInstance3D.new()
	var post_mesh := CylinderMesh.new()
	post_mesh.top_radius = 0.08
	post_mesh.bottom_radius = 0.08
	post_mesh.height = 1.6
	post.mesh = post_mesh
	post.position = Vector3(0, 0.8, 0)
	post.material_override = wood_mat
	_mesh_root.add_child(post)
	
	# Target Torso silhouette
	var torso := MeshInstance3D.new()
	var torso_mesh := BoxMesh.new()
	torso_mesh.size = Vector3(0.55, 0.85, 0.08)
	torso.mesh = torso_mesh
	torso.position = Vector3(0, 1.25, 0)
	var target_mat := StandardMaterial3D.new()
	target_mat.albedo_color = Color(0.85, 0.78, 0.65)
	target_mat.roughness = 0.9
	torso.material_override = target_mat
	_mesh_root.add_child(torso)
	
	# Target Head
	var head := MeshInstance3D.new()
	var head_mesh := CylinderMesh.new()
	head_mesh.top_radius = 0.14
	head_mesh.bottom_radius = 0.14
	head_mesh.height = 0.28
	head.mesh = head_mesh
	head.position = Vector3(0, 1.78, 0)
	head.material_override = target_mat
	_mesh_root.add_child(head)
	
	# Bullseye Ring Decal
	var bullseye := MeshInstance3D.new()
	var bullseye_mesh := CylinderMesh.new()
	bullseye_mesh.top_radius = 0.18
	bullseye_mesh.bottom_radius = 0.18
	bullseye_mesh.height = 0.02
	bullseye.mesh = bullseye_mesh
	bullseye.rotation_degrees.x = 90
	bullseye.position = Vector3(0, 1.25, 0.05)
	var bullseye_mat := StandardMaterial3D.new()
	bullseye_mat.albedo_color = Color(0.85, 0.15, 0.15)
	bullseye.material_override = bullseye_mat
	_mesh_root.add_child(bullseye)


func _create_procedural_enemy_mesh() -> void:
	# Body
	var body := MeshInstance3D.new()
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.3
	body_mesh.height = 1.2
	body.mesh = body_mesh
	body.position = Vector3(0, 1.0, 0)
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.5, 0.2, 0.15)
	body.material_override = body_mat
	_mesh_root.add_child(body)
	
	# Head
	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.18
	head_mesh.height = 0.36
	head.mesh = head_mesh
	head.position = Vector3(0, 1.75, 0)
	var head_mat := StandardMaterial3D.new()
	head_mat.albedo_color = Color(0.65, 0.5, 0.4)
	head.material_override = head_mat
	_mesh_root.add_child(head)
	
	# Helmet
	var helmet := MeshInstance3D.new()
	var helmet_mesh := SphereMesh.new()
	helmet_mesh.radius = 0.2
	helmet_mesh.height = 0.28
	helmet.mesh = helmet_mesh
	helmet.position = Vector3(0, 1.82, 0)
	var hmat := StandardMaterial3D.new()
	hmat.albedo_color = Color(0.3, 0.15, 0.1)
	helmet.material_override = hmat
	_mesh_root.add_child(helmet)
	
	# Weapon
	var wpn := MeshInstance3D.new()
	var wpn_mesh := BoxMesh.new()
	wpn_mesh.size = Vector3(0.05, 0.07, 0.5)
	wpn.mesh = wpn_mesh
	wpn.position = Vector3(0.35, 1.1, -0.3)
	var wpn_mat := StandardMaterial3D.new()
	wpn_mat.albedo_color = Color(0.12, 0.12, 0.12)
	wpn_mat.metallic = 0.7
	wpn.material_override = wpn_mat
	_mesh_root.add_child(wpn)
	
	# Legs
	for side in [-1, 1]:
		var leg := MeshInstance3D.new()
		var leg_mesh := CylinderMesh.new()
		leg_mesh.top_radius = 0.1
		leg_mesh.bottom_radius = 0.12
		leg_mesh.height = 0.8
		leg.mesh = leg_mesh
		leg.position = Vector3(side * 0.15, 0.4, 0)
		var leg_mat := StandardMaterial3D.new()
		leg_mat.albedo_color = Color(0.35, 0.18, 0.12)
		leg.material_override = leg_mat
		_mesh_root.add_child(leg)


func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found:
			return found
	return null


func _apply_enemy_tint(node: Node) -> void:
	if node is MeshInstance3D:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.42, 0.22, 0.2)
		mat.roughness = 0.6
		node.material_override = mat
	for child in node.get_children():
		_apply_enemy_tint(child)


func _setup_navigation() -> void:
	_nav_agent = NavigationAgent3D.new()
	_nav_agent.path_desired_distance = 0.5
	_nav_agent.target_desired_distance = 1.0
	_nav_agent.avoidance_enabled = true
	_nav_agent.radius = 0.4
	add_child(_nav_agent)


func _physics_process(delta: float) -> void:
	if current_state == AIState.DEAD:
		return
	
	# Gravity
	if not is_on_floor():
		velocity.y -= _gravity * delta
	
	# Update AI
	_update_detection()
	_update_state(delta)
	_update_movement(delta)
	
	move_and_slide()


func _update_detection() -> void:
	if current_state == AIState.DEAD:
		return
	
	# Find player
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		_target = null
		return
	
	var player: Node3D = players[0]
	var dist := global_position.distance_to(player.global_position)
	
	if dist <= detection_range:
		# Check angle
		var to_player := (player.global_position - global_position).normalized()
		var forward := -global_transform.basis.z
		var angle := rad_to_deg(forward.angle_to(to_player))
		
		if angle <= detection_angle / 2.0 or current_state in [AIState.ALERT, AIState.CHASE, AIState.ATTACK]:
			# Line of sight check
			var space_state := get_world_3d().direct_space_state
			var query := PhysicsRayQueryParameters3D.create(
				global_position + Vector3.UP * 1.2,
				player.global_position + Vector3.UP * 1.0
			)
			query.collision_mask = 1  # Environment only
			query.exclude = [get_rid()]
			
			var result := space_state.intersect_ray(query)
			
			if result.is_empty():
				# Can see player
				_target = player
				_last_known_position = player.global_position
				_lose_sight_timer = 0.0
				return
	
	# Cannot see player
	if _target != null:
		_lose_sight_timer += get_physics_process_delta_time()
		if _lose_sight_timer >= lose_sight_time:
			_target = null


func _update_state(delta: float) -> void:
	_previous_state = current_state
	
	match current_state:
		AIState.IDLE:
			if _target:
				current_state = AIState.ALERT
			elif patrol_points.size() > 0:
				current_state = AIState.PATROL
		
		AIState.PATROL:
			if _target:
				current_state = AIState.ALERT
			else:
				_patrol_timer -= delta
				if _patrol_timer <= 0:
					_patrol_index = (_patrol_index + 1) % patrol_points.size()
					_nav_agent.target_position = patrol_points[_patrol_index]
					_patrol_timer = patrol_wait_time
		
		AIState.ALERT:
			if _target:
				var dist := global_position.distance_to(_target.global_position)
				if dist <= attack_range:
					current_state = AIState.ATTACK
				else:
					current_state = AIState.CHASE
			else:
				current_state = AIState.INVESTIGATE
		
		AIState.CHASE:
			if _target == null:
				current_state = AIState.INVESTIGATE
			else:
				var dist := global_position.distance_to(_target.global_position)
				if dist <= attack_range:
					current_state = AIState.ATTACK
				_nav_agent.target_position = _target.global_position
		
		AIState.ATTACK:
			_attack_cooldown -= delta
			if _target == null:
				current_state = AIState.INVESTIGATE
			else:
				var dist := global_position.distance_to(_target.global_position)
				if dist > attack_range * 1.2:
					current_state = AIState.CHASE
				elif _attack_cooldown <= 0:
					_perform_attack()
					_attack_cooldown = 1.0 / attack_rate
					_current_ammo -= 1
					if _current_ammo <= 0:
						current_state = AIState.RELOAD
		
		AIState.RELOAD:
			_attack_cooldown -= delta
			if _attack_cooldown <= 0:
				_current_ammo = _max_ammo
				if _target:
					current_state = AIState.ATTACK
				else:
					current_state = AIState.IDLE
		
		AIState.INVESTIGATE:
			if _target:
				current_state = AIState.ALERT
			else:
				_nav_agent.target_position = _last_known_position
				if _nav_agent.is_navigation_finished():
					current_state = AIState.IDLE
		
		AIState.HURT:
			# Brief stagger then return to combat
			_attack_cooldown -= delta
			if _attack_cooldown <= 0:
				if _target:
					current_state = AIState.ATTACK
				else:
					current_state = AIState.ALERT
	
	if _animator and _is_using_skeletal_mesh:
		match current_state:
			AIState.DEAD:
				_animator.play_anim("death", 0.15)
			AIState.ATTACK:
				_animator.play_anim("aim", 0.15)
			AIState.CHASE:
				_animator.play_anim("run", 0.2)
			AIState.PATROL, AIState.INVESTIGATE:
				_animator.play_anim("walk", 0.2)
			AIState.IDLE, AIState.ALERT:
				_animator.play_anim("idle", 0.2)


func _update_movement(delta: float) -> void:
	if current_state in [AIState.DEAD, AIState.HURT, AIState.ATTACK]:
		# No movement during these states (attack can have slight movement)
		if current_state == AIState.ATTACK:
			# Face target
			if _target:
				var look_pos := _target.global_position
				look_pos.y = global_position.y
				if look_pos.distance_to(global_position) > 0.1:
					var dir := (look_pos - global_position).normalized()
					var target_angle := atan2(dir.x, dir.z)
					_mesh_root.rotation.y = lerp_angle(_mesh_root.rotation.y, target_angle, 5.0 * delta)
		velocity.x = 0
		velocity.z = 0
		return
	
	if _nav_agent.is_navigation_finished():
		velocity.x = 0
		velocity.z = 0
		return
	
	var next_pos := _nav_agent.get_next_path_position()
	var direction := (next_pos - global_position).normalized()
	direction.y = 0
	
	var speed := run_speed if current_state == AIState.CHASE else move_speed
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	
	# Face movement direction
	if direction.length() > 0.1:
		var target_angle := atan2(direction.x, direction.z)
		_mesh_root.rotation.y = lerp_angle(_mesh_root.rotation.y, target_angle, 8.0 * delta)


func _perform_attack() -> void:
	if _target == null or current_state == AIState.DEAD:
		return
	
	if _animator and _is_using_skeletal_mesh:
		_animator.play_one_shot("fire")
	
	# Raycast attack
	var origin := global_position + Vector3.UP * 1.2
	var target_pos := _target.global_position + Vector3.UP * 1.0
	
	# Add some inaccuracy
	var spread := 0.05
	target_pos += Vector3(
		randf_range(-spread, spread),
		randf_range(-spread, spread),
		randf_range(-spread, spread)
	) * global_position.distance_to(_target.global_position)
	
	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(origin, target_pos)
	query.collision_mask = 1 | 2  # Environment + Player
	query.exclude = [get_rid()]
	
	var result := space_state.intersect_ray(query)
	
	if result and result["collider"].is_in_group("player"):
		if result["collider"].has_method("take_damage"):
			result["collider"].take_damage(damage, global_position)


func take_damage(amount: float, from_position: Vector3 = Vector3.ZERO) -> void:
	if current_state == AIState.DEAD:
		return
	
	current_health -= amount
	health_changed.emit(current_health, max_health)
	
	# Alert to attacker position
	_last_known_position = from_position
	
	if current_health <= 0:
		_die()
	else:
		# Brief hurt state
		current_state = AIState.HURT
		_attack_cooldown = 0.3  # Stagger duration
		if _animator and _is_using_skeletal_mesh:
			_animator.play_one_shot("hit")
		
		# Find the player as target
		if _target == null:
			var players := get_tree().get_nodes_in_group("player")
			if not players.is_empty():
				_target = players[0]


func _die() -> void:
	current_state = AIState.DEAD
	current_health = 0
	
	# Disable collision
	collision_layer = 0
	collision_mask = 0
	
	# Death animation
	if _animator and _is_using_skeletal_mesh:
		_animator.play_anim("death", 0.15)
	elif is_inside_tree() and _mesh_root:
		var tween := create_tween()
		if tween:
			tween.tween_property(_mesh_root, "rotation_degrees:x", -90, 0.4)
			tween.parallel().tween_property(_mesh_root, "position:y", -0.3, 0.4)
	
	# Notify
	GameManager.record_enemy_killed()
	enemy_died.emit(self)
	
	# Remove after delay
	if is_inside_tree():
		await get_tree().create_timer(5.0).timeout
		queue_free()
