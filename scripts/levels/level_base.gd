extends Node3D
## Base level scene — the gameplay arena for all missions.
## Spawns player, enemies, objectives, and manages mission flow.

const AudioSynthesizer = preload("res://scripts/utils/audio_synthesizer.gd")

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
	var env_type: String = _mission_data.get("environment", "forest")
	match env_type:
		"forest":
			ground_mat.albedo_color = Color(0.18, 0.28, 0.14)
			ground_mat.roughness = 0.85
		"desert":
			ground_mat.albedo_color = Color(0.72, 0.58, 0.38)
			ground_mat.roughness = 0.9
		"military_base":
			ground_mat.albedo_color = Color(0.28, 0.30, 0.29)
			ground_mat.roughness = 0.7
			ground_mat.metallic = 0.1
		"village":
			ground_mat.albedo_color = Color(0.38, 0.32, 0.24)
			ground_mat.roughness = 0.85
		"industrial":
			ground_mat.albedo_color = Color(0.24, 0.24, 0.26)
			ground_mat.roughness = 0.75
			ground_mat.metallic = 0.15
		_:
			ground_mat.albedo_color = Color(0.25, 0.32, 0.22)
			ground_mat.roughness = 0.8
	
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
	
	# Directional Sunlight with soft shadows
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-48, -35, 0)
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	sun.shadow_bias = 0.04
	sun.directional_shadow_max_distance = 65.0
	sun.light_color = Color(1.0, 0.96, 0.88)
	add_child(sun)
	
	# WorldEnvironment with physical sky and ACES tonemapping
	var env := WorldEnvironment.new()
	env.name = "WorldEnvironment"
	var environment := Environment.new()
	
	var sky := Sky.new()
	var sky_mat := PhysicalSkyMaterial.new()
	sky_mat.rayleigh_coefficient = 2.2
	sky_mat.mie_coefficient = 0.006
	sky.sky_material = sky_mat
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.45
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_exposure = 1.05
	
	environment.fog_enabled = true
	environment.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	environment.fog_density = 0.0055
	match env_type:
		"desert":
			environment.fog_light_color = Color(0.78, 0.70, 0.55)
		"military_base":
			environment.fog_light_color = Color(0.58, 0.62, 0.68)
		"forest":
			environment.fog_light_color = Color(0.52, 0.62, 0.52)
		"industrial":
			environment.fog_light_color = Color(0.48, 0.50, 0.54)
		_:
			environment.fog_light_color = Color(0.55, 0.60, 0.65)
	
	env.environment = environment
	add_child(env)
	
	# Spawn 3D modular cover objects and foliage
	_spawn_cover_objects(nav_region)
	
	# Bake navigation
	nav_region.bake_navigation_mesh()


func _spawn_cover_objects(nav_parent: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = GameManager.current_mission_id * 12345
	
	var env_type: String = _mission_data.get("environment", "forest")
	var num_objects := 16 + mini(GameManager.current_mission_id * 2, 24)
	
	for i in num_objects:
		var pos := Vector3(
			rng.randf_range(-40, 40),
			0,
			rng.randf_range(-40, 40)
		)
		# Ensure clean tactical clearing around player spawn (0, 0, 0)
		if pos.length() < 9.0:
			continue
		
		var obj := StaticBody3D.new()
		obj.collision_layer = 1
		obj.position = pos
		obj.rotation_degrees.y = rng.randf_range(0, 360)
		
		var col := CollisionShape3D.new()
		var obj_type := rng.randi() % 5
		var model_node: Node3D = null
		
		match obj_type:
			0:  # Military Sandbag Barricade
				var path := "res://assets/models/props/Sandbags.glb"
				if ResourceLoader.exists(path):
					var scene: PackedScene = load(path)
					if scene:
						model_node = scene.instantiate()
						model_node.scale = Vector3(3.2, 3.2, 3.2)
						var shape := BoxShape3D.new()
						shape.size = Vector3(0.9, 0.75, 0.4)
						col.shape = shape
						col.position.y = 0.38
				
				if model_node == null:
					var box := BoxMesh.new()
					box.size = Vector3(1.5, 0.8, 0.4)
					var m := MeshInstance3D.new()
					m.mesh = box
					m.position.y = 0.4
					model_node = m
					var shape := BoxShape3D.new()
					shape.size = box.size
					col.shape = shape
					col.position.y = 0.4
			
			1:  # Wooden Supply Crate
				var path := "res://assets/models/props/Crate.glb"
				if ResourceLoader.exists(path):
					var scene: PackedScene = load(path)
					if scene:
						model_node = scene.instantiate()
						var s := rng.randf_range(4.5, 6.0)
						model_node.scale = Vector3(s, s, s)
						var shape := BoxShape3D.new()
						shape.size = Vector3(s * 0.16, s * 0.16, s * 0.16)
						col.shape = shape
						col.position.y = shape.size.y / 2.0
				
				if model_node == null:
					var box := BoxMesh.new()
					box.size = Vector3(1.0, 1.0, 1.0)
					var m := MeshInstance3D.new()
					m.mesh = box
					m.position.y = 0.5
					model_node = m
					var shape := BoxShape3D.new()
					shape.size = box.size
					col.shape = shape
					col.position.y = 0.5
			
			2:  # Steel Drum or Gas Cylinder
				var use_barrel := rng.randf() <= 0.65
				var path := "res://assets/models/props/Barrel.glb" if use_barrel else "res://assets/models/props/PropaneTank.glb"
				
				if ResourceLoader.exists(path):
					var scene: PackedScene = load(path)
					if scene:
						model_node = scene.instantiate()
						if use_barrel:
							model_node.scale = Vector3(5.5, 5.5, 5.5)
							var shape := CylinderShape3D.new()
							shape.radius = 0.45
							shape.height = 1.15
							col.shape = shape
							col.position.y = 0.57
						else:
							model_node.scale = Vector3(0.28, 0.28, 0.28)
							var shape := CylinderShape3D.new()
							shape.radius = 0.3
							shape.height = 0.8
							col.shape = shape
							col.position.y = 0.4
				
				if model_node == null:
					var cyl := CylinderMesh.new()
					cyl.top_radius = 0.4
					cyl.bottom_radius = 0.4
					cyl.height = 1.1
					var m := MeshInstance3D.new()
					m.mesh = cyl
					m.position.y = 0.55
					model_node = m
					var shape := CylinderShape3D.new()
					shape.radius = 0.4
					shape.height = 1.1
					col.shape = shape
					col.position.y = 0.55
			
			3:  # Natural Rock Cover
				var rock_path := "res://assets/models/environment/Rock_1.glb" if rng.randf() > 0.5 else "res://assets/models/environment/Rock_2.glb"
				if ResourceLoader.exists(rock_path):
					var scene: PackedScene = load(rock_path)
					if scene:
						model_node = scene.instantiate()
						var r_scale := rng.randf_range(1.1, 1.6)
						model_node.scale = Vector3(r_scale, r_scale, r_scale)
						var shape := SphereShape3D.new()
						shape.radius = 0.55 * r_scale
						col.shape = shape
						col.position.y = shape.radius * 0.7
				
				if model_node == null:
					var sphere := SphereMesh.new()
					sphere.radius = 0.7
					sphere.height = 1.0
					var m := MeshInstance3D.new()
					m.mesh = sphere
					m.position.y = 0.5
					model_node = m
					var shape := SphereShape3D.new()
					shape.radius = 0.7
					col.shape = shape
					col.position.y = 0.5
			
			4:  # Tactical Fuel Canister
				var can_path := "res://assets/models/props/GasCan.glb"
				if ResourceLoader.exists(can_path):
					var scene: PackedScene = load(can_path)
					if scene:
						model_node = scene.instantiate()
						model_node.scale = Vector3(0.22, 0.22, 0.22)
						var shape := BoxShape3D.new()
						shape.size = Vector3(0.4, 0.5, 0.25)
						col.shape = shape
						col.position.y = 0.25
				
				if model_node == null:
					var box := BoxMesh.new()
					box.size = Vector3(0.4, 0.5, 0.25)
					var m := MeshInstance3D.new()
					m.mesh = box
					m.position.y = 0.25
					model_node = m
					var shape := BoxShape3D.new()
					shape.size = box.size
					col.shape = shape
					col.position.y = 0.25
		
		if model_node:
			obj.add_child(model_node)
		obj.add_child(col)
		nav_parent.add_child(obj)
	
	# Trees & Foliage
	var num_trees := 22 if env_type in ["forest", "village"] else 8
	for i in num_trees:
		var tree_pos := Vector3(
			rng.randf_range(-46, 46),
			0,
			rng.randf_range(-46, 46)
		)
		if tree_pos.length() < 9:
			continue
		
		var tree := StaticBody3D.new()
		tree.collision_layer = 1
		tree.position = tree_pos
		tree.rotation_degrees.y = rng.randf_range(0, 360)
		
		var tree_path := "res://assets/models/environment/Tree_1.glb" if rng.randf() > 0.5 else "res://assets/models/environment/Tree_2.glb"
		var tree_inst: Node3D = null
		if ResourceLoader.exists(tree_path):
			var scene: PackedScene = load(tree_path)
			if scene:
				tree_inst = scene.instantiate()
				var t_scale := rng.randf_range(0.9, 1.3)
				tree_inst.scale = Vector3(t_scale, t_scale, t_scale)
				tree.add_child(tree_inst)
		
		if tree_inst == null:
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
		
		# Trunk collision
		var col := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = 0.25
		shape.height = 3.5
		col.shape = shape
		col.position.y = 1.75
		tree.add_child(col)
		
		nav_parent.add_child(tree)
	
	# Bushes (ground cover)
	if env_type in ["forest", "village", "military_base"]:
		var bush_path := "res://assets/models/environment/Bush_1.glb"
		if ResourceLoader.exists(bush_path):
			var bush_scene: PackedScene = load(bush_path)
			if bush_scene:
				for i in 15:
					var b_pos := Vector3(rng.randf_range(-42, 42), 0, rng.randf_range(-42, 42))
					if b_pos.length() < 7:
						continue
					var b_inst: Node3D = bush_scene.instantiate()
					var b_scale := rng.randf_range(0.8, 1.4)
					b_inst.scale = Vector3(b_scale, b_scale, b_scale)
					b_inst.position = b_pos
					b_inst.rotation_degrees.y = rng.randf_range(0, 360)
					nav_parent.add_child(b_inst)


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
	
	# Connect HUD before starting mission so initial objective labels are rendered
	_hud.setup_mission(_mission_manager)
	_mission_manager.start_mission(_mission_data)
	
	_spawn_waypoints()


func _spawn_waypoints() -> void:
	var objectives: Array = _mission_data.get("objectives", [])
	var waypoint_index := 0
	
	for obj in objectives:
		var obj_type: String = obj.get("type", "")
		var target_id: String = str(obj.get("target", ""))
		
		if obj_type == "reach" or obj_type == "defend":
			var pos := Vector3.ZERO
			match target_id:
				"waypoint_1":
					pos = Vector3(0, 0, -22)
				"waypoint_2":
					pos = Vector3(25, 0, -25)
				"extraction":
					pos = Vector3(28, 0, -28)
				"base":
					pos = Vector3(0, 0, 8)
				_:
					pos = Vector3(randf_range(-25, 25), 0, randf_range(-25, -15))
			
			_create_waypoint_beacon(target_id, pos, obj.get("description", "Objective Point"), obj_type == "extraction")
			waypoint_index += 1


func _create_waypoint_beacon(target_id: String, pos: Vector3, label_text: String, is_extraction: bool = false) -> void:
	var area := Area3D.new()
	area.name = "Waypoint_" + target_id
	area.position = pos
	area.collision_layer = 32  # Trigger layer
	area.collision_mask = 2   # Player layer
	
	# Cylinder collision trigger
	var col := CollisionShape3D.new()
	var col_shape := CylinderShape3D.new()
	col_shape.radius = 2.5
	col_shape.height = 2.0
	col.shape = col_shape
	col.position.y = 1.0
	area.add_child(col)
	
	# Glowing floor ring pad
	var ring := MeshInstance3D.new()
	var ring_mesh := CylinderMesh.new()
	ring_mesh.top_radius = 2.4
	ring_mesh.bottom_radius = 2.5
	ring_mesh.height = 0.05
	ring.mesh = ring_mesh
	ring.position.y = 0.02
	
	var ring_mat := StandardMaterial3D.new()
	var glow_color := Color(0.2, 0.9, 0.3) if is_extraction else Color(0.2, 0.7, 1.0)
	ring_mat.albedo_color = glow_color
	ring_mat.emission_enabled = true
	ring_mat.emission = glow_color
	ring_mat.emission_energy_multiplier = 3.0
	ring.material_override = ring_mat
	area.add_child(ring)
	
	# Vertical beacon pillar
	var beam := MeshInstance3D.new()
	var beam_mesh := CylinderMesh.new()
	beam_mesh.top_radius = 0.06
	beam_mesh.bottom_radius = 0.06
	beam_mesh.height = 6.0
	beam.mesh = beam_mesh
	beam.position.y = 3.0
	beam.material_override = ring_mat
	area.add_child(beam)
	
	# Floating billboard label
	var lbl := Label3D.new()
	lbl.text = "🎯 " + label_text
	lbl.position = Vector3(0, 3.2, 0)
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.font_size = 22
	lbl.modulate = glow_color
	area.add_child(lbl)
	
	area.body_entered.connect(func(body: Node3D):
		if body.is_in_group("player"):
			_mission_manager.report_location_reached(target_id)
			AudioManager.play_sfx(AudioSynthesizer.create_chime())
			area.queue_free()
	)
	
	add_child(area)


func _spawn_enemies() -> void:
	var enemy_count: int = _mission_data.get("enemy_count", 3)
	var difficulty: float = _mission_data.get("difficulty", 0.2)
	var enemy_types: Array = _mission_data.get("enemy_types", ["soldier_basic"])
	var rng := RandomNumberGenerator.new()
	rng.seed = GameManager.current_mission_id * 67890
	
	var max_active := 8 if GameManager.is_mobile else 12
	enemy_count = mini(enemy_count, max_active)
	
	var is_tutorial := enemy_types.has("training_dummy")
	
	for i in enemy_count:
		var enemy := EnemyController.new()
		enemy.name = "Enemy_%d" % i
		
		if is_tutorial:
			enemy.enemy_type = "training_dummy"
			# Spread dummies across shooting range
			var dummy_x := -7.0 + float(i) * 7.0
			enemy.position = Vector3(dummy_x, 0.1, -18.0)
			enemy.max_health = 40.0
			enemy.move_speed = 0.0
			enemy.run_speed = 0.0
			enemy.damage = 0.0
			enemy.attack_rate = 0.0
		else:
			var chosen_type: String = enemy_types[i % enemy_types.size()]
			enemy.enemy_type = chosen_type
			
			var pos := Vector3.ZERO
			for attempt in 10:
				pos = Vector3(
					rng.randf_range(-35, 35),
					0.1,
					rng.randf_range(-35, 35)
				)
				if pos.length() > 10:
					break
			enemy.position = pos
			
			# Stats adjusted by type and difficulty
			var hp_mult := 1.5 if chosen_type == "soldier_heavy" else (1.2 if chosen_type == "soldier_elite" else 1.0)
			enemy.max_health = (80.0 + difficulty * 70.0) * hp_mult
			enemy.damage = 8.0 + difficulty * 12.0
			enemy.attack_rate = 0.5 + difficulty * 0.8
			enemy.detection_range = 15.0 + difficulty * 15.0
			enemy.move_speed = (3.5 if chosen_type == "soldier_elite" else 2.5) + difficulty * 2.0
			enemy.run_speed = (6.0 if chosen_type == "soldier_elite" else 4.0) + difficulty * 3.0
			
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
	_mission_manager.report_enemy_killed(enemy.enemy_type)
	if enemy.enemy_type != "enemy":
		_mission_manager.report_enemy_killed("enemy")


func _on_player_died() -> void:
	pass

