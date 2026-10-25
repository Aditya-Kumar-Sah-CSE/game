extends Node3D
## Base level scene — the gameplay arena for all missions.
## Spawns player, enemies, objectives, and manages mission flow.

var _player: PlayerController
var _hud: GameHUD
var _touch_controls: TouchControls
var _pause_menu: PauseMenu
var _result_screen: MissionResultScreen
var _mission_manager: MissionManager

var _enemies: Array[EnemyController] = []
var _mission_data: Dictionary = {}


func _ready() -> void:
	# Get mission data
	_mission_data = MissionDatabase.get_mission(GameManager.current_mission_id)
	if _mission_data.is_empty():
		_mission_data = MissionDatabase.get_mission(0)  # Fallback to tutorial
	
	_build_environment()
	_spawn_player()
	_setup_ui()
	_setup_mission()
	_spawn_enemies()
	
	# Start gameplay
	GameManager.set_state(GameManager.GameState.PLAYING)


func _build_environment() -> void:
	# Ground plane
	var ground := StaticBody3D.new()
	ground.name = "Ground"
	ground.collision_layer = 1  # Environment
	add_child(ground)
	
	var ground_col := CollisionShape3D.new()
	var ground_shape := BoxShape3D.new()
	ground_shape.size = Vector3(100, 0.1, 100)
	ground_col.shape = ground_shape
	ground_col.position = Vector3(0, -0.05, 0)
	ground.add_child(ground_col)
	
	var ground_mesh := MeshInstance3D.new()
	var plane := BoxMesh.new()
	plane.size = Vector3(100, 0.1, 100)
	ground_mesh.mesh = plane
	ground_mesh.position = Vector3(0, -0.05, 0)
	
	var ground_mat := StandardMaterial3D.new()
	# Color based on environment theme
	match _mission_data.get("environment", "forest"):
		"forest":
			ground_mat.albedo_color = Color(0.2, 0.35, 0.15)
		"desert":
			ground_mat.albedo_color = Color(0.7, 0.55, 0.35)
		"military_base":
			ground_mat.albedo_color = Color(0.35, 0.35, 0.3)
		"village":
			ground_mat.albedo_color = Color(0.4, 0.35, 0.25)
		"industrial":
			ground_mat.albedo_color = Color(0.3, 0.3, 0.3)
		_:
			ground_mat.albedo_color = Color(0.3, 0.4, 0.2)
	
	ground_mesh.material_override = ground_mat
	ground.add_child(ground_mesh)
	
	# Navigation region
	var nav_region := NavigationRegion3D.new()
	nav_region.name = "NavigationRegion"
	var nav_mesh := NavigationMesh.new()
	nav_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav_mesh.cell_size = 0.25
	nav_mesh.cell_height = 0.25
	nav_mesh.agent_radius = 0.4
	nav_mesh.agent_height = 1.8
	nav_region.navigation_mesh = nav_mesh
	add_child(nav_region)
	
	# Move environment into nav region for baking
	# ... we'll add obstacles below
	
	# Lighting
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-45, -30, 0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	sun.light_color = Color(1.0, 0.95, 0.85)
	add_child(sun)
	
	# Environment
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.4, 0.5, 0.7)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.3, 0.35, 0.4)
	environment.ambient_light_energy = 0.5
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.5, 0.55, 0.6)
	environment.fog_density = 0.005
	env.environment = environment
	add_child(env)
	
	# Spawn cover objects (walls, barriers, crates)
	_spawn_cover_objects(nav_region)
	
	# Bake navigation
	nav_region.bake_navigation_mesh()


func _spawn_cover_objects(nav_parent: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = GameManager.current_mission_id * 12345  # Deterministic per level
	
	var env_type: String = _mission_data.get("environment", "forest")
	var num_objects := 15 + GameManager.current_mission_id * 2
	num_objects = mini(num_objects, 40)
	
	for i in num_objects:
		var obj := StaticBody3D.new()
		obj.collision_layer = 1  # Environment
		
		var pos := Vector3(
			rng.randf_range(-40, 40),
			0,
			rng.randf_range(-40, 40)
		)
		
		# Don't spawn too close to player spawn
		if pos.length() < 5:
			continue
		
		obj.position = pos
		
		var mesh_inst := MeshInstance3D.new()
		var col := CollisionShape3D.new()
		
		var obj_type := rng.randi() % 4
		
		match obj_type:
			0:  # Wall/barrier
				var box := BoxMesh.new()
				var w := rng.randf_range(1.0, 4.0)
				var h := rng.randf_range(1.0, 2.5)
				box.size = Vector3(w, h, 0.4)
				mesh_inst.mesh = box
				mesh_inst.position.y = h / 2
				
				var shape := BoxShape3D.new()
				shape.size = box.size
				col.shape = shape
				col.position.y = h / 2
				
				var mat := StandardMaterial3D.new()
				match env_type:
					"forest":
						mat.albedo_color = Color(0.4, 0.35, 0.2)
					"desert":
						mat.albedo_color = Color(0.65, 0.5, 0.35)
					"military_base":
						mat.albedo_color = Color(0.4, 0.42, 0.38)
					"village":
						mat.albedo_color = Color(0.55, 0.45, 0.35)
					"industrial":
						mat.albedo_color = Color(0.45, 0.4, 0.35)
				mesh_inst.material_override = mat
			
			1:  # Crate
				var box := BoxMesh.new()
				var s := rng.randf_range(0.6, 1.5)
				box.size = Vector3(s, s, s)
				mesh_inst.mesh = box
				mesh_inst.position.y = s / 2
				
				var shape := BoxShape3D.new()
				shape.size = box.size
				col.shape = shape
				col.position.y = s / 2
				
				var mat := StandardMaterial3D.new()
				mat.albedo_color = Color(0.5, 0.4, 0.2)
				mesh_inst.material_override = mat
			
			2:  # Cylinder (barrel/pillar)
				var cyl := CylinderMesh.new()
				cyl.top_radius = rng.randf_range(0.3, 0.6)
				cyl.bottom_radius = cyl.top_radius
				cyl.height = rng.randf_range(0.8, 1.5)
				mesh_inst.mesh = cyl
				mesh_inst.position.y = cyl.height / 2
				
				var shape := CylinderShape3D.new()
				shape.radius = cyl.top_radius
				shape.height = cyl.height
				col.shape = shape
				col.position.y = cyl.height / 2
				
				var mat := StandardMaterial3D.new()
				mat.albedo_color = Color(0.35, 0.35, 0.3)
				mat.metallic = 0.5
				mesh_inst.material_override = mat
			
			3:  # Rock (sphere-ish)
				var sphere := SphereMesh.new()
				var r := rng.randf_range(0.5, 1.5)
				sphere.radius = r
				sphere.height = r * 1.5
				mesh_inst.mesh = sphere
				mesh_inst.position.y = r * 0.6
				
				var shape := SphereShape3D.new()
				shape.radius = r
				col.shape = shape
				col.position.y = r * 0.6
				
				var mat := StandardMaterial3D.new()
				match env_type:
					"forest":
						mat.albedo_color = Color(0.35, 0.35, 0.3)
					"desert":
						mat.albedo_color = Color(0.6, 0.5, 0.4)
					_:
						mat.albedo_color = Color(0.4, 0.38, 0.35)
				mesh_inst.material_override = mat
		
		obj.rotation_degrees.y = rng.randf_range(0, 360)
		
		obj.add_child(mesh_inst)
		obj.add_child(col)
		nav_parent.add_child(obj)
	
	# Trees (for forest/village) - simple cone + cylinder
	if env_type in ["forest", "village"]:
		for i in range(20):
			var tree := StaticBody3D.new()
			tree.collision_layer = 1
			tree.position = Vector3(
				rng.randf_range(-45, 45),
				0,
				rng.randf_range(-45, 45)
			)
			if tree.position.length() < 8:
				continue
			
			# Trunk
			var trunk := MeshInstance3D.new()
			var trunk_mesh := CylinderMesh.new()
			trunk_mesh.top_radius = 0.15
			trunk_mesh.bottom_radius = 0.2
			trunk_mesh.height = 3.0
			trunk.mesh = trunk_mesh
			trunk.position.y = 1.5
			var trunk_mat := StandardMaterial3D.new()
			trunk_mat.albedo_color = Color(0.35, 0.25, 0.15)
			trunk.material_override = trunk_mat
			tree.add_child(trunk)
			
			# Foliage (cone)
			var foliage := MeshInstance3D.new()
			var cone := CylinderMesh.new()
			cone.top_radius = 0.0
			cone.bottom_radius = 1.5
			cone.height = 3.0
			foliage.mesh = cone
			foliage.position.y = 4.0
			var foliage_mat := StandardMaterial3D.new()
			foliage_mat.albedo_color = Color(0.15, 0.4, 0.12)
			foliage.material_override = foliage_mat
			tree.add_child(foliage)
			
			# Collision (simple cylinder for trunk)
			var col := CollisionShape3D.new()
			var shape := CylinderShape3D.new()
			shape.radius = 0.2
			shape.height = 3.0
			col.shape = shape
			col.position.y = 1.5
			tree.add_child(col)
			
			nav_parent.add_child(tree)


func _spawn_player() -> void:
	_player = PlayerController.new()
	_player.name = "Player"
	_player.position = Vector3(0, 0.1, 0)
	_player.add_to_group("player")
	add_child(_player)
	
	_player.player_died.connect(_on_player_died)


func _setup_ui() -> void:
	# HUD
	_hud = GameHUD.new()
	_hud.name = "HUD"
	add_child(_hud)
	_hud.setup_player(_player)
	_hud.update_mission_name(_mission_data.get("name", "Mission"))
	
	# Touch controls
	_touch_controls = TouchControls.new()
	_touch_controls.name = "TouchControls"
	add_child(_touch_controls)
	_touch_controls.setup_player(_player)
	
	# Pause menu
	_pause_menu = PauseMenu.new()
	_pause_menu.name = "PauseMenu"
	add_child(_pause_menu)
	
	# Mission result screen
	_result_screen = MissionResultScreen.new()
	_result_screen.name = "MissionResult"
	add_child(_result_screen)


func _setup_mission() -> void:
	_mission_manager = MissionManager.new()
	_mission_manager.name = "MissionManager"
	add_child(_mission_manager)
	
	_mission_manager.start_mission(_mission_data)
	_hud.setup_mission(_mission_manager)


func _spawn_enemies() -> void:
	var enemy_count: int = _mission_data.get("enemy_count", 3)
	var difficulty: float = _mission_data.get("difficulty", 0.2)
	var rng := RandomNumberGenerator.new()
	rng.seed = GameManager.current_mission_id * 67890
	
	# Max active enemies for mobile performance
	var max_active := 8 if GameManager.is_mobile else 12
	enemy_count = mini(enemy_count, max_active)
	
	for i in enemy_count:
		var enemy := EnemyController.new()
		enemy.name = "Enemy_%d" % i
		
		# Random position away from player
		var pos := Vector3.ZERO
		for attempt in 10:
			pos = Vector3(
				rng.randf_range(-35, 35),
				0.1,
				rng.randf_range(-35, 35)
			)
			if pos.length() > 10:  # At least 10m from player spawn
				break
		
		enemy.position = pos
		
		# Scale stats by difficulty
		enemy.max_health = 80.0 + difficulty * 70.0
		enemy.damage = 8.0 + difficulty * 12.0
		enemy.attack_rate = 0.5 + difficulty * 0.8
		enemy.detection_range = 15.0 + difficulty * 15.0
		enemy.move_speed = 2.5 + difficulty * 2.0
		enemy.run_speed = 4.0 + difficulty * 3.0
		
		# Patrol points near spawn position
		enemy.patrol_points = [
			pos + Vector3(rng.randf_range(-5, 5), 0, rng.randf_range(-5, 5)),
			pos + Vector3(rng.randf_range(-5, 5), 0, rng.randf_range(-5, 5)),
			pos
		]
		
		enemy.enemy_died.connect(_on_enemy_died)
		
		add_child(enemy)
		_enemies.append(enemy)


func _on_enemy_died(enemy: EnemyController) -> void:
	_enemies.erase(enemy)
	_mission_manager.report_enemy_killed("enemy")


func _on_player_died() -> void:
	# Mission failure is handled by PlayerController → GameManager
	pass
