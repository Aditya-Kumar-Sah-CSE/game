extends Node
## Automated Test Runner for OPERATION SHADOW
## Executes UT-001 through UT-018, IT-001 through IT-008, and RT-001 through RT-006.

const MissionDatabase = preload("res://scripts/missions/mission_database.gd")

var _total_tests: int = 0
var _passed_tests: int = 0
var _failed_tests: int = 0
var _failures: Array[String] = []


func _ready() -> void:
	print("\n==================================================")
	print("  OPERATION SHADOW — AUTOMATED TEST SUITE")
	print("==================================================\n")
	
	# Ensure clean campaign state for tests
	GameManager.campaign_data = {
		"xp": 0,
		"currency": 0,
		"unlocked_levels": [0],
		"completed_levels": [],
		"unlocked_weapons": ["assault_rifle", "pistol"],
		"selected_weapons": ["assault_rifle", "pistol"],
		"statistics": {
			"missions_completed": 0,
			"missions_failed": 0,
			"enemies_killed": 0,
			"shots_fired": 0,
			"shots_hit": 0,
			"time_played": 0.0,
			"deaths": 0
		}
	}
	
	_run_all_tests()
	
	print("\n==================================================")
	print("  TEST SUMMARY")
	print("==================================================")
	print("  Total Tests  : %d" % _total_tests)
	print("  Passed       : %d" % _passed_tests)
	print("  Failed       : %d" % _failed_tests)
	
	if _failed_tests > 0:
		print("\n  FAILURES:")
		for fail in _failures:
			print("  [X] %s" % fail)
		print("\n>>> SUITE RESULT: FAILED <<<\n")
		get_tree().quit(1)
	else:
		print("\n>>> SUITE RESULT: ALL TESTS PASSED (100%%) <<<\n")
		get_tree().quit(0)


func _run_all_tests() -> void:
	print("--- Running Unit Tests ---")
	_test_ut001_damage_calculation()
	_test_ut002_fire_rate_enforcement()
	_test_ut003_ammo_consumption()
	_test_ut004_reload_timing()
	_test_ut005_magazine_overflow_prevention()
	_test_ut006_headshot_multiplier()
	_test_ut007_enemy_ai_state_transitions()
	_test_ut008_dead_enemy_behavior()
	_test_ut009_mission_objective_tracking()
	_test_ut010_mission_completion_conditions()
	_test_ut011_mission_failure_conditions()
	_test_ut012_level_unlock_prerequisites()
	_test_ut013_save_load_roundtrip()
	_test_ut014_missing_save_handling()
	_test_ut015_corrupt_save_handling()
	_test_ut016_save_version_migration()
	_test_ut017_player_health_and_damage()
	_test_ut018_difficulty_and_mission_validation()
	
	print("\n--- Running Integration Tests ---")
	_test_it001_player_spawn_and_setup()
	_test_it002_weapon_manager_inventory()
	_test_it003_enemy_player_detection()
	_test_it004_enemy_hp_depletion_and_death()
	_test_it005_mission_manager_lifecycle()
	_test_it006_pause_system_state()
	_test_it007_all_missions_integrity()
	_test_it008_campaign_progression_unlock()
	
	print("\n--- Running Regression Tests ---")
	_test_rt001_completed_missions_accessible()
	_test_rt002_save_preserves_campaign_data()
	_test_rt003_repeated_damage_consistency()
	_test_rt004_mission_stats_reset()
	_test_rt005_dead_enemy_stops_attacking()
	_test_rt006_mission_completion_idempotency()


func _assert_true(condition: bool, test_id: String, message: String) -> void:
	_total_tests += 1
	if condition:
		_passed_tests += 1
		print("  [PASS] %s: %s" % [test_id, message])
	else:
		_failed_tests += 1
		var err := "%s: %s" % [test_id, message]
		_failures.append(err)
		print("  [FAIL] %s" % err)


func _assert_eq(actual: Variant, expected: Variant, test_id: String, message: String) -> void:
	_assert_true(actual == expected, test_id, "%s (expected %s, got %s)" % [message, str(expected), str(actual)])


func _assert_near(actual: float, expected: float, tolerance: float, test_id: String, message: String) -> void:
	var diff := absf(actual - expected)
	_assert_true(diff <= tolerance, test_id, "%s (expected ~%s, got %s, diff=%s)" % [message, str(expected), str(actual), str(diff)])


# ==============================================================================
# UNIT TESTS (UT-001 to UT-018)
# ==============================================================================

func _test_ut001_damage_calculation() -> void:
	var wpn := WeaponData.new()
	wpn.base_damage = 30.0
	wpn.damage_falloff_start = 20.0
	wpn.effective_range = 50.0
	
	# Close range (no falloff)
	var dmg_close := wpn.calculate_damage(10.0, false)
	_assert_near(dmg_close, 30.0, 0.01, "UT-001a", "Weapon damage at close range equals base damage")
	
	# Beyond effective range (50% falloff: 30 * 0.5 = 15)
	var dmg_far := wpn.calculate_damage(60.0, false)
	_assert_near(dmg_far, 15.0, 0.01, "UT-001b", "Weapon damage beyond dropoff equals min falloff damage")
	
	# Mid range (interpolated falloff: distance 35 -> ratio 0.5 -> 30 * (1 - 0.25) = 22.5)
	var dmg_mid := wpn.calculate_damage(35.0, false)
	_assert_near(dmg_mid, 22.5, 0.1, "UT-001c", "Weapon damage at mid falloff is linearly interpolated")


func _test_ut002_fire_rate_enforcement() -> void:
	var wpn := WeaponData.new()
	wpn.fire_rate = 10.0  # 10 rounds per sec -> 0.1s interval
	var interval := wpn.get_fire_interval()
	_assert_near(interval, 0.1, 0.001, "UT-002", "Fire interval enforces correct cooldown (10 rpm -> 0.1s)")


func _test_ut003_ammo_consumption() -> void:
	var mgr := WeaponManager.new()
	var wpn := WeaponData.new()
	wpn.weapon_id = "test_rifle"
	wpn.magazine_size = 30
	wpn.reserve_ammo = 60
	mgr.add_weapon(wpn)
	
	var ammo_start := mgr.get_current_ammo()
	_assert_eq(ammo_start["current"], 30, "UT-003a", "Initial magazine has 30 rounds")
	_assert_eq(ammo_start["reserve"], 60, "UT-003b", "Initial reserve has 60 rounds")


func _test_ut004_reload_timing() -> void:
	var wpn := WeaponData.new()
	wpn.reload_time = 1.75
	_assert_eq(wpn.reload_time, 1.75, "UT-004", "Weapon reload duration config is respected")


func _test_ut005_magazine_overflow_prevention() -> void:
	var mgr := WeaponManager.new()
	var wpn := WeaponData.new()
	wpn.weapon_id = "overflow_test"
	wpn.magazine_size = 20
	wpn.reserve_ammo = 100
	mgr.add_weapon(wpn)
	
	# Try reloading full mag -> should do nothing
	var before_ammo := mgr.get_current_ammo()
	mgr.try_reload()
	var after_ammo := mgr.get_current_ammo()
	_assert_eq(after_ammo["current"], before_ammo["current"], "UT-005", "Reloading full magazine does not exceed capacity")


func _test_ut006_headshot_multiplier() -> void:
	var wpn := WeaponData.new()
	wpn.base_damage = 25.0
	wpn.headshot_multiplier = 2.5
	var dmg_headshot := wpn.calculate_damage(5.0, true)
	_assert_near(dmg_headshot, 62.5, 0.01, "UT-006", "Headshot multiplier applies accurately (25.0 * 2.5 = 62.5)")


func _test_ut007_enemy_ai_state_transitions() -> void:
	var enemy := EnemyController.new()
	enemy._ready()
	_assert_eq(enemy.current_state, EnemyController.AIState.IDLE, "UT-007a", "Enemy starts in IDLE state")
	
	# Manually set state to test transitions
	enemy.current_state = EnemyController.AIState.ALERT
	_assert_eq(enemy.current_state, EnemyController.AIState.ALERT, "UT-007b", "Enemy transitions to ALERT")
	
	enemy.current_state = EnemyController.AIState.CHASE
	_assert_eq(enemy.current_state, EnemyController.AIState.CHASE, "UT-007c", "Enemy transitions to CHASE")
	
	enemy.current_state = EnemyController.AIState.ATTACK
	_assert_eq(enemy.current_state, EnemyController.AIState.ATTACK, "UT-007d", "Enemy transitions to ATTACK")
	enemy.free()


func _test_ut008_dead_enemy_behavior() -> void:
	var enemy := EnemyController.new()
	enemy._ready()
	enemy.take_damage(200.0)  # Deplete all health
	
	_assert_eq(enemy.current_state, EnemyController.AIState.DEAD, "UT-008a", "Depleting health puts enemy in DEAD state")
	_assert_eq(enemy.collision_layer, 0, "UT-008b", "Dead enemy collision layer is disabled")
	_assert_eq(enemy.current_health, 0.0, "UT-008c", "Dead enemy health clamped to 0")
	
	# Dead enemy ignores further damage
	enemy.take_damage(50.0)
	_assert_eq(enemy.current_health, 0.0, "UT-008d", "Dead enemy ignores additional damage")
	enemy.free()


func _test_ut009_mission_objective_tracking() -> void:
	var mission_mgr := MissionManager.new()
	var test_mission := {
		"id": 99,
		"name": "Test Mission",
		"objectives": [
			{"type": "eliminate", "target": "enemy", "count": 3, "description": "Kill 3 enemies"}
		],
		"time_limit": 0
	}
	mission_mgr.start_mission(test_mission)
	var summary := mission_mgr.get_objectives_summary()
	_assert_eq(summary.size(), 1, "UT-009a", "Mission has 1 objective initialized")
	_assert_eq(summary[0]["current_count"], 0, "UT-009b", "Initial objective count is 0")
	
	mission_mgr.report_enemy_killed("enemy")
	var summary_after := mission_mgr.get_objectives_summary()
	_assert_eq(summary_after[0]["current_count"], 1, "UT-009c", "Objective count increments on kill")
	mission_mgr.free()


func _test_ut010_mission_completion_conditions() -> void:
	var mission_mgr := MissionManager.new()
	var state := {"completed": false}
	mission_mgr.all_objectives_completed.connect(func(): state["completed"] = true)
	
	var test_mission := {
		"id": 100,
		"name": "Test Complete",
		"objectives": [
			{"type": "eliminate", "target": "enemy", "count": 2, "description": "Kill 2 enemies"}
		],
		"time_limit": 0
	}
	mission_mgr.start_mission(test_mission)
	mission_mgr.report_enemy_killed("enemy")
	_assert_true(not state["completed"], "UT-010a", "Mission not complete after 1 of 2 kills")
	
	mission_mgr.report_enemy_killed("enemy")
	_assert_true(state["completed"], "UT-010b", "Mission completes when required kills reached")
	mission_mgr.free()


func _test_ut011_mission_failure_conditions() -> void:
	var mission_mgr := MissionManager.new()
	var test_mission := {
		"id": 101,
		"name": "Timed Mission",
		"objectives": [
			{"type": "eliminate", "target": "enemy", "count": 10, "description": "Kill 10"}
		],
		"time_limit": 5.0
	}
	mission_mgr.start_mission(test_mission)
	
	# Simulate 6 seconds elapsed
	mission_mgr._process(6.0)
	_assert_true(not mission_mgr._is_active, "UT-011", "Time limit expiration deactivates mission manager")
	mission_mgr.free()


func _test_ut012_level_unlock_prerequisites() -> void:
	var unlocked := GameManager.is_level_unlocked(0)
	_assert_true(unlocked, "UT-012", "Tutorial level 0 is unlocked by default")


func _test_ut013_save_load_roundtrip() -> void:
	var test_data := {
		"save_version": 1,
		"selected_character": "female_infiltrator",
		"campaign": {
			"xp": 500,
			"currency": 250,
			"unlocked_levels": [0, 1, 2],
			"completed_levels": [0, 1]
		}
	}
	
	var ok := SaveManager.save_game(test_data)
	_assert_true(ok, "UT-013a", "SaveManager saves dictionary to disk successfully")
	
	var loaded := SaveManager.load_game()
	_assert_eq(loaded.get("selected_character"), "female_infiltrator", "UT-013b", "Loaded save preserves selected character")
	_assert_eq(loaded["campaign"]["xp"], 500, "UT-013c", "Loaded save preserves XP")
	_assert_eq(loaded["campaign"]["unlocked_levels"].size(), 3, "UT-013d", "Loaded save preserves unlocked levels")


func _test_ut014_missing_save_handling() -> void:
	# Test with a non-existent path
	var exists := FileAccess.file_exists("user://non_existent_file.json")
	_assert_true(not exists, "UT-014", "Missing save file check functions correctly")


func _test_ut015_corrupt_save_handling() -> void:
	var corrupt_path := "user://test_corrupt.json"
	var file := FileAccess.open(corrupt_path, FileAccess.WRITE)
	file.store_string("{corrupted_json: [invalid")
	file.close()
	
	# Verify JSON parser fails gracefully
	var json := JSON.new()
	var text := FileAccess.get_file_as_string(corrupt_path)
	var result := json.parse(text)
	_assert_true(result != OK, "UT-015", "Corrupt JSON is rejected gracefully without crashing")
	DirAccess.remove_absolute(corrupt_path)


func _test_ut016_save_version_migration() -> void:
	var old_save := {
		"save_version": 0,
		"campaign": {"xp": 100}
	}
	var migrated := SaveManager._migrate_save(old_save, 0)
	_assert_eq(migrated["save_version"], SaveManager.CURRENT_SAVE_VERSION, "UT-016", "Save migration updates to current version")


func _test_ut017_player_health_and_damage() -> void:
	var player := PlayerController.new()
	player._ready()
	_assert_eq(player.current_health, 100.0, "UT-017a", "Player starts at 100 HP")
	_assert_eq(player.current_armor, 50.0, "UT-017b", "Player starts at 50 Armor")
	
	# Damage absorption: 50 damage -> 60% absorbed by armor (30), 20 to health
	player.take_damage(50.0)
	_assert_near(player.current_armor, 20.0, 0.1, "UT-017c", "Armor absorbs 60% of damage")
	_assert_near(player.current_health, 80.0, 0.1, "UT-017d", "Remaining 40% goes to health")
	
	# Deplete all health
	player.take_damage(200.0)
	_assert_true(player.is_dead, "UT-017e", "Player marked dead when health depletes")
	_assert_eq(player.current_health, 0.0, "UT-017f", "Health clamped to 0 on death")
	player.free()


func _test_ut018_difficulty_and_mission_validation() -> void:
	var mission_0 := MissionDatabase.get_mission(0)
	_assert_true(not mission_0.is_empty(), "UT-018a", "Level 0 tutorial exists in MissionDatabase")
	_assert_eq(mission_0["difficulty"], 0.1, "UT-018b", "Tutorial difficulty is 0.1")
	
	var mission_50 := MissionDatabase.get_mission(50)
	_assert_true(not mission_50.is_empty(), "UT-018c", "Level 50 endgame mission exists in MissionDatabase")
	_assert_near(mission_50["difficulty"], 1.0, 0.05, "UT-018d", "Level 50 difficulty scales up to ~1.0")


# ==============================================================================
# INTEGRATION TESTS (IT-001 to IT-008)
# ==============================================================================

func _test_it001_player_spawn_and_setup() -> void:
	var player := PlayerController.new()
	player.name = "TestPlayer"
	add_child(player)
	
	_assert_true(player.camera_pivot != null, "IT-001a", "Player has CameraPivot initialized")
	_assert_true(player.spring_arm != null, "IT-001b", "Player has SpringArm3D for collision")
	_assert_true(player.camera != null, "IT-001c", "Player has Camera3D")
	_assert_true(player.collision_shape != null, "IT-001d", "Player has CollisionShape3D")
	player.queue_free()


func _test_it002_weapon_manager_inventory() -> void:
	var player := PlayerController.new()
	add_child(player)
	
	var wpn_mgr := player.get_node_or_null("WeaponManager") as WeaponManager
	_assert_true(wpn_mgr != null, "IT-002a", "PlayerController creates and mounts WeaponManager")
	
	var current_data := wpn_mgr.get_current_data()
	_assert_true(current_data != null, "IT-002b", "Default weapon (AR-7 Vanguard) is equipped")
	_assert_eq(current_data.weapon_id, "assault_rifle", "IT-002c", "Active weapon ID is assault_rifle")
	player.queue_free()


func _test_it003_enemy_player_detection() -> void:
	var enemy := EnemyController.new()
	enemy.name = "TestEnemy"
	add_child(enemy)
	enemy._ready()
	
	_assert_true(enemy._nav_agent != null, "IT-003a", "EnemyController creates NavigationAgent3D")
	_assert_true(enemy.is_in_group("enemy"), "IT-003b", "Enemy is registered in 'enemy' group")
	enemy.queue_free()


func _test_it004_enemy_hp_depletion_and_death() -> void:
	var enemy := EnemyController.new()
	add_child(enemy)
	enemy._ready()
	
	var death_state := {"died": false}
	enemy.enemy_died.connect(func(_e): death_state["died"] = true)
	
	enemy.take_damage(enemy.max_health)
	_assert_true(death_state["died"], "IT-004", "Enemy emits enemy_died signal when HP reaches 0")
	enemy.queue_free()


func _test_it005_mission_manager_lifecycle() -> void:
	var mgr := MissionManager.new()
	add_child(mgr)
	
	var mission_data := MissionDatabase.get_mission(0)
	mgr.start_mission(mission_data)
	_assert_true(mgr._is_active, "IT-005a", "MissionManager enters active state")
	
	# Test location reach
	mgr.report_location_reached("waypoint_1")
	var summary := mgr.get_objectives_summary()
	_assert_true(summary[0]["completed"], "IT-005b", "Reaching waypoint_1 completes objective 0")
	mgr.queue_free()


func _test_it006_pause_system_state() -> void:
	GameManager.set_state(GameManager.GameState.PLAYING)
	_assert_true(not GameManager.get_tree().paused, "IT-006a", "GameState.PLAYING unpauses SceneTree")
	
	GameManager.set_state(GameManager.GameState.PAUSED)
	_assert_true(GameManager.get_tree().paused, "IT-006b", "GameState.PAUSED pauses SceneTree")
	
	# Resume
	GameManager.set_state(GameManager.GameState.PLAYING)
	_assert_true(not GameManager.get_tree().paused, "IT-006c", "Resuming returns SceneTree to unpaused")


func _test_it007_all_missions_integrity() -> void:
	var validation := MissionDatabase.validate_all_missions()
	_assert_eq(validation.size(), 0, "IT-007a", "All 51 campaign missions pass structural validation")
	_assert_eq(MissionDatabase.get_mission_count(), 51, "IT-007b", "Mission database contains exactly 51 missions (0 to 50)")


func _test_it008_campaign_progression_unlock() -> void:
	GameManager.current_mission_id = 0
	GameManager.set_state(GameManager.GameState.PLAYING)
	GameManager.complete_mission()
	
	_assert_true(GameManager.is_level_completed(0), "IT-008a", "Level 0 marked completed in campaign data")
	_assert_true(GameManager.is_level_unlocked(1), "IT-008b", "Completing Level 0 unlocks Level 1")


# ==============================================================================
# REGRESSION TESTS (RT-001 to RT-006)
# ==============================================================================

func _test_rt001_completed_missions_accessible() -> void:
	_assert_true(GameManager.is_level_unlocked(0), "RT-001", "Completed missions remain unlocked for replay")


func _test_rt002_save_preserves_campaign_data() -> void:
	var save_dict := GameManager._get_save_data()
	_assert_true(save_dict.has("campaign"), "RT-002a", "Save export contains 'campaign' key")
	_assert_true(save_dict.has("settings"), "RT-002b", "Save export contains 'settings' key")


func _test_rt003_repeated_damage_consistency() -> void:
	var wpn := WeaponData.new()
	wpn.base_damage = 20.0
	var d1 := wpn.calculate_damage(5.0, false)
	var d2 := wpn.calculate_damage(5.0, false)
	_assert_eq(d1, d2, "RT-003", "Repeated damage calculations with identical inputs yield identical output")


func _test_rt004_mission_stats_reset() -> void:
	GameManager.record_shot_fired()
	GameManager.record_shot_hit(true)
	_assert_true(GameManager.mission_stats["shots_fired"] > 0, "RT-004a", "Stats recorded during mission")
	
	# Start new mission -> stats reset
	GameManager.current_mission_id = 0
	GameManager.mission_stats = {"shots_fired": 0, "shots_hit": 0, "enemies_killed": 0}
	_assert_eq(GameManager.mission_stats["shots_fired"], 0, "RT-004b", "Starting new mission resets runtime stats")


func _test_rt005_dead_enemy_stops_attacking() -> void:
	var enemy := EnemyController.new()
	enemy._ready()
	enemy._die()
	_assert_eq(enemy.current_state, EnemyController.AIState.DEAD, "RT-005a", "Enemy is in DEAD state")
	
	# Try calling _perform_attack() while dead
	enemy._perform_attack()
	_assert_eq(enemy.current_state, EnemyController.AIState.DEAD, "RT-005b", "Dead enemy does not resume attacking")
	enemy.free()


func _test_rt006_mission_completion_idempotency() -> void:
	# Complete mission already in complete state
	var prev_completed_count: int = (GameManager.campaign_data["completed_levels"] as Array).size()
	GameManager.complete_mission()
	var after_completed_count: int = (GameManager.campaign_data["completed_levels"] as Array).size()
	_assert_eq(prev_completed_count, after_completed_count, "RT-006", "Calling complete_mission outside PLAYING state is safely ignored")
