extends Node3D
## Automated Theme Levels Verification Test
## Tests representative levels across all 5 distinct environment themes:
## Level 0: military_base
## Level 1: forest
## Level 4: village
## Level 13: desert
## Level 14: industrial

const THEME_TEST_LEVELS: Array[Dictionary] = [
	{"level_id": 0, "theme": "military_base", "name": "Basic Training"},
	{"level_id": 1, "theme": "forest", "name": "First Contact"},
	{"level_id": 4, "theme": "village", "name": "Village Sweep"},
	{"level_id": 13, "theme": "desert", "name": "Dune Patroller"},
	{"level_id": 14, "theme": "industrial", "name": "Refinery Breach"}
]

var _current_index: int = 0
var _results: Array[Dictionary] = []


func _ready() -> void:
	print("\n==================================================")
	print("  RUNNING REPRESENTATIVE THEME LEVELS TEST")
	print("==================================================\n")
	_run_next_level()


func _run_next_level() -> void:
	if _current_index >= THEME_TEST_LEVELS.size():
		_finish_tests()
		return
	
	var test_info: Dictionary = THEME_TEST_LEVELS[_current_index]
	var level_id: int = test_info["level_id"]
	var theme_name: String = test_info["theme"]
	print("Testing Level %d [%s] — '%s'..." % [level_id, theme_name, test_info["name"]])
	
	GameManager.current_mission_id = level_id
	var level_scene: PackedScene = load("res://scenes/levels/level_base.tscn")
	var level_instance = level_scene.instantiate()
	add_child(level_instance)
	
	# Allow frames for _ready() and navigation baking
	await get_tree().process_frame
	await get_tree().process_frame
	
	var res := {
		"level_id": level_id,
		"theme": theme_name,
		"has_player": false,
		"player_pos_valid": false,
		"enemies_spawned": 0,
		"waypoints_spawned": 0,
		"has_environment": false,
		"passed": true,
		"notes": []
	}
	
	# Verify Player
	var player: PlayerController = level_instance.get_node_or_null("Player")
	if player:
		res["has_player"] = true
		if player.global_position.distance_to(Vector3(0, 1, 0)) < 2.0:
			res["player_pos_valid"] = true
		else:
			res["notes"].append("Player spawn unexpected: %s" % str(player.global_position))
	else:
		res["has_player"] = false
		res["passed"] = false
		res["notes"].append("Missing Player node")
	
	# Verify Environment
	var env_node = level_instance.get_node_or_null("WorldEnvironment")
	var dir_light = level_instance.get_node_or_null("Sun")
	var nav_region = level_instance.get_node_or_null("NavigationRegion")
	var ground = level_instance.get_node_or_null("Ground")
	if env_node and dir_light and nav_region and ground:
		res["has_environment"] = true
	else:
		res["has_environment"] = false
		res["passed"] = false
		res["notes"].append("Missing WorldEnvironment, Sun, NavigationRegion, or Ground")
	
	# Verify Enemies
	var enemies := get_tree().get_nodes_in_group("enemy")
	res["enemies_spawned"] = enemies.size()
	if enemies.size() == 0:
		res["passed"] = false
		res["notes"].append("Zero enemies spawned")
	
	# Verify Waypoint Beacons
	var waypoint_count := 0
	for child in level_instance.get_children():
		if child is Area3D and child.name.begins_with("Waypoint_"):
			waypoint_count += 1
	res["waypoints_spawned"] = waypoint_count
	
	_results.append(res)
	
	print("  -> Result: %s | Enemies: %d | Waypoints: %d | Env: %s" % [
		"PASS" if res["passed"] else "FAIL",
		res["enemies_spawned"],
		res["waypoints_spawned"],
		"OK" if res["has_environment"] else "FAIL"
	])
	
	# Clean up
	level_instance.queue_free()
	await get_tree().process_frame
	
	_current_index += 1
	_run_next_level()


func _finish_tests() -> void:
	print("\n==================================================")
	print("  THEME LEVELS TEST SUMMARY")
	print("==================================================")
	var all_passed := true
	for r in _results:
		var status_str := "PASS" if r["passed"] else "FAIL"
		print("  [%s] Level %d (%s): Enemies=%d, Waypoints=%d" % [status_str, r["level_id"], r["theme"], r["enemies_spawned"], r["waypoints_spawned"]])
		if not r["passed"]:
			all_passed = false
			for n in r["notes"]:
				print("       Issue: %s" % n)
	
	print("\nOverall Status: %s\n" % ("ALL THEMES VERIFIED" if all_passed else "SOME THEMES FAILED"))
	get_tree().quit(0 if all_passed else 1)
