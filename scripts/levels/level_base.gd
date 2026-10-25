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
var _extraction_beacon: Area3D = null
var _extraction_ready: bool = false


func _process(_delta: float) -> void:
	if _extraction_beacon and is_instance_valid(_extraction_beacon) and _mission_manager:
		var ready: bool = _mission_manager.can_extract()
		if ready != _extraction_ready:
			_extraction_ready = ready
			_update_extraction_beacon_visual(ready)


func _update_extraction_beacon_visual(ready: bool) -> void:
	if not _extraction_beacon or not is_instance_valid(_extraction_beacon):
		return
	var ring: MeshInstance3D = _extraction_beacon.get_node_or_null("Ring")
	var beam: MeshInstance3D = _extraction_beacon.get_node_or_null("Beam")
	var lbl: Label3D = _extraction_beacon.get_node_or_null("Label")
	var color := Color(0.2, 0.95, 0.35) if ready else Color(0.9, 0.5, 0.15)
	
	if ring and ring.material_override is StandardMaterial3D:
		var mat: StandardMaterial3D = ring.material_override
		mat.albedo_color = color
		mat.emission = color
		mat.emission_energy_multiplier = 4.0 if ready else 1.2
	if beam and beam.material_override is StandardMaterial3D:
		var mat: StandardMaterial3D = beam.material_override
		mat.albedo_color = color
		mat.emission = color
		mat.emission_energy_multiplier = 4.0 if ready else 1.2
	if lbl:
		lbl.text = "🚁 EXTRACTION AVAILABLE" if ready else "🔒 EXTRACTION LOCKED (ELIMINATE TARGETS)"
		lbl.modulate = color
	
	if ready and _hud and _hud.has_method("show_tutorial_banner"):
		_hud.show_tutorial_banner("EXTRACTION ZONE ACTIVE — PROCEED TO HELIPAD", 4.0)
		AudioManager.play_sfx(AudioSynthesizer.create_chime())


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
	if GameManager.current_mission_id == 0:
		_build_basic_training_facility(nav_region)
	else:
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
	if GameManager.current_mission_id == 0:
		_player.position = Vector3(0, 0.1, 15.0)
	else:
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
					pos = Vector3(0, 0, -5.0) if GameManager.current_mission_id == 0 else Vector3(0, 0, -22)
				"waypoint_2":
					pos = Vector3(32, 0, -28) if GameManager.current_mission_id == 0 else Vector3(25, 0, -25)
				"extraction":
					pos = Vector3(32, 0, -28) if GameManager.current_mission_id == 0 else Vector3(28, 0, -28)
				"base":
					pos = Vector3(0, 0, 8)
				_:
					pos = Vector3(randf_range(-25, 25), 0, randf_range(-25, -15))
			
			_create_waypoint_beacon(target_id, pos, obj.get("description", "Objective Point"), obj_type == "extraction" or target_id == "waypoint_2")
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
	ring.name = "Ring"
	var ring_mesh := CylinderMesh.new()
	ring_mesh.top_radius = 2.4
	ring_mesh.bottom_radius = 2.5
	ring_mesh.height = 0.05
	ring.mesh = ring_mesh
	ring.position.y = 0.02
	
	var ring_mat := StandardMaterial3D.new()
	var is_locked := (is_extraction and GameManager.current_mission_id == 0)
	var glow_color := Color(0.9, 0.5, 0.15) if is_locked else (Color(0.2, 0.9, 0.3) if is_extraction else Color(0.2, 0.7, 1.0))
	ring_mat.albedo_color = glow_color
	ring_mat.emission_enabled = true
	ring_mat.emission = glow_color
	ring_mat.emission_energy_multiplier = 3.0
	ring.material_override = ring_mat
	area.add_child(ring)
	
	# Vertical beacon pillar
	var beam := MeshInstance3D.new()
	beam.name = "Beam"
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
	lbl.name = "Label"
	lbl.text = "🔒 EXTRACTION LOCKED" if is_locked else ("🎯 " + label_text)
	lbl.position = Vector3(0, 3.2, 0)
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.font_size = 20
	lbl.modulate = glow_color
	area.add_child(lbl)
	
	if is_extraction:
		_extraction_beacon = area
	
	area.body_entered.connect(func(body: Node3D):
		if body.is_in_group("player"):
			if is_extraction and _mission_manager and not _mission_manager.can_extract():
				if _hud and _hud.has_method("show_tutorial_banner"):
					_hud.show_tutorial_banner("OBJECTIVES INCOMPLETE: Eliminate all targets first!", 2.5)
				AudioManager.play_sfx(AudioSynthesizer.create_hit_blip())
				return
			_mission_manager.report_location_reached(target_id)
			AudioManager.play_sfx(AudioSynthesizer.create_chime())
			area.queue_free()
	)
	
	add_child(area)


func _spawn_enemies() -> void:
	if GameManager.current_mission_id == 0:
		# 1. Stationary Targets at varying combat distances
		var target_configs := [
			{"name": "Target_Stationary_1", "pos": Vector3(-5.0, 0.1, -16.0), "moving": false, "range": 0.0, "speed": 0.0},
			{"name": "Target_Stationary_2", "pos": Vector3(0.0, 0.1, -22.0), "moving": false, "range": 0.0, "speed": 0.0},
			{"name": "Target_Stationary_3", "pos": Vector3(5.0, 0.1, -18.0), "moving": false, "range": 0.0, "speed": 0.0},
			# 2. Moving Targets on motorized rail tracks
			{"name": "Target_Moving_1", "pos": Vector3(0.0, 0.1, -26.0), "moving": true, "range": 4.5, "speed": 2.2},
			{"name": "Target_Moving_2", "pos": Vector3(0.0, 0.1, -31.0), "moving": true, "range": 6.0, "speed": 3.0}
		]
		for cfg in target_configs:
			var t := EnemyController.new()
			t.name = cfg["name"]
			t.enemy_type = "training_dummy"
			t.position = cfg["pos"]
			t.max_health = 35.0
			t.move_speed = 0.0
			t.run_speed = 0.0
			t.damage = 0.0
			t.attack_rate = 0.0
			t.is_moving_target = cfg["moving"]
			t.move_range = cfg["range"]
			t.move_speed_custom = cfg["speed"]
			t.enemy_died.connect(_on_enemy_died)
			add_child(t)
			_enemies.append(t)
		
		# 3. Live Combat Training Soldiers in Zone D
		var combat_configs := [
			{"name": "CombatEnemy_1", "pos": Vector3(20.0, 0.1, -20.0)},
			{"name": "CombatEnemy_2", "pos": Vector3(25.0, 0.1, -25.0)}
		]
		for c_cfg in combat_configs:
			var ce := EnemyController.new()
			ce.name = c_cfg["name"]
			ce.enemy_type = "soldier_basic"
			ce.position = c_cfg["pos"]
			ce.max_health = 40.0
			ce.damage = 3.0
			ce.attack_rate = 0.5
			ce.detection_range = 14.0
			ce.move_speed = 2.0
			ce.run_speed = 3.5
			ce.patrol_points = [
				c_cfg["pos"] + Vector3(-3, 0, 0),
				c_cfg["pos"] + Vector3(3, 0, 0),
				c_cfg["pos"]
			]
			ce.enemy_died.connect(_on_enemy_died)
			add_child(ce)
			_enemies.append(ce)
		return

	# Standard enemy spawn for missions 1-50
	var enemy_count: int = _mission_data.get("enemy_count", 3)
	var difficulty: float = _mission_data.get("difficulty", 0.2)
	var enemy_types: Array = _mission_data.get("enemy_types", ["soldier_basic"])
	var rng := RandomNumberGenerator.new()
	rng.seed = GameManager.current_mission_id * 67890
	
	var max_active := 8 if GameManager.is_mobile else 12
	enemy_count = mini(enemy_count, max_active)
	
	for i in enemy_count:
		var enemy := EnemyController.new()
		enemy.name = "Enemy_%d" % i
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


# -------------------------------------------------------------
# LEVEL 0: CAMP BLACKWOOD TACTICAL TRAINING FACILITY BUILDER
# -------------------------------------------------------------

func _build_basic_training_facility(nav_parent: Node3D) -> void:
	# 1. Concrete facility slabs
	# Spawn & Orientation Staging Pad
	var spawn_pad := _create_solid_slab(Vector3(0, 0.02, 14.5), Vector3(16.0, 0.05, 9.0), Color(0.22, 0.23, 0.25))
	nav_parent.add_child(spawn_pad)
	
	# Obstacle Runway Slab (from Z = 10 down to Z = -5)
	var runway_slab := _create_solid_slab(Vector3(0, 0.01, 2.5), Vector3(6.5, 0.03, 17.0), Color(0.24, 0.25, 0.27))
	nav_parent.add_child(runway_slab)
	
	# Shooting Range Firing Platform (at Z = -8)
	var range_slab := _create_solid_slab(Vector3(0, 0.02, -8.0), Vector3(16.0, 0.04, 4.0), Color(0.22, 0.23, 0.25))
	nav_parent.add_child(range_slab)
	
	# Combat Arena Compound Slab (at (21, 0, -21))
	var arena_slab := _create_solid_slab(Vector3(21, 0.01, -21), Vector3(16.0, 0.03, 16.0), Color(0.26, 0.25, 0.24))
	nav_parent.add_child(arena_slab)
	
	# Connecting Pathway: Range to Arena
	var connector_slab := _create_solid_slab(Vector3(10.5, 0.01, -11.0), Vector3(9.0, 0.03, 4.0), Color(0.24, 0.25, 0.27))
	connector_slab.rotation_degrees.y = 35
	nav_parent.add_child(connector_slab)
	
	# Extraction Helipad Slab (at (32, 0, -28))
	_create_helipad(Vector3(32, 0.02, -28), nav_parent)
	
	# 2. Zone A: Spawn & Orientation
	# Rear security sandbag barricade
	for x in [-4.5, -1.5, 1.5, 4.5]:
		var sb := _create_training_prop("res://assets/models/props/Sandbags.glb", Vector3(x, 0, 18.5), 0.0, Vector3(3.2, 3.2, 3.2))
		nav_parent.add_child(sb)
	
	# Left & right security barriers
	for z in [14.0, 16.5]:
		var sb_l := _create_training_prop("res://assets/models/props/Sandbags.glb", Vector3(-6.5, 0, z), 90.0, Vector3(3.2, 3.2, 3.2))
		var sb_r := _create_training_prop("res://assets/models/props/Sandbags.glb", Vector3(6.5, 0, z), 90.0, Vector3(3.2, 3.2, 3.2))
		nav_parent.add_child(sb_l)
		nav_parent.add_child(sb_r)
	
	# Weapon Display Tables
	# Left Table: Sidearms & Shotguns
	var crate_l := _create_training_prop("res://assets/models/props/Crate.glb", Vector3(-4.0, 0, 14.5), 0.0, Vector3(5.0, 5.0, 5.0))
	nav_parent.add_child(crate_l)
	var wpn_p := _create_training_prop("res://assets/models/weapons/Pistol.glb", Vector3(-4.0, 0.85, 14.2), -90.0, Vector3(0.01, 0.01, 0.01))
	var wpn_sg := _create_training_prop("res://assets/models/weapons/Shotgun.glb", Vector3(-4.0, 0.85, 14.8), -90.0, Vector3(0.01, 0.01, 0.01))
	nav_parent.add_child(wpn_p)
	nav_parent.add_child(wpn_sg)
	_create_signpost(Vector3(-4.0, 1.2, 13.5), 0.0, "WEAPON STATION: SIDEARMS", nav_parent)
	
	# Right Table: Primary Rifles
	var crate_r := _create_training_prop("res://assets/models/props/Crate.glb", Vector3(4.0, 0, 14.5), 0.0, Vector3(5.0, 5.0, 5.0))
	nav_parent.add_child(crate_r)
	var wpn_ar := _create_training_prop("res://assets/models/weapons/AssaultRifle.glb", Vector3(4.0, 0.85, 14.2), 90.0, Vector3(0.01, 0.01, 0.01))
	var wpn_sn := _create_training_prop("res://assets/models/weapons/Sniper.glb", Vector3(4.0, 0.85, 14.8), 90.0, Vector3(0.01, 0.01, 0.01))
	nav_parent.add_child(wpn_ar)
	nav_parent.add_child(wpn_sn)
	_create_signpost(Vector3(4.0, 1.2, 13.5), 0.0, "WEAPON STATION: RIFLES", nav_parent)
	
	# Orientation Gantry Archway (Overhead clearance for sprinting)
	_create_signpost(Vector3(0, 3.4, 11.5), 0.0, "CAMP BLACKWOOD — BASIC TRAINING\nADVANCE NORTH THROUGH OBSTACLE COURSE", nav_parent, true)
	
	# 3. Zone B: Movement Obstacle Course
	# Flanking sandbag lines along runway
	for z in [9.0, 6.5, 4.0, 1.5, -1.0, -3.5]:
		var sb_l := _create_training_prop("res://assets/models/props/Sandbags.glb", Vector3(-3.4, 0, z), 90.0, Vector3(3.2, 3.2, 3.2))
		var sb_r := _create_training_prop("res://assets/models/props/Sandbags.glb", Vector3(3.4, 0, z), 90.0, Vector3(3.2, 3.2, 3.2))
		nav_parent.add_child(sb_l)
		nav_parent.add_child(sb_r)
	
	# Sprint prompt trigger at Z = 8.5
	_create_trigger(Vector3(0, 1.0, 8.5), Vector3(6.0, 2.0, 2.0), func():
		if _hud and _hud.has_method("show_tutorial_banner"):
			_hud.show_tutorial_banner("[SPRINT] SPRINT FORWARD TOWARD THE OBSTACLES", 3.0)
	, nav_parent)
	
	# OBSTACLE 1: Jump Hurdle at Z = 4.5 (solid concrete barrier height = 0.65m)
	_create_solid_barrier(Vector3(0, 0.325, 4.5), Vector3(6.4, 0.65, 0.45), nav_parent, Color(0.4, 0.42, 0.44))
	_create_signpost(Vector3(0, 1.4, 4.7), 0.0, "BARRIER 01: [JUMP] TO LEAP OVER", nav_parent)
	
	# Jump landing feedback trigger at Z = 3.2
	_create_trigger(Vector3(0, 1.0, 3.2), Vector3(6.0, 2.0, 1.5), func():
		if _hud and _hud.has_method("show_tutorial_banner"):
			_hud.show_tutorial_banner("✓ HURDLE CLEARED!", 2.5)
		AudioManager.play_sfx(AudioSynthesizer.create_chime())
	, nav_parent)
	
	# OBSTACLE 2: Crouch Clearance Tunnel at Z = 0.0
	# Overhead collision barrier spanning Y = 1.25m to 2.5m (height 1.25m)
	_create_solid_barrier(Vector3(0, 1.9, 0.0), Vector3(6.4, 1.3, 0.6), nav_parent, Color(0.28, 0.3, 0.35))
	# Frame posts on sides
	_create_solid_barrier(Vector3(-3.1, 1.0, 0.0), Vector3(0.4, 2.0, 0.6), nav_parent, Color(0.2, 0.22, 0.25))
	_create_solid_barrier(Vector3(3.1, 1.0, 0.0), Vector3(0.4, 2.0, 0.6), nav_parent, Color(0.2, 0.22, 0.25))
	_create_signpost(Vector3(0, 1.8, 0.4), 0.0, "BARRIER 02: [CROUCH] TO PASS UNDER", nav_parent)
	
	# Crouch passage exit trigger at Z = -2.2
	_create_trigger(Vector3(0, 1.0, -2.2), Vector3(6.0, 2.0, 1.5), func():
		if _hud and _hud.has_method("show_tutorial_banner"):
			_hud.show_tutorial_banner("✓ CROUCH PASSAGE COMPLETED!", 2.5)
		AudioManager.play_sfx(AudioSynthesizer.create_chime())
	, nav_parent)
	
	# 4. Zone C: Tactical Shooting Range
	# Firing booths at Z = -8.0
	for x in [-4.0, 0.0, 4.0]:
		var sb_booth := _create_training_prop("res://assets/models/props/Sandbags.glb", Vector3(x, 0, -8.0), 0.0, Vector3(3.2, 3.2, 3.2))
		nav_parent.add_child(sb_booth)
	
	# Ammo Supply Crates on firing line
	var ammo_crate := _create_training_prop("res://assets/models/props/Crate.glb", Vector3(-5.8, 0, -8.0), 0.0, Vector3(4.5, 4.5, 4.5))
	nav_parent.add_child(ammo_crate)
	_create_signpost(Vector3(0, 1.6, -7.0), 0.0, "FIRING RANGE: [AIM] & DESTROY 3 TARGETS", nav_parent)
	
	# Moving target steel rail tracks
	_create_rail_track(Vector3(0, 0.03, -26.0), 10.0, nav_parent)
	_create_rail_track(Vector3(0, 0.03, -31.0), 13.0, nav_parent)
	
	# 5. Zone D: Combat Training Arena
	# Sandbag perimeter walls around compound (21, 0, -21)
	var arena_walls := [
		Vector3(14.0, 0, -18.0), Vector3(14.0, 0, -24.0),
		Vector3(28.0, 0, -14.0), Vector3(28.0, 0, -20.0), Vector3(28.0, 0, -26.0),
		Vector3(18.0, 0, -28.5), Vector3(24.0, 0, -28.5)
	]
	for pos in arena_walls:
		var sb := _create_training_prop("res://assets/models/props/Sandbags.glb", pos, 0.0, Vector3(3.2, 3.2, 3.2))
		nav_parent.add_child(sb)
	
	# Crates & barrels inside combat compound
	var crates_pos := [Vector3(18.0, 0, -18.0), Vector3(24.0, 0, -22.0), Vector3(19.0, 0, -25.0)]
	for cp in crates_pos:
		var c := _create_training_prop("res://assets/models/props/Crate.glb", cp, 15.0, Vector3(5.0, 5.0, 5.0))
		nav_parent.add_child(c)
	
	var barrels_pos := [Vector3(17.0, 0, -19.5), Vector3(25.5, 0, -21.0), Vector3(21.0, 0, -26.0)]
	for bp in barrels_pos:
		var b := _create_training_prop("res://assets/models/props/Barrel.glb", bp, 0.0, Vector3(5.5, 5.5, 5.5))
		nav_parent.add_child(b)
	
	_create_signpost(Vector3(14.0, 1.5, -14.0), 45.0, "COMBAT ARENA: LIVE TRAINING HOSTILES", nav_parent)
	
	# 6. Boundary Perimeter Rocks & Foliage
	var boundary_elements := [
		Vector3(-25.0, 0, 10.0), Vector3(-28.0, 0, -15.0), Vector3(-26.0, 0, -32.0),
		Vector3(38.0, 0, 10.0), Vector3(40.0, 0, -10.0), Vector3(42.0, 0, -35.0),
		Vector3(-12.0, 0, -42.0), Vector3(12.0, 0, -42.0), Vector3(30.0, 0, -42.0)
	]
	for bp in boundary_elements:
		var rock_p := "res://assets/models/environment/Rock_1.glb" if bp.x < 0 else "res://assets/models/environment/Rock_2.glb"
		var rock := _create_training_prop(rock_p, bp, randf_range(0, 360), Vector3(1.5, 1.5, 1.5))
		nav_parent.add_child(rock)
		var tree := _create_training_prop("res://assets/models/environment/Tree_1.glb", bp + Vector3(2.5, 0, 2.5), 0.0, Vector3(1.1, 1.1, 1.1))
		nav_parent.add_child(tree)


func _create_solid_slab(pos: Vector3, size: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.position = pos
	
	var col := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	col.shape = box_shape
	body.add_child(col)
	
	var m := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	m.mesh = box_mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.8
	m.material_override = mat
	body.add_child(m)
	return body


func _create_solid_barrier(pos: Vector3, size: Vector3, parent: Node3D, color: Color = Color(0.35, 0.35, 0.35)) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.position = pos
	
	var col := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	col.shape = box_shape
	body.add_child(col)
	
	var m := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	m.mesh = box_mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.75
	m.material_override = mat
	body.add_child(m)
	
	parent.add_child(body)
	return body


func _create_training_prop(model_path: String, pos: Vector3, rot_y_deg: float, s: Vector3) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	root.rotation_degrees.y = rot_y_deg
	
	if ResourceLoader.exists(model_path):
		var scene: PackedScene = load(model_path)
		if scene:
			var inst = scene.instantiate()
			inst.scale = s
			root.add_child(inst)
	return root


func _create_signpost(pos: Vector3, rot_y_deg: float, text: String, parent: Node3D, is_large: bool = false) -> void:
	var sign_node := Node3D.new()
	sign_node.position = pos
	sign_node.rotation_degrees.y = rot_y_deg
	
	if is_large:
		# Overhead Entrance Gantry Archway (clear runway beneath)
		var post_mat := StandardMaterial3D.new()
		post_mat.albedo_color = Color(0.2, 0.2, 0.22)
		
		for offset_x in [-2.8, 2.8]:
			var p := MeshInstance3D.new()
			var p_mesh := CylinderMesh.new()
			p_mesh.top_radius = 0.08
			p_mesh.bottom_radius = 0.08
			p_mesh.height = 3.4
			p.mesh = p_mesh
			p.position = Vector3(offset_x, -1.7, 0)
			p.material_override = post_mat
			sign_node.add_child(p)
		
		# Crossbeam
		var beam := MeshInstance3D.new()
		var beam_mesh := BoxMesh.new()
		beam_mesh.size = Vector3(6.0, 0.12, 0.12)
		beam.mesh = beam_mesh
		beam.position = Vector3(0, 0, 0)
		beam.material_override = post_mat
		sign_node.add_child(beam)
		
		# Board
		var board := MeshInstance3D.new()
		var board_mesh := BoxMesh.new()
		board_mesh.size = Vector3(5.6, 1.1, 0.08)
		board.mesh = board_mesh
		board.position = Vector3(0, 0, 0)
		var board_mat := StandardMaterial3D.new()
		board_mat.albedo_color = Color(0.12, 0.14, 0.16)
		board.material_override = board_mat
		sign_node.add_child(board)
		
		# Label
		var lbl := Label3D.new()
		lbl.text = text
		lbl.position = Vector3(0, 0, 0.05)
		lbl.font_size = 18
		lbl.modulate = Color(1.0, 0.9, 0.4)
		sign_node.add_child(lbl)
	else:
		# Post
		var post := MeshInstance3D.new()
		var post_mesh := CylinderMesh.new()
		post_mesh.top_radius = 0.05
		post_mesh.bottom_radius = 0.05
		post_mesh.height = 1.4
		post.mesh = post_mesh
		post.position.y = -post_mesh.height / 2.0
		var post_mat := StandardMaterial3D.new()
		post_mat.albedo_color = Color(0.2, 0.2, 0.22)
		post.material_override = post_mat
		sign_node.add_child(post)
		
		# Board
		var board := MeshInstance3D.new()
		var board_mesh := BoxMesh.new()
		board_mesh.size = Vector3(1.8, 0.5, 0.08)
		board.mesh = board_mesh
		var board_mat := StandardMaterial3D.new()
		board_mat.albedo_color = Color(0.12, 0.14, 0.16)
		board.material_override = board_mat
		sign_node.add_child(board)
		
		# Label
		var lbl := Label3D.new()
		lbl.text = text
		lbl.position = Vector3(0, 0, 0.05)
		lbl.font_size = 14
		lbl.modulate = Color(1.0, 0.9, 0.4)
		sign_node.add_child(lbl)
	
	parent.add_child(sign_node)


func _create_trigger(pos: Vector3, size: Vector3, on_enter: Callable, parent: Node3D) -> Area3D:
	var area := Area3D.new()
	area.position = pos
	area.collision_layer = 32
	area.collision_mask = 2
	
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	area.add_child(col)
	
	var has_fired := false
	area.body_entered.connect(func(body: Node3D):
		if not has_fired and body.is_in_group("player"):
			has_fired = true
			on_enter.call()
	)
	parent.add_child(area)
	return area


func _create_rail_track(pos: Vector3, length: float, parent: Node3D) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.position = pos
	
	var m := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(length, 0.06, 0.35)
	m.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.22, 0.25)
	mat.metallic = 0.85
	mat.roughness = 0.4
	m.material_override = mat
	body.add_child(m)
	parent.add_child(body)
	return body


func _create_helipad(pos: Vector3, parent: Node3D) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	
	# Main concrete pad
	var pad := MeshInstance3D.new()
	var pad_mesh := BoxMesh.new()
	pad_mesh.size = Vector3(10.0, 0.12, 10.0)
	pad.mesh = pad_mesh
	var pad_mat := StandardMaterial3D.new()
	pad_mat.albedo_color = Color(0.2, 0.22, 0.24)
	pad.material_override = pad_mat
	root.add_child(pad)
	
	# Yellow Border Stripe
	var border := MeshInstance3D.new()
	var border_mesh := BoxMesh.new()
	border_mesh.size = Vector3(9.6, 0.13, 9.6)
	border.mesh = border_mesh
	var border_mat := StandardMaterial3D.new()
	border_mat.albedo_color = Color(0.9, 0.75, 0.15)
	border.material_override = border_mat
	root.add_child(border)
	
	# Inner Dark Center
	var center := MeshInstance3D.new()
	var center_mesh := BoxMesh.new()
	center_mesh.size = Vector3(8.8, 0.14, 8.8)
	center.mesh = center_mesh
	center.material_override = pad_mat
	root.add_child(center)
	
	# 'H' Marking: Left vertical bar
	var bar_l := MeshInstance3D.new()
	var b_mesh := BoxMesh.new()
	b_mesh.size = Vector3(0.5, 0.15, 4.0)
	bar_l.mesh = b_mesh
	bar_l.position = Vector3(-1.4, 0, 0)
	bar_l.material_override = border_mat
	root.add_child(bar_l)
	
	# 'H' Marking: Right vertical bar
	var bar_r := MeshInstance3D.new()
	bar_r.mesh = b_mesh
	bar_r.position = Vector3(1.4, 0, 0)
	bar_r.material_override = border_mat
	root.add_child(bar_r)
	
	# 'H' Marking: Crossbar
	var bar_c := MeshInstance3D.new()
	var c_mesh := BoxMesh.new()
	c_mesh.size = Vector3(2.4, 0.15, 0.5)
	bar_c.mesh = c_mesh
	bar_c.material_override = border_mat
	root.add_child(bar_c)
	
	parent.add_child(root)
	return root

