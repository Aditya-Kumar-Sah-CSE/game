extends Node
## Targeted verification test suite for Level 0 Military Training Ground

var _passed := 0
var _failed := 0

func _ready() -> void:
	print("\n==================================================")
	print("  LEVEL 0 TRAINING FACILITY TARGETED TESTS")
	print("==================================================\n")
	
	GameManager.current_mission_id = 0
	var level_scene: PackedScene = load("res://scenes/levels/level_base.tscn")
	var level = level_scene.instantiate()
	add_child(level)
	
	# Test 1: Player spawn position
	var player = level.get_node_or_null("Player")
	_assert(player != null, "T0-01", "Player spawns in Level 0")
	if player:
		var dist_to_spawn = player.position.distance_to(Vector3(0, 0.1, 15.0))
		_assert(dist_to_spawn < 1.0, "T0-02", "Player spawns at orientation pad (0, 0.1, 15)")
	
	# Test 2: Moving target mechanics
	var moving_targets := []
	var stationary_targets := []
	var combat_enemies := []
	for c in level.get_children():
		if c is EnemyController:
			if c.enemy_type == "training_dummy":
				if c.is_moving_target:
					moving_targets.append(c)
				else:
					stationary_targets.append(c)
			elif c.enemy_type == "soldier_basic":
				combat_enemies.append(c)
	
	_assert(stationary_targets.size() == 3, "T0-03", "3 Stationary bullseye targets spawned on range (got %d)" % stationary_targets.size())
	_assert(moving_targets.size() == 2, "T0-04", "2 Moving targets spawned on motorized tracks (got %d)" % moving_targets.size())
	_assert(combat_enemies.size() == 2, "T0-05", "2 Live combat training soldiers spawned in Zone D (got %d)" % combat_enemies.size())
	
	# Test 3: Moving target glide
	if moving_targets.size() > 0:
		var mt = moving_targets[0]
		var initial_x = mt.position.x
		mt._physics_process(0.5)
		_assert(mt.position.x != initial_x, "T0-06", "Moving target slides along X-axis during physics process")
	
	# Test 4: Target hit detection and damage response
	if stationary_targets.size() > 0:
		var st = stationary_targets[0]
		var initial_hp = st.current_health
		st.take_damage(20.0, Vector3.ZERO)
		_assert(st.current_health == initial_hp - 20.0, "T0-07", "Target takes weapon damage accurately (expected %f, got %f)" % [initial_hp - 20.0, st.current_health])
	
	# Test 5: Sequential extraction lock
	var mgr: MissionManager = level.get_node_or_null("MissionManager")
	_assert(mgr != null, "T0-08", "MissionManager active on level")
	if mgr:
		_assert(not mgr.can_extract(), "T0-09", "Extraction is strictly locked while targets remain")
		
		# Complete waypoint_1 and kill 3 dummies
		mgr.report_location_reached("waypoint_1")
		mgr.report_enemy_killed("training_dummy")
		mgr.report_enemy_killed("training_dummy")
		mgr.report_enemy_killed("training_dummy")
		
		_assert(mgr.can_extract(), "T0-10", "Extraction unlocks once all training targets are destroyed")
	
	# Test 6: Extraction beacon visual responds
	if level._extraction_beacon:
		level._update_extraction_beacon_visual(true)
		var lbl: Label3D = level._extraction_beacon.get_node_or_null("Label")
		_assert(lbl and lbl.text.contains("AVAILABLE"), "T0-11", "Extraction beacon displays AVAILABLE when unlocked")
	
	print("\n==================================================")
	print("  TESTS SUMMARY: %d PASSED, %d FAILED" % [_passed, _failed])
	print("==================================================\n")
	
	level.queue_free()
	get_tree().quit(0 if _failed == 0 else 1)


func _assert(condition: bool, code: String, desc: String) -> void:
	if condition:
		print("  [PASS] %s: %s" % [code, desc])
		_passed += 1
	else:
		print("  [FAIL] %s: %s" % [code, desc])
		_failed += 1
